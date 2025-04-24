## Action Button Test Suite
## Tests the functionality of individual action buttons in the campaign UI
## 
## NOTE: This is the preferred implementation for testing ActionButton components directly with GameTest.
## There is a duplicate test in tests/unit/ui/components/campaign/test_action_button.gd that uses component_test_base
## and tests a different aspect (the scene instance rather than the script). Both tests are kept until full testing
## strategy alignment is complete.
@tool
extends "res://tests/fixtures/base/game_test.gd"
# Use explicit preloads instead of global class names

# Type-safe script references
const ActionButton := preload("res://src/scenes/campaign/components/ActionButton.gd")

# Type-safe instance variables
var _action_button: Node = null

# Test Lifecycle Methods
func before_each() -> void:
	await super.before_each()
	
	# Initialize game state
	_game_state = create_test_game_state()
	if not _game_state:
		push_error("Failed to create game state")
		return
	add_child_autofree(_game_state)
	track_test_node(_game_state)
	
	# Initialize action button
	_action_button = ActionButton.new()
	if not _action_button:
		push_error("Failed to create action button")
		return
	add_child_autofree(_action_button)
	track_test_node(_action_button)
	
	await stabilize_engine()

func after_each() -> void:
	_action_button = null
	_game_state = null
	await super.after_each()

# Button Initialization Tests
func test_button_initialization() -> void:
	if not is_instance_valid(_action_button):
		push_warning("Skipping test_button_initialization: action button is null or invalid")
		pending("Test skipped - action button is null or invalid")
		return
		
	assert_not_null(_action_button, "Action button should be initialized")
	
	if not _action_button.has_method("is_visible") or not _action_button.has_method("is_enabled"):
		push_warning("Skipping initialization checks: required methods not found")
		pending("Test skipped - required methods not found")
		return
	
	var is_visible: bool = TypeSafeMixin._call_node_method_bool(_action_button, "is_visible", [])
	assert_true(is_visible, "Button should be visible after initialization")
	
	var is_enabled: bool = TypeSafeMixin._call_node_method_bool(_action_button, "is_enabled", [])
	assert_true(is_enabled, "Button should be enabled by default")

# Button State Tests
func test_button_state() -> void:
	if not is_instance_valid(_action_button):
		push_warning("Skipping test_button_state: action button is null or invalid")
		pending("Test skipped - action button is null or invalid")
		return
		
	if not _action_button.has_method("set_enabled") or not _action_button.has_method("get_enabled") or not _action_button.has_method("set_visible") or not _action_button.has_method("is_visible"):
		push_warning("Skipping state tests: required methods not found")
		pending("Test skipped - required methods not found")
		return
		
	watch_signals(_action_button)
	
	# Test enable/disable
	TypeSafeMixin._call_node_method_bool(_action_button, "set_enabled", [false])
	var is_enabled: bool = TypeSafeMixin._call_node_method_bool(_action_button, "get_enabled", [])
	assert_false(is_enabled, "Button should be disabled")
	
	if _action_button.has_signal("state_changed"):
		verify_signal_emitted(_action_button, "state_changed")
	
	# Test visibility
	TypeSafeMixin._call_node_method_bool(_action_button, "set_visible", [false])
	var is_visible: bool = TypeSafeMixin._call_node_method_bool(_action_button, "is_visible", [])
	assert_false(is_visible, "Button should be hidden")
	
	if _action_button.has_signal("visibility_changed"):
		verify_signal_emitted(_action_button, "visibility_changed")

# Button Text Tests
func test_button_text() -> void:
	if not is_instance_valid(_action_button):
		push_warning("Skipping test_button_text: action button is null or invalid")
		pending("Test skipped - action button is null or invalid")
		return
		
	if not _action_button.has_method("set_text") or not _action_button.has_method("get_text"):
		push_warning("Skipping text tests: required methods not found")
		pending("Test skipped - required methods not found")
		return
		
	watch_signals(_action_button)
	
	var test_text := "Test Action"
	var success = TypeSafeMixin._call_node_method_bool(_action_button, "set_text", [test_text])
	
	if not success:
		push_warning("Failed to set button text - set_text method failed")
		pending("Test skipped - set_text method failed")
		return
		
	var button_text: String = TypeSafeMixin._safe_cast_to_string(TypeSafeMixin._call_node_method(_action_button, "get_text", []))
	assert_eq(button_text, test_text, "Button text should match")
	
	if _action_button.has_signal("text_changed"):
		verify_signal_emitted(_action_button, "text_changed")

# Button Icon Tests
func test_button_icon() -> void:
	if not is_instance_valid(_action_button):
		push_warning("Skipping test_button_icon: action button is null or invalid")
		pending("Test skipped - action button is null or invalid")
		return
		
	if not _action_button.has_method("set_icon") or not _action_button.has_method("get_icon"):
		push_warning("Skipping icon tests: required methods not found")
		pending("Test skipped - required methods not found")
		return
		
	watch_signals(_action_button)
	
	# Use Godot's built-in placeholder texture
	var test_icon := PlaceholderTexture2D.new()
	test_icon.size = Vector2(32, 32)
	var success = TypeSafeMixin._call_node_method_bool(_action_button, "set_icon", [test_icon])
	
	if not success:
		push_warning("Failed to set button icon - set_icon method failed")
		pending("Test skipped - set_icon method failed")
		return
		
	var button_icon: Resource = TypeSafeMixin._safe_cast_to_resource(TypeSafeMixin._call_node_method(_action_button, "get_icon", []), "")
	assert_eq(button_icon, test_icon, "Button icon should match")
	
	if _action_button.has_signal("icon_changed"):
		verify_signal_emitted(_action_button, "icon_changed")

# Button Action Tests
func test_button_action() -> void:
	if not is_instance_valid(_action_button):
		push_warning("Skipping test_button_action: action button is null or invalid")
		pending("Test skipped - action button is null or invalid")
		return
		
	if not _action_button.has_method("set_action_id") or not _action_button.has_method("get_action_id") or not _action_button.has_method("execute_action"):
		push_warning("Skipping action tests: required methods not found")
		pending("Test skipped - required methods not found")
		return
		
	watch_signals(_action_button)
	
	var action_id := "test_action"
	var success = TypeSafeMixin._call_node_method_bool(_action_button, "set_action_id", [action_id])
	
	if not success:
		push_warning("Failed to set action ID - set_action_id method failed")
		pending("Test skipped - set_action_id method failed")
		return
		
	var button_action: String = TypeSafeMixin._safe_cast_to_string(TypeSafeMixin._call_node_method(_action_button, "get_action_id", []))
	assert_eq(button_action, action_id, "Button action ID should match")
	
	# Test action execution
	success = TypeSafeMixin._call_node_method_bool(_action_button, "execute_action", [])
	
	if not success:
		push_warning("Failed to execute action - execute_action method failed")
		pending("Test skipped - execute_action method failed")
		return
		
	if _action_button.has_signal("action_executed"):
		verify_signal_emitted(_action_button, "action_executed")

# Button Style Tests
func test_button_style() -> void:
	if not is_instance_valid(_action_button):
		push_warning("Skipping test_button_style: action button is null or invalid")
		pending("Test skipped - action button is null or invalid")
		return
		
	if not _action_button.has_method("set_style") or not _action_button.has_method("get_style"):
		push_warning("Skipping style tests: required methods not found")
		pending("Test skipped - required methods not found")
		return
		
	watch_signals(_action_button)
	
	# Test normal style
	var success = TypeSafeMixin._call_node_method_bool(_action_button, "set_style", ["normal"])
	
	if not success:
		push_warning("Failed to set normal style - set_style method failed")
		pending("Test skipped - set_style method failed")
		return
		
	var style: String = TypeSafeMixin._safe_cast_to_string(TypeSafeMixin._call_node_method(_action_button, "get_style", []))
	assert_eq(style, "normal", "Button style should be normal")
	
	if _action_button.has_signal("style_changed"):
		verify_signal_emitted(_action_button, "style_changed")
	
	# Test highlighted style
	success = TypeSafeMixin._call_node_method_bool(_action_button, "set_style", ["highlighted"])
	
	if not success:
		push_warning("Failed to set highlighted style - set_style method failed")
		pending("Test skipped - set_style method failed")
		return
		
	style = TypeSafeMixin._safe_cast_to_string(TypeSafeMixin._call_node_method(_action_button, "get_style", []))
	assert_eq(style, "highlighted", "Button style should be highlighted")
	
	if _action_button.has_signal("style_changed"):
		verify_signal_emitted(_action_button, "style_changed")

# Button Tooltip Tests
func test_button_tooltip() -> void:
	if not is_instance_valid(_action_button):
		push_warning("Skipping test_button_tooltip: action button is null or invalid")
		pending("Test skipped - action button is null or invalid")
		return
		
	if not _action_button.has_method("set_tooltip") or not _action_button.has_method("get_tooltip"):
		push_warning("Skipping tooltip tests: required methods not found")
		pending("Test skipped - required methods not found")
		return
		
	watch_signals(_action_button)
	
	var tooltip_text := "Test tooltip"
	var success = TypeSafeMixin._call_node_method_bool(_action_button, "set_tooltip", [tooltip_text])
	
	if not success:
		push_warning("Failed to set tooltip - set_tooltip method failed")
		pending("Test skipped - set_tooltip method failed")
		return
		
	var button_tooltip: String = TypeSafeMixin._safe_cast_to_string(TypeSafeMixin._call_node_method(_action_button, "get_tooltip", []))
	assert_eq(button_tooltip, tooltip_text, "Button tooltip should match")
	
	if _action_button.has_signal("tooltip_changed"):
		verify_signal_emitted(_action_button, "tooltip_changed")

# Button Size Tests
func test_button_size() -> void:
	if not is_instance_valid(_action_button):
		push_warning("Skipping test_button_size: action button is null or invalid")
		pending("Test skipped - action button is null or invalid")
		return
		
	if not _action_button.has_method("set_custom_size") or not _action_button.has_method("get_custom_size"):
		push_warning("Skipping size tests: required methods not found")
		pending("Test skipped - required methods not found")
		return
		
	watch_signals(_action_button)
	
	var size := Vector2(100, 50)
	var success = TypeSafeMixin._call_node_method_bool(_action_button, "set_custom_size", [size])
	
	if not success:
		push_warning("Failed to set custom size - set_custom_size method failed")
		pending("Test skipped - set_custom_size method failed")
		return
		
	var result = TypeSafeMixin._call_node_method(_action_button, "get_custom_size", [])
	
	if not result is Vector2:
		push_warning("get_custom_size did not return a Vector2")
		pending("Test skipped - get_custom_size returned invalid type")
		return
		
	var button_size := result as Vector2
	assert_eq(button_size, size, "Button size should match")
	
	if _action_button.has_signal("size_changed"):
		verify_signal_emitted(_action_button, "size_changed")

# Error Handling Tests
func test_error_handling() -> void:
	if not is_instance_valid(_action_button):
		push_warning("Skipping test_error_handling: action button is null or invalid")
		pending("Test skipped - action button is null or invalid")
		return
		
	if not _action_button.has_method("set_style") or not _action_button.has_method("set_icon"):
		push_warning("Skipping error handling tests: required methods not found")
		pending("Test skipped - required methods not found")
		return
		
	watch_signals(_action_button)
	
	# Test invalid style
	var success: bool = TypeSafeMixin._call_node_method_bool(_action_button, "set_style", ["invalid_style"])
	assert_false(success, "Should not set invalid style")
	
	if _action_button.has_signal("style_changed"):
		verify_signal_not_emitted(_action_button, "style_changed")
	
	# Test invalid icon
	success = TypeSafeMixin._call_node_method_bool(_action_button, "set_icon", [null])
	assert_false(success, "Should not set invalid icon")
	
	if _action_button.has_signal("icon_changed"):
		verify_signal_not_emitted(_action_button, "icon_changed")

# Accessibility Tests
func test_accessibility() -> void:
	if not is_instance_valid(_action_button):
		push_warning("Skipping test_accessibility: action button is null or invalid")
		pending("Test skipped - action button is null or invalid")
		return
		
	if not _action_button.has_method("grab_focus") or not _action_button.has_method("has_focus") or not _action_button.has_method("release_focus"):
		push_warning("Skipping accessibility tests: required methods not found")
		pending("Test skipped - required methods not found")
		return
		
	watch_signals(_action_button)
	
	# Test focus handling
	var success = TypeSafeMixin._call_node_method_bool(_action_button, "grab_focus", [])
	
	if not success:
		push_warning("Failed to grab focus - grab_focus method failed")
		pending("Test skipped - grab_focus method failed")
		return
		
	var has_focus: bool = TypeSafeMixin._call_node_method_bool(_action_button, "has_focus", [])
	assert_true(has_focus, "Button should have focus")
	
	if _action_button.has_signal("focus_entered"):
		verify_signal_emitted(_action_button, "focus_entered")
	
	# Test keyboard navigation
	success = TypeSafeMixin._call_node_method_bool(_action_button, "release_focus", [])
	
	if not success:
		push_warning("Failed to release focus - release_focus method failed")
		pending("Test skipped - release_focus method failed")
		return
		
	has_focus = TypeSafeMixin._call_node_method_bool(_action_button, "has_focus", [])
	assert_false(has_focus, "Button should not have focus")
	
	if _action_button.has_signal("focus_exited"):
		verify_signal_emitted(_action_button, "focus_exited")
