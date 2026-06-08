extends GdUnitTestSuite
## TacticalBattleUI responsive / clarity smoke + contract (battle-flow UX pass, Jun 2026)
##
## Instantiates the REAL TacticalBattleUI scene (so it also catches runtime errors
## introduced by the Phase-2 container-type changes) and locks in:
##   1. The bottom action row (PhaseButtonsContainer) is an HFlowContainer so it
##      wraps on the 360dp portrait floor instead of overflowing
##   2. The drawer toolbar is an HFlowContainer so its 5-7 buttons wrap
##   3. The companion phase-instruction banner is built and shows/hides correctly
##   4. The responsive overlay-width helper clamps to a sane range
##
## gdUnit4 v6.0.3. Run with -c, never --headless (project rule).

const BattleScene := preload("res://src/ui/screens/battle/TacticalBattleUI.tscn")


func _make_ui() -> Control:
	var ui: Control = auto_free(BattleScene.instantiate())
	add_child(ui)
	# Let deferred _setup_ui / _apply_responsive_layout / _check_standalone_mode run.
	await get_tree().process_frame
	await get_tree().process_frame
	return ui


func test_action_row_and_drawer_toolbar_are_flow_containers() -> void:
	var ui := await _make_ui()
	assert_bool(ui.action_buttons is HFlowContainer).override_failure_message(
		"PhaseButtonsContainer must be HFlowContainer to wrap in portrait").is_true()
	var bar = ui.action_buttons.get_node_or_null("DrawerBar")
	assert_object(bar).override_failure_message(
		"DrawerBar should be built by _apply_tier_visibility(0)").is_not_null()
	assert_bool(bar is HFlowContainer).override_failure_message(
		"DrawerBar must be HFlowContainer so its buttons wrap in portrait").is_true()


func test_phase_instruction_banner_built_and_toggles() -> void:
	var ui := await _make_ui()
	assert_object(ui._phase_banner).override_failure_message(
		"phase-instruction banner not built in _build_redesign_frame").is_not_null()
	# Hidden until an instruction is set.
	ui._set_phase_instruction(2, "Enemy Actions", "Resolve enemy actions on the table.")
	assert_bool(ui._phase_banner.visible).is_true()
	assert_str(ui._phase_banner_label.text).contains("Resolve enemy actions")
	assert_str(ui._phase_banner_chip.text).contains("PHASE 3/5")
	# Empty instruction hides it.
	ui._set_phase_instruction(0, "Reaction Roll", "")
	assert_bool(ui._phase_banner.visible).is_false()


func test_overlay_width_clamped() -> void:
	var ui := await _make_ui()
	var w: float = ui._overlay_width()
	assert_float(w).is_greater_equal(280.0)
	assert_float(w).is_less_equal(560.0)
	var w_wide: float = ui._overlay_width(700.0)
	assert_float(w_wide).is_greater_equal(280.0)
	assert_float(w_wide).is_less_equal(700.0)
