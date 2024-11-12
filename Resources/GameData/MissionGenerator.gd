# Scripts/Missions/MissionGenerator.gd
class_name MissionGenerator
extends Node

@onready var game_manager = get_node("/root/GameManager")

var game_state: GameState

func _init(_game_state: GameState) -> void:
	game_state = _game_state

func generate_mission() -> Mission:
	var mission = Mission.new()
	mission.type = GlobalEnums.Type.OPPORTUNITY
	mission.objective = _generate_random_objective()
	mission.difficulty = randi() % 3 + 1
	mission.time_limit = randi() % 3 + 2
	mission.location = game_state.current_location
	mission.rewards = _generate_rewards(mission.difficulty)
	mission.deployment_type = GlobalEnums.DeploymentType.LINE
	mission.victory_condition = GlobalEnums.VictoryConditionType.TURNS
	mission.ai_behavior = GlobalEnums.AIBehavior.TACTICAL
	return mission

func _generate_random_objective() -> GlobalEnums.MissionObjective:
	return GlobalEnums.MissionObjective.values()[randi() % GlobalEnums.MissionObjective.size()]

func _generate_rewards(difficulty: int) -> Dictionary:
	return {
		"credits": difficulty * 100 + randi() % 100,
		"reputation": difficulty
	}
