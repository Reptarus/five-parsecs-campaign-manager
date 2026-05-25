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
static func export_viewport_as_pdf(
	viewport_texture: Texture2D,
	page_size_inches: Vector2,
	output_path: String
) -> Error:
	var backend: String = best_available_backend()
	match backend:
		BACKEND_GODOTHARU:
			return _export_via_godotharu(
				viewport_texture, page_size_inches, output_path)
		BACKEND_GODOTPDF:
			return _export_via_godotpdf(
				viewport_texture, page_size_inches, output_path)
		_:
			return ERR_UNAVAILABLE


## Reset the backend cache. For tests + dev hot-swap of addons.
static func reset_cache() -> void:
	_cached_backend = "__unset__"


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
	output_path: String
) -> Error:
	if not ClassDB.class_exists(_GODOTHARU_CLASS):
		return ERR_UNAVAILABLE
	var pdf: RefCounted = ClassDB.instantiate(_GODOTHARU_CLASS)
	if pdf == null:
		return ERR_CANT_CREATE

	pdf.new_doc()
	pdf.set_title("Five Parsecs Sheet Export")
	pdf.set_creator("Five Parsecs Campaign Manager")
	# COMP_ALL = 0x0F per libharu HPDF_CompressionMode — text + image + metadata
	pdf.set_compression_mode(0x0F)

	# Convert page size: inches → libharu points (1 inch = 72 points)
	var page_w_pt: float = page_size_inches.x * 72.0
	var page_h_pt: float = page_size_inches.y * 72.0

	var page: RefCounted = pdf.add_page()
	if page == null:
		return ERR_CANT_CREATE
	page.set_width(page_w_pt)
	page.set_height(page_h_pt)

	# Encode the viewport image as PNG bytes in memory — libharu reads from
	# the byte buffer; no temp file needed.
	var img: Image = viewport_texture.get_image()
	if img == null:
		return ERR_CANT_CREATE
	var png_bytes: PackedByteArray = img.save_png_to_buffer()
	if png_bytes.is_empty():
		return ERR_CANT_CREATE

	var image_handle: RefCounted = pdf.load_png_image_from_mem(
		png_bytes, png_bytes.size())
	if image_handle == null:
		return ERR_CANT_CREATE

	# Draw the sheet image edge-to-edge on the page (no letterbox — libharu
	# supports arbitrary page sizes, so we sized the page to match the sheet).
	page.draw_image(image_handle, 0.0, 0.0, page_w_pt, page_h_pt)

	var status: int = pdf.save_to_file(output_path)
	# HPDF_OK = 0; any other value is a libharu error code
	if status != 0:
		return ERR_FILE_CANT_WRITE
	return OK


# ── GodotPDF path (pure GDScript, universal fallback) ────────────────────
#
# Real API verified by reading addons/godotpdf/PDF.gd source (May 23 2026):
#   pdf.newPDF(title, creator) -> void  — resets state, auto-adds page 1
#   pdf.newImage(pageNum, position, image: Image, imageSize) -> bool
#                                       — takes Image directly, no temp file
#   pdf.export(path) -> bool            — true on success, false on failure
#
# GodotPDF page size is hardcoded Vector2i(612, 792) (US letter portrait) —
# not configurable via the API. The page_size_inches parameter is therefore
# IGNORED on this backend; our 3:2 landscape sheet letterboxes into the
# portrait page with vertical margins. See docs/sop/sheet-export.md.
#
# GodotPDF extends Control (Node). Explicit pdf.free() cleanup since we
# never add_child it — function-local scope alone won't release Node memory.

static func _export_via_godotpdf(
	viewport_texture: Texture2D,
	_page_size_inches: Vector2,  # ignored — GodotPDF page size is hardcoded 612x792
	output_path: String
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
	# GodotPDF requires RGB8 or RGBA8 (per PDF.gd line 103). SubViewport
	# texture is typically RGBA8 already; defensive convert covers HDR /
	# transparent-bg edge cases.
	var fmt: int = img.get_format()
	if fmt != Image.FORMAT_RGB8 and fmt != Image.FORMAT_RGBA8:
		img.convert(Image.FORMAT_RGBA8)

	pdf.newPDF("Five Parsecs Sheet Export", "Five Parsecs Campaign Manager")

	# Letterbox the 3:2 sheet into 612x792 portrait — fit-to-width,
	# vertically centered. (page size is fixed; can't render landscape here.)
	var page_w := 612
	var page_h := 792
	var src_aspect: float = float(img.get_width()) / float(img.get_height())
	var fit_w: int = page_w
	var fit_h: int = int(round(float(page_w) / src_aspect))
	if fit_h > page_h:
		fit_h = page_h
		fit_w = int(round(float(page_h) * src_aspect))
	var pos_x: int = (page_w - fit_w) / 2
	var pos_y: int = (page_h - fit_h) / 2

	var image_ok: bool = pdf.newImage(
		1, Vector2i(pos_x, pos_y), img, Vector2i(fit_w, fit_h))
	if not image_ok:
		pdf.free()
		return ERR_CANT_CREATE

	var export_ok: bool = pdf.export(output_path)
	pdf.free()
	return OK if export_ok else ERR_FILE_CANT_WRITE
