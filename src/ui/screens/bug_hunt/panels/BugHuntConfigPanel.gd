extends Control

## Bug Hunt Config Panel — Step 1 of 4
## Campaign name, difficulty selection, regiment name generation.

signal config_updated(data: Dictionary)

# Deep space theme colors
const COLOR_BASE := Color("#1A1A2E")
const COLOR_ELEVATED := Color("#252542")
const COLOR_ACCENT := Color("#2D5A7B")
const COLOR_TEXT := Color("#E0E0E0")
const COLOR_TEXT_SEC := Color("#808080")
const COLOR_BORDER := Color("#3A3A5C")
const COLOR_INPUT := Color("#1E1E36")

var _coordinator = null
var _name_edit: LineEdit
var _regiment_label: Label
var _color_label: Label
var _difficulty_option: OptionButton
var _escalation_check: CheckButton

var _config_data: Dictionary = {
	"campaign_name": "",
	"regiment_name": "",
	"uniform_color": "",
	"difficulty": "mess_me_up",
	"use_campaign_escalation": false
}

const DIFFICULTIES := [
	{"id": "im_too_pretty_to_die", "name": "I'm Too Pretty to Die"},
	{"id": "hey_not_too_crazy", "name": "Hey, Not Too Crazy"},
	{"id": "mess_me_up", "name": "Mess Me Up"},
	{"id": "mega_violence", "name": "Mega-violence"},
	{"id": "living_nightmare", "name": "Living Nightmare"}
]


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

	# Title
	var title := Label.new()
	title.text = "BUG HUNT — CAMPAIGN SETUP"
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", COLOR_TEXT)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	# Campaign Name
	var name_card := _create_card("Campaign Name", vbox)
	_name_edit = LineEdit.new()
	_name_edit.placeholder_text = "Enter campaign name..."
	_name_edit.add_theme_color_override("font_color", COLOR_TEXT)
	_name_edit.custom_minimum_size.y = 48
	_name_edit.text_changed.connect(_on_name_changed)
	name_card.add_child(_name_edit)

	# Regiment Name
	var regiment_card := _create_card("Regiment", vbox)
	_regiment_label = Label.new()
	_regiment_label.text = "Not yet generated"
	_regiment_label.add_theme_color_override("font_color", COLOR_TEXT)
	_regiment_label.add_theme_font_size_override("font_size", 18)
	regiment_card.add_child(_regiment_label)

	_color_label = Label.new()
	_color_label.text = "Uniform: —"
	_color_label.add_theme_color_override("font_color", COLOR_TEXT_SEC)
	regiment_card.add_child(_color_label)

	var gen_btn := Button.new()
	gen_btn.text = "Generate Regiment Name"
	gen_btn.custom_minimum_size.y = 48
	gen_btn.pressed.connect(_on_generate_regiment)
	regiment_card.add_child(gen_btn)

	# Difficulty
	var diff_card := _create_card("Mission Difficulty", vbox)
	_difficulty_option = OptionButton.new()
	_difficulty_option.custom_minimum_size.y = 48
	for i in range(DIFFICULTIES.size()):
		_difficulty_option.add_item(DIFFICULTIES[i].name, i)
	_difficulty_option.selected = 2  # Default: "Mess Me Up"
	_difficulty_option.item_selected.connect(_on_difficulty_changed)
	diff_card.add_child(_difficulty_option)

	# Campaign Escalation
	_escalation_check = CheckButton.new()
	_escalation_check.text = "Use Campaign Escalation (fixed Priority sequence)"
	_escalation_check.add_theme_color_override("font_color", COLOR_TEXT)
	_escalation_check.toggled.connect(_on_escalation_toggled)
	diff_card.add_child(_escalation_check)


func _create_card(title_text: String, parent: Control) -> VBoxContainer:
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = COLOR_ELEVATED
	style.border_color = COLOR_BORDER
	style.border_width_bottom = 1
	style.border_width_top = 1
	style.border_width_left = 1
	style.border_width_right = 1
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
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


func _on_name_changed(new_name: String) -> void:
	_config_data.campaign_name = new_name
	_emit_update()


func _on_generate_regiment() -> void:
	if _coordinator and _coordinator.has_method("generate_regiment_name"):
		var result: Dictionary = _coordinator.generate_regiment_name()
		_config_data.regiment_name = result.get("full_name", "Unknown Regiment")
		_config_data.uniform_color = result.get("uniform_color", "")
		_regiment_label.text = _config_data.regiment_name
		_color_label.text = "Uniform: " + _config_data.uniform_color
		_emit_update()


func _on_difficulty_changed(index: int) -> void:
	if index >= 0 and index < DIFFICULTIES.size():
		_config_data.difficulty = DIFFICULTIES[index].id
		_emit_update()


func _on_escalation_toggled(pressed: bool) -> void:
	_config_data.use_campaign_escalation = pressed
	_emit_update()


func _emit_update() -> void:
	config_updated.emit(_config_data.duplicate())
