@tool
extends Control
class_name CharacterCreator

## Character creation system for Five Parsecs campaign
## Handles character generation, customization, and validation

const GameEnums = preload("res://src/core/systems/GlobalEnums.gd")
const Character = preload("res://src/core/character/Base/Character.gd")

signal character_created(character: Character)
signal creation_cancelled()
signal validation_failed(errors: Array[String])

enum CreatorMode {
	STANDARD,
	CAPTAIN,
	CREW_MEMBER,
	QUICK_GENERATION
}

var current_mode: CreatorMode = CreatorMode.STANDARD
var current_character: Character
var is_visible: bool = false

# UI Components (to be connected in _ready)
var name_field: LineEdit
var class_option: OptionButton
var background_option: OptionButton
var stat_controls: Dictionary = {}

func _init() -> void:
	current_character = Character.new()

func _ready() -> void:
	_setup_ui_components()
	_connect_signals()

func _setup_ui_components() -> void:
	# This would normally set up UI components
	# For now, creating basic references
	pass

func _connect_signals() -> void:
	# Connect UI signals when components are available
	pass

func start_creation(mode: CreatorMode = CreatorMode.STANDARD) -> void:
	current_mode = mode
	current_character = Character.new()
	_apply_mode_defaults()
	show_creator()

func _apply_mode_defaults() -> void:
	match current_mode:
		CreatorMode.CAPTAIN:
			current_character.character_name = "Captain"
			# Apply captain-specific defaults
		CreatorMode.CREW_MEMBER:
			current_character.character_name = "Crew Member"
			# Apply crew member defaults
		CreatorMode.QUICK_GENERATION:
			_generate_random_character()

func _generate_random_character() -> void:
	# Generate random character attributes
	current_character.character_name = _generate_random_name()
	current_character.character_class = _get_random_class_index()
	_randomize_stats()

func _generate_random_name() -> String:
	var names = ["Alex", "Jordan", "Morgan", "Casey", "Riley", "Sam", "Avery", "Quinn"]
	return names[randi() % names.size()]

func _get_random_class_index() -> int:
	# Return a random class index instead of string
	return randi() % 6 # Assuming 6 different classes

func _randomize_stats() -> void:
	# Randomize character stats within reasonable bounds
	for i in range(6):
		var stat_value = randi() % 6 + 1
		current_character.set_stat(i, stat_value)

func validate_character() -> Dictionary:
	var errors: Array[String] = []
	var warnings: Array[String] = []
	
	# Validate name
	if current_character.character_name.strip_edges().is_empty():
		errors.append("Character name cannot be empty")
	
	# Validate class (check if it's a valid index)
	if current_character.character_class < 0:
		errors.append("Character class must be selected")
	
	# Validate stats (assuming we have some constraints)
	var total_stats = 0
	for i in range(6):
		total_stats += current_character.get_stat(i)
	
	if total_stats < 6:
		errors.append("Character stats are too low")
	elif total_stats > 30:
		warnings.append("Character stats are very high")
	
	return {
		"is_valid": errors.is_empty(),
		"errors": errors,
		"warnings": warnings
	}

func finalize_character() -> bool:
	var validation = validate_character()
	
	if not validation.is_valid:
		validation_failed.emit(validation.errors)
		return false
	
	character_created.emit(current_character)
	hide_creator()
	return true

func cancel_creation() -> void:
	creation_cancelled.emit()
	hide_creator()

func show_creator() -> void:
	is_visible = true
	visible = true

func hide_creator() -> void:
	is_visible = false
	visible = false

func get_current_character() -> Character:
	return current_character

func set_character_name(name: String) -> void:
	if current_character:
		current_character.character_name = name

func set_character_class(char_class_index: int) -> void:
	if current_character:
		current_character.character_class = char_class_index

func set_character_background(background: int) -> void:
	if current_character:
		current_character.background = background

func randomize_character() -> void:
	_generate_random_character()

# Callback methods for UI interactions
func _on_randomize_pressed() -> void:
	randomize_character()

func _on_create_pressed() -> void:
	finalize_character()

func _on_cancel_pressed() -> void:
	cancel_creation()

func _on_name_changed(new_name: String) -> void:
	set_character_name(new_name)

func _on_class_selected(index: int) -> void:
	if index >= 0:
		set_character_class(index)

func _on_background_selected(index: int) -> void:
	if index >= 0:
		set_character_background(index) # Use the index directly
