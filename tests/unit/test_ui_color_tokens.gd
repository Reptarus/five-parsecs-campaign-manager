extends GdUnitTestSuite
## The secondary-text token, and the WCAG AA contract nothing was checking.
##
## Found 2026-09-07 while preparing the desk half of TABLET_CHECKLIST §3
## ("Physical legibility ... Deep Space palette legible at low brightness").
##
## `#808080` was NOT the theme's secondary-text colour. The canonical token is
## `UIColors.COLOR_TEXT_SECONDARY` = `#9ca3af`. `#808080` was a hardcoded drift
## sitting at **67 sites across 27 files**, and it fails WCAG AA for normal text
## against every background this app actually renders it on:
##
##     #808080 on #111827 (UIColors card)          4.49   FAILS (needs 4.5)
##     #808080 on #1A1A2E (a11y theme base)        4.32   FAILS
##     #808080 on #252542 (a11y theme elevated)    3.74   FAILS
##     #9ca3af on #111827                          6.99   passes
##     #9ca3af on #1A1A2E                          6.72   passes
##     #9ca3af on #252542                          5.82   passes
##
## Two things made it invisible for so long:
##
## 1. `TerrainLegendStrip.gd:12` declared `const COLOR_TEXT_SECONDARY :=
##    Color("#808080")` — the token's own NAME bound to a different value — so
##    grepping the token returned two colours and neither looked wrong.
## 2. `AccessibilityThemes.gd` opens with *"Complies with WCAG 2.1 Level AA
##    standards for visual accessibility"* and then set `text_secondary` to the
##    failing grey in all three colourblind palettes. It is live via
##    `ThemeManager._apply_colorblind_variant()`, so that reached real users.
##
## ⚠ A stated compliance claim in a docblock is not a test. This suite is the
## test. It asserts the INVARIANT (the token clears AA on the backgrounds in
## play), not the constant — so re-tuning the palette stays legal and dropping
## below AA does not.

const UIColorsRef = preload("res://src/ui/components/base/UIColors.gd")
const AccessibilityThemesRef = preload("res://src/ui/themes/AccessibilityThemes.gd")

## WCAG 2.1 SC 1.4.3 — normal-size text. Large text (>=18.66px bold / >=24px)
## may use 3.0, but secondary text here renders at 10-16px, so it cannot claim
## that exemption.
const AA_NORMAL_TEXT := 4.5

## The grey this sprint removed. Kept ONLY so the contrast helper below can be
## shown to discriminate — see test_the_contrast_helper_actually_discriminates.
const REMOVED_GREY := Color(0.5019608, 0.5019608, 0.5019608)


# ── WCAG 2.1 relative luminance ─────────────────────────────────────────────
# Deliberately NOT Color.srgb_to_linear(): that is the engine's rendering
# transform, which is an approximation in some builds. WCAG defines an exact
# piecewise curve and this is it, so the numbers here match a contrast checker.

func _channel(v: float) -> float:
	if v <= 0.03928:
		return v / 12.92
	return pow((v + 0.055) / 1.055, 2.4)


func _luminance(c: Color) -> float:
	return 0.2126 * _channel(c.r) + 0.7152 * _channel(c.g) + 0.0722 * _channel(c.b)


func _contrast(fg: Color, bg: Color) -> float:
	var a := _luminance(fg)
	var b := _luminance(bg)
	var hi: float = maxf(a, b)
	var lo: float = minf(a, b)
	return (hi + 0.05) / (lo + 0.05)


# ── The premise, instrumented first ─────────────────────────────────────────
# If the helper above were broken and returned a large number for everything,
# every assertion below would pass vacuously. This case makes that impossible:
# the colour we removed must still FAIL, by the same function, on the same
# backgrounds. It is the reason the rest of the suite means anything.

func test_the_contrast_helper_actually_discriminates() -> void:
	var card: Color = UIColorsRef.COLOR_SECONDARY
	assert_float(_contrast(REMOVED_GREY, card)).is_less(AA_NORMAL_TEXT)
	# ...and a known-good pairing must clear it, so the helper is not simply
	# returning something small for everything either.
	assert_float(_contrast(UIColorsRef.COLOR_TEXT_PRIMARY, card)) \
		.is_greater(AA_NORMAL_TEXT)
	# Sanity: identical colours are 1.0, white-on-black is 21.0 (the WCAG bounds).
	assert_float(_contrast(card, card)).is_equal_approx(1.0, 0.001)
	assert_float(_contrast(Color.WHITE, Color.BLACK)).is_equal_approx(21.0, 0.01)


# ── The token clears AA where it is actually rendered ───────────────────────

func test_secondary_text_clears_aa_on_the_card_background() -> void:
	# COLOR_SECONDARY (#111827) is the card background secondary text sits on
	# across the campaign screens and PreBattleUI's "Before You Deploy" block.
	assert_float(_contrast(UIColorsRef.COLOR_TEXT_SECONDARY, UIColorsRef.COLOR_SECONDARY)) \
		.is_greater_equal(AA_NORMAL_TEXT)


func test_secondary_text_clears_aa_on_every_ui_background() -> void:
	var backgrounds := {
		"COLOR_PRIMARY": UIColorsRef.COLOR_PRIMARY,
		"COLOR_SECONDARY": UIColorsRef.COLOR_SECONDARY,
		"COLOR_TERTIARY": UIColorsRef.COLOR_TERTIARY,
	}
	for key: String in backgrounds:
		var ratio := _contrast(UIColorsRef.COLOR_TEXT_SECONDARY, backgrounds[key])
		assert_float(ratio) \
			.override_failure_message(
				"secondary text on %s = %.2f, below AA %.1f" % [key, ratio, AA_NORMAL_TEXT]) \
			.is_greater_equal(AA_NORMAL_TEXT)


func test_primary_text_clears_aa_on_the_card() -> void:
	assert_float(_contrast(UIColorsRef.COLOR_TEXT_PRIMARY, UIColorsRef.COLOR_SECONDARY)) \
		.is_greater_equal(AA_NORMAL_TEXT)


## ⚠ OPEN FINDING, deliberately NOT changed here — surfaced 2026-09-07 by
## the assertion this case replaced, while fixing a different colour.
##
## COLOR_TEXT_MUTED (#6b7280) measures **3.67** on the card background — below
## the 4.5 AA floor for normal text. It is a SECOND hole, independent of the
## drift this suite was written for.
##
## WCAG exempts "inactive user interface components", and UIColors aliases
## COLOR_TEXT_DISABLED to this rung, which would make the exemption apply. But
## the 126 consumers are mostly NOT disabled states: `WeaponTableDisplay`
## prints weapon DAMAGE values in it, `JournalEntryTypes` colours entry labels
## with it, and `NotificationManager.gd:243` uses it for an ACTIVE close
## button. Informational text and live controls get no exemption.
##
## Raising the rung is a palette decision with a 126-site visual footprint and
## it compresses the primary/secondary/muted hierarchy — the owner's call, not
## a silent edit inside a sprint about a different colour.
##
## So this case asserts the 3.0 floor (WCAG's large-text / UI-component
## threshold). That still catches further degradation, and it does NOT lock
## the defect in: raising the rung to clear 4.5 keeps this green.
func test_muted_text_holds_the_3_0_floor_with_its_aa_gap_recorded() -> void:
	var ratio := _contrast(UIColorsRef.COLOR_TEXT_MUTED, UIColorsRef.COLOR_SECONDARY)
	assert_float(ratio).override_failure_message(
		"muted text on the card = %.2f, under even the 3.0 floor" % ratio) \
		.is_greater_equal(3.0)


# ── The accessibility themes must honour their own docblock ─────────────────

func test_every_accessibility_theme_clears_aa_for_secondary_text() -> void:
	# AccessibilityThemes.gd claims WCAG 2.1 AA compliance in its header. Until
	# 2026-09-07 all three colourblind palettes set text_secondary to the failing
	# grey, measuring 4.32 on their base and 3.74 on their elevated background.
	var themes := {
		"HIGH_CONTRAST": AccessibilityThemesRef.HIGH_CONTRAST_THEME,
		"DEUTERANOPIA": AccessibilityThemesRef.DEUTERANOPIA_THEME,
		"PROTANOPIA": AccessibilityThemesRef.PROTANOPIA_THEME,
		"TRITANOPIA": AccessibilityThemesRef.TRITANOPIA_THEME,
	}
	for name_key: String in themes:
		var palette: Dictionary = themes[name_key]
		var fg: Color = palette["text_secondary"]
		for bg_key: String in ["base", "elevated", "input"]:
			var ratio := _contrast(fg, palette[bg_key])
			assert_float(ratio) \
				.override_failure_message(
					"%s text_secondary on %s = %.2f, below AA %.1f"
					% [name_key, bg_key, ratio, AA_NORMAL_TEXT]) \
				.is_greater_equal(AA_NORMAL_TEXT)


# ── The BBCode hex strings must track the Color consts ──────────────────────

func test_bbcode_hex_tokens_match_their_color_consts() -> void:
	# RichTextLabel "[color=#...]" needs a String and a const expression cannot
	# call .to_html(), so UIColors carries both forms. That duplication is only
	# safe because this case fails the moment they disagree.
	assert_object(Color(UIColorsRef.HEX_TEXT_PRIMARY)) \
		.is_equal(UIColorsRef.COLOR_TEXT_PRIMARY)
	assert_object(Color(UIColorsRef.HEX_TEXT_SECONDARY)) \
		.is_equal(UIColorsRef.COLOR_TEXT_SECONDARY)
	assert_object(Color(UIColorsRef.HEX_TEXT_MUTED)) \
		.is_equal(UIColorsRef.COLOR_TEXT_MUTED)


# ── The drift guard ─────────────────────────────────────────────────────────

func _collect_gd_files(dir_path: String, out: Array) -> void:
	var d := DirAccess.open(dir_path)
	if d == null:
		return
	d.list_dir_begin()
	var entry := d.get_next()
	while entry != "":
		if not entry.begins_with("."):
			var full := dir_path.path_join(entry)
			if d.current_is_dir():
				_collect_gd_files(full, out)
			elif entry.ends_with(".gd"):
				out.append(full)
		entry = d.get_next()
	d.list_dir_end()


func test_the_failing_grey_is_gone_from_src() -> void:
	# 67 sites drifted onto this value precisely because nothing checked. The
	# semantic assertions above cannot catch a NEW hardcoded literal — only a
	# source scan can, so the two kinds of case are complementary here.
	# Full-line comments are skipped: this file's own history is documented at
	# UIColors.gd and AccessibilityThemes.gd and must stay readable.
	var files: Array = []
	_collect_gd_files("res://src", files)
	# Sanity floor: src/ held 483 .gd files when this was written, so a walk
	# returning near-nothing is broken rather than clean. The message MUST
	# interpolate the count — a fixed string here once reported "scanned 0"
	# against a healthy 483 and sent the author hunting a phantom bug.
	assert_int(files.size()).override_failure_message(
		"scanned %d .gd files under res://src — expected 400+, so the walk is broken, not the source"
		% files.size()).is_greater(400)

	var offenders: Array[String] = []
	for path: String in files:
		var text := FileAccess.get_file_as_string(path)
		if not text.contains("808080"):
			continue
		var lines := text.split("\n")
		for i in range(lines.size()):
			var line: String = lines[i]
			if not line.contains("808080"):
				continue
			if line.strip_edges().begins_with("#"):
				continue
			offenders.append("%s:%d" % [path, i + 1])

	assert_array(offenders).override_failure_message(
		"the pre-2026-09-07 secondary grey is back at: %s" % str(offenders)).is_empty()
