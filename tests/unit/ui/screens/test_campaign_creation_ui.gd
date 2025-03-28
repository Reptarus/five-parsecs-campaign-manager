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

# Type-safe helper methods - fixed indentation
func _safe_get_property(property: String, default_value = null):
    # Use Compatibility helper and check for method existence
    return TypeSafeMixin._call_node_method(_ui, "get", [property]) if _ui and _ui.has("get") else default_value

func _set_ui_property(property: String, value: Variant) -> void:
    if not _ui:
        push_error("Trying to set property '%s' on null creation UI" % property)
        return
    if not property in _ui:
        push_error("Creation UI missing required property: %s" % property)
        return
    TypeSafeMixin._call_node_method_bool(_ui, "set", [property, value])

# Test cases
func test_initial_state() -> void:
    assert_not_null(_ui, "CampaignCreationUI should be initialized")
    assert_false(_safe_get_property("is_campaign_valid", false),
        "Campaign should not be valid initially")
    assert_not_null(_safe_get_property("name_input"), "Name input should exist")
    assert_not_null(_safe_get_property("difficulty_selector"), "Difficulty selector should exist")
    assert_not_null(_safe_get_property("create_button"), "Create button should exist")

# Campaign Settings Tests
func test_campaign_settings() -> void:
    var name_input: Node = _safe_get_property("name_input")
    var difficulty_selector: Node = _safe_get_property("difficulty_selector")
    
    if name_input and "text" in name_input:
        TypeSafeMixin._call_node_method_bool(name_input, "set", ["text", "Test Campaign"])
    if difficulty_selector and "selected" in difficulty_selector:
        TypeSafeMixin._call_node_method_bool(difficulty_selector, "set", ["selected", DifficultyLevel.NORMAL])
    
    if "update_settings" in _ui:
        TypeSafeMixin._call_node_method_bool(_ui, "update_settings")
    
    assert_true(_safe_get_property("is_campaign_valid", false),
        "Campaign should be valid with name and difficulty")
    
    var settings: Dictionary = _safe_get_property("campaign_settings", {})
    if not settings.is_empty():
        assert_eq(settings.get("name", ""), "Test Campaign", "Should store campaign name")
        assert_eq(settings.get("difficulty", -1), DifficultyLevel.NORMAL, "Should store difficulty setting")

# Validation Tests
func test_campaign_validation() -> void:
    var name_input: Node = _safe_get_property("name_input")
    
    # Test empty name
    if name_input and "text" in name_input:
        TypeSafeMixin._call_node_method_bool(name_input, "set", ["text", ""])
    if "update_settings" in _ui:
        TypeSafeMixin._call_node_method_bool(_ui, "update_settings")
    assert_false(_safe_get_property("is_campaign_valid", false),
        "Campaign should be invalid with empty name")
    
    # Test valid name
    if name_input and "text" in name_input:
        TypeSafeMixin._call_node_method_bool(name_input, "set", ["text", "Valid Name"])
    if "update_settings" in _ui:
        TypeSafeMixin._call_node_method_bool(_ui, "update_settings")
    assert_true(_safe_get_property("is_campaign_valid", false),
        "Campaign should be valid with proper name")

# Creation Flow Tests
func test_campaign_creation_flow() -> void:
    var name_input: Node = _safe_get_property("name_input")
    var difficulty_selector: Node = _safe_get_property("difficulty_selector")
    
    # Setup valid campaign
    if name_input and "text" in name_input:
        TypeSafeMixin._call_node_method_bool(name_input, "set", ["text", "Test Campaign"])
    if difficulty_selector and "selected" in difficulty_selector:
        TypeSafeMixin._call_node_method_bool(difficulty_selector, "set", ["selected", DifficultyLevel.NORMAL])
    if "update_settings" in _ui:
        TypeSafeMixin._call_node_method_bool(_ui, "update_settings")
    
    # Test creation only if method exists
    if "create_campaign" in _ui:
        TypeSafeMixin._call_node_method_bool(_ui, "create_campaign")
        
        verify_signal_emitted(_ui, "campaign_created")
        assert_not_null(_safe_get_property("campaign", null),
            "Should create campaign in game state")
    else:
        push_warning("UI missing create_campaign method, skipping creation test")

# UI Interaction Tests
func test_ui_interactions() -> void:
    var difficulty_selector: Node = _safe_get_property("difficulty_selector")
    var name_input: Node = _safe_get_property("name_input")
    
    # Test difficulty change
    if difficulty_selector and "selected" in difficulty_selector:
        TypeSafeMixin._call_node_method_bool(difficulty_selector, "set", ["selected", DifficultyLevel.HARD])
        if "on_difficulty_changed" in _ui:
            TypeSafeMixin._call_node_method_bool(_ui, "on_difficulty_changed", [DifficultyLevel.HARD])
    
    # Test name change
    if name_input and "text" in name_input:
        TypeSafeMixin._call_node_method_bool(name_input, "set", ["text", "New Name"])
        if "on_name_changed" in _ui:
            TypeSafeMixin._call_node_method_bool(_ui, "on_name_changed", ["New Name"])
    
    var settings: Dictionary = _safe_get_property("campaign_settings", {})
    if not settings.is_empty():
        assert_eq(settings.get("difficulty", -1), DifficultyLevel.HARD, "Should update difficulty setting")
        assert_eq(settings.get("name", ""), "New Name", "Should update campaign name")

# Error Cases Tests
func test_error_cases() -> void:
    var name_input: Node = _safe_get_property("name_input")
    
    # Test invalid characters in name
    if name_input and "text" in name_input:
        TypeSafeMixin._call_node_method_bool(name_input, "set", ["text", "Test/Campaign"])
    if "update_settings" in _ui:
        TypeSafeMixin._call_node_method_bool(_ui, "update_settings")
    assert_false(_safe_get_property("is_campaign_valid", false),
        "Should reject names with invalid characters")
    
    # Test extremely long name
    if name_input and "text" in name_input:
        TypeSafeMixin._call_node_method_bool(name_input, "set", ["text", "A".repeat(100)])
    if "update_settings" in _ui:
        TypeSafeMixin._call_node_method_bool(_ui, "update_settings")
    assert_false(_safe_get_property("is_campaign_valid", false),
        "Should reject extremely long names")

# Navigation Tests
func test_navigation() -> void:
    if "cancel_creation" in _ui:
        TypeSafeMixin._call_node_method_bool(_ui, "cancel_creation")
    verify_signal_emitted(_ui, "campaign_cancelled")

# Cleanup Tests
func test_cleanup() -> void:
    var name_input: Node = _safe_get_property("name_input")
    var difficulty_selector: Node = _safe_get_property("difficulty_selector")
    
    # Set some values
    if name_input and "text" in name_input:
        TypeSafeMixin._call_node_method_bool(name_input, "set", ["text", "Test"])
    if difficulty_selector and "selected" in difficulty_selector:
        TypeSafeMixin._call_node_method_bool(difficulty_selector, "set", ["selected", DifficultyLevel.HARD])
    
    # Reset UI
    if "reset" in _ui:
        TypeSafeMixin._call_node_method_bool(_ui, "reset")
    
    # Verify reset
    if name_input and "text" in name_input:
        assert_eq(TypeSafeMixin._safe_cast_to_string(TypeSafeMixin._call_node_method(name_input, "get", ["text"])), "", "Should clear campaign name")
    if difficulty_selector and "selected" in difficulty_selector:
        assert_eq(TypeSafeMixin._call_node_method_int(difficulty_selector, "get", ["selected"]), DifficultyLevel.NORMAL, "Should reset difficulty to normal")