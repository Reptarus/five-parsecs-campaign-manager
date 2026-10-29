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


# ── BBCode colour roles (Sprint U, 2026-10-28) ──────────────────────────────
# The Planetfall panels hand-wrote 64 hex [color] tags in three ambers and two reds.
# They now name a role ([color=ui-success]) that UIColors.bbcode() resolves.

func test_every_bbcode_role_clears_aa_on_the_card() -> void:
	for role: String in UIColorsRef.BBCODE_ROLES:
		var ratio := _contrast(UIColorsRef.BBCODE_ROLES[role], UIColorsRef.COLOR_SECONDARY)
		assert_float(ratio).override_failure_message(
			"%s on the card = %.2f, below AA %.1f" % [role, ratio, AA_NORMAL_TEXT]) \
			.is_greater_equal(AA_NORMAL_TEXT)


func test_bbcode_resolves_every_role_to_its_palette_hex() -> void:
	for role: String in UIColorsRef.BBCODE_ROLES:
		var hex: String = (UIColorsRef.BBCODE_ROLES[role] as Color).to_html(false)
		assert_str(UIColorsRef.bbcode("a [color=%s]b %d[/color] c" % [role, 3])) \
			.is_equal("a [color=#%s]b 3[/color] c" % hex)
	assert_str(UIColorsRef.bbcode("[color=#123456]kept[/color]")) \
		.is_equal("[color=#123456]kept[/color]")


func test_planetfall_text_names_roles_not_hex() -> void:
	var files: Array = []
	_collect_gd_files("res://src/ui/screens/planetfall", files)
	assert_int(files.size()).override_failure_message(
		"scanned %d Planetfall scripts; the walk is broken" % files.size()).is_greater(20)
	# Both shapes: a literal tag, and a quoted hex fed to "[color=%s]" (one hid there).
	# A Color("#...") constructor is a palette definition, not text.
	var quoted_hex := RegEx.create_from_string("(?<!Color\\()\"#[0-9A-Fa-f]{6}\"")
	var hex_tags: Array[String] = []
	for path: String in files:
		var lines := FileAccess.get_file_as_string(path).split("\n")
		for i in range(lines.size()):
			if lines[i].strip_edges().begins_with("#"):
				continue
			if lines[i].contains("[color=#") or quoted_hex.search(lines[i]) != null:
				hex_tags.append("%s:%d" % [path, i + 1])
	assert_array(hex_tags).override_failure_message(
		"hex [color] tags are back: %s" % str(hex_tags)).is_empty()

	# A misspelt role renders in the default colour with no error anywhere.
	var src: Array = []
	_collect_gd_files("res://src", src)
	# A role can also arrive through a variable: `"[color=%s]" % color` with color "ui-…".
	var role_re := RegEx.create_from_string(
		"(?:\\[color=|\")(ui-[a-z_]+(?:-[a-z_]+)*)(?:\\]|\")")
	var unknown: Array[String] = []
	var seen := 0
	for path: String in src:
		var text := FileAccess.get_file_as_string(path)
		if not text.contains("ui-"):
			continue
		for m in role_re.search_all(text):
			seen += 1
			if not UIColorsRef.BBCODE_ROLES.has(m.get_string(1)):
				unknown.append("%s: %s" % [path, m.get_string(1)])
	assert_int(seen).override_failure_message("premise: roles are in use").is_greater(60)
	assert_array(unknown).override_failure_message("unknown roles: %s" % str(unknown)) \
		.is_empty()


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


## A scene stores the same grey as floats, so the hex scan above never saw it: five
## Labels in four scenes (two step labels, a stats line, an action label, the tier
## badge) still drew it on 2026-10-28.
func test_the_failing_grey_is_gone_from_scenes() -> void:
	var scenes: Array = []
	_collect_files("res://src", [".tscn", ".tres"], scenes)
	assert_int(scenes.size()).override_failure_message(
		"scanned %d scenes; the walk is broken" % scenes.size()).is_greater(50)
	var offenders: Array[String] = []
	for path: String in scenes:
		var lines := FileAccess.get_file_as_string(path).split("\n")
		for i in range(lines.size()):
			if lines[i].contains("Color(0.502, 0.502, 0.502"):
				offenders.append("%s:%d" % [path, i + 1])
	assert_array(offenders).override_failure_message(
		"the failing grey is in a scene at: %s" % str(offenders)).is_empty()


## Bold and italic runs take the label's size. Overriding `normal_font_size` alone left
## them at the theme's 16 px, so "Colony Morale will be: 5 -> [b]4[/b]" printed the 4
## larger than the line. Every RichTextLabel size goes through the one helper.
func _bracket_depth(line: String) -> int:
	return line.count("[") + line.count("{") + line.count("(") \
		- line.count("]") - line.count("}") - line.count(")")


## Every colour a UI script writes is a UIColors token or a named palette constant.
## There were 137 inline Color("#...") literals in 22 files, most of them the OLD values
## of tokens UIColors has since moved (#D97706 was COLOR_WARNING, #252542 was
## COLOR_ELEVATED), so the battle screens drew a palette the rest of the app had left.
## A declaration (any const, or a member var at column 0) may hold a hex: that is
## where a categorical palette lives, defined once.
func test_ui_scripts_write_no_inline_hex_colours() -> void:
	var files: Array = []
	_collect_gd_files("res://src/ui", files)
	assert_int(files.size()).override_failure_message(
		"premise: the walk found the UI scripts (237 on 2026-10-29)").is_greater(200)
	var decl := RegEx.create_from_string("^(\\s*(static )?const|var) [A-Za-z_]+")
	var inline: Array[String] = []
	for path: String in files:
		if path.ends_with("/UIColors.gd") or path.ends_with("/AccessibilityThemes.gd"):
			continue
		var depth := 0
		var lines := FileAccess.get_file_as_string(path).split("\n")
		for i in range(lines.size()):
			var line: String = lines[i]
			if depth > 0:
				depth += _bracket_depth(line)
				continue
			if decl.search(line) != null:
				depth = maxi(0, _bracket_depth(line))
				continue
			if line.strip_edges().begins_with("#"):
				continue
			if line.contains("Color(\"#"):
				inline.append("%s:%d" % [path, i + 1])
	assert_array(inline).override_failure_message(
		"inline hex colours (use a UIColors token):\n%s" % "\n".join(inline)).is_empty()


## A local const named after a token must BE the token. TerrainLegendStrip bound
## COLOR_TEXT_SECONDARY to a failing grey (recorded in CLAUDE.md), and 16 more such
## consts survived in the battle UI, each restating a legacy value.
func test_no_const_restates_a_token_with_a_hex() -> void:
	var tokens: Dictionary = load("res://src/ui/components/base/UIColors.gd") \
		.get_script_constant_map()
	assert_bool(tokens.has("COLOR_BASE") and tokens.has("COLOR_TEXT_PRIMARY")) \
		.override_failure_message("premise: read the UIColors constants").is_true()
	var files: Array = []
	_collect_gd_files("res://src", files)
	var hex_const := RegEx.create_from_string(
		"^\\s*const ([A-Z_]+) *(:[^=]*)?:?= *Color\\(\"#")
	var shadows: Array[String] = []
	for path: String in files:
		if path.ends_with("/UIColors.gd"):
			continue
		var lines := FileAccess.get_file_as_string(path).split("\n")
		for i in range(lines.size()):
			var m := hex_const.search(lines[i])
			if m != null and tokens.has(m.get_string(1)):
				shadows.append("%s:%d %s" % [path, i + 1, m.get_string(1)])
	assert_array(shadows).override_failure_message(
		"consts restating a token with a hex:\n%s" % "\n".join(shadows)).is_empty()


## One avatar palette. Five screens kept their own list and Bug Hunt's differed, so a
## character moved between modes changed colour.
func test_every_avatar_reads_the_one_palette() -> void:
	var files: Array = []
	_collect_gd_files("res://src", files)
	var callers := 0
	var copies: Array[String] = []
	for path: String in files:
		var src := FileAccess.get_file_as_string(path)
		callers += src.count("UIColors.avatar_color(")
		if not path.ends_with("/UIColors.gd") and src.contains("Color(\"#ec4899\")"):
			copies.append(path)
	assert_int(callers).override_failure_message(
		"the avatar sites no longer read UIColors.avatar_color()").is_greater_equal(5)
	assert_array(copies).override_failure_message(
		"another avatar palette: %s" % str(copies)).is_empty()
	assert_object(UIColors.avatar_color("Bryn Ito")).is_equal(UIColors.avatar_color("Bryn Ito"))
	var seen := {}
	for n in ["Ada", "Bryn", "Cass", "Dov", "Eli", "Fen", "Gil", "Hal", "Ira", "Jo"]:
		seen[UIColors.avatar_color(n).to_html()] = true
	assert_int(seen.size()).override_failure_message(
		"ten names drew %d colours" % seen.size()).is_greater(3)


## The battle screen sizes text through _scaled_font() (ResponsiveManager), 24 times.
## 27 more sites wrote a fixed size, so on a phone and on a wide screen the crew rail,
## the terrain controls, the psionics card and the end-of-phase checklist kept a
## desktop size while everything beside them scaled.
func test_the_battle_screen_scales_every_font_size() -> void:
	var path := "res://src/ui/screens/battle/TacticalBattleUI.gd"
	var lines := FileAccess.get_file_as_string(path).split("\n")
	assert_int(lines.size()).override_failure_message("premise: read %s" % path) \
		.is_greater(5000)
	var literal := RegEx.create_from_string(
		"_font_size_override\\(\"[a-z_]*font_size\", *\\d+\\)|size_rich_text\\([^,]+, *\\d+\\)")
	var scaled := 0
	var fixed: Array[String] = []
	for i in range(lines.size()):
		if lines[i].strip_edges().begins_with("#"):
			continue
		if literal.search(lines[i]) != null:
			fixed.append("%d: %s" % [i + 1, lines[i].strip_edges()])
		if lines[i].contains("_scaled_font("):
			scaled += 1
	assert_int(scaled).override_failure_message(
		"premise: the screen routes sizes through _scaled_font()").is_greater(40)
	assert_array(fixed).override_failure_message(
		"fixed font sizes on the battle screen:\n%s" % "\n".join(fixed)).is_empty()


func test_rich_text_bold_takes_the_labels_size() -> void:
	var rtl := RichTextLabel.new()
	auto_free(rtl)
	ScreenChrome.size_rich_text(rtl, 12)
	for key: String in ["normal_font_size", "bold_font_size", "italics_font_size",
			"bold_italics_font_size"]:
		assert_bool(rtl.has_theme_font_size_override(key)).override_failure_message(
			"%s is left at the theme size" % key).is_true()
		assert_int(rtl.get_theme_font_size(key)).is_equal(12)

	var files: Array = []
	_collect_gd_files("res://src", files)
	var raw: Array[String] = []
	var helper_calls := 0
	for path: String in files:
		var text := FileAccess.get_file_as_string(path)
		helper_calls += text.count("ScreenChrome.size_rich_text(")
		if path.ends_with("/ScreenChrome.gd"):
			continue
		var lines := text.split("\n")
		for i in range(lines.size()):
			if lines[i].contains("\"normal_font_size\",") \
					or lines[i].strip_edges().begins_with("\"normal_font_size\"") \
					and lines[i].contains(","):
				raw.append("%s:%d" % [path, i + 1])
	assert_int(helper_calls).override_failure_message("premise: the helper is in use") \
		.is_greater(60)
	assert_array(raw).override_failure_message(
		"a RichTextLabel sizes its normal text only: %s" % str(raw)).is_empty()

	var scenes: Array = []
	_collect_files("res://src", [".tscn"], scenes)
	var bare: Array[String] = []
	for path: String in scenes:
		var text := FileAccess.get_file_as_string(path)
		if text.contains("theme_override_font_sizes/normal_font_size = ") \
				and text.contains("bbcode_enabled = true") \
				and not text.contains("theme_override_font_sizes/bold_font_size = "):
			for line in text.split("\n"):
				if line.begins_with("theme_override_font_sizes/normal_font_size = ") \
						and line.get_slice("= ", 1).to_int() != 16:
					bare.append(path)
					break
	assert_array(bare).override_failure_message(
		"a scene shrinks its rich text but not the bold runs: %s" % str(bare)).is_empty()


func _collect_files(dir_path: String, exts: Array, out: Array) -> void:
	var d := DirAccess.open(dir_path)
	if d == null:
		return
	d.list_dir_begin()
	var entry := d.get_next()
	while entry != "":
		if not entry.begins_with("."):
			var full := dir_path.path_join(entry)
			if d.current_is_dir():
				_collect_files(full, exts, out)
			else:
				for ext: String in exts:
					if entry.ends_with(ext):
						out.append(full)
		entry = d.get_next()
	d.list_dir_end()


# ── CheckBox icons (Sprint U, 2026-10-28) ───────────────────────────────────
# The project theme styled CheckBox text and background but set no icons, so all
# 34 screens that build a CheckBox drew Godot's default glyph: a dark square that
# was all but invisible on this palette (Planetfall Lock and Load read as a list of
# names with nothing to tap). WCAG 2.1 SC 1.4.11 asks 3:1 for a control's boundary.

const THEME_PATH := "res://src/ui/themes/sci_fi_theme.tres"
const NON_TEXT_CONTRAST := 3.0
const CHECK_ICONS := ["checked", "unchecked", "checked_disabled", "unchecked_disabled",
	"radio_checked", "radio_unchecked", "radio_checked_disabled", "radio_unchecked_disabled"]


## The strongest edge an icon draws along its middle row, composited over `bg`.
func _icon_edge_contrast(tex: Texture2D, bg: Color) -> float:
	var img: Image = tex.get_image()
	if img.is_compressed():
		img.decompress()
	var best := 1.0
	var y: int = img.get_height() / 2
	for x in range(img.get_width()):
		var px: Color = img.get_pixel(x, y)
		var shown := Color(lerpf(bg.r, px.r, px.a), lerpf(bg.g, px.g, px.a),
				lerpf(bg.b, px.b, px.a))
		best = maxf(best, _contrast(shown, bg))
	return best


## The premise: the engine's own glyph really does fail here, so the case below
## measures something.
func test_the_default_checkbox_glyph_fails_on_this_palette() -> void:
	var glyph: Texture2D = ThemeDB.get_default_theme().get_icon("unchecked", "CheckBox")
	var ratio := _icon_edge_contrast(glyph, UIColorsRef.COLOR_PRIMARY)
	assert_float(ratio).override_failure_message(
		"premise: the default unchecked glyph reads %.2f on the base" % ratio) \
		.is_less(NON_TEXT_CONTRAST)


func test_the_theme_draws_visible_checkbox_icons() -> void:
	var theme: Theme = load(THEME_PATH)
	for icon in CHECK_ICONS:
		assert_bool(theme.has_icon(icon, "CheckBox")).override_failure_message(
			"the theme sets no CheckBox '%s' icon" % icon).is_true()
	for icon in ["unchecked", "checked", "radio_unchecked", "radio_checked"]:
		for bg in [UIColorsRef.COLOR_PRIMARY, UIColorsRef.COLOR_SECONDARY]:
			var ratio := _icon_edge_contrast(theme.get_icon(icon, "CheckBox"), bg)
			assert_float(ratio).override_failure_message(
				"CheckBox '%s' edge reads %.2f on %s" % [icon, ratio, bg.to_html(false)]) \
				.is_greater_equal(NON_TEXT_CONTRAST)
