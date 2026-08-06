extends GdUnitTestSuite

## Campaign Editor data-layer methods (v1): FiveParsecsCampaignCore.remove_crew_member /
## update_crew_member (with is_captain preservation) and GameStateManager.set_turns_played.
## These are the write-through chokepoints the editor uses instead of raw dict writes.

const CampaignCore = preload("res://src/game/campaign/FiveParsecsCampaignCore.gd")

var _core

func before_test() -> void:
	_core = CampaignCore.new()
	_core.crew_data = {"members": [
		{"character_id": "cap", "character_name": "Captain", "is_captain": true, "combat": 1},
		{"character_id": "m1", "character_name": "Member One", "is_captain": false, "combat": 2},
	]}
	_core._rebuild_crew_id_index()

# --- remove_crew_member ---

func test_remove_crew_member_removes_by_id_and_rebuilds_index() -> void:
	assert_bool(_core.remove_crew_member("m1")).is_true()
	assert_int(_core.get_crew_members().size()).is_equal(1)
	assert_object(_core.get_crew_member_by_id("m1")).is_null()
	# The surviving captain still resolves through the rebuilt index.
	assert_object(_core.get_crew_member_by_id("cap")).is_not_null()

func test_remove_crew_member_bad_id_is_noop() -> void:
	assert_bool(_core.remove_crew_member("nonexistent")).is_false()
	assert_int(_core.get_crew_members().size()).is_equal(2)

# --- update_crew_member ---

func test_update_crew_member_preserves_captain_flag() -> void:
	# The edited dict from the character creator carries NO is_captain; the update must
	# keep the captain a captain (add_crew_member would have wrongly demoted them).
	var edited := {"character_id": "cap", "character_name": "Captain Renamed", "combat": 5}
	assert_bool(_core.update_crew_member("cap", edited)).is_true()
	var cap: Dictionary = _core.get_crew_member_by_id("cap")
	assert_bool(bool(cap.get("is_captain", false))).is_true()
	assert_str(str(cap.get("character_name"))).is_equal("Captain Renamed")
	assert_int(int(cap.get("combat"))).is_equal(5)

func test_update_crew_member_noncaptain_stays_noncaptain() -> void:
	# Even if an edited non-captain dict tries to sneak is_captain=true, the current
	# roster entry's flag wins (only one captain, sourced from the existing member).
	var edited := {"character_id": "m1", "character_name": "M1", "is_captain": true}
	assert_bool(_core.update_crew_member("m1", edited)).is_true()
	var m: Dictionary = _core.get_crew_member_by_id("m1")
	assert_bool(bool(m.get("is_captain", false))).is_false()

func test_update_crew_member_bad_id_is_noop() -> void:
	assert_bool(_core.update_crew_member("nope", {"character_id": "nope"})).is_false()
	assert_int(_core.get_crew_members().size()).is_equal(2)

# --- set_turns_played ---

func test_set_turns_played_writes_through_and_clamps() -> void:
	var gsm = get_node_or_null("/root/GameStateManager")
	var gs = get_node_or_null("/root/GameState")
	assert_object(gsm).is_not_null()
	assert_object(gs).is_not_null()
	var saved = gs.current_campaign if "current_campaign" in gs else null
	gs.current_campaign = _core

	gsm.set_turns_played(20)
	assert_int(int(_core.progress_data.get("turns_played", -1))).is_equal(20)

	gsm.set_turns_played(-5)  # clamps to 0
	assert_int(int(_core.progress_data.get("turns_played", -1))).is_equal(0)

	gs.current_campaign = saved
