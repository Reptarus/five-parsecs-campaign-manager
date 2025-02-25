@tool
extends "res://tests/fixtures/base/game_test.gd"
class_name MobileTest

## Base class for mobile-specific tests
##
## Provides utilities for testing mobile features like touch input,
## responsive layouts, performance metrics, and device simulation.

# Mobile test configuration
const MOBILE_TEST_CONFIG := {
	"stabilize_time": 0.2 as float,
	"gesture_timeout": 1.0 as float,
	"animation_timeout": 0.5 as float,
	"min_touch_target": 44.0 as float
}

# Screen size presets for responsive testing
const MOBILE_SCREEN_SIZES := {
	"phone_portrait": Vector2i(360, 640),
	"phone_landscape": Vector2i(640, 360),
	"tablet_portrait": Vector2i(768, 1024),
	"tablet_landscape": Vector2i(1024, 768),
	"foldable_open": Vector2i(884, 1104),
	"foldable_closed": Vector2i(412, 892)
}

# DPI presets for device simulation
const MOBILE_DEVICE_DPI := {
	"ldpi": 120,
	"mdpi": 160,
	"hdpi": 240,
	"xhdpi": 320,
	"xxhdpi": 480,
	"xxxhdpi": 640
}

# Type-safe instance variables (only declare what's new in this class)
var _original_dpi: float
var _gesture_manager: Node = null
var _mobile_game_state: Node = null
var _mobile_fps_samples: Array[float] = []

## Lifecycle methods

func before_each() -> void:
	await super.before_each()
	_store_original_settings()
	_setup_mobile_environment()
	await stabilize_engine(MOBILE_TEST_CONFIG.stabilize_time)

func after_each() -> void:
	_restore_original_settings()
	_gesture_manager = null
	_mobile_game_state = null
	_mobile_fps_samples.clear()
	await super.after_each()

## Setup and teardown helpers

func _store_original_settings() -> void:
	# We're using _original_window_size and _original_window_mode from parent class
	# Just store the DPI which is specific to mobile tests
	_original_dpi = DisplayServer.screen_get_dpi(0) # Primary screen

func _setup_mobile_environment() -> void:
	# Setup mobile environment
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	get_tree().root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	
	# Initialize game state
	_mobile_game_state = create_test_game_state()
	if _mobile_game_state:
		add_child_autofree(_mobile_game_state)
		track_test_node(_mobile_game_state)
	
	# Initialize gesture manager
	_gesture_manager = _create_gesture_manager()
	if _gesture_manager:
		add_child_autofree(_gesture_manager)
		track_test_node(_gesture_manager)

func _restore_original_settings() -> void:
	DisplayServer.window_set_size(_original_window_size)
	DisplayServer.window_set_mode(_original_window_mode)
	# Note: DPI cannot be set directly in Godot 4.2, we can only read it

## Resolution and device simulation

func set_resolution(resolution_name: String) -> void:
	if resolution_name in MOBILE_SCREEN_SIZES:
		DisplayServer.window_set_size(MOBILE_SCREEN_SIZES[resolution_name])
		await get_tree().process_frame
		await stabilize_engine(MOBILE_TEST_CONFIG.stabilize_time)

func set_custom_resolution(width: int, height: int) -> void:
	DisplayServer.window_set_size(Vector2i(width, height))
	await get_tree().process_frame
	await stabilize_engine(MOBILE_TEST_CONFIG.stabilize_time)

func set_dpi(dpi_name: String) -> void:
	if dpi_name in MOBILE_DEVICE_DPI:
		# Note: In Godot 4.2, we can't set DPI directly, this is for simulation only
		push_warning("DPI cannot be set directly in Godot 4.2. This is for testing purposes only.")
		await get_tree().process_frame

func simulate_portrait_orientation() -> void:
	var current_size := DisplayServer.window_get_size()
	if current_size.x > current_size.y:
		DisplayServer.window_set_size(Vector2i(current_size.y, current_size.x))
	await stabilize_engine(MOBILE_TEST_CONFIG.stabilize_time)

func simulate_landscape_orientation() -> void:
	var current_size := DisplayServer.window_get_size()
	if current_size.x < current_size.y:
		DisplayServer.window_set_size(Vector2i(current_size.y, current_size.x))
	await stabilize_engine(MOBILE_TEST_CONFIG.stabilize_time)

## Touch input simulation

func simulate_touch(position: Vector2, pressed: bool = true, index: int = 0) -> void:
	var touch := InputEventScreenTouch.new()
	touch.position = position
	touch.pressed = pressed
	touch.index = index
	Input.parse_input_event(touch)
	await stabilize_engine(MOBILE_TEST_CONFIG.stabilize_time)

func simulate_drag(start_position: Vector2, end_position: Vector2, duration: float = 0.1, index: int = 0) -> void:
	# Start touch
	await simulate_touch(start_position, true, index)
	
	# Simulate drag
	var step_count := 10
	var step_size := (end_position - start_position) / step_count
	var current_position := start_position
	
	for i in range(step_count):
		current_position += step_size
		var drag := InputEventScreenDrag.new()
		drag.position = current_position
		drag.relative = step_size
		drag.index = index
		Input.parse_input_event(drag)
		await get_tree().process_frame
	
	await get_tree().create_timer(duration).timeout
	
	# End touch
	await simulate_touch(end_position, false, index)

## Gesture simulation

func simulate_swipe(start_position: Vector2, direction: Vector2, distance: float = 100.0) -> void:
	var end_position := start_position + direction.normalized() * distance
	await simulate_drag(start_position, end_position)

func simulate_pinch(center: Vector2, start_scale: float = 1.0, end_scale: float = 2.0) -> void:
	var start_distance := 100.0 * start_scale
	var end_distance := 100.0 * end_scale
	
	var touch1_start := center + Vector2(- start_distance / 2, 0)
	var touch1_end := center + Vector2(- end_distance / 2, 0)
	var touch2_start := center + Vector2(start_distance / 2, 0)
	var touch2_end := center + Vector2(end_distance / 2, 0)
	
	await simulate_drag(touch1_start, touch1_end, 0.2, 0)
	await simulate_drag(touch2_start, touch2_end, 0.2, 1)

func simulate_rotation(center: Vector2, angle: float) -> void:
	var radius := 100.0
	var start_angle := 0.0
	var end_angle := angle
	
	var touch1_start := center + Vector2(cos(start_angle), sin(start_angle)) * radius
	var touch1_end := center + Vector2(cos(end_angle), sin(end_angle)) * radius
	var touch2_start := center + Vector2(cos(start_angle + PI), sin(start_angle + PI)) * radius
	var touch2_end := center + Vector2(cos(end_angle + PI), sin(end_angle + PI)) * radius
	
	await simulate_drag(touch1_start, touch1_end, 0.2, 0)
	await simulate_drag(touch2_start, touch2_end, 0.2, 1)

## Touch target testing

func assert_touch_target_size(node: Node, expected_size: Vector2 = Vector2(MOBILE_TEST_CONFIG.min_touch_target, MOBILE_TEST_CONFIG.min_touch_target)) -> void:
	if not node is Control:
		push_error("Node must be a Control node")
		return
		
	var control := node as Control
	assert_true(control.size.x >= expected_size.x,
		"Touch target width should be at least %d pixels" % expected_size.x)
	assert_true(control.size.y >= expected_size.y,
		"Touch target height should be at least %d pixels" % expected_size.y)

func verify_touch_targets(parent: Control) -> void:
	var interactive_controls := parent.find_children("*", "Control", true, false)
	interactive_controls = interactive_controls.filter(func(c): return c.focus_mode != Control.FOCUS_NONE)
	
	for control in interactive_controls:
		assert_touch_target_size(control)

func assert_fits_screen(control: Control, message: String = "") -> void:
	if not control:
		push_error("Control is null")
		return
		
	var screen_size := DisplayServer.window_get_size()
	var control_size := control.get_rect().size
	
	assert_true(control_size.x <= screen_size.x and control_size.y <= screen_size.y,
		message if message else "Control should fit within screen bounds")

## Responsive layout testing

func test_responsive_layout(control: Control) -> void:
	for resolution_name in MOBILE_SCREEN_SIZES:
		await set_resolution(resolution_name)
		var resolution_size: Vector2i = MOBILE_SCREEN_SIZES[resolution_name]
		
		# Verify layout constraints
		assert_true(control.size.x <= resolution_size.x,
			"Control width should fit screen size %s" % resolution_name)
		assert_true(control.size.y <= resolution_size.y,
			"Control height should fit screen size %s" % resolution_name)
		
		# Verify touch targets
		verify_touch_targets(control)

## Performance testing

func measure_touch_performance(iterations: int = 100) -> Dictionary:
	_mobile_fps_samples.clear()
	var memory_before := Performance.get_monitor(Performance.MEMORY_STATIC)
	var draw_calls_before := Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
	
	for i in range(iterations):
		var position := Vector2(100 + i, 100 + i)
		await simulate_touch(position, true)
		await simulate_touch(position, false)
		_mobile_fps_samples.append(Engine.get_frames_per_second())
	
	var memory_after := Performance.get_monitor(Performance.MEMORY_STATIC)
	var draw_calls_after := Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
	
	return {
		"average_fps": _calculate_average(_mobile_fps_samples),
		"minimum_fps": _calculate_minimum(_mobile_fps_samples),
		"memory_delta_kb": (memory_after - memory_before) / 1024,
		"draw_calls_delta": draw_calls_after - draw_calls_before
	}

func _calculate_average(values: Array) -> float:
	if values.is_empty():
		return 0.0
	var sum := 0.0
	for value in values:
		sum += value
	return sum / values.size()

func _calculate_minimum(values: Array) -> float:
	if values.is_empty():
		return 0.0
	var min_value: float = values[0]
	for value in values:
		min_value = min(min_value, value)
	return min_value

func _calculate_maximum(values: Array) -> float:
	if values.is_empty():
		return 0.0
	var max_value: float = values[0]
	for value in values:
		max_value = max(max_value, value)
	return max_value

func _calculate_percentile(values: Array, percentile: float) -> float:
	if values.is_empty():
		return 0.0
	var sorted := values.duplicate()
	sorted.sort()
	var index := int(sorted.size() * percentile)
	return sorted[index]

## Helper methods

func wait_for_gesture() -> void:
	await get_tree().create_timer(MOBILE_TEST_CONFIG.gesture_timeout).timeout

func wait_for_animation() -> void:
	await get_tree().create_timer(MOBILE_TEST_CONFIG.animation_timeout).timeout

func _create_gesture_manager() -> Node:
	return null # Override in derived classes

func create_test_game_state() -> Node:
	var state := Node.new()
	add_child_autofree(state)
	return state