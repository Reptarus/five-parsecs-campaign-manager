extends GdUnitTestSuite
## Pre-battle responsive / clarity layout contract (battle-flow UX pass, Jun 2026)
##
## Instantiates the real PreBattle.tscn and locks in the structural changes that
## de-clip the screen on the 360dp portrait floor and keep the CampaignTurnController
## handoff contract intact:
##   1. AdaptivePanelGroup holds 4 panes in order Mission / Forces / Battlefield / Crew
##      against max_columns = 4 (was 3 until 2026-09-07 — at 3 the Crew pane wrapped to
##      its own row and landed below the fold in landscape)
##   2. The 8-col enemy stat GridContainer is wrapped in a horizontal-scroll
##      ScrollContainer (h=AUTO, v=DISABLED) so it swipes in portrait, fills on desktop
##   3. Crew selection buttons meet the touch-target floor and wrap long names
##   4. selected_representation_mode / selected_tier remain script PROPERTIES
##      (read by CampaignTurnController._on_deployment_confirmed) and auto-resolve
##      greys out the tracking-tier radios
##
##   5. In LANDSCAPE the four panes resolve to four EVEN columns with the crew list on
##      screen, the page does not hang off either edge, and a touch-drag over the
##      content scrolls it (cases 6-9, added 2026-09-07)
##
## ⭐ CASES 6-9 BUILD UNDER A SubViewport, AND THAT IS LOAD-BEARING.
## `AdaptivePanelGroup._columns_that_fit()` reads
## `get_viewport().get_visible_rect().size.x`. A screen added straight to this suite
## sees the project's square 1080 stretch base, which is 3 columns no matter what the
## breakpoint says — so a rendered 4-column assertion taken there can only ever fail.
## Under a SubViewport that call returns the SubViewport's own size, which is how a
## device-sized design space is reproduced with no window (this suite runs headless).
##
## ⭐ AND THE GESTURE IS REACHABLE HERE TOO, despite "Godot does not deliver InputEvents
## headless". That is true of the OS input path, not of `Viewport.push_input()`, which
## the 4.6 docs describe as locally applying an event through `Control._gui_input()` —
## exactly the chain MOUSE_FILTER_STOP interrupts. ScrollContainer's touch-drag arms when
## `DisplayServer.is_touchscreen_available()` is true, whose base implementation returns
## `Input.is_emulating_touch_from_mouse()`, and this project sets
## `input_devices/pointing/emulate_touch_from_mouse=true` (project.godot:109). The case
## instruments that premise first, because if it were false every drag would read as
## blocked and the case would pass for the wrong reason.
##
## gdUnit4 v6.0.3 compatible.
## ⚠ The note here used to read "never --headless (project rule)". That rule was
## superseded on 2026-09-05: gdUnit4 refuses --headless and prints its own override,
## --ignoreHeadlessMode, which 270 of 271 suites run correctly under. This suite is one
## of them — re-verified headless 2026-09-06, 5/5. The one genuine exception is
## test_sheet_source_paths_resolve.gd, which builds a real SheetRenderer and needs a
## rendering device. Nothing here asserts an InputEvent, which is the actual thing
## headless cannot deliver.

const PreBattleScene := preload("res://src/ui/screens/battle/PreBattle.tscn")

const ENEMY_FIXTURE := {
	"title": "Test Raid",
	"description": "A test mission.",
	"battle_type": 0,
	"enemy_force": {
		"type": "Enforcers",
		"numbers": "+0",
		"panic": "1-2",
		"speed": 4,
		"combat_skill": 1,
		"toughness": 4,
		"ai": "T",
		"weapons": "2 A",
		"count": 4,
		"special_rules": [],
	},
}


func _make_ui() -> Control:
	var ui: Control = auto_free(PreBattleScene.instantiate())
	add_child(ui)
	return ui


## Depth-first find the first node of a given Godot class under `root`.
func _find_by_class(root: Node, klass: String) -> Node:
	for child in root.get_children():
		if child.is_class(klass):
			return child
		var found := _find_by_class(child, klass)
		if found:
			return found
	return null


func test_adaptive_panes_order_mission_forces_battlefield_crew() -> void:
	var ui := _make_ui()
	var group = ui._panel_group
	assert_object(group).is_not_null()
	assert_int(group.get_pane_count()).is_equal(4)
	# _titles is the tab/focus order = add_pane order.
	var titles: Array = []
	for t in group._titles:
		titles.append(str(t))
	assert_array(titles).is_equal(["Mission", "Forces", "Battlefield", "Crew"])


func test_enemy_table_wrapped_in_horizontal_scroll() -> void:
	var ui := _make_ui()
	ui._setup_enemy_info(ENEMY_FIXTURE)
	var grid := _find_by_class(ui.enemy_info_panel, "GridContainer")
	assert_object(grid).override_failure_message(
		"enemy stat GridContainer not found under enemy_info_panel").is_not_null()
	var parent := grid.get_parent()
	assert_bool(parent is ScrollContainer).override_failure_message(
		"enemy GridContainer must be wrapped in a ScrollContainer for portrait swipe"
	).is_true()
	var scroll := parent as ScrollContainer
	assert_int(scroll.horizontal_scroll_mode).is_equal(ScrollContainer.SCROLL_MODE_AUTO)
	assert_int(scroll.vertical_scroll_mode).is_equal(ScrollContainer.SCROLL_MODE_DISABLED)


func test_crew_buttons_meet_touch_target_and_wrap() -> void:
	var ui := _make_ui()
	ui.setup_crew_selection([
		{"name": "Alice Longnameson the Considerably Verbose"},
		{"name": "Bob"},
		{"name": "Carol"},
	], 6)
	var buttons: Array = []
	_collect_toggle_buttons(ui.crew_selection_panel, buttons)
	assert_int(buttons.size()).is_greater_equal(3)
	for b in buttons:
		assert_int(int(b.custom_minimum_size.y)).override_failure_message(
			"crew button below 48px touch floor").is_greater_equal(48)
		assert_bool(b.autowrap_mode != TextServer.AUTOWRAP_OFF).override_failure_message(
			"crew button must wrap long names").is_true()


func _collect_toggle_buttons(root: Node, out: Array) -> void:
	for child in root.get_children():
		if child is Button and (child as Button).toggle_mode:
			out.append(child)
		_collect_toggle_buttons(child, out)


func test_selection_properties_preserved_and_auto_resolve_couples_tier() -> void:
	var ui := _make_ui()
	# The CampaignTurnController handoff reads these as script properties.
	assert_bool("selected_representation_mode" in ui).is_true()
	assert_bool("selected_tier" in ui).is_true()
	# Build the two decision cards (radios), then pick auto-resolve.
	ui._setup_mission_info(ENEMY_FIXTURE)
	assert_int(ui._tier_radios.size()).is_equal(3)
	ui._on_representation_radio_pressed("auto_resolve")
	for r in ui._tier_radios:
		assert_bool(r.disabled).override_failure_message(
			"tracking-tier radios must grey out under auto-resolve").is_true()
	assert_str(str(ui.selected_representation_mode)).is_equal("auto_resolve")


## ── T11 "Select Crew renders header-only" ────────────────────────────────────
## ⚠ THE CASE ABOVE IS THE CAUTIONARY TALE FOR THIS ONE.
## test_crew_buttons_meet_touch_target_and_wrap() asserts custom_minimum_size.y and
## autowrap_mode — CONSTRUCTION properties — so it passed cheerfully for as long as the
## Crew pane rendered as a bare "Select Crew" header with no list under it at all.
##
## Mechanism: 4 panes against max_columns = 3 leaves Crew alone on grid row 2.
## AdaptivePanelGroup has no row-height logic, so a row gets its own minimum plus a
## share of the surplus — and with ShortScreenScroll enabling correctly (T11-01) the
## inner column settles at its combined minimum, making the surplus ZERO. The Crew
## pane's own minimum was header-sized because its list sits in a ScrollContainer,
## which contributes ZERO minimum on its scroll axis. The pane was visible and
## correctly laid out; it had simply asked for nothing.
##
## So this asserts the RENDERED RECT. A minimum holds at every size, which is what makes
## the assertion size-independent and therefore valid without a real window.
const CREW_ROWS_VISIBLE := 3
const TOUCH_FLOOR := 48


func _crew_scroll(ui: Control) -> ScrollContainer:
	var panel: Node = ui.find_child("CrewSelection", true, false)
	if not panel:
		return null
	return _find_by_class(panel, "ScrollContainer") as ScrollContainer


func test_the_crew_pane_requests_real_height_not_just_its_header() -> void:
	var ui := _make_ui()
	ui.setup_crew_selection([
		{"name": "Alice"}, {"name": "Bob"}, {"name": "Carol"},
		{"name": "Dave"}, {"name": "Erin"}, {"name": "Frank"},
	], 6)
	# Two frames: one for the container sort, one for the rects to settle.
	await get_tree().process_frame
	await get_tree().process_frame

	var scroll := _crew_scroll(ui)
	assert_object(scroll).override_failure_message(
		"the Crew pane must still hold a ScrollContainer — if this is null the pane was "
		+ "restructured and every assertion below stopped testing anything"
	).is_not_null()

	var floor_px: int = CREW_ROWS_VISIBLE * TOUCH_FLOOR
	assert_float(scroll.get_combined_minimum_size().y).override_failure_message(
		"the crew ScrollContainer reports a %.1f px minimum. A ScrollContainer "
		% scroll.get_combined_minimum_size().y
		+ "contributes ZERO on its scroll axis, so without an explicit floor the whole "
		+ "Crew pane asks for header height only and row 2 of the grid gives it exactly "
		+ "that — 'Select Crew' with no list beneath it."
	).is_greater_equal(float(floor_px))

	assert_float(scroll.size.y).override_failure_message(
		"the crew ScrollContainer RENDERED %.1f px tall, under the %d px floor "
		% [scroll.size.y, floor_px]
		+ "(%d rows x %d px touch target). Asserting the rendered rect rather than "
		% [CREW_ROWS_VISIBLE, TOUCH_FLOOR]
		+ "custom_minimum_size is the whole point of this case."
	).is_greater_equal(float(floor_px))


## ── LANDSCAPE: four even columns, the page on screen, and the gesture ────────────
##
## Device baseline (TB361FU, 2560x1600 physical at density 2.0): 1280x800 dp, which
## ResponsiveManager classifies WIDE, and a design space of 2560/1.16 x 1600/1.16 =
## 2207x1379 (SettingsManager.TARGET_EFFECTIVE; see verify_layout.gd's docblock).
const TABLET_DESIGN := Vector2i(2207, 1379)
const TABLET_DP := Vector2(1280, 800)
const DESKTOP_DESIGN := Vector2i(1655, 931)
const DESKTOP_DP := Vector2(1920, 1080)
const PHONE_LANDSCAPE_DESIGN := Vector2i(733, 338)
const PHONE_LANDSCAPE_DP := Vector2(851, 393)

var _rm: Node = null
var _rm_saved: Dictionary = {}


## Pin ResponsiveManager to what a device reports, and remember what to put back.
##
## ⚠ Pinned PER CASE rather than in before_test() on purpose: cases 1-5 above were
## written against whatever headless reports (window 0x0 -> MOBILE), and changing that
## for the whole suite would silently re-point five passing assertions at a different
## layout mode. The restore lives in after_test() so a failing case cannot leak state.
##
## The three members written here are plain vars (ResponsiveManager.gd:31-34), which is
## the same seam test_content_scale_formula.gd uses — there is no other way to tell a
## desktop test runner it is a 1280 dp tablet.
func _pin_responsive(dp: Vector2) -> void:
	_rm = get_node_or_null("/root/ResponsiveManager")
	if _rm == null:
		return
	if _rm_saved.is_empty():
		_rm_saved = {
			"size": _rm.current_viewport_size,
			"landscape": _rm.is_landscape,
			"breakpoint": _rm.current_breakpoint,
		}
	_rm.current_viewport_size = dp
	_rm.is_landscape = dp.x >= dp.y
	_rm.current_breakpoint = _rm._classify_breakpoint(int(dp.x))


func after_test() -> void:
	if _rm != null and not _rm_saved.is_empty():
		_rm.current_viewport_size = _rm_saved["size"]
		_rm.is_landscape = _rm_saved["landscape"]
		_rm.current_breakpoint = _rm_saved["breakpoint"]
	_rm_saved.clear()
	_rm = null


## The real mission a device run produced, via the shared populator so the sweeps and
## this suite cannot drift apart. Returns {} if the fixture is missing.
func _device_mission() -> Dictionary:
	var PopCls = load("res://tests/tools/screen_populator.gd")
	if PopCls == null:
		return {}
	return PopCls.new(get_tree().root).device_pre_battle_mission()


func _six_crew() -> Array:
	return [
		{"name": "Alice"}, {"name": "Bob"}, {"name": "Carol"},
		{"name": "Dave"}, {"name": "Erin"}, {"name": "Frank"},
	]


## Build the populated screen inside a SubViewport of `design` px. See the ⭐ note in
## the docblock for why the SubViewport is not optional.
func _ui_in_viewport(design: Vector2i, dp: Vector2) -> Dictionary:
	_pin_responsive(dp)
	var sv := SubViewport.new()
	sv.size = design
	add_child(sv)
	auto_free(sv)
	var ui: Control = PreBattleScene.instantiate()
	sv.add_child(ui)
	var mission: Dictionary = _device_mission()
	if not mission.is_empty():
		ui.setup_preview(mission.duplicate(true))
	ui.setup_crew_selection(_six_crew(), 6)
	var cond = mission.get("deployment_condition", {})
	if cond is Dictionary and not (cond as Dictionary).is_empty():
		ui.set_deployment_condition(cond)
	# Containers re-sort deferred and _open_touch_chain() is deferred by one frame, so a
	# measurement taken now would read a tree that is still settling.
	for _i in range(8):
		await get_tree().process_frame
	return {"sv": sv, "ui": ui, "mission": mission}


func _panes(ui: Control) -> GridContainer:
	var group: Node = ui.find_child("AdaptiveContent", true, false)
	if group == null:
		return null
	return group.get_node_or_null("PaneGrid") as GridContainer


func _toggle_buttons(ui: Control) -> Array:
	var out: Array = []
	_collect_toggle_buttons(ui.crew_selection_panel, out)
	return out


func test_the_group_asks_for_four_columns() -> void:
	var ui := _make_ui()
	assert_int(ui._panel_group.max_columns).override_failure_message(
		"PreBattleUI adds FOUR panes. At max_columns = 3 the fourth wraps onto its own "
		+ "grid row, and GridContainer gives that row the pane's own minimum plus an equal "
		+ "share of a surplus that is zero once ShortScreenScroll settles — so it lands "
		+ "below the fold. Same ceiling ShipManager.gd:104-108 already sets."
	).is_equal(4)


func test_four_even_columns_with_the_device_mission_at_the_tablet() -> void:
	var mission: Dictionary = _device_mission()
	assert_bool(mission.is_empty()).override_failure_message(
		"tests/fixtures/device/prebattle_rival_attack_mission_2026-09-06.json is missing. "
		+ "Without it this case would build the screen from a generated mission whose "
		+ "Mission pane is ~440 px shorter, which FITS the shipped 3-column layout — i.e. "
		+ "it would pass while proving nothing."
	).is_false()

	var built: Dictionary = await _ui_in_viewport(TABLET_DESIGN, TABLET_DP)
	var ui: Control = built["ui"]
	var grid := _panes(ui)
	assert_object(grid).is_not_null()

	assert_int(grid.columns).override_failure_message(
		"the four panes did not resolve to four columns at the tablet's design space "
		+ "(%dx%d, WIDE, room for %d)" % [TABLET_DESIGN.x, TABLET_DESIGN.y,
			ui._panel_group._columns_that_fit()]
	).is_equal(4)

	# Even columns are what the unwrapped description used to prevent: it reported its
	# whole text width (1134 px measured) as a minimum, and GridContainer hands an
	# oversize column exactly that and splits only the REST equally — 1136/328/328/327.
	var widths: Array[float] = []
	for pane in grid.get_children():
		if pane is Control:
			widths.append((pane as Control).get_global_rect().size.x)
	var lo: float = widths[0]
	var hi: float = widths[0]
	for w in widths:
		lo = minf(lo, w)
		hi = maxf(hi, w)
	assert_float(hi - lo).override_failure_message(
		"column widths %s span %.0f px. One child is reporting a minimum wider than an "
		% [str(widths), hi - lo]
		+ "even share — almost always a Label with autowrap OFF, whose minimum IS its "
		+ "text width."
	).is_less(8.0)

	# The finding itself: the crew list must be readable without scrolling to it.
	var buttons: Array = _toggle_buttons(ui)
	assert_int(buttons.size()).is_equal(6)
	var off := 0
	for b in buttons:
		var r: Rect2 = (b as Control).get_global_rect()
		if r.position.y < 0.0 or r.end.y > float(TABLET_DESIGN.y):
			off += 1
	assert_int(off).override_failure_message(
		"%d of 6 crew buttons are outside the %dx%d viewport. This is the Select Crew "
		% [off, TABLET_DESIGN.x, TABLET_DESIGN.y]
		+ "finding: the pane the player must act on is off screen in landscape."
	).is_equal(0)


func test_the_page_does_not_hang_off_the_side_edges() -> void:
	## Nothing on this screen scrolls sideways and PreBattle.tscn anchors its root
	## full-rect with grow BOTH ways, so horizontal overflow is split across both edges
	## and is never recoverable by the player. Measured before the description was
	## wrapped, with the device mission: 23 px at desktop, 96 px at phone landscape.
	for spec in [[DESKTOP_DESIGN, DESKTOP_DP, "desktop 1920x1080"],
			[PHONE_LANDSCAPE_DESIGN, PHONE_LANDSCAPE_DP, "phone landscape 851x393"]]:
		var design: Vector2i = spec[0]
		var built: Dictionary = await _ui_in_viewport(design, spec[1])
		var ui: Control = built["ui"]
		var mc: Control = ui.get_node_or_null("MarginContainer")
		assert_object(mc).is_not_null()
		var r: Rect2 = mc.get_global_rect()
		var over: float = maxf(-r.position.x, r.end.x - float(design.x))
		assert_float(over).override_failure_message(
			"%s: %.1f px of the page is off BOTH side edges (rect %s in a %dx%d viewport)."
			% [spec[2], over, str(r), design.x, design.y]
			+ " The usual cause is a Label with autowrap OFF reporting its full text width"
			+ " as a minimum and dragging the whole chain wider than the screen."
		).is_less(1.0)
		(built["sv"] as Node).queue_free()
		await get_tree().process_frame


func test_the_touch_chain_is_open_after_population() -> void:
	## The premise first: if the counter cannot see a STOP control, "nothing left to
	## open" below is vacuous and this case would pass with the fix deleted.
	var OpenerCls = load("res://src/ui/components/common/TouchScrollOpener.gd")
	var holder := Control.new()
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(holder)
	auto_free(holder)
	holder.add_child(PanelContainer.new())
	assert_int(OpenerCls.open_subtree(holder)).override_failure_message(
		"a fresh PanelContainer is MOUSE_FILTER_STOP by construction (its own constructor "
		+ "sets it), so the opener must report 1 here. It did not, so every count below "
		+ "would be meaningless."
	).is_equal(1)

	var built: Dictionary = await _ui_in_viewport(TABLET_DESIGN, TABLET_DP)
	var ui: Control = built["ui"]
	var scroll: ScrollContainer = ui.find_child("ContentScroll", true, false)
	assert_object(scroll).override_failure_message(
		"ShortScreenScroll did not build ContentScroll, so there is no outer scroll for a "
		+ "drag to reach and the rest of this case tests nothing."
	).is_not_null()

	assert_int(OpenerCls.open_subtree(scroll)).override_failure_message(
		"the screen left STOP controls under ContentScroll after all three setup calls, so "
		+ "a touch-drag over them dies before it reaches the scroll — Viewport stops "
		+ "Mouse/ScreenDrag/ScreenTouch at the first STOP control, and only WHEEL events "
		+ "are excepted. _open_touch_chain() must run after EVERY populating entry point."
	).is_equal(0)


func test_a_touch_drag_over_the_content_scrolls_the_page() -> void:
	## Premise: without touch emulation ScrollContainer never arms a drag, and every
	## result below would read as blocked — a false negative that looks like the defect.
	assert_bool(DisplayServer.is_touchscreen_available()).override_failure_message(
		"DisplayServer.is_touchscreen_available() is false, so ScrollContainer will not "
		+ "arm a touch drag and this case cannot measure anything. Its base implementation "
		+ "returns Input.is_emulating_touch_from_mouse(); the project sets "
		+ "input_devices/pointing/emulate_touch_from_mouse=true (project.godot:109)."
	).is_true()

	var built: Dictionary = await _ui_in_viewport(DESKTOP_DESIGN, DESKTOP_DP)
	var ui: Control = built["ui"]
	var sv: SubViewport = built["sv"]
	var scroll: ScrollContainer = ui.find_child("ContentScroll", true, false)
	assert_object(scroll).is_not_null()

	var bar: VScrollBar = scroll.get_v_scroll_bar()
	assert_float(bar.max_value - bar.page).override_failure_message(
		"the page does not overflow here, so there is nothing to scroll and a 'the drag "
		+ "worked' result would be indistinguishable from a drag that did nothing."
	).is_greater(1.0)

	var started := [false]
	var cb := func() -> void:
		started[0] = true
	scroll.scroll_started.connect(cb)

	scroll.scroll_vertical = 0
	await get_tree().process_frame
	var target: Control = ui.mission_info_panel
	var point: Vector2 = scroll.get_global_rect().intersection(
		target.get_global_rect()).get_center()
	await _drag(sv, point, -160.0)

	assert_float(float(scroll.scroll_vertical)).override_failure_message(
		"a drag over the Mission body left scroll_vertical at 0. The event died in the "
		+ "STOP chrome before reaching ContentScroll — which is exactly what the tablet "
		+ "reported (five swipe positions, byte-identical frames) and what "
		+ "_open_touch_chain() exists to fix."
	).is_greater(0.0)
	assert_bool(started[0]).override_failure_message(
		"scroll_vertical moved but scroll_started never fired, so the page was not scrolled "
		+ "by a TOUCH DRAG — that signal is emitted only for a drag on the scrollable area."
	).is_true()
	scroll.scroll_started.disconnect(cb)


func test_a_drag_that_starts_on_a_crew_button_scrolls_without_toggling_it() -> void:
	## The other half of opening the chrome: STOP -> PASS must not turn the crew list
	## into a minefield where scrolling past a name deselects it. BaseButton clears
	## status.press_attempt on NOTIFICATION_SCROLL_BEGIN, so a drag cancels the press —
	## and a plain tap must still toggle, or the list is unusable in the other direction.
	var built: Dictionary = await _ui_in_viewport(TABLET_DESIGN, TABLET_DP)
	var ui: Control = built["ui"]
	var sv: SubViewport = built["sv"]
	var scroll: ScrollContainer = ui.find_child("ContentScroll", true, false)
	var buttons: Array = _toggle_buttons(ui)
	assert_int(buttons.size()).is_equal(6)

	var target: Button = null
	for b in buttons:
		if scroll.get_global_rect().encloses((b as Control).get_global_rect()):
			target = b
			break
	assert_object(target).override_failure_message(
		"no crew button sits wholly inside ContentScroll, so a drag starting on one cannot "
		+ "be measured here."
	).is_not_null()

	var was: bool = target.button_pressed
	var before: float = float(scroll.scroll_vertical)
	await _drag(sv, target.get_global_rect().get_center(), -120.0)
	assert_bool(target.button_pressed).override_failure_message(
		"dragging the page from a crew button toggled that crew member. Scrolling a list "
		+ "must never change the deployment."
	).is_equal(was)
	assert_float(float(scroll.scroll_vertical)).override_failure_message(
		"a drag that started on a crew button did not scroll the page."
	).is_not_equal(before)

	# ... and a tap still selects.
	var deployed_before: String = str(ui._deploy_label.text)
	await _tap(sv, target.get_global_rect().get_center())
	assert_bool(target.button_pressed).override_failure_message(
		"the crew button no longer responds to a tap. Opening STOP -> PASS must leave the "
		+ "control's own handling intact — PASS still delivers the event to it FIRST."
	).is_not_equal(was)
	assert_str(str(ui._deploy_label.text)).override_failure_message(
		"the deployment counter did not follow the toggle (still %s)" % deployed_before
	).is_not_equal(deployed_before)


## A synthetic touch-drag. `in_local_coords = true` because the points come from
## get_global_rect() inside the SubViewport, which IS its local space.
func _drag(sv: SubViewport, from: Vector2, dy: float) -> void:
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = from
	press.global_position = from
	sv.push_input(press, true)
	await get_tree().process_frame
	var pos := from
	var step := Vector2(0.0, dy / 8.0)
	for _i in range(8):
		pos += step
		var mm := InputEventMouseMotion.new()
		mm.position = pos
		mm.global_position = pos
		mm.relative = step
		mm.button_mask = MOUSE_BUTTON_MASK_LEFT
		sv.push_input(mm, true)
		await get_tree().process_frame
	# Hold still so the drag speed decays: releasing while it is non-zero starts INERTIA
	# and the scroll position keeps moving after the assertion reads it.
	for _j in range(14):
		await get_tree().process_frame
	var rel := InputEventMouseButton.new()
	rel.button_index = MOUSE_BUTTON_LEFT
	rel.pressed = false
	rel.position = pos
	rel.global_position = pos
	sv.push_input(rel, true)
	await get_tree().process_frame
	await get_tree().process_frame


func _tap(sv: SubViewport, at: Vector2) -> void:
	for pressed in [true, false]:
		var ev := InputEventMouseButton.new()
		ev.button_index = MOUSE_BUTTON_LEFT
		ev.pressed = pressed
		ev.position = at
		ev.global_position = at
		sv.push_input(ev, true)
		await get_tree().process_frame
	await get_tree().process_frame
