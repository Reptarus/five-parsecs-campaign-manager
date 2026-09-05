extends GdUnitTestSuite
## T11-04 — the Settings screen must fit a phone in portrait (fixed 2026-09-04).
##
## `AccessibilitySettingsPanel._setup_ui()` set `custom_minimum_size = Vector2(600, 400)`.
## The 600 put 297.2 px of every settings row off the right edge of a phone in portrait,
## whose design space is 338.79 px wide.
##
## WHY A HARD FLOOR PROPAGATED THAT FAR. The settings content lives in a ScrollContainer
## whose HORIZONTAL axis is SCROLL_MODE_DISABLED — correct, a settings page must not
## scroll sideways — and a disabled axis makes a ScrollContainer PROPAGATE its child's
## minimum on that axis rather than absorb it. That is the T11-01 mechanism one axis
## over. Measured chain: panel 600 -> ScrollContainer 608 -> VBoxContainer 608 -> root
## MarginContainer 636, against a 338.79 px viewport.
##
## WHY NO SWEEP CAUGHT IT. `SettingsScreen._enter_tree()` restores `user://window.ini`
## and applies its saved size (:127-129). verify_layout.gd builds a fresh instance per
## size, so the screen snapped the window back to the persisted 800x1280 before every
## measurement — six identical geometries reported as six passes. verify_rotation.gd
## builds once and re-applies a size per step, which overwrites the restore, which is
## the entire reason the two sweeps disagreed for a day. verify_layout now re-asserts
## the window size after `_enter_tree` (see `_reassert_size` there).
##
## These cases are the FAST structural guard; the end-to-end proof is the layout sweep.
## They deliberately assert the shape (no hardcoded width floor, descriptions wrap)
## rather than an exact pixel count, so they cannot flake on font metrics or UI scale.

const PANEL := preload("res://src/ui/screens/settings/AccessibilitySettingsPanel.gd")
const SCREEN_PATH := "res://src/ui/screens/settings/SettingsScreen.tscn"

## WHAT THIS BOUND CAN AND CANNOT CATCH - read before tightening it.
##
## A 360 dp phone has 310 px of design space at the shipped stretch config, so 310 is
## the number that matters on a device. This suite deliberately asserts against 360
## instead, and the difference is coverage that is NOT here:
##
##   - `before_test()` pins ResponsiveManager to MOBILE, so FONT sizes are the phone's.
##   - The real gdUnit4 WINDOW is whatever `GameState`'s boot-time window.ini restore
##     made it, and `ScreenChrome.apply_page_chrome()` sizes the page gutter from that
##     window, not from ResponsiveManager. So the measurement is mobile fonts inside a
##     desktop-width gutter - a hybrid, and the gutter moves the total by ~16 px.
##
## Asserting 310 against a hybrid produced a FALSE RED: the fully-fixed screen measured
## 326 here while the layout sweep called it clean at 360x640. Making the two agree
## would mean resizing the window from inside a unit test, which is the cross-suite
## hazard `before_test()` exists to avoid.
##
## So the split is explicit: THIS SUITE catches gross regressions - a hardcoded floor,
## an unwrapped description - fast and without a window. `tests/tools/verify_layout.gd`
## is the authority for MARGINAL overflow and is what found the 3.7 px toggle-row case.
## ⚠ Proven, not assumed: reverting the toggle-row autowrap fix (SettingsScreen.gd's
## `_add_toggle_row`) leaves this suite GREEN at 328 px. Do not read these four passes
## as "SettingsScreen fits a phone" - read them as "no gross width regression".
const PHONE_DESIGN_WIDTH := 360.0

## _exit_tree() writes window state back. Point it at a scratch file so a test run can
## never touch the developer's real user://window.ini, and never resize their window.
const SCRATCH_WINDOW_STATE := "user://__test_window_state.ini"


## Design space of a 360 dp phone at the shipped stretch config. ResponsiveManager
## classifies MOBILE below 480 dip, so this pins the mobile branch.
const PHONE_VIEWPORT := Vector2(310.0, 551.0)

var _rm: Node = null
var _saved: Dictionary = {}


## PIN THE CONFIGURATION THIS SUITE CLAIMS TO MEASURE.
##
## Font sizes on this screen come from `ResponsiveManager.get_responsive_font_size()`
## and are baked in at build time, so the width the screen demands depends on the
## ambient breakpoint - and the ambient breakpoint depends on the WINDOW, which comes
## from `GameState`'s boot-time `user://window.ini` restore. Running either layout
## sweep rewrites that file (every SettingsScreen instance saves on the way out), so
## this suite silently measured a different configuration depending on what had been
## run before it: it passed at one window size and reported 372.0 px at 800x1280, with
## DESKTOP fonts compared against a phone's width - the same wrong comparison the
## layout sweep was making before it learned to rebuild.
##
## Driving the fields directly is what the ResponsiveManager suite already does
## (test_responsive_manager_effective_columns.gd:20-25); the difference is that this
## one must drive the AUTOLOAD, because the screen under test reads that instance.
## Restored in after_test so this suite cannot become someone else's flake.
func before_test() -> void:
	_rm = get_node_or_null("/root/ResponsiveManager")
	if _rm == null:
		return
	_saved = {
		"bp": _rm.current_breakpoint,
		"landscape": _rm.is_landscape,
		"vp": _rm.current_viewport_size,
	}
	_rm.current_breakpoint = _rm.Breakpoint.MOBILE
	_rm.is_landscape = false
	_rm.current_viewport_size = PHONE_VIEWPORT


func after_test() -> void:
	if _rm == null or _saved.is_empty():
		return
	_rm.current_breakpoint = _saved["bp"]
	_rm.is_landscape = _saved["landscape"]
	_rm.current_viewport_size = _saved["vp"]


func after() -> void:
	if FileAccess.file_exists(SCRATCH_WINDOW_STATE):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SCRATCH_WINDOW_STATE))


func test_the_accessibility_panel_declares_no_hardcoded_width_floor() -> void:
	var panel: Control = auto_free(PANEL.new())
	add_child(panel)
	await await_idle_frame()
	# It has ONE consumer (SettingsScreen.gd:235) which adds it with
	# size_flags_horizontal = SIZE_EXPAND_FILL, so its parent stretches it wherever
	# there is room. A width floor therefore buys nothing and can only ever block.
	assert_float(panel.custom_minimum_size.x).override_failure_message(
		"AccessibilitySettingsPanel must not impose a width floor: it is stretched by "
		+ "its only consumer, and inside a horizontally-DISABLED ScrollContainer a "
		+ "floor propagates all the way to the screen root (T11-04)."
	).is_equal(0.0)


func test_the_accessibility_panel_fits_a_phone_in_portrait() -> void:
	var panel: Control = auto_free(PANEL.new())
	add_child(panel)
	await await_idle_frame()
	await await_idle_frame()
	var need: float = panel.get_combined_minimum_size().x
	assert_float(need).override_failure_message(
		"AccessibilitySettingsPanel demands %.1f px of width, more than the %.0f px a "
		% [need, PHONE_DESIGN_WIDTH]
		+ "phone in portrait has. Widest child: %s" % _widest_child(panel)
	).is_less(PHONE_DESIGN_WIDTH)


func test_every_description_label_in_the_panel_wraps() -> void:
	# An unwrapped Label demands its full single-line text width as a minimum, which is
	# the same defect in miniature: with the 600 floor gone, the unwrapped
	# "Standard theme - no accessibility adjustments" became the widest constraint at
	# 326 px, leaving ~13 px of headroom on a phone. Three of the file's four
	# descriptive labels already wrapped; the fourth was missed.
	var panel: Control = auto_free(PANEL.new())
	add_child(panel)
	await await_idle_frame()
	await await_idle_frame()
	var offenders: Array[String] = []
	for node in _all_controls(panel):
		if not (node is Label):
			continue
		var lbl := node as Label
		# A short caption is a label, not a description; the defect shape is prose.
		if lbl.text.length() < 24:
			continue
		if lbl.autowrap_mode == TextServer.AUTOWRAP_OFF:
			offenders.append('"%s" (%d chars, min %.0f px)'
				% [lbl.text, lbl.text.length(), lbl.get_combined_minimum_size().x])
	assert_array(offenders).override_failure_message(
		"These description Labels have autowrap OFF, so each demands its full "
		+ "unwrapped width as a minimum on a phone: %s" % str(offenders)
	).is_empty()


func test_the_whole_settings_screen_fits_a_phone_in_portrait() -> void:
	# Test the SCREEN, not just the builder it calls — a panel-level assertion is blind
	# to a floor introduced anywhere else on the page, and this is the contract that
	# actually matters to a player.
	#
	# ⚠ This case asserted `root.get_combined_minimum_size().x` first, and it was a
	# FALSE GREEN: it passed with the 600 px floor restored. SettingsScreen's root is a
	# plain `Control`, and a plain Control does not aggregate its children's minimums —
	# only Containers do — so it reports 0.0 and the assertion was `0 < 360`, which no
	# defect can fail. The probe had already printed the tell and I read past it:
	#     SettingsScreen        Control          min.x    0.00
	#       @MarginContainer@199 MarginContainer min.x  636.00
	# Walk the descendants instead, which is where the constraint actually lives.
	var ps: PackedScene = load(SCREEN_PATH)
	assert_object(ps).is_not_null()
	var inst: Node = ps.instantiate()
	# `_window_config_path` is a plain var and `_enter_tree` fires on add_child, so
	# redirecting it here disables the window restore without changing any other
	# behaviour (`overlay_mode` would have changed several).
	inst._window_config_path = SCRATCH_WINDOW_STATE
	add_child(inst)
	if inst is CanvasItem and not (inst as CanvasItem).visible:
		(inst as CanvasItem).show()
	for _i in range(6):
		await await_idle_frame()

	var worst := 0.0
	var who := ""
	for ctl in _all_controls(inst as Control):
		if not ctl.is_visible_in_tree():
			continue
		# A node under a ScrollContainer that CAN scroll horizontally is allowed to be
		# wider than the screen — that is what the scroll is for. Settings' own scroll
		# has its horizontal axis DISABLED, so nothing there gets this exemption.
		if _inside_h_scrollable(ctl, inst):
			continue
		var w: float = ctl.get_combined_minimum_size().x
		if w > worst:
			worst = w
			who = "%s (%s)" % [String(ctl.name), ctl.get_class()]
	inst.queue_free()
	await await_idle_frame()

	assert_float(worst).override_failure_message(
		"[%s] SettingsScreen demands %.1f px of width, more than the %.0f px a phone in "
		% [_ambient(), worst, PHONE_DESIGN_WIDTH]
		+ "portrait has, so its rows run off the right edge (T11-04). The node "
		+ "imposing it: %s" % who
	).is_less(PHONE_DESIGN_WIDTH)


## True when an ancestor below `stop` is a ScrollContainer that can actually scroll
## horizontally, which is the only case where an over-wide minimum is legitimate.
func _inside_h_scrollable(n: Node, stop: Node) -> bool:
	var p := n.get_parent()
	while p != null and p != stop:
		if p is ScrollContainer 				and (p as ScrollContainer).horizontal_scroll_mode 					!= ScrollContainer.SCROLL_MODE_DISABLED:
			return true
		p = p.get_parent()
	return false


## Font sizes on this screen come from ResponsiveManager, so the width it demands
## depends on the ambient breakpoint. Report it: a failure that does not say which
## configuration it measured sends the reader looking in the wrong place.
func _ambient() -> String:
	var rm := get_node_or_null("/root/ResponsiveManager")
	if rm == null:
		return "no ResponsiveManager"
	return "bp=%d landscape=%s vp=%s fontx%.3f win=%s" % [
		rm.current_breakpoint, str(rm.is_landscape), str(rm.current_viewport_size),
		rm.get_font_size_multiplier(), str(DisplayServer.window_get_size())]


## Name the child imposing the width, so a failure says what to fix rather than only
## that something is too wide.
func _widest_child(ctl: Control) -> String:
	var best: Control = null
	var best_w := -1.0
	for c in ctl.get_children():
		if not (c is Control):
			continue
		var w: float = (c as Control).get_combined_minimum_size().x
		if w > best_w:
			best_w = w
			best = c as Control
	if best == null:
		return "(no Control children)"
	return "%s (%s) min.x %.1f" % [String(best.name), best.get_class(), best_w]


func _all_controls(rootc: Control) -> Array[Control]:
	var out: Array[Control] = []
	var stack: Array = [rootc]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		for c in n.get_children():
			stack.append(c)
		if n is Control:
			out.append(n as Control)
	return out
