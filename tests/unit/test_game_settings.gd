@tool
extends GameTest

const GameSettings = preload("res://src/core/state/GameSettings.gd")

var settings: GameSettings

func before_each() -> void:
    await super.before_each()
    settings = GameSettings.new()
    if not settings:
        push_error("Failed to create game settings")
        return
    track_test_resource(settings)
    await stabilize_engine()

func after_each() -> void:
    await super.after_each()
    settings = null

func test_initialization() -> void:
    assert_eq(_call_resource_method(settings, "get_difficulty_level") as int, GameEnums.DifficultyLevel.NORMAL, "Should initialize with normal difficulty")
    assert_eq(_call_resource_method(settings, "get_campaign_type") as int, GameEnums.FiveParcsecsCampaignType.STANDARD, "Should initialize with standard campaign")
    assert_eq(_call_resource_method(settings, "get_victory_condition") as int, GameEnums.FiveParcsecsCampaignVictoryType.STANDARD, "Should initialize with standard victory condition")
    assert_true(_call_resource_method(settings, "get_tutorial_enabled") as bool, "Should initialize with tutorials enabled")
    assert_true(_call_resource_method(settings, "get_auto_save_enabled") as bool, "Should initialize with auto-save enabled")
    assert_eq(_call_resource_method(settings, "get_auto_save_frequency") as int, 15, "Should initialize with default auto-save frequency")
    assert_true(_call_resource_method(settings, "get_sound_enabled") as bool, "Should initialize with sound enabled")
    assert_eq(_call_resource_method(settings, "get_sound_volume") as float, 1.0, "Should initialize with full sound volume")
    assert_true(_call_resource_method(settings, "get_music_enabled") as bool, "Should initialize with music enabled")
    assert_eq(_call_resource_method(settings, "get_music_volume") as float, 1.0, "Should initialize with full music volume")

func test_difficulty_settings() -> void:
    # Test setting difficulty
    _call_resource_method(settings, "set_difficulty", [GameEnums.DifficultyLevel.HARD])
    assert_eq(_call_resource_method(settings, "get_difficulty_level") as int, GameEnums.DifficultyLevel.HARD, "Should update difficulty level")
    
    # Test difficulty modifiers
    assert_eq(_call_resource_method(settings, "get_enemy_strength_modifier") as float, 1.5, "Should increase enemy strength on hard")
    assert_eq(_call_resource_method(settings, "get_loot_modifier") as float, 0.8, "Should decrease loot on hard")
    assert_eq(_call_resource_method(settings, "get_credit_modifier") as float, 0.7, "Should decrease credits on hard")
    
    # Test easy difficulty
    _call_resource_method(settings, "set_difficulty", [GameEnums.DifficultyLevel.EASY])
    assert_eq(_call_resource_method(settings, "get_enemy_strength_modifier") as float, 0.8, "Should decrease enemy strength on easy")
    assert_eq(_call_resource_method(settings, "get_loot_modifier") as float, 1.2, "Should increase loot on easy")
    assert_eq(_call_resource_method(settings, "get_credit_modifier") as float, 1.2, "Should increase credits on easy")

func test_campaign_settings() -> void:
    # Test setting campaign type
    _call_resource_method(settings, "set_campaign_type", [GameEnums.FiveParcsecsCampaignType.STORY])
    assert_eq(_call_resource_method(settings, "get_campaign_type") as int, GameEnums.FiveParcsecsCampaignType.STORY, "Should update campaign type")
    
    # Test setting victory condition
    _call_resource_method(settings, "set_victory_condition", [GameEnums.FiveParcsecsCampaignVictoryType.STORY_COMPLETE])
    assert_eq(_call_resource_method(settings, "get_victory_condition") as int, GameEnums.FiveParcsecsCampaignVictoryType.STORY_COMPLETE, "Should update victory condition")
    
    # Test campaign restrictions
    assert_true(_call_resource_method(settings, "is_story_missions_enabled") as bool, "Should enable story missions in story campaign")
    assert_false(_call_resource_method(settings, "is_sandbox_features_enabled") as bool, "Should disable sandbox features in story campaign")

func test_tutorial_settings() -> void:
    # Test disabling tutorials
    _call_resource_method(settings, "set_tutorial_enabled", [false])
    assert_false(_call_resource_method(settings, "get_tutorial_enabled") as bool, "Should disable tutorials")
    assert_false(_call_resource_method(settings, "should_show_tutorial", ["any_tutorial"]) as bool, "Should not show tutorials when disabled")
    
    # Test tutorial tracking
    _call_resource_method(settings, "set_tutorial_enabled", [true])
    assert_true(_call_resource_method(settings, "should_show_tutorial", ["test_tutorial"]) as bool, "Should show unseen tutorial")
    _call_resource_method(settings, "mark_tutorial_completed", ["test_tutorial"])
    assert_false(_call_resource_method(settings, "should_show_tutorial", ["test_tutorial"]) as bool, "Should not show completed tutorial")
    
    # Test tutorial reset
    _call_resource_method(settings, "reset_tutorials")
    assert_true(_call_resource_method(settings, "should_show_tutorial", ["test_tutorial"]) as bool, "Should show tutorial after reset")

func test_auto_save_settings() -> void:
    # Test disabling auto-save
    _call_resource_method(settings, "set_auto_save_enabled", [false])
    assert_false(_call_resource_method(settings, "get_auto_save_enabled") as bool, "Should disable auto-save")
    
    # Test auto-save frequency
    _call_resource_method(settings, "set_auto_save_frequency", [30])
    assert_eq(_call_resource_method(settings, "get_auto_save_frequency") as int, 30, "Should update auto-save frequency")
    
    # Test frequency limits
    _call_resource_method(settings, "set_auto_save_frequency", [0])
    assert_eq(_call_resource_method(settings, "get_auto_save_frequency") as int, 5, "Should enforce minimum frequency")
    _call_resource_method(settings, "set_auto_save_frequency", [120])
    assert_eq(_call_resource_method(settings, "get_auto_save_frequency") as int, 60, "Should enforce maximum frequency")

func test_audio_settings() -> void:
    # Test sound settings
    _call_resource_method(settings, "set_sound_enabled", [false])
    assert_false(_call_resource_method(settings, "get_sound_enabled") as bool, "Should disable sound")
    _call_resource_method(settings, "set_sound_volume", [0.5])
    assert_eq(_call_resource_method(settings, "get_sound_volume") as float, 0.5, "Should update sound volume")
    
    # Test music settings
    _call_resource_method(settings, "set_music_enabled", [false])
    assert_false(_call_resource_method(settings, "get_music_enabled") as bool, "Should disable music")
    _call_resource_method(settings, "set_music_volume", [0.7])
    assert_eq(_call_resource_method(settings, "get_music_volume") as float, 0.7, "Should update music volume")
    
    # Test volume limits
    _call_resource_method(settings, "set_sound_volume", [1.5])
    assert_eq(_call_resource_method(settings, "get_sound_volume") as float, 1.0, "Should clamp sound volume to maximum")
    _call_resource_method(settings, "set_music_volume", [-0.5])
    assert_eq(_call_resource_method(settings, "get_music_volume") as float, 0.0, "Should clamp music volume to minimum")

func test_serialization() -> void:
    # Modify settings
    _call_resource_method(settings, "set_difficulty", [GameEnums.DifficultyLevel.HARD])
    _call_resource_method(settings, "set_campaign_type", [GameEnums.FiveParcsecsCampaignType.STORY])
    _call_resource_method(settings, "set_victory_condition", [GameEnums.FiveParcsecsCampaignVictoryType.STORY_COMPLETE])
    _call_resource_method(settings, "set_tutorial_enabled", [false])
    _call_resource_method(settings, "set_auto_save_enabled", [false])
    _call_resource_method(settings, "set_auto_save_frequency", [30])
    _call_resource_method(settings, "set_sound_enabled", [false])
    _call_resource_method(settings, "set_sound_volume", [0.5])
    _call_resource_method(settings, "set_music_enabled", [false])
    _call_resource_method(settings, "set_music_volume", [0.7])
    
    # Serialize and deserialize
    var data := _call_resource_method(settings, "serialize") as Dictionary
    var new_settings := _call_resource_method(GameSettings, "deserialize_new", [data]) as GameSettings
    track_test_resource(new_settings)
    
    # Verify settings
    assert_eq(_call_resource_method(new_settings, "get_difficulty_level") as int, _call_resource_method(settings, "get_difficulty_level") as int, "Should preserve difficulty level")
    assert_eq(_call_resource_method(new_settings, "get_campaign_type") as int, _call_resource_method(settings, "get_campaign_type") as int, "Should preserve campaign type")
    assert_eq(_call_resource_method(new_settings, "get_victory_condition") as int, _call_resource_method(settings, "get_victory_condition") as int, "Should preserve victory condition")
    assert_eq(_call_resource_method(new_settings, "get_tutorial_enabled") as bool, _call_resource_method(settings, "get_tutorial_enabled") as bool, "Should preserve tutorial setting")
    assert_eq(_call_resource_method(new_settings, "get_auto_save_enabled") as bool, _call_resource_method(settings, "get_auto_save_enabled") as bool, "Should preserve auto-save setting")
    assert_eq(_call_resource_method(new_settings, "get_auto_save_frequency") as int, _call_resource_method(settings, "get_auto_save_frequency") as int, "Should preserve auto-save frequency")
    assert_eq(_call_resource_method(new_settings, "get_sound_enabled") as bool, _call_resource_method(settings, "get_sound_enabled") as bool, "Should preserve sound setting")
    assert_eq(_call_resource_method(new_settings, "get_sound_volume") as float, _call_resource_method(settings, "get_sound_volume") as float, "Should preserve sound volume")
    assert_eq(_call_resource_method(new_settings, "get_music_enabled") as bool, _call_resource_method(settings, "get_music_enabled") as bool, "Should preserve music setting")
    assert_eq(_call_resource_method(new_settings, "get_music_volume") as float, _call_resource_method(settings, "get_music_volume") as float, "Should preserve music volume")