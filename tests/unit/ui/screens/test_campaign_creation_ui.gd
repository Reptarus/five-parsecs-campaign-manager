@tool
extends "res://tests/fixtures/specialized/ui_test.gd"

const CampaignCreationUI: GDScript = preload("res://src/ui/screens/campaign/CampaignCreationUI.gd")
const GameState: GDScript = preload("res://src/core/state/GameState.gd")
const Compatibility = preload("res://tests/fixtures/helpers/test_compatibility_helper.gd")

# Enum for difficulty levels
enum DifficultyLevel {EASY = 0, NORMAL = 1, HARD = 2}

# Type-safe instance variables
var _ui: CampaignCreationUI
var _mock_game_state: GameState

# Type-safe lifecycle methods
func before_each() -> void:
    await super.before_each()
    
    _mock_game_state = GameState.new()
    if not _mock_game_state:
        push_error("Failed to create mock game state")
        return
    add_child(_mock_game_state)
    track_test_node(_mock_game_state)
    
    _ui = CampaignCreationUI.new()
    if not _ui:
        push_error("Failed to create campaign creation UI")
        return
    add_child(_ui)
    track_test_node(_ui)
    await _ui.ready
    
    # Watch for signals
    if _signal_watcher:
        _signal_watcher.watch_signals(_ui)

func after_each() -> void:
    if is_instance_valid(_ui):
        _ui.queue_free()
    if is_instance_valid(_mock_game_state):
        _mock_game_state.queue_free()
    _ui = null
    _mock_game_state = null
    await super.after_each()

# Helper functions for signal verification
func verify_signal_emitted(emitter: Object, signal_name: String, message: String = "") -> void:
    assert_signal_emitted(emitter, signal_name, message if message else "Signal %s should have been emitted" % signal_name)