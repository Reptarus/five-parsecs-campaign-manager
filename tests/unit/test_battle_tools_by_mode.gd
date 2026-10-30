extends GdUnitTestSuite
## Sprint 7b BS5: the battle screen's Tools and Reference tabs follow the battle's book.
##
## THE DEFECTS THIS PINS.
## - Bug Hunt and Planetfall battles offered the Character Quick Roll, the Brawl Resolver
##   and the Core Rules weapon table, all of which work the Core Rules only.
## - The Combat Situation panel listed ten To Hit modifiers (Light Cover -1, Heavy Cover
##   -2, Elevated +1 and seven more) that are in neither book: Core Rules p.44 handles
##   cover through the row's number, not a modifier. Its wire into the calculator called a
##   method with no definition. The panel is deleted in every mode.
## - The Combat Calculator added a cover and a range spinner to a base of 3, hard-coded its
##   Damage mode to Damage 0 against Toughness 4, and printed a Brawling rule ("Damage +1")
##   and a Reaction rule ("1D6 + Reactions, higher acts first") the books do not have.
## - The Character Quick Roll took 1 off a Snap Fire shot. Core Rules p.113 has no such
##   modifier, and neither has the errata or Bug Hunt's p.198.

const TacticalBattleScene := preload("res://src/ui/screens/battle/TacticalBattleUI.tscn")
const AccordionScript := preload("res://src/ui/components/battle/AccordionToolContainer.gd")
const CalculatorScene := preload("res://src/ui/components/battle/CombatCalculator.tscn")
const QuickRollScript := preload("res://src/ui/components/battle/CharacterQuickRollPanel.gd")
const Sections := preload("res://src/ui/components/battle/CheatSheetSections.gd")
const CheatSheetScript := preload("res://src/ui/components/battle/CheatSheetPanel.gd")
const SaveDirGuard := preload("res://tests/fixtures/helpers/save_dir_guard.gd")

var _user_state: Dictionary


func before_test() -> void:
	_user_state = SaveDirGuard.snapshot()


func after_test() -> void:
	SaveDirGuard.restore(_user_state)


# ── the accordion ──────────────────────────────────────────────────────────────

func test_removing_a_section_frees_it_and_the_rest_still_toggle_their_own() -> void:
	var acc: Node = auto_free(AccordionScript.new())
	add_child(acc)
	var bodies: Array[Control] = []
	for title: String in ["A", "B", "C"]:
		var body := Label.new()
		bodies.append(body)
		acc.add_section(title, body, "about %s" % title)
	var a_header: Button = acc._section_headers[0]
	acc.remove_section(acc.find_section("A"))
	assert_int(acc.find_section("A")).is_equal(-1)
	assert_object(bodies[0].get_parent()).is_null()
	assert_object(a_header.get_parent()).is_null()
	acc._section_headers[0].pressed.emit()
	assert_bool(bodies[1].visible).override_failure_message(
		"the header now first must open its own section, B").is_true()
	assert_bool(bodies[2].visible).is_false()
	acc.remove_section(-1)
	assert_int(acc._section_titles.size()).is_equal(2)


# ── the battle screen ──────────────────────────────────────────────────────────

func _screen(mode: String) -> Control:
	var ui: Control = auto_free(TacticalBattleScene.instantiate())
	add_child(ui)
	await get_tree().process_frame
	ui._is_bug_hunt_mode = mode == "bug_hunt"
	ui._is_planetfall_mode = mode == "planetfall"
	ui._apply_rules_mode_to_tools()
	return ui


func test_a_core_battle_keeps_every_tool_but_the_situation_panel() -> void:
	var ui: Control = await _screen("core")
	assert_object(ui._tools_accordion).override_failure_message(
		"premise: the Tools accordion was built").is_not_null()
	assert_array(ui._tools_accordion._section_titles).contains_exactly(
		["Quick Dice Rolls", "Combat Calculator", "Character Quick Roll", "Brawl Resolver"])
	assert_object(ui.weapon_table_display).is_not_null()


func test_bug_hunt_and_planetfall_battles_drop_the_core_rules_tools() -> void:
	for mode: String in ["bug_hunt", "planetfall"]:
		var ui: Control = await _screen(mode)
		assert_array(ui._tools_accordion._section_titles).override_failure_message(
			"%s battle" % mode).contains_exactly(["Quick Dice Rolls", "Combat Calculator"])
		assert_object(ui.character_quick_roll).is_null()
		assert_object(ui.brawl_resolver).is_null()
		assert_object(ui.weapon_table_display).is_null()
		assert_str(str(ui.combat_calculator._rules_mode)).is_equal(mode)


# ── the calculator ─────────────────────────────────────────────────────────────

func _calculator(mode: String) -> Node:
	var calc: Node = auto_free(CalculatorScene.instantiate())
	add_child(calc)
	calc.set_rules_mode(mode)
	return calc


func _shot_texts(calc: Node) -> PackedStringArray:
	var out: PackedStringArray = []
	for i in calc.shot_option.item_count:
		out.append(calc.shot_option.get_item_text(i))
	return out


func test_the_calculator_lists_the_to_hit_rows_each_book_prints() -> void:
	var core: Node = _calculator("core")
	assert_str(" | ".join(_shot_texts(core))).override_failure_message(
		"errata v1.06 adds the covered-within-6\" row to the Core Rules") \
		.contains("Within 6\" and in Cover: 5+")
	assert_int(core.shot_option.item_count).is_equal(4)
	for mode: String in ["bug_hunt", "planetfall"]:
		var calc: Node = _calculator(mode)
		assert_int(calc.shot_option.item_count).override_failure_message(
			"%s prints three rows" % mode).is_equal(3)
		assert_str(" | ".join(_shot_texts(calc))).not_contains("Within 6\" and in Cover")


func _capture(calc: Node) -> Array:
	var seen: Array = []
	calc.calculation_completed.connect(func(_t: String, r: Dictionary) -> void: seen.append(r))
	return seen


func test_the_calculators_to_hit_says_what_the_die_needs() -> void:
	var calc: Node = _calculator("bug_hunt")
	var seen := _capture(calc)
	calc.attacker_combat.value = 1
	calc.shot_option.selected = 1
	calc._calculate_to_hit()
	assert_int(int(seen[0].target_number)).is_equal(5)
	assert_int(int(seen[0].die_needed)).is_equal(4)
	assert_int(int(seen[0].hit_faces)).is_equal(3)


func test_the_calculators_damage_follows_each_books_hit_table() -> void:
	var expected := {
		"core": {"down": 3, "stun": 3},
		"bug_hunt": {"down": 2, "wounded": 1, "stun": 3},
		"planetfall": {"down": 2, "sprawling": 1, "stun": 3},
	}
	for mode: String in expected:
		var calc: Node = _calculator(mode)
		var seen := _capture(calc)
		calc.weapon_damage.value = 0
		calc.target_toughness.value = 4
		calc._calculate_damage()
		assert_dict(seen[0].outcomes).override_failure_message(
			"%s: 1D6+0 against Toughness 4" % mode).is_equal(expected[mode])


# ── the quick roll ─────────────────────────────────────────────────────────────

func test_a_snap_fire_shot_takes_no_to_hit_penalty() -> void:
	var panel: Node = auto_free(QuickRollScript.new())
	add_child(panel)
	# The die comes from DiceManager ("Quick Roll"). The panel's own RNG is seeded to
	# roll something else, so a panel that ignored DiceManager fails here every time.
	var seed_not_three := -1
	for s in range(1, 500):
		var probe := RandomNumberGenerator.new()
		probe.seed = s
		if probe.randi_range(1, 6) != 3:
			seed_not_three = s
			break
	assert_int(seed_not_three).is_greater(0)
	var dm: Node = get_tree().root.get_node_or_null("/root/DiceManager")
	assert_object(dm).override_failure_message("premise: DiceManager").is_not_null()
	dm.clear_forced_results()
	dm.queue_forced_result("Quick Roll", 3)
	panel._selected_character = {"name": "Ash", "combat": 0, "is_holding_snap": true}
	panel._cover_check.button_pressed = false
	panel._range_spin.value = 3
	panel._rng.seed = seed_not_three
	panel._execute_hit_roll()
	dm.clear_forced_results()
	assert_int(int(panel._last_result.roll)).override_failure_message(
		"the Quick Roll die did not come from DiceManager").is_equal(3)
	assert_int(int(panel._last_result.threshold)).is_equal(3)
	assert_bool(bool(panel._last_result.hit)).override_failure_message(
		"p.113: a 3 against 3+ hits whether or not the shot is Snap Fire").is_true()


# ── the reference tab ──────────────────────────────────────────────────────────

func test_the_planetfall_reference_lists_its_own_weapons() -> void:
	var body := ""
	for s: Dictionary in Sections.planetfall_sections():
		if str(s.title) == "Weapons (Planetfall pp.76-79)":
			body = str(s.content)
	assert_str(body).override_failure_message("the section exists").is_not_empty()
	assert_str(body).contains("[b]Flame Projector[/b]  6\" | Shots – | Damage +1") \
		.contains("[b]Bio-Gun[/b]  12\" | Shots Special | Damage +1") \
		.contains("[b]Carver Blade[/b]  Brawl | Shots – | Damage +2")


## The battle screen sweeps itself once; the sheet builds its sections later and inserts
## "This Battle" later still (TacticalBattleUI calls set_battle_context after setup). A
## Button is STOP by default, so each builder must open what it adds or a finger drag
## over the Reference tab dies on the section it lands on.
func test_the_this_battle_section_lets_a_drag_through() -> void:
	var sheet: Node = auto_free(CheatSheetScript.new())
	add_child(sheet)
	await get_tree().process_frame
	sheet.set_battle_context({"enemy_force": {"type": "Vent Crawlers", "count": 5}})
	var header: Control = sheet._vbox.get_node_or_null("_battle_header")
	var body: Control = sheet._vbox.get_node_or_null("_battle_body")
	assert_object(header).override_failure_message("premise: the section was inserted") 		.is_not_null()
	assert_int(header.mouse_filter).is_not_equal(Control.MOUSE_FILTER_STOP)
	assert_int(body.mouse_filter).is_not_equal(Control.MOUSE_FILTER_STOP)
