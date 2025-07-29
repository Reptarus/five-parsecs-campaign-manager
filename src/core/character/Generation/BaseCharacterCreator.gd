@tool
extends Control
class_name BaseCharacterCreator

## Character creation UI component for Five Parsecs campaign
## Now uses BaseCharacterCreationSystem for unified character creation logic
## Part of Phase 2B Character Creator Consolidation

const BaseCharacterCreationSystem = preload("res://src/base/character/BaseCharacterCreationSystem.gd")
# GlobalEnums available as autoload singleton
const Character = preload("res://src/core/character/Character.gd")

signal character_created(character: Character)
signal creation_cancelled()
signal validation_failed(errors: Array[String])

# Character creation system (handles all logic)
var creation_system: BaseCharacterCreationSystem = null
var is_visible: bool = false

# UI Components (to be connected in _ready)
var name_field: LineEdit
var class_option: OptionButton
var background_option: OptionButton
var stat_controls: Dictionary = {}

func _init() -> void:
	creation_system = BaseCharacterCreationSystem.new()
	_connect_creation_system_signals()

func _ready() -> void:
	_setup_ui_components()
	_connect_signals()

func _connect_creation_system_signals() -> void:
	"""Connect to creation system signals"""
	if creation_system:
		creation_system.character_created.connect(_on_system_character_created)
		creation_system.character_updated.connect(_on_system_character_updated)
		creation_system.creation_cancelled.connect(_on_system_creation_cancelled)
		creation_system.validation_failed.connect(_on_system_validation_failed)

func _setup_ui_components() -> void:
	# This would normally set up UI components
	# For now, creating basic references
	pass

func _connect_signals() -> void:
	# Connect UI signals when components are available
	pass

func start_creation(mode: BaseCharacterCreationSystem.CreationMode = BaseCharacterCreationSystem.CreationMode.STANDARD, existing_character: Character = null) -> Character:
	"""Start character creation using the creation system"""
	if creation_system:
		return creation_system.start_creation(mode, existing_character)
	return null

func generate_random_character() -> Character:
	"""Generate random character using creation system"""
	if creation_system:
		var character = creation_system.generate_random_character()
		show_creator()
		return character
	return null

func validate_character() -> Dictionary:
	"""Validate character using creation system"""
	if creation_system:
		return creation_system.validate_character()
	return {"is_valid": false, "errors": ["Creation system not available"], "warnings": []}

func finalize_character() -> bool:
	"""Finalize character creation using creation system"""
	if creation_system:
		var result = creation_system.finalize_character()
		if result.success:
			hide_creator()
		return result.success
	return false

func cancel_creation() -> void:
	"""Cancel character creation using creation system"""
	if creation_system:
		creation_system.cancel_creation()
	hide_creator()

func show_creator() -> void:
	is_visible = true
	visible = true

func hide_creator() -> void:
	is_visible = false
	visible = false

func get_current_character() -> Character:
	"""Get current character from creation system"""
	if creation_system:
		return creation_system.get_current_character()
	return null

func set_character_name(name: String) -> void:
	"""Set character name using creation system"""
	if creation_system:
		creation_system.set_character_name(name)

func set_character_class(char_class_index: int) -> void:
	"""Set character class using creation system"""
	if creation_system:
		creation_system.set_character_class(char_class_index)

func set_character_background(background: int) -> void:
	"""Set character background using creation system"""
	if creation_system:
		creation_system.set_character_background(background)

func set_character_origin(origin: int) -> void:
	"""Set character origin using creation system"""
	if creation_system:
		creation_system.set_character_origin(origin)

func set_character_motivation(motivation: int) -> void:
	"""Set character motivation using creation system"""
	if creation_system:
		creation_system.set_character_motivation(motivation)

func randomize_character() -> void:
	"""Randomize character using creation system"""
	generate_random_character()

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
		set_character_background(index)

func _on_origin_selected(index: int) -> void:
	if index >= 0:
		set_character_origin(index)

func _on_motivation_selected(index: int) -> void:
	if index >= 0:
		set_character_motivation(index)

## Creation system signal handlers
func _on_system_character_created(character: Character) -> void:
	"""Handle character created from creation system"""
	character_created.emit(character)

func _on_system_character_updated(character: Character) -> void:
	"""Handle character updated from creation system"""
	character_created.emit(character) # Use same signal for now

func _on_system_creation_cancelled() -> void:
	"""Handle creation cancelled from creation system"""
	creation_cancelled.emit()

func _on_system_validation_failed(errors: Array[String]) -> void:
	"""Handle validation failed from creation system"""
	validation_failed.emit(errors)

## Data access methods for UI components
func get_available_origins() -> Array[Dictionary]:
	"""Get available origins for UI population"""
	if creation_system:
		return creation_system.get_available_origins()
	return []

func get_available_backgrounds() -> Array[Dictionary]:
	"""Get available backgrounds for UI population"""
	if creation_system:
		return creation_system.get_available_backgrounds()
	return []

func get_available_classes() -> Array[Dictionary]:
	"""Get available classes for UI population"""
	if creation_system:
		return creation_system.get_available_classes()
	return []

func get_available_motivations() -> Array[Dictionary]:
	"""Get available motivations for UI population"""
	if creation_system:
		return creation_system.get_available_motivations()
	return []

## Public API compatibility methods
func is_editing_mode() -> bool:
	"""Check if in editing mode"""
	if creation_system:
		return creation_system.is_editing()
	return false

func get_creation_mode() -> BaseCharacterCreationSystem.CreationMode:
	"""Get current creation mode"""
	if creation_system:
		return creation_system.get_creation_mode()
	return BaseCharacterCreationSystem.CreationMode.STANDARD
