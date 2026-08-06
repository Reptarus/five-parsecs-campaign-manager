extends GdUnitTestSuite
## Campaign saves must never be destroyed by an interrupted write.
##
## THE BUG THIS EXISTS TO PREVENT
## All four campaign cores did:
##     var file = FileAccess.open(path, FileAccess.WRITE)   # truncates to 0 bytes NOW
##     file.store_string(json_string)                       # ~40 KB
##     file.close()                                         # no flush, no error check
##     return OK                                            # unconditional
##
## FileAccess.WRITE truncates the LIVE save the instant it opens, so from that
## moment until close() the campaign exists only in memory. Godot only auto-closes
## files on a NORMAL process exit, so an Android background-kill, OOM kill or
## task-swipe in that window leaves a 0-byte or half-written JSON. The next launch
## gets null from load_from_file() and only push_warning()s — Continue silently does
## nothing and the campaign is gone.
##
## The window opened on EVERY phase completion (the turn controller autosaves after
## each), plus world-phase checkpoints, the End Phase panel and the dashboard Save
## button. On Android, being killed while backgrounded is routine.
##
## There was no recovery: CampaignFinalizationService writes a `.backup` once at
## campaign creation and NOTHING ever reads a .backup file.
##
## gdUnit4 v6.0.3 compatible.

const Writer = preload("res://src/core/state/SaveFileWriter.gd")

const TARGET := "user://test_atomic_target.save"
const GOOD_JSON := '{"campaign_id":"good","turns":7}'


func after_test() -> void:
	for p in [TARGET, TARGET + ".bak", TARGET + ".tmp"]:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(p))


func _write_raw(path: String, text: String) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(text)
	f.close()


func _read(path: String) -> String:
	if not FileAccess.file_exists(path):
		return ""
	var f := FileAccess.open(path, FileAccess.READ)
	var t := f.get_as_text()
	f.close()
	return t


# --- the write itself ---------------------------------------------------------

func test_a_normal_write_lands_and_leaves_no_temp() -> void:
	assert_int(Writer.write_text_atomic(TARGET, GOOD_JSON)).is_equal(OK)
	assert_str(_read(TARGET)).is_equal(GOOD_JSON)
	assert_bool(FileAccess.file_exists(TARGET + ".tmp")).override_failure_message(
		"a .tmp survived a successful write; the rename did not happen"
	).is_false()


func test_the_previous_save_is_kept_as_a_bak() -> void:
	_write_raw(TARGET, '{"campaign_id":"older"}')
	Writer.write_text_atomic(TARGET, GOOD_JSON)
	assert_str(_read(TARGET + ".bak")).override_failure_message(
		"no .bak generation was kept, so a future corrupt write has nothing to fall back to"
	).is_equal('{"campaign_id":"older"}')


# --- the recovery path (the half nobody built last time) ----------------------

func test_a_truncated_save_is_recovered_from_the_bak() -> void:
	# The EXACT artefact an interrupted write leaves: a 0-byte file.
	# Simulate a later write that produced a good .bak then died mid-swap.
	_write_raw(TARGET + ".bak", GOOD_JSON)
	_write_raw(TARGET, "")

	var recovered: Dictionary = Writer.read_json_with_fallback(TARGET)
	assert_str(str(recovered.get("campaign_id", ""))).override_failure_message(
		"a 0-byte save was not recovered from .bak — this is the data-loss case"
	).is_equal("good")


func test_a_corrupt_half_written_save_is_recovered_from_the_bak() -> void:
	_write_raw(TARGET + ".bak", GOOD_JSON)
	_write_raw(TARGET, '{"campaign_id":"goo')   # truncated mid-JSON
	var recovered: Dictionary = Writer.read_json_with_fallback(TARGET)
	assert_str(str(recovered.get("campaign_id", ""))).is_equal("good")


func test_a_healthy_save_is_never_overridden_by_a_stale_bak() -> void:
	# Anti-false-positive: the fallback must only fire when the primary is UNUSABLE.
	_write_raw(TARGET + ".bak", '{"campaign_id":"stale"}')
	_write_raw(TARGET, GOOD_JSON)
	var loaded: Dictionary = Writer.read_json_with_fallback(TARGET)
	assert_str(str(loaded.get("campaign_id", ""))).override_failure_message(
		"the .bak overrode a perfectly good save"
	).is_equal("good")


func test_missing_primary_and_missing_bak_returns_empty_not_garbage() -> void:
	assert_bool(Writer.read_json_with_fallback(TARGET).is_empty()).is_true()
