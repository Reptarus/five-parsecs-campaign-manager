class_name StealthMissionPanel
extends PanelContainer
## Stealth Mission Panel - Code-only UI for stealth mission flow
##
## Displays stealth round tracking, spotting check inputs, and detection status.
## Embedded in BattlePhasePanel when mission_type == STEALTH.
##
## Usage: var panel = StealthMissionPanel.new(); panel.setup_mission(mission_data)

const StealthGenRef = preload("res://src/core/mission/StealthMissionGenerator.gd")

const COLOR_STEALTH := UIColors.COLOR_EMERALD  # Green - undetected
const COLOR_DETECTED := UIColors.COLOR_DANGER   # Red - detected
const COLOR_TEXT := UIColors.COLOR_TEXT_PRIMARY
const COLOR_BG := UIColors.COLOR_ELEVATED
const COLOR_BORDER := UIColors.COLOR_BORDER
const COLOR_HEADER := UIColors.COLOR_ACCENT

signal detection_triggered
signal mission_completed
signal round_advanced(round_num: int)

var _mission_data: Dictionary = {}
var _current_round: int = 0
var _is_detected: bool = false

var _header_label: Label
var _status_label: Label
var _round_label: Label
var _instruction_display: RichTextLabel
var _advance_button: Button
var _detect_button: Button
var _complete_button: Button


func _ready() -> void:
	_setup_style()
	_build_ui()


func _setup_style() -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = COLOR_BG
	style.set_corner_radius_all(8)
	style.set_border_width_all(1)
	style.border_color = COLOR_BORDER
	style.set_content_margin_all(12)
	add_theme_stylebox_override("panel", style)
	custom_minimum_size = Vector2(400, 300)


func _build_ui() -> void:
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	add_child(vbox)

	# Header
	_header_label = Label.new()
	_header_label.text = "STEALTH MISSION"
	_header_label.add_theme_font_size_override("font_size", 18)
	_header_label.add_theme_color_override("font_color", COLOR_STEALTH)
	_header_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_header_label)

	# Status bar
	var status_hbox := HBoxContainer.new()
	status_hbox.add_theme_constant_override("separation", 16)
	vbox.add_child(status_hbox)

	_round_label = Label.new()
	_round_label.text = "Round: 0"
	_round_label.add_theme_font_size_override("font_size", 14)
	_round_label.add_theme_color_override("font_color", COLOR_TEXT)
	status_hbox.add_child(_round_label)

	_status_label = Label.new()
	_status_label.text = "Status: HIDDEN"
	_status_label.add_theme_font_size_override("font_size", 14)
	_status_label.add_theme_color_override("font_color", COLOR_STEALTH)
	_status_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	status_hbox.add_child(_status_label)

	# Separator
	var sep := HSeparator.new()
	vbox.add_child(sep)

	# Instruction display
	_instruction_display = RichTextLabel.new()
	_instruction_display.bbcode_enabled = true
	_instruction_display.fit_content = true
	_instruction_display.custom_minimum_size = Vector2(0, 200)
	_instruction_display.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_instruction_display.add_theme_font_size_override("normal_font_size", 13)
	_instruction_display.add_theme_color_override("default_color", COLOR_TEXT)
	vbox.add_child(_instruction_display)

	# Button bar
	var btn_hbox := HBoxContainer.new()
	btn_hbox.add_theme_constant_override("separation", 8)
	vbox.add_child(btn_hbox)

	_advance_button = Button.new()
	_advance_button.text = "Next Stealth Round"
	_advance_button.custom_minimum_size = Vector2(0, 40)
	_advance_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_advance_button.pressed.connect(_on_advance_pressed)
	btn_hbox.add_child(_advance_button)

	_detect_button = Button.new()
	_detect_button.text = "DETECTED!"
	_detect_button.custom_minimum_size = Vector2(0, 40)
	_detect_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_detect_button.pressed.connect(_on_detect_pressed)
	btn_hbox.add_child(_detect_button)

	_complete_button = Button.new()
	_complete_button.text = "Mission Complete"
	_complete_button.custom_minimum_size = Vector2(0, 40)
	_complete_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_complete_button.visible = false
	_complete_button.pressed.connect(_on_complete_pressed)
	btn_hbox.add_child(_complete_button)


## ============================================================================
## PUBLIC API
## ============================================================================

func setup_mission(mission_data: Dictionary) -> void:
	_mission_data = mission_data
	_current_round = 0
	_is_detected = false
	if is_inside_tree():
		_show_setup()


func _show_setup() -> void:
	var setup_text := StealthGenRef.generate_setup_instructions(_mission_data)
	_instruction_display.text = setup_text
	_round_label.text = "Round: Setup"
	_status_label.text = "Status: HIDDEN"
	_status_label.add_theme_color_override("font_color", COLOR_STEALTH)
	_header_label.add_theme_color_override("font_color", COLOR_STEALTH)
	_advance_button.visible = true
	_detect_button.visible = true
	_complete_button.visible = false


func _on_advance_pressed() -> void:
	_current_round += 1
	_round_label.text = "Round: %d" % _current_round
	var round_text := StealthGenRef.generate_stealth_round_instructions(
		_current_round, _mission_data
	)
	_instruction_display.text = round_text
	round_advanced.emit(_current_round)


func _on_detect_pressed() -> void:
	_is_detected = true
	_status_label.text = "Status: DETECTED!"
	_status_label.add_theme_color_override("font_color", COLOR_DETECTED)
	_header_label.text = "STEALTH MISSION - COMBAT"
	_header_label.add_theme_color_override("font_color", COLOR_DETECTED)
	_instruction_display.text = StealthGenRef.generate_detection_result()
	_advance_button.visible = false
	_detect_button.visible = false
	_complete_button.visible = true
	detection_triggered.emit()


func _on_complete_pressed() -> void:
	_instruction_display.text = StealthGenRef.generate_extraction_text(_mission_data)
	_advance_button.visible = false
	_detect_button.visible = false
	_complete_button.visible = false
	mission_completed.emit()


func is_detected() -> bool:
	return _is_detected


func get_current_round() -> int:
	return _current_round
