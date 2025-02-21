@tool
extends "res://tests/fixtures/game_test.gd"

const CampaignCreationUI: GDScript = preload("res://src/ui/screens/campaign/CampaignCreationUI.gd")
const GameEnums: GDScript = preload("res://src/core/systems/GlobalEnums.gd")

var creation_ui: CampaignCreationUI = null
var mock_game_state: Node = null

## Safe Property Access Methods
func _get_ui_property(property: String, default_value: Variant = null) -> Variant:
    if not creation_ui:
        push_error("Trying to access property '%s' on null creation UI" % property)
        return default_value
    if not property in creation_ui:
        push_error("Creation UI missing required property: %s" % property)
        return default_value
    return creation_ui.get(property)

func _set_ui_property(property: String, value: Variant) -> void:
    if not creation_ui:
        push_error("Trying to set property '%s' on null creation UI" % property)
        return
    if not property in creation_ui:
        push_error("Creation UI missing required property: %s" % property)
        return
    creation_ui.set(property, value)

func before_each() -> void:
    await super.before_each()
    
    mock_game_state = GameState.new()
    if not mock_game_state:
        push_error("Failed to create mock game state")
        return
    add_child(mock_game_state)
    track_test_node(mock_game_state)
    
    creation_ui = CampaignCreationUI.new()
    if not creation_ui:
        push_error("Failed to create campaign creation UI")
        return
    add_child(creation_ui)
    track_test_node(creation_ui)
    await creation_ui.ready
    
    # Watch for signals
    watch_signals(creation_ui)

func after_each() -> void:
    if is_instance_valid(creation_ui):
        creation_ui.queue_free()
    if is_instance_valid(mock_game_state):
        mock_game_state.queue_free()
    creation_ui = null
    mock_game_state = null
    await super.after_each()

# Basic State Tests
func test_initial_state() -> void:
    assert_not_null(creation_ui, "CampaignCreationUI should be initialized")
    assert_false(_get_ui_property("is_campaign_valid", false),
        "Campaign should not be valid initially")
    assert_not_null(_get_ui_property("name_input"), "Name input should exist")
    assert_not_null(_get_ui_property("difficulty_selector"), "Difficulty selector should exist")
    assert_not_null(_get_ui_property("create_button"), "Create button should exist")

# Campaign Settings Tests
func test_campaign_settings() -> void:
    var name_input: Node = _get_ui_property("name_input")
    var difficulty_selector: Node = _get_ui_property("difficulty_selector")
    
    if name_input and "text" in name_input:
        _set_property_safe(name_input, "text", "Test Campaign")
    if difficulty_selector and "selected" in difficulty_selector:
        _set_property_safe(difficulty_selector, "selected", GameEnums.DifficultyLevel.NORMAL)
    
    if "update_settings" in creation_ui:
        _call_node_method(creation_ui, "update_settings")
    
    assert_true(_get_ui_property("is_campaign_valid", false),
        "Campaign should be valid with name and difficulty")
    
    var settings: Dictionary = _get_ui_property("campaign_settings", {})
    if not settings.is_empty():
        assert_eq(settings.get("name", ""), "Test Campaign", "Should store campaign name")
        assert_eq(settings.get("difficulty", -1), GameEnums.DifficultyLevel.NORMAL, "Should store difficulty setting")

# Validation Tests
func test_campaign_validation() -> void:
    var name_input: Node = _get_ui_property("name_input")
    
    # Test empty name
    if name_input and "text" in name_input:
        _set_property_safe(name_input, "text", "")
    if "update_settings" in creation_ui:
        _call_node_method(creation_ui, "update_settings")
    assert_false(_get_ui_property("is_campaign_valid", false),
        "Campaign should be invalid with empty name")
    
    # Test valid name
    if name_input and "text" in name_input:
        _set_property_safe(name_input, "text", "Valid Name")
    if "update_settings" in creation_ui:
        _call_node_method(creation_ui, "update_settings")
    assert_true(_get_ui_property("is_campaign_valid", false),
        "Campaign should be valid with proper name")

# Creation Flow Tests
func test_campaign_creation_flow() -> void:
    var name_input: Node = _get_ui_property("name_input")
    var difficulty_selector: Node = _get_ui_property("difficulty_selector")
    
    # Setup valid campaign
    if name_input and "text" in name_input:
        _set_property_safe(name_input, "text", "Test Campaign")
    if difficulty_selector and "selected" in difficulty_selector:
        _set_property_safe(difficulty_selector, "selected", GameEnums.DifficultyLevel.NORMAL)
    if "update_settings" in creation_ui:
        _call_node_method(creation_ui, "update_settings")
    
    # Test creation
    if "create_campaign" in creation_ui:
        _call_node_method(creation_ui, "create_campaign")
    
    verify_signal_emitted(creation_ui, "campaign_created")
    assert_not_null(_get_ui_property("campaign", null),
        "Should create campaign in game state")

# UI Interaction Tests
func test_ui_interactions() -> void:
    var difficulty_selector: Node = _get_ui_property("difficulty_selector")
    var name_input: Node = _get_ui_property("name_input")
    
    # Test difficulty change
    if difficulty_selector and "selected" in difficulty_selector:
        _set_property_safe(difficulty_selector, "selected", GameEnums.DifficultyLevel.HARD)
        if "on_difficulty_changed" in creation_ui:
            _call_node_method(creation_ui, "on_difficulty_changed", [GameEnums.DifficultyLevel.HARD])
    
    # Test name change
    if name_input and "text" in name_input:
        _set_property_safe(name_input, "text", "New Name")
        if "on_name_changed" in creation_ui:
            _call_node_method(creation_ui, "on_name_changed", ["New Name"])
    
    var settings: Dictionary = _get_ui_property("campaign_settings", {})
    if not settings.is_empty():
        assert_eq(settings.get("difficulty", -1), GameEnums.DifficultyLevel.HARD, "Should update difficulty setting")
        assert_eq(settings.get("name", ""), "New Name", "Should update campaign name")

# Error Cases Tests
func test_error_cases() -> void:
    var name_input: Node = _get_ui_property("name_input")
    
    # Test invalid characters in name
    if name_input and "text" in name_input:
        _set_property_safe(name_input, "text", "Test/Campaign")
    if "update_settings" in creation_ui:
        _call_node_method(creation_ui, "update_settings")
    assert_false(_get_ui_property("is_campaign_valid", false),
        "Should reject names with invalid characters")
    
    # Test extremely long name
    if name_input and "text" in name_input:
        _set_property_safe(name_input, "text", "A".repeat(100))
    if "update_settings" in creation_ui:
        _call_node_method(creation_ui, "update_settings")
    assert_false(_get_ui_property("is_campaign_valid", false),
        "Should reject extremely long names")

# Navigation Tests
func test_navigation() -> void:
    if "cancel_creation" in creation_ui:
        _call_node_method(creation_ui, "cancel_creation")
    verify_signal_emitted(creation_ui, "campaign_cancelled")

# Cleanup Tests
func test_cleanup() -> void:
    var name_input: Node = _get_ui_property("name_input")
    var difficulty_selector: Node = _get_ui_property("difficulty_selector")
    
    # Set some values
    if name_input and "text" in name_input:
        _set_property_safe(name_input, "text", "Test")
    if difficulty_selector and "selected" in difficulty_selector:
        _set_property_safe(difficulty_selector, "selected", GameEnums.DifficultyLevel.HARD)
    
    # Reset UI
    if "reset" in creation_ui:
        _call_node_method(creation_ui, "reset")
    
    # Verify reset
    if name_input and "text" in name_input:
        assert_eq(_get_property_safe(name_input, "text", ""), "", "Should clear campaign name")
    if difficulty_selector and "selected" in difficulty_selector:
        assert_eq(_get_property_safe(difficulty_selector, "selected", -1), GameEnums.DifficultyLevel.NORMAL,
            "Should reset difficulty to normal")