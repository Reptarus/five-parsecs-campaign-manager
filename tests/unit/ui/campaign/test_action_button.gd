## Action Button Test Suite
## Tests the functionality of individual action buttons in the campaign UI
@tool
extends GameTest

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
	_action_button = Node.new()
	_action_button.set_script(ActionButton)
	if not _action_button:
		push_error("Failed to create action button")
		return
	TypeSafeMixin._safe_method_call_bool(_action_button, "initialize", [_game_state])
	add_child_autofree(_action_button)
	track_test_node(_action_button)
	
	await stabilize_engine()

func after_each() -> void:
	_action_button = null
	_game_state = null
	await super.after_each()

# Button Initialization Tests
func test_button_initialization() -> void:
	assert_not_null(_action_button, "Action button should be initialized")
	
	var is_visible: bool = TypeSafeMixin._safe_method_call_bool(_action_button, "is_visible", [])
	assert_true(is_visible, "Button should be visible after initialization")
	
	var is_enabled: bool = TypeSafeMixin._safe_method_call_bool(_action_button, "is_enabled", [])
	assert_true(is_enabled, "Button should be enabled by default")

# Button State Tests
func test_button_state() -> void:
	watch_signals(_action_button)
	
	# Test enable/disable
	TypeSafeMixin._safe_method_call_bool(_action_button, "set_enabled", [false])
	var is_enabled: bool = TypeSafeMixin._safe_method_call_bool(_action_button, "is_enabled", [])
	assert_false(is_enabled, "Button should be disabled")
	verify_signal_emitted(_action_button, "state_changed")
	
	# Test visibility
	TypeSafeMixin._safe_method_call_bool(_action_button, "set_visible", [false])
	var is_visible: bool = TypeSafeMixin._safe_method_call_bool(_action_button, "is_visible", [])
	assert_false(is_visible, "Button should be hidden")
	verify_signal_emitted(_action_button, "visibility_changed")

# Button Text Tests
func test_button_text() -> void:
	watch_signals(_action_button)
	
	var test_text := "Test Action"
	TypeSafeMixin._safe_method_call_bool(_action_button, "set_text", [test_text])
	var button_text: String = TypeSafeMixin._safe_method_call_string(_action_button, "get_text", [])
	assert_eq(button_text, test_text, "Button text should match")
	verify_signal_emitted(_action_button, "text_changed")

# Button Icon Tests
func test_button_icon() -> void:
	watch_signals(_action_button)
	
	# Use Godot's built-in placeholder texture
	var test_icon := PlaceholderTexture2D.new()
	test_icon.size = Vector2(32, 32)
	TypeSafeMixin._safe_method_call_bool(_action_button, "set_icon", [test_icon])
	var button_icon: Resource = TypeSafeMixin._safe_method_call_resource(_action_button, "get_icon", [])
	assert_eq(button_icon, test_icon, "Button icon should match")
	verify_signal_emitted(_action_button, "icon_changed")

# Button Action Tests
func test_button_action() -> void:
	watch_signals(_action_button)
	
	var action_id := "test_action"
	TypeSafeMixin._safe_method_call_bool(_action_button, "set_action_id", [action_id])
	var button_action: String = TypeSafeMixin._safe_method_call_string(_action_button, "get_action_id", [])
	assert_eq(button_action, action_id, "Button action ID should match")
	
	# Test action execution
	TypeSafeMixin._safe_method_call_bool(_action_button, "execute_action", [])
	verify_signal_emitted(_action_button, "action_executed")

# Button Style Tests
func test_button_style() -> void:
	watch_signals(_action_button)
	
	# Test normal style
	TypeSafeMixin._safe_method_call_bool(_action_button, "set_style", ["normal"])
	var style: String = TypeSafeMixin._safe_method_call_string(_action_button, "get_style", [])
	assert_eq(style, "normal", "Button style should be normal")
	verify_signal_emitted(_action_button, "style_changed")
	
	# Test highlighted style
	TypeSafeMixin._safe_method_call_bool(_action_button, "set_style", ["highlighted"])
	style = TypeSafeMixin._safe_method_call_string(_action_button, "get_style", [])
	assert_eq(style, "highlighted", "Button style should be highlighted")
	verify_signal_emitted(_action_button, "style_changed")

# Button Tooltip Tests
func test_button_tooltip() -> void:
	watch_signals(_action_button)
	
	var tooltip_text := "Test tooltip"
	TypeSafeMixin._safe_method_call_bool(_action_button, "set_tooltip", [tooltip_text])
	var button_tooltip: String = TypeSafeMixin._safe_method_call_string(_action_button, "get_tooltip", [])
	assert_eq(button_tooltip, tooltip_text, "Button tooltip should match")
	verify_signal_emitted(_action_button, "tooltip_changed")

# Button Size Tests
func test_button_size() -> void:
	watch_signals(_action_button)
	
	var size := Vector2(100, 50)
	TypeSafeMixin._safe_method_call_bool(_action_button, "set_custom_size", [size])
	var button_size: Vector2 = TypeSafeMixin._safe_method_call_vector2(_action_button, "get_custom_size", [])
	assert_eq(button_size, size, "Button size should match")
	verify_signal_emitted(_action_button, "size_changed")

# Error Handling Tests
func test_error_handling() -> void:
	watch_signals(_action_button)
	
	# Test invalid style
	var success: bool = TypeSafeMixin._safe_method_call_bool(_action_button, "set_style", ["invalid_style"])
	assert_false(success, "Should not set invalid style")
	verify_signal_not_emitted(_action_button, "style_changed")
	
	# Test invalid icon
	success = TypeSafeMixin._safe_method_call_bool(_action_button, "set_icon", [null])
	assert_false(success, "Should not set invalid icon")
	verify_signal_not_emitted(_action_button, "icon_changed")

# Accessibility Tests
func test_accessibility() -> void:
	watch_signals(_action_button)
	
	# Test focus handling
	TypeSafeMixin._safe_method_call_bool(_action_button, "grab_focus", [])
	var has_focus: bool = TypeSafeMixin._safe_method_call_bool(_action_button, "has_focus", [])
	assert_true(has_focus, "Button should have focus")
	verify_signal_emitted(_action_button, "focus_entered")
	
	# Test keyboard navigation
	TypeSafeMixin._safe_method_call_bool(_action_button, "release_focus", [])
	has_focus = TypeSafeMixin._safe_method_call_bool(_action_button, "has_focus", [])
	assert_false(has_focus, "Button should not have focus")
	verify_signal_emitted(_action_button, "focus_exited")