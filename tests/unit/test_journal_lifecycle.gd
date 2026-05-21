extends GdUnitTestSuite
## Tests for the CampaignJournal cross-campaign contamination guard in
## GameState._propagate_campaign_id_to_journal().
##
## Bug being prevented: switching to a different campaign (CREATE or LOAD)
## must not leave stale entries from the previous campaign in the autoload.
## See plan: docs/sprint notes for "Journal Cross-Campaign Contamination".

var journal: Node
var state: Node

# Snapshot fields restored in after_test so tests don't pollute the
# autoload state if a real campaign happens to be loaded in the harness.
var _saved_id: String = ""
var _saved_entries: Array = []
var _saved_milestones: Array = []
var _saved_character_histories: Dictionary = {}
var _saved_next_entry_id: int = 1
var _saved_created_at: int = 0


func before_test() -> void:
	var tree := Engine.get_main_loop()
	assert_that(tree).is_not_null()
	journal = tree.root.get_node_or_null("/root/CampaignJournal")
	state = tree.root.get_node_or_null("/root/GameState")
	assert_that(journal).is_not_null()
	assert_that(state).is_not_null()

	# Snapshot — every test runs against a clean journal then restores.
	_saved_id = str(journal.current_campaign_id)
	_saved_entries = journal.entries.duplicate(true)
	_saved_milestones = journal.milestones.duplicate(true)
	_saved_character_histories = journal.character_histories.duplicate(true)
	_saved_next_entry_id = journal.next_entry_id
	_saved_created_at = journal.campaign_created_at

	# Reset to a known-clean state. initialize_for_campaign wipes
	# entries/milestones/character_histories and sets id.
	journal.initialize_for_campaign("")
	journal.set_current_campaign_id("")


func after_test() -> void:
	if journal == null:
		return
	# Restore the snapshot so we don't break anything else running in
	# the test harness (or a real loaded campaign in the editor).
	journal.initialize_for_campaign(_saved_id)
	journal.entries.assign(_saved_entries)
	journal.milestones.assign(_saved_milestones)
	journal.character_histories = _saved_character_histories.duplicate(true)
	journal.next_entry_id = _saved_next_entry_id
	journal.campaign_created_at = _saved_created_at
	# Rebuild entries_by_id index from restored entries
	journal.entries_by_id.clear()
	for entry_v in journal.entries:
		var entry: Dictionary = entry_v
		var eid: String = str(entry.get("id", ""))
		if not eid.is_empty():
			journal.entries_by_id[eid] = entry


# ============================================================================
# Scenario 1: Fresh CREATE wipes stale entries from a previous campaign
# ============================================================================

func test_fresh_create_wipes_stale_entries() -> void:
	# Seed entries that pretend to belong to "campaign_alpha"
	journal.set_current_campaign_id("campaign_alpha")
	var alpha_id: String = journal.create_entry({
		"type": "milestone",
		"title": "Alpha entry"})
	assert_int(journal.entries.size()).is_equal(1)
	assert_str(alpha_id).is_not_empty()

	# Simulate the CreationCoordinator path: a brand new campaign is set.
	# The heuristic should detect the id change + non-empty entries[] and
	# wipe via initialize_for_campaign.
	state.propagate_campaign_id_to_journal("campaign_beta")

	assert_int(journal.entries.size()).is_equal(0)
	assert_str(str(journal.current_campaign_id)).is_equal("campaign_beta")


# ============================================================================
# Scenario 2: Re-setting the SAME id preserves entries (mid-session refresh)
# ============================================================================

func test_same_campaign_reset_preserves_entries() -> void:
	journal.set_current_campaign_id("campaign_x")
	journal.create_entry({"type": "milestone", "title": "X entry"})
	assert_int(journal.entries.size()).is_equal(1)

	# Re-setting the same id should NOT wipe — e.g. mid-session phase
	# transitions that re-trigger set_current_campaign for the same campaign.
	state.propagate_campaign_id_to_journal("campaign_x")

	assert_int(journal.entries.size()).is_equal(1)
	assert_str(str(journal.current_campaign_id)).is_equal("campaign_x")


# ============================================================================
# Scenario 3: Quit-to-menu (campaign cleared, id set to "") wipes entries
# ============================================================================

func test_quit_to_menu_clears_journal() -> void:
	journal.set_current_campaign_id("campaign_y")
	journal.create_entry({"type": "milestone", "title": "Y entry"})
	assert_int(journal.entries.size()).is_equal(1)

	# Quit to main menu: set_current_campaign(null) → propagates "".
	# Empty id is "different from current id", entries non-empty → wipe.
	# This prevents Y's entries leaking into the next campaign created
	# without exiting the game.
	state.propagate_campaign_id_to_journal("")

	assert_int(journal.entries.size()).is_equal(0)
	assert_str(str(journal.current_campaign_id)).is_equal("")


# ============================================================================
# Scenario 4: LOAD path — set_current_campaign wipes, load_from_save repopulates
# ============================================================================

func test_load_path_preserves_after_apply_pending_qol() -> void:
	# Seed stale entries from a "previous" campaign in the same session
	journal.set_current_campaign_id("campaign_old")
	journal.create_entry({
		"type": "milestone",
		"title": "Old session entry"})
	assert_int(journal.entries.size()).is_equal(1)

	# LOAD sequence step 1: set_current_campaign fires (via GameState.load_campaign).
	# Heuristic wipes — harmless because step 2 immediately repopulates.
	state.propagate_campaign_id_to_journal("campaign_loaded")
	assert_int(journal.entries.size()).is_equal(0)

	# LOAD sequence step 2: apply_pending_qol_data → load_from_save.
	# This is what FiveParsecsCampaignCore.apply_pending_qol_data does for
	# 5PFH saves; we simulate the payload shape directly.
	var save_data: Dictionary = {
		"qol_data": {
			"journal": {
				"schema_version": 2,
				"entries": [{
					"id": "loaded_1",
					"type": "milestone",
					"title": "Loaded entry",
				}],
				"milestones": [],
				"character_histories": {},
				"created_at": 0,
				"last_updated": 0,
				"next_entry_id": 2,
			}
		}
	}
	journal.load_from_save(save_data)

	# Final state: entries match what the save file contained, not the
	# stale "Old session entry" we seeded at the top.
	assert_int(journal.entries.size()).is_equal(1)
	assert_str(str(journal.entries[0].get("title", ""))).is_equal("Loaded entry")


# ============================================================================
# Scenario 5: First campaign of session — no wipe needed (no stale entries)
# ============================================================================

func test_first_campaign_of_session_no_wipe_needed() -> void:
	# before_test() already cleared to fresh state — confirm baseline
	assert_int(journal.entries.size()).is_equal(0)
	assert_str(str(journal.current_campaign_id)).is_equal("")

	# First campaign set after game launch: no stale entries to wipe,
	# heuristic takes the non-destructive set_current_campaign_id path.
	state.propagate_campaign_id_to_journal("campaign_first")

	assert_str(str(journal.current_campaign_id)).is_equal("campaign_first")
	# entries still empty — nothing was written or cleared
	assert_int(journal.entries.size()).is_equal(0)


# ============================================================================
# Scenario 6: current_campaign_id round-trips through save_to_dict/load_from_save
# ============================================================================

func test_current_campaign_id_round_trips_through_save_dict() -> void:
	# Set an id and create one entry, save the dict, mutate the autoload to a
	# DIFFERENT id, then load — the loaded id should overwrite the live one.
	journal.set_current_campaign_id("campaign_saved")
	journal.create_entry({"type": "milestone", "title": "Saved entry"})

	var saved: Dictionary = journal.save_to_dict()
	assert_str(str(saved.get("current_campaign_id", ""))).is_equal("campaign_saved")

	# Simulate a fresh autoload state with a DIFFERENT id (e.g. user is
	# manually importing a JSON file from another campaign)
	journal.initialize_for_campaign("campaign_different")
	assert_str(str(journal.current_campaign_id)).is_equal("campaign_different")

	# load_from_save expects the OUTER {"qol_data": {"journal": <dict>}} wrap
	journal.load_from_save({"qol_data": {"journal": saved}})

	# The saved id should win
	assert_str(str(journal.current_campaign_id)).is_equal("campaign_saved")
	assert_int(journal.entries.size()).is_equal(1)


func test_load_preserves_propagated_id_when_save_lacks_field() -> void:
	# Backward compat: pre-v2 saves don't include current_campaign_id.
	# In that case, load_from_save must NOT clobber the live id (which
	# GameState propagated from the loaded campaign).
	journal.set_current_campaign_id("campaign_propagated")

	# Synthesize a "legacy" save dict (no current_campaign_id field)
	var legacy_journal: Dictionary = {
		"schema_version": 2,
		"entries": [{
			"id": "legacy_1",
			"type": "milestone",
			"title": "Legacy entry"}],
		"milestones": [],
		"character_histories": {},
		"created_at": 0,
		"last_updated": 0,
		"next_entry_id": 2,
	}
	journal.load_from_save({"qol_data": {"journal": legacy_journal}})

	# Entries loaded, but the id stays what GameState propagated
	assert_int(journal.entries.size()).is_equal(1)
	assert_str(str(journal.current_campaign_id)).is_equal("campaign_propagated")


# ============================================================================
# Scenario 7: Cross-mode CampaignCore Resources round-trip journal via qol_data
# ============================================================================
## These tests cover the new _pending_qol_data + _build_qol_data +
## apply_pending_qol_data plumbing added to BugHunt/Planetfall/Tactics cores.
## Before this fix, the cross-mode cores wrote journal data into their save
## files but never restored it on load — silent data loss.

func _exercise_cross_mode_round_trip(core: Resource, mode_label: String) -> void:
	# Seed the live journal as if we played a session for this mode
	journal.set_current_campaign_id("test_" + mode_label)
	journal.create_entry({
		"type": "milestone",
		"title": mode_label + " entry"})
	assert_int(journal.entries.size()).is_equal(1)

	# Save: to_dictionary should snapshot the journal under qol_data.journal
	var saved: Dictionary = core.to_dictionary()
	assert_bool(saved.has("qol_data")).is_true()
	var qol: Dictionary = saved.get("qol_data", {})
	assert_bool(qol.has("journal")).is_true()
	var journal_dict: Dictionary = qol.get("journal", {})
	assert_int((journal_dict.get("entries", []) as Array).size()).is_equal(1)

	# Wipe the live journal — pretend the session ended
	journal.initialize_for_campaign("")
	assert_int(journal.entries.size()).is_equal(0)

	# Load: instantiate a fresh core, hydrate from the saved dict.
	# Capture happens in from_dictionary; restore deferred to apply_pending_qol_data.
	var fresh: Resource = core.get_script().new()
	fresh.from_dictionary(saved)

	# apply_pending_qol_data: replays load_from_save against the live journal
	fresh.apply_pending_qol_data()

	# Verify the seeded entry was restored
	assert_int(journal.entries.size()).is_equal(1)
	assert_str(str(journal.entries[0].get("title", ""))).is_equal(
		mode_label + " entry")


func test_bug_hunt_core_round_trips_journal_via_qol_data() -> void:
	_exercise_cross_mode_round_trip(BugHuntCampaignCore.new(), "bug_hunt")


func test_planetfall_core_round_trips_journal_via_qol_data() -> void:
	_exercise_cross_mode_round_trip(PlanetfallCampaignCore.new(), "planetfall")


func test_tactics_core_round_trips_journal_via_qol_data() -> void:
	_exercise_cross_mode_round_trip(TacticsCampaignCore.new(), "tactics")
