@tool
extends "res://tests/fixtures/base/game_test.gd"

const GameSettings: GDScript = preload("res://src/core/state/GameSettings.gd")

# Type-safe instance variables
var settings: Resource = null

# Type-safe lifecycle methods
func before_each() -> void:
    await super.before_each()
    settings = GameSettings.new()
    if not settings:
        push_error("Failed to create game settings")
        return
    track_test_resource(settings)
    await stabilize_engine()

func after_each() -> void:
    settings = null
    await super.after_each()

# Test cases
func test_initialization() -> void:
    assert_eq(TypeSafeMixin._call_node_method_int(settings, "get_difficulty_level"), GameEnums.DifficultyLevel.NORMAL,
        "Should initialize with normal difficulty")
    assert_eq(TypeSafeMixin._call_node_method_int(settings, "get_campaign_type"), GameEnums.FiveParcsecsCampaignType.STANDARD,
        "Should initialize with standard campaign")
    assert_eq(TypeSafeMixin._call_node_method_int(settings, "get_victory_condition"), GameEnums.FiveParcsecsCampaignVictoryType.STANDARD,
        "Should initialize with standard victory condition")
    assert_true(TypeSafeMixin._call_node_method_bool(settings, "get_tutorial_enabled"),
        "Should initialize with tutorials enabled")
    assert_true(TypeSafeMixin._call_node_method_bool(settings, "get_auto_save_enabled"),
        "Should initialize with auto-save enabled")
    assert_eq(TypeSafeMixin._call_node_method_int(settings, "get_auto_save_frequency"), 15,
        "Should initialize with default auto-save frequency")
    assert_true(TypeSafeMixin._call_node_method_bool(settings, "get_sound_enabled"),
        "Should initialize with sound enabled")
    assert_eq(TypeSafeMixin._safe_cast_float(TypeSafeMixin._call_node_method(settings, "get_sound_volume")), 1.0,
        "Should initialize with full sound volume")
    assert_true(TypeSafeMixin._call_node_method_bool(settings, "get_music_enabled"),
        "Should initialize with music enabled")
    assert_eq(TypeSafeMixin._safe_cast_float(TypeSafeMixin._call_node_method(settings, "get_music_volume")), 1.0,
        "Should initialize with full music volume")

func test_difficulty_settings() -> void:
    # Test setting difficulty
    TypeSafeMixin._call_node_method_bool(settings, "set_difficulty", [GameEnums.DifficultyLevel.HARD])
    assert_eq(TypeSafeMixin._call_node_method_int(settings, "get_difficulty_level"), GameEnums.DifficultyLevel.HARD,
        "Should update difficulty level")
    
    # Test difficulty modifiers
    assert_eq(TypeSafeMixin._safe_cast_float(TypeSafeMixin._call_node_method(settings, "get_enemy_strength_modifier")), 1.5,
        "Should increase enemy strength on hard")
    assert_eq(TypeSafeMixin._safe_cast_float(TypeSafeMixin._call_node_method(settings, "get_loot_modifier")), 0.8,
        "Should decrease loot on hard")
    assert_eq(TypeSafeMixin._safe_cast_float(TypeSafeMixin._call_node_method(settings, "get_credit_modifier")), 0.7,
        "Should decrease credits on hard")
    
    # Test easy difficulty
    TypeSafeMixin._call_node_method_bool(settings, "set_difficulty", [GameEnums.DifficultyLevel.EASY])
    assert_eq(TypeSafeMixin._safe_cast_float(TypeSafeMixin._call_node_method(settings, "get_enemy_strength_modifier")), 0.8,
        "Should decrease enemy strength on easy")
    assert_eq(TypeSafeMixin._safe_cast_float(TypeSafeMixin._call_node_method(settings, "get_loot_modifier")), 1.2,
        "Should increase loot on easy")
    assert_eq(TypeSafeMixin._safe_cast_float(TypeSafeMixin._call_node_method(settings, "get_credit_modifier")), 1.2,
        "Should increase credits on easy")

func test_campaign_settings() -> void:
    # Test setting campaign type
    TypeSafeMixin._call_node_method_bool(settings, "set_campaign_type", [GameEnums.FiveParcsecsCampaignType.STORY])
    assert_eq(TypeSafeMixin._call_node_method_int(settings, "get_campaign_type"), GameEnums.FiveParcsecsCampaignType.STORY,
        "Should update campaign type")
    
    # Test setting victory condition
    TypeSafeMixin._call_node_method_bool(settings, "set_victory_condition", [GameEnums.FiveParcsecsCampaignVictoryType.STORY_COMPLETE])
    assert_eq(TypeSafeMixin._call_node_method_int(settings, "get_victory_condition"), GameEnums.FiveParcsecsCampaignVictoryType.STORY_COMPLETE,
        "Should update victory condition")
    
    # Test campaign restrictions
    assert_true(TypeSafeMixin._call_node_method_bool(settings, "is_story_missions_enabled"),
        "Should enable story missions in story campaign")
    assert_false(TypeSafeMixin._call_node_method_bool(settings, "is_sandbox_features_enabled"),
        "Should disable sandbox features in story campaign")

func test_tutorial_settings() -> void:
    # Test disabling tutorials
    TypeSafeMixin._call_node_method_bool(settings, "set_tutorial_enabled", [false])
    assert_false(TypeSafeMixin._call_node_method_bool(settings, "get_tutorial_enabled"),
        "Should disable tutorials")
    assert_false(TypeSafeMixin._call_node_method_bool(settings, "should_show_tutorial", ["any_tutorial"]),
        "Should not show tutorials when disabled")
    
    # Test tutorial tracking
    TypeSafeMixin._call_node_method_bool(settings, "set_tutorial_enabled", [true])
    assert_true(TypeSafeMixin._call_node_method_bool(settings, "should_show_tutorial", ["test_tutorial"]),
        "Should show unseen tutorial")
    TypeSafeMixin._call_node_method_bool(settings, "mark_tutorial_completed", ["test_tutorial"])
    assert_false(TypeSafeMixin._call_node_method_bool(settings, "should_show_tutorial", ["test_tutorial"]),
        "Should not show completed tutorial")
    
    # Test tutorial reset
    TypeSafeMixin._call_node_method_bool(settings, "reset_tutorials")
    assert_true(TypeSafeMixin._call_node_method_bool(settings, "should_show_tutorial", ["test_tutorial"]),
        "Should show tutorial after reset")

func test_auto_save_settings() -> void:
    # Test disabling auto-save
    TypeSafeMixin._call_node_method_bool(settings, "set_auto_save_enabled", [false])
    assert_false(TypeSafeMixin._call_node_method_bool(settings, "get_auto_save_enabled"),
        "Should disable auto-save")
    
    # Test auto-save frequency
    TypeSafeMixin._call_node_method_bool(settings, "set_auto_save_frequency", [30])
    assert_eq(TypeSafeMixin._call_node_method_int(settings, "get_auto_save_frequency"), 30,
        "Should update auto-save frequency")
    
    # Test frequency limits
    TypeSafeMixin._call_node_method_bool(settings, "set_auto_save_frequency", [0])
    assert_eq(TypeSafeMixin._call_node_method_int(settings, "get_auto_save_frequency"), 5,
        "Should enforce minimum frequency")
    TypeSafeMixin._call_node_method_bool(settings, "set_auto_save_frequency", [120])
    assert_eq(TypeSafeMixin._call_node_method_int(settings, "get_auto_save_frequency"), 60,
        "Should enforce maximum frequency")

func test_audio_settings() -> void:
    # Test sound settings
    TypeSafeMixin._call_node_method_bool(settings, "set_sound_enabled", [false])
    assert_false(TypeSafeMixin._call_node_method_bool(settings, "get_sound_enabled"),
        "Should disable sound")
    TypeSafeMixin._call_node_method_bool(settings, "set_sound_volume", [0.5])
    assert_eq(TypeSafeMixin._safe_cast_float(TypeSafeMixin._call_node_method(settings, "get_sound_volume")), 0.5,
        "Should update sound volume")
    
    # Test music settings
    TypeSafeMixin._call_node_method_bool(settings, "set_music_enabled", [false])
    assert_false(TypeSafeMixin._call_node_method_bool(settings, "get_music_enabled"),
        "Should disable music")
    TypeSafeMixin._call_node_method_bool(settings, "set_music_volume", [0.7])
    assert_eq(TypeSafeMixin._safe_cast_float(TypeSafeMixin._call_node_method(settings, "get_music_volume")), 0.7,
        "Should update music volume")
    
    # Test volume limits
    TypeSafeMixin._call_node_method_bool(settings, "set_sound_volume", [1.5])
    assert_eq(TypeSafeMixin._safe_cast_float(TypeSafeMixin._call_node_method(settings, "get_sound_volume")), 1.0,
        "Should clamp sound volume to maximum")
    TypeSafeMixin._call_node_method_bool(settings, "set_music_volume", [-0.5])
    assert_eq(TypeSafeMixin._safe_cast_float(TypeSafeMixin._call_node_method(settings, "get_music_volume")), 0.0,
        "Should clamp music volume to minimum")

func test_serialization() -> void:
    # Modify settings
    TypeSafeMixin._call_node_method_bool(settings, "set_difficulty", [GameEnums.DifficultyLevel.HARD])
    TypeSafeMixin._call_node_method_bool(settings, "set_campaign_type", [GameEnums.FiveParcsecsCampaignType.STORY])
    TypeSafeMixin._call_node_method_bool(settings, "set_victory_condition", [GameEnums.FiveParcsecsCampaignVictoryType.STORY_COMPLETE])
    TypeSafeMixin._call_node_method_bool(settings, "set_tutorial_enabled", [false])
    TypeSafeMixin._call_node_method_bool(settings, "set_auto_save_enabled", [false])
    TypeSafeMixin._call_node_method_bool(settings, "set_auto_save_frequency", [30])
    TypeSafeMixin._call_node_method_bool(settings, "set_sound_enabled", [false])
    TypeSafeMixin._call_node_method_bool(settings, "set_sound_volume", [0.5])
    TypeSafeMixin._call_node_method_bool(settings, "set_music_enabled", [false])
    TypeSafeMixin._call_node_method_bool(settings, "set_music_volume", [0.7])
    
    # Serialize and deserialize
    var data: Dictionary = TypeSafeMixin._call_node_method_dict(settings, "serialize", [], {})
    var new_settings := TypeSafeMixin._safe_cast_to_object(TypeSafeMixin._call_node_method(GameSettings, "deserialize_new", [data]), "") as GameSettings
    track_test_resource(new_settings)
    
    # Verify settings
    assert_eq(TypeSafeMixin._call_node_method_int(new_settings, "get_difficulty_level"),
        TypeSafeMixin._call_node_method_int(settings, "get_difficulty_level"),
        "Should preserve difficulty level")
    assert_eq(TypeSafeMixin._call_node_method_int(new_settings, "get_campaign_type"),
        TypeSafeMixin._call_node_method_int(settings, "get_campaign_type"),
        "Should preserve campaign type")
    assert_eq(TypeSafeMixin._call_node_method_int(new_settings, "get_victory_condition"),
        TypeSafeMixin._call_node_method_int(settings, "get_victory_condition"),
        "Should preserve victory condition")
    assert_eq(TypeSafeMixin._call_node_method_bool(new_settings, "get_tutorial_enabled"),
        TypeSafeMixin._call_node_method_bool(settings, "get_tutorial_enabled"),
        "Should preserve tutorial setting")
    assert_eq(TypeSafeMixin._call_node_method_bool(new_settings, "get_auto_save_enabled"),
        TypeSafeMixin._call_node_method_bool(settings, "get_auto_save_enabled"),
        "Should preserve auto-save setting")
    assert_eq(TypeSafeMixin._call_node_method_int(new_settings, "get_auto_save_frequency"),
        TypeSafeMixin._call_node_method_int(settings, "get_auto_save_frequency"),
        "Should preserve auto-save frequency")
    assert_eq(TypeSafeMixin._call_node_method_bool(new_settings, "get_sound_enabled"),
        TypeSafeMixin._call_node_method_bool(settings, "get_sound_enabled"),
        "Should preserve sound setting")
    assert_eq(TypeSafeMixin._safe_cast_float(TypeSafeMixin._call_node_method(new_settings, "get_sound_volume")),
        TypeSafeMixin._safe_cast_float(TypeSafeMixin._call_node_method(settings, "get_sound_volume")),
        "Should preserve sound volume")
    assert_eq(TypeSafeMixin._call_node_method_bool(new_settings, "get_music_enabled"),
        TypeSafeMixin._call_node_method_bool(settings, "get_music_enabled"),
        "Should preserve music setting")
    assert_eq(TypeSafeMixin._safe_cast_float(TypeSafeMixin._call_node_method(new_settings, "get_music_volume")),
        TypeSafeMixin._safe_cast_float(TypeSafeMixin._call_node_method(settings, "get_music_volume")),
        "Should preserve music volume")