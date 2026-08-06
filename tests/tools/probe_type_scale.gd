extends SceneTree

## WINDOWED probe: does type ACTUALLY change size when the window does?
##
## Run (no --headless — resizing needs a real window):
##   godot --path <root> --script res://tests/tools/probe_type_scale.gd
##   godot --path <root> --script res://tests/tools/probe_type_scale.gd -- \
##       scene=res://src/ui/screens/store/StoreScreen.tscn
##
## ── WHY THIS EXISTS ──────────────────────────────────────────────────────────
## "Fonts respond to screen size" was true of the THEME and false of the app: a
## control with add_theme_font_size_override() is permanently invisible to the
## theme system, and non-battle UI had 990 of those against 208 responsive ones.
## Reading get_font_size_multiplier() proves nothing, because almost nothing was
## consuming it. This walks real instantiated screens and reports the font sizes
## that actually reached the controls, so a regression back to pinned type shows
## up as a column of identical numbers.
##
## Deliberately reports the DISTRIBUTION rather than one label: a screen mixes
## several rungs of the ladder, and a fix that only moved titles would look
## complete from a single sample.

const SIZES := [
	{"label": "small phone", "w": 360, "h": 780},
	{"label": "phone", "w": 393, "h": 851},
	{"label": "tablet", "w": 834, "h": 1112},
	{"label": "desktop", "w": 1440, "h": 900},
]

const DEFAULT_SCENES := [
	"res://src/ui/screens/compendium/CompendiumScreen.tscn",
	"res://src/ui/screens/equipment/EquipmentManager.tscn",
	"res://src/ui/screens/store/StoreScreen.tscn",
]

var _scenes: Array[String] = []


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("scene="):
			_scenes.append(arg.substr(6))
	if _scenes.is_empty():
		_scenes.assign(DEFAULT_SCENES)
	_run()


func _run() -> void:
	# Autoloads are not in the tree yet during _initialize, and ResponsiveManager
	# classifies off the CURRENT window — so the very first sample reads a stale
	# breakpoint and lies about the first scene. Warm up before measuring anything.
	await process_frame
	DisplayServer.window_set_size(Vector2i(1280, 800))
	for _i in range(4):
		await process_frame

	var rm := root.get_node_or_null(NodePath("/root/ResponsiveManager"))
	print("ResponsiveManager: %s" % ("found" if rm else "MISSING"))

	for scene_path: String in _scenes:
		if not ResourceLoader.exists(scene_path):
			print("\n%s  -- not found, skipped" % scene_path)
			continue
		print("\n=== %s ===" % scene_path.get_file())
		for size: Dictionary in SIZES:
			await _probe(scene_path, size)
	quit()


func _probe(scene_path: String, size: Dictionary) -> void:
	DisplayServer.window_set_size(Vector2i(size["w"], size["h"]))
	# Three frames: one for the resize to land, one for ResponsiveManager to
	# reclassify and rescale the theme, one for controls to remeasure.
	for _i in range(3):
		await process_frame

	var packed: PackedScene = load(scene_path)
	if packed == null:
		return
	var inst: Node = packed.instantiate()
	root.add_child(inst)
	for _i in range(4):
		await process_frame

	var sizes: Dictionary = {}
	_collect(inst, sizes)

	var rm := root.get_node_or_null(NodePath("/root/ResponsiveManager"))
	var bp := "?"
	var mult := 0.0
	if rm:
		bp = str(rm.current_breakpoint)
		mult = rm.get_font_size_multiplier()

	var keys: Array = sizes.keys()
	keys.sort()
	var parts: PackedStringArray = []
	for k: int in keys:
		parts.append("%dpx x%d" % [k, sizes[k]])
	print("  %-12s %4dx%-4d  bp=%s mult=%.2f  ->  %s" % [
		size["label"], size["w"], size["h"], bp, mult,
		", ".join(parts) if parts.size() > 0 else "(no text controls)"
	])

	inst.queue_free()
	await process_frame


## Tally the font size each text control actually draws at. get_theme_font_size()
## is the resolved answer -- it returns the override when there is one and falls
## through to the theme when there is not, which is exactly the question.
func _collect(node: Node, tally: Dictionary) -> void:
	if node is Label or node is Button or node is RichTextLabel:
		var ctl := node as Control
		if ctl.visible:
			var fs: int = ctl.get_theme_font_size("font_size")
			if fs > 0:
				tally[fs] = int(tally.get(fs, 0)) + 1
	for child in node.get_children():
		_collect(child, tally)
