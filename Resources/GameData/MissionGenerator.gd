# Scripts/Missions/MissionGenerator.gd
class_name MissionGenerator
extends Node

const Mission = preload("res://Resources/GameData/Mission.gd")
const GlobalEnums = preload("res://Resources/GameData/GlobalEnums.gd")
const GameState = preload("res://Resources/GameData/GameState.gd")

var game_state: GameState
var difficulty_settings: DifficultySettings

func _init(_game_state: GameState) -> void:
	game_state = _game_state
	difficulty_settings = game_state.difficulty_settings

func generate_mission(mission_type: int = GlobalEnums.MissionType.OPPORTUNITY) -> Mission:
	var mission = Mission.new()
	
	mission.mission_type = mission_type
	mission.objective = _generate_objective(mission_type)
	mission.difficulty = _calculate_difficulty(mission_type)
	mission.time_limit = _calculate_time_limit(mission_type)
	mission.location = game_state.current_location
	mission.rewards = _generate_rewards(mission.difficulty, mission_type)
	mission.deployment_type = _select_deployment_type(mission_type)
	mission.victory_condition = _select_victory_condition(mission.objective)
	mission.ai_behavior = _select_ai_behavior(mission_type)
	
	_populate_mission_enemies(mission)
	_add_mission_conditions(mission)
	
	return mission

func _generate_objective(mission_type: int) -> int:
	match mission_type:
		GlobalEnums.MissionType.PATRON:
			return _generate_patron_objective()
		GlobalEnums.MissionType.STORY:
			return _generate_story_objective()
		GlobalEnums.MissionType.TUTORIAL:
			return GlobalEnums.MissionObjective.ELIMINATE_TARGET
		_:
			return _generate_random_objective()

func _calculate_difficulty(mission_type: int) -> int:
	var base_difficulty = 1
	
	match mission_type:
		GlobalEnums.MissionType.PATRON:
			base_difficulty += 1
		GlobalEnums.MissionType.STORY:
			base_difficulty += 2
		GlobalEnums.MissionType.TUTORIAL:
			base_difficulty = 1
	
	return base_difficulty + difficulty_settings.get_difficulty_modifier()

func _calculate_time_limit(mission_type: int) -> int:
	match mission_type:
		GlobalEnums.MissionType.PATRON:
			return randi() % 3 + 3  # 3-5 turns
		GlobalEnums.MissionType.STORY:
			return randi() % 2 + 4  # 4-5 turns
		GlobalEnums.MissionType.TUTORIAL:
			return 5  # Fixed time for tutorials
		_:
			return randi() % 3 + 2  # 2-4 turns

func _generate_rewards(difficulty: int, mission_type: int) -> Dictionary:
	var rewards = {
		"credits": _calculate_credit_reward(difficulty, mission_type),
		"reputation": _calculate_reputation_reward(difficulty, mission_type)
	}
	
	if randf() < 0.3:  # 30% chance for bonus reward
		rewards["item"] = true
	
	if mission_type == GlobalEnums.MissionType.STORY:
		rewards["story_points"] = difficulty
	
	return rewards

func _calculate_credit_reward(difficulty: int, mission_type: int) -> int:
	var base_reward = difficulty * 100
	
	match mission_type:
		GlobalEnums.MissionType.PATRON:
			base_reward *= 1.5
		GlobalEnums.MissionType.STORY:
			base_reward *= 2
		GlobalEnums.MissionType.TUTORIAL:
			base_reward = 50
	
	return int(base_reward)

func _calculate_reputation_reward(difficulty: int, mission_type: int) -> int:
	var base_reputation = difficulty
	
	match mission_type:
		GlobalEnums.MissionType.PATRON:
			base_reputation += 1
		GlobalEnums.MissionType.STORY:
			base_reputation += 2
		GlobalEnums.MissionType.TUTORIAL:
			base_reputation = 1
	
	return base_reputation

func _select_deployment_type(mission_type: int) -> int:
	match mission_type:
		GlobalEnums.MissionType.TUTORIAL:
			return GlobalEnums.DeploymentType.LINE
		GlobalEnums.MissionType.ASSAULT:
			return GlobalEnums.DeploymentType.SCATTERED
		GlobalEnums.MissionType.DEFENSE:
			return GlobalEnums.DeploymentType.DEFENSIVE
		_:
			return GlobalEnums.DeploymentType.values()[randi() % GlobalEnums.DeploymentType.size()]

func _select_victory_condition(objective: int) -> int:
	match objective:
		GlobalEnums.MissionObjective.MOVE_THROUGH:
			return GlobalEnums.VictoryConditionType.TURNS
		GlobalEnums.MissionObjective.ELIMINATE_TARGET:
			return GlobalEnums.VictoryConditionType.BATTLES
		_:
			return GlobalEnums.VictoryConditionType.QUESTS

func _select_ai_behavior(mission_type: int) -> int:
	match mission_type:
		GlobalEnums.MissionType.TUTORIAL:
			return GlobalEnums.AIBehavior.CAUTIOUS
		GlobalEnums.MissionType.ASSAULT:
			return GlobalEnums.AIBehavior.AGGRESSIVE
		GlobalEnums.MissionType.DEFENSE:
			return GlobalEnums.AIBehavior.DEFENSIVE
		_:
			return GlobalEnums.AIBehavior.TACTICAL

func _generate_patron_objective() -> int:
	var objectives = [
		GlobalEnums.MissionObjective.RETRIEVE,
		GlobalEnums.MissionObjective.PROTECT,
		GlobalEnums.MissionObjective.ELIMINATE
	]
	return objectives[randi() % objectives.size()]

func _generate_story_objective() -> int:
	var objectives = [
		GlobalEnums.MissionObjective.EXPLORE,
		GlobalEnums.MissionObjective.NEGOTIATE,
		GlobalEnums.MissionObjective.RESCUE
	]
	return objectives[randi() % objectives.size()]

func _generate_random_objective() -> int:
	return GlobalEnums.MissionObjective.values()[randi() % GlobalEnums.MissionObjective.size()]

func _populate_mission_enemies(mission: Mission) -> void:
	var enemy_count = _calculate_enemy_count(mission.difficulty, mission.mission_type)
	for i in enemy_count:
		var enemy = _generate_enemy(mission.difficulty)
		mission.enemies.append(enemy)

func _add_mission_conditions(mission: Mission) -> void:
	mission.required_crew_size = _calculate_required_crew_size(mission.difficulty)
	mission.hazards = _generate_hazards(mission.difficulty)
	mission.conditions = _generate_conditions(mission.mission_type)

func _calculate_enemy_count(difficulty: int, mission_type: int) -> int:
	var base_count = difficulty + 1
	if mission_type == GlobalEnums.MissionType.ASSAULT:
		base_count += 2
	return base_count

func _generate_enemy(difficulty: int) -> Character:
	# Implementation will depend on Enemy class
	return null

func _calculate_required_crew_size(difficulty: int) -> int:
	return difficulty + 2

func _generate_hazards(difficulty: int) -> Array[String]:
	# Implementation
	return []

func _generate_conditions(mission_type: int) -> Array[String]:
	# Implementation
	return []
