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
