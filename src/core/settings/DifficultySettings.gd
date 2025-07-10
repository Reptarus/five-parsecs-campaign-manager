# DifficultySettings.gd
extends Resource

const GlobalEnums = preload("res://src/core/systems/GlobalEnums.gd")

var enemy_health_modifier: float = 1.0
var enemy_damage_modifier: float = 1.0
var enemy_count_modifier: float = 1.0
var resource_gain_modifier: float = 1.0
var experience_gain_modifier: float = 1.0
var mission_reward_modifier: float = 1.0
var permadeath_enabled: bool = false
var tutorial_enabled: bool = true

func apply_difficulty_settings(difficulty: GlobalEnums.DifficultyLevel) -> void:
	match difficulty:
		GlobalEnums.DifficultyLevel.EASY:
			enemy_health_modifier = 0.8
			enemy_damage_modifier = 0.8
			enemy_count_modifier = 0.8
			resource_gain_modifier = 1.2
			experience_gain_modifier = 1.2
			mission_reward_modifier = 1.2
			permadeath_enabled = false
			tutorial_enabled = true
		GlobalEnums.DifficultyLevel.NORMAL:
			enemy_health_modifier = 1.0
			enemy_damage_modifier = 1.0
			enemy_count_modifier = 1.0
			resource_gain_modifier = 1.0
			experience_gain_modifier = 1.0
			mission_reward_modifier = 1.0
			permadeath_enabled = false
			tutorial_enabled = true
		GlobalEnums.DifficultyLevel.HARD:
			enemy_health_modifier = 1.2
			enemy_damage_modifier = 1.2
			enemy_count_modifier = 1.2
			resource_gain_modifier = 0.9
			experience_gain_modifier = 1.1
			mission_reward_modifier = 0.9
			permadeath_enabled = false
			tutorial_enabled = false
		GlobalEnums.DifficultyLevel.HARDCORE:
			enemy_health_modifier = 1.4
			enemy_damage_modifier = 1.3
			enemy_count_modifier = 1.3
			resource_gain_modifier = 0.8
			experience_gain_modifier = 1.2
			mission_reward_modifier = 0.8
			permadeath_enabled = true
			tutorial_enabled = false
		GlobalEnums.DifficultyLevel.ELITE:
			enemy_health_modifier = 1.6
			enemy_damage_modifier = 1.4
			enemy_count_modifier = 1.4
			resource_gain_modifier = 0.7
			experience_gain_modifier = 1.3
			mission_reward_modifier = 0.7
			permadeath_enabled = true
			tutorial_enabled = false
