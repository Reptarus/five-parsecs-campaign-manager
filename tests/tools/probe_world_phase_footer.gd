extends SceneTree

## T11-40 — is the World Phase nav actually squeezed, and on WHICH step?
##
## The populated layout sweep passes this screen at all six sizes, including the
## 48dp touch floor that T11-40's 37px button should trip. Two candidate reasons,
## and they need different fixes, so this measures rather than assumes:
##   (a) the defect does not reproduce at these sizes, or
##   (b) the screen is parked on a SHORT step, so the tall case is never exercised
##       — which would make the populator a half-fix: populated, wrong step.
##
## Reports the visible step, every VBox child's rect, and each nav/footer button's
## height in dp against the same TOUCH_FLOOR_DP the sweep uses.
##
## ⚠ WINDOWED on purpose. --headless gives a dummy DisplayServer: window_set_size()
## does nothing and every rect measures at the default. The first run of this probe
## came back `window.size = (1, 1)` for exactly that reason.
##
##   Godot_console.exe --path <project> --script tests/tools/probe_world_phase_footer.gd \
##       -- campaign=user://saves/<file>.save

const SCENE := "res://src/ui/screens/world/WorldPhaseController.tscn"
const TOUCH_FLOOR_DP := 48.0
## Matches SettingsManager.TARGET_EFFECTIVE; the sweep derives this per measurement
## rather than hardcoding it, and so does _dp() below.
## ⚠ 1280x800 is the sweep's "tablet landscape" row and it is NOT this tablet any
## more. The sweep's premise (a desktop window sized to the device's dp reproduces its
## layout arithmetic) held while content_scale still multiplied by display density; the
## T11-07 fix REMOVED that term, so the device now renders at 0.7830 where this desktop
## computes 1.5660 - exactly 2x - and its design space is window_PIXELS / 1.16, not
## dp / 1.16. The TB361FU is 2560x1600 physical, so its real design space is ~2207x1379.
const SIZES: Array = [
	[1280, 800, "sweep row: tablet landscape (1280x800 dp)"],
	[2560, 1600, "TRUE device px: TB361FU landscape"],
	[1600, 2560, "TRUE device px: TB361FU portrait"],
]

var _frame: int = 0
var _started: bool = false


func _process(_d: float) -> bool:
	# Harness constraint inherited from verify_layout: root.is_inside_tree() is false
	# during _initialize() under --script, so every "/root/X" lookup errors there.
	#
	# ⚠ NEVER return true here. _run() is a coroutine (it awaits frames between
	# resizes), and returning true quits the SceneTree on the spot - the first version
	# of this probe printed its header and exited 0 with no measurements at all, which
	# reads exactly like a clean pass. _run() calls quit() when it is genuinely done.
	_frame += 1
	if _frame < 2 or _started:
		return false
	_started = true
	_run()
	return false


func _run() -> void:
	_load_campaign()
	var populator = load("res://tests/tools/screen_populator.gd").new(root)
	print("=== T11-40  World Phase nav geometry (WINDOWED) ===")
	print("populate: %s" % populator.state_line())

	for spec: Array in SIZES:
		DisplayServer.window_set_size(Vector2i(int(spec[0]), int(spec[1])))
		await process_frame
		await process_frame
		await _measure(str(spec[2]), populator)
	quit(0)


func _load_campaign() -> void:
	var wanted := ""
	for arg in OS.get_cmdline_user_args():
		if String(arg).begins_with("campaign="):
			wanted = String(arg).substr("campaign=".length())
	if wanted.is_empty() or not FileAccess.file_exists(wanted):
		print("!! no campaign - every step pane will be EMPTY and this proves nothing")
		return
	var gs := root.get_node_or_null("/root/GameState")
	if gs and gs.has_method("load_campaign"):
		gs.load_campaign(wanted)


func _measure(label: String, populator) -> void:
	var packed: PackedScene = load(SCENE)
	var inst: Node = packed.instantiate()
	root.add_child(inst)
	await process_frame
	populator.populate_post(inst, SCENE)
	await process_frame
	await process_frame
	await process_frame

	var vp: Vector2 = root.get_visible_rect().size
	var dp_ratio: float = float(DisplayServer.window_get_size().x) / maxf(1.0, vp.x)
	print("")
	print("--- %s | window %s | design %s | dp ratio %.4f ---"
		% [label, str(DisplayServer.window_get_size()), str(vp), dp_ratio])

	# WHICH STEP is on screen? An empty or short step never exercises T11-40.
	var scroll: Node = inst.get_node_or_null("MarginContainer/VBoxContainer/ContentScroll")
	var host: Node = scroll.get_node_or_null("ContentColumn") if scroll else null
	var phase_c: Node = null
	if host:
		phase_c = host.get_node_or_null("PhaseContainer")
	if phase_c == null:
		phase_c = inst.get_node_or_null("MarginContainer/VBoxContainer/PhaseContainer")
	var ps: Node = phase_c.get_node_or_null("PhaseScroll") if phase_c else null
	if ps:
		for step: Node in ps.get_children():
			if step is Control and (step as Control).visible:
				var sc: Control = step
				print("  VISIBLE STEP: %-24s rect %s  min.y %.1f"
					% [sc.name, str(sc.size), sc.get_combined_minimum_size().y])
	else:
		print("  !! PhaseScroll not found (layout restructured)")

	var vbox: Node = inst.get_node_or_null("MarginContainer/VBoxContainer")
	print("  VBox children (tight layout puts the nav INSIDE ContentScroll):")
	for c: Node in vbox.get_children():
		if c is Control:
			print("     %-16s y %.1f..%.1f" % [c.name, (c as Control).position.y,
				(c as Control).position.y + (c as Control).size.y])

	# The buttons T11-40 named, wherever the layout put them.
	for nm: String in ["NextButton", "BackButton", "BackToDashboardButton",
			"ProceedToBattleButton"]:
		var b: Node = inst.find_child(nm, true, false)
		if not (b is Control):
			continue
		var bc: Control = b
		var dp: float = bc.size.y * dp_ratio
		var bottom: float = bc.global_position.y + bc.size.y
		var flag: String = "  << UNDER THE %.0fdp FLOOR" % TOUCH_FLOOR_DP if dp < TOUCH_FLOOR_DP - 0.5 else ""
		var off: String = "  << %.1f px BELOW the viewport" % (bottom - vp.y) if bottom > vp.y + 0.5 else ""
		print("     %-24s h %.1f design = %.1f dp%s%s"
			% [nm, bc.size.y, dp, flag, off])

	# Can the player actually REACH the nav by scrolling? In the tight layout the nav
	# is inside ContentScroll by design (T10-11), so "below the fold" is expected -
	# what is NOT acceptable is a last control that cannot be brought fully into view.
	if scroll is ScrollContainer:
		var sc: ScrollContainer = scroll
		var vbar: VScrollBar = sc.get_v_scroll_bar()
		sc.scroll_vertical = int(vbar.max_value)
		await process_frame
		await process_frame
		print("  AT MAX SCROLL (scroll_vertical=%d of max %d, page %d):"
			% [sc.scroll_vertical, int(vbar.max_value), int(vbar.page)])
		var sc_bottom: float = sc.global_position.y + sc.size.y
		for nm2: String in ["NextButton", "BackToDashboardButton", "ProceedToBattleButton"]:
			var b2: Node = inst.find_child(nm2, true, false)
			if not (b2 is Control):
				continue
			var bc2: Control = b2
			var vis_top: float = maxf(bc2.global_position.y, sc.global_position.y)
			var vis_bot: float = minf(bc2.global_position.y + bc2.size.y, sc_bottom)
			var visible_px: float = maxf(0.0, vis_bot - vis_top)
			var cut: float = bc2.size.y - visible_px
			print("     %-24s %.1f of %.1f px visible%s"
				% [nm2, visible_px, bc2.size.y,
					("  << %.1f px CLIPPED at the scroll edge" % cut) if cut > 0.5 else ""])

	inst.queue_free()
	await process_frame
