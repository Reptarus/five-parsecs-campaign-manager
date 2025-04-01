extends Resource
# This file should be referenced via preload
# Use explicit preloads instead of global class names

const Self = preload("res://src/core/state/GameSettings.gd")

const GameEnums = preload("res://src/core/enums/GameEnums.gd")

@export var difficulty_level: GameEnums.DifficultyLevel = GameEnums.DifficultyLevel.NORMAL
@export var campaign_type: GameEnums.FiveParcsecsCampaignType = GameEnums.FiveParcsecsCampaignType.STANDARD
@export var victory_condition: GameEnums.FiveParcsecsCampaignVictoryType = GameEnums.FiveParcsecsCampaignVictoryType.STANDARD
@export var tutorial_enabled: bool = true
@export var auto_save_enabled: bool = true
@export var auto_save_frequency: int = 15
@export var sound_enabled: bool = true
@export var sound_volume: float = 1.0
@export var music_enabled: bool = true
@export var music_volume: float = 1.0

var completed_tutorials: Array[String] = []

func _init() -> void:
    pass

func set_difficulty(level: GameEnums.DifficultyLevel) -> void:
    difficulty_level = level

func get_enemy_strength_modifier() -> float:
    match difficulty_level:
        GameEnums.DifficultyLevel.EASY:
            return 0.8
        GameEnums.DifficultyLevel.HARD:
            return 1.5
        GameEnums.DifficultyLevel.NIGHTMARE:
            return 2.0
        GameEnums.DifficultyLevel.HARDCORE:
            return 2.5
        GameEnums.DifficultyLevel.ELITE:
            return 3.0
        _:
            return 1.0

func get_loot_modifier() -> float:
    match difficulty_level:
        GameEnums.DifficultyLevel.EASY:
            return 1.2
        GameEnums.DifficultyLevel.HARD:
            return 0.8
        GameEnums.DifficultyLevel.NIGHTMARE:
            return 0.6
        GameEnums.DifficultyLevel.HARDCORE:
            return 0.5
        GameEnums.DifficultyLevel.ELITE:
            return 0.4
        _:
            return 1.0

func get_credit_modifier() -> float:
    match difficulty_level:
        GameEnums.DifficultyLevel.EASY:
            return 1.2
        GameEnums.DifficultyLevel.HARD:
            return 0.7
        GameEnums.DifficultyLevel.NIGHTMARE:
            return 0.5
        GameEnums.DifficultyLevel.HARDCORE:
            return 0.4
        GameEnums.DifficultyLevel.ELITE:
            return 0.3
        _:
            return 1.0

func set_campaign_type(type: GameEnums.FiveParcsecsCampaignType) -> void:
    campaign_type = type

func set_victory_condition(condition: GameEnums.FiveParcsecsCampaignVictoryType) -> void:
    victory_condition = condition

func is_story_missions_enabled() -> bool:
    return campaign_type == GameEnums.FiveParcsecsCampaignType.STORY

func is_sandbox_features_enabled() -> bool:
    return campaign_type == GameEnums.FiveParcsecsCampaignType.SANDBOX

func set_tutorial_enabled(enabled: bool) -> void:
    tutorial_enabled = enabled

func should_show_tutorial(tutorial_id: String) -> bool:
    return tutorial_enabled and not (tutorial_id in completed_tutorials)

func mark_tutorial_completed(tutorial_id: String) -> void:
    if not (tutorial_id in completed_tutorials):
        completed_tutorials.append(tutorial_id)

func reset_tutorials() -> void:
    completed_tutorials.clear()

func set_auto_save_enabled(enabled: bool) -> void:
    auto_save_enabled = enabled

func set_auto_save_frequency(minutes: int) -> void:
    auto_save_frequency = clampi(minutes, 5, 60)

func set_sound_enabled(enabled: bool) -> void:
    sound_enabled = enabled

func set_sound_volume(volume: float) -> void:
    sound_volume = clampf(volume, 0.0, 1.0)

func set_music_enabled(enabled: bool) -> void:
    music_enabled = enabled

func set_music_volume(volume: float) -> void:
    music_volume = clampf(volume, 0.0, 1.0)

func serialize() -> Dictionary:
    return {
        "difficulty_level": difficulty_level,
        "campaign_type": campaign_type,
        "victory_condition": victory_condition,
        "tutorial_enabled": tutorial_enabled,
        "completed_tutorials": completed_tutorials,
        "auto_save_enabled": auto_save_enabled,
        "auto_save_frequency": auto_save_frequency,
        "sound_enabled": sound_enabled,
        "sound_volume": sound_volume,
        "music_enabled": music_enabled,
        "music_volume": music_volume
    }

func deserialize(data: Dictionary) -> void:
    difficulty_level = data.get("difficulty_level", GameEnums.DifficultyLevel.NORMAL)
    campaign_type = data.get("campaign_type", GameEnums.FiveParcsecsCampaignType.STANDARD)
    victory_condition = data.get("victory_condition", GameEnums.FiveParcsecsCampaignVictoryType.STANDARD)
    tutorial_enabled = data.get("tutorial_enabled", true)
    completed_tutorials = data.get("completed_tutorials", [])
    auto_save_enabled = data.get("auto_save_enabled", true)
    auto_save_frequency = data.get("auto_save_frequency", 15)
    sound_enabled = data.get("sound_enabled", true)
    sound_volume = data.get("sound_volume", 1.0)
    music_enabled = data.get("music_enabled", true)
    music_volume = data.get("music_volume", 1.0)

static func deserialize_new(data: Dictionary) -> Resource:
    var settings = Self.new()
    settings.deserialize(data)
    return settings
