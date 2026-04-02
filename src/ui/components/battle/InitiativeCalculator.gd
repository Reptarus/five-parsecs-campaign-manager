class_name FPCM_InitiativeCalculator
extends PanelContainer

## Initiative Calculator Panel
##
## UI component for calculating Seize the Initiative rolls.
## Displays all modifiers, calculates probability, and shows results.
##
## Reference: Core Rules p.117 "Seizing the Initiative"

const SeizeInitiativeSystem = preload("res://src/core/battle/SeizeInitiativeSystem.gd")
const FiveParsecsCampaignPanel = preload("res://src/ui/screens/campaign/panels/BaseCampaignPanel.gd")

# Signals
signal initiative_calculated(result: SeizeInitiativeSystem.InitiativeResult)
signal roll_requested()

# UI References
@onready var title_label: Label = $VBox/TitleLabel
@onready var savvy_value: SpinBox = $VBox/SavvyRow/SavvyValue
@onready var probability_label: Label = $VBox/ProbabilityLabel
@onready var modifiers_container: VBoxContainer = $VBox/ModifiersContainer
@onready var roll_button: Button = $VBox/ButtonRow/RollButton
@onready var result_panel: PanelContainer = $VBox/ResultPanel
@onready var result_label: RichTextLabel = $VBox/ResultPanel/ResultLabel

# Modifier checkboxes
var outnumbered_check: CheckBox
var hired_muscle_check: CheckBox
var motion_tracker_check: CheckBox
var scanner_bot_check: CheckBox
var difficulty_option: OptionButton

# System
var initiative_system: SeizeInitiativeSystem
var last_result: SeizeInitiativeSystem.InitiativeResult

func _ready() -> void:
	initiative_system = SeizeInitiativeSystem.new()
	_setup_panel_style()
	_setup_modifiers_ui()
	_setup_buttons()
	_update_probability()

	if result_panel:
		result_panel.hide()

func _setup_panel_style() -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = FiveParsecsCampaignPanel.COLOR_ELEVATED # Design system: card backgrounds
	style.set_corner_radius_all(8)
	style.set_border_width_all(1)
	style.border_width_left = 3 # Accent border (initiative indicator)
	style.border_color = FiveParsecsCampaignPanel.COLOR_FOCUS # Design system: cyan focus color
	style.set_content_margin_all(FiveParsecsCampaignPanel.SPACING_MD) # Design system: 16px
	add_theme_stylebox_override("panel", style)

func _setup_modifiers_ui() -> void:
	if not modifiers_container:
		return

	# Clear existing
	for child in modifiers_container.get_children():
		child.queue_free()

	# Difficulty mode
	var diff_row := HBoxContainer.new()
	var diff_label := Label.new()
	diff_label.text = "Difficulty:"
	diff_label.custom_minimum_size.x = 120
	diff_row.add_child(diff_label)

	difficulty_option = OptionButton.new()
	difficulty_option.add_item("Normal", 0)
	difficulty_option.add_item("Challenging", 1)
	difficulty_option.add_item("Hardcore (-2)", 2)
	difficulty_option.add_item("Insanity (-3)", 3)
	difficulty_option.item_selected.connect(_on_difficulty_changed)
	diff_row.add_child(difficulty_option)
	modifiers_container.add_child(diff_row)

	# Outnumbered checkbox
	outnumbered_check = CheckBox.new()
	outnumbered_check.text = "Outnumbered (+1)"
	outnumbered_check.toggled.connect(_on_outnumbered_toggled)
	modifiers_container.add_child(outnumbered_check)

	# Hired Muscle checkbox
	hired_muscle_check = CheckBox.new()
	hired_muscle_check.text = "vs Hired Muscle (-1)"
	hired_muscle_check.toggled.connect(_on_hired_muscle_toggled)
	modifiers_container.add_child(hired_muscle_check)

	# Equipment section
	var equip_label := Label.new()
	equip_label.text = "Equipment:"
	equip_label.add_theme_color_override("font_color", UIColors.COLOR_TEXT_SECONDARY)
	modifiers_container.add_child(equip_label)

	# Motion Tracker
	motion_tracker_check = CheckBox.new()
	motion_tracker_check.text = "Motion Tracker (+1)"
	motion_tracker_check.toggled.connect(_on_motion_tracker_toggled)
	modifiers_container.add_child(motion_tracker_check)

	# Scanner Bot
	scanner_bot_check = CheckBox.new()
	scanner_bot_check.text = "Scanner Bot (+1)"
	scanner_bot_check.toggled.connect(_on_scanner_bot_toggled)
	modifiers_container.add_child(scanner_bot_check)

func _setup_buttons() -> void:
	if roll_button:
		roll_button.pressed.connect(_on_roll_pressed)

## Set crew data for automatic savvy detection
func set_crew(crew: Array) -> void:
	if not initiative_system:
		initiative_system = SeizeInitiativeSystem.new()
	initiative_system.set_crew_data(crew)

	# Update savvy display
	if savvy_value:
		savvy_value.value = initiative_system.highest_savvy

	# BUG-042 FIX: Auto-detect equipment modifiers from crew data
	_auto_detect_equipment(crew)

	_update_probability()

## BUG-042 FIX: Scan crew equipment for initiative-relevant items
func _auto_detect_equipment(crew: Array) -> void:
	var has_motion_tracker := false
	var has_scanner_bot := false
	for member in crew:
		var equip_list: Array = []
		if member is Dictionary:
			equip_list = member.get("equipment", [])
		elif "equipment" in member:
			var eq = member.equipment
			equip_list = eq if eq is Array else []
		for item in equip_list:
			var item_name: String = ""
			if item is Dictionary:
				item_name = item.get("name", "").to_lower()
			elif item is String:
				item_name = item.to_lower()
			if "motion tracker" in item_name:
				has_motion_tracker = true
			if "scanner bot" in item_name:
				has_scanner_bot = true
	if motion_tracker_check:
		motion_tracker_check.button_pressed = has_motion_tracker
		initiative_system.set_motion_tracker(has_motion_tracker)
	if scanner_bot_check:
		scanner_bot_check.button_pressed = has_scanner_bot
		initiative_system.set_scanner_bot(has_scanner_bot)

## Set highest savvy manually
func set_savvy(value: int) -> void:
	initiative_system.highest_savvy = value
	if savvy_value:
		savvy_value.value = value
	_update_probability()

## Set enemy modifier (for enemy types with initiative bonuses/penalties)
func set_enemy_modifier(value: int, enemy_name: String = "Enemy Type") -> void:
	initiative_system.set_enemy_modifier(value, enemy_name)
	_update_probability()

## Get last roll result
func get_last_result() -> SeizeInitiativeSystem.InitiativeResult:
	return last_result

func _on_difficulty_changed(index: int) -> void:
	var mode: SeizeInitiativeSystem.DifficultyMode
	match index:
		0: mode = SeizeInitiativeSystem.DifficultyMode.NORMAL
		1: mode = SeizeInitiativeSystem.DifficultyMode.CHALLENGING
		2: mode = SeizeInitiativeSystem.DifficultyMode.HARDCORE
		3: mode = SeizeInitiativeSystem.DifficultyMode.INSANITY
		_: mode = SeizeInitiativeSystem.DifficultyMode.NORMAL

	initiative_system.set_difficulty_mode(mode)
	_update_probability()

func _on_outnumbered_toggled(pressed: bool) -> void:
	initiative_system.set_outnumbered(pressed)
	_update_probability()

func _on_hired_muscle_toggled(pressed: bool) -> void:
	initiative_system.set_hired_muscle(pressed)
	_update_probability()

func _on_motion_tracker_toggled(pressed: bool) -> void:
	initiative_system.set_motion_tracker(pressed)
	_update_probability()

func _on_scanner_bot_toggled(pressed: bool) -> void:
	initiative_system.set_scanner_bot(pressed)
	_update_probability()

func _on_roll_pressed() -> void:
	# Update savvy from spinbox
	if savvy_value:
		initiative_system.highest_savvy = int(savvy_value.value)

	# Roll
	last_result = initiative_system.roll_initiative()
	_display_result(last_result)

	roll_requested.emit()
	initiative_calculated.emit(last_result)

func _update_probability() -> void:
	if not probability_label:
		return

	var prob: float = initiative_system.get_success_probability()
	var required: int = initiative_system.calculate_required_roll()

	probability_label.text = "Need %d+ on 2D6 (%.0f%% chance)" % [required, prob]

	# Color based on probability
	if prob >= 70:
		probability_label.modulate = UIColors.COLOR_EMERALD
	elif prob >= 40:
		probability_label.modulate = UIColors.COLOR_AMBER
	else:
		probability_label.modulate = UIColors.COLOR_AMBER

func _display_result(result: SeizeInitiativeSystem.InitiativeResult) -> void:
	if not result_panel or not result_label:
		return

	result_panel.show()

	# Build result text
	var text := ""

	# Dice roll
	text += "[center][font_size=24]"
	text += "🎲 %d + %d = %d" % [result.dice_values[0], result.dice_values[1], result.base_roll]
	text += "[/font_size][/center]\n\n"

	# Breakdown
	text += "Base Roll: %d\n" % result.base_roll
	text += "Savvy Bonus: +%d\n" % result.savvy_bonus

	if result.total_modifiers != 0:
		var sign_str := "+" if result.total_modifiers > 0 else ""
		text += "Modifiers: %s%d\n" % [sign_str, result.total_modifiers]

		# Show modifier breakdown
		for mod in result.modifiers_breakdown:
			var mod_sign := "+" if mod.value > 0 else ""
			var applied := "" if mod.applied else " [color=gray](ignored)[/color]"
			text += "  • %s: %s%d%s\n" % [mod.name, mod_sign, mod.value, applied]

	text += "\n[b]Total: %d vs %d[/b]\n\n" % [result.roll_total, result.target_number]

	# Result
	if result.success:
		text += "[center][color=lime][font_size=20]SUCCESS![/font_size][/color][/center]\n"
		text += "[color=gray]%s[/color]" % initiative_system.get_success_effects()
	else:
		text += "[center][color=red][font_size=20]FAILED[/font_size][/color][/center]\n"
		text += "[color=gray]Normal battle round sequence applies.[/color]"

	result_label.bbcode_enabled = true
	result_label.text = text

	# Style result panel based on outcome
	var result_style := StyleBoxFlat.new()
	if result.success:
		result_style.bg_color = Color(0.1, 0.3, 0.1, 0.9)
		result_style.border_color = UIColors.COLOR_EMERALD
	else:
		result_style.bg_color = Color(0.3, 0.1, 0.1, 0.9)
		result_style.border_color = UIColors.COLOR_RED

	result_style.corner_radius_top_left = 4
	result_style.corner_radius_top_right = 4
	result_style.corner_radius_bottom_left = 4
	result_style.corner_radius_bottom_right = 4
	result_style.border_width_left = 2
	result_style.border_width_right = 2
	result_style.border_width_top = 2
	result_style.border_width_bottom = 2
	result_style.content_margin_left = 8
	result_style.content_margin_right = 8
	result_style.content_margin_top = 8
	result_style.content_margin_bottom = 8
	result_panel.add_theme_stylebox_override("panel", result_style)

## Reset the calculator
func reset() -> void:
	last_result = null

	if result_panel:
		result_panel.hide()

	if outnumbered_check:
		outnumbered_check.button_pressed = false
	if hired_muscle_check:
		hired_muscle_check.button_pressed = false
	if motion_tracker_check:
		motion_tracker_check.button_pressed = false
	if scanner_bot_check:
		scanner_bot_check.button_pressed = false
	if difficulty_option:
		difficulty_option.selected = 0

	initiative_system = SeizeInitiativeSystem.new()
	_update_probability()
