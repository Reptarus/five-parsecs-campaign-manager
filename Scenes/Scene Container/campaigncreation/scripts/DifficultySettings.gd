# DifficultySettings.gd
class_name DifficultySettings
extends Resource

enum DifficultyLevel { EASY, NORMAL, CHALLENGING, HARDCORE, INSANITY, BASIC_TUTORIAL, ADVANCED_TUTORIAL }

@export var level: DifficultyLevel = DifficultyLevel.NORMAL
@export var enemy_health_multiplier: float = 1.0
@export var enemy_damage_multiplier: float = 1.0
@export var loot_quantity_multiplier: float = 1.0
@export var event_frequency: float = 1.0
@export var enemy_count_modifier: int = 0
@export var invasion_roll_modifier: int = 0
@export var seize_initiative_penalty: int = 0
@export var unique_individual_modifier: int = 0
@export var story_point_modifier: int = 0
@export var specialist_enemy_count: int = 0
@export var unique_individual_chance: float = 0.0
@export var stars_of_story_disabled: bool = false
@export var tutorial_step: int = 0

func set_difficulty(new_level: DifficultyLevel) -> void:
	level = new_level
	match level:
		DifficultyLevel.EASY:
			enemy_health_multiplier = 0.8
			enemy_damage_multiplier = 0.8
			loot_quantity_multiplier = 1.2
			event_frequency = 0.8
			enemy_count_modifier = -1
			invasion_roll_modifier = 0
			seize_initiative_penalty = 0
			unique_individual_modifier = 0
			story_point_modifier = 0
			specialist_enemy_count = 0
			unique_individual_chance = 0.0
			stars_of_story_disabled = false
		DifficultyLevel.NORMAL:
			enemy_health_multiplier = 1.0
			enemy_damage_multiplier = 1.0
			loot_quantity_multiplier = 1.0
			event_frequency = 1.0
			enemy_count_modifier = 0
			invasion_roll_modifier = 0
			seize_initiative_penalty = 0
			unique_individual_modifier = 0
			story_point_modifier = 0
			specialist_enemy_count = 0
			unique_individual_chance = 0.0
			stars_of_story_disabled = false
		DifficultyLevel.CHALLENGING:
			enemy_health_multiplier = 1.0
			enemy_damage_multiplier = 1.0
			loot_quantity_multiplier = 1.0
			event_frequency = 1.0
			enemy_count_modifier = 0
			invasion_roll_modifier = 0
			seize_initiative_penalty = 0
			unique_individual_modifier = 0
			story_point_modifier = 0
			specialist_enemy_count = 0
			unique_individual_chance = 0.0
			stars_of_story_disabled = false
			# Special rule for Challenging
			# When rolling to determine enemy numbers faced in battle, count any die rolling a 1 or 2 as a 3.
		DifficultyLevel.HARDCORE:
			enemy_health_multiplier = 1.2
			enemy_damage_multiplier = 1.2
			loot_quantity_multiplier = 0.8
			event_frequency = 1.2
			enemy_count_modifier = 1  # Add an additional Basic enemy to every battle
			invasion_roll_modifier = 2
			seize_initiative_penalty = 2
			unique_individual_modifier = 1
			story_point_modifier = -1
			specialist_enemy_count = 0
			unique_individual_chance = 0.0
			stars_of_story_disabled = false
		DifficultyLevel.INSANITY:
			enemy_health_multiplier = 1.5
			enemy_damage_multiplier = 1.5
			loot_quantity_multiplier = 0.5
			event_frequency = 1.5
			enemy_count_modifier = 1  # Add an additional specialist enemy to every battle
			invasion_roll_modifier = 3
			seize_initiative_penalty = 3
			unique_individual_modifier = 0
			story_point_modifier = -999  # Effectively disables story points
			specialist_enemy_count = 1
			unique_individual_chance = 1.0  # Always includes a Unique Individual
			stars_of_story_disabled = true
		DifficultyLevel.BASIC_TUTORIAL:
			_set_basic_tutorial()
		DifficultyLevel.ADVANCED_TUTORIAL:
			_set_advanced_tutorial()

func _set_basic_tutorial() -> void:
	enemy_health_multiplier = 0.7
	enemy_damage_multiplier = 0.7
	loot_quantity_multiplier = 1.5
	event_frequency = 0.5
	enemy_count_modifier = -2
	invasion_roll_modifier = -2
	seize_initiative_penalty = 0
	unique_individual_modifier = -2
	story_point_modifier = 2
	specialist_enemy_count = 0
	unique_individual_chance = 0.0
	stars_of_story_disabled = false
	tutorial_step = 1

func _set_advanced_tutorial() -> void:
	enemy_health_multiplier = 0.9
	enemy_damage_multiplier = 0.9
	loot_quantity_multiplier = 1.2
	event_frequency = 0.8
	enemy_count_modifier = -1
	invasion_roll_modifier = -1
	seize_initiative_penalty = 1
	unique_individual_modifier = -1
	story_point_modifier = 1
	specialist_enemy_count = 0
	unique_individual_chance = 0.1
	stars_of_story_disabled = false
	tutorial_step = 1

func advance_tutorial() -> void:
	if level == DifficultyLevel.BASIC_TUTORIAL or level == DifficultyLevel.ADVANCED_TUTORIAL:
		tutorial_step += 1
		_adjust_tutorial_difficulty()

func _adjust_tutorial_difficulty() -> void:
	match tutorial_step:
		2:
			enemy_health_multiplier += 0.1
			enemy_damage_multiplier += 0.1
		3:
			enemy_count_modifier += 1
			loot_quantity_multiplier -= 0.1
		4:
			event_frequency += 0.2
			unique_individual_chance += 0.1
		5:
			specialist_enemy_count += 1
			story_point_modifier -= 1
		_:
			# For steps beyond 5, gradually increase difficulty
			enemy_health_multiplier += 0.05
			enemy_damage_multiplier += 0.05
			enemy_count_modifier += 1 if tutorial_step % 2 == 0 else 0

func to_dict() -> Dictionary:
	return {
		"level": DifficultyLevel.keys()[level],
		"enemy_health_multiplier": enemy_health_multiplier,
		"enemy_damage_multiplier": enemy_damage_multiplier,
		"loot_quantity_multiplier": loot_quantity_multiplier,
		"event_frequency": event_frequency,
		"enemy_count_modifier": enemy_count_modifier,
		"invasion_roll_modifier": invasion_roll_modifier,
		"seize_initiative_penalty": seize_initiative_penalty,
		"unique_individual_modifier": unique_individual_modifier,
		"story_point_modifier": story_point_modifier,
		"specialist_enemy_count": specialist_enemy_count,
		"unique_individual_chance": unique_individual_chance,
		"stars_of_story_disabled": stars_of_story_disabled,
		"tutorial_step": tutorial_step
	}

static func from_dict(data: Dictionary) -> DifficultySettings:
	var settings := DifficultySettings.new()
	settings.level = DifficultyLevel[data["level"]]
	settings.enemy_health_multiplier = data["enemy_health_multiplier"]
	settings.enemy_damage_multiplier = data["enemy_damage_multiplier"]
	settings.loot_quantity_multiplier = data["loot_quantity_multiplier"]
	settings.event_frequency = data["event_frequency"]
	settings.enemy_count_modifier = data["enemy_count_modifier"]
	settings.invasion_roll_modifier = data["invasion_roll_modifier"]
	settings.seize_initiative_penalty = data["seize_initiative_penalty"]
	settings.unique_individual_modifier = data["unique_individual_modifier"]
	settings.story_point_modifier = data["story_point_modifier"]
	settings.specialist_enemy_count = data["specialist_enemy_count"]
	settings.unique_individual_chance = data["unique_individual_chance"]
	settings.stars_of_story_disabled = data["stars_of_story_disabled"]
	settings.tutorial_step = data["tutorial_step"]
	return settings

func serialize() -> Dictionary:
	return to_dict()

static func deserialize(data: Dictionary) -> DifficultySettings:
	return from_dict(data)
