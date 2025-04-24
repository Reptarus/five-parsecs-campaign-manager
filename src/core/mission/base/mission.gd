@tool
extends "res://src/base/mission/mission_base.gd"
# This file should be referenced via preload
# Use explicit preloads instead of global class names

## Five Parsecs Mission Implementation
##
## Extends the base mission system with Five Parsecs specific functionality
## including resource multipliers, deployment points, and campaign-specific features.

# Define mission states as enum instead of dictionary
enum MissionState {
	AVAILABLE = 0,
	IN_PROGRESS = 1,
	COMPLETED = 2,
	FAILED = 3,
	EXPIRED = 4
}

# Five Parsecs specific properties
var resource_multiplier: float = 1.0
var reputation_multiplier: float = 1.0
var victory_condition: int = GameEnums.MissionVictoryType.OBJECTIVE
var deployment_points: Array[Vector2] = []
var objective_points: Array[Vector2] = []
var mission_events: Array[Dictionary] = []
var campaign_effects: Array[Dictionary] = []
var reward = null # Actual resource for reward
var current_state: int = MissionState.AVAILABLE

# Safe helpers
func _has_key(dict, key):
	if dict == null:
		return false
	if dict is Dictionary:
		return dict.has(key)
	return false

func _has_method(obj, method_name):
	if obj == null:
		return false
	if obj is Object:
		return obj.has_method(method_name)
	return false

func _in_array(arr, value):
	if arr == null:
		return false
	if arr is Array:
		return arr.has(value)
	return false

# Override methods to add Five Parsecs specific functionality
func _init() -> void:
	if _has_method(self, "super"):
		super._init()
	# Initialize required properties for tests
	if not get("mission_name"):
		set("mission_name", "")
	if not get("description"):
		set("description", "")
	if not get("difficulty"):
		set("difficulty", 1)
	if not get("rewards"):
		set("rewards", {})
	if not get("is_completed"):
		set("is_completed", false)
	if not get("is_failed"):
		set("is_failed", false)
	if not get("mission_type"):
		set("mission_type", 0)

## Complete the mission with optional success parameter
func complete(success: bool = true) -> bool:
	if success:
		# Update completion status
		is_completed = true # Set the property directly
		current_state = MissionState.COMPLETED
		emit_signal("mission_completed") # Use emit_signal instead of .emit()
	else:
		is_failed = true
		current_state = MissionState.FAILED
		emit_signal("mission_failed")
	return success

## Override calculate_final_rewards to apply Five Parsecs multipliers
func calculate_final_rewards() -> Dictionary:
	# Only provide rewards for completed missions
	if current_state != MissionState.COMPLETED:
		return {}
	
	var final_rewards := rewards.duplicate()
	if _has_key(final_rewards, "credits"):
		final_rewards["credits"] = roundi(final_rewards["credits"] * resource_multiplier)
	if _has_key(final_rewards, "reputation"):
		final_rewards["reputation"] = roundi(final_rewards["reputation"] * reputation_multiplier)
	
	return final_rewards

## Generate deployment points for the mission
func generate_deployment_points(map_size: Vector2) -> void:
	# Implementation will be added in a separate PR
	pass

## Generate objective points for the mission
func generate_objective_points(map_size: Vector2) -> void:
	# Implementation will be added in a separate PR
	pass

## Check for mission events based on current state
func check_mission_events() -> Array[Dictionary]:
	# Implementation will be added in a separate PR
	return []

## Apply campaign effects to the mission
func apply_campaign_effects(effects: Array[Dictionary]) -> void:
	campaign_effects.append_array(effects)
	# Additional implementation will be added in a separate PR

# Test compatibility methods
func get_name() -> String:
	return mission_name
	
func set_name(value: String) -> void:
	mission_name = value
	
func get_description() -> String:
	return description
	
func set_description(value: String) -> void:
	description = value
	
func get_difficulty() -> int:
	return difficulty
	
func set_difficulty(value: int) -> void:
	difficulty = value
	
# Method to check completion status - renamed to avoid conflict
func check_completion() -> bool:
	return current_state == MissionState.COMPLETED
	
func set_completed(value: bool) -> void:
	is_completed = value # Set the property directly
	if value:
		current_state = MissionState.COMPLETED
	else:
		# If unsetting completion, revert to in progress
		current_state = MissionState.IN_PROGRESS
		
func get_mission_type() -> int:
	return mission_type
	
func set_mission_type(value: int) -> void:
	mission_type = value
	
func get_reward():
	return reward
	
func set_reward(value) -> void:
	reward = value
	if value and _has_method(value, "to_dict"):
		rewards = value.to_dict()
		
func get_state() -> int:
	return current_state
	
func set_state(value: int) -> void:
	current_state = value
	
func transition_to(new_state: int) -> bool:
	var valid_transitions = {
		MissionState.AVAILABLE: [MissionState.IN_PROGRESS, MissionState.EXPIRED],
		MissionState.IN_PROGRESS: [MissionState.COMPLETED, MissionState.FAILED],
		MissionState.COMPLETED: [],
		MissionState.FAILED: [],
		MissionState.EXPIRED: []
	}
	
	if not _has_key(valid_transitions, current_state) or not _in_array(valid_transitions[current_state], new_state):
		return false
		
	current_state = new_state
	emit_signal("mission_state_changed", current_state)
	return true
	
# Difficulty scaling methods
func apply_difficulty_scaling_to_reward() -> void:
	if reward and _has_method(reward, "apply_difficulty_scaling"):
		reward.apply_difficulty_scaling(difficulty)
