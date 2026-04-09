extends Control

## Planetfall Creation Step 6: Final Review
## Shows summary of all creation choices before launching the campaign.

const UIColorsRef = preload("res://src/ui/components/base/UIColors.gd")

var _coordinator = null
var _content: VBoxContainer


func set_coordinator(coord) -> void:
	_coordinator = coord


func _ready() -> void:
	_build_ui()


func refresh() -> void:
	if not _coordinator or not _content:
		return
	# Clear and rebuild
	for child in _content.get_children():
		child.queue_free()
	_build_summary()
	if _coordinator:
		_coordinator.mark_review_seen()


func _build_ui() -> void:
	var scroll := ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)

	_content = VBoxContainer.new()
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.add_theme_constant_override("separation", 12)
	scroll.add_child(_content)

	_build_summary()


func _build_summary() -> void:
	if not _coordinator:
		var placeholder := Label.new()
		placeholder.text = "Waiting for data..."
		placeholder.add_theme_color_override("font_color", UIColorsRef.COLOR_TEXT_SECONDARY)
		_content.add_child(placeholder)
		return

	var data: Dictionary = _coordinator.get_all_data()

	# Header
	var header := Label.new()
	header.text = "COLONY REVIEW"
	header.add_theme_font_size_override("font_size", 20)
	header.add_theme_color_override("font_color", UIColorsRef.COLOR_TEXT_PRIMARY)
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_content.add_child(header)

	# Config summary
	var config: Dictionary = data.get("config", {})
	_add_info_row("Campaign", config.get("campaign_name", "Unnamed"))
	_add_info_row("Colony", config.get("colony_name", "—"))
	_add_info_row("Expedition", config.get("expedition_type", "—"))

	# Roster summary
	var roster: Array = data.get("roster", [])
	var class_counts := {"scientist": 0, "scout": 0, "trooper": 0}
	for char_dict in roster:
		var cls: String = char_dict.get("class", "")
		if class_counts.has(cls):
			class_counts[cls] += 1
	_add_info_row("Roster", "%d characters (%dS / %dSc / %dT)" % [
		roster.size(), class_counts.scientist, class_counts.scout, class_counts.trooper
	])

	# Map summary
	var map_cfg: Dictionary = data.get("map_config", {})
	if map_cfg.has("grid_size"):
		var gs: Array = map_cfg.grid_size
		_add_info_row("Map", "%d x %d grid (%d sectors)" % [gs[0], gs[1], gs[0] * gs[1]])

	# Tutorial results
	var tut: Dictionary = data.get("tutorial_results", {})
	var tut_text := ""
	if tut.get("beacons_success", false):
		tut_text += "Beacons +2 RM  "
	if tut.get("analysis_success", false):
		tut_text += "Analysis +RP  "
	if tut.get("perimeter_success", false):
		tut_text += "Perimeter +3 Morale"
	if tut_text.is_empty():
		tut_text = "Skipped or pending"
	_add_info_row("Tutorials", tut_text.strip_edges())

	# Ready message
	var ready_lbl := Label.new()
	ready_lbl.text = "\nPress 'Establish Colony' to begin your Planetfall campaign!"
	ready_lbl.add_theme_font_size_override("font_size", 16)
	ready_lbl.add_theme_color_override("font_color", Color("#10B981"))
	ready_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ready_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_content.add_child(ready_lbl)


func _add_info_row(label_text: String, value_text: String) -> void:
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 8)

	var lbl := Label.new()
	lbl.text = label_text + ":"
	lbl.add_theme_font_size_override("font_size", 15)
	lbl.add_theme_color_override("font_color", UIColorsRef.COLOR_TEXT_SECONDARY)
	lbl.custom_minimum_size = Vector2(120, 0)
	hbox.add_child(lbl)

	var val := Label.new()
	val.text = value_text
	val.add_theme_font_size_override("font_size", 15)
	val.add_theme_color_override("font_color", UIColorsRef.COLOR_TEXT_PRIMARY)
	val.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	val.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hbox.add_child(val)

	_content.add_child(hbox)
