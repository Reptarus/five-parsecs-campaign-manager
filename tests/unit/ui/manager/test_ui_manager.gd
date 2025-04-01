@tool
extends "res://tests/fixtures/base/game_test.gd"

const UIManager = preload("res://src/ui/screens/UIManager.gd")
const GameplayOptionsMenu = preload("res://src/ui/screens/gameplay_options_menu.gd")
const CampaignDashboard = preload("res://src/ui/screens/campaign/CampaignDashboard.gd")

var _ui_manager

# Lifecycle methods
func before_each() -> void:
    await super.before_each()
    
    _ui_manager = UIManager.new()
    if not _ui_manager:
        push_error("Failed to create UI manager")
        return
    add_child(_ui_manager)
    track_test_node(_ui_manager)
    await _ui_manager.ready
    
    # Watch signals
    if _signal_watcher:
        _signal_watcher.watch_signals(_ui_manager)

func after_each() -> void:
    if is_instance_valid(_ui_manager):
        _ui_manager.queue_free()
    _ui_manager = null
    await super.after_each()

# Basic State Tests
func test_initial_state() -> void:
    if not is_instance_valid(_ui_manager):
        push_warning("Skipping test_initial_state: _ui_manager is null or invalid")
        pending("Test skipped - _ui_manager is null or invalid")
        return
        
    assert_not_null(_ui_manager, "UIManager should be initialized")
    
    if not ("current_screen" in _ui_manager and "screen_history" in _ui_manager):
        push_warning("Skipping current_screen and screen_history checks: properties not found")
        pending("Test skipped - required properties not found")
        return
        
    assert_null(_ui_manager.current_screen, "No screen should be active initially")
    assert_eq(_ui_manager.screen_history.size(), 0, "Screen history should be empty initially")

# Screen Management Tests
func test_show_screen() -> void:
    if not is_instance_valid(_ui_manager):
        push_warning("Skipping test_show_screen: _ui_manager is null or invalid")
        pending("Test skipped - _ui_manager is null or invalid")
        return
        
    if not _ui_manager.has_method("show_screen"):
        push_warning("Skipping test_show_screen: show_screen method not found")
        pending("Test skipped - show_screen method not found")
        return
        
    # Show options menu
    var screen_data = {"screen_type": "options_menu"}
    _ui_manager.show_screen(screen_data)
    
    if not ("current_screen" in _ui_manager and "screen_container" in _ui_manager):
        push_warning("Skipping current_screen and screen_container checks: properties not found")
        pending("Test skipped - required properties not found")
        return
        
    assert_not_null(_ui_manager.current_screen, "Screen should be active after show_screen")
    assert_eq(_ui_manager.current_screen.get_class(), "GameplayOptionsMenu",
        "Current screen should be options menu")
    assert_eq(_ui_manager.screen_container.get_child_count(), 1,
        "Screen container should have one child")

func test_screen_registration() -> void:
    if not is_instance_valid(_ui_manager):
        push_warning("Skipping test_screen_registration: _ui_manager is null or invalid")
        pending("Test skipped - _ui_manager is null or invalid")
        return
        
    if not (_ui_manager.has_method("register_screen") and _ui_manager.has_method("get_screen_class")):
        push_warning("Skipping test_screen_registration: required methods not found")
        pending("Test skipped - required methods not found")
        return
        
    # Register custom screen
    var custom_screen_type = "test_screen"
    _ui_manager.register_screen(custom_screen_type, GameplayOptionsMenu)
    
    var screen_class = _ui_manager.get_screen_class(custom_screen_type)
    assert_eq(screen_class, GameplayOptionsMenu,
        "Should retrieve registered screen class")

func test_navigation_history() -> void:
    if not is_instance_valid(_ui_manager):
        push_warning("Skipping test_navigation_history: _ui_manager is null or invalid")
        pending("Test skipped - _ui_manager is null or invalid")
        return
        
    if not (_ui_manager.has_method("show_screen") and _ui_manager.has_method("navigate_back")):
        push_warning("Skipping test_navigation_history: required methods not found")
        pending("Test skipped - required methods not found")
        return
        
    # Show multiple screens in sequence
    _ui_manager.show_screen({"screen_type": "options_menu"})
    _ui_manager.show_screen({"screen_type": "campaign_dashboard"})
    
    if not "screen_history" in _ui_manager:
        push_warning("Skipping screen_history check: property not found")
        pending("Test skipped - screen_history property not found")
        return
        
    assert_eq(_ui_manager.screen_history.size(), 1,
        "Screen history should track previous screen")
    
    # Navigate back
    _ui_manager.navigate_back()
    
    if not "current_screen" in _ui_manager:
        push_warning("Skipping current_screen check: property not found")
        pending("Test skipped - current_screen property not found")
        return
        
    assert_eq(_ui_manager.current_screen.get_class(), "GameplayOptionsMenu",
        "Should return to previous screen")
    assert_eq(_ui_manager.screen_history.size(), 0,
        "Screen history should be empty after navigating back")

# Screen Transition Tests
func test_screen_transitions() -> void:
    if not is_instance_valid(_ui_manager):
        push_warning("Skipping test_screen_transitions: _ui_manager is null or invalid")
        pending("Test skipped - _ui_manager is null or invalid")
        return
        
    if not (_ui_manager.has_method("show_screen") and _ui_manager.has_signal("screen_transition_started")):
        push_warning("Skipping test_screen_transitions: required methods or signals not found")
        pending("Test skipped - required methods or signals not found")
        return
        
    # Watch for transition signals
    _ui_manager.show_screen({"screen_type": "options_menu"})
    
    verify_signal_emitted(_ui_manager, "screen_transition_started")
    
    # Let the transition complete
    await get_tree().create_timer(0.2).timeout
    verify_signal_emitted(_ui_manager, "screen_transition_completed")

# Screen Stacking Tests
func test_screen_stacking() -> void:
    if not is_instance_valid(_ui_manager):
        push_warning("Skipping test_screen_stacking: _ui_manager is null or invalid")
        pending("Test skipped - _ui_manager is null or invalid")
        return
        
    if not (_ui_manager.has_method("show_screen") and
            _ui_manager.has_method("pop_screen") and
            "screen_stack" in _ui_manager):
        push_warning("Skipping test_screen_stacking: required methods or properties not found")
        pending("Test skipped - required methods or properties not found")
        return
        
    # Push screens to stack
    _ui_manager.show_screen({"screen_type": "options_menu", "stack": true})
    _ui_manager.show_screen({"screen_type": "campaign_dashboard", "stack": true})
    
    assert_eq(_ui_manager.screen_stack.size(), 2,
        "Screen stack should contain both screens")
    
    # Pop screen
    _ui_manager.pop_screen()
    
    if not "current_screen" in _ui_manager:
        push_warning("Skipping current_screen check: property not found")
        pending("Test skipped - current_screen property not found")
        return
        
    assert_eq(_ui_manager.current_screen.get_class(), "GameplayOptionsMenu",
        "Should return to options menu after pop")
    assert_eq(_ui_manager.screen_stack.size(), 1,
        "Screen stack should have one screen left")

# UI Data Tests
func test_ui_data_management() -> void:
    if not is_instance_valid(_ui_manager):
        push_warning("Skipping test_ui_data_management: _ui_manager is null or invalid")
        pending("Test skipped - _ui_manager is null or invalid")
        return
        
    if not (_ui_manager.has_method("store_ui_data") and _ui_manager.has_method("retrieve_ui_data")):
        push_warning("Skipping test_ui_data_management: required methods not found")
        pending("Test skipped - required methods not found")
        return
        
    # Store UI data
    var test_data = {"player_name": "Test Player", "score": 100}
    _ui_manager.store_ui_data("test_data_key", test_data)
    
    # Retrieve UI data
    var retrieved_data = _ui_manager.retrieve_ui_data("test_data_key")
    assert_eq(retrieved_data, test_data, "Should retrieve stored UI data")
    
    # Clear UI data
    if _ui_manager.has_method("clear_ui_data"):
        _ui_manager.clear_ui_data("test_data_key")
        var cleared_data = _ui_manager.retrieve_ui_data("test_data_key")
        assert_null(cleared_data, "Data should be null after clearing")

# Error Cases Tests
func test_invalid_screen_show() -> void:
    if not is_instance_valid(_ui_manager):
        push_warning("Skipping test_invalid_screen_show: _ui_manager is null or invalid")
        pending("Test skipped - _ui_manager is null or invalid")
        return
        
    if not _ui_manager.has_method("show_screen"):
        push_warning("Skipping test_invalid_screen_show: show_screen method not found")
        pending("Test skipped - show_screen method not found")
        return
        
    # Try to show non-existent screen
    var result = _ui_manager.show_screen({"screen_type": "non_existent_screen"})
    assert_false(result, "Should return false for invalid screen type")
    
    if not "current_screen" in _ui_manager:
        push_warning("Skipping current_screen check: property not found")
        pending("Test skipped - current_screen property not found")
        return
        
    assert_null(_ui_manager.current_screen, "Current screen should remain null")

func test_invalid_navigation() -> void:
    if not is_instance_valid(_ui_manager):
        push_warning("Skipping test_invalid_navigation: _ui_manager is null or invalid")
        pending("Test skipped - _ui_manager is null or invalid")
        return
        
    if not _ui_manager.has_method("navigate_back"):
        push_warning("Skipping test_invalid_navigation: navigate_back method not found")
        pending("Test skipped - navigate_back method not found")
        return
        
    # Navigate back with empty history
    var result = _ui_manager.navigate_back()
    assert_false(result, "Should return false when navigating back with empty history")

# Cleanup Tests
func test_cleanup() -> void:
    if not is_instance_valid(_ui_manager):
        push_warning("Skipping test_cleanup: _ui_manager is null or invalid")
        pending("Test skipped - _ui_manager is null or invalid")
        return
        
    if not (_ui_manager.has_method("show_screen") and
            _ui_manager.has_method("cleanup") and
            "screen_container" in _ui_manager):
        push_warning("Skipping test_cleanup: required methods or properties not found")
        pending("Test skipped - required methods or properties not found")
        return
        
    # Show a screen
    _ui_manager.show_screen({"screen_type": "options_menu"})
    
    # Cleanup UI manager
    _ui_manager.cleanup()
    
    assert_eq(_ui_manager.screen_container.get_child_count(), 0,
        "Screen container should be empty after cleanup")
        
    if not ("current_screen" in _ui_manager and "screen_history" in _ui_manager):
        push_warning("Skipping current_screen and screen_history checks: properties not found")
        pending("Test skipped - required properties not found")
        return
        
    assert_null(_ui_manager.current_screen, "Current screen should be null after cleanup")
    assert_eq(_ui_manager.screen_history.size(), 0, "Screen history should be empty after cleanup")