@tool
extends "res://tests/fixtures/game_test.gd"

const GameplayOptionsMenu = preload("res://src/ui/screens/gameplay_options_menu.gd")

var options_menu: GameplayOptionsMenu
var mock_game_state: GameState

func before_each() -> void:
    mock_game_state = GameState.new()
    add_child(mock_game_state)
    
    options_menu = GameplayOptionsMenu.new()
    add_child(options_menu)
    await options_menu.ready

func after_each() -> void:
    options_menu.queue_free()
    mock_game_state.queue_free()

# Basic State Tests
func test_initial_state() -> void:
    assert_not_null(options_menu, "GameplayOptionsMenu should be initialized")
    assert_false(options_menu.is_modified, "Options should not start as modified")

# Settings Tests
func test_difficulty_setting() -> void:
    watch_signals(options_menu)
    
    options_menu.difficulty_option.selected = GameEnums.DifficultyLevel.HARD
    options_menu._on_difficulty_changed(GameEnums.DifficultyLevel.HARD)
    
    assert_true(options_menu.is_modified,
        "Options should be marked as modified after change")
    assert_eq(options_menu.current_settings.difficulty, GameEnums.DifficultyLevel.HARD,
        "Should store selected difficulty")

# UI Interaction Tests
func test_apply_settings() -> void:
    watch_signals(options_menu)
    
    # Change multiple settings
    options_menu.difficulty_option.selected = GameEnums.DifficultyLevel.HARD
    options_menu.enable_tutorials_check.button_pressed = false
    options_menu._on_settings_changed()
    
    options_menu._on_apply_pressed()
    
    assert_signal_emitted(options_menu, "settings_applied")
    assert_false(options_menu.is_modified,
        "Options should not be marked as modified after applying")

# Reset Tests
func test_reset_settings() -> void:
    # Change settings first
    options_menu.difficulty_option.selected = GameEnums.DifficultyLevel.HARD
    options_menu.enable_tutorials_check.button_pressed = false
    options_menu._on_settings_changed()
    
    options_menu._on_reset_pressed()
    
    assert_eq(options_menu.difficulty_option.selected, GameEnums.DifficultyLevel.NORMAL,
        "Should reset difficulty to normal")
    assert_true(options_menu.enable_tutorials_check.button_pressed,
        "Should reset tutorials to enabled")
    assert_false(options_menu.is_modified,
        "Options should not be marked as modified after reset")

# Navigation Tests
func test_navigation() -> void:
    watch_signals(get_tree())
    
    options_menu._on_back_pressed()
    assert_signal_emitted(get_tree(), "change_scene_to_file")

# Save/Load Tests
func test_save_load_settings() -> void:
    # Change and save settings
    options_menu.difficulty_option.selected = GameEnums.DifficultyLevel.HARD
    options_menu.enable_tutorials_check.button_pressed = false
    options_menu._on_settings_changed()
    options_menu._save_settings()
    
    # Create new menu instance
    var new_menu = GameplayOptionsMenu.new()
    add_child(new_menu)
    await new_menu.ready
    
    assert_eq(new_menu.difficulty_option.selected, GameEnums.DifficultyLevel.HARD,
        "Should load saved difficulty setting")
    assert_false(new_menu.enable_tutorials_check.button_pressed,
        "Should load saved tutorial setting")
    
    new_menu.queue_free()

# Performance Tests
func test_rapid_setting_changes() -> void:
    var start_time := Time.get_ticks_msec()
    
    for i in range(100):
        options_menu.difficulty_option.selected = i % GameEnums.DifficultyLevel.size()
        options_menu._on_settings_changed()
    
    var duration := Time.get_ticks_msec() - start_time
    assert_true(duration < 1000,
        "Should handle rapid setting changes efficiently")

# Error Cases Tests
func test_invalid_settings() -> void:
    # Test invalid difficulty level
    options_menu.difficulty_option.selected = -1
    options_menu._on_settings_changed()
    
    assert_eq(options_menu.current_settings.difficulty, GameEnums.DifficultyLevel.NORMAL,
        "Should default to normal difficulty for invalid value")

# Cleanup Tests
func test_cleanup() -> void:
    # Change settings
    options_menu.difficulty_option.selected = GameEnums.DifficultyLevel.HARD
    options_menu.enable_tutorials_check.button_pressed = false
    options_menu._on_settings_changed()
    
    options_menu.cleanup()
    
    assert_false(options_menu.is_modified,
        "Should reset modified flag on cleanup")
    assert_eq(options_menu.difficulty_option.selected, GameEnums.DifficultyLevel.NORMAL,
        "Should reset settings on cleanup")