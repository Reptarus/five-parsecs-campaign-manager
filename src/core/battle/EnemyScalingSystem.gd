class_name EnemyScalingSystem
extends Node

const GameEnums = preload("res://src/core/systems/GlobalEnums.gd")

var base_health: float = 100.0
var base_damage: float = 10.0
var base_armor: float = 5.0
var base_speed: float = 4.0

var health_modifier: float = 1.0
var damage_modifier: float = 1.0
var armor_modifier: float = 1.0
var speed_modifier: float = 1.0
var count_modifier: float = 1.0

func calculate_enemy_scaling(difficulty: GameEnums.DifficultyLevel, player_level: int, mission_type: GameEnums.MissionType) -> Dictionary:
	_apply_difficulty_scaling(difficulty)
	_apply_mission_type_scaling(mission_type)
	_apply_level_scaling(player_level)
	
	return {
		"health": base_health * health_modifier,
		"damage": base_damage * damage_modifier,
		"armor": base_armor * armor_modifier,
		"speed": base_speed * speed_modifier,
		"count_modifier": count_modifier
	}

func _apply_level_scaling(level: int) -> void:
	var level_modifier = 1.0 + (level * 0.1)
	health_modifier *= level_modifier
	damage_modifier *= level_modifier
	armor_modifier *= level_modifier

func _apply_difficulty_scaling(difficulty: GameEnums.DifficultyLevel) -> void:
	match difficulty:
		GameEnums.DifficultyLevel.EASY:
			health_modifier = 0.8
			damage_modifier = 0.8
			armor_modifier = 0.8
			count_modifier = 0.8
			
		GameEnums.DifficultyLevel.NORMAL:
			health_modifier = 1.0
			damage_modifier = 1.0
			armor_modifier = 1.0
			count_modifier = 1.0
			
		GameEnums.DifficultyLevel.HARD:
			health_modifier = 1.2
			damage_modifier = 1.2
			armor_modifier = 1.1
			count_modifier = 1.2
			
		GameEnums.DifficultyLevel.VETERAN:
			health_modifier = 1.4
			damage_modifier = 1.3
			armor_modifier = 1.2
			count_modifier = 1.3
			
		GameEnums.DifficultyLevel.ELITE:
			health_modifier = 1.6
			damage_modifier = 1.4
			armor_modifier = 1.3
			count_modifier = 1.4

func _apply_mission_type_scaling(mission_type: GameEnums.MissionType) -> void:
	match mission_type:
		GameEnums.MissionType.GREEN_ZONE:
			health_modifier *= 0.9
			damage_modifier *= 0.9
			
		GameEnums.MissionType.RED_ZONE:
			health_modifier *= 1.2
			damage_modifier *= 1.2
			count_modifier *= 1.1
			
		GameEnums.MissionType.BLACK_ZONE:
			health_modifier *= 1.4
			damage_modifier *= 1.4
			armor_modifier *= 1.2
			count_modifier *= 1.2