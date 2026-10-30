extends GdUnitTestSuite
## Sprint 7b BS2: Battle Events (Core Rules pp.116-117) roll in a Core Rules battle only.
##
## THE DEFECT THIS PINS. The end of Rounds 2 and 4 announced a Battle Event in every
## battle mode: the round tracker's signal, the End Phase checklist step and the round
## HUD all fired in Bug Hunt and Planetfall battles, and neither book has the table.
## The HUD's End Phase prompt also asked a Bug Hunt player to roll Morale, which Bug Hunt
## does not have (p.200), and a Planetfall player to roll it at the end of the round,
## where Planetfall tests Panic as each enemy falls (p.40).

const TacticalBattleScene := preload("res://src/ui/screens/battle/TacticalBattleUI.tscn")
const HudScript := preload("res://src/ui/components/battle/BattleRoundHUD.gd")
const SaveDirGuard := preload("res://tests/fixtures/helpers/save_dir_guard.gd")

var _user_state: Dictionary


class RoundStub extends Node:
	var round_number: int = 2
	func get_current_round() -> int:
		return round_number


func before_test() -> void:
	_user_state = SaveDirGuard.snapshot()


func after_test() -> void:
	SaveDirGuard.restore(_user_state)


func _screen(mode: String) -> Control:
	var ui: Control = auto_free(TacticalBattleScene.instantiate())
	add_child(ui)
	await get_tree().process_frame
	ui._is_bug_hunt_mode = mode == "bug_hunt"
	ui._is_planetfall_mode = mode == "planetfall"
	return ui


func _labels(node: Node) -> String:
	var out := ""
	for n in node.find_children("*", "", true, false):
		if n is Label or n is Button:
			out += str(n.text) + "\n"
		elif n is RichTextLabel:
			out += str(n.text) + "\n"
	return out


func test_only_a_core_battle_rolls_battle_events() -> void:
	for mode: String in ["core", "bug_hunt", "planetfall"]:
		var ui: Control = await _screen(mode)
		assert_bool(ui._battle_events_apply()).override_failure_message(
			"%s battle" % mode).is_equal(mode == "core")


func test_the_end_phase_checklist_has_no_battle_event_outside_the_core_rules() -> void:
	for mode: String in ["core", "planetfall"]:
		var ui: Control = await _screen(mode)
		var stub := RoundStub.new()
		auto_free(stub)
		ui.round_tracker = stub
		ui._battle_context = {"deployment": {}}
		var checklist: Control = auto_free(ui._build_end_phase_checklist())
		var text := _labels(checklist)
		assert_str(text).override_failure_message("premise: the Round 2 checklist built") \
			.contains("END OF ROUND 2")
		if mode == "core":
			assert_str(text).contains("Battle Event")
		else:
			assert_str(text).not_contains("Battle Event")


func _live_feed(ui: Control) -> String:
	if ui.unified_log == null:
		return ""
	return str(ui.unified_log._live_feed.get_parsed_text())


func test_a_bug_hunt_event_trigger_does_nothing() -> void:
	# The handler logs before its tier check, so the log is where an ungated trigger
	# shows up even on a LOG_ONLY screen. The core arm proves the probe can see it.
	var core: Control = await _screen("core")
	core._on_battle_event_triggered(2, "random_event")
	assert_str(_live_feed(core)).override_failure_message(
		"premise: a core trigger reaches the battle log").contains("BATTLE EVENT")
	var ui: Control = await _screen("bug_hunt")
	var before: int = ui._battle_event_fired_this_round
	ui._on_battle_event_triggered(2, "random_event")
	ui._check_pending_battle_event()
	assert_int(ui._battle_event_fired_this_round).is_equal(before)
	assert_str(_live_feed(ui)).not_contains("BATTLE EVENT")
	assert_bool(ui.event_resolution != null and ui.event_resolution.is_visible_in_tree()) \
		.is_false()


func _hud(mode: String) -> Node:
	var hud: Node = auto_free(HudScript.new())
	add_child(hud)
	hud.set_display_tier(1)
	hud.set_rules_mode(mode)
	hud._current_round = 2
	hud._current_phase = 4
	hud._casualties_this_round = 2
	hud._update_reminder_text()
	hud._check_battle_event_indicator()
	return hud


func test_the_round_hud_follows_the_battles_book() -> void:
	var core: Node = _hud("core")
	assert_str(core._auto_prompt_label.text).override_failure_message(
		"premise: the core prompt still asks for both").contains("Battle Event") \
		.contains("Morale")
	assert_bool(core._event_indicator.visible).is_true()
	var bh: Node = _hud("bug_hunt")
	assert_str(bh._auto_prompt_label.text).not_contains("Battle Event") \
		.not_contains("Morale: roll").contains("No morale in Bug Hunt (p.200)")
	assert_str(bh._reminder_label.text).contains("Spawn Points (p.199)")
	assert_bool(bh._event_indicator.visible).is_false()
	var pf: Node = _hud("planetfall")
	assert_str(pf._auto_prompt_label.text).not_contains("Battle Event") \
		.contains("Panic is tested as each Tactical enemy falls")
