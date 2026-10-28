extends GdUnitTestSuite

## Compendium p.206 Military Life results are HONOURED, not only written (PB-2).
##
## ⚠ Before 2026-10-27 BugHuntPhaseManager wrote five flags into
## `military_life_modifiers` after every battle and nothing read any of them: a
## marine in the Brig still deployed, a reprimanded marine still took an assignment,
## a recommendation's +2 never reached a roll, special duties gave no bonus roll, and
## a friend in the Intel Corps never moved a Priority.
##
## Every flag here is written by the REAL producer (the phase manager's
## `military_life_flag` op, the one the post-battle resolver emits), so no case can
## pass against a hand-built shape the app never writes.

const CoreScript = preload("res://src/game/campaign/BugHuntCampaignCore.gd")
const PhaseManager = preload("res://src/core/campaign/BugHuntPhaseManager.gd")
const MissionPanel = preload("res://src/ui/screens/bug_hunt/panels/BugHuntMissionPanel.gd")
const AssignPanel = preload("res://src/ui/screens/bug_hunt/panels/SpecialAssignmentsPanel.gd")

const SaveDirGuard := preload("res://tests/fixtures/helpers/save_dir_guard.gd")
## The phase manager's persist() goes through GameState.save_campaign(), which also
## rewrites last_campaign: unguarded, the next process auto-loads this Bug Hunt core
## and a 5PFH suite reads its String difficulty (measured 2026-10-27, Sprint 3 gate).

var _dm: Node
var _user_state: Dictionary


func before_test() -> void:
	_user_state = SaveDirGuard.snapshot()
	_dm = get_tree().root.get_node_or_null("/root/DiceManager")


func after_test() -> void:
	if _dm != null:
		_dm.clear_forced_results()
	SaveDirGuard.restore(_user_state)


func _core() -> Resource:
	var core = CoreScript.new()
	core.campaign_name = "T"
	core.main_characters = [
		{"id": "a", "name": "Alpha", "equipment": ["service_pistol"], "reactions": 1,
			"combat_skill": 0, "speed": 4, "toughness": 3, "savvy": 0},
		{"id": "b", "name": "Bravo", "equipment": ["service_pistol"], "reactions": 1,
			"combat_skill": 0, "speed": 4, "toughness": 3, "savvy": 0}]
	return core


## Write a flag exactly as the post-battle step does.
func _flag(core: Resource, cid: String, flag: String, amount: int) -> void:
	var pm = PhaseManager.new()
	add_child(pm)
	auto_free(pm)
	pm.setup(core)
	pm._apply_post_battle_effect({"op": "military_life_flag", "target": cid,
		"flag": flag, "amount": amount, "cite": "Compendium p.206"})
	assert_int(core.military_life_flag(cid, flag)) \
		.override_failure_message("the producer did not write %s" % flag).is_equal(amount)


func _labels(root: Node) -> String:
	var text := ""
	for n in root.find_children("*", "Label", true, false):
		text += (n as Label).text + "\n"
	return text


func _mission(core: Resource, priority: int) -> Control:
	assert_object(_dm).is_not_null()
	for i in 3:
		_dm.queue_forced_result("Bug Hunt Objective: die %d" % (i + 1), i + 1)
	_dm.queue_forced_result("Bug Hunt Priority: die 1", priority)
	_dm.queue_forced_result("Bug Hunt Priority: die 2", 6)
	var panel: Control = MissionPanel.new()
	add_child(panel)
	auto_free(panel)
	panel.set_campaign(core)
	panel._generate_mission()
	return panel


func _assignments(core: Resource) -> Control:
	var panel: Control = AssignPanel.new()
	add_child(panel)
	auto_free(panel)
	panel.set_campaign(core)
	panel.refresh()
	return panel


# ── the mission: Brig / special duties, and the Intel Corps ──────────────────────

func test_a_marine_held_back_by_military_life_does_not_take_the_field() -> void:
	var core := _core()
	_flag(core, "a", "miss_next_mission", 1)
	var panel := _mission(core, 3)
	assert_array(panel._participant_ids).contains_exactly(["b"])
	assert_str(_labels(panel)).contains("Alpha misses this mission")
	panel._spend_military_life_flags()
	assert_int(core.military_life_flag("a", "miss_next_mission")) \
		.override_failure_message("p.206: the NEXT mission only").is_equal(0)


func test_a_friend_in_the_intel_corps_moves_the_next_priority() -> void:
	var core := _core()
	_flag(core, "a", "priority_modifier", -1)
	var panel := _mission(core, 4)
	assert_int(int(panel._mission_context.priority)).is_equal(3)
	assert_str(_labels(panel)).contains("-1 Priority, a friend in the Intel Corps")
	panel._spend_military_life_flags()
	assert_int(core.military_life_flag_total("priority_modifier")).is_equal(0)


# ── Special Assignments: reprimand, recommendation, special duties ───────────────

func test_a_reprimanded_marine_takes_no_assignment_this_turn() -> void:
	var core := _core()
	_flag(core, "a", "special_assignment_blocked", 1)
	var panel := _assignments(core)
	assert_int(panel.find_children("*", "OptionButton", true, false).size()) \
		.override_failure_message("only Bravo may pick an assignment").is_equal(1)
	assert_str(_labels(panel)).contains("Alpha (Reprimanded)")
	panel.complete()
	assert_int(core.military_life_flag("a", "special_assignment_blocked")) \
		.override_failure_message("p.206: the NEXT campaign turn only").is_equal(0)


func test_a_recommendation_adds_to_the_next_roll_once() -> void:
	var core := _core()
	core.main_characters = [core.main_characters[0]]
	_flag(core, "a", "special_assignment_bonus", 2)
	var panel := _assignments(core)
	var opts: Array = panel.find_children("*", "OptionButton", true, false)
	assert_int(opts.size()).is_equal(1)
	(opts[0] as OptionButton).select(1)
	var target: int = int(panel._assignments_data[(opts[0] as OptionButton).get_item_id(1) - 1]
		.get("target_2d6", 0))
	# Two dice summing to two below the target: a success only with the +2.
	_dm.queue_forced_result("Bug Hunt Special Assignment die 1", 1)
	_dm.queue_forced_result("Bug Hunt Special Assignment die 2", target - 3)
	panel._on_roll_all()
	assert_str(_labels(panel)).contains("+2 Military Life = %d vs %d" % [target, target])
	assert_str(str(panel._assignment_slots[0].result)).is_equal("success")
	assert_int(core.military_life_flag("a", "special_assignment_bonus")).is_equal(0)


func test_special_duties_give_a_bonus_assignment_roll() -> void:
	var core := _core()
	core.main_characters = [core.main_characters[0]]
	_flag(core, "a", "extra_special_assignment_rolls", 1)
	var panel := _assignments(core)
	assert_int(panel.find_children("*", "OptionButton", true, false).size()) \
		.override_failure_message("p.206: a bonus roll on the Special Assignments table") \
		.is_equal(2)
	panel.complete()
	assert_int(core.military_life_flag("a", "extra_special_assignment_rolls")).is_equal(0)
