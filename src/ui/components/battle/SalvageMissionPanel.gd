class_name SalvageMissionPanel
extends PanelContainer
## Salvage Mission Panel - Code-only UI for salvage job mission flow
##
## Displays tension track, contact resolution, POI investigation, and salvage collection.
## Embedded in TacticalBattleUI when mission_type == "salvage".
##
## Usage: var panel = SalvageMissionPanel.new(); panel.setup_mission(mission_data)

const SalvageGenRef = preload("res://src/core/mission/SalvageJobGenerator.gd")
const CompendiumSalvageRef = preload("res://src/data/compendium_salvage_jobs.gd")

const COLOR_SALVAGE := UIColors.COLOR_CYAN  # Exploration blue
const COLOR_HOSTILE := UIColors.COLOR_DANGER  # Red - hostiles
const COLOR_TENSION := UIColors.COLOR_WARNING  # Orange - tension rising
const COLOR_TEXT := UIColors.COLOR_TEXT_PRIMARY
const COLOR_BG := UIColors.COLOR_ELEVATED
const COLOR_BORDER := UIColors.COLOR_BORDER

signal round_advanced(round_num: int)
signal contact_revealed
signal mission_completed

var _mission_data: Dictionary = {}
var _current_round: int = 0
var _tension: int = 3
var _salvage_units: int = 0
var _contacts_spawned: int = 0
var _is_illegal: bool = false

var _header_label: Label
var _tension_label: Label
var _round_label: Label
var _salvage_label: Label
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
	_header_label.text = "SALVAGE JOB"
	_header_label.add_theme_font_size_override("font_size", 18)
	_header_label.add_theme_color_override("font_color", COLOR_SALVAGE)
	_header_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_header_label)

	# Status bar
	var status_hbox := HBoxContainer.new()
	status_hbox.add_theme_constant_override("separation", 12)
	vbox.add_child(status_hbox)

	_round_label = Label.new()
	_round_label.text = "Round: 0"
	_round_label.add_theme_font_size_override("font_size", 14)
	_round_label.add_theme_color_override("font_color", COLOR_TEXT)
	status_hbox.add_child(_round_label)

	_tension_label = Label.new()
	_tension_label.text = "Tension: 3/12"
	_tension_label.add_theme_font_size_override("font_size", 14)
	_tension_label.add_theme_color_override("font_color", COLOR_TENSION)
	status_hbox.add_child(_tension_label)

	_salvage_label = Label.new()
	_salvage_label.text = "Salvage: 0"
	_salvage_label.add_theme_font_size_override("font_size", 14)
	_salvage_label.add_theme_color_override("font_color", COLOR_SALVAGE)
	_salvage_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_salvage_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	status_hbox.add_child(_salvage_label)

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

	var salvage_btn := Button.new()
	salvage_btn.text = "+1 Salvage"
	salvage_btn.custom_minimum_size = Vector2(0, 40)
	salvage_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	salvage_btn.pressed.connect(_on_collect_salvage)
	btn_hbox.add_child(salvage_btn)

	_complete_button = Button.new()
	_complete_button.text = "Extract & Complete"
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

	_add_roll_button(row1, "Resolve Contact", _on_roll_contact)
	_add_roll_button(row1, "Roll Tension", _on_roll_tension)

	var row2 := HBoxContainer.new()
	row2.add_theme_constant_override("separation", 4)
	_roll_buttons_container.add_child(row2)

	_add_roll_button(row2, "Investigate POI", _on_roll_poi)
	_add_roll_button(row2, "Roll Hostiles", _on_roll_hostiles)


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
	_tension = mission_data.get("tension", 3)
	_salvage_units = 0
	_contacts_spawned = 0
	_is_illegal = mission_data.get("is_illegal", false)
	if is_inside_tree():
		_show_setup()


func _show_setup() -> void:
	var setup_text := SalvageGenRef.generate_setup_instructions(_mission_data)
	_instruction_display.text = setup_text
	_round_label.text = "Round: Setup"
	_update_tension_display()
	_update_salvage_display()
	_header_label.add_theme_color_override("font_color", COLOR_SALVAGE)
	_advance_button.visible = true
	_complete_button.visible = false


func _update_tension_display() -> void:
	_tension_label.text = "Tension: %d/12" % _tension
	if _tension >= 8:
		_tension_label.add_theme_color_override("font_color", COLOR_HOSTILE)
	elif _tension >= 5:
		_tension_label.add_theme_color_override("font_color", COLOR_TENSION)
	else:
		_tension_label.add_theme_color_override("font_color", COLOR_TEXT)


func _update_salvage_display() -> void:
	var credits := SalvageGenRef.get_salvage_credits(_salvage_units)
	_salvage_label.text = "Salvage: %d (%d cr)" % [_salvage_units, credits]


func _on_advance_pressed() -> void:
	_current_round += 1
	_round_label.text = "Round: %d" % _current_round

	var round_text := SalvageGenRef.generate_round_instructions(
		_current_round, _tension
	)
	_instruction_display.text = round_text

	_complete_button.visible = true
	round_advanced.emit(_current_round)


func _on_collect_salvage() -> void:
	_salvage_units += 1
	_update_salvage_display()
	var text := _instruction_display.text
	text += "\n\n[color=#4FC3F7][b]+1 SALVAGE[/b] collected. Total: %d units.[/color]" % _salvage_units
	_instruction_display.text = text


func _on_complete_pressed() -> void:
	_advance_button.visible = false
	_complete_button.visible = false
	_instruction_display.text = SalvageGenRef.generate_post_mission_text(
		_salvage_units, _is_illegal
	)
	mission_completed.emit()


## ============================================================================
## ROLL BUTTON HANDLERS
## ============================================================================

func _on_roll_contact() -> void:
	var result: Dictionary = SalvageGenRef.resolve_contact()
	var text := _instruction_display.text
	text += "\n\n[color=#D97706][b]CONTACT RESOLVED:[/b] %s[/color]" % result.get("instruction", "Unknown")

	# Handle tension changes from contact resolution
	if result.get("tension_change", 0) != 0:
		_tension = clampi(_tension + result.tension_change, 0, 12)
		_update_tension_display()

	_instruction_display.text = text
	_contacts_spawned += 1
	contact_revealed.emit()


func _on_roll_tension() -> void:
	var result: Dictionary = CompendiumSalvageRef.roll_tension(_tension)
	var text := _instruction_display.text
	if result.is_empty():
		text += "\n\n[color=#808080](Salvage Jobs DLC not enabled)[/color]"
	else:
		text += "\n\n[color=#D97706][b]TENSION CHECK:[/b] %s[/color]" % result.get("instruction", "No change")
		if result.get("new_tension", _tension) != _tension:
			_tension = clampi(result.new_tension, 0, 12)
			_update_tension_display()
	_instruction_display.text = text


func _on_roll_poi() -> void:
	var result: Dictionary = SalvageGenRef.roll_point_of_interest()
	var text := _instruction_display.text
	text += "\n\n[color=#10B981][b]POINT OF INTEREST:[/b] %s[/color]" % result.get("instruction", "Nothing found")
	_instruction_display.text = text


func _on_roll_hostiles() -> void:
	var result: Dictionary = SalvageGenRef.roll_hostile_type()
	var text := _instruction_display.text
	text += "\n\n[color=#DC2626][b]HOSTILES:[/b] %s[/color]" % result.get("instruction", "Unknown hostiles")
	_instruction_display.text = text


func get_current_round() -> int:
	return _current_round


func get_tension() -> int:
	return _tension


func get_salvage_units() -> int:
	return _salvage_units
