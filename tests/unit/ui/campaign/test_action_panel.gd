## Action Panel Test Suite
## Tests the functionality of the campaign action panel UI component
@tool
extends GameTest

# Type-safe script references
const ActionPanel := preload("res://src/scenes/campaign/components/ActionPanel.gd")

# Type-safe instance variables
var _action_panel: Node = null

# Test Lifecycle Methods
func before_each() -> void:
	await super.before_each()
	
	# Initialize game state
	if not _game_state:
		push_error("Failed to create game state")
		return
	add_child_autofree(_game_state)
	track_test_node(_game_state)
	
	# Initialize action panel
	_action_panel = ActionPanel.new()
	if not _action_panel:
		push_error("Failed to create action panel")
		return
	TypeSafeMixin._safe_method_call_bool(_action_panel, "initialize", [_game_state])
	add_child_autofree(_action_panel)
	track_test_node(_action_panel)
	
	await stabilize_engine()

func after_each() -> void:
	_action_panel = null
	await super.after_each()

# Panel Initialization Tests
func test_panel_initialization() -> void:
	assert_not_null(_action_panel, "Action panel should be initialized")
	
	var is_visible: bool = TypeSafeMixin._safe_method_call_bool(_action_panel, "is_visible", [])
	assert_true(is_visible, "Panel should be visible after initialization")
	
	var actions: Array = TypeSafeMixin._safe_method_call_array(_action_panel, "get_available_actions", [])
	assert_true(actions.size() > 0, "Should have available actions")

# Action Button Tests
func test_action_buttons() -> void:
	watch_signals(_action_panel)
	
	# Test button creation
	var action_data := {
		"id": "test_action",
		"label": "Test Action",
		"enabled": true
	}
	
	var success: bool = TypeSafeMixin._safe_method_call_bool(_action_panel, "add_action_button", [action_data])
	assert_true(success, "Should add action button")
	verify_signal_emitted(_action_panel, "action_added")
	
	# Test button state
	var is_enabled: bool = TypeSafeMixin._safe_method_call_bool(_action_panel, "is_action_enabled", ["test_action"])
	assert_true(is_enabled, "Action should be enabled")

# Action Execution Tests
func test_action_execution() -> void:
	watch_signals(_action_panel)
	
	# Add test action
	var action_data := {
		"id": "test_action",
		"label": "Test Action",
		"enabled": true
	}
	TypeSafeMixin._safe_method_call_bool(_action_panel, "add_action_button", [action_data])
	
	# Execute action
	var success: bool = TypeSafeMixin._safe_method_call_bool(_action_panel, "execute_action", ["test_action"])
	assert_true(success, "Should execute action successfully")
	verify_signal_emitted(_action_panel, "action_executed")

# Action Group Tests
func test_action_groups() -> void:
	watch_signals(_action_panel)
	
	# Create action group
	var group_data := {
		"id": "test_group",
		"label": "Test Group",
		"actions": [
			{
				"id": "action1",
				"label": "Action 1",
				"enabled": true
			},
			{
				"id": "action2",
				"label": "Action 2",
				"enabled": true
			}
		]
	}
	
	var success: bool = TypeSafeMixin._safe_method_call_bool(_action_panel, "create_action_group", [group_data])
	assert_true(success, "Should create action group")
	verify_signal_emitted(_action_panel, "group_created")
	
	# Test group actions
	var group_actions: Array = TypeSafeMixin._safe_method_call_array(_action_panel, "get_group_actions", ["test_group"])
	assert_eq(group_actions.size(), 2, "Group should have two actions")

# Action State Tests
func test_action_states() -> void:
	watch_signals(_action_panel)
	
	# Add test action
	var action_data := {
		"id": "test_action",
		"label": "Test Action",
		"enabled": true
	}
	TypeSafeMixin._safe_method_call_bool(_action_panel, "add_action_button", [action_data])
	
	# Test enable/disable
	TypeSafeMixin._safe_method_call_bool(_action_panel, "set_action_enabled", ["test_action", false])
	var is_enabled: bool = TypeSafeMixin._safe_method_call_bool(_action_panel, "is_action_enabled", ["test_action"])
	assert_false(is_enabled, "Action should be disabled")
	verify_signal_emitted(_action_panel, "action_state_changed")

# Action Visibility Tests
func test_action_visibility() -> void:
	watch_signals(_action_panel)
	
	# Add test action
	var action_data := {
		"id": "test_action",
		"label": "Test Action",
		"enabled": true
	}
	TypeSafeMixin._safe_method_call_bool(_action_panel, "add_action_button", [action_data])
	
	# Test show/hide
	TypeSafeMixin._safe_method_call_bool(_action_panel, "set_action_visible", ["test_action", false])
	var is_visible: bool = TypeSafeMixin._safe_method_call_bool(_action_panel, "is_action_visible", ["test_action"])
	assert_false(is_visible, "Action should be hidden")
	verify_signal_emitted(_action_panel, "action_visibility_changed")

# Action Removal Tests
func test_action_removal() -> void:
	watch_signals(_action_panel)
	
	# Add test action
	var action_data := {
		"id": "test_action",
		"label": "Test Action",
		"enabled": true
	}
	TypeSafeMixin._safe_method_call_bool(_action_panel, "add_action_button", [action_data])
	
	# Remove action
	var success: bool = TypeSafeMixin._safe_method_call_bool(_action_panel, "remove_action", ["test_action"])
	assert_true(success, "Should remove action successfully")
	verify_signal_emitted(_action_panel, "action_removed")
	
	# Verify removal
	var actions: Array = TypeSafeMixin._safe_method_call_array(_action_panel, "get_available_actions", [])
	assert_false(actions.has("test_action"), "Action should be removed from available actions")

# Error Handling Tests
func test_error_handling() -> void:
	watch_signals(_action_panel)
	
	# Test invalid action execution
	var success: bool = TypeSafeMixin._safe_method_call_bool(_action_panel, "execute_action", ["invalid_action"])
	assert_false(success, "Should not execute invalid action")
	verify_signal_not_emitted(_action_panel, "action_executed")
	
	# Test invalid group creation
	success = TypeSafeMixin._safe_method_call_bool(_action_panel, "create_action_group", [null])
	assert_false(success, "Should not create invalid group")
	verify_signal_not_emitted(_action_panel, "group_created")

# Panel State Tests
func test_panel_state() -> void:
	watch_signals(_action_panel)
	
	# Test panel enable/disable
	TypeSafeMixin._safe_method_call_bool(_action_panel, "set_panel_enabled", [false])
	var is_enabled: bool = TypeSafeMixin._safe_method_call_bool(_action_panel, "is_panel_enabled", [])
	assert_false(is_enabled, "Panel should be disabled")
	verify_signal_emitted(_action_panel, "panel_state_changed")
	
	# Test panel visibility
	TypeSafeMixin._safe_method_call_bool(_action_panel, "set_panel_visible", [false])
	var is_visible: bool = TypeSafeMixin._safe_method_call_bool(_action_panel, "is_visible", [])
	assert_false(is_visible, "Panel should be hidden")
	verify_signal_emitted(_action_panel, "visibility_changed")
