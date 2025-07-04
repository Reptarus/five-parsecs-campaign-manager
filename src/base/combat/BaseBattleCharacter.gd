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
var _character_name: String:
	get: return ""
	set(_value): pass

var _health: int:
	get: return 0
	set(_value): pass

var _max_health: int:
	get: return 0
	set(_value): pass

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
func get_current_action() -> int:
	return current_action
func get_available_actions() -> Array:
	return available_actions
func get_is_active() -> bool:
	return is_active
func get_character_name() -> String:
	return _character_name
func get_health() -> int:
	return _health
func get_max_health() -> int:
	return _max_health
func get_is_defeated() -> bool:
	return _health <= 0
func get_is_wounded() -> bool:
	return _health <= _max_health / 3
func get_is_dead() -> bool:
	return _health <= 0
func get_is_alive() -> bool:
	return _health > 0
