extends Control

## Bug Hunt Config Panel — Step 1 of 4
## Campaign name, difficulty selection, regiment name generation.

signal config_updated(data: Dictionary)

# Deep space theme tokens (via UIColors canonical source)
const _UC = preload("res://src/ui/components/base/UIColors.gd")
const COLOR_BASE := _UC.COLOR_BASE
const COLOR_ELEVATED := _UC.COLOR_ELEVATED
const COLOR_ACCENT := _UC.COLOR_ACCENT
const COLOR_TEXT := _UC.COLOR_TEXT_PRIMARY
const COLOR_TEXT_SEC := _UC.COLOR_TEXT_SECONDARY
const COLOR_BORDER := _UC.COLOR_BORDER
const COLOR_INPUT := _UC.COLOR_INPUT
const COLOR_DANGER := _UC.COLOR_DANGER
const SPACING_MD := _UC.SPACING_MD
const SPACING_LG := _UC.SPACING_LG
const TOUCH_TARGET_COMFORT := _UC.TOUCH_TARGET_COMFORT

var _coordinator = null
var _name_edit: LineEdit
var _validation_label: Label
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


func _scaled_font(base: int) -> int:
	var rm := get_node_or_null("/root/ResponsiveManager")
	if rm and rm.has_method("get_responsive_font_size"):
		return rm.get_responsive_font_size(base)
	return base


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
	title.add_theme_font_size_override("font_size", _scaled_font(24))
	title.add_theme_color_override("font_color", COLOR_TEXT)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	# ISSUE-053: Flavor text to fill sparse layout
	var flavor := Label.new()
	flavor.text = "Military deployment in hostile territory. " \
		+ "Your squad faces waves of alien threats with limited support."
	flavor.add_theme_font_size_override("font_size", _scaled_font(14))
	flavor.add_theme_color_override("font_color", COLOR_TEXT_SEC)
	flavor.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	flavor.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(flavor)

	# Campaign Name
	var name_card := _create_card("Campaign Name", vbox)
	_name_edit = LineEdit.new()
	_name_edit.placeholder_text = "Tap here to name your campaign..."
	_name_edit.add_theme_color_override("font_color", COLOR_TEXT)
	_name_edit.add_theme_color_override("font_placeholder_color", Color(COLOR_TEXT_SEC, 0.5))
	var input_style := StyleBoxFlat.new()
	input_style.bg_color = COLOR_INPUT
	input_style.border_color = COLOR_BORDER
	input_style.set_border_width_all(1)
	input_style.set_corner_radius_all(8)
	input_style.set_content_margin_all(12)
	_name_edit.add_theme_stylebox_override("normal", input_style)
	var focus_style := input_style.duplicate()
	focus_style.border_color = _UC.COLOR_FOCUS
	_name_edit.add_theme_stylebox_override("focus", focus_style)
	_name_edit.custom_minimum_size.y = TOUCH_TARGET_COMFORT
	_name_edit.text_changed.connect(_on_name_changed)
	name_card.add_child(_name_edit)

	_validation_label = Label.new()
	_validation_label.text = ""
	_validation_label.add_theme_color_override("font_color", COLOR_DANGER)
	_validation_label.add_theme_font_size_override("font_size", _scaled_font(12))
	_validation_label.visible = false
	name_card.add_child(_validation_label)

	# Regiment Name
	var regiment_card := _create_card("Regiment", vbox)
	_regiment_label = Label.new()
	_regiment_label.text = "Not yet generated"
	_regiment_label.add_theme_color_override("font_color", COLOR_TEXT)
	_regiment_label.add_theme_font_size_override("font_size", _scaled_font(18))
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
	_escalation_check.custom_minimum_size.y = 48  # ISSUE-046: TOUCH_TARGET_MIN
	_escalation_check.add_theme_color_override("font_color", COLOR_TEXT)
	_escalation_check.toggled.connect(_on_escalation_toggled)
	diff_card.add_child(_escalation_check)


func _create_card(title_text: String, parent: Control) -> VBoxContainer:
	## Glass morphism card matching CampaignScreenBase pattern.
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(COLOR_ELEVATED.r, COLOR_ELEVATED.g, COLOR_ELEVATED.b, 0.8)
	style.border_color = Color(COLOR_BORDER.r, COLOR_BORDER.g, COLOR_BORDER.b, 0.5)
	style.set_border_width_all(1)
	style.set_corner_radius_all(16)
	style.set_content_margin_all(SPACING_LG)
	panel.add_theme_stylebox_override("panel", style)
	parent.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", _UC.SPACING_SM)
	panel.add_child(vbox)

	var lbl := Label.new()
	lbl.text = title_text.to_upper()
	lbl.add_theme_font_size_override("font_size", _scaled_font(16))
	lbl.add_theme_color_override("font_color", COLOR_TEXT_SEC)
	vbox.add_child(lbl)

	var sep := HSeparator.new()
	sep.modulate = COLOR_BORDER
	vbox.add_child(sep)

	return vbox


func _on_name_changed(new_name: String) -> void:
	_config_data.campaign_name = new_name
	if new_name.strip_edges().is_empty():
		_validation_label.text = "Campaign name is required"
		_validation_label.visible = true
	else:
		_validation_label.visible = false
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
