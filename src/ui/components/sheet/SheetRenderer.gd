class_name SheetRenderer
extends Control

## Renders an official Modiphius sheet PNG with player data overlaid on the
## printed fields. Exports to PNG (universal) or PDF (via PdfExportRouter).
##
## Architecture: PNG background as TextureRect + a Label/RichTextLabel per
## field positioned by the field-coordinate JSON manifest at
## data/sheets/<book>/<sheet_id>_fields.json.
##
## Field coordinates are in source-PNG pixels. The renderer scales them to the
## current on-screen display size; export always uses the source resolution
## via SubViewport.set_size_2d_override (per Godot 4.6 docs).
##
## Usage:
##   var renderer := SheetRenderer.new()
##   add_child(renderer)
##   renderer.render_sheet("crew_log", {"campaign": campaign, "world": world})
##   renderer.export_to_png("user://my_crew.png")

# Preload-based refs — global class_name cache can lag behind file edits
# (CLAUDE.md "Preload Pattern for UI Class References" + Sprint 2 F4 finding).
const PdfExportRouter = preload("res://src/core/export/PdfExportRouter.gd")

const DEBUG_OVERLAY_COLOR := Color(1.0, 0.2, 0.2, 0.4)

# Loaded manifest state for the currently-rendered sheet.
var _manifest: Dictionary = {}
var _source_size: Vector2i = Vector2i(2764, 1843)

# Tracks the field overlay nodes so they can be removed before re-render.
var _field_nodes: Array[Control] = []

# Background TextureRect (the official sheet PNG).
var _background: TextureRect = null

# Debug-overlay state.
var _debug_overlay: bool = false

# "Print blank" mode — hides all field overlays, shows just the PNG.
var _blank_mode: bool = false


func _ready() -> void:
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## Render a sheet with the given data context.
## sheet_id: e.g. "crew_log", "encounter_log", "world_record_sheet"
## data_context: dict like {"campaign": ..., "world": ..., "journal": ...}
##   used to resolve field source paths via dot-notation traversal.
func render_sheet(sheet_id: String, data_context: Dictionary) -> void:
	var manifest_path: String = _resolve_manifest_path(sheet_id)
	if not ResourceLoader.exists(manifest_path) \
			and not FileAccess.file_exists(manifest_path):
		push_warning("SheetRenderer: manifest not found: %s" % manifest_path)
		return
	var file: FileAccess = FileAccess.open(manifest_path, FileAccess.READ)
	if file == null:
		push_warning("SheetRenderer: cannot open %s" % manifest_path)
		return
	var json := JSON.new()
	var parse_err: Error = json.parse(file.get_as_text())
	file.close()
	if parse_err != OK:
		push_warning("SheetRenderer: JSON parse failed: %s" % json.get_error_message())
		return
	var data: Variant = json.get_data()
	if not data is Dictionary:
		push_warning("SheetRenderer: manifest is not a Dictionary")
		return
	_manifest = data
	var src_size_arr: Array = _manifest.get("source_size", [2764, 1843])
	if src_size_arr.size() >= 2:
		_source_size = Vector2i(int(src_size_arr[0]), int(src_size_arr[1]))
	_clear_field_nodes()
	_ensure_background()
	_load_background_texture()
	if not _blank_mode:
		_populate_fields(data_context)
	queue_redraw()


## Toggle blank mode (no field overlay; just the unmodified PNG).
## Useful for "print blank to fill by hand" workflow.
func set_blank_mode(blank: bool) -> void:
	if _blank_mode == blank:
		return
	_blank_mode = blank
	for node in _field_nodes:
		node.visible = not blank


## Toggle the debug overlay — draws field bounding rects in red.
## Used to calibrate the field-coordinate JSON manifest.
func set_debug_overlay(enabled: bool) -> void:
	_debug_overlay = enabled
	queue_redraw()


## Export the rendered sheet to a PNG file at the source resolution.
## NEVER call from _ready() or the first frame — the SubViewport texture is
## empty until first frame_post_draw (per Godot 4.6 docs).
func export_to_png(output_path: String) -> Error:
	if _manifest.is_empty():
		return ERR_UNCONFIGURED
	var sub_viewport: SubViewport = await _render_offscreen()
	if sub_viewport == null:
		return ERR_CANT_CREATE
	var img: Image = sub_viewport.get_texture().get_image()
	sub_viewport.queue_free()
	if img == null:
		return ERR_CANT_CREATE
	return img.save_png(output_path)


## Export the rendered sheet to a PDF file via PdfExportRouter.
## Returns ERR_UNAVAILABLE if no PDF backend is installed — caller should
## fall back to export_to_png and surface a toast.
func export_to_pdf(output_path: String) -> Error:
	if _manifest.is_empty():
		return ERR_UNCONFIGURED
	if not PdfExportRouter.is_pdf_available():
		return ERR_UNAVAILABLE
	var sub_viewport: SubViewport = await _render_offscreen()
	if sub_viewport == null:
		return ERR_CANT_CREATE
	var texture: ViewportTexture = sub_viewport.get_texture()
	# US letter landscape default to match the source 2764x1843 ~3:2 aspect.
	# Honored by GodotHaru (libharu supports custom page sizes). IGNORED by
	# GodotPDF (page size is hardcoded 612x792 portrait in PDF.gd; sheet
	# letterboxes into the portrait page). See docs/sop/sheet-export.md.
	var page_size_inches := Vector2(11.0, 8.5)
	var err: Error = PdfExportRouter.export_viewport_as_pdf(
		texture, page_size_inches, output_path)
	sub_viewport.queue_free()
	return err


## Source resolution this sheet renders at (post-load).
func get_source_size() -> Vector2i:
	return _source_size


# ── Internal ───────────────────────────────────────────────────────────────

func _resolve_manifest_path(sheet_id: String) -> String:
	# MVP: all 3 sheets live under data/sheets/core/. Future books extend
	# via a sheet_id → book lookup; for now we infer "core" for the trio.
	return "res://data/sheets/core/%s_fields.json" % sheet_id


func _ensure_background() -> void:
	if _background != null and is_instance_valid(_background):
		return
	_background = TextureRect.new()
	_background.set_anchors_preset(Control.PRESET_FULL_RECT)
	_background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_background.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	_background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_background)


func _load_background_texture() -> void:
	if _background == null:
		return
	var png_path: String = str(_manifest.get("source_png", ""))
	if png_path.is_empty() or not ResourceLoader.exists(png_path):
		push_warning("SheetRenderer: background PNG not found: %s" % png_path)
		return
	var tex: Texture2D = load(png_path)
	if tex == null:
		push_warning("SheetRenderer: load failed for %s" % png_path)
		return
	_background.texture = tex


func _clear_field_nodes() -> void:
	for node in _field_nodes:
		if is_instance_valid(node):
			node.queue_free()
	_field_nodes.clear()


func _populate_fields(data_context: Dictionary) -> void:
	var fields: Array = _manifest.get("fields", [])
	for raw_field in fields:
		if not raw_field is Dictionary:
			continue
		var field: Dictionary = raw_field
		var node: Control = _build_field_node(field, data_context)
		if node != null:
			add_child(node)
			_field_nodes.append(node)


func _build_field_node(field: Dictionary, ctx: Dictionary) -> Control:
	var rect_arr: Array = field.get("rect", [])
	if rect_arr.size() < 4:
		return null
	var rect_src := Rect2(
		float(rect_arr[0]), float(rect_arr[1]),
		float(rect_arr[2]), float(rect_arr[3]))
	var rect_screen: Rect2 = _scale_rect_to_display(rect_src)
	var ftype: String = str(field.get("type", "text"))
	var value: Variant = _resolve_source(str(field.get("source", "")), ctx)
	var font_size: int = int(field.get("font_size", 24))
	var align: String = str(field.get("align", "left"))
	# Scale font size to display, but keep a minimum so debug visibility holds.
	var scale_factor: float = _get_display_scale()
	var display_font_size: int = max(8, int(round(font_size * scale_factor)))

	match ftype:
		"text", "number":
			var lbl := Label.new()
			lbl.position = rect_screen.position
			lbl.size = rect_screen.size
			lbl.text = str(value) if value != null else ""
			lbl.add_theme_font_size_override("font_size", display_font_size)
			lbl.add_theme_color_override("font_color", Color.BLACK)
			lbl.clip_text = true
			lbl.horizontal_alignment = _h_align(align)
			lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
			return lbl
		"multiline_text":
			var rtl := RichTextLabel.new()
			rtl.position = rect_screen.position
			rtl.size = rect_screen.size
			rtl.bbcode_enabled = false
			rtl.fit_content = false
			rtl.scroll_active = false
			rtl.text = str(value) if value != null else ""
			rtl.add_theme_font_size_override(
				"normal_font_size", display_font_size)
			rtl.add_theme_color_override("default_color", Color.BLACK)
			rtl.mouse_filter = Control.MOUSE_FILTER_IGNORE
			return rtl
		"checkbox":
			var cb := Label.new()
			cb.position = rect_screen.position
			cb.size = rect_screen.size
			# Filled checkbox if value is truthy; empty otherwise.
			cb.text = "X" if _is_truthy(value) else ""
			cb.add_theme_font_size_override("font_size", display_font_size)
			cb.add_theme_color_override("font_color", Color.BLACK)
			cb.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			cb.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			cb.mouse_filter = Control.MOUSE_FILTER_IGNORE
			return cb
		_:
			# Unknown type — silent skip rather than crash.
			return null


func _scale_rect_to_display(rect_src: Rect2) -> Rect2:
	var scale: float = _get_display_scale()
	# Letterbox: keep aspect ratio, center inside this Control.
	var src_aspect: float = float(_source_size.x) / float(_source_size.y)
	var dst_aspect: float = size.x / max(1.0, size.y)
	var content_w: float
	var content_h: float
	if dst_aspect > src_aspect:
		content_h = size.y
		content_w = content_h * src_aspect
	else:
		content_w = size.x
		content_h = content_w / src_aspect
	var offset_x: float = (size.x - content_w) * 0.5
	var offset_y: float = (size.y - content_h) * 0.5
	var content_scale: float = content_w / float(_source_size.x)
	return Rect2(
		offset_x + rect_src.position.x * content_scale,
		offset_y + rect_src.position.y * content_scale,
		rect_src.size.x * content_scale,
		rect_src.size.y * content_scale)


func _get_display_scale() -> float:
	if size.x <= 0 or _source_size.x <= 0:
		return 1.0
	var src_aspect: float = float(_source_size.x) / float(_source_size.y)
	var dst_aspect: float = size.x / max(1.0, size.y)
	if dst_aspect > src_aspect:
		return size.y / float(_source_size.y)
	return size.x / float(_source_size.x)


func _h_align(align: String) -> int:
	match align:
		"right":
			return HORIZONTAL_ALIGNMENT_RIGHT
		"center":
			return HORIZONTAL_ALIGNMENT_CENTER
		_:
			return HORIZONTAL_ALIGNMENT_LEFT


func _is_truthy(value: Variant) -> bool:
	if value == null:
		return false
	if value is bool:
		return value
	if value is int or value is float:
		return value != 0
	if value is String:
		return not (value as String).is_empty()
	return true


## Resolve a source path like "campaign.captain.character_name" or
## "campaign.crew[0].character_name" against the data_context dict.
## Returns null if any segment is missing.
func _resolve_source(path: String, ctx: Dictionary) -> Variant:
	if path.is_empty():
		return null
	var current: Variant = ctx
	var segments: PackedStringArray = path.split(".")
	for seg in segments:
		if seg.is_empty():
			continue
		# Handle "crew[0]" → property "crew", index 0
		var bracket_open: int = seg.find("[")
		if bracket_open > 0:
			var prop: String = seg.substr(0, bracket_open)
			var bracket_close: int = seg.find("]", bracket_open)
			if bracket_close < 0:
				return null
			var idx_str: String = seg.substr(
				bracket_open + 1, bracket_close - bracket_open - 1)
			if not idx_str.is_valid_int():
				return null
			var idx: int = idx_str.to_int()
			current = _access_property(current, prop)
			if current == null:
				return null
			current = _access_index(current, idx)
			if current == null:
				return null
		else:
			current = _access_property(current, seg)
			if current == null:
				return null
	return current


func _access_property(obj: Variant, prop: String) -> Variant:
	if obj is Dictionary:
		var d: Dictionary = obj
		if d.has(prop):
			return d[prop]
		return null
	# Object (Resource, Node) — use `in` + `get`
	if obj is Object:
		if prop in obj:
			return obj.get(prop)
		return null
	return null


func _access_index(obj: Variant, idx: int) -> Variant:
	if obj is Array:
		var arr: Array = obj
		if idx < 0 or idx >= arr.size():
			return null
		return arr[idx]
	return null


# Render this sheet into an offscreen SubViewport at source resolution.
# Returns the SubViewport (caller must queue_free it).
# Uses Godot 4.6 set_size_2d_override pattern (verified via Context7 docs).
func _render_offscreen() -> SubViewport:
	var sub_viewport := SubViewport.new()
	sub_viewport.size = _source_size
	sub_viewport.set_size_2d_override(_source_size)
	sub_viewport.set_size_2d_override_stretch(true)
	sub_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	sub_viewport.render_target_clear_mode = SubViewport.CLEAR_MODE_ALWAYS
	sub_viewport.transparent_bg = false
	# Add to the active scene tree so it renders.
	get_tree().root.add_child(sub_viewport)

	# Duplicate self into the SubViewport at full source resolution so the
	# overlay scales pixel-perfect to the printed PNG.
	var clone := duplicate(DUPLICATE_USE_INSTANTIATION) as Control
	if clone == null:
		sub_viewport.queue_free()
		return null
	clone.size = Vector2(_source_size)
	clone.position = Vector2.ZERO
	sub_viewport.add_child(clone)
	# Re-render the clone with the same manifest data so child labels exist.
	# (duplicate() copies properties but the dynamically-instantiated field
	# nodes don't always survive — re-running render_sheet on the clone
	# ensures the overlay is present at the SubViewport resolution.)
	if clone.has_method("_set_manifest_for_export"):
		clone._set_manifest_for_export(_manifest)

	# Wait for the next frame to ensure the texture is populated.
	await RenderingServer.frame_post_draw
	return sub_viewport


## Internal — clone uses this to inherit manifest without re-loading.
func _set_manifest_for_export(manifest: Dictionary) -> void:
	_manifest = manifest
	var src_size_arr: Array = _manifest.get("source_size", [2764, 1843])
	if src_size_arr.size() >= 2:
		_source_size = Vector2i(int(src_size_arr[0]), int(src_size_arr[1]))


# Debug overlay — draws field bounding rects in red over the rendered sheet.
func _draw() -> void:
	if not _debug_overlay or _manifest.is_empty():
		return
	var fields: Array = _manifest.get("fields", [])
	for raw_field in fields:
		if not raw_field is Dictionary:
			continue
		var field: Dictionary = raw_field
		var rect_arr: Array = field.get("rect", [])
		if rect_arr.size() < 4:
			continue
		var rect_src := Rect2(
			float(rect_arr[0]), float(rect_arr[1]),
			float(rect_arr[2]), float(rect_arr[3]))
		var rect_screen: Rect2 = _scale_rect_to_display(rect_src)
		draw_rect(rect_screen, DEBUG_OVERLAY_COLOR, false, 2.0)
