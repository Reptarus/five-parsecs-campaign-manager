extends Resource
class_name GameSettings

const GlobalEnums = preload("res://src/core/systems/GlobalEnums.gd")

@export var difficulty_level: GlobalEnums.DifficultyLevel = GlobalEnums.DifficultyLevel.NORMAL
@export var campaign_type: GlobalEnums.FiveParcsecsCampaignType = GlobalEnums.FiveParcsecsCampaignType.STANDARD
@export var victory_condition: GlobalEnums.FiveParcsecsCampaignVictoryType = GlobalEnums.FiveParcsecsCampaignVictoryType.STANDARD
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
func set_difficulty(level: GlobalEnums.DifficultyLevel) -> void:
	difficulty_level = level
func get_enemy_strength_modifier() -> float:
	match difficulty_level:
		GlobalEnums.DifficultyLevel.EASY:
			return 0.8
		GlobalEnums.DifficultyLevel.HARD:
			return 1.5
		GlobalEnums.DifficultyLevel.NIGHTMARE:
			return 2.0
		GlobalEnums.DifficultyLevel.HARDCORE:
			return 2.5
		GlobalEnums.DifficultyLevel.ELITE:
			return 3.0
		_:
			return 1.0

func get_loot_modifier() -> float:
	match difficulty_level:
		GlobalEnums.DifficultyLevel.EASY:
			return 1.2
		GlobalEnums.DifficultyLevel.HARD:
			return 0.8
		GlobalEnums.DifficultyLevel.NIGHTMARE:
			return 0.6
		GlobalEnums.DifficultyLevel.HARDCORE:
			return 0.5
		GlobalEnums.DifficultyLevel.ELITE:
			return 0.4
		_:
			return 1.0

func get_credit_modifier() -> float:
	match difficulty_level:
		GlobalEnums.DifficultyLevel.EASY:
			return 1.2
		GlobalEnums.DifficultyLevel.HARD:
			return 0.7
		GlobalEnums.DifficultyLevel.NIGHTMARE:
			return 0.5
		GlobalEnums.DifficultyLevel.HARDCORE:
			return 0.4
		GlobalEnums.DifficultyLevel.ELITE:
			return 0.3
		_:
			return 1.0

func set_campaign_type(type: GlobalEnums.FiveParcsecsCampaignType) -> void:
	campaign_type = type
func set_victory_condition(condition: GlobalEnums.FiveParcsecsCampaignVictoryType) -> void:
	victory_condition = condition
func is_story_missions_enabled() -> bool:
	return campaign_type == GlobalEnums.FiveParcsecsCampaignType.STORY

func is_sandbox_features_enabled() -> bool:
	return campaign_type == GlobalEnums.FiveParcsecsCampaignType.SANDBOX

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
	difficulty_level = data.get("difficulty_level", GlobalEnums.DifficultyLevel.NORMAL)

	campaign_type = data.get("campaign_type", GlobalEnums.FiveParcsecsCampaignType.STANDARD)

	victory_condition = data.get("victory_condition", GlobalEnums.FiveParcsecsCampaignVictoryType.STANDARD)

	tutorial_enabled = data.get("tutorial_enabled", true)

	completed_tutorials = data.get("completed_tutorials", [])

	auto_save_enabled = data.get("auto_save_enabled", true)

	auto_save_frequency = data.get("auto_save_frequency", 15)

	sound_enabled = data.get("sound_enabled", true)

	sound_volume = data.get("sound_volume", 1.0)

	music_enabled = data.get("music_enabled", true)

	music_volume = data.get("music_volume", 1.0)

static func deserialize_new(data: Dictionary) -> GameSettings:
	var settings := GameSettings.new()
	if settings and settings.has_method("deserialize"): settings.deserialize(data)
	return settings

## Safe property access helper - eliminates UNSAFE_METHOD_ACCESS warnings
## Based on Godot 4.4 best practices for safe property access
func safe_get_property(obj: Variant, property: String, default_value: Variant = null) -> Variant:
	if obj == null:
		return default_value
	if obj is Object and obj.has_method("get"):
		var value: Variant = obj.get(property)
		return value if value != null else default_value
	elif obj is Dictionary:
		return obj.get(property, default_value)
	return default_value
## Safe method call helper - eliminates UNSAFE_METHOD_ACCESS warnings
func safe_call_method(obj: Variant, method_name: String, args: Array = []) -> Variant:
	if obj == null:
		return null
	if obj is Object and obj.has_method(method_name):
		return obj.callv(method_name, args)
	return null
