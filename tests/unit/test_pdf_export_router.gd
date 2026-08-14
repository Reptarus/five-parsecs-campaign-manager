extends GdUnitTestSuite
## Tests for PdfExportRouter — the plugin-abstraction layer that decides which
## PDF backend (GodotHaru / GodotPDF / none) handles export requests.
##
## Detection logic is pure (ClassDB + ResourceLoader checks) so no scene tree
## is required. Tests focus on:
##   - Backend identifier contract (only the 3 documented constants)
##   - Detection priority (GodotHaru > GodotPDF > none)
##   - Cache behavior (single detection per session, reset_cache works)
##   - Graceful no-backend fallback (ERR_UNAVAILABLE, never crash)

const PdfExportRouter := preload("res://src/core/export/PdfExportRouter.gd")

const VALID_BACKENDS: Array[String] = [
	PdfExportRouter.BACKEND_GODOTHARU,
	PdfExportRouter.BACKEND_GODOTPDF,
	PdfExportRouter.BACKEND_NONE,
]


func before_test() -> void:
	# Each test gets a clean cache — addon presence is the same throughout
	# the run, but resetting makes the cache-behavior test independent.
	PdfExportRouter.reset_cache()


# ============================================================================
# best_available_backend contract
# ============================================================================

func test_best_available_backend_returns_documented_constant() -> void:
	var backend: String = PdfExportRouter.best_available_backend()
	assert_that(VALID_BACKENDS).contains([backend]) \
		.override_failure_message(
			"Backend %s is not one of the 3 documented constants" % backend)


func test_best_available_backend_caches_result() -> void:
	# First call populates the cache; second call must return the same value
	# without re-running detection (we can't directly observe "re-running" but
	# we can verify the contract that repeated calls are idempotent).
	var first: String = PdfExportRouter.best_available_backend()
	var second: String = PdfExportRouter.best_available_backend()
	var third: String = PdfExportRouter.best_available_backend()
	assert_str(second).is_equal(first)
	assert_str(third).is_equal(first)


func test_reset_cache_allows_redetection() -> void:
	var first: String = PdfExportRouter.best_available_backend()
	PdfExportRouter.reset_cache()
	var second: String = PdfExportRouter.best_available_backend()
	# Same plugins are installed (or not) across both calls, so the result
	# is identical — but the reset path executes without erroring.
	assert_str(second).is_equal(first)


# ============================================================================
# is_pdf_available convenience
# ============================================================================

func test_is_pdf_available_matches_backend_presence() -> void:
	var backend: String = PdfExportRouter.best_available_backend()
	var available: bool = PdfExportRouter.is_pdf_available()
	if backend == PdfExportRouter.BACKEND_NONE:
		assert_bool(available).is_false() \
			.override_failure_message(
				"Backend is NONE but is_pdf_available returned true")
	else:
		assert_bool(available).is_true() \
			.override_failure_message(
				"Backend is %s but is_pdf_available returned false" % backend)


# ============================================================================
# export_viewport_as_pdf — graceful no-backend fallback
# ============================================================================

func test_export_returns_unavailable_when_no_backend() -> void:
	# In a CI environment without either plugin installed, this is the path
	# we care about: the router returns ERR_UNAVAILABLE cleanly rather than
	# crashing or writing a corrupt file. SheetRenderer relies on this to
	# fall back to PNG-only.
	if PdfExportRouter.best_available_backend() != PdfExportRouter.BACKEND_NONE:
		# Skip — this CI box has a PDF plugin installed, so the no-backend
		# code path can't be exercised here. The contract still holds; the
		# test environment just can't observe it.
		return
	# Build a tiny dummy texture (1x1 white) so we don't depend on a real
	# render. The router should bail out before it ever touches the texture.
	var img: Image = Image.create(1, 1, false, Image.FORMAT_RGBA8)
	img.fill(Color.WHITE)
	var tex: ImageTexture = ImageTexture.create_from_image(img)
	var err: Error = PdfExportRouter.export_viewport_as_pdf(
		tex, Vector2(11.0, 8.5), "user://_unit_test_pdf_should_not_exist.pdf")
	assert_int(err).is_equal(ERR_UNAVAILABLE)


# ============================================================================
# Routing priority: GodotHaru is preferred over GodotPDF
# ============================================================================

func test_godotharu_wins_over_godotpdf_when_both_present() -> void:
	# We can't actually install/uninstall plugins from a test, but we can
	# verify the ORDER of detection in best_available_backend by reading the
	# source contract: BACKEND_GODOTHARU is checked first. If the current
	# environment reports GODOTHARU, GODOTPDF, or NONE, all are valid — we
	# just assert that the priority order is respected when both are present.
	var backend: String = PdfExportRouter.best_available_backend()
	# If GODOTPDF is reported, GODOTHARU must NOT be class-registered (else
	# the priority would have selected it first).
	if backend == PdfExportRouter.BACKEND_GODOTPDF:
		assert_bool(ClassDB.class_exists(&"PDF_DOC")).is_false() \
			.override_failure_message(
				"PdfExportRouter reported GODOTPDF but PDF_DOC class exists" \
				+ " — priority order violated")
	# Positive assertion (added Sprint 2 when GodotHaru landed in addons/):
	# if GODOTHARU is actually available in ClassDB, the router MUST report
	# it as the best backend. Proves the priority order is actively honored,
	# not just consistent. With both plugins present (current dev box state),
	# this exercises the GODOTHARU branch.
	if ClassDB.class_exists(&"PDF_DOC"):
		assert_str(backend).is_equal(PdfExportRouter.BACKEND_GODOTHARU) \
			.override_failure_message(
				"PDF_DOC class exists but router reported '%s' — " % backend \
				+ "GODOTHARU priority not honored")


# ============================================================================
# Constants haven't drifted
# ============================================================================

func test_backend_constants_are_strings() -> void:
	# Defensive: refactor accidentally turning these into enum ints would
	# break downstream code that compares to literal strings.
	assert_str(PdfExportRouter.BACKEND_GODOTHARU).is_equal("godotharu")
	assert_str(PdfExportRouter.BACKEND_GODOTPDF).is_equal("godotpdf")
	assert_str(PdfExportRouter.BACKEND_NONE).is_equal("")


# ============================================================================
# Page geometry — the sheet must not be STRETCHED onto the page
#
# The libharu path drew the image edge-to-edge (`draw_image(img, 0, 0, page_w,
# page_h)`) while claiming the page had been sized to match the sheet. It never
# had: US Letter landscape is 1.294:1 and the sheet is 1.4998:1, so every desktop
# export stretched vertically by 15.9% — measured as 251 x 217 DPI on the
# artifact against a correct 251 x 251 from the mobile path.
#
# Only the ARTIFACT showed it. These tests pin the shared helper both backends
# now use; tests/tools/emit_sheet_pdf.gd + the PyPDF2 audit remain the end-to-end
# check that the callers actually route through it.
# ============================================================================

const SHEET_SRC := Vector2i(2764, 1843)  # all 3 Core sheets
const LETTER_LANDSCAPE_W := 792
const LETTER_LANDSCAPE_H := 612


func test_fit_rect_preserves_the_source_aspect_ratio() -> void:
	var fit: Array = PdfExportRouter._fit_rect(
		SHEET_SRC, LETTER_LANDSCAPE_W, LETTER_LANDSCAPE_H)
	var src_aspect: float = float(SHEET_SRC.x) / float(SHEET_SRC.y)
	var fit_aspect: float = float(fit[2]) / float(fit[3])
	# Within a point of rounding. A 15.9% stretch is ~0.2 of aspect, so this
	# tolerance cannot pass the bug it was written for.
	assert_float(fit_aspect).is_equal_approx(src_aspect, 0.01) \
		.override_failure_message(
			"Sheet drawn at aspect %.4f but its source is %.4f — the page render " % [
				fit_aspect, src_aspect]
			+ "is STRETCHED. See _fit_rect().")


func test_fit_rect_letterboxes_the_core_sheet_on_us_letter() -> void:
	var fit: Array = PdfExportRouter._fit_rect(
		SHEET_SRC, LETTER_LANDSCAPE_W, LETTER_LANDSCAPE_H)
	# Width-limited inside the safe print margin: 792 - 2*18 = 756 wide,
	# 756 / 1.4998 = 504 tall, centred on the page.
	assert_array(fit).is_equal([18, 54, 756, 504])


## The sheet must not run into the strip a consumer printer cannot reach.
##
## MEASURED on the artwork: `crew_log.png`'s ink spans x 46..2703 of 2764.
## Fitted edge-to-edge that left 0.183in of clear paper on the left — inside
## the ~0.25in unprintable border of a typical home printer, so "Actual size"
## clipped the outer box borders off the form. It only ever looked survivable
## because most print dialogs default to shrink-to-fit.
func test_fit_rect_keeps_the_sheets_ink_clear_of_the_unprintable_border() -> void:
	var fit: Array = PdfExportRouter._fit_rect(
		SHEET_SRC, LETTER_LANDSCAPE_W, LETTER_LANDSCAPE_H)
	# Where the artwork's own outermost ink lands on the page, in points.
	var ink_x0: float = 46.0
	var ink_x1: float = 2703.0
	var scale: float = float(fit[2]) / float(SHEET_SRC.x)
	var left_clear: float = float(fit[0]) + ink_x0 * scale
	var right_clear: float = float(LETTER_LANDSCAPE_W) - (float(fit[0]) + (ink_x1 + 1.0) * scale)
	var safe_pt: float = 0.25 * 72.0
	assert_float(left_clear).is_greater_equal(safe_pt) \
		.override_failure_message(
			"only %.3f in of clear paper left of the sheet's ink (need %.2f in)" % [
				left_clear / 72.0, safe_pt / 72.0])
	assert_float(right_clear).is_greater_equal(safe_pt) \
		.override_failure_message(
			"only %.3f in of clear paper right of the sheet's ink (need %.2f in)" % [
				right_clear / 72.0, safe_pt / 72.0])


func test_fit_rect_never_exceeds_the_page() -> void:
	# A tall source must letterbox on the OTHER axis rather than overflow.
	for src in [Vector2i(2764, 1843), Vector2i(1843, 2764), Vector2i(1000, 1000)]:
		var fit: Array = PdfExportRouter._fit_rect(
			src, LETTER_LANDSCAPE_W, LETTER_LANDSCAPE_H)
		assert_bool(int(fit[0]) >= 0 and int(fit[1]) >= 0).is_true()
		assert_bool(int(fit[0]) + int(fit[2]) <= LETTER_LANDSCAPE_W).is_true() \
			.override_failure_message("%s overflows page width" % [fit])
		assert_bool(int(fit[1]) + int(fit[3]) <= LETTER_LANDSCAPE_H).is_true() \
			.override_failure_message("%s overflows page height" % [fit])


func test_fit_rect_degrades_to_full_page_on_a_bad_source_size() -> void:
	# Never return a zero rect — an unreadable sheet beats no sheet.
	assert_array(PdfExportRouter._fit_rect(Vector2i.ZERO, 792, 612)) \
		.is_equal([0, 0, 792, 612])


# ============================================================================
# Text-layer string handling
#
# The two backends need OPPOSITE treatment and a prior design note got it wrong,
# so both halves are pinned here:
#   libharu escapes internally  -> the router must NOT pre-escape (double-escape)
#   GodotPDF concatenates raw   -> the addon must escape at the Tj site
# Reverting the addon half makes the exported file unopenable while the exporter
# still returns OK, which is why this is a test and not a code comment.
# ============================================================================

const GodotPdfScript := preload("res://addons/godotpdf/PDF.gd")


func test_flatten_field_text_does_not_escape_pdf_specials() -> void:
	# If this ever starts escaping, libharu output gains literal backslashes.
	var out: String = PdfExportRouter.flatten_field_text("Vance (Doc) Ryu")
	assert_str(out).is_equal("Vance (Doc) Ryu")
	assert_str(out).not_contains("\\")


func test_flatten_field_text_collapses_newlines_to_one_line() -> void:
	# A raw newline inside `(...)` is legal but splits the search token in two.
	assert_str(PdfExportRouter.flatten_field_text("Fuel Hog\nArmored")) \
		.is_equal("Fuel Hog Armored")
	assert_str(PdfExportRouter.flatten_field_text("a\r\nb")).is_equal("a  b")


func test_godotpdf_escapes_every_pdf_string_special() -> void:
	assert_str(GodotPdfScript.escapePdfText("Vance (Doc) Ryu")) \
		.is_equal("Vance \\(Doc\\) Ryu")
	assert_str(GodotPdfScript.escapePdfText("Half ( Open")).is_equal("Half \\( Open")
	assert_str(GodotPdfScript.escapePdfText("Half ) Close")).is_equal("Half \\) Close")


func test_godotpdf_escape_replaces_backslash_first() -> void:
	# Order matters: escaping parens first would then re-escape the backslashes
	# this step adds, doubling them. A trailing backslash is the sharp case —
	# unescaped it would escape the CLOSING paren and swallow the rest of the file.
	assert_str(GodotPdfScript.escapePdfText("Trail\\")).is_equal("Trail\\\\")
	assert_str(GodotPdfScript.escapePdfText("Mix \\( Weird")) \
		.is_equal("Mix \\\\\\( Weird")


func test_godotpdf_escape_leaves_ordinary_text_untouched() -> void:
	assert_str(GodotPdfScript.escapePdfText("Bryn Ito")).is_equal("Bryn Ito")
	assert_str(GodotPdfScript.escapePdfText("")).is_equal("")


# ============================================================================
# End-to-end ARTIFACT checks (GodotPDF — the backend Android actually uses)
#
# The tests above pin _fit_rect, but the distortion bug lived in the CALLER: the
# helper was never wrong, it simply was not used. So these export a real file and
# read the bytes back.
#
# GodotPDF is the right backend to assert on here for two reasons: it is the one
# that ships to the primary (mobile) platform, and it compresses ONLY the image
# stream, so the page geometry and /Info are plain ASCII in the file. libharu
# flate-compresses its content streams, so the equivalent check for it lives in
# tests/tools/emit_sheet_pdf.gd + the PyPDF2 audit.
#
# No SubViewport and no framebuffer needed — the export path takes any Texture2D.
# ============================================================================

func _tiny_sheet_texture() -> ImageTexture:
	# Same 2764x1843 aspect as the real Core sheets, 1/20th the pixels so the
	# test stays fast. Aspect is the only property these assertions care about.
	var img := Image.create(276, 184, false, Image.FORMAT_RGB8)
	img.fill(Color.WHITE)
	return ImageTexture.create_from_image(img)


func _export_tmp(text_layer: Array = []) -> String:
	var path := "user://_test_pdf_artifact.pdf"
	var err: int = PdfExportRouter._export_via_godotpdf(
		_tiny_sheet_texture(), Vector2(11.0, 8.5), path, text_layer)
	assert_int(err).is_equal(OK)
	var f: FileAccess = FileAccess.open(path, FileAccess.READ)
	assert_object(f).is_not_null()
	var body: String = f.get_buffer(f.get_length()).get_string_from_ascii()
	f.close()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	return body


func test_export_writes_a_landscape_mediabox() -> void:
	# Upstream was locked to US Letter PORTRAIT and the requested page size was
	# thrown away, so a 3:2 sheet filled 53% of a portrait page.
	assert_str(_export_tmp()).contains("/MediaBox [0 0 792 612]")


func test_export_draws_the_sheet_without_stretching_it() -> void:
	# `w 0 0 h x y cm` is the placement matrix. Edge-to-edge on a Letter page
	# would read `792 0 0 612 0 0` — a 15.9% vertical stretch of a 3:2 sheet.
	var body: String = _export_tmp()
	assert_str(body).contains("756 0 0 504 18 54 cm") \
		.override_failure_message(
			"Page matrix is not the letterboxed 792x528 at y=42 — the sheet is "
			+ "being STRETCHED onto the page. See _fit_rect().")
	assert_str(body).not_contains("792 0 0 612 0 0 cm")
	# ...and not the correct-aspect-but-no-margin geometry either, which put
	# the sheet inside the printer's unprintable border.
	assert_str(body).not_contains("792 0 0 528 0 42 cm")


func test_export_does_not_leak_the_addon_authors_metadata() -> void:
	# Upstream hardcoded `_addInfo("Test", "Nolan")`, ignoring newPDF()'s
	# arguments — so every document a player exported, mailed or archived was
	# titled "Test" and credited to a stranger. /Title is what a reader shows in
	# its title bar and what Chrome shows in the browser TAB.
	var body: String = _export_tmp()
	assert_str(body).not_contains("(Test)")
	assert_str(body).not_contains("(Nolan)")
	assert_str(body).contains("/Title (Five Parsecs Sheet Export)")
	assert_str(body).contains("/Creator (Five Parsecs Campaign Manager)")
	assert_str(body).contains("/CreationDate (D:")


func test_export_text_layer_is_invisible_and_lands_after_the_image() -> void:
	# PDF render mode 3 = "neither fill nor stroke" — the OCR-layer technique.
	# If this regressed to mode 0 the export would print a SECOND, misaligned
	# copy of every value on top of the sheet, which is far worse output than a
	# non-searchable file.
	var body: String = _export_tmp([
		{"text": "Bryn Ito", "rect": Rect2(171, 712, 300, 62),
		 "font_size": 26, "align": "left"},
	])
	assert_str(body).contains("3 Tr")
	assert_str(body).contains("(Bryn Ito) Tj")
	var image_at: int = body.find(" Do")
	var text_at: int = body.find("BT")
	assert_bool(image_at > -1 and text_at > image_at).is_true() \
		.override_failure_message(
			"Text must be drawn AFTER the image (Do at %d, BT at %d)" % [image_at, text_at])


func test_export_escapes_hostile_values_in_the_text_layer() -> void:
	# A crew member called "Vance (Doc) Ryu" is a legal name and used to produce
	# an unopenable file — while the exporter still returned OK.
	var body: String = _export_tmp([
		{"text": "Vance (Doc) Ryu", "rect": Rect2(0, 0, 300, 62),
		 "font_size": 26, "align": "left"},
	])
	assert_str(body).contains("(Vance \\(Doc\\) Ryu) Tj")


func test_export_omits_the_text_layer_when_none_is_given() -> void:
	# The layer is optional; a caller that passes nothing must still get a file
	# with no stray BT/ET block.
	assert_str(_export_tmp()).not_contains(" Tj")
