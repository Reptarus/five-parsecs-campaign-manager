# DifficultySettings.gd
class_name DifficultySettings
extends Resource

const GlobalEnums = preload("res://Resources/GameData/GlobalEnums.gd")

@export var enemy_health_multiplier: float = 1.0
@export var enemy_damage_multiplier: float = 1.0
@export var loot_quantity_multiplier: float = 1.0
@export var injury_recovery_modifier: int = 0
@export var starting_credits_multiplier: float = 1.0
@export var enemy_count_modifier: int = 0
@export var unique_individual_chance: float = 0.0
@export var stars_of_story_disabled: bool = false

func apply_difficulty_settings(difficulty: GlobalEnums.DifficultyMode) -> void:
	match difficulty:
		GlobalEnums.DifficultyMode.EASY:
			enemy_health_multiplier = 0.8
			enemy_damage_multiplier = 0.8
			loot_quantity_multiplier = 1.2
			injury_recovery_modifier = 1
			starting_credits_multiplier = 1.2
			enemy_count_modifier = -1
			unique_individual_chance = 0.05
			stars_of_story_disabled = false
		GlobalEnums.DifficultyMode.NORMAL:
			enemy_health_multiplier = 1.0
			enemy_damage_multiplier = 1.0
			loot_quantity_multiplier = 1.0
			injury_recovery_modifier = 0
			starting_credits_multiplier = 1.0
			enemy_count_modifier = 0
			unique_individual_chance = 0.1
			stars_of_story_disabled = false
		GlobalEnums.DifficultyMode.HARD:
			enemy_health_multiplier = 1.2
			enemy_damage_multiplier = 1.2
			loot_quantity_multiplier = 0.8
			injury_recovery_modifier = -1
			starting_credits_multiplier = 0.8
			enemy_count_modifier = 1
			unique_individual_chance = 0.15
			stars_of_story_disabled = false
		GlobalEnums.DifficultyMode.VETERAN:
			enemy_health_multiplier = 1.4
			enemy_damage_multiplier = 1.4
			loot_quantity_multiplier = 0.7
			injury_recovery_modifier = -2
			starting_credits_multiplier = 0.7
			enemy_count_modifier = 2
			unique_individual_chance = 0.2
			stars_of_story_disabled = false
		GlobalEnums.DifficultyMode.CHALLENGING:
			enemy_health_multiplier = 1.6
			enemy_damage_multiplier = 1.6
			loot_quantity_multiplier = 0.6
			injury_recovery_modifier = -3
			starting_credits_multiplier = 0.6
			enemy_count_modifier = 3
			unique_individual_chance = 0.25
			stars_of_story_disabled = true
		GlobalEnums.DifficultyMode.HARDCORE:
			enemy_health_multiplier = 1.8
			enemy_damage_multiplier = 1.8
			loot_quantity_multiplier = 0.5
			injury_recovery_modifier = -4
			starting_credits_multiplier = 0.5
			enemy_count_modifier = 4
			unique_individual_chance = 0.3
			stars_of_story_disabled = true
		GlobalEnums.DifficultyMode.INSANITY:
			enemy_health_multiplier = 2.0
			enemy_damage_multiplier = 2.0
			loot_quantity_multiplier = 0.4
			injury_recovery_modifier = -5
			starting_credits_multiplier = 0.4
			enemy_count_modifier = 5
			unique_individual_chance = 0.35
			stars_of_story_disabled = true
			