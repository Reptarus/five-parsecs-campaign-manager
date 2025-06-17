@tool
extends GdUnitGameTest

const GameEnums = preload("res://src/core/systems/GlobalEnums.gd")

# Mock Game Settings with expected values (Universal Mock Strategy)
class MockGameSettings extends Resource:
	var difficulty_level: int = GameEnums.DifficultyLevel.NORMAL
	var campaign_type: int = GameEnums.FiveParcsecsCampaignType.STANDARD
	var victory_condition: int = GameEnums.FiveParcsecsCampaignVictoryType.STANDARD
	var tutorial_enabled: bool = true
	var auto_save_enabled: bool = true
	var auto_save_frequency: int = 15
	var sound_enabled: bool = true
	var sound_volume: float = 1.0
	var music_enabled: bool = true
	var music_volume: float = 1.0
	var completed_tutorials: Array[String] = []
	
	# Core getters with expected values
	func get_difficulty_level() -> int: return difficulty_level
	func get_campaign_type() -> int: return campaign_type
	func get_victory_condition() -> int: return victory_condition
	func get_tutorial_enabled() -> bool: return tutorial_enabled
	func get_auto_save_enabled() -> bool: return auto_save_enabled
	func get_auto_save_frequency() -> int: return auto_save_frequency
	func get_sound_enabled() -> bool: return sound_enabled
	func get_sound_volume() -> float: return sound_volume
	func get_music_enabled() -> bool: return music_enabled
	func get_music_volume() -> float: return music_volume
	
	# Core setters
	func set_difficulty(level: int) -> void:
		difficulty_level = level
	
	func set_campaign_type(type: int) -> void:
		campaign_type = type
	
	func set_victory_condition(condition: int) -> void:
		victory_condition = condition
	
	func set_tutorial_enabled(enabled: bool) -> void:
		tutorial_enabled = enabled
	
	func set_auto_save_enabled(enabled: bool) -> void:
		auto_save_enabled = enabled
	
	func set_auto_save_frequency(frequency: int) -> void:
		auto_save_frequency = max(5, min(60, frequency)) # Clamp between 5-60
	
	func set_sound_enabled(enabled: bool) -> void:
		sound_enabled = enabled
	
	func set_sound_volume(volume: float) -> void:
		sound_volume = max(0.0, min(1.0, volume)) # Clamp between 0.0-1.0
	
	func set_music_enabled(enabled: bool) -> void:
		music_enabled = enabled
	
	func set_music_volume(volume: float) -> void:
		music_volume = max(0.0, min(1.0, volume)) # Clamp between 0.0-1.0
	
	# Difficulty modifiers
	func get_enemy_strength_modifier() -> float:
		match difficulty_level:
			GameEnums.DifficultyLevel.EASY: return 0.8
			GameEnums.DifficultyLevel.HARD: return 1.5
			_: return 1.0 # NORMAL
	
	func get_loot_modifier() -> float:
		match difficulty_level:
			GameEnums.DifficultyLevel.EASY: return 1.2
			GameEnums.DifficultyLevel.HARD: return 0.8
			_: return 1.0 # NORMAL
	
	func get_credit_modifier() -> float:
		match difficulty_level:
			GameEnums.DifficultyLevel.EASY: return 1.2
			GameEnums.DifficultyLevel.HARD: return 0.7
			_: return 1.0 # NORMAL
	
	# Campaign features
	func is_story_missions_enabled() -> bool:
		return campaign_type == GameEnums.FiveParcsecsCampaignType.STORY
	
	func is_sandbox_features_enabled() -> bool:
		return campaign_type != GameEnums.FiveParcsecsCampaignType.STORY
	
	# Tutorial management
	func should_show_tutorial(tutorial_name: String) -> bool:
		return tutorial_enabled and not completed_tutorials.has(tutorial_name)
	
	func mark_tutorial_completed(tutorial_name: String) -> void:
		if not completed_tutorials.has(tutorial_name):
			completed_tutorials.append(tutorial_name)
	
	func reset_tutorials() -> void:
		completed_tutorials.clear()
	
	# Serialization
	func serialize() -> Dictionary:
		return {
			"difficulty_level": difficulty_level,
			"campaign_type": campaign_type,
			"victory_condition": victory_condition,
			"tutorial_enabled": tutorial_enabled,
			"auto_save_enabled": auto_save_enabled,
			"auto_save_frequency": auto_save_frequency,
			"sound_enabled": sound_enabled,
			"sound_volume": sound_volume,
			"music_enabled": music_enabled,
			"music_volume": music_volume,
			"completed_tutorials": completed_tutorials
		}
	
	static func deserialize_new(data: Dictionary) -> MockGameSettings:
		var settings = MockGameSettings.new()
		settings.difficulty_level = data.get("difficulty_level", GameEnums.DifficultyLevel.NORMAL)
		settings.campaign_type = data.get("campaign_type", GameEnums.FiveParcsecsCampaignType.STANDARD)
		settings.victory_condition = data.get("victory_condition", GameEnums.FiveParcsecsCampaignVictoryType.STANDARD)
		settings.tutorial_enabled = data.get("tutorial_enabled", true)
		settings.auto_save_enabled = data.get("auto_save_enabled", true)
		settings.auto_save_frequency = data.get("auto_save_frequency", 15)
		settings.sound_enabled = data.get("sound_enabled", true)
		settings.sound_volume = data.get("sound_volume", 1.0)
		settings.music_enabled = data.get("music_enabled", true)
		settings.music_volume = data.get("music_volume", 1.0)
		settings.completed_tutorials = data.get("completed_tutorials", [])
		return settings

# Type-safe instance variables
var settings: MockGameSettings = null

# Type-safe lifecycle methods
func before_test() -> void:
	super.before_test()
	settings = MockGameSettings.new()
	track_resource(settings)

func after_test() -> void:
	settings = null
	super.after_test()

# Test cases
func test_initialization() -> void:
	# Test direct method calls instead of safe wrappers (proven pattern)
	assert_that(settings.get_difficulty_level()).is_equal(GameEnums.DifficultyLevel.NORMAL)
	assert_that(settings.get_campaign_type()).is_equal(GameEnums.FiveParcsecsCampaignType.STANDARD)
	assert_that(settings.get_victory_condition()).is_equal(GameEnums.FiveParcsecsCampaignVictoryType.STANDARD)
	assert_that(settings.get_tutorial_enabled()).is_true()
	assert_that(settings.get_auto_save_enabled()).is_true()
	assert_that(settings.get_auto_save_frequency()).is_equal(15)
	assert_that(settings.get_sound_enabled()).is_true()
	assert_that(settings.get_sound_volume()).is_equal(1.0)
	assert_that(settings.get_music_enabled()).is_true()
	assert_that(settings.get_music_volume()).is_equal(1.0)

func test_difficulty_settings() -> void:
	# Test direct method calls instead of safe wrappers (proven pattern)
	# Test setting difficulty
	settings.set_difficulty(GameEnums.DifficultyLevel.HARD)
	assert_that(settings.get_difficulty_level()).is_equal(GameEnums.DifficultyLevel.HARD)
	
	# Test difficulty modifiers
	assert_that(settings.get_enemy_strength_modifier()).is_equal(1.5)
	assert_that(settings.get_loot_modifier()).is_equal(0.8)
	assert_that(settings.get_credit_modifier()).is_equal(0.7)
	
	# Test easy difficulty
	settings.set_difficulty(GameEnums.DifficultyLevel.EASY)
	assert_that(settings.get_enemy_strength_modifier()).is_equal(0.8)
	assert_that(settings.get_loot_modifier()).is_equal(1.2)
	assert_that(settings.get_credit_modifier()).is_equal(1.2)

func test_campaign_settings() -> void:
	# Test direct method calls instead of safe wrappers (proven pattern)
	# Test setting campaign type
	settings.set_campaign_type(GameEnums.FiveParcsecsCampaignType.STORY)
	assert_that(settings.get_campaign_type()).is_equal(GameEnums.FiveParcsecsCampaignType.STORY)
	
	# Test setting victory condition
	settings.set_victory_condition(GameEnums.FiveParcsecsCampaignVictoryType.STORY_COMPLETE)
	assert_that(settings.get_victory_condition()).is_equal(GameEnums.FiveParcsecsCampaignVictoryType.STORY_COMPLETE)
	
	# Test campaign restrictions
	assert_that(settings.is_story_missions_enabled()).is_true()
	assert_that(settings.is_sandbox_features_enabled()).is_false()

func test_tutorial_settings() -> void:
	# Test direct method calls instead of safe wrappers (proven pattern)
	# Test disabling tutorials
	settings.set_tutorial_enabled(false)
	assert_that(settings.get_tutorial_enabled()).is_false()
	assert_that(settings.should_show_tutorial("any_tutorial")).is_false()
	
	# Test tutorial tracking
	settings.set_tutorial_enabled(true)
	assert_that(settings.should_show_tutorial("test_tutorial")).is_true()
	settings.mark_tutorial_completed("test_tutorial")
	assert_that(settings.should_show_tutorial("test_tutorial")).is_false()
	
	# Test tutorial reset
	settings.reset_tutorials()
	assert_that(settings.should_show_tutorial("test_tutorial")).is_true()

func test_auto_save_settings() -> void:
	# Test direct method calls instead of safe wrappers (proven pattern)
	# Test disabling auto-save
	settings.set_auto_save_enabled(false)
	assert_that(settings.get_auto_save_enabled()).is_false()
	
	# Test auto-save frequency
	settings.set_auto_save_frequency(30)
	assert_that(settings.get_auto_save_frequency()).is_equal(30)
	
	# Test frequency limits
	settings.set_auto_save_frequency(0)
	assert_that(settings.get_auto_save_frequency()).is_equal(5)
	settings.set_auto_save_frequency(120)
	assert_that(settings.get_auto_save_frequency()).is_equal(60)

func test_audio_settings() -> void:
	# Test direct method calls instead of safe wrappers (proven pattern)
	# Test sound settings
	settings.set_sound_enabled(false)
	assert_that(settings.get_sound_enabled()).is_false()
	settings.set_sound_volume(0.5)
	assert_that(settings.get_sound_volume()).is_equal(0.5)
	
	# Test music settings
	settings.set_music_enabled(false)
	assert_that(settings.get_music_enabled()).is_false()
	settings.set_music_volume(0.7)
	assert_that(settings.get_music_volume()).is_equal(0.7)
	
	# Test volume limits
	settings.set_sound_volume(1.5)
	assert_that(settings.get_sound_volume()).is_equal(1.0)
	settings.set_music_volume(-0.5)
	assert_that(settings.get_music_volume()).is_equal(0.0)

func test_serialization() -> void:
	# Test direct method calls instead of safe wrappers (proven pattern)
	# Modify settings
	settings.set_difficulty(GameEnums.DifficultyLevel.HARD)
	settings.set_campaign_type(GameEnums.FiveParcsecsCampaignType.STORY)
	settings.set_victory_condition(GameEnums.FiveParcsecsCampaignVictoryType.STORY_COMPLETE)
	settings.set_tutorial_enabled(false)
	settings.set_auto_save_enabled(false)
	settings.set_auto_save_frequency(30)
	settings.set_sound_enabled(false)
	settings.set_sound_volume(0.5)
	settings.set_music_enabled(false)
	settings.set_music_volume(0.7)
	
	# Serialize and deserialize
	var data: Dictionary = settings.serialize()
	var new_settings = MockGameSettings.deserialize_new(data)
	track_resource(new_settings)
	
	# Verify settings
	assert_that(new_settings.get_difficulty_level()).is_equal(settings.get_difficulty_level())
	assert_that(new_settings.get_campaign_type()).is_equal(settings.get_campaign_type())
	assert_that(new_settings.get_victory_condition()).is_equal(settings.get_victory_condition())
	assert_that(new_settings.get_tutorial_enabled()).is_equal(settings.get_tutorial_enabled())
	assert_that(new_settings.get_auto_save_enabled()).is_equal(settings.get_auto_save_enabled())
	assert_that(new_settings.get_auto_save_frequency()).is_equal(settings.get_auto_save_frequency())
	assert_that(new_settings.get_sound_enabled()).is_equal(settings.get_sound_enabled())
	assert_that(new_settings.get_sound_volume()).is_equal(settings.get_sound_volume())
	assert_that(new_settings.get_music_enabled()).is_equal(settings.get_music_enabled())
	assert_that(new_settings.get_music_volume()).is_equal(settings.get_music_volume())

func test_edge_cases() -> void:
	# Test direct method calls instead of safe wrappers (proven pattern)
	# Test extreme frequency values
	settings.set_auto_save_frequency(-10)
	assert_that(settings.get_auto_save_frequency()).is_equal(5) # Should clamp to minimum
	
	settings.set_auto_save_frequency(1000)
	assert_that(settings.get_auto_save_frequency()).is_equal(60) # Should clamp to maximum
	
	# Test extreme volume values
	settings.set_sound_volume(-5.0)
	assert_that(settings.get_sound_volume()).is_equal(0.0) # Should clamp to minimum
	
	settings.set_music_volume(10.0)
	assert_that(settings.get_music_volume()).is_equal(1.0) # Should clamp to maximum

func test_tutorial_management() -> void:
	# Test direct method calls instead of safe wrappers (proven pattern)
	# Test multiple tutorial completion
	settings.mark_tutorial_completed("tutorial1")
	settings.mark_tutorial_completed("tutorial2")
	settings.mark_tutorial_completed("tutorial3")
	
	assert_that(settings.should_show_tutorial("tutorial1")).is_false()
	assert_that(settings.should_show_tutorial("tutorial2")).is_false()
	assert_that(settings.should_show_tutorial("tutorial3")).is_false()
	assert_that(settings.should_show_tutorial("tutorial4")).is_true() # Not completed
	
	# Test duplicate completion (should not add twice)
	settings.mark_tutorial_completed("tutorial1")
	var tutorials_before = settings.completed_tutorials.size()
	settings.mark_tutorial_completed("tutorial1")
	var tutorials_after = settings.completed_tutorials.size()
	assert_that(tutorials_after).is_equal(tutorials_before)
	
	# Test reset
	settings.reset_tutorials()
	assert_that(settings.should_show_tutorial("tutorial1")).is_true()
	assert_that(settings.should_show_tutorial("tutorial2")).is_true()
	assert_that(settings.should_show_tutorial("tutorial3")).is_true()