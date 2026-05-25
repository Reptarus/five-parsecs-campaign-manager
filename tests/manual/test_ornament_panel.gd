## Manual visual test for OrnamentPanel — proves the architecture's central
## claim: corner accents render at IDENTICAL pixel size across all panel
## sizes (which is what the rulebook does, and what 9-slice CAN'T do).
##
## Launch:
##   - F6 (play current scene) with this .tscn open, OR
##   - Project Settings → Application → Run → Main Scene → set to this .tscn
##
## Layout:
##   Row 1 (sizes):  3 panels of CYAN/PRIMARY at 200x140, 400x280, 700x420
##                   Title banner ON. Corner accents SHOULD look identical
##                   pixel-size across all three (the no-stretch claim).
##   Row 2 (colors): 5 panels of NEUTRAL/PRIMARY/SUCCESS/WARNING/DANGER/PURPLE
##                   at 220x140 each, title banner ON. Proves modulate cascade.
##   Row 3 (no-banner): 3 panels at 280x160, title banner OFF. Proves the
##                   collapse-when-empty branch.
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

	# Row 1 — size variation (corners SHOULD look identical across sizes)
	_add_section_label(root,
			"Sizes (corner accents must be SAME pixel size across all three):")
	var row1 := HBoxContainer.new()
	row1.add_theme_constant_override("separation", 24)
	row1.alignment = BoxContainer.ALIGNMENT_BEGIN
	root.add_child(row1)
	row1.add_child(_make_panel("Small", Vector2(200, 140),
			OrnamentPanelScript.COLOR_PRIMARY, "Compact data card."))
	row1.add_child(_make_panel("Medium", Vector2(400, 280),
			OrnamentPanelScript.COLOR_PRIMARY,
			"Section card holding a paragraph of description text."))
	row1.add_child(_make_panel("Large", Vector2(700, 420),
			OrnamentPanelScript.COLOR_PRIMARY,
			"Dialog-scale container with room for forms, lists, or rich text."))

	# Row 2 — color variation
	_add_section_label(root,
			"Colors (modulate cascades to stroke + accents together):")
	var row2 := HBoxContainer.new()
	row2.add_theme_constant_override("separation", 16)
	row2.alignment = BoxContainer.ALIGNMENT_BEGIN
	root.add_child(row2)
	var color_cases := [
		["Crew", OrnamentPanelScript.COLOR_NEUTRAL],
		["Mission", OrnamentPanelScript.COLOR_PRIMARY],
		["Equipment", OrnamentPanelScript.COLOR_SUCCESS],
		["Upkeep", OrnamentPanelScript.COLOR_WARNING],
		["Rivals", OrnamentPanelScript.COLOR_DANGER],
		["GM Tools", OrnamentPanelScript.COLOR_PURPLE],
	]
	for case in color_cases:
		row2.add_child(_make_panel(case[0], Vector2(220, 140),
				case[1], "Semantic accent."))

	# Row 3 — no-banner variant
	_add_section_label(root,
			"Title banner empty → collapses (3rd panel keeps a title for compare):")
	var row3 := HBoxContainer.new()
	row3.add_theme_constant_override("separation", 24)
	row3.alignment = BoxContainer.ALIGNMENT_BEGIN
	root.add_child(row3)
	row3.add_child(_make_panel("", Vector2(280, 160),
			OrnamentPanelScript.COLOR_PRIMARY,
			"No banner. Just rounded chrome + corner accents."))
	row3.add_child(_make_panel("", Vector2(280, 160),
			OrnamentPanelScript.COLOR_SUCCESS,
			"Another bannerless example, green accent."))
	row3.add_child(_make_panel("With Banner", Vector2(280, 160),
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
