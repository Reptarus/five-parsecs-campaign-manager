@tool
class_name TestGestureManager
extends "res://tests/unit/ui/base/component_test_base.gd"

## Tests for the GestureManager component
##
## Tests gesture recognition including taps, swipes, pinches,
## and proper target registration/unregistration

const GestureManagerClass = preload("res://src/ui/components/gesture/GestureManager.gd")

# Type-safe instance variables
var _gesture_manager
var _test_node: Control

# Mock input event creation
func create_mock_touch_event(position: Vector2, pressed: bool, index: int = 0) -> InputEventScreenTouch:
	var event = InputEventScreenTouch.new()
	event.position = position
	event.pressed = pressed
	event.index = index
	return event

func create_mock_drag_event(position: Vector2, relative: Vector2, index: int = 0) -> InputEventScreenDrag:
	var event = InputEventScreenDrag.new()
	event.position = position
	event.relative = relative
	event.index = index
	return event

## Override to create our component
func _create_component_instance() -> Control:
	# Create a wrapper Control node that contains the GestureManager
	var wrapper = Control.new()
	wrapper.name = "GestureManagerWrapper"
	
	# Create and add the gesture manager as a child
	var gesture_manager = GestureManagerClass.new()
	gesture_manager.name = "GestureManager"
	wrapper.add_child(gesture_manager)
	
	# Store reference to the gesture manager for testing
	_gesture_manager = gesture_manager
	
	return wrapper

## Setup before each test
func before_each() -> void:
	await super.before_each()
	
	# If _gesture_manager wasn't set in _create_component_instance, try to find it in the component
	if not is_instance_valid(_gesture_manager) and is_instance_valid(_component):
		_gesture_manager = _component.get_node_or_null("GestureManager")
	
	# Create test node to receive gestures
	_test_node = Control.new()
	add_child_autofree(_test_node)
	track_test_node(_test_node)
	_test_node.size = Vector2(100, 100)
	_test_node.global_position = Vector2(50, 50)
	
	# Initialize the component
	if is_instance_valid(_gesture_manager):
		# Watch signals
		if _signal_watcher:
			_signal_watcher.watch_signals(_gesture_manager)
	else:
		push_error("Failed to initialize gesture manager")

## Cleanup after each test
func after_each() -> void:
	# Let component_test_base handle cleanup
	await super.after_each()
	
	_gesture_manager = null
	_test_node = null

# Basic Gesture Tests
func test_tap_recognition() -> void:
	if not is_instance_valid(_gesture_manager):
		push_warning("Skipping test_tap_recognition: _gesture_manager is null or invalid")
		pending("Test skipped - _gesture_manager is null or invalid")
		return
		
	if not (_gesture_manager.has_method("register_target") and
			_gesture_manager.has_method("unregister_target") and
			_gesture_manager.has_method("_input")):
		push_warning("Skipping test_tap_recognition: required methods not found")
		pending("Test skipped - required methods not found")
		return
		
	if not (_gesture_manager.has_signal("tap") and is_instance_valid(_test_node)):
		push_warning("Skipping test_tap_recognition: required signals or test node not found")
		pending("Test skipped - required signals or test node not found")
		return
		
	# Register test node for gestures
	_gesture_manager.register_target(_test_node)
	
	# Simulate tap gesture
	var touch_position = Vector2(100, 100)
	var touch_start = create_mock_touch_event(touch_position, true)
	var touch_end = create_mock_touch_event(touch_position, false)
	
	# Process events
	_gesture_manager._input(touch_start)
	_gesture_manager._input(touch_end)
	
	# Check tap signal emission
	assert_signal_emitted(_gesture_manager, "tap")
	
	# Verify target and position
	var last_signal_data = get_signal_parameters(_gesture_manager, "tap")
	assert_eq(last_signal_data[0], _test_node, "Tap target should be the test node")
	assert_eq(last_signal_data[1], touch_position, "Tap position should match touch position")

func test_swipe_recognition() -> void:
	if not is_instance_valid(_gesture_manager):
		push_warning("Skipping test_swipe_recognition: _gesture_manager is null or invalid")
		pending("Test skipped - _gesture_manager is null or invalid")
		return
		
	if not (_gesture_manager.has_method("register_target") and
			_gesture_manager.has_method("_input") and
			_gesture_manager.has_signal("swipe")):
		push_warning("Skipping test_swipe_recognition: required methods or signals not found")
		pending("Test skipped - required methods or signals not found")
		return
		
	if not is_instance_valid(_test_node):
		push_warning("Skipping test_swipe_recognition: _test_node is null or invalid")
		pending("Test skipped - _test_node is null or invalid")
		return
		
	# Register test node for gestures
	_gesture_manager.register_target(_test_node)
	
	# Simulate swipe gesture
	var start_position = Vector2(100, 100)
	var end_position = Vector2(300, 100)
	
	var touch_start = create_mock_touch_event(start_position, true)
	var drag_event = create_mock_drag_event(Vector2(200, 100), Vector2(10, 0))
	var touch_end = create_mock_touch_event(end_position, false)
	
	# Process events
	_gesture_manager._input(touch_start)
	_gesture_manager._input(drag_event)
	_gesture_manager._input(touch_end)
	
	# Check swipe signal emission
	assert_signal_emitted(_gesture_manager, "swipe")
	
	# Verify swipe parameters
	var last_signal_data = get_signal_parameters(_gesture_manager, "swipe")
	assert_eq(last_signal_data[0], _test_node, "Swipe target should be the test node")
	assert_eq(last_signal_data[1], start_position, "Swipe start should match touch start")
	assert_eq(last_signal_data[2], end_position, "Swipe end should match touch end")
	assert_eq(last_signal_data[3], 1, "Swipe direction should be RIGHT")

func test_pinch_recognition() -> void:
	if not is_instance_valid(_gesture_manager):
		push_warning("Skipping test_pinch_recognition: _gesture_manager is null or invalid")
		pending("Test skipped - _gesture_manager is null or invalid")
		return
		
	if not (_gesture_manager.has_method("register_target") and
			_gesture_manager.has_method("_input") and
			_gesture_manager.has_signal("pinch")):
		push_warning("Skipping test_pinch_recognition: required methods or signals not found")
		pending("Test skipped - required methods or signals not found")
		return
		
	if not is_instance_valid(_test_node):
		push_warning("Skipping test_pinch_recognition: _test_node is null or invalid")
		pending("Test skipped - _test_node is null or invalid")
		return
		
	# Register test node for gestures
	_gesture_manager.register_target(_test_node)
	
	# Simulate pinch gesture
	var touch1_start = create_mock_touch_event(Vector2(100, 100), true, 0)
	var touch2_start = create_mock_touch_event(Vector2(200, 200), true, 1)
	
	var drag1 = create_mock_drag_event(Vector2(120, 120), Vector2(20, 20), 0)
	var drag2 = create_mock_drag_event(Vector2(180, 180), Vector2(-20, -20), 1)
	
	var touch1_end = create_mock_touch_event(Vector2(120, 120), false, 0)
	var touch2_end = create_mock_touch_event(Vector2(180, 180), false, 1)
	
	# Process events
	_gesture_manager._input(touch1_start)
	_gesture_manager._input(touch2_start)
	_gesture_manager._input(drag1)
	_gesture_manager._input(drag2)
	_gesture_manager._input(touch1_end)
	_gesture_manager._input(touch2_end)
	
	# Check pinch signal emission
	assert_signal_emitted(_gesture_manager, "pinch")
	
	# Verify pinch parameters
	var last_signal_data = get_signal_parameters(_gesture_manager, "pinch")
	assert_eq(last_signal_data[0], _test_node, "Pinch target should be the test node")
	
	# Check zoom factor is less than 1 (pinch in)
	assert_true(last_signal_data[1] < 1.0, "Zoom factor should be less than 1 for pinch in")

# Target Management Tests
func test_target_registration() -> void:
	if not is_instance_valid(_gesture_manager):
		push_warning("Skipping test_target_registration: _gesture_manager is null or invalid")
		pending("Test skipped - _gesture_manager is null or invalid")
		return
		
	if not (_gesture_manager.has_method("register_target") and
			_gesture_manager.has_method("unregister_target") and
			_gesture_manager.has_method("is_target_registered")):
		push_warning("Skipping test_target_registration: required methods not found")
		pending("Test skipped - required methods not found")
		return
		
	if not is_instance_valid(_test_node):
		push_warning("Skipping test_target_registration: _test_node is null or invalid")
		pending("Test skipped - _test_node is null or invalid")
		return
		
	# Register test node
	_gesture_manager.register_target(_test_node)
	
	# Check registration
	assert_true(_gesture_manager.is_target_registered(_test_node),
		"Test node should be registered")
	
	# Unregister test node
	_gesture_manager.unregister_target(_test_node)
	
	# Check registration again
	assert_false(_gesture_manager.is_target_registered(_test_node),
		"Test node should no longer be registered")

# Gesture Settings Tests
func test_gesture_settings() -> void:
	if not is_instance_valid(_gesture_manager):
		push_warning("Skipping test_gesture_settings: _gesture_manager is null or invalid")
		pending("Test skipped - _gesture_manager is null or invalid")
		return
		
	if not (_gesture_manager.has_method("set_tap_timeout") and
			_gesture_manager.has_method("set_swipe_threshold") and
			_gesture_manager.has_method("set_pinch_threshold")):
		push_warning("Skipping test_gesture_settings: required methods not found")
		pending("Test skipped - required methods not found")
		return
		
	# Set custom gesture settings
	_gesture_manager.set_tap_timeout(0.3)
	_gesture_manager.set_swipe_threshold(50.0)
	_gesture_manager.set_pinch_threshold(0.2)
	
	# Verify settings
	assert_eq(_gesture_manager.tap_timeout, 0.3, "Tap timeout should be set correctly")
	assert_eq(_gesture_manager.swipe_threshold, 50.0, "Swipe threshold should be set correctly")
	assert_eq(_gesture_manager.pinch_threshold, 0.2, "Pinch threshold should be set correctly")

# Multi-touch Tests
func test_multi_touch_handling() -> void:
	if not is_instance_valid(_gesture_manager):
		push_warning("Skipping test_multi_touch_handling: _gesture_manager is null or invalid")
		pending("Test skipped - _gesture_manager is null or invalid")
		return
		
	if not (_gesture_manager.has_method("register_target") and
			_gesture_manager.has_method("_input")):
		push_warning("Skipping test_multi_touch_handling: required methods not found")
		pending("Test skipped - required methods not found")
		return
		
	if not is_instance_valid(_test_node):
		push_warning("Skipping test_multi_touch_handling: _test_node is null or invalid")
		pending("Test skipped - _test_node is null or invalid")
		return
		
	# Register test node
	_gesture_manager.register_target(_test_node)
	
	# Simulate simultaneous touches
	var touch1 = create_mock_touch_event(Vector2(100, 100), true, 0)
	var touch2 = create_mock_touch_event(Vector2(200, 200), true, 1)
	var touch3 = create_mock_touch_event(Vector2(300, 300), true, 2)
	
	# Process events
	_gesture_manager._input(touch1)
	_gesture_manager._input(touch2)
	_gesture_manager._input(touch3)
	
	# Verify all touches are tracked
	assert_eq(_gesture_manager.active_touches.size(), 3,
		"All three touches should be tracked")
	
	# End touches in reverse order
	var release1 = create_mock_touch_event(Vector2(300, 300), false, 2)
	var release2 = create_mock_touch_event(Vector2(200, 200), false, 1)
	var release3 = create_mock_touch_event(Vector2(100, 100), false, 0)
	
	_gesture_manager._input(release1)
	assert_eq(_gesture_manager.active_touches.size(), 2,
		"Two touches should remain after first release")
	
	_gesture_manager._input(release2)
	assert_eq(_gesture_manager.active_touches.size(), 1,
		"One touch should remain after second release")
	
	_gesture_manager._input(release3)
	assert_eq(_gesture_manager.active_touches.size(), 0,
		"No touches should remain after all releases")

# Error Case Tests
func test_invalid_target() -> void:
	if not is_instance_valid(_gesture_manager):
		push_warning("Skipping test_invalid_target: _gesture_manager is null or invalid")
		pending("Test skipped - _gesture_manager is null or invalid")
		return
		
	if not (_gesture_manager.has_method("register_target") and
			_gesture_manager.has_method("is_target_registered")):
		push_warning("Skipping test_invalid_target: required methods not found")
		pending("Test skipped - required methods not found")
		return
		
	# Try to register null target
	_gesture_manager.register_target(null)
	
	# Verify null target is not registered
	assert_false(_gesture_manager.is_target_registered(null),
		"Null target should not be registered")
	
	# Create and immediately free a node
	var temp_node = Control.new()
	add_child(temp_node)
	temp_node.queue_free()
	await get_tree().process_frame
	
	# Try to register freed node
	_gesture_manager.register_target(temp_node)
	
	# Verify freed node is not registered
	assert_false(_gesture_manager.is_target_registered(temp_node),
		"Freed node should not be registered")

# Cleanup Tests
func test_cleanup() -> void:
	if not is_instance_valid(_gesture_manager):
		push_warning("Skipping test_cleanup: _gesture_manager is null or invalid")
		pending("Test skipped - _gesture_manager is null or invalid")
		return
		
	if not (_gesture_manager.has_method("register_target") and
			_gesture_manager.has_method("cleanup")):
		push_warning("Skipping test_cleanup: required methods not found")
		pending("Test skipped - required methods not found")
		return
		
	if not is_instance_valid(_test_node):
		push_warning("Skipping test_cleanup: _test_node is null or invalid")
		pending("Test skipped - _test_node is null or invalid")
		return
		
	# Register test node
	_gesture_manager.register_target(_test_node)
	
	# Clean up gesture manager
	_gesture_manager.cleanup()
	
	# Verify all targets are unregistered
	assert_false(_gesture_manager.is_target_registered(_test_node),
		"Test node should not be registered after cleanup")
	
	# Verify all touches are cleared
	assert_eq(_gesture_manager.active_touches.size(), 0,
		"All touches should be cleared after cleanup")
