extends GdUnitTestSuite

## Planetfall pp.69-71, Step 17 Character Events.
##
## Until 2026-10-27 the Step 17 dialog applied six of the twenty rows itself and printed
## the other fourteen: R&R took nobody off world, a Dispute bound nothing at Lock and Load,
## Personal reflection doubled no XP, Personal tragedy forfeited none, an Accident that
## rolled Dead killed the character instead of putting them in Sick Bay for 5 turns, and a
## Change of assignment transferred nobody. PlanetfallCharacterEvents now decides and the
## phase manager applies; these cases pin each hop where the result lands.
##
## The phase manager saves on every applied op and an accepted transfer writes to
## user://transfers/, so the save guard is mandatory and every transfer file is deleted.

const CoreScript = preload("res://src/game/campaign/PlanetfallCampaignCore.gd")
const PMScript = preload("res://src/core/campaign/PlanetfallPhaseManager.gd")
const EventsScript = preload("res://src/core/systems/PlanetfallCharacterEvents.gd")
const SimpleDialog = preload("res://src/ui/screens/planetfall/panels/PlanetfallSimpleDialog.gd")
const LockAndLoad = preload(
	"res://src/ui/screens/planetfall/panels/PlanetfallLockAndLoadPanel.gd")
const PostBattlePanel = preload(
	"res://src/ui/screens/planetfall/panels/PlanetfallPostBattlePanel.gd")
const ColonyEvents = preload(
	"res://src/ui/screens/planetfall/panels/PlanetfallColonyEventsPanel.gd")
const SaveDirGuard := preload("res://tests/fixtures/helpers/save_dir_guard.gd")
const Phase = PMScript.Phase

var _user_state: Dictionary
var _saved_campaign: Variant
var _dm: Node
var _transfers: Array = []


func before_test() -> void:
	_user_state = SaveDirGuard.snapshot()
	var gs := get_tree().root.get_node_or_null("/root/GameState")
	_saved_campaign = gs.current_campaign if gs else null
	_dm = get_tree().root.get_node_or_null("/root/DiceManager")
	_transfers = []


func after_test() -> void:
	if _dm != null:
		_dm.clear_forced_results()
	for path in _transfers:
		if FileAccess.file_exists(str(path)):
			DirAccess.remove_absolute(str(path))
	var gs := get_tree().root.get_node_or_null("/root/GameState")
	if gs:
		gs.current_campaign = _saved_campaign
	SaveDirGuard.restore(_user_state)


func _core() -> Resource:
	var core = CoreScript.new()
	core.colony_name = "Probe"
	core.game_phase = "active"
	core.campaign_turn = 3
	core.colony_morale = 0
	core.story_points = 0
	core.roster = [
		{"id": "c1", "name": "Ash", "class": "trooper", "xp": 0, "loyalty": "committed"},
		{"id": "c2", "name": "Kip", "class": "scientist", "xp": 0, "loyalty": "committed"},
	]
	return core


func _pm(core: Resource) -> Node:
	var pm: Node = PMScript.new()
	add_child(pm)
	auto_free(pm)
	pm.setup(core)
	return pm


func _pm_at(core: Resource, phase: int) -> Node:
	var pm := _pm(core)
	pm.start_new_turn()
	while pm.current_phase != phase:
		pm.complete_current_phase({})
	return pm


func _mount(script: GDScript) -> Control:
	var panel: Control = script.new()
	add_child(panel)
	auto_free(panel)
	return panel


func _dialog(core: Resource, pm: Node) -> Control:
	var panel := _mount(SimpleDialog)
	panel.set_campaign(core)
	panel.set_phase_manager(pm)
	panel.configure("character_event", pm.current_phase)
	panel.phase_completed.connect(pm.complete_current_phase)
	panel.refresh()
	return panel


func _resolve(pm: Node, cid: String, roll: int) -> Dictionary:
	return EventsScript.new().resolve(pm.character_event_context(), cid, roll)


func _apply(pm: Node, receipt: Dictionary) -> void:
	pm.apply_character_event_ops(receipt.get("ops", []))


func _op_kinds(receipt: Dictionary) -> Array:
	var kinds: Array = []
	for op in receipt.get("ops", []):
		kinds.append(str(op.get("op", "")))
	return kinds


func _away(core: Resource, cid: String) -> void:
	core.set_character_note(cid, "away_until", int(core.campaign_turn) + 1)


func _force(key: String, values: Array) -> void:
	for v in values:
		_dm.queue_forced_result(key, v)


func _xp(core: Resource, cid: String) -> int:
	return int(core.get_roster_character_by_id(cid).get("xp", 0))


func _loyalty(core: Resource, cid: String) -> String:
	return str(core.get_roster_character_by_id(cid).get("loyalty", "")).to_lower()


## A roster row's text. On Lock and Load the name is the deploy CheckBox's own text
## (Sprint U made the whole name the tap target), so Buttons are read as well as Labels.
func _row_text(panel: Control, cid_name: String) -> String:
	for n in panel.find_children("*", "", true, false):
		if (n is Label or n is Button) and str(n.text).begins_with(cid_name):
			return str(n.text)
	return ""


# ── The resolver: every row of the pp.70-71 table has an effect ─────────────────

func test_every_row_of_the_table_produces_its_effect() -> void:
	var core := _core()
	core.tactical_enemies = [{"name": "Raiders"}]
	core.add_to_sick_bay("c1", 3)
	var pm := _pm(core)
	pm.set_battle_result({"won": true})
	# One roll inside each row, c1 in Sick Bay and the last mission won.
	var expected := {
		3: ["xp"],                          # Personal training
		8: ["loyalty_gain", "xp"],          # Minor promotion
		13: ["enemy_info"],                 # Personal investigation
		18: ["sick_bay_extend"],            # Something in the water
		23: ["recover_fully", "away"],      # R&R
		28: [],                             # Change of assignment (a choice)
		33: ["loyalty_loss"],               # Disputes with leadership
		38: ["loyalty_gain"],               # Commitment to the cause
		43: ["dispute"],                    # Dispute
		48: ["note"],                       # Personal calibrations
		53: ["injury"],                     # Sickness
		58: ["xp", "loyalty_gain", "xp", "loyalty_gain"],  # Making friends
		63: ["story_point_gain", "morale_adjust"],  # Personal life achievement
		68: ["reduce_recovery"],            # Excellent health
		73: ["injury"],                     # Accident
		78: ["note"],                       # Personal reflection
		83: ["loyalty_gain"],               # Personal conviction (mission won)
		88: [],                             # Losing faith (mission won: no change)
		93: ["note"],                       # Personal tragedy
		98: ["xp"],                         # New hobby
	}
	for roll in expected:
		if roll == 58:
			_force("Planetfall Friendship", [6, 6])
		if roll == 73:
			_force("Planetfall Injury", [50])
		var r := _resolve(pm, "c1", roll)
		assert_array(_op_kinds(r)).override_failure_message(
			"D100 %d (%s) produced %s" % [roll, str(r.event.get("id", "?")), str(_op_kinds(r))]) \
			.is_equal(expected[roll])
	var choice := _resolve(pm, "c1", 28)
	assert_str(str(choice.choice.get("kind", ""))).is_equal("change_of_assignment")


# ── R&R (p.70) ───────────────────────────────────────────────────────────────────

func test_r_and_r_heals_and_takes_the_character_off_world_for_two_turns() -> void:
	var core := _core()
	core.add_to_sick_bay("c1", 3)
	var pm := _pm(core)
	_apply(pm, _resolve(pm, "c1", 23))
	assert_bool(core.sick_bay.has("c1")) \
		.override_failure_message("p.70: they recover completely from any injuries").is_false()
	assert_bool(core.is_away("c1")).is_true()
	assert_str(core.deployment_block_reason("c1", "patrol")) \
		.override_failure_message("an off-world character was deployable").is_not_empty()
	assert_array(pm.character_event_context().away).contains(["c1"])
	core.campaign_turn += 2
	assert_bool(core.is_away("c1")).override_failure_message("gone for 2 campaign turns") \
		.is_true()
	core.campaign_turn += 1
	assert_bool(core.is_away("c1")).is_false()


func test_a_disloyal_character_who_rolls_1_or_2_on_r_and_r_does_not_return() -> void:
	var core := _core()
	core.roster[0]["loyalty"] = "disloyal"
	var pm := _pm(core)
	_force("Planetfall R&R Return", [2])
	_apply(pm, _resolve(pm, "c1", 23))
	assert_object(core.get_roster_character_by_id("c1")).is_null()


func test_a_disloyal_character_who_rolls_6_on_r_and_r_comes_back_committed() -> void:
	var core := _core()
	core.roster[0]["loyalty"] = "disloyal"
	var pm := _pm(core)
	_force("Planetfall R&R Return", [6])
	_apply(pm, _resolve(pm, "c1", 23))
	assert_str(_loyalty(core, "c1")).is_equal("committed")
	assert_bool(core.is_away("c1")).is_true()


func test_a_character_off_world_is_never_the_target_of_a_character_event() -> void:
	var core := _core()
	core.roster = [core.roster[0]]
	var pm := _pm_at(core, Phase.CHARACTER_EVENT)
	_away(core, "c1")
	var dlg := _dialog(core, pm)
	_force("Planetfall Step 17 Event", [3])
	dlg.complete()
	assert_int(_xp(core, "c1")) \
		.override_failure_message("p.69: an absent character cannot be the target of events") \
		.is_equal(0)


func test_an_off_world_character_is_not_offered_to_a_colony_event() -> void:
	var core := _core()
	_away(core, "c2")
	var panel: Control = _mount(ColonyEvents)
	panel.set_campaign(core)
	panel.refresh()
	_force("Planetfall Colony Event", [68])  # Report on progress: pick a character
	panel.complete()
	var offered: Array = []
	for i in range(panel._choice_pick.item_count):
		if panel._choice_pick.get_item_metadata(i) != null:
			offered.append(str(panel._choice_pick.get_item_metadata(i)))
	assert_array(offered).is_equal(["c1"])


func test_an_off_world_character_misses_the_colony_training_xp() -> void:
	var core := _core()
	_away(core, "c2")
	var panel: Control = _mount(ColonyEvents)
	panel.set_campaign(core)
	panel.refresh()
	_force("Planetfall Colony Event", [53])  # New training program: +1 XP to all
	panel.complete()
	assert_int(_xp(core, "c1")).is_equal(1)
	assert_int(_xp(core, "c2")).is_equal(0)


func test_an_off_world_character_cannot_catch_the_colony_virus() -> void:
	var core := _core()
	_away(core, "c2")
	var panel: Control = _mount(ColonyEvents)
	panel.set_campaign(core)
	panel.refresh()
	# On world only c1 rolls (1: infected), and nobody is left to spread to. Were c2
	# rolled, its 6 would leave it the spread target and the second 1 would infect it.
	_force("Planetfall Virus Infection", [1, 6, 1])
	_force("Planetfall Virus Recovery", [2, 2])
	_force("Planetfall Colony Event", [78])  # Hostile virus
	panel.complete()
	assert_int(int(core.sick_bay.get("c1", 0))).is_equal(2)
	assert_bool(core.sick_bay.has("c2")).is_false()


# ── Dispute (p.70) ───────────────────────────────────────────────────────────────

func test_a_dispute_keeps_the_pair_off_next_turns_mission_unless_pitched() -> void:
	var core := _core()
	var pm := _pm(core)
	_apply(pm, _resolve(pm, "c1", 43))
	assert_str(core.deployment_conflict("c2", ["c1"], "patrol")) \
		.override_failure_message("the dispute is for NEXT turn's mission").is_empty()
	core.campaign_turn += 1
	assert_str(core.deployment_conflict("c2", ["c1"], "patrol")).contains("Ash")
	assert_str(core.deployment_conflict("c2", ["c1"], "pitched_battle")).is_empty()


func test_lock_and_load_refuses_the_second_character_of_a_dispute() -> void:
	var core := _core()
	core.add_dispute("c1", "c2", int(core.campaign_turn))
	var panel: Control = _mount(LockAndLoad)
	panel.set_campaign(core)
	panel.set_mission_context({"selected_mission": {"id": "patrol"}})
	panel.refresh()
	(panel._deploy_checks["c1"] as CheckBox).button_pressed = true
	(panel._deploy_checks["c2"] as CheckBox).button_pressed = true
	assert_bool(panel._deployed.has("c2")) \
		.override_failure_message("both disputants were deployed").is_false()
	assert_bool((panel._deploy_checks["c2"] as CheckBox).button_pressed).is_false()
	assert_bool(panel._conflict_label.visible).is_true()
	assert_str(panel._conflict_label.text).contains("dispute")


func test_lock_and_load_lets_a_dispute_fight_a_pitched_battle_together() -> void:
	var core := _core()
	core.add_dispute("c1", "c2", int(core.campaign_turn))
	var panel: Control = _mount(LockAndLoad)
	panel.set_campaign(core)
	panel.set_mission_context({"selected_mission": {"id": "pitched_battle"}})
	panel.refresh()
	(panel._deploy_checks["c1"] as CheckBox).button_pressed = true
	(panel._deploy_checks["c2"] as CheckBox).button_pressed = true
	assert_bool(panel._deployed.has("c1") and panel._deployed.has("c2")).is_true()


func test_lock_and_load_names_the_character_event_results_to_remember() -> void:
	var core := _core()
	core.set_character_note("c1", "calibrated", true)
	core.set_character_note("c1", "double_xp", true)
	core.set_character_note("c2", "xp_forfeit_turn", int(core.campaign_turn))
	var panel: Control = _mount(LockAndLoad)
	panel.set_campaign(core)
	panel.set_mission_context({"selected_mission": {"id": "patrol"}})
	panel.refresh()
	assert_str(_row_text(panel, "Ash")).contains("+1 to hit").contains("Double XP")
	assert_str(_row_text(panel, "Kip")).contains("no XP")


# ── Making friends, Excellent health, Accident (pp.70-71) ───────────────────────

func test_making_friends_gives_both_xp_and_a_5_plus_a_level_of_loyalty() -> void:
	var core := _core()
	var pm := _pm(core)
	_force("Planetfall Friendship", [5, 4])
	_apply(pm, _resolve(pm, "c1", 58))
	assert_int(_xp(core, "c1")).is_equal(1)
	assert_int(_xp(core, "c2")).is_equal(1)
	assert_str(_loyalty(core, "c1")).is_equal("loyal")
	assert_str(_loyalty(core, "c2")).is_equal("committed")


func test_excellent_health_cuts_a_recovery_or_is_saved_for_the_next_injury() -> void:
	var core := _core()
	core.add_to_sick_bay("c2", 4)
	var pm := _pm(core)
	_apply(pm, _resolve(pm, "c2", 68))
	assert_int(int(core.sick_bay.get("c2", 0))).is_equal(2)
	_apply(pm, _resolve(pm, "c1", 68))
	assert_bool(bool(core.get_character_note("c1", "saved_health", false))).is_true()
	pm.apply_character_event_ops([{"op": "injury", "character_id": "c1", "turns": 4}])
	assert_int(int(core.sick_bay.get("c1", 0))) \
		.override_failure_message("p.71: the saved effect reduces the next injury by 2") \
		.is_equal(2)
	assert_bool(bool(core.get_character_note("c1", "saved_health", false))).is_false()


func test_an_accident_that_rolls_dead_is_five_turns_in_sick_bay() -> void:
	var core := _core()
	var pm := _pm(core)
	_force("Planetfall Injury", [10])
	_apply(pm, _resolve(pm, "c1", 73))
	assert_object(core.get_roster_character_by_id("c1")) \
		.override_failure_message("p.71: a Dead result becomes 5 turns of recovery") \
		.is_not_null()
	assert_int(int(core.sick_bay.get("c1", 0))).is_equal(5)


# ── Conviction and Losing faith follow the mission (p.71) ───────────────────────

func test_conviction_and_losing_faith_follow_the_turns_mission() -> void:
	var core := _core()
	var pm := _pm(core)
	pm.set_battle_result({"won": true})
	_apply(pm, _resolve(pm, "c1", 83))
	_apply(pm, _resolve(pm, "c2", 88))
	assert_str(_loyalty(core, "c1")).is_equal("loyal")
	assert_str(_loyalty(core, "c2")) \
		.override_failure_message("Losing faith on a successful mission changes nothing") \
		.is_equal("committed")
	pm.set_battle_result({"won": false})
	_apply(pm, _resolve(pm, "c2", 88))
	assert_str(_loyalty(core, "c2")).is_equal("disloyal")


# ── Notes that pay out at Step 10 (p.71) ────────────────────────────────────────

func test_personal_tragedy_forfeits_next_turns_xp_and_only_that_turn() -> void:
	var core := _core()
	var pm := _pm(core)
	_apply(pm, _resolve(pm, "c1", 93))
	assert_int(core.award_xp("c1", 2)).override_failure_message("this turn still pays") \
		.is_equal(2)
	core.campaign_turn += 1
	assert_int(core.award_xp("c1", 3)).is_equal(0)
	assert_int(_xp(core, "c1")).is_equal(2)
	core.campaign_turn += 1
	assert_int(core.award_xp("c1", 1)).is_equal(1)


func _step_10(core: Resource) -> Node:
	var pm := _pm(core)
	pm.stamp_mission({"id": "patrol", "mission_name": "Patrol Mission",
		"opposition_type": "tactical", "deployed_ids": ["c1", "c2"]})
	var by_id: Array = []
	for c in core.roster:
		by_id.append(c.duplicate())
	pm.set_battle_result({"won": true, "victory": true, "mission_type": "patrol",
		"crew_participants": by_id, "crew_injuries_data": [], "crew_casualties_data": []})
	var panel: Control = _mount(PostBattlePanel)
	panel.set_campaign(core)
	panel.set_phase_manager(pm)
	panel.set_battle_results(pm.get_battle_result())
	panel._current_sub_step = panel.SubStep.EXPERIENCE
	panel._resolve_experience()
	return pm


func test_personal_reflection_doubles_the_next_missions_xp_once() -> void:
	var core := _core()
	core.set_character_note("c2", "double_xp", true)
	core.set_character_note("c2", "calibrated", true)
	_step_10(core)
	assert_int(_xp(core, "c1")).is_greater(0)
	assert_int(_xp(core, "c2")).override_failure_message("p.71: double XP") \
		.is_equal(2 * _xp(core, "c1"))
	assert_bool(bool(core.get_character_note("c2", "double_xp", false))).is_false()
	assert_bool(bool(core.get_character_note("c2", "calibrated", false))) \
		.override_failure_message("the calibration lasts one mission").is_false()


func test_a_tragedy_turn_earns_no_xp_at_step_10() -> void:
	var core := _core()
	core.set_character_note("c2", "xp_forfeit_turn", int(core.campaign_turn))
	_step_10(core)
	assert_int(_xp(core, "c1")).is_greater(0)
	assert_int(_xp(core, "c2")).is_equal(0)


# ── Change of assignment (p.70) ──────────────────────────────────────────────────

func test_an_accepted_change_of_assignment_transfers_the_character() -> void:
	var core := _core()
	var pm := _pm_at(core, Phase.CHARACTER_EVENT)
	_away(core, "c2")
	var dlg := _dialog(core, pm)
	_force("Planetfall Step 17 Event", [28])
	dlg.complete()
	assert_bool(dlg.step_status().ready) \
		.override_failure_message("the step waits for the player's answer").is_false()
	dlg._decide_assignment(dlg._assignment_choices[0], true)
	var paths: Array = dlg._result_data.get("transfers", [])
	_transfers.append_array(paths)
	assert_int(paths.size()).is_equal(1)
	assert_bool(FileAccess.file_exists(str(paths[0]))).is_true()
	var envelope: Variant = JSON.parse_string(FileAccess.get_file_as_string(str(paths[0])))
	assert_str(str((envelope as Dictionary).get("target_mode", ""))).is_equal("five_parsecs")
	assert_object(core.get_roster_character_by_id("c1")) \
		.override_failure_message("the transferred character stayed on the roster").is_null()
	dlg.complete()
	assert_bool(pm.is_phase_complete(Phase.CHARACTER_EVENT)).is_true()


func test_an_unanswered_change_of_assignment_is_a_decline() -> void:
	var core := _core()
	var pm := _pm_at(core, Phase.CHARACTER_EVENT)
	_away(core, "c2")
	var dlg := _dialog(core, pm)
	_force("Planetfall Step 17 Event", [28])
	dlg.complete()
	dlg.complete()
	assert_object(core.get_roster_character_by_id("c1")).is_not_null()
	assert_str(_loyalty(core, "c1")) \
		.override_failure_message("p.70: if they decline, gain 1 level of Loyalty") \
		.is_equal("loyal")
	assert_bool(dlg._result_data.has("transfers")).is_false()
	assert_bool(pm.is_phase_complete(Phase.CHARACTER_EVENT)).is_true()


# ── Persistence ──────────────────────────────────────────────────────────────────

func test_character_notes_and_disputes_survive_a_save() -> void:
	var core := _core()
	core.set_character_note("c1", "away_until", 5)
	core.set_character_note("c2", "double_xp", true)
	core.add_dispute("c1", "c2", 4)
	var loaded = CoreScript.new()
	loaded.from_dictionary(core.to_dictionary())
	assert_int(int(loaded.get_character_note("c1", "away_until", -1))).is_equal(5)
	assert_bool(bool(loaded.get_character_note("c2", "double_xp", false))).is_true()
	assert_int(loaded.disputes.size()).is_equal(1)
	assert_str(str(loaded.disputes[0].get("b", ""))).is_equal("c2")
