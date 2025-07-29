# DifficultySettings.gd
extends Resource

# GlobalEnums available as autoload singleton

var enemy_health_modifier: float = 1.0
var enemy_damage_modifier: float = 1.0
var enemy_count_modifier: float = 1.0
var resource_gain_modifier: float = 1.0
var experience_gain_modifier: float = 1.0
var mission_reward_modifier: float = 1.0
var player_health_bonus: float = 1.0
var player_damage_bonus: float = 1.0
var experience_multiplier: float = 1.0
var credit_multiplier: float = 1.0
var permadeath_enabled: bool = false
var tutorial_enabled: bool = true

func apply_difficulty_settings(difficulty: GlobalEnums.DifficultyLevel) -> void:
	match difficulty:
		GlobalEnums.DifficultyLevel.STORY:
			enemy_health_modifier = 0.8
			enemy_damage_modifier = 0.8
			enemy_count_modifier = 0.8
			player_health_bonus = 1.2
			player_damage_bonus = 1.2
			experience_multiplier = 1.5
			credit_multiplier = 1.5
			permadeath_enabled = false
			tutorial_enabled = true
		GlobalEnums.DifficultyLevel.STANDARD:
			enemy_health_modifier = 1.0
			enemy_damage_modifier = 1.0
			enemy_count_modifier = 1.0
			player_health_bonus = 1.0
			player_damage_bonus = 1.0
			experience_multiplier = 1.0
			credit_multiplier = 1.0
			permadeath_enabled = false
			tutorial_enabled = true
		GlobalEnums.DifficultyLevel.CHALLENGING:
			enemy_health_modifier = 1.2
			enemy_damage_modifier = 1.2
			enemy_count_modifier = 1.2
			player_health_bonus = 0.9
			player_damage_bonus = 0.9
			experience_multiplier = 0.8
			credit_multiplier = 0.8
			permadeath_enabled = true
			tutorial_enabled = false
