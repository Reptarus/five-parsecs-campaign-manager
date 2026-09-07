extends SceneTree
## HEADLESS geometry + GESTURE probe for PreBattleUI in landscape.
##
## Run:
##   godot --headless --path <root> --script res://tests/tools/probe_prebattle_landscape.gd
##   ... -- campaign=user://saves/x.save        (optional: real crew instead of generated)
##   ... -- mission=C:/path/to/a/pulled.save    (optional: a different device mission)
##   ... -- cols=3                              (the DETECTION arm; see below)
##
## ── WHY THIS IS HEADLESS, when every other geometry harness here is not ──────────
##
## `tests/tools/verify_layout.gd` must be windowed because it resizes the real WINDOW,
## and DisplayServer returns dummy values under --headless so window_set_size() does
## nothing. This probe sidesteps that entirely: it builds the screen inside a
## **SubViewport sized to the design space** and pins ResponsiveManager's plain members
## to what the device reports. `AdaptivePanelGroup._columns_that_fit()` reads
## `get_viewport().get_visible_rect().size.x`, which for a node under a SubViewport is
## the SubViewport's size — so a 2207x1379 SubViewport reproduces the tablet's column
## arithmetic with no window at all.
##
## ⚠ That is also the trap: a screen built as a direct child of the tree root measures
## the 1080 square stretch base (-> 3 columns) no matter what you asked for. Anything
## asserting a rendered column count MUST build under a SubViewport.
##
## ── AND WHY THE GESTURE IS MEASURABLE HERE AT ALL ───────────────────────────────
##
## CLAUDE.md records that "Godot does not deliver InputEvents in headless mode", and
## that is true of the OS input path. It is NOT true of `Viewport.push_input()`, which
## the 4.6 docs describe as locally applying an event and dispatching it through
## `Control._gui_input()` — the exact chain MOUSE_FILTER_STOP interrupts. And
## `ScrollContainer`'s touch-drag runs off EMULATED MOUSE events: it arms on a LEFT
## press when `DisplayServer.is_touchscreen_available()` is true, whose base
## implementation returns `Input.is_emulating_touch_from_mouse()` — and this project
## sets `input_devices/pointing/emulate_touch_from_mouse=true` (project.godot:109).
## So a synthetic mouse drag takes the real touch path, `scroll_started` fires, and the
## whole STOP-vs-PASS question is answerable at the desk.
##
## ⚠ What this still cannot answer is the DEVICE's own input stack — the real
## digitiser, `emulate_mouse_from_touch`, and the physical deadzone. Deploy #27 is the
## authority for that. This probe is the reproduction, not the verdict.
##
## ── WHAT IT PRINTS ──────────────────────────────────────────────────────────────
## Per configuration: the resolved column count, every pane's minimum and rect, the
## outer scroll's mode/need/budget, whether the crew list is on screen without
## scrolling, the root MarginContainer's overflow on all four sides, a census of STOP
## controls left under ContentScroll, and a before/after drag measurement.
##
## Harness constraints inherited from verify_layout.gd, do not relax:
##   1. All work runs in _process() on frame >= 2, never _initialize(): under --script
##      the autoloads exist but root.is_inside_tree() is false during _initialize().
##   2. NOTHING is preload()ed — several production scripts reference bare autoload
##      identifiers, which are not registered as globals when a --script main loop is
##      compiled. Runtime load() from inside _process() works.

const PATH := "res://src/ui/screens/battle/PreBattle.tscn"
## Mirrors TouchScrollOpener._SKIP so the census counts what the opener would open.
const SKIP := ["ScrollContainer", "Tree", "ItemList", "TextEdit", "RichTextLabel", "GraphEdit"]
const EPS := 0.5

## [design_w, design_h, dp_w, dp_h, label].
## design = window px / SettingsManager.TARGET_EFFECTIVE (1.16, T11-47); dp = window px /
## screen scale, which is what ResponsiveManager classifies. The tablet is 2560x1600
## PHYSICAL at density 2.0, so 1280x800 dp and a 2207x1379 design space.
const CONFIGS := [
	[2207, 1379, 1280, 800, "TB361FU landscape 2560x1600 @2.0 = 1280x800dp"],
	[1655, 931, 1920, 1080, "desktop 1920x1080 @1.0"],
	[1103, 689, 1280, 800, "1280x800 window @1.0 (a SMALLER screen, not the tablet)"],
	[733, 338, 851, 393, "phone landscape 851x393 @1.0"],
]

var _frame := 0
var _started := false
var _scene: PackedScene = null
var _pop = null
var _opener = null
var _rm: Node = null
var _fail := 0
var _force_cols := 0
var _mission: Dictionary = {}
var _crew: Array = []
var _deploy: int = 6
var _mission_label := ""


func _process(_delta: float) -> bool:
	_frame += 1
	if _frame < 2 or _started:
		return false
	_started = true
	_run()
	return false


func _run() -> void:
	_read_args()
	print("=== PREBATTLE LANDSCAPE PROBE ===")
	print("display_server=%s touchscreen_available=%s emulate_touch_from_mouse=%s deadzone=%s" % [
		DisplayServer.get_name(), str(DisplayServer.is_touchscreen_available()),
		str(ProjectSettings.get_setting("input_devices/pointing/emulate_touch_from_mouse", false)),
		str(ProjectSettings.get_setting("gui/common/default_scroll_deadzone", -1))])
	if not DisplayServer.is_touchscreen_available():
		# Instrument the premise: without this the drag arms nothing and every gesture
		# reads DEAD, which looks exactly like the defect this probe exists to detect.
		print("!! is_touchscreen_available() is FALSE — ScrollContainer will not arm a "
			+ "touch drag, so every gesture result below would be a FALSE NEGATIVE.")
		_fail += 1
	_stub_legal_consent()
	_load_requested_campaign()
	_rm = root.get_node_or_null("/root/ResponsiveManager")
	if _rm == null:
		print("!! ResponsiveManager autoload missing")
		quit(2)
		return
	_scene = load(PATH)
	_pop = load("res://tests/tools/screen_populator.gd").new(root)
	_opener = load("res://src/ui/components/common/TouchScrollOpener.gd")
	_resolve_mission()
	print("campaign: %s" % _campaign_state())
	print("mission:  %s" % _mission_label)
	print("arm:      %s" % ("max_columns FORCED to %d (DETECTION ARM)" % _force_cols
		if _force_cols > 0 else "as shipped"))
	# Premise for the census: a fresh PanelContainer is STOP, so the counter must see 1.
	var holder := Control.new()
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(holder)
	holder.add_child(PanelContainer.new())
	var premise: int = _opener.open_subtree(holder)
	print("premise:  open_subtree(one fresh PanelContainer) -> %d (expect 1)" % premise)
	if premise != 1:
		print("!! the STOP counter is broken; every 'nothing left to open' below is vacuous")
		_fail += 1
	holder.queue_free()

	for cfg in CONFIGS:
		await _one(cfg)

	print("\n================ RESULT ================")
	print("PREBATTLE LANDSCAPE PROBE: %s (fail=%d)" % [
		"PASS" if _fail == 0 else "FAIL", _fail])
	quit(1 if _fail > 0 else 0)


func _read_args() -> void:
	for arg in OS.get_cmdline_user_args():
		var a := String(arg).strip_edges()
		if a.begins_with("cols="):
			_force_cols = int(a.substr("cols=".length()))


## Prefer an explicitly named device save, else the committed device fixture, else the
## generated mission — and SAY WHICH, because the generated one cannot reproduce the
## defect (its Mission pane is ~440 px shorter).
func _resolve_mission() -> void:
	var override := ""
	for arg in OS.get_cmdline_user_args():
		if String(arg).begins_with("mission="):
			override = String(arg).substr("mission=".length())

	if not override.is_empty():
		if not FileAccess.file_exists(override):
			print("!! mission file does not exist: %s" % override)
			_fail += 1
		else:
			var parsed = JSON.parse_string(FileAccess.get_file_as_string(override))
			if parsed is Dictionary:
				var p = (parsed as Dictionary).get("progress", {})
				var m = (p as Dictionary).get("current_mission", {}) if p is Dictionary else {}
				if m is Dictionary and not (m as Dictionary).is_empty():
					_mission = _pop._restore_ints(m)
					_mission_label = "OVERRIDE %s (%d keys)" % [
						override.get_file(), _mission.size()]

	if _mission.is_empty():
		_mission = _pop.device_pre_battle_mission()
		if not _mission.is_empty():
			_mission_label = "committed device fixture (%d keys, %d-char briefing)" % [
				_mission.size(), str(_mission.get("description", "")).length()]

	if _mission.is_empty():
		_mission = (_pop.battle_fixture().get("mission", {}) as Dictionary).duplicate(true)
		_mission_label = ("GENERATED (%d keys) — the device fixture is missing, so the "
			+ "Mission pane measures short and the landscape defect will NOT reproduce") % _mission.size()

	_crew = _pop.campaign_crew()
	if _crew.is_empty():
		_crew = _pop.battle_fixture().get("crew", [])
	var gs := root.get_node_or_null("/root/GameState")
	if gs != null and gs.has_method("get_campaign_crew_size"):
		_deploy = maxi(1, int(gs.get_campaign_crew_size()))


func _one(cfg: Array) -> void:
	var w: int = cfg[0]
	var h: int = cfg[1]
	_pin_rm(cfg[2], cfg[3])
	var sv := SubViewport.new()
	sv.size = Vector2i(w, h)
	root.add_child(sv)
	_pop.populate_pre(PATH)
	var inst: Node = _scene.instantiate()
	sv.add_child(inst)
	if inst is CanvasItem and not (inst as CanvasItem).visible:
		(inst as CanvasItem).show()
	print("\n===== %s | design %dx%d =====" % [cfg[4], w, h])

	var group: Node = inst.find_child("AdaptiveContent", true, false)
	if group == null:
		print("!! AdaptiveContent not found — _setup_adaptive_panels() did not run")
		_fail += 1
		inst.queue_free()
		sv.queue_free()
		await process_frame
		return
	if _force_cols > 0:
		group.max_columns = _force_cols

	# The three calls CampaignTurnController makes, in its order.
	inst.setup_preview(_mission.duplicate(true))
	inst.setup_crew_selection(_crew.duplicate(true), _deploy)
	var cond = _mission.get("deployment_condition", {})
	if not (cond is Dictionary) or (cond as Dictionary).is_empty():
		var terr = _mission.get("terrain", {})
		if terr is Dictionary:
			cond = (terr as Dictionary).get("deployment_condition", {})
	if cond is Dictionary and not (cond as Dictionary).is_empty():
		inst.set_deployment_condition(cond)

	_apply_runtime_overlay_net(inst)
	await _settle(inst)
	_pin_rm(cfg[2], cfg[3])
	await _settle(inst)

	_measure(sv, inst, group, w, h)
	await _gesture(sv, inst)

	inst.queue_free()
	await process_frame
	sv.queue_free()
	await process_frame


## ResponsiveManager classifies DENSITY-INDEPENDENT window size, which a SubViewport
## cannot supply, so the three members it derives are written directly. This is the same
## seam tests/unit/test_content_scale_formula.gd uses, and it exists because those really
## are plain members — see ResponsiveManager.gd:31-34.
func _pin_rm(dp_w: int, dp_h: int) -> void:
	_rm.current_viewport_size = Vector2(dp_w, dp_h)
	_rm.is_landscape = dp_w >= dp_h
	_rm.current_breakpoint = _rm._classify_breakpoint(dp_w)
	_rm._apply_theme_font_scale()


func _r(r: Rect2) -> String:
	return "(%.0f,%.0f %.0fx%.0f)" % [r.position.x, r.position.y, r.size.x, r.size.y]


func _v(v: Vector2) -> String:
	return "%.0fx%.0f" % [v.x, v.y]


func _measure(sv: SubViewport, inst: Node, group: Node, w: int, h: int) -> void:
	var ds := Vector2(w, h)
	var grid: GridContainer = group.get_node_or_null("PaneGrid")
	var tabs: Control = group.get_node_or_null("PaneTabBar")
	var scroll: ScrollContainer = inst.find_child("ContentScroll", true, false)
	var column: Control = scroll.get_node_or_null("ScrollColumn") if scroll else null
	var mc: Control = inst.get_node_or_null("MarginContainer")

	print("rm=%s eff_cols=%d landscape=%s | columns_that_fit=%d | subviewport=%s" % [
		_rm.get_breakpoint_name(), _rm.get_effective_columns(), str(_rm.is_landscape),
		group._columns_that_fit(), _r(sv.get_visible_rect())])
	if grid == null:
		print("!! PaneGrid missing")
		_fail += 1
		return
	print("grid.columns=%d tabs_visible=%s grid.min=%s grid.rect=%s" % [
		grid.columns, str(tabs.visible if tabs else false),
		_v(grid.get_combined_minimum_size()), _r(grid.get_global_rect())])
	var widths: Array[float] = []
	for pane in grid.get_children():
		if pane is Control:
			var pr: Rect2 = (pane as Control).get_global_rect()
			widths.append(pr.size.x)
			print("  pane %-12s min=%-10s rect=%-22s" % [
				pane.name, _v((pane as Control).get_combined_minimum_size()), _r(pr)])
	if widths.size() >= 2:
		var lo: float = widths[0]
		var hi: float = widths[0]
		for x in widths:
			lo = minf(lo, x)
			hi = maxf(hi, x)
		print("  column width spread: %.0f .. %.0f (%.0f px)" % [lo, hi, hi - lo])

	if scroll:
		var need: float = column.get_combined_minimum_size().y if column else -1.0
		print("ContentScroll mode=%s rect=%s | need=%.1f budget=%.1f overflow=%.1f" % [
			_mode_name(scroll.vertical_scroll_mode), _r(scroll.get_global_rect()),
			need, scroll.size.y, need - scroll.size.y])

	var crew_scroll: ScrollContainer = _crew_scroll(inst)
	if crew_scroll:
		var cr: Rect2 = crew_scroll.get_global_rect()
		var buttons: Array = []
		_collect_toggle_buttons(inst.crew_selection_panel, buttons)
		var visible_n := 0
		for b in buttons:
			var br: Rect2 = (b as Control).get_global_rect()
			if br.position.y >= -EPS and br.end.y <= ds.y + EPS:
				visible_n += 1
		# ⚠ The CONTAINER legitimately runs past the fold once it is stretched to fill a
		# tall grid row; what matters is where its TOP is and how many rows are readable
		# without scrolling. Testing the container's bottom would report the fixed
		# layout as broken.
		print("crew list: top=%.0f (%s) | %d of %d buttons inside the viewport | first=%s last=%s" % [
			cr.position.y,
			"ABOVE THE FOLD" if cr.position.y < ds.y else "BELOW THE FOLD",
			visible_n, buttons.size(),
			_r((buttons[0] as Control).get_global_rect()) if not buttons.is_empty() else "-",
			_r((buttons[buttons.size() - 1] as Control).get_global_rect()) if not buttons.is_empty() else "-"])
		# THE FINDING ITSELF, asserted rather than merely printed.
		#
		# ⚠ Scoped to the configurations with ROOM for one column per pane, measured from
		# the viewport — never from `grid.columns`, which is the thing under test. Scoping
		# on the resolved count was the first version of this check and it was worthless:
		# forcing max_columns back to 3 made the guard skip itself, so the detection arm
		# reported PASS while printing 1 of 6 buttons on screen. A check whose precondition
		# is the defect can never see the defect.
		#
		# On a genuinely smaller screen (the 1103x689 and 733x338 rows) the fit clamp
		# drops to 3 or 2 columns, an orphan row is unavoidable, and the page scrolling to
		# it is CORRECT — failing there would demand a layout the viewport cannot hold.
		var panes: int = grid.get_child_count()
		var has_room: bool = group._columns_that_fit() >= panes \
			and _rm.get_effective_columns() >= panes
		if has_room and visible_n < buttons.size():
			print("!! %d of %d crew buttons are off-screen in a %d-column layout — this is "
				% [buttons.size() - visible_n, buttons.size(), grid.columns]
				+ "the Select Crew finding: the player cannot see the list to act on it")
			_fail += 1
		if inst._deploy_label:
			var dr: Rect2 = (inst._deploy_label as Control).get_global_rect()
			print("deploy label '%s' rect=%s on_screen=%s" % [
				inst._deploy_label.text, _r(dr),
				str(dr.position.y >= -EPS and dr.end.y <= ds.y + EPS)])

	var footer: Control = inst.find_child("FooterPanel", true, false)
	if footer:
		var fr: Rect2 = footer.get_global_rect()
		print("footer rect=%s on_screen=%s" % [
			_r(fr), str(fr.position.y >= -EPS and fr.end.y <= ds.y + EPS)])

	if mc:
		var r: Rect2 = mc.get_global_rect()
		var offs := [-r.position.x, r.end.x - ds.x, -r.position.y, r.end.y - ds.y]
		print("root MarginContainer rect=%s min=%s | overflow L=%.1f R=%.1f T=%.1f B=%.1f" % [
			_r(r), _v(mc.get_combined_minimum_size()), offs[0], offs[1], offs[2], offs[3]])
		# HORIZONTAL overflow is never legitimate: nothing here scrolls sideways, and the
		# root grows BOTH ways, so it hangs off each edge equally. Vertical overflow IS
		# legitimate — that is what ContentScroll is for.
		if offs[0] > EPS or offs[1] > EPS:
			print("!! %.1f px of this page is off the LEFT and RIGHT edges" % maxf(offs[0], offs[1]))
			_fail += 1

	if scroll:
		var hist := {}
		var n := _census(scroll, hist)
		print("STOP controls left under ContentScroll (outside _SKIP): %d %s" % [n, str(hist)])
		if n > 0:
			print("!! the screen did not open its own touch chain")
			_fail += 1


func _mode_name(m: int) -> String:
	match m:
		ScrollContainer.SCROLL_MODE_DISABLED: return "DISABLED"
		ScrollContainer.SCROLL_MODE_AUTO: return "AUTO"
		ScrollContainer.SCROLL_MODE_SHOW_ALWAYS: return "SHOW_ALWAYS"
		ScrollContainer.SCROLL_MODE_SHOW_NEVER: return "SHOW_NEVER"
	return str(m)


func _gesture(sv: SubViewport, inst: Node) -> void:
	var scroll: ScrollContainer = inst.find_child("ContentScroll", true, false)
	if scroll == null:
		return
	var bar: VScrollBar = scroll.get_v_scroll_bar()
	var range_px: float = bar.max_value - bar.page
	if range_px <= EPS:
		print("gesture: this shape does not overflow (range %.1f px), nothing to scroll" % range_px)
		return

	var started := [false]
	var cb := func() -> void:
		started[0] = true
	scroll.scroll_started.connect(cb)

	for probe in [["Mission body", inst.mission_info_panel], ["Forces table", inst.enemy_info_panel]]:
		scroll.scroll_vertical = 0
		await process_frame
		await process_frame
		started[0] = false
		var pt: Vector2 = _point_inside(probe[1], scroll)
		var before: float = scroll.scroll_vertical
		await _drag(sv, pt, -160.0, 8)
		var after: float = scroll.scroll_vertical
		var moved: bool = absf(after - before) > EPS
		print("gesture over %-13s at (%.0f,%.0f): scroll_vertical %.1f -> %.1f  scroll_started=%s  %s" % [
			probe[0], pt.x, pt.y, before, after, str(started[0]),
			"MOVED" if moved else "DEAD — the drag never reached ContentScroll"])
		if not moved:
			_fail += 1

	# A drag that STARTS on a crew toggle must scroll the page and leave the toggle
	# alone (BaseButton clears press_attempt on NOTIFICATION_SCROLL_BEGIN); a tap on the
	# same button must still toggle it. Both halves, or "it scrolls now" hides a
	# regression where the list can no longer be used.
	scroll.scroll_vertical = int(bar.max_value)
	await process_frame
	await process_frame
	var buttons: Array = []
	_collect_toggle_buttons(inst.crew_selection_panel, buttons)
	var target: Button = null
	var sr: Rect2 = scroll.get_global_rect()
	for b in buttons:
		if sr.encloses((b as Control).get_global_rect()):
			target = b
			break
	if target == null:
		print("crew-button check: no button fully inside ContentScroll here; skipped")
	else:
		var was: bool = target.button_pressed
		var sv_before: float = scroll.scroll_vertical
		await _drag(sv, target.get_global_rect().get_center(), 120.0, 8)
		var ok_drag: bool = absf(scroll.scroll_vertical - sv_before) > EPS \
			and target.button_pressed == was
		print("drag STARTING on crew button '%s': scroll %.1f -> %.1f, pressed %s -> %s  %s" % [
			target.text.replace("\n", " "), sv_before, scroll.scroll_vertical,
			str(was), str(target.button_pressed),
			"OK" if ok_drag else "!! a drag over the list toggled a crew member"])
		if not ok_drag:
			_fail += 1
		scroll.scroll_vertical = int(bar.max_value)
		await process_frame
		await process_frame
		was = target.button_pressed
		await _tap(sv, target.get_global_rect().get_center())
		var ok_tap: bool = target.button_pressed != was
		print("TAP on crew button '%s': pressed %s -> %s | '%s'  %s" % [
			target.text.replace("\n", " "), str(was), str(target.button_pressed),
			inst._deploy_label.text if inst._deploy_label else "",
			"OK" if ok_tap else "!! the button no longer responds to a tap"])
		if not ok_tap:
			_fail += 1

	scroll.scroll_started.disconnect(cb)


## Centre of the part of `ctl` that is inside the scroll's rect, so the synthetic finger
## lands on something actually visible rather than on clipped content.
func _point_inside(ctl: Control, scroll: ScrollContainer) -> Vector2:
	var sr: Rect2 = scroll.get_global_rect()
	if ctl == null:
		return sr.get_center()
	var ix: Rect2 = sr.intersection(ctl.get_global_rect())
	if ix.size.x <= 0.0 or ix.size.y <= 0.0:
		return sr.get_center()
	return ix.get_center()


func _drag(sv: SubViewport, from: Vector2, dy: float, steps: int) -> void:
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = from
	press.global_position = from
	sv.push_input(press, true)
	await process_frame
	var pos := from
	var step := Vector2(0.0, dy / float(steps))
	for _i in range(steps):
		pos += step
		var mm := InputEventMouseMotion.new()
		mm.position = pos
		mm.global_position = pos
		mm.relative = step
		mm.button_mask = MOUSE_BUTTON_MASK_LEFT
		sv.push_input(mm, true)
		await process_frame
	# Hold still so the container's drag speed decays to zero: on release a non-zero
	# speed starts INERTIA, and the position then keeps moving after the measurement.
	for _j in range(14):
		await process_frame
	var rel := InputEventMouseButton.new()
	rel.button_index = MOUSE_BUTTON_LEFT
	rel.pressed = false
	rel.position = pos
	rel.global_position = pos
	sv.push_input(rel, true)
	await process_frame
	await process_frame


func _tap(sv: SubViewport, at: Vector2) -> void:
	for pressed in [true, false]:
		var ev := InputEventMouseButton.new()
		ev.button_index = MOUSE_BUTTON_LEFT
		ev.pressed = pressed
		ev.position = at
		ev.global_position = at
		sv.push_input(ev, true)
		await process_frame
	await process_frame


func _census(node: Node, hist: Dictionary) -> int:
	var n := 0
	for c in node.get_children():
		if c is Control and (c as Control).mouse_filter == Control.MOUSE_FILTER_STOP:
			var skip := false
			for cls: String in SKIP:
				if c.is_class(cls):
					skip = true
					break
			if not skip:
				n += 1
				hist[c.get_class()] = int(hist.get(c.get_class(), 0)) + 1
		n += _census(c, hist)
	return n


func _crew_scroll(inst: Node) -> ScrollContainer:
	var panel: Node = inst.find_child("CrewSelection", true, false)
	if panel == null:
		return null
	return _find_by_class(panel, "ScrollContainer") as ScrollContainer


func _find_by_class(node: Node, klass: String) -> Node:
	for child in node.get_children():
		if child.is_class(klass):
			return child
		var found := _find_by_class(child, klass)
		if found:
			return found
	return null


func _collect_toggle_buttons(node: Node, out: Array) -> void:
	if node == null:
		return
	for child in node.get_children():
		if child is Button and (child as Button).toggle_mode:
			out.append(child)
		_collect_toggle_buttons(child, out)


## Reproduce what the running app does to every screen it navigates to (see
## verify_layout.gd's note): SettingsOverlay reserves its floating-button band.
func _apply_runtime_overlay_net(inst: Node) -> void:
	var so := root.get_node_or_null("/root/SettingsOverlay")
	if so == null:
		return
	if so.has_method("_update_visibility"):
		so._update_visibility()
	if so.has_method("reserve_band_on"):
		so.reserve_band_on(inst)


## Wait until the geometry STOPS CHANGING. Panels populate from call_deferred and
## ScrollContainers re-sort after their content arrives, so a fixed frame count reads
## transient rects and reports overflow that does not survive the next frame.
func _settle(inst: Node) -> void:
	var last := ""
	var stable := 0
	for _i in range(30):
		await process_frame
		var sig := _geometry_signature(inst)
		if sig == last:
			stable += 1
			if stable >= 3:
				return
		else:
			stable = 0
			last = sig


func _geometry_signature(inst: Node) -> String:
	var acc := 0.0
	var n := 0
	var stack: Array = [inst]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		for c in node.get_children():
			stack.append(c)
		if node is Control and (node as Control).is_visible_in_tree():
			var r: Rect2 = (node as Control).get_global_rect()
			acc += r.position.x + r.position.y * 3.0 + r.size.x * 7.0 + r.size.y * 11.0
			n += 1
	return "%d:%.2f" % [n, acc]


func _load_requested_campaign() -> void:
	var wanted := ""
	for arg in OS.get_cmdline_user_args():
		if String(arg).begins_with("campaign="):
			wanted = String(arg).substr("campaign=".length())
	if wanted.is_empty():
		return
	var gs := root.get_node_or_null("/root/GameState")
	if gs == null or not gs.has_method("load_campaign"):
		print("campaign load requested but GameState is unavailable: %s" % wanted)
		return
	if not FileAccess.file_exists(wanted):
		print("campaign load requested but file does not exist: %s" % wanted)
		return
	gs.load_campaign(wanted)


func _campaign_state() -> String:
	var gs := root.get_node_or_null("/root/GameState")
	if gs == null:
		return "GameState autoload missing"
	var campaign = null
	if gs.has_method("get_current_campaign"):
		campaign = gs.get_current_campaign()
	if campaign == null:
		return "NO CAMPAIGN loaded (crew comes from the generated fixture)"
	var id := ""
	if "campaign_name" in campaign:
		id = str(campaign.campaign_name)
	return "loaded: %s" % (id if not id.is_empty() else "<unnamed>")


## Satisfy the legal gate IN MEMORY ONLY for the duration of the probe.
## ⚠ It must NEVER call accept_eula() / accept_privacy(), which write
## user://legal_consent.cfg and would record a consent no human ever gave.
func _stub_legal_consent() -> void:
	var lcm := root.get_node_or_null("/root/LegalConsentManager")
	if lcm == null:
		return
	lcm.eula_accepted = true
	lcm.eula_accepted_version = lcm.EULA_VERSION
	lcm.privacy_accepted = true
	lcm.privacy_accepted_version = lcm.PRIVACY_VERSION
