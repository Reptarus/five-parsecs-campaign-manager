extends SceneTree
## Ad-hoc driver probe: instantiate ONE screen at ONE size and list the controls whose
## minimum size is forcing the layout wider (or taller) than the space available.
##
## The layout sweep names the outermost overflowing node and its deepest single driver;
## when a screen is down to its last few pixels you want the whole chain instead. This
## prints every visible Control whose minimum on the chosen axis is within reach of the
## worst offender, deepest path first, so the fix target is unambiguous.
##
## Run (NOTE: no --headless — layout needs a real window):
##   godot --path <root> --script res://tests/tools/probe_widest.gd -- <scene> <w> <h> [axis]
##
##   <scene>  res:// path to a .tscn
##   <w> <h>  WINDOW size in device dp (design space is this / ~1.16)
##   [axis]   "x" (default) or "y"

var _frame := 0
var _started := false


func _process(_delta: float) -> bool:
	_frame += 1
	if _frame < 2 or _started:
		return false
	_started = true
	_run()
	return false


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var scene_path: String = args[0] if args.size() > 0 else ""
	var w: int = int(args[1]) if args.size() > 1 else 393
	var h: int = int(args[2]) if args.size() > 2 else 851
	var axis: String = String(args[3]).to_lower() if args.size() > 3 else "x"
	if scene_path.is_empty() or not ResourceLoader.exists(scene_path):
		print("usage: --script probe_widest.gd -- res://path/Scene.tscn 393 851 [x|y]")
		quit(1)
		return

	DisplayServer.window_set_size(Vector2i(w, h))
	for _i in range(3):
		await process_frame

	var inst: Node = (load(scene_path) as PackedScene).instantiate()
	root.add_child(inst)
	if inst is CanvasItem and not (inst as CanvasItem).visible:
		(inst as CanvasItem).show()
	for _i in range(25):
		await process_frame
	# Same overlay net the sweep applies, so the numbers match what it reports.
	var so := root.get_node_or_null("/root/SettingsOverlay")
	if so != null:
		if so.has_method("_update_visibility"):
			so._update_visibility()
		if so.has_method("reserve_band_on"):
			so.reserve_band_on(inst)
	for _i in range(25):
		await process_frame

	var ds: Vector2 = root.get_visible_rect().size
	var horiz := axis != "y"
	print("scene: %s" % scene_path)
	print("design space: %.1f x %.1f  (window %dx%d)" % [ds.x, ds.y, w, h])
	print("axis: %s   budget: %.1f" % ["width" if horiz else "height", ds.x if horiz else ds.y])

	var rows: Array = []
	var worst := 0.0
	var stack: Array = [[inst, 0]]
	while not stack.is_empty():
		var entry: Array = stack.pop_back()
		var node: Node = entry[0]
		var depth: int = entry[1]
		for c in node.get_children():
			stack.append([c, depth + 1])
		if not (node is Control) or not (node as Control).is_visible_in_tree():
			continue
		var m: Vector2 = (node as Control).get_combined_minimum_size()
		var mv: float = m.x if horiz else m.y
		worst = maxf(worst, mv)
		rows.append([mv, depth, "%s (%s)" % [str(inst.get_path_to(node)), node.get_class()]])

	rows.sort_custom(func(a, b): return a[0] > b[0] if a[0] != b[0] else a[1] > b[1])
	print("--- controls within 140px of the worst minimum (%.0f), deepest first ---" % worst)
	var shown := 0
	for r in rows:
		if r[0] < worst - 140.0 or shown >= 25:
			break
		print("  %7.1f  depth=%-2d  %s" % [r[0], r[1], r[2]])
		shown += 1
	quit(0)
