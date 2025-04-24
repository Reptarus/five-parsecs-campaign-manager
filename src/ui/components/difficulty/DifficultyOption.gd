@tool
extends Control
class_name DifficultyOption

## A reusable component for selecting game difficulty levels
## Provides standardized difficulty options with proper signal handling

const Self = preload("res://src/ui/components/difficulty/DifficultyOption.gd")
const GameEnums = preload("res://src/core/enums/GameEnums.gd")

## Emitted when the difficulty level is changed
signal value_changed(difficulty: GameEnums.DifficultyLevel)

## The option button used for difficulty selection
@onready var option_button: OptionButton = $OptionButton

## Current selected difficulty level
var current_difficulty: GameEnums.DifficultyLevel = GameEnums.DifficultyLevel.NORMAL
## Auto verification flag
var auto_verify: bool = true

## Initializes the component with default options and signals
func _ready() -> void:
	if Engine.is_editor_hint():
		return
		
	if not is_properly_initialized():
		push_error("DifficultyOption: Failed to initialize - OptionButton not found")
		return
	
	_setup_options()
	_connect_signals()

## Sets up the difficulty option with a specific difficulty and tooltip
## @param difficulty: The initial difficulty level to set
## @param tooltip_text: The tooltip text to display on hover
func setup(difficulty: GameEnums.DifficultyLevel, tooltip_text: String) -> void:
	current_difficulty = difficulty
	if is_properly_initialized():
		option_button.selected = difficulty
		option_button.tooltip_text = tooltip_text

## Sets up the available difficulty options
func _setup_options() -> void:
	if not is_properly_initialized():
		push_warning("DifficultyOption: option_button is null, cannot setup options")
		return
	
	option_button.clear()
	option_button.add_item("Easy", GameEnums.DifficultyLevel.EASY)
	option_button.add_item("Normal", GameEnums.DifficultyLevel.NORMAL)
	option_button.add_item("Hard", GameEnums.DifficultyLevel.HARD)
	option_button.add_item("Hardcore", GameEnums.DifficultyLevel.HARDCORE)
	option_button.add_item("Elite", GameEnums.DifficultyLevel.ELITE)
	
	# Set initial selection
	option_button.selected = current_difficulty

## Connects the necessary signals for this component
func _connect_signals() -> void:
	if not is_properly_initialized():
		push_warning("DifficultyOption: option_button is null, cannot connect signals")
		return
	
	if option_button.item_selected.is_connected(_on_option_selected):
		option_button.item_selected.disconnect(_on_option_selected)
	option_button.item_selected.connect(_on_option_selected)

## Returns the currently selected difficulty level
## @return: The current difficulty level enum value
func get_difficulty() -> GameEnums.DifficultyLevel:
	return current_difficulty

## Sets the difficulty level and updates the UI
## @param difficulty: The difficulty level to set
func set_difficulty(difficulty: GameEnums.DifficultyLevel) -> void:
	# Validate the difficulty is within valid range
	if difficulty < 0 or difficulty >= GameEnums.DifficultyLevel.size():
		push_warning("DifficultyOption: Invalid difficulty level: " + str(difficulty))
		return
		
	current_difficulty = difficulty
	if is_properly_initialized():
		option_button.selected = difficulty

## Handler for when a new option is selected
## @param index: The index of the selected option
func _on_option_selected(index: int) -> void:
	# Validate the index is a valid difficulty level
	if index < 0 or index >= GameEnums.DifficultyLevel.size():
		push_warning("DifficultyOption: Invalid option selected: " + str(index))
		return
		
	current_difficulty = index
	value_changed.emit(current_difficulty)

## Helper method to check if the component is properly initialized
## @return: True if the option_button is valid, false otherwise
func is_properly_initialized() -> bool:
	return option_button != null

## Gets verification rules associated with difficulty levels
## @return: Dictionary with verification rules for each difficulty
func get_verification_rules() -> Dictionary:
	return {
		GameEnums.DifficultyLevel.EASY: {
			"health_modifier": 1.2,
			"damage_modifier": 0.8,
			"loot_modifier": 1.2
		},
		GameEnums.DifficultyLevel.NORMAL: {
			"health_modifier": 1.0,
			"damage_modifier": 1.0,
			"loot_modifier": 1.0
		},
		GameEnums.DifficultyLevel.HARD: {
			"health_modifier": 0.8,
			"damage_modifier": 1.2,
			"loot_modifier": 0.8
		},
		GameEnums.DifficultyLevel.HARDCORE: {
			"health_modifier": 0.6,
			"damage_modifier": 1.5,
			"loot_modifier": 0.6
		},
		GameEnums.DifficultyLevel.ELITE: {
			"health_modifier": 0.5,
			"damage_modifier": 2.0,
			"loot_modifier": 0.5
		}
	}

## Gets the auto verification flag 
## @return: Whether auto verification is enabled
func get_auto_verify() -> bool:
	return auto_verify

## Sets the auto verification flag
## @param value: New auto verification status
func set_auto_verify(value: bool) -> void:
	auto_verify = value
