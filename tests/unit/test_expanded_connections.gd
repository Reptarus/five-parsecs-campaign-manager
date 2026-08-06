extends GdUnitTestSuite
## Expanded Connections — Compendium pp.80-86.
##
## THE DEFECT THIS PINS. Same shape as Expanded Quests: complete data, correct
## readers, zero callers. missions_expanded.json carries the 5-row D6 main table
## and all five 6-row subtables — 30 scenarios, each with the book's `*` decline
## marker recorded as `decline_allowed` — and compendium_missions_expanded.gd
## exposed check_for_connection() / roll_connection_type() /
## roll_connection_subtable() behind a correct EXPANDED_CONNECTIONS gate. None of
## the three was called from anywhere.
##
## (src/core/character/connections/CharacterConnections.gd is a DIFFERENT system
## — creation-time starting contacts. The chapter trace conflated the two.)
##
## gdUnit4 v6.0.3 compatible.

const Connections = preload("res://src/core/campaign/ExpandedConnections.gd")
const MissionsExpanded = preload("res://src/data/compendium_missions_expanded.gd")

const PREP_SRC := "res://src/ui/screens/world/components/MissionPrepComponent.gd"
const PHASE_MGR_SRC := "res://src/core/campaign/CampaignPhaseManager.gd"
const COMPLETION_SRC := "res://src/core/campaign/phases/post_battle/PostBattleCompletion.gd"
const POST_BATTLE_SRC := "res://src/core/campaign/phases/PostBattlePhase.gd"

var _saved_flag: bool = false
var _saved_owned: bool = false
var _saved_no_roll: bool = false
var _saved_variety: bool = false


func _dlc() -> Node:
	return Engine.get_main_loop().root.get_node_or_null("/root/DLCManager")


func _sm() -> Node:
	return Engine.get_main_loop().root.get_node_or_null("/root/SettingsManager")


func before_test() -> void:
	var dlc := _dlc()
	if dlc != null:
		_saved_owned = dlc.has_dlc("freelancers_handbook")
		_saved_flag = dlc.is_feature_enabled(dlc.ContentFlag.get("EXPANDED_CONNECTIONS"))
	var sm := _sm()
	if sm != null:
		_saved_no_roll = bool(sm.use_connections_no_roll())
		_saved_variety = bool(sm.use_connections_variety())


func after_test() -> void:
	var dlc := _dlc()
	if dlc != null:
		dlc.set_feature_enabled(dlc.ContentFlag.get("EXPANDED_CONNECTIONS"), _saved_flag)
		dlc.set_dlc_owned("freelancers_handbook", _saved_owned)
	_set_options(_saved_no_roll, _saved_variety)


func _set_options(no_roll: bool, variety: bool) -> void:
	var sm := _sm()
	if sm == null:
		return
	sm.set_setting("gameplay", "connections_no_roll", no_roll)
	sm.set_setting("gameplay", "connections_variety", variety)


func _enable() -> bool:
	var dlc := _dlc()
	if dlc == null:
		return false
	dlc.set_dlc_owned("freelancers_handbook", true)
	dlc.set_feature_enabled(dlc.ContentFlag.get("EXPANDED_CONNECTIONS"), true)
	_set_options(false, false)
	return true


## A campaign with the automatic first-game Connection already spent, so a test
## about the 1D6 is a test about the 1D6.
func _campaign(first_game_done: bool = true) -> Dictionary:
	return {"progress_data": {"expanded_connections": {
		"seen": [], "last_had_connection": false,
		"first_game_done": first_game_done, "pending": {},
	}}}


func _src(path: String) -> String:
	var f := FileAccess.open(path, FileAccess.READ)
	assert_object(f).override_failure_message("cannot open %s" % path).is_not_null()
	var text: String = f.get_as_text()
	f.close()
	return text


func _code_only(path: String) -> String:
	var out: PackedStringArray = []
	for line in _src(path).split("\n"):
		if line.strip_edges().begins_with("#"):
			continue
		out.append(line)
	return "\n".join(out)


## =========================================================================
## The tables (pp.81-86)
## =========================================================================

func test_the_main_table_covers_1_to_6_and_names_five_subtables() -> void:
	var rows: Array = MissionsExpanded.CONNECTION_MAIN_TABLE
	assert_int(rows.size()).is_equal(5)
	var expected: int = 1
	var subtables: Array = []
	for row: Variant in rows:
		assert_int(int(row["roll_min"])).is_equal(expected)
		expected = int(row["roll_max"]) + 1
		subtables.append(int(row["subtable"]))
	assert_int(expected).is_equal(7)
	assert_array(subtables).contains_exactly([1, 2, 3, 4, 5])


func test_every_subtable_has_six_rows_addressable_by_d6() -> void:
	for number in range(1, 6):
		var rows: Array = Connections.subtable(number)
		assert_int(rows.size()).override_failure_message(
			"subtable %d" % number).is_equal(6)
		for roll in range(1, 7):
			assert_str(str(Connections.subtable_entry(number, roll).get("id", ""))
				).override_failure_message(
					"subtable %d roll %d does not resolve" % [number, roll]).is_not_empty()


func test_the_decline_markers_match_the_book_asterisks() -> void:
	## p.82 subtable 1 prints * on rows 1, 3, 5 and 6 only.
	var expected := {1: true, 2: false, 3: true, 4: false, 5: true, 6: true}
	for roll in expected.keys():
		assert_bool(bool(Connections.subtable_entry(1, roll).get("decline_allowed", false))
			).override_failure_message(
				"subtable 1 row %d decline flag" % roll).is_equal(expected[roll])


## =========================================================================
## The p.80 check
## =========================================================================

func test_connections_do_not_occur_on_quest_rival_or_patron_missions() -> void:
	## p.80, verbatim: "Connections do not occur during Quest, Rival or Patron
	## missions."
	if not _enable():
		return
	for source: String in ["quest", "rival", "patron", "invasion", "story_track"]:
		var out: Dictionary = Connections.check(_campaign(), source, 6)
		assert_bool(bool(out["applies"])).override_failure_message(
			"a %s mission must never be asked the question" % source).is_false()
		assert_bool(bool(out["triggered"])).is_false()


func test_five_or_six_gives_a_connection_and_lower_does_not() -> void:
	if not _enable():
		return
	for roll in [1, 2, 3, 4]:
		assert_bool(bool(Connections.check(_campaign(), "opportunity", roll)["triggered"])
			).override_failure_message("1D6 = %d must not trigger" % roll).is_false()
	for roll in [5, 6]:
		assert_bool(bool(Connections.check(_campaign(), "opportunity", roll)["triggered"])
			).override_failure_message("1D6 = %d must trigger" % roll).is_true()


func test_the_first_game_gets_an_automatic_connection() -> void:
	## p.81: "If you are playing your first game since purchasing this expansion,
	## have a Connection happen automatically this campaign turn."
	if not _enable():
		return
	var campaign := _campaign(false)
	var first: Dictionary = Connections.check(campaign, "opportunity", 1)
	assert_bool(bool(first["triggered"])).override_failure_message(
		"a losing die must not beat the automatic first Connection").is_true()
	# And it is spent — the next check is an ordinary roll.
	assert_bool(bool(Connections.check(campaign, "opportunity", 1)["triggered"])).is_false()


func test_the_no_roll_option_alternates_every_other_mission() -> void:
	## p.81: "a Connection occurs any time you play an Opportunity mission AND the
	## prior Opportunity mission did not have a Connection."
	if not _enable():
		return
	_set_options(true, false)
	var campaign := _campaign()
	assert_bool(bool(Connections.check(campaign, "opportunity", 1)["triggered"])
		).override_failure_message("the die must be ignored entirely").is_true()
	Connections.roll_connection(campaign, 1, 1, 1)
	assert_bool(bool(Connections.check(campaign, "opportunity", 6)["triggered"])
		).override_failure_message("the mission after a Connection has none").is_false()
	Connections.note_no_connection(campaign)
	assert_bool(bool(Connections.check(campaign, "opportunity", 1)["triggered"])).is_true()


func test_the_check_never_applies_when_the_chapter_is_off() -> void:
	var dlc := _dlc()
	if dlc == null:
		return
	dlc.set_feature_enabled(dlc.ContentFlag.get("EXPANDED_CONNECTIONS"), false)
	assert_bool(bool(Connections.check(_campaign(), "opportunity", 6)["applies"])).is_false()
	assert_bool(Connections.roll_connection(_campaign(), 1, 6, 1).is_empty()).is_true()


## =========================================================================
## Rolling the Connection
## =========================================================================

func test_the_main_roll_routes_to_the_right_subtable() -> void:
	if not _enable():
		return
	var routes := {1: 1, 2: 1, 3: 2, 4: 3, 5: 4, 6: 5}
	for main_roll in routes.keys():
		var record: Dictionary = Connections.roll_connection(_campaign(), 1, main_roll, 1)
		assert_int(int(record.get("subtable", 0))).override_failure_message(
			"D6 = %d must route to subtable %d" % [main_roll, routes[main_roll]]
		).is_equal(routes[main_roll])


func test_the_connection_persists_as_a_pending_offer() -> void:
	if not _enable():
		return
	var campaign := _campaign()
	var record: Dictionary = Connections.roll_connection(campaign, 4, 1, 1)
	assert_str(str(record["id"])).is_equal("old_friend_trouble")
	var pending: Dictionary = Connections.get_pending(campaign)
	assert_str(str(pending.get("id", ""))).is_equal("old_friend_trouble")
	assert_int(int(pending.get("offered_on_turn", -1))).is_equal(4)


func test_the_variety_swap_is_off_by_default_and_repeats_are_allowed() -> void:
	## The designer note is explicitly a preference ("If you prefer to maintain
	## variety"), so the main line must keep rolling the same result.
	if not _enable():
		return
	var campaign := _campaign()
	Connections.roll_connection(campaign, 1, 1, 1)
	Connections.resolve_pending(campaign, false)
	var second: Dictionary = Connections.roll_connection(campaign, 2, 1, 1)
	assert_str(str(second["id"])).is_equal("old_friend_trouble")


func test_the_variety_swap_takes_the_first_new_result_in_the_same_subtable() -> void:
	## p.81 designer note, verbatim: "swap a result you have already had this
	## campaign for THE FIRST NEW RESULT IN THE SAME SUBTABLE." A walk down the
	## printed order, not a re-roll.
	if not _enable():
		return
	_set_options(false, true)
	var campaign := _campaign()
	Connections.roll_connection(campaign, 1, 1, 1)      # subtable 1 row 1
	Connections.resolve_pending(campaign, false)
	var second: Dictionary = Connections.roll_connection(campaign, 2, 1, 1)
	assert_str(str(second["id"])).override_failure_message(
		"a seen result must be swapped for the next unseen row"
	).is_equal("associate_data_cache")
	assert_str(str(second.get("variety_swapped_from", ""))).is_equal("old_friend_trouble")


func test_the_variety_swap_stays_inside_the_same_subtable() -> void:
	if not _enable():
		return
	_set_options(false, true)
	var campaign := _campaign()
	# Fill subtable 1 rows 1 and 2, then roll row 1 again.
	Connections.roll_connection(campaign, 1, 1, 1)
	Connections.resolve_pending(campaign, false)
	Connections.roll_connection(campaign, 1, 1, 2)
	Connections.resolve_pending(campaign, false)
	var third: Dictionary = Connections.roll_connection(campaign, 2, 1, 1)
	assert_int(int(third["subtable"])).is_equal(1)
	assert_str(str(third["id"])).is_equal("favor_owed")


## =========================================================================
## Declining and expiry (p.81)
## =========================================================================

func test_a_starred_event_can_be_turned_down() -> void:
	if not _enable():
		return
	var campaign := _campaign()
	Connections.roll_connection(campaign, 1, 1, 1)  # 1-1 is marked *
	var out: Dictionary = Connections.resolve_pending(campaign, true)
	assert_bool(bool(out.get("declined", false))).is_true()
	assert_bool(Connections.get_pending(campaign).is_empty()).override_failure_message(
		"a declined Connection is spent: 'fight a random Opportunity mission "
		+ "WITHOUT generating a Connection for it'").is_true()


func test_an_unstarred_event_cannot_be_turned_down() -> void:
	if not _enable():
		return
	var campaign := _campaign()
	Connections.roll_connection(campaign, 1, 1, 2)  # 1-2 has no *
	assert_bool(Connections.resolve_pending(campaign, true).is_empty()).is_true()
	assert_bool(Connections.get_pending(campaign).is_empty()).override_failure_message(
		"the offer must still stand after a refused decline").is_false()


func test_the_offer_survives_the_next_turn_and_lapses_after() -> void:
	## p.81: "Seize any opportunity immediately next campaign turn, or the option
	## disappears."
	if not _enable():
		return
	var campaign := _campaign()
	Connections.roll_connection(campaign, 3, 1, 1)
	assert_bool(Connections.expire_stale(campaign, 3).is_empty()).is_true()
	assert_bool(Connections.expire_stale(campaign, 4).is_empty()).override_failure_message(
		"the offer is still live on the very next campaign turn").is_true()
	assert_bool(Connections.expire_stale(campaign, 5).is_empty()).override_failure_message(
		"the offer must be gone by the turn after next").is_false()
	assert_bool(Connections.get_pending(campaign).is_empty()).is_true()


func test_playing_the_mission_spends_the_offer() -> void:
	if not _enable():
		return
	var campaign := _campaign()
	Connections.roll_connection(campaign, 1, 1, 1)
	var out: Dictionary = Connections.resolve_pending(campaign, false)
	assert_str(str(out.get("id", ""))).is_equal("old_friend_trouble")
	assert_bool(bool(out.get("declined", true))).is_false()
	assert_bool(Connections.get_pending(campaign).is_empty()).is_true()


func test_the_mission_stamp_carries_the_instruction() -> void:
	if not _enable():
		return
	var campaign := _campaign()
	Connections.roll_connection(campaign, 1, 6, 3)
	var stamp: Dictionary = Connections.mission_stamp(campaign)
	assert_str(str(stamp.get("connection_id", ""))).is_equal("stolen_heirloom")
	assert_int(int(stamp.get("connection_subtable", 0))).is_equal(5)
	assert_str(str(stamp.get("connection_instruction", ""))).is_not_empty()


## =========================================================================
## Anti-regression: the wires themselves
## =========================================================================

func test_the_check_runs_in_mission_prep() -> void:
	## p.80 puts it "while establishing the objectives and parameters", which is
	## this step and no other.
	var code: String = _code_only(PREP_SRC)
	assert_str(code).contains("_check_for_connection()")
	assert_str(code).contains("ExpandedConnectionsRef.roll_connection(")
	assert_str(code).override_failure_message(
		"the no-roll option needs the negative branch recorded too"
	).contains("ExpandedConnectionsRef.note_no_connection(")


func test_the_decline_control_exists_for_starred_events() -> void:
	var code: String = _code_only(PREP_SRC)
	assert_str(code).contains("_on_decline_connection_pressed")
	assert_str(code).contains("decline_allowed")


func test_the_expiry_runs_at_turn_rollover() -> void:
	var code: String = _code_only(PHASE_MGR_SRC)
	assert_str(code).contains("_expire_stale_connection(campaign)")
	assert_str(code).contains("ExpandedConnectionsRef.expire_stale(")


func test_playing_the_mission_clears_it_from_the_post_battle_side() -> void:
	## A subsystem function with no caller is the defect this whole sprint is
	## about, so assert the call site, not just the definition.
	assert_str(_code_only(COMPLETION_SRC)).contains("func resolve_connection")
	assert_str(_code_only(POST_BATTLE_SRC)).contains("_completion.resolve_connection(_ctx)")
