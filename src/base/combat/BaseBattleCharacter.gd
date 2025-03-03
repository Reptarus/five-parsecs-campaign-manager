@tool
extends Node2D
class_name BaseBattleCharacter

# This is an abstract base class for battle characters
# Game-specific implementations should extend this class

# Reference to the character data
# This should be overridden in derived classes with the appropriate type
var character_data: Resource

func _init(data = null) -> void:
	if data:
		character_data = data

func get_character_data() -> Resource:
	return character_data

# Delegate common properties to character_data
# These should be overridden in derived classes with appropriate getters/setters
var character_name: String:
	get: return ""
	set(value): pass

var health: int:
	get: return 0
	set(value): pass

var max_health: int:
	get: return 0
	set(value): pass

# Battle-specific properties
var is_active: bool = false
var current_action: int = 0 # Should use appropriate enum in derived classes
var available_actions: Array = []

# Virtual methods to be implemented by derived classes
func initialize_for_battle() -> void:
	is_active = true
	current_action = 0
	available_actions = []

func cleanup_battle() -> void:
	is_active = false
	current_action = 0
	available_actions.clear()

# Additional virtual methods that derived classes might implement
func can_perform_action(action_type: int) -> bool:
	return action_type in available_actions

func perform_action(action_type: int, target = null) -> void:
	pass # To be implemented by derived classes

func take_damage(amount: int) -> void:
	pass # To be implemented by derived classes

func heal(amount: int) -> void:
	pass # To be implemented by derived classes