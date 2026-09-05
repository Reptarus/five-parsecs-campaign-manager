extends SceneTree

## T11-06. Name the driver of the PrintSheetScreen field-overlap findings.
##
## The layout sweep reports "drawn ON TOP OF" between sibling field nodes and can only
## say WHICH nodes overlap. This prints, per field node, the four numbers that decide
## the geometry:
##
##   src        the manifest rect, in source (2764x1843) coordinates
##   want       what _scale_rect_to_display() computed for the current display scale
##   got        the rect the node actually ended up with
##   min        get_combined_minimum_size() - the value `Control.size` is clamped UP to
##
## `want` vs `got` is the whole question. If they agree, the manifest and the scaling
## are both fine and the overlap is in the source coordinates. If `got.y > want.y`, a
## minimum won, and `min` plus the font line height says which one.
##
## Run WITHOUT --headless: under --headless DisplayServer returns dummy values, so
## window_set_size does nothing and every measurement is taken at the default rect.
##
##   Godot_console.exe --path <project> --script tests/tools/probe_sheet_field_geometry.gd \
##       -- w=851 h=393 sheet=crew_log

const PrintSheetScene := "res://src/ui/screens/print/PrintSheetScreen.tscn"

var _w: int = 851
var _h: int = 393
var _sheet: String = ""


func _init() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("w="):
			_w = int(a.substr(2))
		elif a.begins_with("h="):
			_h = int(a.substr(2))
		elif a.begins_with("sheet="):
			_sheet = a.substr(6)
	_run.call_deferred()


func _run() -> void:
	DisplayServer.window_set_size(Vector2i(_w, _h))
	await process_frame
	await process_frame

	var packed: PackedScene = load(PrintSheetScene)
	if packed == null:
		push_error("cannot load %s" % PrintSheetScene)
		quit(1)
		return
	var screen: Node = packed.instantiate()
	root.add_child(screen)
	# The screen builds its UI in _ready(); give layout two frames to settle, then a
	# third after the render so _rescale_field_nodes() (wired to `resized`) has run.
	for _i in range(4):
		await process_frame

	var renderer: Node = _find_renderer(screen)
	if renderer == null:
		print("FAIL: no SheetRenderer under PrintSheetScreen")
		quit(1)
		return

	print("=== SHEET FIELD GEOMETRY @ %dx%d ===" % [_w, _h])
	print("renderer rect      : pos %s size %s" % [renderer.position, renderer.size])
	var src_size: Vector2i = renderer.get_source_size()
	print("source size        : %s" % src_size)
	var scale: float = 0.0
	if renderer.has_method("_get_display_scale"):
		scale = renderer._get_display_scale()
	print("display scale      : %.5f" % scale)
	var layer: Node = renderer.get_node_or_null("FieldLayer")
	if layer != null:
		print("field layer        : pos %s scale %s size %s"
			% [layer.position, layer.scale, layer.size])
	else:
		print("field layer        : ABSENT")
	print("")

	var sheets: Array = [_sheet] if not _sheet.is_empty() else _tab_ids(screen)
	for sid in sheets:
		_report_sheet(screen, renderer, str(sid), scale)

	quit(0)


func _tab_ids(screen: Node) -> Array:
	# The screen owns the tab list in its SHEETS const; read it rather than hardcoding,
	# so a sheet added to the screen is covered without editing the probe.
	var out: Array = []
	var sc: Script = screen.get_script()
	if sc != null:
		for c in sc.get_script_constant_map().get("SHEETS", []):
			out.append(str(c.get("id", "")))
	return out


func _report_sheet(screen: Node, renderer: Node, sheet_id: String, scale: float) -> void:
	# Render through the SCREEN's own context builder, not a fixture: the two
	# device-only sheet defects both lived in the ~15 lines that FETCH the campaign,
	# world and journal (docs/sop/sheet-export.md, "Don't test only build()").
	renderer.render_sheet(sheet_id, screen._build_data_context())

	var nodes: Array = []
	if "_field_nodes" in renderer:
		nodes = renderer._field_nodes
	print("--- %s : %d field nodes ---" % [sheet_id, nodes.size()])
	if nodes.is_empty():
		return

	# Field nodes are positioned in SOURCE pixels under a transformed layer, so the rect
	# a node SHOULD have is its manifest rect verbatim. Any difference is a
	# minimum-size clamp - the whole of T11-06.
	var clamped: int = 0
	var width_err_max: float = 0.0
	var height_err_max: float = 0.0
	var shown: int = 0
	for node in nodes:
		if not is_instance_valid(node) or not node.has_meta("sheet_src_rect"):
			continue
		var src: Rect2 = node.get_meta("sheet_src_rect")
		var want: Rect2 = src
		var got := Rect2(node.position, node.size)
		var mn: Vector2 = node.get_combined_minimum_size()
		var dw: float = absf(got.size.x - want.size.x)
		var dh: float = absf(got.size.y - want.size.y)
		width_err_max = maxf(width_err_max, dw)
		height_err_max = maxf(height_err_max, dh)
		var is_clamped: bool = dh > 0.5 or dw > 0.5
		if is_clamped:
			clamped += 1
		# Print the first 12 clamped nodes in full; the rest are summarised below.
		if is_clamped and shown < 12:
			shown += 1
			var fs: int = int(node.get_meta("sheet_font_size", 0))
			var applied: int = 0
			var prop: String = str(node.get_meta("sheet_font_prop", "font_size"))
			if node.has_theme_font_size_override(prop):
				applied = node.get_theme_font_size(prop)
			print(("  %-28s src %s\n      want %s\n      got  %s\n"
					+ "      min  %s  font base=%d applied=%d  line_h=%s")
				% [str(node.name), _r(src), _r(want), _r(got), mn, fs, applied,
					_line_height(node, prop, applied)])
	print("  clamped nodes      : %d / %d  (source px)" % [clamped, nodes.size()])
	print("  max width error    : %.3f px" % width_err_max)
	print("  max height error   : %.3f px" % height_err_max)
	# The sweep's actual question: do any two fields overlap ON SCREEN? Source rects are
	# already known clean, so this reports what the transform produces.
	var overlaps: int = _count_overlaps(nodes)
	print("  overlapping pairs  : %d" % overlaps)
	print("")


func _count_overlaps(nodes: Array) -> int:
	var rects: Array = []
	for node in nodes:
		if not is_instance_valid(node):
			continue
		var r := Rect2(node.position, node.size)
		if r.size.x <= 0.0 or r.size.y <= 0.0:
			continue
		# Blank fields cannot paint over anything; a print form is meant to have empty
		# boxes, so counting them would report the sheet as broken for being blank.
		if node is Label and (node as Label).text.strip_edges().is_empty():
			continue
		if node is RichTextLabel and (node as RichTextLabel).text.strip_edges().is_empty():
			continue
		rects.append(r)
	var n: int = 0
	for i in range(rects.size()):
		for j in range(i + 1, rects.size()):
			var a: Rect2 = rects[i]
			var b: Rect2 = rects[j]
			# grow(-0.5): a shared border is adjacency, not an overlap.
			if a.grow(-0.5).intersects(b.grow(-0.5)):
				n += 1
	return n


func _line_height(node: Node, prop: String, applied: int) -> String:
	var f: Font = node.get_theme_font("font") if node.has_method("get_theme_font") else null
	if f == null:
		return "n/a"
	return "%.2f" % f.get_height(applied if applied > 0 else 16)


func _r(r: Rect2) -> String:
	return "[%8.2f %8.2f  %8.2f x %8.2f]" % [r.position.x, r.position.y,
			r.size.x, r.size.y]


func _find_renderer(n: Node) -> Node:
	if n.get_script() != null:
		var p: String = str(n.get_script().resource_path)
		if p.ends_with("SheetRenderer.gd"):
			return n
	for c in n.get_children():
		var r: Node = _find_renderer(c)
		if r != null:
			return r
	return null
