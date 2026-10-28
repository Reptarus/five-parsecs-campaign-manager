extends GdUnitTestSuite

## Bug Hunt mission setup choices bind: Compendium pp.187-189 (MG-1, MG-2, MG-3, MG-4,
## MG-8, MG-9, MG-11).
##
## ⚠ Before 2026-10-27 the Reputation spends on p.187 were a label with nothing to
## press, the support result lived only in a label, the loadout dropdowns were never
## read, the "I'm too pretty to die" +2 and p.205's permanent +1 Support roll were not
## both counted, and every request button stayed enabled with no points left (the
## tablet walk recorded "12 requests enabled vs 1 point").
##
## Every case drives the REAL panel and reads what reaches the battle, because the
## defects all lived between a control and the payload, not inside a rule.

const MissionPanel = preload("res://src/ui/screens/bug_hunt/panels/BugHuntMissionPanel.gd")
const CoreScript = preload("res://src/game/campaign/BugHuntCampaignCore.gd")
const Setup = preload("res://src/core/battle/BugHuntBattleSetup.gd")
const Guide = preload("res://src/core/battle/BugHuntBattleGuide.gd")

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


## A panel whose mission is generated with Priority forced to `priority` and three
## different objective dice, so no objective is Vital or Critical (p.185).
func _panel(priority: int, reputation: int = 0, extra_rolls: int = 0,
		difficulty: String = "mess_me_up") -> Control:
	assert_object(_dm).override_failure_message("DiceManager autoload is required") \
		.is_not_null()
	var core = CoreScript.new()
	core.campaign_name = "T"
	core.reputation = reputation
	core.extra_support_rolls = extra_rolls
	core.difficulty = difficulty
	core.main_characters = [
		{"id": "a", "name": "Alpha", "equipment": ["service_pistol", "trooper_armor"]},
		{"id": "b", "name": "Bravo", "equipment": ["service_pistol", "trooper_armor"]}]
	for i in 3:
		_dm.queue_forced_result("Bug Hunt Objective: die %d" % (i + 1), i + 1)
	_dm.queue_forced_result("Bug Hunt Priority: die 1", priority)
	_dm.queue_forced_result("Bug Hunt Priority: die 2", 6)
	var panel: Control = MissionPanel.new()
	add_child(panel)
	auto_free(panel)
	panel.set_campaign(core)
	panel._generate_mission()
	# Instrument the premise: every forced roll was consumed, so the Priority below
	# is the one this case asked for and not a random one.
	assert_int(int(panel._mission_context.get("priority", -1))) \
		.override_failure_message("the forced Priority did not land").is_equal(priority)
	return panel


func _button(panel: Node, text: String) -> Button:
	for n in panel.find_children("*", "Button", true, false):
		if (n as Button).text == text:
			return n
	return null


func _points_text(panel: Node) -> String:
	return str(panel._support_points_lbl.text)


# ── MG-1: Reputation moves Priority, within p.187's limits ───────────────────────

func test_reputation_moves_priority_and_spawn_within_the_p187_limits() -> void:
	var panel := _panel(3, 3)
	var up := _button(panel, "Priority +1 (1 Reputation)")
	var down := _button(panel, "Priority -1 (1 Reputation)")
	assert_object(up).is_not_null()
	assert_object(down).is_not_null()
	up.pressed.emit()
	up.pressed.emit()
	assert_int(int(panel._mission_context.priority)).is_equal(5)
	assert_int(int(panel._mission_context.spawn_rating)) \
		.override_failure_message("p.187 Step 5: Spawn Rating is Priority -1, max 3") \
		.is_equal(3)
	assert_bool(up.disabled).is_true()
	# Emitting bypasses `disabled`, so this proves the HANDLER refuses a third point.
	up.pressed.emit()
	assert_int(int(panel._mission_context.priority)) \
		.override_failure_message("p.187: at most 2 Reputation may move Priority") \
		.is_equal(5)
	down.pressed.emit()
	assert_int(int(panel._mission_context.priority)).is_equal(4)
	assert_int(int(panel._campaign.reputation)) \
		.override_failure_message("nothing is spent until the mission launches") \
		.is_equal(3)
	panel._spend_committed_reputation()
	panel._spend_committed_reputation()
	assert_int(int(panel._campaign.reputation)) \
		.override_failure_message("one point committed, spent exactly once") \
		.is_equal(2)


# ── MG-2 / MG-3 / MG-4: every source of Support points counts ────────────────────

func test_support_points_count_every_p187_and_p205_source() -> void:
	# Priority 3, "I'm too pretty to die" +2 (p.187), Crippling blow +1 (p.205).
	var panel := _panel(3, 1, 1, "im_too_pretty_to_die")
	assert_str(_points_text(panel)).contains("Support Points: 6 left of 6")
	var buy := _button(panel, "Spend 1 Reputation: +1 Support Point")
	assert_object(buy).is_not_null()
	buy.pressed.emit()
	assert_str(_points_text(panel)).contains("Support Points: 7 left of 7")
	assert_bool(buy.disabled).override_failure_message("the only Reputation is committed") \
		.is_true()
	buy.pressed.emit()
	assert_str(_points_text(panel)).contains("7 left of 7")


# ── MG-11 + MG-8: requests stop at zero points, and the result reaches the battle ─

func test_requests_stop_at_zero_points_and_the_result_is_stamped() -> void:
	# Reputation 2 so the Priority lock below is the ONLY reason that button is
	# disabled; with none, the assertion would pass on the Reputation check alone.
	var panel := _panel(1, 2)
	var buttons: Array = panel._support_buttons
	assert_int(buttons.size()).is_greater(1)
	_dm.queue_forced_result("Bug Hunt Support die 1", 6)
	_dm.queue_forced_result("Bug Hunt Support die 2", 6)
	(buttons[0] as Button).pressed.emit()
	var stamped: Array = panel._mission_context.get("support", [])
	assert_int(stamped.size()).is_equal(1)
	assert_bool(bool(stamped[0].approved)).is_true()
	assert_int(int(stamped[0].roll)).is_equal(12)
	for i in range(1, buttons.size()):
		assert_bool((buttons[i] as Button).disabled) \
			.override_failure_message("request %d is pressable with 0 points left" % i) \
			.is_true()
	assert_bool(_button(panel, "Priority +1 (1 Reputation)").disabled) \
		.override_failure_message("p.187: Priority is fixed once support is rolled") \
		.is_true()
	(buttons[1] as Button).pressed.emit()
	assert_int((panel._mission_context.support as Array).size()).is_equal(1)
	var md: Dictionary = Setup.new().generate_battle_context(panel._mission_context)
	assert_str(str(Guide.briefing_rows(md))).contains("✓ %s" % stamped[0].name)


# ── MG-9: the loadout is stamped and reaches the battle's copy of the crew ────────

func test_the_loadout_is_stamped_and_reaches_the_battle_copy() -> void:
	var panel := _panel(3)
	var weapon_opts: Array = []
	for n in panel.find_children("*", "OptionButton", true, false):
		if (n as OptionButton).item_count > 0 \
				and (n as OptionButton).get_item_text(0).begins_with("Combat Rifle"):
			weapon_opts.append(n)
	assert_int(weapon_opts.size()).is_equal(2)
	assert_str(str(panel._mission_context.loadout.a.weapon)).is_equal("combat_rifle")
	(weapon_opts[0] as OptionButton).item_selected.emit(1)
	var cannon: CheckBox = null
	for n in panel.find_children("*", "CheckBox", true, false):
		if (n as CheckBox).text == "Hand Cannon swap":
			cannon = n
			break
	cannon.button_pressed = true
	var crew: Array = (panel._campaign.main_characters as Array).duplicate(true)
	panel._apply_loadout(crew)
	assert_array(crew[0].equipment).contains_exactly(
		["hand_cannon", "trooper_armor", "shotgun"])
	assert_array(crew[1].equipment).contains_exactly(
		["service_pistol", "trooper_armor", "combat_rifle"])
	assert_array(panel._campaign.main_characters[0].equipment) \
		.override_failure_message("p.187: the loadout is for this mission only") \
		.contains_exactly(["service_pistol", "trooper_armor"])
	var md: Dictionary = Setup.new().generate_battle_context(panel._mission_context)
	assert_str(str(Guide.briefing_rows(md))) \
		.contains("Alpha: Shotgun, Hand Cannon in place of the Service Pistol")


# ── MG-12 / MG-13: the p.187 Campaign escalation option ──────────────────────────

## An escalation campaign at `turn`, with the three objective dice forced. The Priority
## dice are NOT forced: escalation replaces the roll, so a forced value would never be
## consumed and would leak into the next suite that rolls Priority.
func _escalation_panel(turn: int, objective_dice: Array) -> Control:
	var core = CoreScript.new()
	core.campaign_name = "E"
	core.use_campaign_escalation = true
	core.campaign_turn = turn
	core.main_characters = [{"id": "a", "name": "Alpha", "equipment": []}]
	for i in 3:
		_dm.queue_forced_result("Bug Hunt Objective: die %d" % (i + 1), objective_dice[i])
	var panel: Control = MissionPanel.new()
	add_child(panel)
	auto_free(panel)
	panel.set_campaign(core)
	panel._generate_mission()
	return panel


## MG-12, CONFIRMED: p.187 "instead of rolling, you will use the following Priority
## Ratings" replaces the ROLL only. The Vital/Critical sentence is its own paragraph,
## so a Vital Objective still adds +1 to the escalation rating.
func test_a_vital_objective_still_raises_an_escalation_rating() -> void:
	var panel := _escalation_panel(3, [1, 1, 2])
	assert_int(int(panel._mission_context.escalation_step)).is_equal(2)
	assert_int(int(panel._mission_context.priority)) \
		.override_failure_message("p.187: rating 2 for mission 3, +1 for the Vital").is_equal(3)


## MG-13: p.187 prints eight ratings, 1-1-2-2-3-4-5-6, for a campaign that "slowly
## escalates". Mission 9 holds at the last one rather than dropping back to 1.
func test_the_escalation_sequence_holds_at_its_last_rating() -> void:
	var panel := _escalation_panel(9, [1, 2, 3])
	assert_int(int(panel._mission_context.escalation_step)).is_equal(7)
	assert_int(int(panel._mission_context.priority)).is_equal(6)
	assert_int(int(panel._mission_context.spawn_rating)) \
		.override_failure_message("p.187: the escalation Spawn Ratings end at 3").is_equal(3)
