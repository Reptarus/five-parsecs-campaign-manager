@tool
extends "res://src/core/mission/base/mission.gd"
class_name GameFiveParsecsMission

## Game-specific Five Parsecs Mission Implementation
##
## Extends the core Five Parsecs mission with game-specific
## functionality and overrides.

# Game-specific properties
var custom_mission_events: Array[Dictionary] = []
var advanced_rules: Dictionary = {}

func _init() -> void:
	super._init()

## Game-specific method to handle custom mission events
func process_custom_mission_events() -> void:
	# Implementation will be added in a separate PR
	pass

## Override calculate_final_rewards to add game-specific bonuses
func calculate_final_rewards() -> Dictionary:
	var final_rewards = super.calculate_final_rewards()
	
	# Add game-specific reward calculations
	if final_rewards.has("credits") and advanced_rules.has("bonus_credits"):
		final_rewards["credits"] += advanced_rules.bonus_credits
	
	return final_rewards
