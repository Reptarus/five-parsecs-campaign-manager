extends GdUnitTestSuite

## Tactics screens at phone size and at the touch floor (Sprint U, 2026-10-28).
##
## No sweep, capture or layout check had built a Tactics screen. The first captures found:
##
##   * the creation header (a non-wrapping title beside Cancel and a 70 px spacer) made
##     every wizard step wider than a phone, so the species Select buttons, the roster's
##     + Add and Launch Campaign were all off the right edge;
##   * the first screen read "Step 1 of 5" on a four-step wizard;
##   * Cancel, the species Select buttons and the turn screen's Dashboard button were
##     40 design px tall: 46.4 dp at the 1.16 effective scale, under the 48 dp floor.
##
## verify_layout measures only the wizard's FIRST step (a fresh instance shows Configuration),
## so the steps where the clipped buttons were are walked here, each driven by its panel.
## ⚠ The header case asserts the title's own width and line count as well: a wrapping Label
## reports a ~1 px minimum, and a title squeezed into a one-word column reads as "fits".

const CREATION_SCENE := "res://src/ui/screens/tactics/TacticsCreationUI.tscn"
const TURN_SCENE := "res://src/ui/screens/tactics/TacticsTurnController.tscn"
const DASHBOARD_SCENE := "res://src/ui/screens/tactics/TacticsDashboard.tscn"
const Populator := preload("res://tests/tools/screen_populator.gd")
const SaveDirGuard := preload("res://tests/fixtures/helpers/save_dir_guard.gd")

## The smallest phone verify_layout sweeps, in design px (360 x 640 physical).
const SMALL_PHONE := Vector2i(310, 551)
const TOUCH_FLOOR_DP := 48.0
const EPS := 0.5
const TITLE := "FIVE PARSECS: TACTICS"

var _user_state: Dictionary
var _saved_campaign: Variant = null


func before_test() -> void:
	_user_state = SaveDirGuard.snapshot()
	var gs := get_tree().root.get_node_or_null("/root/GameState")
	_saved_campaign = gs.current_campaign if gs else null


func after_test() -> void:
	var gs := get_tree().root.get_node_or_null("/root/GameState")
	if gs:
		gs.current_campaign = _saved_campaign
	SaveDirGuard.restore(_user_state)


func _find_label(root: Node, text: String) -> Label:
	for n in root.find_children("*", "Label", true, false):
		if (n as Label).text == text:
			return n
	return null


func _buttons_with_text(root: Node, text: String) -> Array:
	var out: Array = []
	for n in root.find_children("*", "Button", true, false):
		if (n as Button).text == text and (n as Button).is_visible_in_tree():
			out.append(n)
	return out


## Every visible button (and, when asked, every visible label) must lie inside the
## screen's width. Returns the offenders.
func _offenders(root: Node, width: float, with_labels := false) -> PackedStringArray:
	var bad := PackedStringArray()
	var kinds := ["Button", "Label"] if with_labels else ["Button"]
	for kind in kinds:
		for n in root.find_children("*", kind, true, false):
			var c := n as Control
			if not c.is_visible_in_tree() or str(c.get("text")).is_empty():
				continue
			var r: Rect2 = c.get_global_rect()
			if r.end.x > width + EPS or r.position.x < -EPS:
				bad.append("'%s' x=%.1f..%.1f" % [str(c.get("text")).left(40), r.position.x,
					r.end.x])
	return bad


## Step changes fade the old panel out over 0.15 s before showing the new one.
func _settle() -> void:
	await get_tree().create_timer(0.3).timeout
	for _i in range(3):
		await get_tree().process_frame


func _mount_creation_in_phone() -> Node:
	var sv := SubViewport.new()
	sv.size = SMALL_PHONE
	add_child(sv)
	auto_free(sv)
	var ui: Node = (load(CREATION_SCENE) as PackedScene).instantiate()
	sv.add_child(ui)
	await _settle()
	return ui


func test_the_first_screen_names_the_real_step_count() -> void:
	var ui: Node = (load(CREATION_SCENE) as PackedScene).instantiate()
	add_child(ui)
	auto_free(ui)
	await _settle()
	assert_str(ui._step_label.text).is_equal("Step 1 of %d: Configuration"
		% ui.coordinator.total_steps)
	assert_int(ui.coordinator.total_steps).is_equal(4)


func test_the_creation_title_wraps_inside_a_small_phone() -> void:
	var ui: Node = await _mount_creation_in_phone()
	var title: Label = _find_label(ui, TITLE)
	assert_object(title).is_not_null()
	var rect: Rect2 = title.get_global_rect()
	assert_float(rect.end.x).override_failure_message(
		"the title runs to x=%.1f on a %d px screen" % [rect.end.x, SMALL_PHONE.x]) \
		.is_less_equal(float(SMALL_PHONE.x) + EPS)
	assert_float(rect.size.x).override_failure_message(
		"the title is %.1f px wide, a column rather than a heading" % rect.size.x) \
		.is_greater(100.0)
	assert_int(title.get_line_count()).is_less_equal(2)


## Each step as a player reaches it, with its own controls filled in by its own panel.
func test_every_creation_step_fits_a_small_phone() -> void:
	var ui: Node = await _mount_creation_in_phone()
	var coord: Node = ui.coordinator
	var platoon: Array = Populator.TACTICS_PLATOON
	for step in range(4):
		coord.go_to_step(step)
		await _settle()
		var panel: Node = ui.panels[step]
		match step:
			0:
				panel._name_edit.text = "Fit check"
				panel._on_name_changed("Fit check")
			1:
				panel._on_species_selected("human_colonists")
			2:
				for unit_id in platoon:
					panel._add_unit_to_roster(unit_id)
			3:
				panel.refresh()
		await _settle()
		var bad := _offenders(ui, float(SMALL_PHONE.x))
		assert_int(bad.size()).override_failure_message(
			"step %d (%s): %d button(s) off a %d px phone: %s"
			% [step + 1, coord.get_step_name(step), bad.size(), SMALL_PHONE.x,
				", ".join(bad.slice(0, 4))]).is_equal(0)
	# The steps were reached with their own content, not skipped past empty.
	assert_int(_buttons_with_text(ui, "Launch Campaign").size()).is_equal(1)


## Each species card prints that species' own Military profile and what each Special Rule
## does. It used to print "12 units, 21 weapons" for every species, plus rule names alone.
func test_each_species_card_shows_its_own_profile_and_rules() -> void:
	var ui: Node = (load(CREATION_SCENE) as PackedScene).instantiate()
	add_child(ui)
	auto_free(ui)
	await _settle()
	ui.coordinator.go_to_step(1)
	await _settle()
	var panel: Node = ui.panels[1]
	var texts: Array = []
	for n in panel.find_children("*", "Label", true, false):
		texts.append((n as Label).text)
	var books: Dictionary = panel._species_books
	assert_int(books.size()).is_greater(10)
	var lines := {}
	for sid in books:
		var book = books[sid]
		var line: String = panel.military_line(book)
		if not line.is_empty():
			lines[line] = true
			assert_bool(texts.any(func(t): return String(t).contains(line))) \
				.override_failure_message("%s: its Military line is not on its card" % sid) \
				.is_true()
		for t in book.species.species_traits:
			if not String(t.description).is_empty():
				assert_bool(texts.has(t.description)).override_failure_message(
					"%s: '%s' is named without its rule text" % [sid, t.get_display_name()]) \
					.is_true()
	assert_int(lines.size()).override_failure_message(
		"only %d distinct Military lines across %d species" % [lines.size(), books.size()]) \
		.is_greater(5)
	# The taller cards must not stretch their Select buttons into slabs.
	var floor_px: float = float(load("res://src/ui/components/base/UIColors.gd").TOUCH_TARGET_MIN)
	for b in _buttons_with_text(panel, "Select"):
		assert_float((b as Button).size.y).override_failure_message(
			"a Select button is %.0f px tall on a %.0f px card"
			% [(b as Button).size.y, ((b as Button).get_parent() as Control).size.y]) \
			.is_less_equal(floor_px + EPS)
	# The numbers are the species file's, not a recomputation of them.
	var human: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(
		"res://data/tactics/species/human_colonists.json"))["profiles"]["military"]
	assert_str(panel.military_line(books["human_colonists"])).contains(
		"Speed %d\" · Reactions %d · Combat Skill %+d · Toughness %d · KP %d · Savvy %+d" % [
			int(human["speed"]), int(human["reactions"]), int(human["combat_skill"]),
			int(human["toughness"]), int(human["kp"]), int(human["savvy"])])


## A one-figure unit is "1 model", in the roster, the review and a unit's status line.
func test_counts_read_as_a_player_writes_them() -> void:
	var ui: Node = (load(CREATION_SCENE) as PackedScene).instantiate()
	add_child(ui)
	auto_free(ui)
	await _settle()
	ui.panels[1]._on_species_selected("human_colonists")
	ui.coordinator.go_to_step(2)
	await _settle()
	for unit_id in Populator.TACTICS_PLATOON:
		ui.panels[2]._add_unit_to_roster(unit_id)
	await _settle()
	ui.coordinator.go_to_step(3)
	ui.panels[3].refresh()
	await _settle()
	var singular := 0
	for step in [2, 3]:
		for n in (ui.panels[step] as Node).find_children("*", "Label", true, false):
			var t: String = (n as Label).text
			assert_bool(t.contains("1 models") or t.contains("1 units")) \
				.override_failure_message("step %d prints '%s'" % [step + 1, t]).is_false()
			if t.contains("1 model"):
				singular += 1
	assert_int(singular).override_failure_message(
		"no one-figure unit was shown, so the singular was never exercised").is_greater(1)
	var Unit = load("res://src/data/tactics/TacticsCampaignUnit.gd")
	assert_str(Unit.condition_text({"condition": "devastated", "unusable_battles": 1})) \
		.contains("1 battle until usable")
	assert_str(Unit.condition_text({"condition": "devastated", "unusable_battles": 2})) \
		.contains("2 battles until usable")


## The roster a player is building sits BESIDE the unit list on a tablet, and inside the
## 800 px form; in portrait it is one column and the header counts what was added.
func test_the_roster_sits_beside_the_unit_list_on_a_tablet() -> void:
	var rm := get_tree().root.get_node("/root/ResponsiveManager")
	var saved := [rm.current_breakpoint, rm.is_landscape]
	rm.current_breakpoint = rm.Breakpoint.TABLET
	rm.is_landscape = true
	var sv := SubViewport.new()
	sv.size = Vector2i(1280, 800)
	add_child(sv)
	auto_free(sv)
	var ui: Node = (load(CREATION_SCENE) as PackedScene).instantiate()
	sv.add_child(ui)
	await _settle()
	ui.panels[1]._on_species_selected("human_colonists")
	ui.coordinator.go_to_step(2)
	await _settle()
	var roster: Node = ui.panels[2]
	for unit_id in Populator.TACTICS_PLATOON:
		roster._add_unit_to_roster(unit_id)
	await _settle()
	var grid := roster.find_child("RosterColumns", true, false) as GridContainer
	assert_object(grid).is_not_null()
	assert_int(grid.columns).is_equal(2)
	var cols: Array = grid.get_children()
	assert_float(absf((cols[0] as Control).position.y - (cols[1] as Control).position.y)) \
		.override_failure_message("Your Roster is not beside Available Units").is_less(1.0)
	var form_right: float = (1280.0 + float(ui.MAX_FORM_WIDTH)) / 2.0
	var bad := _offenders(ui, form_right)
	assert_int(bad.size()).override_failure_message(
		"%d control(s) past the form's right edge (%.0f): %s"
		% [bad.size(), form_right, ", ".join(bad.slice(0, 4))]).is_equal(0)
	assert_str(roster._points_label.text).ends_with("· 5 units")
	rm.current_breakpoint = rm.Breakpoint.MOBILE
	rm.is_landscape = false
	roster._apply_columns()
	assert_int(grid.columns).is_equal(1)
	rm.current_breakpoint = saved[0]
	rm.is_landscape = saved[1]


## Every turn phase as the turn screen shows it on a phone. The Strategic phase's Zone
## cards and stat rows ran past the right edge in the first portrait capture.
func test_every_turn_phase_fits_a_small_phone() -> void:
	Populator.new(get_tree().root)._pre_tactics()
	var core: Resource = get_tree().root.get_node("/root/GameState").current_campaign
	var sv := SubViewport.new()
	sv.size = SMALL_PHONE
	add_child(sv)
	auto_free(sv)
	for phase in range(8):
		core.record_turn_phase(phase, {})
		var tc: Node = (load(TURN_SCENE) as PackedScene).instantiate()
		sv.add_child(tc)
		for _i in range(8):
			await get_tree().process_frame
		assert_int(tc.phase_manager.current_phase).is_equal(phase)
		var bad := _offenders(tc, float(SMALL_PHONE.x), true)
		assert_int(bad.size()).override_failure_message(
			"phase %d (%s): %d control(s) off a %d px phone: %s"
			% [phase, tc.phase_manager.get_phase_name(phase), bad.size(), SMALL_PHONE.x,
				", ".join(bad.slice(0, 4))]).is_equal(0)
		sv.remove_child(tc)
		tc.free()


## The dashboard title starts below the Settings and bug-report buttons, and a unit card
## says what its stats grid cannot (its p.106 condition, or that it is ready) instead of
## repeating Models and Battles.
func test_the_dashboard_clears_the_settings_band_and_cards_do_not_repeat_stats() -> void:
	Populator.new(get_tree().root)._pre_tactics()
	var so := get_tree().root.get_node("/root/SettingsOverlay")
	var band: float = so.get_reserved_bottom()
	assert_float(band).override_failure_message(
		"no Settings band is showing, so clearing it proves nothing").is_greater(0.0)
	var sv := SubViewport.new()
	sv.size = Vector2i(393, 851)
	add_child(sv)
	auto_free(sv)
	var dash: Node = (load(DASHBOARD_SCENE) as PackedScene).instantiate()
	sv.add_child(dash)
	await _settle()
	var title := _find_label(dash, "Sweep fixture")
	assert_object(title).is_not_null()
	assert_float(title.get_global_rect().position.y).override_failure_message(
		"the title starts at y=%.0f, under the %.0f px Settings band"
		% [title.get_global_rect().position.y, band]).is_greater_equal(band - EPS)
	var ready_cards := 0
	for n in dash.find_children("*", "Label", true, false):
		var t: String = (n as Label).text
		assert_bool(t.contains(" models") or t.contains(" battles")).override_failure_message(
			"a card subtitle repeats the stats grid: '%s'" % t).is_false()
		if t == "Ready to deploy":
			ready_cards += 1
	assert_int(ready_cards).is_equal(Populator.TACTICS_PLATOON.size())


## Retire sends a veteran to one of three modes. Its rows ran off a phone (a name and
## three buttons in one HBox), Cancel sat below every veteran, and the page, added to the
## window root, was outside the dashboard's touch sweep.
func test_the_retire_overlay_fits_a_small_phone() -> void:
	Populator.new(get_tree().root)._pre_tactics()
	var sv := SubViewport.new()
	sv.size = SMALL_PHONE
	add_child(sv)
	auto_free(sv)
	var dash: Node = (load(DASHBOARD_SCENE) as PackedScene).instantiate()
	sv.add_child(dash)
	await _settle()
	var vets: Array = [
		{"id": "v1", "name": "Sergeant Ito"},
		{"id": "v2", "name": "Lieutenant Commander Anastasia Varenko-Delacroix"}]
	var overlay: Control = dash._build_retire_overlay(vets)
	sv.add_child(overlay)
	await _settle()
	var bad := _offenders(overlay, float(SMALL_PHONE.x), true)
	assert_array(bad).override_failure_message(
		"past a %d px phone: %s" % [SMALL_PHONE.x, bad]).is_empty()
	var cancel: Array = _buttons_with_text(overlay, "Cancel")
	assert_int(cancel.size()).is_equal(1)
	var title := _find_label(overlay, "RETIRE VETERAN")
	assert_float((cancel[0] as Button).get_global_rect().position.y).override_failure_message(
		"Cancel is below the veterans; a phone scrolls past every one to back out") \
		.is_less(title.get_global_rect().position.y)
	var eff := _effective_scale()
	var dests := 0
	for b in overlay.find_children("*", "Button", true, false):
		var btn := b as Button
		assert_int(btn.mouse_filter).override_failure_message(
			"'%s' is STOP, so a drag from it never reaches the page scroll" % btn.text) \
			.is_not_equal(Control.MOUSE_FILTER_STOP)
		if btn.text.begins_with("→ "):
			dests += 1
			_assert_touch_target(btn, eff)
	assert_int(dests).is_equal(6)


## Continue says what pressing it does, in every state TacticsPhaseManager.enter_campaign()
## tells apart, and a campaign with no turn started shows no "TURN 0".
func test_continue_says_what_it_will_do() -> void:
	Populator.new(get_tree().root)._pre_tactics()
	var core: Resource = get_tree().root.get_node("/root/GameState").current_campaign
	var Dash = load("res://src/ui/screens/tactics/TacticsDashboard.gd")
	core.record_turn_phase(4, {})
	assert_str(Dash.continue_text(core)).is_equal("Resume turn 1: Battle")
	core.record_turn_phase(-1, {})  # the turn ended
	assert_str(Dash.continue_text(core)).is_equal("Start turn 2")
	core.turn_phase = core.PHASE_UNRECORDED  # a save from before the record
	assert_str(Dash.continue_text(core)).is_equal("Resume turn 1: Commit Your Force")
	core.campaign_turn = 0
	core.operational_turn = 0
	assert_str(Dash.continue_text(core)).is_equal("Start turn 1")
	var dash: Node = (load(DASHBOARD_SCENE) as PackedScene).instantiate()
	add_child(dash)
	auto_free(dash)
	await _settle()
	assert_object(_find_label(dash, "Start turn 1")).override_failure_message(
		"the Continue card does not say it starts turn 1").is_not_null()
	var zeros := 0
	for title in ["TURN", "OP TURN"]:
		var lbl := _find_label(dash, title)
		assert_object(lbl).is_not_null()
		for sib in lbl.get_parent().get_children():
			if sib is Label and (sib as Label).text == "0":
				zeros += 1
	assert_int(zeros).override_failure_message(
		"%d turn tile(s) read 0 before any turn was played" % zeros).is_equal(0)


## A unit refit (p.108) lists each change as a CheckBox. Those only exist while the refit
## purchase is pending, which no plain phase walk reaches, so they get their own case.
func test_the_refit_options_fit_a_small_phone() -> void:
	Populator.new(get_tree().root)._pre_tactics()
	var core: Resource = get_tree().root.get_node("/root/GameState").current_campaign
	core.record_turn_phase(6, {})  # Phase.ADVANCEMENT
	var sv := SubViewport.new()
	sv.size = SMALL_PHONE
	add_child(sv)
	auto_free(sv)
	var tc: Node = (load(TURN_SCENE) as PackedScene).instantiate()
	sv.add_child(tc)
	for _i in range(8):
		await get_tree().process_frame
	tc._post_battle._on_pick_purchase("unit_refit")
	await _settle()
	var boxes: Array = (tc._post_battle as Node).find_children("*", "CheckBox", true, false)
	assert_int(boxes.size()).override_failure_message(
		"the refit showed no options, so its fit was not measured").is_greater(0)
	var bad := _offenders(tc, float(SMALL_PHONE.x), true)
	assert_int(bad.size()).override_failure_message(
		"%d control(s) off a %d px phone: %s"
		% [bad.size(), SMALL_PHONE.x, ", ".join(bad.slice(0, 4))]).is_equal(0)


## The first phase is p.96's commitment of a force to an Operational Zone (Steps 1 and 8).
## It was titled "Operational Orders" (p.98's Step 4, a different thing) and carried a
## "Battle Plan" card, which in this book is the p.58 AI Battle Plan System.
func test_the_orders_step_names_the_operational_zone() -> void:
	Populator.new(get_tree().root)._pre_tactics()
	var core: Resource = get_tree().root.get_node("/root/GameState").current_campaign
	core.record_turn_phase(0, {})  # Phase.ORDERS
	var tc: Node = (load(TURN_SCENE) as PackedScene).instantiate()
	add_child(tc)
	auto_free(tc)
	for _i in range(8):
		await get_tree().process_frame
	var panel: Node = tc._battle_setup
	assert_bool((panel as Control).is_visible_in_tree()).is_true()
	assert_str(panel._phase_title.text).is_equal("Commit Your Force")
	var zone_card := false
	for n in panel.find_children("*", "Label", true, false):
		var t: String = (n as Label).text
		assert_bool(t.to_lower().contains("battle plan")).override_failure_message(
			"the Orders step still says '%s'" % t).is_false()
		if t == "Operational Zone":
			zone_card = true
	assert_bool(zone_card).is_true()


## "Play another battle this turn" qualifies the outcome button that completes the phase,
## so it is read BEFORE those buttons, not ticked after scrolling past them.
func test_the_play_another_option_comes_before_the_outcome_buttons() -> void:
	Populator.new(get_tree().root)._pre_tactics()
	var core: Resource = get_tree().root.get_node("/root/GameState").current_campaign
	core.record_turn_phase(4, {})  # Phase.BATTLE
	var tc: Node = (load(TURN_SCENE) as PackedScene).instantiate()
	add_child(tc)
	auto_free(tc)
	for _i in range(8):
		await get_tree().process_frame
	var check: CheckBox = tc._another_check
	assert_bool(check.visible).override_failure_message(
		"the option is hidden in the BATTLE phase, so the order proves nothing").is_true()
	var victory: Array = _buttons_with_text(check.get_parent(), "Victory")
	assert_int(victory.size()).is_equal(1)
	var row: Node = (victory[0] as Node).get_parent()
	assert_object(row.get_parent()).is_same(check.get_parent())
	assert_int(check.get_index()).override_failure_message(
		"the option (child %d) sits below the outcome buttons (child %d)"
		% [check.get_index(), row.get_index()]).is_less(row.get_index())


## On a wide tablet the phases read as one centred column, as the creation wizard does,
## rather than stretching labels and values to the two edges of a 2560 px screen.
func test_the_turn_screen_keeps_a_readable_column_on_a_wide_screen() -> void:
	Populator.new(get_tree().root)._pre_tactics()
	var sv := SubViewport.new()
	sv.size = Vector2i(1900, 1080)
	add_child(sv)
	auto_free(sv)
	var tc: Node = (load(TURN_SCENE) as PackedScene).instantiate()
	sv.add_child(tc)
	for _i in range(8):
		await get_tree().process_frame
	var col: Rect2 = (tc._panel_container as Control).get_global_rect()
	assert_float(col.size.x).override_failure_message(
		"the phase column is %.0f px wide on a 1900 px screen" % col.size.x) \
		.is_less_equal(float(tc.MAX_CONTENT_WIDTH) + EPS)
	assert_float(absf(col.get_center().x - 950.0)).is_less(2.0)


func _effective_scale() -> float:
	var src := FileAccess.get_file_as_string("res://src/autoload/SettingsManager.gd")
	var re := RegEx.new()
	re.compile("const TARGET_EFFECTIVE := ([0-9.]+)")
	var m := re.search(src)
	return float(m.get_string(1)) if m else 0.0


func _assert_touch_target(b: Button, eff: float) -> void:
	var h: float = maxf(b.size.y, b.custom_minimum_size.y)
	assert_float(h * eff).override_failure_message(
		"'%s' is %.1f design px, %.1f dp: under the %d dp floor"
		% [b.text, h, h * eff, int(TOUCH_FLOOR_DP)]).is_greater_equal(TOUCH_FLOOR_DP)


func test_the_wizard_buttons_meet_the_touch_floor() -> void:
	var eff := _effective_scale()
	assert_float(eff).override_failure_message(
		"TARGET_EFFECTIVE was not found in SettingsManager.gd, so nothing below is measured") \
		.is_greater(1.0)
	var ui: Node = (load(CREATION_SCENE) as PackedScene).instantiate()
	add_child(ui)
	auto_free(ui)
	await _settle()
	var cancel: Array = _buttons_with_text(ui, "Cancel")
	assert_int(cancel.size()).is_equal(1)
	_assert_touch_target(cancel[0], eff)
	ui.coordinator.go_to_step(1)
	await _settle()
	var selects: Array = _buttons_with_text(ui, "Select")
	assert_int(selects.size()).override_failure_message("the species step showed no species") \
		.is_greater(10)
	for b in selects:
		_assert_touch_target(b, eff)


func test_the_turn_screen_dashboard_button_meets_the_touch_floor() -> void:
	var eff := _effective_scale()
	Populator.new(get_tree().root)._pre_tactics()
	var tc: Node = (load(TURN_SCENE) as PackedScene).instantiate()
	add_child(tc)
	auto_free(tc)
	for _i in range(8):
		await get_tree().process_frame
	var dash: Array = _buttons_with_text(tc, "Dashboard")
	assert_int(dash.size()).is_equal(1)
	# ⚠ BOTH layout classes. Headless, ResponsiveManager reads a 0 px window and says
	# MOBILE, and the collapsed branch was already 48: the defect was the LANDSCAPE
	# branch, i.e. the tablet. Drive the autoload's two fields, as
	# test_prebattle_responsive_layout.gd does, and put them back.
	var rm := get_tree().root.get_node("/root/ResponsiveManager")
	var saved := [rm.current_breakpoint, rm.is_landscape]
	for state in [[rm.Breakpoint.DESKTOP, true], [rm.Breakpoint.MOBILE, false]]:
		rm.current_breakpoint = state[0]
		rm.is_landscape = state[1]
		tc._apply_topbar_responsive()
		assert_bool(rm.should_collapse_to_single_column()).is_equal(not state[1])
		var b: Button = dash[0]
		assert_float(b.custom_minimum_size.y * eff).override_failure_message(
			"Dashboard is %.1f dp in the %s layout, under the %d dp floor"
			% [b.custom_minimum_size.y * eff, "landscape" if state[1] else "portrait",
				int(TOUCH_FLOOR_DP)]).is_greater_equal(TOUCH_FLOOR_DP)
	rm.current_breakpoint = saved[0]
	rm.is_landscape = saved[1]
