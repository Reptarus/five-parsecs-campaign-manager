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
	# T9-11. Field overlays are positioned in SOURCE-PNG pixels scaled by this Control's
	# own `size`, and that scale is baked in once at render_sheet() time. A screen that
	# renders during setup — which PrintSheetScreen does — is still at size 0, so every
	# Label lands at (0,0) with size 0 and `clip_text = true` hides it permanently.
	# Nothing about that is visible: the background is PRESET_FULL_RECT so it resizes
	# itself, and `_draw()` recomputes the debug rects every frame, so both the sheet art
	# and the calibration overlay look perfect while all 144 values are invisible.
	# Re-scale whenever the box changes instead of trusting the size at render time.
	resized.connect(_rescale_field_nodes)


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
	# Write through FileAccess rather than Image.save_png(). On Android the native
	# (SAF) file dialog hands back a content:// URI, and the Godot 4.6 docs guarantee
	# such a URI "can be passed directly to FileAccess to perform read/write
	# operations" — they make no equivalent promise for Image.save_png(). Identical
	# bytes either way; this just routes them through the one API documented to accept
	# the URI. The PDF path already writes via FileAccess (addons/godotpdf/PDF.gd:137).
	var png_bytes: PackedByteArray = img.save_png_to_buffer()
	if png_bytes.is_empty():
		return ERR_CANT_CREATE
	var f: FileAccess = FileAccess.open(output_path, FileAccess.WRITE)
	if f == null:
		return FileAccess.get_open_error()
	f.store_buffer(png_bytes)
	f.close()
	return OK


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
	# US letter landscape to match the source 2764x1843 ~3:2 aspect. Honoured by
	# BOTH backends now — GodotPDF gained setPageSize() and libharu gained the
	# letterbox math it never had. See docs/sop/sheet-export.md.
	var page_size_inches := Vector2(11.0, 8.5)
	var err: Error = PdfExportRouter.export_viewport_as_pdf(
		texture, page_size_inches, output_path,
		_collect_text_layer(sub_viewport))
	sub_viewport.queue_free()
	return err


## The invisible, searchable text layer for the PDF export, in SOURCE pixels.
##
## ⚠ Read off the CLONE inside the SubViewport — the very nodes that were
## rasterized — and NOT from a fresh pass over the manifest. A second pass is two
## producers for one fact, which is the exact shape that has bitten this project
## repeatedly: the layer would go on claiming a value the picture no longer shows,
## and nothing would error. Derived this way the two cannot disagree, because
## there is only one source.
##
## Blank mode deliberately yields nothing: "print blank to fill in by hand" must
## not ship a hidden copy of the data the player asked to leave off the page.
func _collect_text_layer(sub_viewport: SubViewport) -> Array:
	if _blank_mode or sub_viewport == null or sub_viewport.get_child_count() == 0:
		return []
	var out: Array = []
	for child in sub_viewport.get_child(0).get_children():
		if not child is Control:
			continue
		var ctl: Control = child
		if not ctl.has_meta("sheet_src_rect"):
			continue
		var text: String = ""
		var align: String = "left"
		if ctl is Label:
			var lbl: Label = ctl
			text = lbl.text
			if lbl.horizontal_alignment == HORIZONTAL_ALIGNMENT_CENTER:
				align = "center"
			elif lbl.horizontal_alignment == HORIZONTAL_ALIGNMENT_RIGHT:
				align = "right"
		elif ctl is RichTextLabel:
			text = (ctl as RichTextLabel).text
		if text.strip_edges().is_empty():
			continue
		out.append({
			"text": text,
			"rect": ctl.get_meta("sheet_src_rect") as Rect2,
			"font_size": int(ctl.get_meta("sheet_font_size", 24)),
			"align": align,
		})
	return out


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
	# IGNORE_SIZE, not FIT_WIDTH_PROPORTIONAL. The sheet PNGs are tall portrait
	# pages, so FIT_WIDTH_PROPORTIONAL gave this TextureRect a MINIMUM HEIGHT of
	# width x aspect — which propagated up and pushed the preview 640-844px off the
	# bottom of the screen at every size the layout sweep measured.
	#
	# It also disagreed with the field overlays. _get_display_scale() (:285) fits the
	# source page into the renderer's OWN size by the limiting axis and centres it —
	# i.e. exactly KEEP_ASPECT_CENTERED with no minimum imposed. IGNORE_SIZE makes
	# the background obey the same box the field rects are computed against, so this
	# fixes the overflow and removes a latent mismatch in the CV-calibrated overlay
	# alignment rather than trading one for the other.
	_background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# show_behind_parent so the SheetRenderer's own _draw() (debug overlay rects)
	# renders ON TOP of the background PNG. Without this, the parent's _draw is
	# called first and the child TextureRect paints over it. Discovered during
	# Sprint 2.5 MCP runtime testing — debug overlay was invisible until this.
	_background.show_behind_parent = true
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
			# Keep the SOURCE-pixel rect on the node so _rescale_field_nodes() can
			# recompute geometry from it later without rebuilding (and re-resolving)
			# every field. Stored here, where the field dict is already in hand.
			var src_rect: Rect2 = _field_src_rect(field)
			if src_rect.size.x > 0.0:
				node.set_meta("sheet_src_rect", src_rect)
			node.set_meta("sheet_font_size", int(field.get("font_size", 24)))
			# RichTextLabel names its theme size differently from Label.
			node.set_meta("sheet_font_prop",
				"normal_font_size" if node is RichTextLabel else "font_size")
			add_child(node)
			_field_nodes.append(node)


## The field's rect in SOURCE pixels, with the printed caption band excluded.
##
## Manifest rects come from box-outline detection, so they include the caption
## the artwork prints inside the top of each box ("Name", "Weapon", "Range"...).
## Centring a value in the full rect puts it straight on the caption whenever the
## box is short — which is why crew names, species, weapon names and the
## Range/Shots/Damage numbers all collided on device while the taller ship-name
## and crew-name boxes looked fine.
##
## Horizontal padding inside every field box, in SOURCE pixels.
##
## MEASURED off assets/sheets/core/crew_log.png, not chosen: the ink profile across a
## caption band reads `2 2 1 0 0 0 0 10 18 12 ...` — the box's border stroke occupies
## columns 0-2, then four clear columns, and the caption's first glyph starts at +7.
## So 7 is the artwork's OWN left inset, and using it makes a value line up with the
## caption printed above it instead of starting on the border stroke.
const FIELD_PAD_X := 7.0

## How far a value's glyphs should stop short of the writing rule below its box,
## in SOURCE pixels. See _vertical_align_for() for why this exists.
const FIELD_BASELINE_GAP := 4.0

## `label_inset` is measured per field from the artwork by
## scripts/bake_sheet_label_insets.py — re-run it if the sheet art changes.
## Absent or 0 leaves the geometry untouched, so an un-baked manifest still works.
##
## ⚠ TODO (noted Aug 9 2026) — FIELD ALIGNMENT STILL NEEDS A TUNING PASS.
## `label_inset` cleared the values off their printed captions, which was the blocking
## defect, but it is a first approximation and not a typeset result. Known-rough:
##   - NO horizontal padding anywhere. 55 of 144 fields are left-aligned and their text
##     starts flush against the box's border stroke, touching the printed line.
##   - The value is CENTRED in whatever vertical space is left after the inset. On a
##     paper form a written value sits on a line near the bottom of its box; centring
##     floats it, and the taller the box the more it floats.
##   - No shared baseline across a row. The weapon line mixes a left 18-22pt name with
##     centred Range/Shots/Damage numbers at a different size (7 distinct font sizes in
##     the manifest), so they do not sit on a common baseline.
##   - The +2px breathing room inside the measured caption band is a chosen constant,
##     not a tuned one.
## ⚠ Tune against the GENERATED artifact at 2764x1843, never the on-screen preview: the
## preview scales to roughly 0.6x, which hides several px of misalignment. That is
## exactly how the zero-size overlays and the 72 DPI export both survived review.
func _field_src_rect(field: Dictionary) -> Rect2:
	var rect_arr: Array = field.get("rect", [])
	if rect_arr.size() < 4:
		return Rect2()
	var inset: float = float(field.get("label_inset", 0))
	var height: float = float(rect_arr[3])
	var width: float = float(rect_arr[2])
	# Never let a bad inset collapse the field to nothing — better to overlap a
	# caption than to silently drop the value.
	if inset >= height:
		inset = 0.0
	# Side padding, so a left-aligned value does not start on the printed border
	# stroke. Skipped on a box too narrow to give it up.
	var pad: float = FIELD_PAD_X if width > FIELD_PAD_X * 4.0 else 0.0

	# Extend the box down to just above the WRITING RULE, so a bottom-aligned value
	# sits on its line. The rule is not a fixed distance below the manifest rect —
	# measured across the 144 crew-log fields it is +3 to +17, mostly +16 and +9 —
	# so aligning to the rect bottom leaves a gap that varies by ROW even where the
	# font, the box height and the caption are all identical. `rule_offset` is
	# measured per field by scripts/bake_sheet_label_insets.py; 0 means none found,
	# which keeps the field on its own rect bottom.
	var rule: float = float(field.get("rule_offset", 0))
	var bottom: float = height
	if rule > inset + FIELD_BASELINE_GAP:
		bottom = rule - FIELD_BASELINE_GAP

	return Rect2(
		float(rect_arr[0]) + pad, float(rect_arr[1]) + inset,
		width - pad * 2.0, bottom - inset)


func _build_field_node(field: Dictionary, ctx: Dictionary) -> Control:
	var rect_src: Rect2 = _field_src_rect(field)
	if rect_src.size.x <= 0.0:
		return null
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
			lbl.add_theme_font_size_override("font_size", ScreenChrome.font_size(display_font_size))
			lbl.add_theme_color_override("font_color", Color.BLACK)
			lbl.clip_text = true
			lbl.horizontal_alignment = _h_align(align)
			lbl.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
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
				"normal_font_size", ScreenChrome.font_size(display_font_size))
			rtl.add_theme_color_override("default_color", Color.BLACK)
			rtl.mouse_filter = Control.MOUSE_FILTER_IGNORE
			return rtl
		"checkbox":
			var cb := Label.new()
			cb.position = rect_screen.position
			cb.size = rect_screen.size
			# Filled checkbox if value is truthy; empty otherwise.
			cb.text = "X" if _is_truthy(value) else ""
			cb.add_theme_font_size_override("font_size", ScreenChrome.font_size(display_font_size))
			cb.add_theme_color_override("font_color", Color.BLACK)
			cb.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			cb.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			cb.mouse_filter = Control.MOUSE_FILTER_IGNORE
			return cb
		_:
			# Unknown type — silent skip rather than crash.
			return null


## Re-derive every field overlay's geometry from its stored source rect. Called on
## `resized`, so a sheet rendered before layout still lands correctly once the Control
## gets its real box. Cheap: no manifest re-read and no source re-resolution, just
## arithmetic over the nodes that already exist.
func _rescale_field_nodes() -> void:
	if _field_nodes.is_empty() or size.x <= 0.0 or size.y <= 0.0:
		return
	var scale_factor: float = _get_display_scale()
	for node in _field_nodes:
		if not is_instance_valid(node) or not node.has_meta("sheet_src_rect"):
			continue
		var rect_screen: Rect2 = _scale_rect_to_display(node.get_meta("sheet_src_rect"))
		node.position = rect_screen.position
		node.size = rect_screen.size
		var base_fs: int = int(node.get_meta("sheet_font_size", 24))
		node.add_theme_font_size_override(
			str(node.get_meta("sheet_font_prop", "font_size")),
			ScreenChrome.font_size(max(8, int(round(base_fs * scale_factor)))))
	queue_redraw()


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
	# DUPLICATE_SCRIPTS is REQUIRED here. `duplicate(flags)` does NOT add to the default
	# bitmask, it REPLACES it — the default is 15 (SIGNALS|GROUPS|SCRIPTS|INSTANTIATION),
	# so passing DUPLICATE_USE_INSTANTIATION alone is 8 and silently drops the SCRIPT.
	# The clone came back as a bare Control, the has_method() guard below was therefore
	# permanently false, and the manifest handoff was skipped without a single warning.
	# The export has never re-scaled its overlay; it only ever LOOKED right because every
	# field resolved empty (T9-09). Verified against the Godot 4.6 Node docs.
	var clone := duplicate(DUPLICATE_USE_INSTANTIATION | DUPLICATE_SCRIPTS) as Control
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
	else:
		# Never silently. A false guard here is exactly how the missing DUPLICATE_SCRIPTS
		# hid: the export kept "succeeding" while writing an unscaled overlay.
		push_warning(
			"SheetRenderer: export clone lost its script — overlay will NOT be " +
			"rescaled to source resolution. Check the duplicate() flags.")

	# Wait for the next frame to ensure the texture is populated.
	await RenderingServer.frame_post_draw
	return sub_viewport


## Internal — clone uses this to inherit manifest without re-loading.
func _set_manifest_for_export(manifest: Dictionary) -> void:
	_manifest = manifest
	var src_size_arr: Array = _manifest.get("source_size", [2764, 1843])
	if src_size_arr.size() >= 2:
		_source_size = Vector2i(int(src_size_arr[0]), int(src_size_arr[1]))
	# T9-11, export half. duplicate() copies the child Labels AND their meta, but NOT
	# the plain `var _field_nodes` that tracks them — so the clone starts with an empty
	# list and _rescale_field_nodes() would no-op. Re-adopt the duplicated overlays by
	# their meta marker, then rescale to the SubViewport's SOURCE resolution.
	#
	# Without this the export writes the overlay at the ON-SCREEN scale inside a
	# 2764x1843 viewport — a cluster of tiny labels in the top-left corner of an
	# otherwise correct sheet. Same defect as the on-screen case, one layer further out,
	# and invisible until something actually rendered text.
	_field_nodes.clear()
	for child in get_children():
		if child is Control and (child as Control).has_meta("sheet_src_rect"):
			_field_nodes.append(child)
	_rescale_field_nodes()


# Debug overlay — draws field rects over the rendered sheet.
#
# Draws TWO rects per field: the manifest box (faint) and the region a value is
# actually painted into (solid). They differ by `label_inset`.
#
# This used to draw only the box, and that made it actively misleading: during
# the Aug 9 2026 device session the overlay showed a perfectly calibrated grid at
# the same moment every field node was 0x0 and every value invisible. An overlay
# that does not draw what the renderer draws is decoration, not instrumentation.
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
		var box_screen: Rect2 = _scale_rect_to_display(Rect2(
			float(rect_arr[0]), float(rect_arr[1]),
			float(rect_arr[2]), float(rect_arr[3])))
		draw_rect(box_screen, Color(DEBUG_OVERLAY_COLOR, 0.25), false, 1.0)
		var value_screen: Rect2 = _scale_rect_to_display(_field_src_rect(field))
		draw_rect(value_screen, DEBUG_OVERLAY_COLOR, false, 2.0)
