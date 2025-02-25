@tool
extends "res://tests/fixtures/base/game_test.gd"

const GameplayOptionsMenu: GDScript = preload("res://src/ui/screens/gameplay_options_menu.gd")
const GameState: GDScript = preload("res://src/core/state/GameState.gd")

# Type-safe instance variables
var _options_menu: GameplayOptionsMenu
var mock_game_state: GameState

# Type-safe lifecycle methods
func before_each() -> void:
    await super.before_each()
    
    mock_game_state = GameState.new()
    add_child(mock_game_state)
    
    _options_menu = GameplayOptionsMenu.new()
    if not _options_menu:
        push_error("Failed to create gameplay options menu")
        return
    add_child(_options_menu)
    track_test_node(_options_menu)
    await _options_menu.ready
    
    # Watch for signals
    if _signal_watcher:
        _signal_watcher.watch_signals(_options_menu)

func after_each() -> void:
    if is_instance_valid(_options_menu):
        _options_menu.queue_free()
    _options_menu = null
    mock_game_state.queue_free()
    await super.after_each()

# Basic State Tests
func test_initial_state() -> void:
    assert_not_null(_options_menu, "GameplayOptionsMenu should be initialized")
    assert_false(_options_menu.is_modified, "Options should not start as modified")

# Settings Tests
func test_difficulty_setting() -> void:
    _options_menu.difficulty_option.selected = GameEnums.DifficultyLevel.HARD
    _options_menu._on_difficulty_changed(GameEnums.DifficultyLevel.HARD)
    
    assert_true(_options_menu.is_modified,
        "Options should be marked as modified after change")
    assert_eq(_options_menu.current_settings.difficulty, GameEnums.DifficultyLevel.HARD,
        "Should store selected difficulty")

# UI Interaction Tests
func test_apply_settings() -> void:
    # Change multiple settings
    _options_menu.difficulty_option.selected = GameEnums.DifficultyLevel.HARD
    _options_menu.enable_tutorials_check.button_pressed = false
    _options_menu._on_settings_changed()
    
    _options_menu._on_apply_pressed()
    
    verify_signal_emitted(_options_menu, "settings_applied")
    assert_false(_options_menu.is_modified,
        "Options should not be marked as modified after applying")

# Reset Tests
func test_reset_settings() -> void:
    # Change settings first
    _options_menu.difficulty_option.selected = GameEnums.DifficultyLevel.HARD
    _options_menu.enable_tutorials_check.button_pressed = false
    _options_menu._on_settings_changed()
    
    _options_menu._on_reset_pressed()
    
    assert_eq(_options_menu.difficulty_option.selected, GameEnums.DifficultyLevel.NORMAL,
        "Should reset difficulty to normal")
    assert_true(_options_menu.enable_tutorials_check.button_pressed,
        "Should reset tutorials to enabled")
    assert_false(_options_menu.is_modified,
        "Options should not be marked as modified after reset")

# Navigation Tests
func test_navigation() -> void:
    _options_menu._on_back_pressed()
    verify_signal_emitted(_options_menu, "back_pressed")

# Save/Load Tests
func test_save_load_settings() -> void:
    # Change and save settings
    _options_menu.difficulty_option.selected = GameEnums.DifficultyLevel.HARD
    _options_menu.enable_tutorials_check.button_pressed = false
    _options_menu._on_settings_changed()
    _options_menu._on_apply_pressed()
    
    # Load settings
    _options_menu._on_reset_pressed()
    _options_menu._on_load_settings()
    
    assert_eq(_options_menu.difficulty_option.selected, GameEnums.DifficultyLevel.HARD,
        "Should restore saved difficulty")
    assert_false(_options_menu.enable_tutorials_check.button_pressed,
        "Should restore saved tutorial setting")

# Performance Tests
func test_rapid_setting_changes() -> void:
    var start_time := Time.get_ticks_msec()
    
    for i in range(100):
        _options_menu.difficulty_option.selected = i % GameEnums.DifficultyLevel.size()
        _options_menu._on_settings_changed()
    
    var duration := Time.get_ticks_msec() - start_time
    assert_true(duration < 1000,
        "Should handle rapid setting changes efficiently")

# Error Cases Tests
func test_invalid_settings() -> void:
    # Test invalid difficulty level
    _options_menu.difficulty_option.selected = -1
    _options_menu._on_settings_changed()
    
    assert_eq(_options_menu.current_settings.difficulty, GameEnums.DifficultyLevel.NORMAL,
        "Should default to normal difficulty for invalid value")

# Cleanup Tests
func test_cleanup() -> void:
    # Change settings
    _options_menu.difficulty_option.selected = GameEnums.DifficultyLevel.HARD
    _options_menu.enable_tutorials_check.button_pressed = false
    _options_menu._on_settings_changed()
    
    _options_menu.cleanup()
    
    assert_false(_options_menu.is_modified,
        "Should reset modified flag on cleanup")
    assert_eq(_options_menu.difficulty_option.selected, GameEnums.DifficultyLevel.NORMAL,
        "Should reset settings on cleanup")