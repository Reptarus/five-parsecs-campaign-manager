extends GdUnitTestSuite
## Save-integrity round-trips (Phase 1 of the Aug 1 data-flow sprint).
##
## Every case here pins a SAVE/LOAD JOIN. The shape they all share: a field is
## written on one side and read on the other under a different name, a different
## location, or a narrower type — so it survives the session and vanishes on
## reload. None of these produced an error; a `.get(key, default)` on a missing
## key is a silent default, and a narrowing constructor is silent by design.

const CharacterScript = preload("res://src/core/character/Character.gd")
const DetailsScreen = preload("res://src/ui/screens/character/CharacterDetailsScreen.gd")
const ChecklistScript = preload("res://src/qol/TurnPhaseChecklist.gd")
const CampaignCoreScript = preload("res://src/game/campaign/FiveParsecsCampaignCore.gd")

# ══════════════════════════════════════════════════════════════════════════
# 1.1 — Opening a crew card must not delete the member's equipment
#
# CharacterDetailsScreen kept the crew member's live campaign dict and merged
# `to_dictionary()` over it on the way out. But the Character it merged FROM was
# built by from_dictionary(), which narrows `equipment` to Array[String] and
# drops every Dictionary entry — and Dictionary IS the shape
# EquipmentTransferService produces and GameState.verify_consistency expects.
# So viewing a crew member destroyed their gear.
# ══════════════════════════════════════════════════════════════════════════

func test_from_dictionary_really_does_narrow_equipment() -> void:
	# The premise of the whole fix. If this ever stops being true (equipment
	# widened to Array[Dictionary]) the whitelist is still correct, but this
	# case should be revisited rather than silently passing for a new reason.
	var c: Resource = CharacterScript.new()
	c.from_dictionary({
		"character_name": "Vex",
		"equipment": ["plain_string_item", {"id": "itm_1", "name": "Rattle Gun"}],
	})
	var kept: Array = c.equipment
	assert_int(kept.size()).override_failure_message(
		"Character.equipment is Array[String]; the Dictionary entry is expected to be dropped"
	).is_equal(1)
	assert_str(str(kept[0])).is_equal("plain_string_item")

func test_the_writeback_whitelist_excludes_equipment() -> void:
	# The fix itself, asserted directly on the screen's contract. Equipment is
	# moved through EquipmentTransferService against the LIVE campaign, never
	# through this screen's narrowed copy, so it must never ride the merge.
	var keys: PackedStringArray = DetailsScreen.EDITABLE_KEYS
	assert_bool("equipment" in keys).override_failure_message(
		"equipment must NOT be in EDITABLE_KEYS — merging it back deletes Dictionary items"
	).is_false()

func test_the_whitelist_still_carries_what_the_screen_edits() -> void:
	# Guard the opposite failure: a whitelist so tight that real edits stop
	# persisting. These four are the fields the screen actually writes.
	var keys: PackedStringArray = DetailsScreen.EDITABLE_KEYS
	for expected in ["player_notes", "portrait_path", "experience", "acquired_training"]:
		assert_bool(expected in keys).override_failure_message(
			"%s is edited by CharacterDetailsScreen and must persist" % expected).is_true()

func test_a_dictionary_item_survives_the_whitelisted_merge() -> void:
	# End-to-end of the actual bug: live crew dict holds a card-shaped item ->
	# open (from_dictionary) -> close (merge) -> item still there.
	var live_member: Dictionary = {
		"character_id": "crew_1",
		"character_name": "Vex",
		"player_notes": "",
		"equipment": [{"id": "itm_1", "name": "Rattle Gun"}],
	}
	var c: Resource = CharacterScript.new()
	c.from_dictionary(live_member)
	c.player_notes = "edited on the details screen"

	# Exactly what _sync_character_to_source_dict() does.
	var updated: Dictionary = c.to_dictionary()
	for key in DetailsScreen.EDITABLE_KEYS:
		if updated.has(key):
			live_member[key] = updated[key]

	assert_int((live_member["equipment"] as Array).size()).override_failure_message(
		"the crew member's Dictionary-shaped equipment must survive a details-screen visit"
	).is_equal(1)
	assert_str(str(live_member["player_notes"])).is_equal("edited on the details screen")

# ══════════════════════════════════════════════════════════════════════════
# 1.1b — Advanced Training was wired to a property Character does not have
#
# `Character extends Resource` directly and declares `acquired_training`; the
# int `training` lives on BaseCharacterResource, which Character does NOT
# extend. Assigning to the nonexistent property is a runtime error that ABORTS
# the handler — taking the XP deduction on the next line with it. The button
# charged nothing, recorded nothing, and did not refresh.
# ══════════════════════════════════════════════════════════════════════════

func test_character_has_acquired_training_and_not_training() -> void:
	var c: Resource = CharacterScript.new()
	assert_bool("acquired_training" in c).is_true()
	assert_bool("training" in c).override_failure_message(
		"Character must NOT have a `training` property — assigning to it aborts the caller"
	).is_false()

func test_add_training_records_and_round_trips() -> void:
	var c: Resource = CharacterScript.new()
	c.add_training("science_officer")
	assert_array(c.acquired_training).contains(["science_officer"])
	# Duplicate suppressed by the canonical mutator.
	c.add_training("science_officer")
	assert_int((c.acquired_training as Array).size()).is_equal(1)

	var restored: Resource = CharacterScript.new()
	restored.from_dictionary(c.to_dictionary())
	assert_array(restored.acquired_training).override_failure_message(
		"a purchased training course must survive save/load"
	).contains(["science_officer"])

# ══════════════════════════════════════════════════════════════════════════
# 1.2 — Veteran mode / checklist progress never survived a reload
#
# The writer stores this block under "turn_checklist"; the reader looked for
# "checklist_settings", a key nothing in the repo has ever written, so
# load_from_save() early-returned on every single load.
# ══════════════════════════════════════════════════════════════════════════

func test_checklist_loads_from_the_key_the_writer_actually_uses() -> void:
	var cl: Node = auto_free(ChecklistScript.new())
	cl.veteran_mode = true
	var saved: Dictionary = cl.save_to_dict()

	var fresh: Node = auto_free(ChecklistScript.new())
	fresh.load_from_save({"qol_data": {"turn_checklist": saved}})
	assert_bool(fresh.veteran_mode).override_failure_message(
		"veteran_mode must survive reload — the writer's key is qol_data[\"turn_checklist\"]"
	).is_true()

func test_checklist_still_reads_the_legacy_key() -> void:
	var fresh: Node = auto_free(ChecklistScript.new())
	fresh.load_from_save({"qol_data": {"checklist_settings": {"veteran_mode": true}}})
	assert_bool(fresh.veteran_mode).is_true()

func test_mid_turn_checklist_progress_is_serialized() -> void:
	# Neither field was written at all, so a save partway through a phase came
	# back with an empty checklist — re-prompting for finished steps.
	var cl: Node = auto_free(ChecklistScript.new())
	cl.completed_actions = {"pay_crew_upkeep": true}
	cl.current_phase_checklist = {"required": ["resolve_injuries"]}
	var saved: Dictionary = cl.save_to_dict()
	assert_bool(saved.has("completed_actions")).is_true()

	var fresh: Node = auto_free(ChecklistScript.new())
	fresh.load_from_save({"qol_data": {"turn_checklist": saved}})
	assert_bool((fresh.completed_actions as Dictionary).get("pay_crew_upkeep", false)).is_true()
	assert_bool((fresh.current_phase_checklist as Dictionary).has("required")).is_true()

# ══════════════════════════════════════════════════════════════════════════
# 1.3 — schema_version was serialized but never restored
#
# The only one of the four campaign cores missing the restore. Harmless while
# the class default matches what is on disk; the moment the default is bumped,
# every OLD save reports the NEW version in memory and skips its migration.
# ══════════════════════════════════════════════════════════════════════════

func test_schema_version_round_trips() -> void:
	var core: Resource = CampaignCoreScript.new()
	var data: Dictionary = core.to_dictionary()
	# Simulate an older save whose schema differs from the current default.
	(data["meta"] as Dictionary)["schema_version"] = 99

	var loaded: Resource = CampaignCoreScript.new()
	loaded.from_dictionary(data)
	assert_int(int(loaded.schema_version)).override_failure_message(
		"schema_version must come back off disk — SaveFileMigration keys off it"
	).is_equal(99)
