extends GdUnitTestSuite
## A battle modal starts below the floating Settings, bug-report and help buttons.
##
## Those buttons live on SettingsOverlay's CanvasLayer 99, above the battle
## screen's modal layer (93). The modal was centred on the whole screen, so on a
## phone a tall one (the companion-level picker) ran its title and scrollbar under
## the buttons. It is now centred in the space below them.

const TacticalBattleScene := preload("res://src/ui/screens/battle/TacticalBattleUI.tscn")
const SaveDirGuard := preload("res://tests/fixtures/helpers/save_dir_guard.gd")

var _user_state: Dictionary = {}
var _previous_campaign = null


func before_test() -> void:
	_user_state = SaveDirGuard.snapshot()
	var gs: Node = get_node("/root/GameState")
	_previous_campaign = gs.current_campaign
	# No campaign: the screen takes its standalone path and writes nothing to one.
	gs.current_campaign = null


func after_test() -> void:
	get_node("/root/GameState").current_campaign = _previous_campaign
	SaveDirGuard.restore(_user_state)


func test_a_tall_modal_starts_below_the_floating_buttons() -> void:
	var band: float = float(get_node("/root/SettingsOverlay").get_reserved_bottom())
	# Premise: the buttons are showing and reach below the old 16 px margin, so a
	# modal centred on the whole screen would sit under them.
	assert_float(band).override_failure_message(
		"the floating buttons are not visible here (band %.1f)" % band).is_greater(16.0)
	var ui: Control = auto_free(TacticalBattleScene.instantiate())
	add_child(ui)
	for i in 3:
		await get_tree().process_frame
	var tall := Control.new()
	tall.custom_minimum_size = Vector2(200, 5000)
	ui._show_overlay(tall)
	for i in 3:
		await get_tree().process_frame
	var scroll: Control = ui.overlay_content.get_parent()
	assert_bool(scroll is ScrollContainer).is_true()
	assert_float(scroll.get_global_rect().position.y).is_greater_equal(band)
