class_name GameState
extends Node

const GameEnums = preload("res://Resources/Core/Systems/GlobalEnums.gd")

var campaign_turn: int = 0
var credits: int = 0
var reputation: int = 0
var completed_missions: Array = []
var victory_condition: Dictionary = {
	"type": GameEnums.VictoryConditionType.TURNS,
	"value": 10
}

func initialize(config: Dictionary = {}) -> void:
	campaign_turn = config.get("campaign_turn", 0)
	credits = config.get("starting_credits", 1000)
	reputation = config.get("starting_reputation", 0)
	completed_missions = config.get("completed_missions", [])
	
	# Set victory condition if provided
	if config.has("victory_condition"):
		victory_condition = config.victory_condition
	else:
		# Default victory condition
		victory_condition = {
			"type": GameEnums.VictoryConditionType.TURNS,
			"value": 10
		}

func check_victory_condition() -> bool:
	match victory_condition.type:
		GameEnums.VictoryConditionType.TURNS:
			return campaign_turn >= victory_condition.value
		GameEnums.VictoryConditionType.QUESTS:
			return completed_missions.size() >= victory_condition.value
		GameEnums.VictoryConditionType.SURVIVAL:
			return campaign_turn >= victory_condition.value
		GameEnums.VictoryConditionType.WEALTH_GOAL:
			return credits >= victory_condition.value
		GameEnums.VictoryConditionType.REPUTATION_GOAL:
			return reputation >= victory_condition.value
		GameEnums.VictoryConditionType.FACTION_DOMINANCE,\
		GameEnums.VictoryConditionType.STORY_COMPLETE:
			# These are handled by their respective systems
			return false
		_:
			return false

func set_victory_condition(type: int, value: int) -> void:
	victory_condition = {
		"type": type,
		"value": value
	}

func get_victory_progress() -> float:
	match victory_condition.type:
		GameEnums.VictoryConditionType.TURNS,\
		GameEnums.VictoryConditionType.SURVIVAL:
			return float(campaign_turn) / float(victory_condition.value)
		GameEnums.VictoryConditionType.QUESTS:
			return float(completed_missions.size()) / float(victory_condition.value)
		GameEnums.VictoryConditionType.WEALTH_GOAL:
			return float(credits) / float(victory_condition.value)
		GameEnums.VictoryConditionType.REPUTATION_GOAL:
			return float(reputation) / float(victory_condition.value)
		_:
			return 0.0

func get_victory_description() -> String:
	match victory_condition.type:
		GameEnums.VictoryConditionType.TURNS:
			return "Survive %d campaign turns (%d/%d)" % [victory_condition.value, campaign_turn, victory_condition.value]
		GameEnums.VictoryConditionType.QUESTS:
			return "Complete %d quests (%d/%d)" % [victory_condition.value, completed_missions.size(), victory_condition.value]
		GameEnums.VictoryConditionType.SURVIVAL:
			return "Survive for %d turns (%d/%d)" % [victory_condition.value, campaign_turn, victory_condition.value]
		GameEnums.VictoryConditionType.WEALTH_GOAL:
			return "Amass %d credits (%d/%d)" % [victory_condition.value, credits, victory_condition.value]
		GameEnums.VictoryConditionType.REPUTATION_GOAL:
			return "Gain %d reputation (%d/%d)" % [victory_condition.value, reputation, victory_condition.value]
		GameEnums.VictoryConditionType.FACTION_DOMINANCE:
			return "Achieve faction dominance"
		GameEnums.VictoryConditionType.STORY_COMPLETE:
			return "Complete the story campaign"
		_:
			return "No victory condition set"

func set_tutorial_mode(enabled: bool) -> void:
	# Configure game state for tutorial mode
	if enabled:
		credits = 2000  # More starting credits for tutorial
		victory_condition = {
			"type": GameEnums.VictoryConditionType.TURNS,
			"value": 5  # Shorter tutorial campaign
		}

func update_difficulty(mode: int) -> void:
	match mode:
		GameEnums.DifficultyMode.EASY:
			credits += 500
		GameEnums.DifficultyMode.HARD:
			credits -= 250

func add_character(character) -> void:
	# This will be handled by the campaign manager
	pass

func cleanup() -> void:
	# Reset all state variables
	campaign_turn = 0
	credits = 0
	reputation = 0
	completed_missions.clear()
	victory_condition = {
		"type": GameEnums.VictoryConditionType.TURNS,
		"value": 10
	}

func serialize() -> Dictionary:
	return {
		"campaign_turn": campaign_turn,
		"credits": credits,
		"reputation": reputation,
		"completed_missions": completed_missions,
		"victory_condition": victory_condition
	}

func deserialize(data: Dictionary) -> void:
	campaign_turn = data.get("campaign_turn", 0)
	credits = data.get("credits", 0)
	reputation = data.get("reputation", 0)
	completed_missions = data.get("completed_missions", [])
	victory_condition = data.get("victory_condition", {
		"type": GameEnums.VictoryConditionType.TURNS,
		"value": 10
	})
