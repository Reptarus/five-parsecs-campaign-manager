extends GdUnitTestSuite
## Sprint 7b BS3: a Hit is resolved in the battle's own book.
##
## THE DEFECT THIS PINS. The battle screen's hit sheet applied Core Rules p.46 in every
## mode: total >= Toughness or a natural 6 was a casualty, anything else a Stun, and a
## save still Stunned. Bug Hunt p.178 Wounds on a roll EQUAL to Toughness (a second Wound
## is a casualty) and a save knocks back without Stunning. Planetfall pp.37-38 knocks a
## figure Sprawling on an equal roll, takes a Kill Point before a casualty, and a save
## negates the Hit. Neither book has the natural-6 rule or Luck, and Planetfall never
## knocks a figure out on Stun markers.

const Calc := preload("res://src/core/battle/BattleCalculations.gd")
const SheetScript := preload("res://src/ui/components/battle/HitResolutionSheet.gd")
const TacticalBattleScene := preload("res://src/ui/screens/battle/TacticalBattleUI.tscn")
const TBUIScript := preload("res://src/ui/screens/battle/TacticalBattleUI.gd")
const SaveDirGuard := preload("res://tests/fixtures/helpers/save_dir_guard.gd")

var _user_state: Dictionary
var _dm: Node
var _save_calls: int = 0


func before_test() -> void:
	_user_state = SaveDirGuard.snapshot()
	_dm = get_tree().root.get_node_or_null("/root/DiceManager")
	_save_calls = 0


func after_test() -> void:
	if _dm != null:
		_dm.clear_forced_results()
	SaveDirGuard.restore(_user_state)


func _die(v: int) -> Callable:
	return func() -> int: return v


func _counting_save(v: int) -> Callable:
	return func() -> int:
		_save_calls += 1
		return v


func _hit(mode: String, dmg: int, t: int, save: int, save_roll: int, roll: int,
		state: Dictionary = {}) -> Dictionary:
	return Calc.resolve_hit_for_mode(mode, dmg, t, save, _die(save_roll), _die(roll), state)


# ── the rule, per book ─────────────────────────────────────────────────────────

func test_core_rules_p46_is_unchanged() -> void:
	assert_str(str(_hit("core", 0, 4, 0, 0, 4).result)).is_equal("down")
	assert_str(str(_hit("core", 0, 8, 0, 0, 6).result)).is_equal("down")
	assert_bool(bool(_hit("core", 0, 8, 0, 0, 6).natural_6)).is_true()
	assert_str(str(_hit("core", 0, 4, 0, 0, 3).result)).is_equal("stun")
	var saved := _hit("core", 0, 4, 5, 5, 6)
	assert_bool(bool(saved.saved)).is_true()
	assert_str(str(saved.result)).override_failure_message(
		"p.46: a deflected Hit still leaves the figure Stunned").is_equal("stun")


func test_bug_hunt_p178_wounds_on_an_equal_roll() -> void:
	assert_str(str(_hit("bug_hunt", 0, 4, 0, 0, 5).result)).is_equal("down")
	assert_str(str(_hit("bug_hunt", 0, 4, 0, 0, 4).result)).is_equal("wounded")
	assert_str(str(_hit("bug_hunt", 0, 4, 0, 0, 4, {"wounds": 1}).result)) \
		.override_failure_message("p.178: a second Wound is a casualty").is_equal("down")
	assert_str(str(_hit("bug_hunt", 0, 4, 0, 0, 3).result)).is_equal("stun")
	assert_str(str(_hit("bug_hunt", 0, 8, 0, 0, 6).result)).override_failure_message(
		"Bug Hunt has no natural-6 casualty").is_equal("stun")
	var saved := _hit("bug_hunt", 3, 3, 5, 5, 6)
	assert_str(str(saved.result)).override_failure_message(
		"p.178: a save means not Stunned, knocked back 1\"").is_equal("saved")


func test_planetfall_p37_sprawls_and_takes_kill_points() -> void:
	assert_str(str(_hit("planetfall", 0, 4, 0, 0, 4).result)).is_equal("sprawling")
	assert_str(str(_hit("planetfall", 0, 4, 0, 0, 5, {"kp": 1}).result)).is_equal("kp_lost")
	assert_str(str(_hit("planetfall", 0, 4, 0, 0, 5, {"kp": 0}).result)).is_equal("down")
	assert_str(str(_hit("planetfall", 0, 4, 0, 0, 3).result)).is_equal("stun")
	assert_str(str(_hit("planetfall", 0, 8, 0, 0, 6).result)).is_equal("stun")
	assert_str(str(_hit("planetfall", 3, 3, 5, 5, 6).result)).is_equal("saved")


func test_a_sprawling_figure_gets_no_save_and_loses_a_point_of_toughness() -> void:
	var out: Dictionary = Calc.resolve_hit_for_mode("planetfall", 0, 4, 5,
		_counting_save(6), _die(4), {"sprawling": true})
	assert_int(_save_calls).override_failure_message(
		"p.38: a Sprawling character foregoes any Saving Throw").is_equal(0)
	assert_int(int(out.toughness_used)).is_equal(3)
	assert_str(str(out.result)).is_equal("down")


# ── the sheet ──────────────────────────────────────────────────────────────────

func _declare_texts(sheet: Node) -> PackedStringArray:
	var out: PackedStringArray = []
	for choice: Array in sheet._declare_choices():
		out.append(str(choice[1]))
	return out


func test_the_sheet_offers_each_books_outcomes() -> void:
	var sheet: Node = auto_free(SheetScript.new())
	sheet.setup("Ash", 4, 0, false)
	assert_int(_declare_texts(sheet).size()).is_equal(2)
	sheet.setup("Ash", 4, 0, false, [], "", {"mode": "bug_hunt"})
	assert_str(" | ".join(_declare_texts(sheet))).contains("Wounded — knocked back 1\"") \
		.contains("Saved — knocked back 1\", not Stunned")
	sheet.setup("Ash", 4, 0, false, [], "", {"mode": "planetfall", "kp": 2})
	assert_str(" | ".join(_declare_texts(sheet))).contains("Lose 1 Kill Point (2 left)") \
		.contains("Knocked Sprawling")
	sheet.setup("Ash", 4, 0, false, [], "", {"mode": "planetfall", "sprawling": true})
	assert_str(" | ".join(_declare_texts(sheet))).not_contains("Saved")


func test_a_declared_second_wound_is_a_casualty() -> void:
	var sheet: Node = auto_free(SheetScript.new())
	sheet.setup("Ash", 4, 0, false, [], "", {"mode": "bug_hunt", "wounds": 1})
	var seen: Array = []
	sheet.hit_resolved.connect(func(o: Dictionary) -> void: seen.append(o))
	sheet._on_declared("wounded")
	assert_str(str(seen[0].result)).is_equal("down")


func test_the_sheet_rolls_through_dice_manager() -> void:
	assert_object(_dm).override_failure_message("premise: DiceManager autoload").is_not_null()
	var sheet: Node = auto_free(SheetScript.new())
	add_child(sheet)
	sheet.setup("Ash", 4, 1, false, [], "", {"mode": "bug_hunt"})
	_dm.queue_forced_result("Hit Resolution: damage", 4)
	sheet._on_roll_pressed()
	assert_str(str(sheet._pending.result)).is_equal("wounded")
	sheet._save_spin.value = 5
	_dm.queue_forced_result("Hit Resolution: save", 5)
	sheet._on_roll_pressed()
	assert_str(str(sheet._pending.result)).is_equal("saved")


# ── the battle screen ──────────────────────────────────────────────────────────

func _screen(mode: String) -> Control:
	var ui: Control = auto_free(TacticalBattleScene.instantiate())
	add_child(ui)
	await get_tree().process_frame
	ui._is_bug_hunt_mode = mode == "bug_hunt"
	ui._is_planetfall_mode = mode == "planetfall"
	return ui


func _unit(toughness: int = 4) -> Object:
	var u = TBUIScript.TacticalUnit.new()
	u.node_name = "Ash"
	u.toughness = toughness
	return u


func test_bug_hunt_two_wounds_make_a_casualty() -> void:
	var ui: Control = await _screen("bug_hunt")
	var u = _unit()
	ui._on_hit_resolved({"result": "wounded", "declared": true}, u, true)
	assert_int(int(u.wounds)).is_equal(1)
	assert_bool(bool(u.is_dead)).is_false()
	assert_int(int(u.stun_markers)).is_equal(0)
	ui._on_hit_resolved({"result": "wounded", "declared": true}, u, true)
	assert_bool(bool(u.is_dead)).is_true()


func test_planetfall_kill_points_go_before_the_figure() -> void:
	var ui: Control = await _screen("planetfall")
	var u = _unit()
	u.kill_points = 1
	ui._on_hit_resolved({"result": "kp_lost", "declared": true}, u, false)
	assert_int(int(u.kill_points)).is_equal(0)
	assert_bool(bool(u.is_dead)).is_false()
	assert_int(int(u.stun_markers)).override_failure_message(
		"p.38: Hits that remove KP do not cause a Stun").is_equal(0)


func test_planetfall_sprawling_recovers_after_the_next_activation() -> void:
	var ui: Control = await _screen("planetfall")
	var u = _unit()
	ui._on_hit_resolved({"result": "sprawling", "declared": true}, u, true)
	assert_bool(bool(u.is_sprawling)).is_true()
	ui._on_card_action("Ash", "generic_action", u)
	assert_bool(bool(u.is_sprawling)).is_false()


func test_planetfall_never_knocks_out_on_stun_markers() -> void:
	var ui: Control = await _screen("planetfall")
	var u = _unit()
	for i in range(4):
		ui._on_card_stun("Ash", u)
	assert_int(int(u.stun_markers)).is_equal(3)
	assert_bool(bool(u.is_knocked_out)).is_false()


func test_only_a_core_battle_spends_luck() -> void:
	var core_ui: Control = await _screen("core")
	var a = _unit()
	a.luck_remaining = 1
	core_ui._on_hit_resolved({"result": "down", "declared": true}, a, true)
	assert_bool(bool(a.is_dead)).override_failure_message(
		"premise: Core Rules p.46 Luck still saves a crew member").is_false()
	var bh_ui: Control = await _screen("bug_hunt")
	var b = _unit()
	b.luck_remaining = 1
	bh_ui._on_hit_resolved({"result": "down", "declared": true}, b, true)
	assert_bool(bool(b.is_dead)).is_true()
	assert_int(int(b.luck_remaining)).is_equal(1)


func test_the_hit_request_hands_the_sheet_the_battles_rules() -> void:
	var ui: Control = await _screen("bug_hunt")
	var u = _unit()
	u.wounds = 1
	ui._on_card_hit_requested("Ash", u, true)
	var sheet: Node = null
	for n in ui.find_children("*", "PanelContainer", true, false):
		if n.get_script() == SheetScript:
			sheet = n
	assert_object(sheet).override_failure_message("premise: the sheet opened").is_not_null()
	assert_str(str(sheet._mode)).is_equal("bug_hunt")
	assert_int(int(sheet._wounds)).is_equal(1)
