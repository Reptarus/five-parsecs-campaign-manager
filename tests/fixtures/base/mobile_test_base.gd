@tool
extends "res://tests/fixtures/base/game_test.gd"
# Use explicit preloads instead of global class names
const MobileTestBaseScript = preload("res://tests/fixtures/base/mobile_test_base.gd")

# Type-safe constants for mobile testing
const DEFAULT_TOUCH_TARGET_SIZE := Vector2(44, 44)
const DEFAULT_SCREEN_DPI := 160
const DEFAULT_RESOLUTION := Vector2i(1920, 1080)

# Type-safe instance variables
var _original_resolution: Vector2i
var _original_dpi: int

# Lifecycle Methods
func before_each() -> void:
	await super.before_each()
	
	# Store original settings
	_original_resolution = DisplayServer.window_get_size()
	_original_dpi = DisplayServer.screen_get_dpi()
	
	# Initialize test environment
	_game_state = create_test_game_state()
	if not _game_state:
		push_error("Failed to create test game state")
		return
	add_child_autofree(_game_state)
	track_test_node(_game_state)
	
	await stabilize_engine()

func after_each() -> void:
	# Disconnect any signals that might be connected
	for node in _tracked_nodes:
		if is_instance_valid(node):
			disconnect_all_signals(node)
	
	# Restore original settings
	restore_resolution()
	restore_device_dpi()
	
	_game_state = null
	await super.after_each()

# Screen Resolution Methods
func set_test_resolution(width: int, height: int) -> void:
	var window := get_window()
	if not window:
		push_error("Failed to get window")
		return
		
	window.size = Vector2i(width, height)
	await stabilize_engine()

func restore_resolution() -> void:
	var window := get_window()
	if not window:
		push_error("Failed to get window")
		return
		
	window.size = _original_resolution
	await stabilize_engine()

# Device Simulation Methods
func simulate_device_dpi(dpi: int) -> void:
	# Store original DPI
	_original_dpi = DisplayServer.screen_get_dpi()
	
	# Set test DPI
	# Note: This is a mock implementation since we can't actually change DPI
	push_warning("DPI simulation not fully implemented")
	
	await stabilize_engine()

func restore_device_dpi() -> void:
	# Restore original DPI
	# Note: This is a mock implementation
	push_warning("DPI restoration not fully implemented")
	
	await stabilize_engine()

# Touch Input Methods
func simulate_touch_press(position: Vector2) -> void:
	var event := InputEventScreenTouch.new()
	event.position = position
	event.pressed = true
	Input.parse_input_event(event)
	await stabilize_engine()

func simulate_touch_release(position: Vector2) -> void:
	var event := InputEventScreenTouch.new()
	event.position = position
	event.pressed = false
	Input.parse_input_event(event)
	await stabilize_engine()

func simulate_touch_drag(from: Vector2, to: Vector2, steps: float = 10.0) -> void:
	var step_size := (to - from) / steps
	var current := from
	
	simulate_touch_press(from)
	
	for i in range(steps):
		current += step_size
		var event := InputEventScreenDrag.new()
		event.position = current
		event.relative = step_size
		Input.parse_input_event(event)
		await stabilize_engine()
	
	simulate_touch_release(to)

# Orientation Methods
func simulate_portrait_orientation() -> void:
	var current_size := DisplayServer.window_get_size()
	if current_size.x > current_size.y:
		set_test_resolution(current_size.y, current_size.x)
	await stabilize_engine()

func simulate_landscape_orientation() -> void:
	var current_size := DisplayServer.window_get_size()
	if current_size.x < current_size.y:
		set_test_resolution(current_size.y, current_size.x)
	await stabilize_engine()

# Mobile-specific Assertions
func assert_fits_screen(control: Control, message: String = "") -> void:
	if not control:
		push_error("Control is null")
		return
		
	var screen_size := DisplayServer.window_get_size()
	var control_size := control.get_rect().size
	
	assert_true(control_size.x <= screen_size.x and control_size.y <= screen_size.y,
		message if message else "Control should fit within screen bounds")

func assert_touch_target_size(node: Node, min_size: Vector2 = DEFAULT_TOUCH_TARGET_SIZE) -> void:
	if not node is Control:
		push_error("Node must be a Control node")
		return
		
	var control := node as Control
	var control_size := control.get_rect().size
	
	assert_true(control_size.x >= min_size.x and control_size.y >= min_size.y,
		"Control should meet minimum touch target size requirements")

# Performance Testing Methods
func measure_mobile_performance(test_function: Callable, iterations: int = 100) -> Dictionary:
	var results := {
		"fps_samples": [],
		"memory_samples": [],
		"draw_calls": [],
		"objects": []
	}
	
	for i in range(iterations):
		await test_function.call()
		results.fps_samples.append(Engine.get_frames_per_second())
		results.memory_samples.append(Performance.get_monitor(Performance.MEMORY_STATIC))
		results.draw_calls.append(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
		results.objects.append(Performance.get_monitor(Performance.OBJECT_COUNT))
	
	return {
		"average_fps": _calculate_average(results.fps_samples),
		"minimum_fps": _calculate_minimum(results.fps_samples),
		"95th_percentile_fps": _calculate_percentile(results.fps_samples, 0.95),
		"memory_delta_kb": (_calculate_maximum(results.memory_samples) - _calculate_minimum(results.memory_samples)) / 1024,
		"draw_calls_delta": _calculate_maximum(results.draw_calls) - _calculate_minimum(results.draw_calls),
		"objects_delta": _calculate_maximum(results.objects) - _calculate_minimum(results.objects)
	}

# Statistical Helper Methods
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
	var sorted: Array = values.duplicate()
	sorted.sort()
	
	# Ensure percentile is within valid range
	var min_value: float = 0.0
	var max_value: float = 1.0
	var safe_percentile: float = max(min_value, min(percentile, max_value))
	
	# Calculate index safely
	var array_size: int = sorted.size()
	var calculated_index: int = int(float(array_size) * safe_percentile)
	var safe_index: int = min(calculated_index, array_size - 1)
	
	return sorted[safe_index]

# Mobile test helpers
func create_test_game_state() -> Node:
	var state := Node.new()
	if not state:
		push_error("Failed to create game state node")
		return null
		
	add_child_autofree(state)
	# add_child_autofree already calls track_test_node
	return state

# Mobile-specific test utilities
func add_child_autofree(node: Node) -> void:
	if not node:
		push_error("Cannot add null node to scene")
		return
		
	add_child(node)
	# Track the node for automatic cleanup
	track_test_node(node)

# Helper method to safely disconnect signals
func disconnect_all_signals(obj: Object) -> void:
	if not is_instance_valid(obj):
		return
		
	# In Godot 4.4, we need to use get_signal_list and then check connections
	for signal_info in obj.get_signal_list():
		var signal_name: StringName = signal_info["name"]
		# Get all connections for this signal
		var connections = obj.get_signal_connection_list(signal_name)
		
		for connection in connections:
			var callable: Callable = connection["callable"]
			if obj.is_connected(signal_name, callable):
				obj.disconnect(signal_name, callable)

# Improved error handling wrapper for test methods
func run_test_with_error_handling(test_method: Callable) -> void:
	# Setup error capture
	var had_error := false
	var error_message := ""
	
	# Attempt to run the test
	await test_method.call()
	
	# Check if any errors were pushed during test execution
	if _error_count > 0:
		had_error = true
		error_message = _last_error
	
	# Always ensure cleanup happens
	_cleanup_test_resources()
	
	# Report failure if needed
	if had_error:
		assert_false(true, "Test failed with error: " + error_message)
		
# Helper to assert test failure with message
func assert_fail(message: String) -> void:
	assert_false(true, message)
