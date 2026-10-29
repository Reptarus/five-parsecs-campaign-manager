extends GdUnitTestSuite

## Planetfall screens at phone size. verify_layout measured them for the first time on
## 2026-10-28 and found two defects no suite could see:
##
##   * the creation wizard's title, a Label that did not wrap, demanded its full 306 px
##     text width and pushed the page 35.7 px past a 310 px phone;
##   * every cell of the colony map was 46.4 dp tall in portrait, under the 48 dp touch
##     floor, because the phone cell was 40 design px at the 1.16 effective scale.
##
## ⚠ A fix that wraps a Label can trade one defect for another: a wrapping Label reports a
## ~1 px minimum, so a container that does not stretch it renders the title as a column
## one letter wide, and an overflow check reads that as clean. The title case therefore
## asserts the title's own width and line count, not only that the page fits.

const CREATION_SCENE := "res://src/ui/screens/planetfall/PlanetfallCreationUI.tscn"
const SectorGrid = preload("res://src/ui/screens/planetfall/panels/PlanetfallSectorGrid.gd")
const CoreScript = preload("res://src/game/campaign/PlanetfallCampaignCore.gd")
const MapScript = preload("res://src/core/systems/PlanetfallMap.gd")
const SaveDirGuard := preload("res://tests/fixtures/helpers/save_dir_guard.gd")
const TurnScene := preload("res://src/ui/screens/planetfall/PlanetfallTurnController.tscn")
const BATTLE_SCENE := "res://src/ui/screens/battle/TacticalBattleUI.tscn"
const MISSIONS := "res://data/planetfall/mission_types.json"
const ENEMIES := "res://data/planetfall/tactical_enemies_generation.json"

## The smallest phone verify_layout sweeps, in design px (360 x 640 physical).
const SMALL_PHONE := Vector2i(310, 551)
## Material/Android minimum touch target; verify_layout.gd TOUCH_FLOOR_DP.
const TOUCH_FLOOR_DP := 48.0
const TITLE := "PLANETFALL — NEW COLONY"

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


func test_the_creation_title_wraps_inside_a_small_phone() -> void:
	var sv := SubViewport.new()
	sv.size = SMALL_PHONE
	add_child(sv)
	auto_free(sv)
	var inst: Node = (load(CREATION_SCENE) as PackedScene).instantiate()
	sv.add_child(inst)
	for _i in range(6):
		await get_tree().process_frame
	var title: Label = _find_label(inst, TITLE)
	assert_object(title).is_not_null()
	var rect: Rect2 = title.get_global_rect()
	assert_float(rect.end.x).override_failure_message(
		"the title runs to x=%.1f on a %d px screen" % [rect.end.x, SMALL_PHONE.x]) \
		.is_less_equal(float(SMALL_PHONE.x))
	# Not collapsed: wide enough for its longest word, and two lines at most.
	assert_float(rect.size.x).override_failure_message(
		"the title is %.1f px wide, a column rather than a heading" % rect.size.x) \
		.is_greater(100.0)
	assert_int(title.get_line_count()).is_less_equal(2)


## The shipped effective scale, read from the line that sets it, so this case follows a
## deliberate re-tune instead of restating 1.16 (test_content_scale_formula.gd explains
## why that constant cannot be read as a property: it is local to _apply_ui_scale()).
func _effective_scale() -> float:
	var src := FileAccess.get_file_as_string("res://src/autoload/SettingsManager.gd")
	var re := RegEx.new()
	re.compile("const TARGET_EFFECTIVE := ([0-9.]+)")
	var m := re.search(src)
	return float(m.get_string(1)) if m else 0.0


func test_every_map_cell_is_a_touch_target() -> void:
	var eff := _effective_scale()
	assert_float(eff).override_failure_message(
		"TARGET_EFFECTIVE was not found in SettingsManager.gd, so nothing below is measured") \
		.is_greater(1.0)
	# Both branches of _cell_size(): a tablet and a phone that collapses to one column.
	for side in [SectorGrid.CELL_MIN, SectorGrid.CELL_PHONE]:
		assert_float(side * eff).override_failure_message(
			"a %d px cell is %.1f dp, under the %d dp floor"
			% [side, side * eff, int(TOUCH_FLOOR_DP)]).is_greater_equal(TOUCH_FLOOR_DP)
	# And the grid builds its cells at that size, whichever branch this process takes.
	var core = CoreScript.new()
	MapScript.generate(core, 6, 6, [2, 2], 0)
	var grid: Control = SectorGrid.new()
	add_child(grid)
	auto_free(grid)
	grid.show_map(core)
	var cells: Array = grid.find_children("*", "Button", true, false)
	assert_int(cells.size()).is_equal(36)
	for b in cells:
		assert_float((b as Button).custom_minimum_size.y * eff).is_greater_equal(TOUCH_FLOOR_DP)


## The battle screen's opening modal for a Planetfall battle: the Planetfall Battle Card and
## the mission briefing's setup checklist (2026-10-28), with the payload the turn
## controller builds for a Skirmish (Battlefield Conditions, two Uncertain features and a
## Tactical Enemy force, so the card is near its longest), on a small phone.
func test_the_planetfall_battle_modal_fits_a_small_phone() -> void:
	var core = CoreScript.new()
	core.colony_name = "Probe"
	core.game_phase = "active"
	core.roster = [{"id": "c1", "name": "Ash", "class": "trooper"}]
	core.lifeform_table = []
	for _i in range(10):
		core.lifeform_table.append({})
	core.tactical_enemies = [{"type": _enemy_type("outlaws"), "boss_located": false,
		"defeated": false}]
	var gs := get_tree().root.get_node("/root/GameState")
	gs.current_campaign = core
	var tc: Control = auto_free(TurnScene.instantiate())
	add_child(tc)
	await get_tree().process_frame
	await get_tree().process_frame
	tc._mission_context = _mission("skirmish")
	tc._deployed_data = {"deployed_characters": {"c1": {"weapon_id": ""}}}
	var md: Dictionary = tc.build_battle_payload().context.mission_data
	var sv := SubViewport.new()
	sv.size = SMALL_PHONE
	add_child(sv)
	auto_free(sv)
	var tb: Control = (load(BATTLE_SCENE) as PackedScene).instantiate()
	sv.add_child(tb)
	await get_tree().process_frame
	tb._stored_mission_data = md
	tb._show_pre_battle_checklist(1)
	await get_tree().create_timer(0.3).timeout
	for _i in range(3):
		await get_tree().process_frame
	var card_title: Label = _find_label(tb, "PLANETFALL BATTLE CARD")
	assert_object(card_title).override_failure_message(
		"no Planetfall Battle Card on screen").is_not_null()
	var scroll: Node = card_title
	while scroll != null and not (scroll is ScrollContainer):
		scroll = scroll.get_parent()
	var modal: Node = scroll.get_parent() if scroll else null
	var bad := PackedStringArray()
	for kind in ["Button", "Label"]:
		for n in modal.find_children("*", kind, true, false):
			var c := n as Control
			if not c.is_visible_in_tree() or str(c.get("text")).is_empty():
				continue
			var r: Rect2 = c.get_global_rect()
			if r.end.x > SMALL_PHONE.x + 0.5 or r.position.x < -0.5:
				bad.append("'%s' x=%.0f..%.0f" % [str(c.get("text")).left(40),
					r.position.x, r.end.x])
	for n in modal.find_children("*", "ScrollContainer", true, false):
		if (n as ScrollContainer).is_visible_in_tree() 				and (n as ScrollContainer).get_h_scroll_bar().visible:
			bad.append("scrolls sideways: %s" % str(modal.get_path_to(n)))
	assert_array(bad).override_failure_message(
		"past a %d px phone:
%s" % [SMALL_PHONE.x, "
".join(bad)]).is_empty()


func _mission(id: String) -> Dictionary:
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(MISSIONS))
	for m in (data as Dictionary).get("missions", []):
		if m is Dictionary and str(m.get("id", "")) == id:
			return (m as Dictionary).duplicate(true)
	return {}


func _enemy_type(id: String) -> Dictionary:
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(ENEMIES))
	for t in (data as Dictionary).get("enemy_types", []):
		if t is Dictionary and str(t.get("id", "")) == id:
			return t
	return {}
