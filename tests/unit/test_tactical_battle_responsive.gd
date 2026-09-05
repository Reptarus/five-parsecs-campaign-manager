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


func test_mobile_app_bar_and_panels_menu_built() -> void:
	# Portrait app bar (hosts the ≡ Panels drawer menu) + the menu both exist.
	var ui := await _make_ui()
	assert_object(ui._mobile_app_bar).override_failure_message(
		"battle MobileAppBar not built").is_not_null()
	assert_object(ui._panels_menu).override_failure_message(
		"≡ Panels drawer menu not built").is_not_null()


func test_overlay_width_clamped() -> void:
	var ui := await _make_ui()
	var w: float = ui._overlay_width()
	assert_float(w).is_greater_equal(280.0)
	assert_float(w).is_less_equal(560.0)
	var w_wide: float = ui._overlay_width(700.0)
	assert_float(w_wide).is_greater_equal(280.0)
	assert_float(w_wide).is_less_equal(700.0)


## ── T11-05: the overlay width must survive a rotation ───────────────────────────
##
## `_overlay_width()` was correct and was called at all four sizing sites — but only at
## BUILD time. Open an overlay in landscape (733 design px, so the clamp returns the full
## 560 cap), rotate to portrait (338.79), and the 560 is a stale minimum:
## `OverlayCenter` is a full-rect CenterContainer with `grow_horizontal =
## GROW_DIRECTION_BOTH`, so it grows in BOTH directions and the overlay lands at
## x = -114.6 — 114.6 px off the left edge, the same off the right, buttons unreachable
## on either side. Measured by `tests/tools/probe_screen_fit.gd`:
##     OverlayCenter  min (568.0, 306.8)  rect [P: (-114.6035, 0.0), S: (568.0, 733.4)]
##
## ⚠ These cases drive `_apply_responsive_layout()`, NOT `_refit_overlay_widths()`
## directly. The helper was never the missing piece — the CALL was, and a test of the
## helper alone would pass with the wiring still absent. That is this project's most
## repeated defect shape ("implemented but never called"), and a test that cannot see it
## is worth very little.

func test_a_resize_refits_a_stale_overlay_width() -> void:
	var ui := await _make_ui()
	ui._show_overlay(VBoxContainer.new())
	await get_tree().process_frame
	assert_bool(ui.overlay_center.visible).override_failure_message(
		"_show_overlay should make OverlayCenter visible").is_true()
	var scroll: ScrollContainer = ui._ensure_overlay_scroll()
	assert_object(scroll).is_not_null()

	# A deliberately absurd stale width rather than the real one (560). The real stale
	# value is whatever a WIDER viewport produced, and a unit test cannot control the
	# gdUnit4 window — so on a wide window the expected value would also be 560 and the
	# assertion could not fail. 9999 is wrong at every window size.
	scroll.custom_minimum_size.x = 9999.0
	ui.overlay_content.custom_minimum_size.x = 9999.0

	ui._apply_responsive_layout()
	await get_tree().process_frame

	var want: float = ui._overlay_width()
	assert_float(scroll.custom_minimum_size.x).override_failure_message(
		"the overlay scroll kept a stale %.1f px minimum after a resize (expected %.1f). "
		% [scroll.custom_minimum_size.x, want]
		+ "_apply_responsive_layout() must re-fit the overlay, not only the side panels."
	).is_equal_approx(want, 0.5)
	assert_float(ui.overlay_content.custom_minimum_size.x).override_failure_message(
		"OverlayContent kept a stale minimum after a resize").is_equal_approx(want, 0.5)


func test_each_overlay_node_keeps_its_own_width_cap() -> void:
	# The caps are NOT uniform: the enemy generation wizard uses 700.0 and everything else
	# takes the 560.0 default. A re-fit that re-applied one cap to every node would
	# silently shrink the wizard on desktop, trading one layout bug for another.
	var ui := await _make_ui()
	ui._show_overlay(VBoxContainer.new())
	await get_tree().process_frame

	var wide := Control.new()
	ui.overlay_content.add_child(wide)
	ui._set_overlay_width(wide, 700.0)
	var narrow := Control.new()
	ui.overlay_content.add_child(narrow)
	ui._set_overlay_width(narrow)
	await get_tree().process_frame

	wide.custom_minimum_size.x = 9999.0
	narrow.custom_minimum_size.x = 9999.0
	ui._apply_responsive_layout()
	await get_tree().process_frame

	assert_float(wide.custom_minimum_size.x).override_failure_message(
		"a node registered with a 700 cap was re-fitted to something else"
	).is_equal_approx(ui._overlay_width(700.0), 0.5)
	assert_float(narrow.custom_minimum_size.x).override_failure_message(
		"a node registered with the default cap was re-fitted to something else"
	).is_equal_approx(ui._overlay_width(), 0.5)
	assert_float(float(wide.get_meta(ui.OVERLAY_CAP_META))).override_failure_message(
		"the per-node cap must survive a re-fit, or the next one loses it").is_equal(700.0)
	# The invariant that makes the two caps meaningful at all, at any window size.
	assert_bool(ui._overlay_width(700.0) >= ui._overlay_width(560.0)).is_true()
