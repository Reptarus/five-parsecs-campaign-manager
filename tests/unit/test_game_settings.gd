extends "res://addons/gut/test.gd"

const GameSettings = preload("res://src/core/state/GameSettings.gd")
const GameEnums = preload("res://src/core/systems/GlobalEnums.gd")

var settings: GameSettings

func before_each() -> void:
    settings = GameSettings.new()

func after_each() -> void:
    settings = null

func test_initialization() -> void:
    assert_eq(settings.difficulty_level, GameEnums.DifficultyLevel.NORMAL, "Should initialize with normal difficulty")
    assert_eq(settings.campaign_type, GameEnums.FiveParcsecsCampaignType.STANDARD, "Should initialize with standard campaign")
    assert_eq(settings.victory_condition, GameEnums.FiveParcsecsCampaignVictoryType.STANDARD, "Should initialize with standard victory condition")
    assert_true(settings.tutorial_enabled, "Should initialize with tutorials enabled")
    assert_true(settings.auto_save_enabled, "Should initialize with auto-save enabled")
    assert_eq(settings.auto_save_frequency, 15, "Should initialize with default auto-save frequency")
    assert_true(settings.sound_enabled, "Should initialize with sound enabled")
    assert_eq(settings.sound_volume, 1.0, "Should initialize with full sound volume")
    assert_true(settings.music_enabled, "Should initialize with music enabled")
    assert_eq(settings.music_volume, 1.0, "Should initialize with full music volume")

func test_difficulty_settings() -> void:
    # Test setting difficulty
    settings.set_difficulty(GameEnums.DifficultyLevel.HARD)
    assert_eq(settings.difficulty_level, GameEnums.DifficultyLevel.HARD, "Should update difficulty level")
    
    # Test difficulty modifiers
    assert_eq(settings.get_enemy_strength_modifier(), 1.5, "Should increase enemy strength on hard")
    assert_eq(settings.get_loot_modifier(), 0.8, "Should decrease loot on hard")
    assert_eq(settings.get_credit_modifier(), 0.7, "Should decrease credits on hard")
    
    # Test easy difficulty
    settings.set_difficulty(GameEnums.DifficultyLevel.EASY)
    assert_eq(settings.get_enemy_strength_modifier(), 0.8, "Should decrease enemy strength on easy")
    assert_eq(settings.get_loot_modifier(), 1.2, "Should increase loot on easy")
    assert_eq(settings.get_credit_modifier(), 1.2, "Should increase credits on easy")

func test_campaign_settings() -> void:
    # Test setting campaign type
    settings.set_campaign_type(GameEnums.FiveParcsecsCampaignType.STORY)
    assert_eq(settings.campaign_type, GameEnums.FiveParcsecsCampaignType.STORY, "Should update campaign type")
    
    # Test setting victory condition
    settings.set_victory_condition(GameEnums.FiveParcsecsCampaignVictoryType.STORY_COMPLETE)
    assert_eq(settings.victory_condition, GameEnums.FiveParcsecsCampaignVictoryType.STORY_COMPLETE, "Should update victory condition")
    
    # Test campaign restrictions
    assert_true(settings.is_story_missions_enabled(), "Should enable story missions in story campaign")
    assert_false(settings.is_sandbox_features_enabled(), "Should disable sandbox features in story campaign")

func test_tutorial_settings() -> void:
    # Test disabling tutorials
    settings.set_tutorial_enabled(false)
    assert_false(settings.tutorial_enabled, "Should disable tutorials")
    assert_false(settings.should_show_tutorial("any_tutorial"), "Should not show tutorials when disabled")
    
    # Test tutorial tracking
    settings.set_tutorial_enabled(true)
    assert_true(settings.should_show_tutorial("test_tutorial"), "Should show unseen tutorial")
    settings.mark_tutorial_completed("test_tutorial")
    assert_false(settings.should_show_tutorial("test_tutorial"), "Should not show completed tutorial")
    
    # Test tutorial reset
    settings.reset_tutorials()
    assert_true(settings.should_show_tutorial("test_tutorial"), "Should show tutorial after reset")

func test_auto_save_settings() -> void:
    # Test disabling auto-save
    settings.set_auto_save_enabled(false)
    assert_false(settings.auto_save_enabled, "Should disable auto-save")
    
    # Test auto-save frequency
    settings.set_auto_save_frequency(30)
    assert_eq(settings.auto_save_frequency, 30, "Should update auto-save frequency")
    
    # Test frequency limits
    settings.set_auto_save_frequency(0)
    assert_eq(settings.auto_save_frequency, 5, "Should enforce minimum frequency")
    settings.set_auto_save_frequency(120)
    assert_eq(settings.auto_save_frequency, 60, "Should enforce maximum frequency")

func test_audio_settings() -> void:
    # Test sound settings
    settings.set_sound_enabled(false)
    assert_false(settings.sound_enabled, "Should disable sound")
    settings.set_sound_volume(0.5)
    assert_eq(settings.sound_volume, 0.5, "Should update sound volume")
    
    # Test music settings
    settings.set_music_enabled(false)
    assert_false(settings.music_enabled, "Should disable music")
    settings.set_music_volume(0.7)
    assert_eq(settings.music_volume, 0.7, "Should update music volume")
    
    # Test volume limits
    settings.set_sound_volume(1.5)
    assert_eq(settings.sound_volume, 1.0, "Should clamp sound volume to maximum")
    settings.set_music_volume(-0.5)
    assert_eq(settings.music_volume, 0.0, "Should clamp music volume to minimum")

func test_serialization() -> void:
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
    var data = settings.serialize()
    var new_settings = GameSettings.deserialize_new(data)
    
    # Verify settings
    assert_eq(new_settings.difficulty_level, settings.difficulty_level, "Should preserve difficulty level")
    assert_eq(new_settings.campaign_type, settings.campaign_type, "Should preserve campaign type")
    assert_eq(new_settings.victory_condition, settings.victory_condition, "Should preserve victory condition")
    assert_eq(new_settings.tutorial_enabled, settings.tutorial_enabled, "Should preserve tutorial setting")
    assert_eq(new_settings.auto_save_enabled, settings.auto_save_enabled, "Should preserve auto-save setting")
    assert_eq(new_settings.auto_save_frequency, settings.auto_save_frequency, "Should preserve auto-save frequency")
    assert_eq(new_settings.sound_enabled, settings.sound_enabled, "Should preserve sound setting")
    assert_eq(new_settings.sound_volume, settings.sound_volume, "Should preserve sound volume")
    assert_eq(new_settings.music_enabled, settings.music_enabled, "Should preserve music setting")
    assert_eq(new_settings.music_volume, settings.music_volume, "Should preserve music volume")