class_name GameState
extends Node

const GlobalEnums = preload("res://Resources/GameData/GlobalEnums.gd")

var campaign_turn: int = 0
var credits: int = 0
var reputation: int = 0
var completed_missions: Array = []
var victory_condition: Dictionary = {
	"type": GlobalEnums.VictoryConditionType.TURNS,
	"value": 10
}

func check_victory_condition() -> bool:
	match victory_condition.type:
		GlobalEnums.VictoryConditionType.TURNS:
			return campaign_turn >= victory_condition.value
		GlobalEnums.VictoryConditionType.QUESTS:
			return completed_missions.size() >= victory_condition.value
		GlobalEnums.VictoryConditionType.SURVIVAL:
			return campaign_turn >= victory_condition.value
		_:
			return false

func set_victory_condition(type: GlobalEnums.VictoryConditionType, value: int) -> void:
	victory_condition = {
		"type": type,
		"value": value
	}

func get_victory_progress() -> float:
	match victory_condition.type:
		GlobalEnums.VictoryConditionType.TURNS:
			return float(campaign_turn) / float(victory_condition.value)
		GlobalEnums.VictoryConditionType.QUESTS:
			return float(completed_missions.size()) / float(victory_condition.value)
		GlobalEnums.VictoryConditionType.SURVIVAL:
			return float(campaign_turn) / float(victory_condition.value)
		_:
			return 0.0

func get_victory_description() -> String:
	match victory_condition.type:
		GlobalEnums.VictoryConditionType.TURNS:
			return "Survive %d campaign turns (%d/%d)" % [victory_condition.value, campaign_turn, victory_condition.value]
		GlobalEnums.VictoryConditionType.QUESTS:
			return "Complete %d quests (%d/%d)" % [victory_condition.value, completed_missions.size(), victory_condition.value]
		GlobalEnums.VictoryConditionType.SURVIVAL:
			return "Survive for %d turns (%d/%d)" % [victory_condition.value, campaign_turn, victory_condition.value]
		_:
			return "No victory condition set"
