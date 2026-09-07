extends GdUnitTestSuite
## T11-07 / T11-47 — the content-scale formula's ALGEBRA, finally guarded.
##
## `SettingsManager._apply_ui_scale()` owns the app's ONE global scale knob:
##
##     tree.root.content_scale_factor = TARGET_EFFECTIVE * get_ui_scale() * stretch_cancel
##
## Until 2026-09-06 **nothing anywhere asserted it**. T11-07 was a single `* _dpi_scale()`
## on the end of that line: `stretch_cancel` cancels the engine's square-base stretch, so
## the algebra collapsed to `effective = TARGET_EFFECTIVE * ui_scale * dpi` and every
## 2.0-density Android device rendered at **2.32x instead of 1.16x** — text ~2x, content
## clipped off the top and bottom, "Settings" pushed off-screen.
##
## ⭐ It shipped because **desktop density is 1.0**, so the offending factor was exactly
## 1.0 on every machine that ran the gates. A green desk suite was not evidence; it was
## the density term being invisible. That is what this suite exists to change.
##
## ── WHY THIS IS TESTABLE AT ALL ──────────────────────────────────────────────
## `SettingsManager._dpi_scale()` prefers `ResponsiveManager.get_screen_scale()`, which
## returns the plain member `screen_scale_factor`. Writing that member lets a headless
## desktop run pretend to be a 2.0-density tablet, so a re-introduced density term is
## OBSERVABLE here. Without that injection point this suite could not exist, which is
## why test_the_density_injection_actually_reaches_the_formula() asserts the injection
## works BEFORE anything else relies on it — an uninstrumented stimulus would make the
## main case pass vacuously (reference_instrument_the_probes_own_premise).
##
## ── ASSERT THE INVARIANT, NEVER THE CONSTANT ─────────────────────────────────
## `TARGET_EFFECTIVE` is a function-local const and unreadable from here, and hardcoding
## 1.16 would only have to be edited by the same person making the mistake — the trap
## `verify_layout._dp_ratio()` already avoids by deriving its ratio live. Every case
## below derives what it compares.
##
## ⚠ SCOPE. Headless, `DisplayServer.window_get_size()` reports 0, so `_apply_ui_scale()`
## takes its `short_axis <= 0.0` fallback and `stretch_cancel` is pinned at 1.0. That
## means content_scale_factor IS the net effective scale here — convenient, but it also
## means **the window-size cancellation is not exercised by this suite**. That half is
## covered by the true-pixel rows in tests/tools/verify_layout.gd and verify_rotation.gd,
## which need a real window. Do not read a green run here as "the formula is fully
## verified"; read it as "no density term, and linear in the user slider".

const _EPS := 0.0005

var _sm: Node
var _rm: Node
var _saved_density: float = 1.0
var _saved_ui: float = 1.0
var _saved_csf: float = 1.0


func before_test() -> void:
	_sm = get_node_or_null("/root/SettingsManager")
	_rm = get_node_or_null("/root/ResponsiveManager")
	assert_object(_sm).override_failure_message(
		"SettingsManager autoload missing — this suite drives the real formula, not a copy"
	).is_not_null()
	assert_object(_rm).override_failure_message(
		"ResponsiveManager autoload missing — it is the density injection point"
	).is_not_null()
	_saved_density = _rm.screen_scale_factor
	_saved_ui = _sm.get_ui_scale()
	_saved_csf = get_tree().root.content_scale_factor


func after_test() -> void:
	# This suite mutates GLOBAL state — the root's content scale and the settings
	# object every other screen reads. Leaving either changed would silently re-scale
	# the rest of the batch, which is the `user://window.ini` trap in a new costume.
	if _rm:
		_rm.screen_scale_factor = _saved_density
	if _sm:
		# Written straight into the ConfigFile, NEVER through set_setting(): that
		# starts a debounced save and would persist a test value into
		# user://options.cfg for every future run.
		_sm._config.set_value("display", "ui_scale", _saved_ui)
		_sm._apply_ui_scale()
	get_tree().root.content_scale_factor = _saved_csf


## Apply the REAL formula under a chosen density and slider, and report what it set.
func _scale_at(density: float, ui: float) -> float:
	_rm.screen_scale_factor = density
	_sm._config.set_value("display", "ui_scale", ui)
	_sm._apply_ui_scale()
	return get_tree().root.content_scale_factor


func test_the_density_injection_actually_reaches_the_formula() -> void:
	# The premise every other case rests on. If writing screen_scale_factor did not
	# reach _dpi_scale(), the density case below would compare 1.0 against 1.0 and pass
	# no matter what the formula did — a diagnostic that cannot disagree.
	_rm.screen_scale_factor = 2.0
	assert_float(_sm._dpi_scale()).override_failure_message(
		"setting ResponsiveManager.screen_scale_factor must reach "
		+ "SettingsManager._dpi_scale(), or the density case proves nothing"
	).is_equal_approx(2.0, _EPS)

	_rm.screen_scale_factor = 2.75
	assert_float(_sm._dpi_scale()).is_equal_approx(2.75, _EPS)


func test_the_scale_ignores_display_density() -> void:
	# ⭐ THE T11-07 GUARD. Re-add `* _dpi_scale()` to SettingsManager.gd and this fails.
	# The densities are the real ones: 1.0 desktop, 2.0 the TB361FU test tablet, 2.75 a
	# common xxhdpi phone.
	var at_desktop := _scale_at(1.0, 1.0)
	var at_tablet := _scale_at(2.0, 1.0)
	var at_phone := _scale_at(2.75, 1.0)

	assert_float(at_tablet).override_failure_message(
		"content_scale_factor moved when only the DISPLAY DENSITY changed (%f -> %f). "
		% [at_desktop, at_tablet]
		+ "That is T11-07: the square-base stretch already normalises physical size, so "
		+ "multiplying by density double-counts it and the device renders ~2x too large."
	).is_equal_approx(at_desktop, _EPS)

	assert_float(at_phone).override_failure_message(
		"content_scale_factor moved with density at 2.75 (%f -> %f)"
		% [at_desktop, at_phone]
	).is_equal_approx(at_desktop, _EPS)


func test_the_scale_is_linear_in_the_user_slider() -> void:
	# The slider is the one factor that SHOULD move it, and proportionally. Asserting the
	# RATIO rather than a value derives TARGET_EFFECTIVE live, so this case survives a
	# deliberate re-tune of that constant and still fails if the slider is dropped,
	# squared, or clamped.
	var base := _scale_at(1.0, 1.0)
	assert_float(base).override_failure_message(
		"content_scale_factor must be positive at the default slider"
	).is_greater(0.0)

	for factor in [0.75, 1.25, 1.5]:
		var got := _scale_at(1.0, factor)
		assert_float(got / base).override_failure_message(
			"ui_scale %f should scale the result by exactly that factor "
			% factor
			+ "(got %f, base %f, ratio %f)" % [got, base, got / base]
		).is_equal_approx(factor, _EPS)


func test_density_and_slider_do_not_interact() -> void:
	# Belt and braces on the two above: a density term hidden INSIDE the slider path
	# (e.g. `ui * dpi`) would pass both cases individually — the density case runs at a
	# fixed slider of 1.0, and the linearity case runs at a fixed density of 1.0. Only
	# varying both at once closes that gap.
	var base := _scale_at(1.0, 1.0)
	var both := _scale_at(2.0, 1.5)
	assert_float(both / base).override_failure_message(
		"with density 2.0 and slider 1.5 the result must be 1.5x the baseline, not 3.0x "
		+ "(got ratio %f) — a density factor folded into the slider path" % (both / base)
	).is_equal_approx(1.5, _EPS)
