class_name StreetFightPanel
extends PanelContainer
## Street Fight Panel - Code-only UI for street fight mission flow
##
## Displays round tracking, suspect identification, police timer, and roll buttons.
## Embedded in TacticalBattleUI when mission_type == "street_fight".
##
## Usage: var panel = StreetFightPanel.new(); panel.setup_mission(mission_data)

const StreetFightGenRef = preload("res://src/core/mission/StreetFightGenerator.gd")
const CompendiumStreetFightsRef = preload("res://src/data/compendium_street_fights.gd")

const COLOR_STREET := UIColors.COLOR_AMBER  # Urban combat amber
const COLOR_POLICE := UIColors.COLOR_DANGER  # Red - police arriving
const COLOR_TEXT := UIColors.COLOR_TEXT_PRIMARY
const COLOR_BG := UIColors.COLOR_ELEVATED
const COLOR_BORDER := UIColors.COLOR_BORDER
const COLOR_HEADER := UIColors.COLOR_ACCENT

signal round_advanced(round_num: int)
signal suspect_revealed
signal mission_completed

var _mission_data: Dictionary = {}
var _current_round: int = 0
var _police_timer: int = 0
var _suspects_identified: int = 0

var _header_label: Label
var _status_label: Label
var _round_label: Label
var _instruction_display: RichTextLabel
var _advance_button: Button
var _roll_buttons_container: VBoxContainer
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
	_header_label.text = "STREET FIGHT"
	_header_label.add_theme_font_size_override("font_size", 18)
	_header_label.add_theme_color_override("font_color", COLOR_STREET)
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
	_status_label.text = "Police: Inactive"
	_status_label.add_theme_font_size_override("font_size", 14)
	_status_label.add_theme_color_override("font_color", COLOR_TEXT)
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

	# Roll buttons section
	_roll_buttons_container = VBoxContainer.new()
	_roll_buttons_container.add_theme_constant_override("separation", 4)
	vbox.add_child(_roll_buttons_container)

	_build_roll_buttons()

	# Action button bar
	var btn_hbox := HBoxContainer.new()
	btn_hbox.add_theme_constant_override("separation", 8)
	vbox.add_child(btn_hbox)

	_advance_button = Button.new()
	_advance_button.text = "Next Round"
	_advance_button.custom_minimum_size = Vector2(0, 40)
	_advance_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_advance_button.pressed.connect(_on_advance_pressed)
	btn_hbox.add_child(_advance_button)

	_complete_button = Button.new()
	_complete_button.text = "Mission Complete"
	_complete_button.custom_minimum_size = Vector2(0, 40)
	_complete_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_complete_button.visible = false
	_complete_button.pressed.connect(_on_complete_pressed)
	btn_hbox.add_child(_complete_button)


func _build_roll_buttons() -> void:
	var label := Label.new()
	label.text = "Quick Rolls:"
	label.add_theme_font_size_override("font_size", 12)
	label.add_theme_color_override("font_color", UIColors.COLOR_TEXT_SECONDARY)
	_roll_buttons_container.add_child(label)

	var row1 := HBoxContainer.new()
	row1.add_theme_constant_override("separation", 4)
	_roll_buttons_container.add_child(row1)

	_add_roll_button(row1, "Identify Suspect", _on_roll_suspect_identity)
	_add_roll_button(row1, "Suspect Action", _on_roll_suspect_action)

	var row2 := HBoxContainer.new()
	row2.add_theme_constant_override("separation", 4)
	_roll_buttons_container.add_child(row2)

	_add_roll_button(row2, "City Marker", _on_roll_city_marker)
	_add_roll_button(row2, "Building Type", _on_roll_building_type)


func _add_roll_button(parent: HBoxContainer, text: String, callback: Callable) -> void:
	var btn := Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(0, 32)
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.pressed.connect(callback)
	parent.add_child(btn)


## ============================================================================
## PUBLIC API
## ============================================================================

func setup_mission(mission_data: Dictionary) -> void:
	_mission_data = mission_data
	_current_round = 0
	_police_timer = 0
	_suspects_identified = 0
	if is_inside_tree():
		_show_setup()


func _show_setup() -> void:
	var setup_text := StreetFightGenRef.generate_setup_instructions(_mission_data)
	_instruction_display.text = setup_text
	_round_label.text = "Round: Setup"
	_status_label.text = "Police: Inactive"
	_status_label.add_theme_color_override("font_color", COLOR_TEXT)
	_header_label.add_theme_color_override("font_color", COLOR_STREET)
	_advance_button.visible = true
	_complete_button.visible = false


func _on_advance_pressed() -> void:
	_current_round += 1
	_round_label.text = "Round: %d" % _current_round

	var round_text := StreetFightGenRef.generate_round_instructions(
		_current_round, _police_timer
	)
	_instruction_display.text = round_text

	# Update police status display
	if _police_timer > 0:
		var threshold := maxi(2, 6 - _police_timer)
		_status_label.text = "Police: Active (%d+ on D6)" % threshold
		_status_label.add_theme_color_override("font_color", COLOR_POLICE)
		_police_timer += 1
	else:
		_status_label.text = "Police: Inactive"

	_complete_button.visible = true
	round_advanced.emit(_current_round)


func _on_complete_pressed() -> void:
	_advance_button.visible = false
	_complete_button.visible = false
	_instruction_display.text = "[b]STREET FIGHT COMPLETE[/b]\n\nProceed to post-battle resolution."
	mission_completed.emit()


## ============================================================================
## ROLL BUTTON HANDLERS
## ============================================================================

func _on_roll_suspect_identity() -> void:
	var result: Dictionary = StreetFightGenRef.roll_suspect_identity()
	var text := _instruction_display.text
	text += "\n\n[color=#4FC3F7][b]SUSPECT IDENTIFIED:[/b] %s[/color]" % result.get("instruction", "Unknown")
	_instruction_display.text = text
	_suspects_identified += 1

	# Start police timer on first weapon fire (suspect identification may lead to combat)
	var suspect_id: String = result.get("id", "")
	if _police_timer == 0 and suspect_id in ["enemy", "ambush"]:
		_police_timer = 1
		_status_label.text = "Police: Active (5+ on D6)"
		_status_label.add_theme_color_override("font_color", COLOR_POLICE)

	suspect_revealed.emit()


func _on_roll_suspect_action() -> void:
	var result: Dictionary = CompendiumStreetFightsRef.roll_suspect_action()
	var text := _instruction_display.text
	if result.is_empty():
		text += "\n\n[color=#808080](Street Fights DLC not enabled)[/color]"
	else:
		text += "\n\n[color=#D97706][b]SUSPECT ACTION:[/b] %s[/color]" % result.get("instruction", "No action")
	_instruction_display.text = text


func _on_roll_city_marker() -> void:
	var action: Dictionary = CompendiumStreetFightsRef.roll_city_marker_action()
	var text := _instruction_display.text
	if action.is_empty():
		text += "\n\n[color=#808080](Street Fights DLC not enabled)[/color]"
	else:
		text += "\n\n[color=#10B981][b]CITY MARKER:[/b] %s[/color]" % action.get("instruction", "No effect")
	_instruction_display.text = text


func _on_roll_building_type() -> void:
	var result: Dictionary = CompendiumStreetFightsRef.roll_building_type()
	var text := _instruction_display.text
	if result.is_empty():
		text += "\n\n[color=#808080](Street Fights DLC not enabled)[/color]"
	else:
		text += "\n\n[color=#4FC3F7][b]BUILDING:[/b] %s[/color]" % result.get("instruction", "Unknown type")
	_instruction_display.text = text


func start_police_timer() -> void:
	## Call when first shot is fired to start police response countdown
	if _police_timer == 0:
		_police_timer = 1
		_status_label.text = "Police: Active (5+ on D6)"
		_status_label.add_theme_color_override("font_color", COLOR_POLICE)


func get_current_round() -> int:
	return _current_round


func get_police_timer() -> int:
	return _police_timer
