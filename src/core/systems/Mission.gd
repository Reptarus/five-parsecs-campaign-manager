@tool
extends Resource
class_name Mission

# GlobalEnums available as autoload singleton

signal mission_completed
signal mission_failed
signal mission_updated

@export var mission_id: String = ""
@export var mission_title: String = ""
@export var mission_description: String = ""
@export var mission_type: int = GlobalEnums.MissionType.NONE
@export var mission_difficulty: int = 1
@export var reward_credits: int = 100
@export var is_completed: bool = false
@export var is_failed: bool = false
@export var turn_offered: int = 0

# Game-specific properties
var _custom_mission_events: Array[Dictionary] = []
var advanced_rules: Dictionary = {}

func _init() -> void:
	pass

func complete(success: bool = true) -> void:
	is_completed = success
	if success:
		mission_completed.emit() # warning: return value discarded (intentional)

func fail(emit_signal: bool = true) -> void:
	is_failed = true
	if emit_signal:
		mission_failed.emit() # warning: return value discarded (intentional)

func serialize() -> Dictionary:
	return {
		"mission_id": mission_id,
		"mission_title": mission_title,
		"mission_description": mission_description,
		"mission_type": mission_type,
		"mission_difficulty": mission_difficulty,
		"reward_credits": reward_credits,
		"is_completed": is_completed,
		"is_failed": is_failed,
		"turn_offered": turn_offered
	}

func deserialize(data: Dictionary) -> Mission:
	mission_id = data.get("mission_id", "")
	mission_title = data.get("mission_title", "")
	mission_description = data.get("mission_description", "")
	mission_type = data.get("mission_type", GlobalEnums.MissionType.NONE)
	mission_difficulty = data.get("mission_difficulty", 1)
	reward_credits = data.get("reward_credits", 100)
	is_completed = data.get("is_completed", false)
	is_failed = data.get("is_failed", false)
	turn_offered = data.get("turn_offered", 0)
	return self

## Game-specific method to handle custom mission events

func process_custom_mission_events() -> void:
	# Implementation will be added in a separate PR
	pass

## Override calculate_final_rewards to add game-specific bonuses

func calculate_final_rewards() -> Dictionary:
	var final_rewards = {}

	# Add game-specific reward calculations
	if final_rewards.has("credits") and advanced_rules.has("bonus_credits"):
		final_rewards["credits"] += advanced_rules.bonus_credits

	return final_rewards

## Safe property access helper - eliminates UNSAFE_METHOD_ACCESS warnings
## Based on Godot 4.4 best practices for safe property access
func safe_get_property(obj: Variant, property: String, default_value: Variant = null) -> Variant:
	if obj == null:
		return default_value
	if obj is Object and obj.has_method("get"):
		var value: Variant = obj.get(property)
		return value if value != null else default_value
	elif obj is Dictionary:
		return obj.get(property, default_value)
	return default_value
## Safe method call helper - eliminates UNSAFE_METHOD_ACCESS warnings
func safe_call_method(obj: Variant, method_name: String, args: Array = []) -> Variant:
	if obj == null:
		return null
	if obj is Object and obj.has_method(method_name):
		return obj.callv(method_name, args)
	return null
