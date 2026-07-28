extends GdUnitTestSuite
## The .bak generation must actually be READ, and deleting a save must be permanent.
##
## THE BUGS THESE EXIST TO PREVENT
##
## 1. A BACKUP NOTHING READS. SaveFileWriter.write_text_atomic() keeps the previous
##    generation as <path>.bak on every save, but all four campaign cores opened the
##    primary file directly with FileAccess.open(path, READ). read_json_with_fallback()
##    had zero callers, so a truncated or half-written save was simply unloadable
##    while the intact backup sat beside it unopened — the exact failure the backup
##    was written to survive.
##
## 2. A DELETE THAT UNDOES ITSELF. Deleting a save removed only the primary file.
##    Once the fallback above was wired, the surviving .bak made the campaign
##    reappear on the next load. Separately, GameState still held the campaign in
##    current_campaign and still named it in `last_campaign`, so Continue reopened
##    the deleted campaign from memory and the next autosave rewrote the file to the
##    same path.
##
## gdUnit4 v6.0.3 compatible.

const SaveFileWriter = preload("res://src/core/state/SaveFileWriter.gd")
const CampaignCore = preload("res://src/game/campaign/FiveParsecsCampaignCore.gd")

const TEST_DIR := "user://test_save_recovery/"

var _paths: Array[String] = []


func before_test() -> void:
	if not DirAccess.dir_exists_absolute(TEST_DIR):
		DirAccess.make_dir_recursive_absolute(TEST_DIR)


func after_test() -> void:
	for p in _paths:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(p)
		if FileAccess.file_exists(p + ".bak"):
			DirAccess.remove_absolute(p + ".bak")
	_paths.clear()


func _path(name: String) -> String:
	var p := TEST_DIR + name
	_paths.append(p)
	return p


# --- reading through the fallback ----------------------------------------------

func test_a_truncated_save_recovers_from_the_backup() -> void:
	var p := _path("truncated.save")
	# Generation 1 — the good save.
	SaveFileWriter.write_text_atomic(p, JSON.stringify({"campaign_id": "gen1", "credits": 40}))
	# Generation 2 — establishes gen1 as the .bak.
	SaveFileWriter.write_text_atomic(p, JSON.stringify({"campaign_id": "gen2", "credits": 55}))

	# Now simulate the crash-mid-write artefact: a 0-byte primary.
	var f := FileAccess.open(p, FileAccess.WRITE)
	f.store_string("")
	f.close()

	var data := SaveFileWriter.read_json_with_fallback(p)
	assert_bool(data.is_empty()).override_failure_message(
		"a 0-byte save still reads as unrecoverable — the .bak was never consulted"
	).is_false()
	assert_str(str(data.get("campaign_id", ""))).is_equal("gen1")


func test_a_corrupt_save_recovers_from_the_backup() -> void:
	var p := _path("corrupt.save")
	SaveFileWriter.write_text_atomic(p, JSON.stringify({"campaign_id": "good"}))
	SaveFileWriter.write_text_atomic(p, JSON.stringify({"campaign_id": "newer"}))

	var f := FileAccess.open(p, FileAccess.WRITE)
	f.store_string("{ this is not json")
	f.close()

	var data := SaveFileWriter.read_json_with_fallback(p)
	assert_str(str(data.get("campaign_id", ""))).is_equal("good")


func test_an_intact_save_is_preferred_over_the_backup() -> void:
	# The fallback must never win over a readable primary.
	var p := _path("intact.save")
	SaveFileWriter.write_text_atomic(p, JSON.stringify({"campaign_id": "older"}))
	SaveFileWriter.write_text_atomic(p, JSON.stringify({"campaign_id": "current"}))

	var data := SaveFileWriter.read_json_with_fallback(p)
	assert_str(str(data.get("campaign_id", ""))).is_equal("current")


func test_no_file_and_no_backup_returns_empty() -> void:
	var data := SaveFileWriter.read_json_with_fallback(TEST_DIR + "does_not_exist.save")
	assert_bool(data.is_empty()).is_true()


func test_the_campaign_core_loads_through_the_fallback() -> void:
	# The wiring that actually matters: load_from_file() must survive a broken primary.
	var p := _path("core_recovery.save")
	var campaign = CampaignCore.new()
	campaign.campaign_id = "recoverable"
	campaign.campaign_name = "Recoverable Crew"
	campaign.save_to_file(p)
	campaign.save_to_file(p)  # second write establishes the .bak

	var f := FileAccess.open(p, FileAccess.WRITE)
	f.store_string("")
	f.close()

	var loaded = CampaignCore.load_from_file(p)
	assert_object(loaded).override_failure_message(
		"load_from_file still returns null on a truncated save instead of using the .bak"
	).is_not_null()
	if loaded:
		assert_str(str(loaded.campaign_id)).is_equal("recoverable")


# --- delete must be permanent ---------------------------------------------------

func test_deleting_a_save_must_also_remove_the_backup() -> void:
	# Documents the contract MainMenu._on_delete_save relies on: with the fallback
	# wired, a surviving .bak resurrects the campaign on the next load.
	var p := _path("deleted.save")
	SaveFileWriter.write_text_atomic(p, JSON.stringify({"campaign_id": "doomed"}))
	SaveFileWriter.write_text_atomic(p, JSON.stringify({"campaign_id": "doomed2"}))
	assert_bool(FileAccess.file_exists(p + ".bak")).is_true()

	# Primary only — the old delete behaviour.
	DirAccess.remove_absolute(p)
	var resurrected := SaveFileWriter.read_json_with_fallback(p)
	assert_bool(resurrected.is_empty()).override_failure_message(
		"deleting only the primary leaves a .bak that loads straight back"
	).is_false()

	# Both — the current behaviour.
	DirAccess.remove_absolute(p + ".bak")
	assert_bool(SaveFileWriter.read_json_with_fallback(p).is_empty()).is_true()


func test_forget_campaign_clears_the_in_memory_campaign() -> void:
	var gs = Engine.get_main_loop().root.get_node_or_null("/root/GameState")
	if gs == null:
		return
	var previous = gs.current_campaign

	var campaign = CampaignCore.new()
	campaign.campaign_id = "to_forget"
	gs.current_campaign = campaign
	gs.forget_campaign("to_forget")

	var still_loaded = gs.current_campaign
	gs.current_campaign = previous  # restore the live autoload before asserting

	assert_object(still_loaded).override_failure_message(
		"the deleted campaign is still loaded, so Continue reopens it and the next autosave rewrites the file"
	).is_null()


func test_forget_campaign_leaves_a_different_campaign_alone() -> void:
	var gs = Engine.get_main_loop().root.get_node_or_null("/root/GameState")
	if gs == null:
		return
	var previous = gs.current_campaign

	var campaign = CampaignCore.new()
	campaign.campaign_id = "keep_me"
	gs.current_campaign = campaign
	gs.forget_campaign("some_other_campaign")

	var still_loaded = gs.current_campaign
	gs.current_campaign = previous

	assert_object(still_loaded).is_not_null()
