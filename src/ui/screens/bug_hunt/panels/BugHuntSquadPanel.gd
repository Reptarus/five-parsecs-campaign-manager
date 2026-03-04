extends Control

## Bug Hunt Squad Panel — Step 2 of 4
## Generate 3-4 main characters, view their stats and backgrounds.

signal squad_updated(data: Dictionary)

const COLOR_BASE := Color("#1A1A2E")
const COLOR_ELEVATED := Color("#252542")
const COLOR_TEXT := Color("#E0E0E0")
const COLOR_TEXT_SEC := Color("#808080")
const COLOR_BORDER := Color("#3A3A5C")
const COLOR_SUCCESS := Color("#10B981")

var _coordinator = null
var _characters_container: VBoxContainer
var _generate_button: Button
var _status_label: Label
var _name_edits: Array[LineEdit] = []

var _squad_data: Dictionary = {
	"main_characters": [],
	"total_reputation": 0
}


func _ready() -> void:
	_build_ui()


func set_coordinator(coord) -> void:
	_coordinator = coord


func _build_ui() -> void:
	var scroll := ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(scroll)

	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 16)
	scroll.add_child(vbox)

	var title := Label.new()
	title.text = "SQUAD SETUP"
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", COLOR_TEXT)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	var desc := Label.new()
	desc.text = "Your squad consists of 3-4 Main Characters. Enter names below (or leave blank for auto-names), then generate your squad."
	desc.add_theme_color_override("font_color", COLOR_TEXT_SEC)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(desc)

	# Name inputs
	var names_card := _create_card("Character Names", vbox)
	_name_edits.clear()
	for i in range(4):
		var hbox := HBoxContainer.new()
		hbox.add_theme_constant_override("separation", 8)
		names_card.add_child(hbox)

		var lbl := Label.new()
		lbl.text = "MC %d:" % (i + 1)
		lbl.add_theme_color_override("font_color", COLOR_TEXT)
		lbl.custom_minimum_size.x = 48
		hbox.add_child(lbl)

		var edit := LineEdit.new()
		edit.placeholder_text = "Auto-generate name" if i < 3 else "(Optional 4th character)"
		edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		edit.custom_minimum_size.y = 40
		hbox.add_child(edit)
		_name_edits.append(edit)

	# Generate button
	_generate_button = Button.new()
	_generate_button.text = "Generate Squad (D100 Tables)"
	_generate_button.custom_minimum_size.y = 56
	_generate_button.pressed.connect(_on_generate_squad)
	vbox.add_child(_generate_button)

	# Status
	_status_label = Label.new()
	_status_label.text = "No squad generated yet."
	_status_label.add_theme_color_override("font_color", COLOR_TEXT_SEC)
	vbox.add_child(_status_label)

	# Characters display
	_characters_container = VBoxContainer.new()
	_characters_container.add_theme_constant_override("separation", 12)
	vbox.add_child(_characters_container)


func _create_card(title_text: String, parent: Control) -> VBoxContainer:
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = COLOR_ELEVATED
	style.border_color = COLOR_BORDER
	style.set_border_width_all(1)
	style.set_corner_radius_all(8)
	style.content_margin_left = 16
	style.content_margin_right = 16
	style.content_margin_top = 16
	style.content_margin_bottom = 16
	panel.add_theme_stylebox_override("panel", style)
	parent.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	panel.add_child(vbox)

	var lbl := Label.new()
	lbl.text = title_text
	lbl.add_theme_font_size_override("font_size", 18)
	lbl.add_theme_color_override("font_color", COLOR_TEXT)
	vbox.add_child(lbl)

	return vbox


func _on_generate_squad() -> void:
	if not _coordinator or not _coordinator.has_method("generate_squad"):
		return

	var names: Array = []
	for edit in _name_edits:
		var txt: String = edit.text.strip_edges()
		if not txt.is_empty():
			names.append(txt)

	var result: Dictionary = _coordinator.generate_squad(names)
	_squad_data = result.duplicate(true)

	_display_squad()
	_emit_update()


func _display_squad() -> void:
	# Clear previous
	for child in _characters_container.get_children():
		child.queue_free()

	var characters: Array = _squad_data.get("main_characters", [])
	_status_label.text = "%d Main Characters generated. Starting Reputation: %d" % [
		characters.size(), _squad_data.get("total_reputation", 0)]
	_status_label.add_theme_color_override("font_color", COLOR_SUCCESS)

	for mc in characters:
		if mc is Dictionary:
			_add_character_card(mc)


func _add_character_card(mc: Dictionary) -> void:
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = COLOR_ELEVATED
	style.border_color = COLOR_BORDER
	style.set_border_width_all(1)
	style.set_corner_radius_all(8)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 12
	style.content_margin_bottom = 12
	panel.add_theme_stylebox_override("panel", style)
	_characters_container.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	panel.add_child(vbox)

	var name_lbl := Label.new()
	name_lbl.text = mc.get("name", "Unknown")
	name_lbl.add_theme_font_size_override("font_size", 18)
	name_lbl.add_theme_color_override("font_color", COLOR_TEXT)
	vbox.add_child(name_lbl)

	var bg_lbl := Label.new()
	bg_lbl.text = "%s | %s | %s" % [
		mc.get("origin", "?"), mc.get("basic_training", "?"), mc.get("service_history", "?")]
	bg_lbl.add_theme_color_override("font_color", COLOR_TEXT_SEC)
	bg_lbl.add_theme_font_size_override("font_size", 14)
	vbox.add_child(bg_lbl)

	var stats_text := "React: %d  Spd: %d  CS: %d  Tough: %d  Savvy: %d  XP: %d" % [
		mc.get("reactions", 0), mc.get("speed", 0), mc.get("combat_skill", 0),
		mc.get("toughness", 0), mc.get("savvy", 0), mc.get("xp", 0)]
	var stats_lbl := Label.new()
	stats_lbl.text = stats_text
	stats_lbl.add_theme_color_override("font_color", COLOR_TEXT)
	stats_lbl.add_theme_font_size_override("font_size", 14)
	vbox.add_child(stats_lbl)

	if mc.get("commendation_xp", 0) > 0 or mc.get("commendation_rep", 0) > 0:
		var comm_lbl := Label.new()
		comm_lbl.text = "Commendation: +%d XP, +%d Rep" % [mc.get("commendation_xp", 0), mc.get("commendation_rep", 0)]
		comm_lbl.add_theme_color_override("font_color", COLOR_SUCCESS)
		comm_lbl.add_theme_font_size_override("font_size", 12)
		vbox.add_child(comm_lbl)


func _emit_update() -> void:
	squad_updated.emit(_squad_data.duplicate(true))
