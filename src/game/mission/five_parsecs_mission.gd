@tool
extends "res://src/base/mission/mission_base.gd"

## Five Parsecs Mission Implementation
##
## Extends the base mission system with Five Parsecs specific functionality
## including resource multipliers, deployment points, and campaign-specific features.

const GameEnums = preload("res://src/core/systems/GlobalEnums.gd")

# Five Parsecs specific properties
var resource_multiplier: float = 1.0
var reputation_multiplier: float = 1.0
var victory_condition: int = GameEnums.MissionVictoryType.OBJECTIVE
var deployment_points: Array[Vector2] = []
var objective_points: Array[Vector2] = []
var mission_events: Array[Dictionary] = []
var campaign_effects: Array[Dictionary] = []

# Override methods to add Five Parsecs specific functionality
func _init() -> void:
	super._init()

## Override calculate_final_rewards to apply Five Parsecs multipliers
func calculate_final_rewards() -> Dictionary:
	if not is_completed:
		return {}
	
	var final_rewards := rewards.duplicate()
	if final_rewards.has("credits"):
		final_rewards["credits"] = roundi(final_rewards["credits"] * resource_multiplier)
	if final_rewards.has("reputation"):
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
