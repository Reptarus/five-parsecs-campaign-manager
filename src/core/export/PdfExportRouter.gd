class_name PdfExportRouter
extends RefCounted

## Routes PDF export requests to the best-available PDF backend.
##
## Adapter pattern: keeps SheetRenderer ignorant of which PDF plugin is loaded.
## Modeled after StoreAdapter in src/core/store/.
##
## Priority:
##   1. GodotHaru (GDExtension, C++ libharu wrapper, ships Win+Linux binaries)
##      Detected via ClassDB.class_exists(&"PDF_DOC")
##   2. GodotPDF (pure-GDScript addon, universal platform coverage)
##      Detected via ResourceLoader.exists("res://addons/godotpdf/PDF.gd")
##   3. ERR_UNAVAILABLE — SheetRenderer falls back to PNG-only export
##
## Detection is cached at first access — avoids per-export overhead.
##
## Both plugins must be added separately to addons/ (Asset Library / framagit
## downloads). The router gracefully degrades if either or both are absent.

const BACKEND_GODOTHARU := "godotharu"
const BACKEND_GODOTPDF := "godotpdf"
const BACKEND_NONE := ""

const _GODOTPDF_SCRIPT_PATH := "res://addons/godotpdf/PDF.gd"
const _GODOTHARU_CLASS := &"PDF_DOC"

static var _cached_backend: String = "__unset__"


## Returns the best-available backend identifier.
## See BACKEND_* constants. Cached after first call.
static func best_available_backend() -> String:
	if _cached_backend != "__unset__":
		return _cached_backend
	if ClassDB.class_exists(_GODOTHARU_CLASS):
		_cached_backend = BACKEND_GODOTHARU
	elif ResourceLoader.exists(_GODOTPDF_SCRIPT_PATH):
		_cached_backend = BACKEND_GODOTPDF
	else:
		_cached_backend = BACKEND_NONE
	return _cached_backend


## True iff any PDF backend is available. UI can grey out "Save PDF" otherwise.
static func is_pdf_available() -> bool:
	return best_available_backend() != BACKEND_NONE


## Render the given viewport texture into a single-page PDF at the path.
## page_size_inches is the target physical page size (e.g. Vector2(11, 8.5)
## for US letter landscape). Returns Error.
## Returns ERR_UNAVAILABLE if no PDF backend is installed; caller falls back.
##
## text_layer is an optional INVISIBLE, searchable text overlay — see
## _place_text_layer(). Entries are
##   {text: String, rect: Rect2 (SOURCE-image pixels), font_size: int, align: String}
## The sheet stays a raster; this only makes it findable. Pass [] to skip.
static func export_viewport_as_pdf(
	viewport_texture: Texture2D,
	page_size_inches: Vector2,
	output_path: String,
	text_layer: Array = []
) -> Error:
	var backend: String = best_available_backend()
	match backend:
		BACKEND_GODOTHARU:
			return _export_via_godotharu(
				viewport_texture, page_size_inches, output_path, text_layer)
		BACKEND_GODOTPDF:
			return _export_via_godotpdf(
				viewport_texture, page_size_inches, output_path, text_layer)
		_:
			return ERR_UNAVAILABLE


## Reset the backend cache. For tests + dev hot-swap of addons.
static func reset_cache() -> void:
	_cached_backend = "__unset__"


## Safe print margin, in points (18 = 0.25 inch), applied on every side.
##
## MEASURED, not chosen. With the sheet fitted edge-to-edge across the 792pt page,
## the ink bbox of `crew_log.png` (x 46..2703 of 2764) left only **0.183in** of
## clear paper on the left and 0.239in on the right. Consumer printers cannot
## print to the edge — 0.25in of unprintable border is typical — so printing at
## "Actual size" clipped the outer box borders off the form.
##
## It survived only because most print dialogs default to shrink-to-fit, which was
## silently protecting the output. That also means **do NOT add
## `/ViewerPreferences /PrintScaling /None`**: forcing 100% is precisely what
## makes the clipping happen.
##
## Insetting costs 4.5% of linear size and RAISES effective resolution, because
## the same 2764 pixels now span 10.5in instead of 11in: 251 -> 263 DPI.
const PRINT_MARGIN_PT := 18


# ── Shared page geometry ─────────────────────────────────────────────────
#
# ⚠ This used to exist ONLY inside _export_via_godotpdf, and the libharu path
# drew edge-to-edge instead: `draw_image(img, 0, 0, page_w, page_h)`. Its comment
# claimed "no letterbox — we sized the page to match the sheet", but the page is
# US Letter landscape (792x612 = 1.294:1) and the sheet is 2764x1843 (1.4998:1).
# They have never matched, so every desktop export STRETCHED the sheet vertically
# by 15.9%: measured 251 x 217 DPI on the artifact where the mobile path measured
# a correct 251 x 251. Circles printed as ovals and every glyph was 16% too tall.
#
# The two backends are now driven by the same function, so they cannot disagree
# again. Returns [x, y, w, h] in points, y measured from the PAGE BOTTOM (PDF
# convention) — both backends place from the bottom-left origin.
static func _fit_rect(src_size: Vector2i, page_w: int, page_h: int) -> Array:
	if src_size.x <= 0 or src_size.y <= 0:
		return [0, 0, page_w, page_h]
	var avail_w: int = page_w - PRINT_MARGIN_PT * 2
	var avail_h: int = page_h - PRINT_MARGIN_PT * 2
	# A page too small to inset gets the whole sheet rather than a negative rect.
	if avail_w <= 0 or avail_h <= 0:
		avail_w = page_w
		avail_h = page_h
	var src_aspect: float = float(src_size.x) / float(src_size.y)
	var fit_w: int = avail_w
	var fit_h: int = int(round(float(avail_w) / src_aspect))
	if fit_h > avail_h:
		fit_h = avail_h
		fit_w = int(round(float(avail_h) * src_aspect))
	return [(page_w - fit_w) / 2, (page_h - fit_h) / 2, fit_w, fit_h]


## Flatten a field value to the single line the search layer stores.
##
## ⚠ This deliberately does NOT escape `(`, `)` or `\`. Escaping belongs at the
## point the string is written into the content stream, and only ONE of the two
## backends needs it there:
##   - libharu escapes internally (HPDF_Stream_WriteEscapeText), so pre-escaping
##     would DOUBLE-escape and a crew member called "Vance (Doc) Ryu" would read
##     back as "Vance \(Doc\) Ryu".
##   - GodotPDF concatenates raw text into `(text) Tj`, so it needs escaping and
##     now does it in newLabel().
## A prior design note recorded "pre-escaping is safe for both"; it is not, and
## the round-trip test at tests/unit/test_pdf_export_router.gd pins the actual
## behaviour of each.
static func flatten_field_text(text: String) -> String:
	return text.replace("\r", " ").replace("\n", " ").strip_edges()


# ── GodotHaru path (GDExtension, full libharu API) ───────────────────────
#
# Real API verified via runtime ClassDB introspection (May 23 2026):
#   PDF_DOC.new_doc() -> void           — create document (must call first)
#   PDF_DOC.add_page() -> PDF_PAGE      — append page, returns page handle
#   PDF_DOC.load_png_image_from_mem(buf: PackedByteArray, size: int) -> Object
#                                       — image handle from in-memory PNG bytes
#   PDF_DOC.save_to_file(path: String) -> int   — 0 = HPDF_OK, non-zero = error
#   PDF_DOC.set_title/set_creator/set_compression_mode(...) -> void
#   PDF_PAGE.set_width(float) -> void   — custom width in libharu points (72 = 1in)
#   PDF_PAGE.set_height(float) -> void  — custom height in libharu points
#   PDF_PAGE.draw_image(img, x, y, w, h: float) -> void  — page coords
#
# PDF_DOC and PDF_PAGE are RefCounted (NOT Object-derived). The `free` method
# appears in their ClassDB method lists because it's inherited from Object,
# but calling `.free()` on a RefCounted throws "Can't free a RefCounted object."
# RefCounted auto-frees when the local var goes out of scope — no cleanup
# needed. (Learned the hard way during Sprint 2 runtime testing.)

static func _export_via_godotharu(
	viewport_texture: Texture2D,
	page_size_inches: Vector2,
	output_path: String,
	text_layer: Array = []
) -> Error:
	if not ClassDB.class_exists(_GODOTHARU_CLASS):
		return ERR_UNAVAILABLE
	var pdf: RefCounted = ClassDB.instantiate(_GODOTHARU_CLASS)
	if pdf == null:
		return ERR_CANT_CREATE

	pdf.new_doc()
	_apply_document_info(pdf)
	# COMP_ALL = 0x0F per libharu HPDF_CompressionMode — text + image + metadata
	pdf.set_compression_mode(0x0F)

	# Convert page size: inches → libharu points (1 inch = 72 points)
	var page_w: int = int(round(page_size_inches.x * 72.0))
	var page_h: int = int(round(page_size_inches.y * 72.0))
	if page_w <= 0 or page_h <= 0:
		page_w = 792
		page_h = 612

	var page: RefCounted = pdf.add_page()
	if page == null:
		return ERR_CANT_CREATE
	page.set_width(float(page_w))
	page.set_height(float(page_h))

	var img: Image = viewport_texture.get_image()
	if img == null:
		return ERR_CANT_CREATE
	if img.get_format() != Image.FORMAT_RGB8:
		img.convert(Image.FORMAT_RGB8)

	# Hand libharu the RAW RGB bytes, not a PNG.
	#
	# ⚠ This used to be save_png_to_buffer() -> load_png_image_from_mem(), which
	# made the pipeline: Godot PNG-ENCODES 15 MB -> libharu PNG-DECODES it ->
	# libharu re-compresses it with flate for the PDF. The encode and the decode
	# are both pure waste; the PDF never contains the PNG.
	#
	# MEASURED: save_png_to_buffer() on a 2764x1843 RGB8 image costs ~84 ms, and
	# get_data() costs ~0 (it hands back the buffer that already exists). That is
	# why the C++ backend was benchmarking 215 ms against the pure-GDScript
	# backend's 65 ms — the "slow" one was not doing the encode.
	#
	# The stream is still /FlateDecode: set_compression_mode(0x0F) includes
	# HPDF_COMP_IMAGE, so libharu compresses the raw stream itself. Verified by
	# reading /Filter and the inflated length back out of the artifact.
	#
	# color_space 1 = HPDF_CS_DEVICE_RGB, bits_per_component 8.
	var image_handle: RefCounted = null
	if pdf.has_method("load_raw_image_from_mem"):
		image_handle = pdf.load_raw_image_from_mem(
			img.get_data(), img.get_width(), img.get_height(), 1, 8)
	if image_handle == null:
		# Older GodotHaru without the raw entry point — the PNG round-trip still
		# produces a correct file, just slower.
		var png_bytes: PackedByteArray = img.save_png_to_buffer()
		if png_bytes.is_empty():
			return ERR_CANT_CREATE
		image_handle = pdf.load_png_image_from_mem(png_bytes, png_bytes.size())
	if image_handle == null:
		return ERR_CANT_CREATE

	# Letterbox to the sheet's aspect. Drawing edge-to-edge is what stretched
	# every desktop export by 15.9% — see _fit_rect().
	var fit: Array = _fit_rect(img.get_size(), page_w, page_h)
	page.draw_image(image_handle,
		float(fit[0]), float(fit[1]), float(fit[2]), float(fit[3]))

	_place_text_layer_haru(pdf, page, text_layer, img.get_size(), fit)

	var status: int = pdf.save_to_file(output_path)
	# HPDF_OK = 0; any other value is a libharu error code
	if status != 0:
		return ERR_FILE_CANT_WRITE
	return OK


## Document metadata, applied identically wherever a backend supports it.
##
## The libharu path used to set Title + Creator only. Everything else here is
## standard for a document a player will file, mail or archive; /CreationDate in
## particular is what a file manager sorts on and what an archive tool records.
static func _apply_document_info(pdf: RefCounted) -> void:
	if pdf.has_method("set_title"):
		pdf.set_title("Five Parsecs Sheet Export")
	if pdf.has_method("set_creator"):
		pdf.set_creator("Five Parsecs Campaign Manager")
	if pdf.has_method("set_author"):
		pdf.set_author("Five Parsecs Campaign Manager")
	if pdf.has_method("set_subject"):
		pdf.set_subject("Five Parsecs From Home campaign record sheet")
	if pdf.has_method("set_keywords"):
		pdf.set_keywords("Five Parsecs From Home, campaign, crew, sheet")
	if pdf.has_method("set_creation_date"):
		# libharu takes a date DICTIONARY (HPDF_Date), not a formatted string, and
		# it reads the SINGULAR keys `minute`/`second` — which is exactly what
		# Time.get_datetime_dict_from_system() already returns, so it passes straight
		# through. (Guessing `minutes`/`seconds` here produced a runtime
		# "Dictionary::operator[] used when there was no value" and a null date; the
		# error does not abort the function, so the only sign was in the artifact.)
		pdf.set_creation_date(Time.get_datetime_dict_from_system())


## Paint the searchable text layer with libharu, in INVISIBLE render mode.
##
## Why invisible rather than replacing the raster with real text: the visible
## sheet is a pixel-exact render of the same field nodes the app shows on screen,
## and keeping it means the PDF cannot drift from the app. Native visible text
## would need font parity, wrap parity and alignment parity with Godot's
## typesetter to look the same — three ways to introduce a mismatch. Mode 3 gets
## the searchability with none of that risk. It is the same technique a scanner's
## OCR layer uses.
##
## HPDF text render mode 3 = HPDF_INVISIBLE (libharu HPDF_TextRenderingMode).
static func _place_text_layer_haru(
	pdf: RefCounted, page: RefCounted, text_layer: Array,
	src_size: Vector2i, fit: Array
) -> void:
	if text_layer.is_empty() or src_size.y <= 0:
		return
	if not (page.has_method("begin_text") and page.has_method("text_out")):
		return
	var font = pdf.get_font("Helvetica") if pdf.has_method("get_font") else null
	if font == null:
		return
	var scale: float = float(fit[2]) / float(src_size.x)
	var top: float = float(fit[1]) + float(fit[3])

	page.begin_text()
	if page.has_method("set_text_rendering_mode"):
		page.set_text_rendering_mode(3)
	for raw in text_layer:
		if not raw is Dictionary:
			continue
		var entry: Dictionary = raw
		# NOT escaped — libharu escapes internally. See flatten_field_text().
		var text: String = flatten_field_text(str(entry.get("text", "")))
		if text.is_empty():
			continue
		var rect: Rect2 = entry.get("rect", Rect2())
		if rect.size.x <= 0.0:
			continue
		var src_fs: float = float(entry.get("font_size", 24))
		page.set_font_and_size(font, max(1.0, src_fs * scale))
		# Our values are BOTTOM-aligned in their rect, so the baseline sits just
		# above the rect bottom — 0.2em is a normal descent allowance.
		var baseline_y: float = rect.position.y + rect.size.y - src_fs * 0.2
		var x: float = float(fit[0]) + rect.position.x * scale
		var y: float = top - baseline_y * scale
		var align: String = str(entry.get("align", "left"))
		if align != "left" and page.has_method("text_width"):
			var slack: float = rect.size.x * scale - page.text_width(text)
			x += slack * 0.5 if align == "center" else slack
		page.text_out(x, y, text)
	page.end_text()


# ── GodotPDF path (pure GDScript, universal fallback) ────────────────────
#
# Real API verified by reading addons/godotpdf/PDF.gd source (May 23 2026):
#   pdf.newPDF(title, creator) -> void  — resets state, auto-adds page 1
#   pdf.newImage(pageNum, position, image: Image, imageSize) -> bool
#                                       — takes Image directly, no temp file
#   pdf.export(path) -> bool            — true on success, false on failure
#
# Three LOCAL PATCHES to addons/godotpdf/PDF.gd back this path (Aug 9 2026). All
# three describe defects that only show up in the artifact, never at the call site,
# so re-apply them together if the addon is ever updated:
#   setPageSize(Vector2i)               — upstream was locked to US Letter PORTRAIT
#   newImage(..., drawSize)             — upstream pinned every image to 72 DPI
#   /FlateDecode + /MediaBox in export  — upstream wrote neither
#
# GodotPDF extends Control (Node). Explicit pdf.free() cleanup since we
# never add_child it — function-local scope alone won't release Node memory.

static func _export_via_godotpdf(
	viewport_texture: Texture2D,
	page_size_inches: Vector2,
	output_path: String,
	text_layer: Array = []
) -> Error:
	var pdf_script: Script = load(_GODOTPDF_SCRIPT_PATH)
	if pdf_script == null:
		return ERR_UNAVAILABLE
	var pdf = pdf_script.new()
	if pdf == null:
		return ERR_CANT_CREATE

	var img: Image = viewport_texture.get_image()
	if img == null:
		pdf.free()
		return ERR_CANT_CREATE
	# Convert to RGB8 up front — this is a PERFORMANCE decision, not just a format one.
	# A PDF image stream is raw RGB either way, so the conversion has to happen; doing
	# it here runs in Godot's C++ Image code instead of a GDScript per-pixel loop, and
	# it puts PDF.gd on its FORMAT_RGB8 branch, which our patch writes with a single
	# store_buffer(). The RGBA8 branch still has to walk every pixel to strip alpha.
	#
	# Measured on a TB361FU: >4 minutes with a frozen UI before, under 2.4 s after.
	#
	# Safe for our source: _render_offscreen() sets transparent_bg = false, so the sheet
	# is fully opaque and dropping alpha is lossless. Image.convert() is a no-op when
	# the format already matches.
	if img.get_format() != Image.FORMAT_RGB8:
		img.convert(Image.FORMAT_RGB8)

	pdf.newPDF("Five Parsecs Sheet Export", "Five Parsecs Campaign Manager")

	# Honour the requested page size — the caller passes (11, 8.5) for our landscape
	# sheets, and this path used to throw it away and emit US Letter PORTRAIT.
	#
	# ⚠ This is the single biggest thing wrong with the old output as a DOCUMENT.
	# A 3:2 landscape sheet on a 612x792 portrait page fills a 612x408 band with 47%
	# of the page blank, so every reader opens it zoomed to fit the PAPER — the sheet
	# lands small and sideways-feeling on a phone. A landscape page fills edge to edge.
	#
	# setPageSize() is a local patch (see addons/godotpdf/PDF.gd) and must be called
	# BEFORE newImage(), which bakes in the page-space Y flip at placement time.
	var page_w := int(round(page_size_inches.x * 72.0))
	var page_h := int(round(page_size_inches.y * 72.0))
	if page_w <= 0 or page_h <= 0:
		page_w = 612
		page_h = 792
	if pdf.has_method("setPageSize"):
		pdf.setPageSize(Vector2i(page_w, page_h))
	else:
		# Un-patched addon: fall back to its hardcoded portrait Letter so the maths
		# below still matches the page that actually gets written.
		page_w = 612
		page_h = 792
	# Shared with the libharu path so the two backends cannot diverge — they did,
	# and only the artifact showed it. See _fit_rect().
	var fit: Array = _fit_rect(img.get_size(), page_w, page_h)
	var pos_x: int = int(fit[0])
	var pos_y: int = int(fit[1])
	var fit_w: int = int(fit[2])
	var fit_h: int = int(fit[3])

	# Keep the sheet's native pixels; only the PAGE RECT is fit_w x fit_h points.
	#
	# ⚠ Passing fit_w/fit_h as the image size (which is what upstream's 4-arg form
	# means) resamples the sheet down to the POINT rect — exactly 72 DPI, because 1
	# point is 1/72 inch. That is what shipped in deploy #3: a "Print Sheet" export at
	# screen resolution, verified by reading /Width 612 /Height 408 back out of the
	# file with PyPDF2. Keeping the 2764px source across an 11in page is ~251 DPI.
	#
	# The 5th argument is a local patch to addons/godotpdf/PDF.gd — see newImage().
	var image_ok: bool = pdf.newImage(
		1, Vector2i(pos_x, pos_y), img, img.get_size(), Vector2i(fit_w, fit_h))
	if not image_ok:
		pdf.free()
		return ERR_CANT_CREATE

	_place_text_layer_godotpdf(pdf, text_layer, img.get_size(), fit, page_h)

	var export_ok: bool = pdf.export(output_path)
	pdf.free()
	return OK if export_ok else ERR_FILE_CANT_WRITE


## Paint the searchable text layer with GodotPDF, in INVISIBLE render mode.
##
## Mirrors _place_text_layer_haru; see there for why the layer is invisible.
##
## Two differences from the libharu path, both properties of the addon:
##
##  - `newLabel` takes a TOP-DOWN y and internally emits the baseline at
##    `(_pageSize.y - y) - fontSize`, so the y we pass is back-solved from the
##    baseline we want. (`setPageSize` must already have been called — it has,
##    above — or the flip uses the wrong page height.)
##  - There is no `text_width`, so a centred/right value is positioned by
##    ESTIMATING the string width. Helvetica digits are exactly 0.556 em and its
##    lowercase averages near 0.5, so 0.52 em per character is close enough for a
##    layer nobody can see: being a few points out moves the selection highlight,
##    never the printed glyphs. Do not "improve" this with a font-metrics table —
##    the visible text is the raster, and that is the whole point of mode 3.
static func _place_text_layer_godotpdf(
	pdf, text_layer: Array, src_size: Vector2i, fit: Array, page_h: int
) -> void:
	if text_layer.is_empty() or src_size.x <= 0:
		return
	if not pdf.has_method("newLabel"):
		return
	# An un-patched addon has no invisible mode, and a VISIBLE duplicate of every
	# value printed over the sheet is far worse output than a non-searchable one.
	if not pdf.has_method("setTextRenderMode"):
		return
	pdf.setTextRenderMode(3)
	var scale: float = float(fit[2]) / float(src_size.x)
	var top: float = float(fit[1]) + float(fit[3])

	for raw in text_layer:
		if not raw is Dictionary:
			continue
		var entry: Dictionary = raw
		var text: String = str(entry.get("text", ""))
		if text.strip_edges().is_empty():
			continue
		var rect: Rect2 = entry.get("rect", Rect2())
		if rect.size.x <= 0.0:
			continue
		var src_fs: float = float(entry.get("font_size", 24))
		var fs: float = max(1.0, src_fs * scale)
		var baseline_y: float = rect.position.y + rect.size.y - src_fs * 0.2
		var x: float = float(fit[0]) + rect.position.x * scale
		var pdf_baseline: float = top - baseline_y * scale
		var align: String = str(entry.get("align", "left"))
		if align != "left":
			var slack: float = rect.size.x * scale - text.length() * fs * 0.52
			x += slack * 0.5 if align == "center" else slack
		# newLabel flips internally and then drops fontSize; back-solve for it.
		var y_top_down: float = float(page_h) - pdf_baseline - fs
		pdf.newLabel(1, Vector2i(int(round(x)), int(round(y_top_down))),
			text, int(round(fs)))
	pdf.setTextRenderMode(0)
