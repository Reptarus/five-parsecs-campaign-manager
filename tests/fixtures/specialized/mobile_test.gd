@tool
extends GdUnitGameTest
class_name MobileTest

## Base class for mobile-specific tests
##
## Provides utilities for testing mobile features like touch input,
## responsive layouts, performance metrics, and device simulation.

const MOBILE_TEST_CONFIG := {
	"stabilize_time": 0.2,
	"gesture_timeout": 1.0,
	"animation_timeout": 0.5,
	"min_touch_target": 44.0,
}

const MOBILE_SCREEN_SIZES := {
	"phone_portrait": Vector2i(360, 640),
	"phone_landscape": Vector2i(640, 360),
	"tablet_portrait": Vector2i(768, 1024),
	"tablet_landscape": Vector2i(1024, 768),
	"foldable_open": Vector2i(884, 1104),
	"foldable_closed": Vector2i(412, 892)
}

const MOBILE_DEVICE_DPI := {
	"ldpi": 120,
	"mdpi": 160,
	"hdpi": 240,
	"xhdpi": 320,
	"xxhdpi": 480,
	"xxxhdpi": 640,
}

var _original_dpi: float
var _original_window_size: Vector2i
var _original_window_mode: DisplayServer.WindowMode
var _gesture_manager: Node = null
var _mobile_game_state: Node = null
var _mobile_fps_samples: Array[float] = []

func before_test() -> void:
	await get_tree().process_frame
	_store_original_settings()
	_setup_mobile_environment()

func after_test() -> void:
	_restore_original_settings()
	_gesture_manager = null
	_mobile_game_state = null
	_mobile_fps_samples.clear()
	await get_tree().process_frame

func _store_original_settings() -> void:
	# Store current settings
	_original_window_size = DisplayServer.window_get_size()
	_original_window_mode = DisplayServer.window_get_mode()
	_original_dpi = DisplayServer.screen_get_dpi(0) # First screen

func _setup_mobile_environment() -> void:
	# Set up mobile-like environment
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	get_tree().root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	
	# Create mobile game state
	_mobile_game_state = create_test_game_state()
	if _mobile_game_state:
		# track_node(node)
		pass
	
	# Create gesture manager
	_gesture_manager = _create_gesture_manager()
	if _gesture_manager:
		# track_node(node)
		pass

func _restore_original_settings() -> void:
	DisplayServer.window_set_size(_original_window_size)
	DisplayServer.window_set_mode(_original_window_mode)
	# Note: DPI cannot be set directly in Godot 4.2, we can only read it

# Resolution and orientation methods

func set_resolution(resolution_name: String) -> void:
	if resolution_name in MOBILE_SCREEN_SIZES:
		DisplayServer.window_set_size(MOBILE_SCREEN_SIZES[resolution_name])
		await get_tree().process_frame

func set_custom_resolution(width: int, height: int) -> void:
	DisplayServer.window_set_size(Vector2i(width, height))
	await get_tree().process_frame

func set_dpi(dpi_name: String) -> void:
	if dpi_name in MOBILE_DEVICE_DPI:
		# Note: Cannot actually set DPI in Godot
		push_warning("DPI cannot be set directly in Godot 4.2. This is for testing purposes only.")

func simulate_portrait_orientation() -> void:
	var current_size = DisplayServer.window_get_size()
	if current_size.x > current_size.y:
		DisplayServer.window_set_size(Vector2i(current_size.y, current_size.x))
		await get_tree().process_frame

func simulate_landscape_orientation() -> void:
	var current_size = DisplayServer.window_get_size()
	if current_size.x < current_size.y:
		DisplayServer.window_set_size(Vector2i(current_size.y, current_size.x))
		await get_tree().process_frame

# Touch simulation methods

func simulate_touch(position: Vector2, _pressed: bool = true, index: int = 0) -> void:
	var touch = InputEventScreenTouch.new()
	touch.position = position
	touch.pressed = _pressed
	touch.index = index
	Input.parse_input_event(touch)

func simulate_drag(start_position: Vector2, end_position: Vector2, duration: float = 0.1, index: int = 0) -> void:
	# Start touch
	simulate_touch(start_position, true, index)
	await get_tree().process_frame
	
	# Simulate drag
	var step_count := 10
	var step_size := (end_position - start_position) / step_count
	var current_position := start_position
	
	for i: int in range(step_count):
		current_position += step_size
		var drag = InputEventScreenDrag.new()
		drag.position = current_position
		drag.relative = step_size
		drag.index = index
		Input.parse_input_event(drag)
		await get_tree().process_frame
	
	await get_tree().process_frame
	
	# End touch
	simulate_touch(end_position, false, index)

func simulate_swipe(start_position: Vector2, direction: Vector2, distance: float = 100.0) -> void:
	var end_position := start_position + direction.normalized() * distance
	await simulate_drag(start_position, end_position, 0.1)

func simulate_pinch(center: Vector2, start_scale: float = 1.0, end_scale: float = 2.0) -> void:
	var start_distance := 100.0 * start_scale
	var end_distance := 100.0 * end_scale
	
	var touch1_start := center + Vector2(-start_distance / 2, 0)
	var touch1_end := center + Vector2(-end_distance / 2, 0)
	var touch2_start := center + Vector2(start_distance / 2, 0)
	var touch2_end := center + Vector2(end_distance / 2, 0)
	
	# Simulate pinch gesture (simplified)
	await simulate_drag(touch1_start, touch1_end, 0.2, 0)

func simulate_rotation(center: Vector2, angle: float) -> void:
	var radius := 100.0
	var start_angle := 0.0
	var end_angle := angle
	
	var touch1_start := center + Vector2(cos(start_angle), sin(start_angle)) * radius
	var touch1_end := center + Vector2(cos(end_angle), sin(end_angle)) * radius
	var touch2_start := center + Vector2(cos(start_angle + PI), sin(start_angle + PI)) * radius
	var touch2_end := center + Vector2(cos(end_angle + PI), sin(end_angle + PI)) * radius
	
	# Simulate rotation gesture (simplified)
	await simulate_drag(touch1_start, touch1_end, 0.2, 0)

# Validation methods

func assert_touch_target_size(node: Node, expected_size: Vector2 = Vector2(MOBILE_TEST_CONFIG.min_touch_target, MOBILE_TEST_CONFIG.min_touch_target)) -> void:
	if not node is Control:
		return
	
	var control = node as Control
	assert_that(control.get_rect().size.x).is_greater_equal(expected_size.x).override_failure_message("Touch target width should be at least %d pixels" % expected_size.x)
	assert_that(control.get_rect().size.y).is_greater_equal(expected_size.y).override_failure_message("Touch target height should be at least %d pixels" % expected_size.y)

func verify_touch_targets(parent: Control) -> void:
	var interactive_controls = parent.find_children("*", "Control")
	interactive_controls = interactive_controls.filter(func(c): return c.focus_mode != Control.FOCUS_NONE)
	
	for control in interactive_controls:
		assert_touch_target_size(control)

func assert_fits_screen(control: Control, message: String = "") -> void:
	if not control:
		return
	
	var control_size := control.get_rect().size
	var screen_size := get_viewport().get_visible_rect().size
	
	var error_message = message if message else "Control should fit within screen bounds"
	assert_that(control_size.x).is_less_equal(screen_size.x).override_failure_message(error_message + " (width)")
	assert_that(control_size.y).is_less_equal(screen_size.y).override_failure_message(error_message + " (height)")

# Testing methods

func test_responsive_layout() -> void:
	# Create a test control for responsive layout testing
	var control: Control = Control.new()
	add_child(control)
	
	for resolution_name in MOBILE_SCREEN_SIZES:
		set_resolution(resolution_name)
		var resolution_size: Vector2i = MOBILE_SCREEN_SIZES[resolution_name]
		
		# Verify layout constraints
		assert_that(control.get_rect().size.x).is_less_equal(resolution_size.x).override_failure_message("Control width should fit screen size %s" % resolution_name)
		assert_that(control.get_rect().size.y).is_less_equal(resolution_size.y).override_failure_message("Control height should fit screen size %s" % resolution_name)
		
		# Verify touch targets
		verify_touch_targets(control)

func measure_touch_performance(iterations: int = 100) -> Dictionary:
	_mobile_fps_samples.clear()
	var memory_before := Performance.get_monitor(Performance.MEMORY_STATIC)
	var draw_calls_before := Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
	
	for i: int in range(iterations):
		simulate_touch(Vector2(100, 100))
		await get_tree().process_frame
		_mobile_fps_samples.append(Engine.get_frames_per_second())
	
	var memory_after := Performance.get_monitor(Performance.MEMORY_STATIC)
	var draw_calls_after := Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
	
	return {
		"average_fps": _calculate_average(_mobile_fps_samples),
		"minimum_fps": _calculate_minimum(_mobile_fps_samples),
		"memory_delta_kb": (memory_after - memory_before) / 1024,
		"draw_calls_delta": draw_calls_after - draw_calls_before,
	}
	
func _calculate_average(values: Array) -> float:
	if values.is_empty():
		return 0.0
	
	var sum = 0.0
	for _value in values:
		sum += _value
	return sum / values.size()

func _calculate_minimum(values: Array) -> float:
	if values.is_empty():
		return 0.0
	
	var min_value = values[0]
	for _value in values:
		min_value = min(min_value, _value)
	return min_value

func _calculate_maximum(values: Array) -> float:
	if values.is_empty():
		return 0.0
	
	var max_value = values[0]
	for _value in values:
		max_value = max(max_value, _value)
	return max_value

func _calculate_percentile(values: Array, percentile: float) -> float:
	if values.is_empty():
		return 0.0
	
	var sorted = values.duplicate()
	sorted.sort()
	var index := int(sorted.size() * percentile)
	return sorted[index]

#

func wait_for_gesture() -> void:
	pass
#

func wait_for_animation() -> void:
	pass
#

func _create_gesture_manager() -> Node:
	var gesture_manager = Node.new()
	gesture_manager.name = "GestureManager"
	return gesture_manager

func create_test_game_state() -> Node:
	var state = Node.new()
	state.name = "TestGameState"
	return state
# 	var state := Node.new()
# 	# add_child(node)
# # track_node(node)