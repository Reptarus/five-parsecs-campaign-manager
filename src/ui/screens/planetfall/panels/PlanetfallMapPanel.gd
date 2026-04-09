extends Control

## Planetfall Creation Step 4: Map Generation
## Player picks grid size (6x6/6x10/10x10), home sector,
## and 10 investigation sites are randomly placed.
## TODO: Interactive map preview — currently auto-generates.

signal map_updated(data: Dictionary)

const UIColorsRef = preload("res://src/ui/components/base/UIColors.gd")

var _coordinator = null


func set_coordinator(coord) -> void:
	_coordinator = coord


func _ready() -> void:
	_build_placeholder()


func _build_placeholder() -> void:
	var scroll := ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)

	var content := VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 16)
	scroll.add_child(content)

	var header := Label.new()
	header.text = "MAP GENERATION"
	header.add_theme_font_size_override("font_size", 18)
	header.add_theme_color_override("font_color", UIColorsRef.COLOR_TEXT_PRIMARY)
	content.add_child(header)

	var desc := Label.new()
	desc.text = "Choose your colony map size. 10 Investigation Sites will be placed randomly."
	desc.add_theme_font_size_override("font_size", 14)
	desc.add_theme_color_override("font_color", UIColorsRef.COLOR_TEXT_SECONDARY)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(desc)

	# Grid size buttons
	var sizes := [
		{"label": "6 x 6 (Standard — 36 sectors)", "rows": 6, "cols": 6},
		{"label": "6 x 10 (Large — 60 sectors)", "rows": 6, "cols": 10},
		{"label": "10 x 10 (Epic — 100 sectors)", "rows": 10, "cols": 10},
	]
	for size_opt in sizes:
		var btn := Button.new()
		btn.text = size_opt.label
		btn.custom_minimum_size = Vector2(300, 48)
		var r: int = size_opt.rows
		var c: int = size_opt.cols
		btn.pressed.connect(func(): _on_size_selected(r, c))
		content.add_child(btn)


func _on_size_selected(rows: int, cols: int) -> void:
	# Auto-place home sector at center-ish and 10 random investigation sites
	var home := [rows / 2, cols / 2]
	var sites: Array = []
	var used: Dictionary = {"%d_%d" % [home[0], home[1]]: true}
	var attempts := 0
	while sites.size() < 10 and attempts < 200:
		var r := randi_range(0, rows - 1)
		var c := randi_range(0, cols - 1)
		var key := "%d_%d" % [r, c]
		if not used.has(key):
			used[key] = true
			sites.append([r, c])
		attempts += 1

	var data := {
		"grid_size": [rows, cols],
		"grid_rows": rows,
		"grid_cols": cols,
		"home_sector": home,
		"investigation_sites": sites
	}
	map_updated.emit(data)
