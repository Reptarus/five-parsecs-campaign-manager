## Manual visual test for OrnamentPanel.
##
## Proves three claims:
##   1. Within an atlas variant, bracket size is fixed regardless of panel
##      size (NinePatchRect "corners stay native" behavior).
##   2. Below COMPACT_THRESHOLD (256 on shorter axis), the panel auto-
##      switches to the 32px-corner atlas; at/above, it uses 64px.
##   3. accent_color cascades to stroke + banner stroke + bracket modulate.
##
## Launch:
##   - F6 (play current scene) with this .tscn open, OR
##   - Project Settings → Application → Run → Main Scene → set to this .tscn
##
## Layout:
##   Row 1 (standard-atlas sizes):
##     3 panels at 400x280, 550x360, 700x420 — all on shorter-axis >= 256
##     so all use the 64px-corner standard atlas. Brackets MUST render at
##     identical pixel size across all three (this is the architecture's
##     central claim).
##   Row 2 (atlas auto-switch):
##     Small panel at 200x140 (compact atlas, 32px corners) next to
##     Medium at 400x280 (standard atlas, 64px corners). Brackets WILL
##     differ in size between the two — that's the intended threshold
##     behavior, not a bug.
##   Row 3 (color cascade):
##     6 panels at 220x140 each, one per semantic color
##     (NEUTRAL/PRIMARY/SUCCESS/WARNING/DANGER/PURPLE). All on compact
##     atlas; stroke + banner stroke + bracket tint all match the color.
##   Row 4 (no-banner variant):
##     3 panels at 280x160, two with empty title_text (banner collapses)
##     and one with title (for side-by-side compare).
extends Control

const OrnamentPanelScript = preload(
		"res://src/ui/components/common/OrnamentPanel.gd")


func _ready() -> void:
	# Dark background so chrome reads against it
	var bg := ColorRect.new()
	bg.color = Color("#1A1A2E")
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.show_behind_parent = true
	add_child(bg)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 32)
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("margin_left", 32)
	root.add_theme_constant_override("margin_top", 32)
	add_child(root)

	# Title for the test scene
	var heading := Label.new()
	heading.text = "OrnamentPanel — Visual Test"
	heading.add_theme_font_size_override("font_size", 24)
	heading.add_theme_color_override("font_color", Color("#E0E0E0"))
	root.add_child(heading)

	# Row 1 — same atlas, different sizes (brackets MUST match pixel-size)
	_add_section_label(root,
			"Row 1 — Standard atlas (shorter axis >= 256): brackets must be IDENTICAL pixel size across all three.")
	var row1 := HBoxContainer.new()
	row1.add_theme_constant_override("separation", 24)
	row1.alignment = BoxContainer.ALIGNMENT_BEGIN
	root.add_child(row1)
	row1.add_child(_make_panel("Medium", Vector2(400, 280),
			OrnamentPanelScript.COLOR_PRIMARY,
			"Section card holding a paragraph of description text."))
	row1.add_child(_make_panel("Larger", Vector2(550, 360),
			OrnamentPanelScript.COLOR_PRIMARY,
			"Wider section with extra room for content."))
	row1.add_child(_make_panel("Large", Vector2(700, 420),
			OrnamentPanelScript.COLOR_PRIMARY,
			"Dialog-scale container with room for forms, lists, or rich text."))

	# Row 2 — atlas auto-switch (compact vs standard at the 256 threshold)
	_add_section_label(root,
			"Row 2 — Atlas auto-switch: Small (200x140 → compact 32px corners) next to Medium (400x280 → standard 64px corners). Different bracket sizes are EXPECTED here.")
	var row2 := HBoxContainer.new()
	row2.add_theme_constant_override("separation", 24)
	row2.alignment = BoxContainer.ALIGNMENT_BEGIN
	root.add_child(row2)
	row2.add_child(_make_panel("Stat Badge", Vector2(200, 140),
			OrnamentPanelScript.COLOR_PRIMARY,
			"Compact atlas (small bracket)."))
	row2.add_child(_make_panel("Section Card", Vector2(400, 280),
			OrnamentPanelScript.COLOR_PRIMARY,
			"Standard atlas (large bracket)."))

	# Row 3 — color variation (proves modulate cascade)
	_add_section_label(root,
			"Row 3 — Modulate cascade: stroke + banner stroke + bracket tint move together for all 6 semantic colors.")
	var row3 := HBoxContainer.new()
	row3.add_theme_constant_override("separation", 16)
	row3.alignment = BoxContainer.ALIGNMENT_BEGIN
	root.add_child(row3)
	var color_cases := [
		["Crew", OrnamentPanelScript.COLOR_NEUTRAL],
		["Mission", OrnamentPanelScript.COLOR_PRIMARY],
		["Equipment", OrnamentPanelScript.COLOR_SUCCESS],
		["Upkeep", OrnamentPanelScript.COLOR_WARNING],
		["Rivals", OrnamentPanelScript.COLOR_DANGER],
		["GM Tools", OrnamentPanelScript.COLOR_PURPLE],
	]
	for case in color_cases:
		row3.add_child(_make_panel(case[0], Vector2(220, 140),
				case[1], "Semantic accent."))

	# Row 4 — no-banner variant (proves banner-collapse branch)
	_add_section_label(root,
			"Row 4 — Empty title_text → banner row collapses. The 3rd panel keeps its title for side-by-side compare.")
	var row4 := HBoxContainer.new()
	row4.add_theme_constant_override("separation", 24)
	row4.alignment = BoxContainer.ALIGNMENT_BEGIN
	root.add_child(row4)
	row4.add_child(_make_panel("", Vector2(280, 160),
			OrnamentPanelScript.COLOR_PRIMARY,
			"No banner. Just rounded chrome + corner accents."))
	row4.add_child(_make_panel("", Vector2(280, 160),
			OrnamentPanelScript.COLOR_SUCCESS,
			"Another bannerless example, green accent."))
	row4.add_child(_make_panel("With Banner", Vector2(280, 160),
			OrnamentPanelScript.COLOR_PRIMARY,
			"Banner ON, for side-by-side comparison."))


func _add_section_label(parent: Control, text: String) -> void:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", 14)
	lbl.add_theme_color_override("font_color", Color("#808080"))
	parent.add_child(lbl)


func _make_panel(title: String, size: Vector2, color: Color,
		body_text: String) -> Control:
	var panel: Control = OrnamentPanelScript.new()
	panel.custom_minimum_size = size
	panel.accent_color = color
	panel.title_text = title

	var body := Label.new()
	body.text = body_text
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_theme_font_size_override("font_size", 13)
	body.add_theme_color_override("font_color", Color("#E0E0E0"))
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.add_content_child(body)
	return panel
