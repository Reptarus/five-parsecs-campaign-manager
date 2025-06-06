@tool
extends "res://addons/gut/test.gd"
# Use explicit preloads instead of global class names

# Core test class that all game tests should extend from
const GutMainClass: GDScript = preload("res://addons/gut/gut.gd")
const GutUtilsClass: GDScript = preload("res://addons/gut/utils.gd")
const GlobalEnumsClass: GDScript = preload("res://src/core/systems/GlobalEnums.gd")
const SignalWatcher: GDScript = preload("res://addons/gut/signal_watcher.gd")
const TypeSafeMixin := preload("res://tests/fixtures/helpers/type_safe_test_mixin.gd")

# Updated compatibility layer to handle GDScript creation
const GutCompatibility = preload("res://tests/fixtures/helpers/gut_compatibility.gd")

# Constants for error handling
const ERROR_TYPE_MISMATCH = "Expected %s but got %s"
const ERROR_INVALID_OBJECT = "Invalid object provided"
const ERROR_INVALID_METHOD = "Invalid method name provided"
const ERROR_PROPERTY_NOT_FOUND = "Property '%s' not found in object"
const ERROR_METHOD_NOT_FOUND = "Method '%s' not found in object"

# Game test constants with explicit types
const STABILIZE_TIME: float = 0.1

# Game test configuration
const GAME_TEST_CONFIG := {
	"auto_save": false,
	"debug_mode": true,
	"test_mode": true
}

# Default game state
const DEFAULT_GAME_STATE := {
	"difficulty_level": 1, # Normal difficulty
	"enable_permadeath": true,
	"use_story_track": true,
	"auto_save_enabled": true,
	"last_save_time": 0
}

# Type-safe instance variables
var _game_state = null
var _test_nodes = []
var _test_resources = []
var _game_settings = {}
var _original_window_size = Vector2i.ZERO
var _original_window_mode = DisplayServer.WINDOW_MODE_WINDOWED
var _fps_samples = []

## Lifecycle methods

func before_each():
	await super.before_each()
	_test_nodes.clear()
	_test_resources.clear()
	_setup_game_environment()
	await stabilize_engine(STABILIZE_TIME)

func after_each():
	_restore_game_environment()
	await _cleanup_game_resources()
	
	# Clean up tracked resources
	for resource in _test_resources:
		if resource != null:
			resource = null
	_test_resources.clear()
	
	# Clean up tracked nodes
	for node in _test_nodes:
		if node and is_instance_valid(node):
			if node.get_parent() == self:
				remove_child(node)
			if not node.is_queued_for_deletion():
				node.queue_free()
	_test_nodes.clear()
	
	await super.after_each()

# Type-safe method calls
func _call_node_method(obj, method: String, args = []):
	if not is_instance_valid(obj):
		push_error(ERROR_INVALID_OBJECT)
		return null
	
	if method.is_empty():
		push_error(ERROR_INVALID_METHOD)
		return null
	
	if not obj.has_method(method):
		push_error(ERROR_METHOD_NOT_FOUND % method)
		return null
	
	return obj.callv(method, args)

func _call_node_method_int(obj, method: String, args = [], default: int = 0) -> int:
	var result = _call_node_method(obj, method, args)
	if result == null:
		return default
	if result is int:
		return result
	push_error(ERROR_TYPE_MISMATCH % ["int", result])
	return default

func _call_node_method_bool(obj, method: String, args = [], default: bool = false) -> bool:
	var result = _call_node_method(obj, method, args)
	if result == null:
		return default
	if result is bool:
		return result
	push_error(ERROR_TYPE_MISMATCH % ["bool", result])
	return default

func _call_node_method_array(obj, method: String, args = [], default = []):
	var result = _call_node_method(obj, method, args)
	if result == null:
		return default
	if result is Array:
		return result
	push_error(ERROR_TYPE_MISMATCH % ["Array", result])
	return default

func _call_node_method_dict(obj, method: String, args = [], default = {}):
	var result = _call_node_method(obj, method, args)
	if result == null:
		return default
	if result is Dictionary:
		return result
	push_error(ERROR_TYPE_MISMATCH % ["Dictionary", result])
	return default

func _call_node_method_object(obj, method: String, args = [], default = null):
	var result = _call_node_method(obj, method, args)
	if result == null:
		return default
	if result is Object:
		return result
	push_error(ERROR_TYPE_MISMATCH % ["Object", result])
	return default

## Environment management

func _setup_game_environment() -> void:
	# Store original window settings
	if DisplayServer:
		_original_window_size = DisplayServer.window_get_size()
		_original_window_mode = DisplayServer.window_get_mode()
		
		# Set up test environment with safe property access
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	else:
		push_warning("DisplayServer is not available")
	
	# Safely access the root content scale mode to avoid null reference errors
	var tree = get_tree()
	if tree and tree.get_root():
		tree.get_root().content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	else:
		push_warning("Scene tree or root node is not available")
	
	# Initialize game state
	_game_state = create_test_game_state()
	if _game_state:
		add_child(_game_state)
		track_test_node(_game_state)

func _restore_game_environment() -> void:
	# Restore window settings
	if DisplayServer:
		DisplayServer.window_set_size(_original_window_size)
		DisplayServer.window_set_mode(_original_window_mode)
	
	# Cleanup game state
	if _game_state and is_instance_valid(_game_state):
		if _game_state.is_inside_tree():
			_game_state.get_parent().remove_child(_game_state)
	_game_state = null
	_game_settings.clear()

func _cleanup_game_resources() -> void:
	# Clean up in reverse order
	for i in range(_test_nodes.size() - 1, -1, -1):
		var node = _test_nodes[i]
		if is_instance_valid(node):
			if node.is_inside_tree():
				node.queue_free()
			_test_nodes.remove_at(i)
		else:
			_test_nodes.remove_at(i)
	
	for i in range(_test_resources.size() - 1, -1, -1):
		var resource = _test_resources[i]
		if resource:
			# Don't try to free RefCounted resources - just remove the reference
			# and let reference counting handle cleanup
			resource = null
		_test_resources.remove_at(i)

## Resource management

func create_test_game_state():
	var GameStateScript = load("res://src/core/state/GameState.gd")
	if not GameStateScript:
		push_error("GameStateScript is null, cannot create game state")
		return null
		
	# Create a new state instance
	var state_instance = null
	
	# Safely create an instance
	state_instance = GameStateScript.new()
	if not state_instance:
		push_error("Failed to create game state instance")
		return null
	
	# Verify the instance has the required methods
	var required_methods = [
		"set_difficulty_level",
		"set_enable_permadeath",
		"set_use_story_track",
		"set_auto_save_enabled",
		"set_last_save_time"
	]
	
	for method in required_methods:
		if not state_instance.has_method(method):
			push_warning("Game state instance missing method: %s" % method)
			# Don't return null here, just warn and continue
	
	# Try to initialize with default state if methods exist
	if state_instance.has_method("set_difficulty_level"):
		state_instance.set_difficulty_level(DEFAULT_GAME_STATE.difficulty_level)
	if state_instance.has_method("set_enable_permadeath"):
		state_instance.set_enable_permadeath(DEFAULT_GAME_STATE.enable_permadeath)
	if state_instance.has_method("set_use_story_track"):
		state_instance.set_use_story_track(DEFAULT_GAME_STATE.use_story_track)
	if state_instance.has_method("set_auto_save_enabled"):
		state_instance.set_auto_save_enabled(DEFAULT_GAME_STATE.auto_save_enabled)
	if state_instance.has_method("set_last_save_time"):
		state_instance.set_last_save_time(DEFAULT_GAME_STATE.last_save_time)
	
	return state_instance

func track_test_node(node) -> void:
	if not node:
		return
	
	if _test_nodes.has(node):
		return
	
	_test_nodes.append(node)

func track_test_resource(resource) -> void:
	if not resource:
		return
	
	if _test_resources.has(resource):
		return
	
	_test_resources.append(resource)

func create_test_resource(resource_type):
	if not resource_type:
		push_error("Cannot create resource from null type")
		return null
	
	var resource = resource_type.new()
	if not resource:
		push_error("Failed to create resource instance")
		return null
	
	track_test_resource(resource)
	return resource

func create_test_node(node_type):
	if not node_type:
		push_error("Cannot create node from null type")
		return null
	
	var node = node_type.new()
	if not node:
		push_error("Failed to create node instance")
		return null
	
	add_child(node)
	track_test_node(node) # This will ensure the node gets freed during cleanup
	return node

func add_child_autofree(node, call_ready = true) -> void:
	if not node:
		push_error("Cannot add null node")
		return
	
	# Check if the node already has a parent
	if node.get_parent() != null:
		push_warning("Node '%s' already has a parent '%s'. Removing from current parent before adding." % [node.name, node.get_parent().name])
		node.get_parent().remove_child(node)
	
	# Add the node and track it
	add_child(node, call_ready)
	track_test_node(node) # This will ensure the node gets freed during cleanup

## Game state verification

func verify_game_state(state, expected_state) -> void:
	if not state:
		push_error("Cannot verify null game state")
		return
	
	if not expected_state:
		push_error("Expected state dictionary is empty or null")
		return
	
	for property in expected_state:
		# Ensure the property is a string for method construction
		var property_name = property
		if property_name.is_empty():
			push_error("Invalid property name in expected state")
			continue
			
		# Try to get method name
		var method_name = "get_" + property_name
		
		# Check if the method exists
		if not state.has_method(method_name):
			push_error("State object missing method: %s" % method_name)
			continue
			
		# Get values and compare
		var actual_value = _call_node_method(state, method_name, [])
		var expected_value = expected_state[property]
		
		# Handle null values
		if actual_value == null:
			push_warning("State property '%s' returned null" % property_name)
			
		# Perform the comparison with detailed error message
		assert_eq(actual_value, expected_value,
			"Game state %s should be %s but was %s" % [property, expected_value, actual_value])

func assert_valid_game_state(state) -> void:
	if not state:
		push_error("Game state is null")
		assert_fail("Game state is null")
		return
	
	assert_true(state.is_inside_tree(), "Game state should be in scene tree")
	assert_true(state.is_processing(), "Game state should be processing")
	
	# Verify essential properties if methods exist
	if state.has_method("get_current_phase"):
		var phase = _call_node_method_int(state, "get_current_phase", [], 0)
		assert_true(phase >= 0, "Invalid game phase")
	
	if state.has_method("get_turn_number"):
		var turn = _call_node_method_int(state, "get_turn_number", [], 0)
		assert_true(turn >= 0, "Invalid turn number")

## Stabilization helpers

func stabilize_engine(time = STABILIZE_TIME) -> void:
	await get_tree().process_frame
	await get_tree().create_timer(time).timeout

func stabilize_game_state(time = STABILIZE_TIME) -> void:
	if _game_state:
		await stabilize_engine(time)

## Game-specific assertions

func assert_game_property(obj, property: String, expected_value, message = "") -> void:
	if not is_instance_valid(obj):
		push_error("Cannot assert property on null object")
		assert_fail("Object is null or invalid")
		return
		
	if property == null or property.is_empty():
		push_error("Property name cannot be empty")
		assert_fail("Empty property name")
		return
		
	# Try to get the property value using our helper method
	var actual_value = get_game_property(obj, property)
	
	# Generate a default message if none provided
	if message.is_empty():
		message = "Game property %s should be %s but was %s" % [property, str(expected_value), str(actual_value)]
		
	# Perform the comparison with safer handling of null values
	assert_eq(actual_value, expected_value, message)

func assert_game_state(state_value: int, message = "") -> void:
	if not _game_state:
		push_error("Game state is null")
		assert_fail("Game state is null")
		return
	
	if not _game_state.has_method("get_current_phase"):
		push_error("Game state missing get_current_phase method")
		assert_fail("Invalid game state object")
		return
		
	var current_state = _call_node_method_int(_game_state, "get_current_phase", [], 0)
	if message.is_empty():
		message = "Game state should be %s but was %s" % [state_value, current_state]
	assert_eq(current_state, state_value, message)

func assert_game_turn(turn_value: int, message = "") -> void:
	if not _game_state:
		push_error("Game state is null")
		assert_fail("Game state is null")
		return
		
	if not _game_state.has_method("get_turn_number"):
		push_error("Game state missing get_turn_number method")
		assert_fail("Invalid game state object")
		return
	
	var current_turn = _call_node_method_int(_game_state, "get_turn_number", [], 0)
	if message.is_empty():
		message = "Game turn should be %s but was %s" % [turn_value, current_turn]
	assert_eq(current_turn, turn_value, message)

## Performance testing

func measure_game_performance(test_function, iterations = 30):
	if not test_function.is_valid():
		push_error("Invalid test function provided")
		return {}
		
	if iterations <= 0:
		push_error("Iterations must be > 0")
		return {}
		
	_fps_samples.clear()
	var memory_before = Performance.get_monitor(Performance.MEMORY_STATIC)
	var draw_calls_before = Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
	
	var start_time = Time.get_ticks_msec()
	
	for i in range(iterations):
		await test_function.call()
		_fps_samples.append(Engine.get_frames_per_second())
	
	var end_time = Time.get_ticks_msec()
	var memory_after = Performance.get_monitor(Performance.MEMORY_STATIC)
	var draw_calls_after = Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
	
	# Calculate metrics
	var total_fps = 0.0
	var min_fps = 1000.0
	for fps in _fps_samples:
		total_fps += fps
		min_fps = min(min_fps, fps)
	
	return {
		"average_fps": total_fps / _fps_samples.size() if not _fps_samples.is_empty() else 0.0,
		"minimum_fps": min_fps if not _fps_samples.is_empty() else 0.0,
		"execution_time_ms": end_time - start_time,
		"memory_delta_kb": (memory_after - memory_before) / 1024.0,
		"draw_calls_delta": draw_calls_after - draw_calls_before
	}

func verify_performance_metrics(metrics, thresholds) -> void:
	if not metrics or metrics.is_empty():
		push_error("Cannot verify empty metrics")
		assert_fail("Empty metrics dictionary")
		return
		
	if not thresholds or thresholds.is_empty():
		push_error("Cannot verify against empty thresholds")
		assert_fail("Empty thresholds dictionary")
		return
		
	for key in thresholds.keys():
		if not metrics.has(key):
			push_error("Performance metrics missing required key: %s" % key)
			assert_fail("Performance metrics should include %s" % key)
			continue
			
		var metric_value = metrics[key]
		var threshold_value = thresholds[key]
		
		match key:
			"average_fps", "minimum_fps":
				# Higher is better
				assert_gt(metrics[key], thresholds[key], "%s should exceed threshold" % key)
			"execution_time_ms", "memory_delta_kb", "draw_calls_delta":
				# Lower is better
				assert_lt(metrics[key], thresholds[key], "%s should be below threshold" % key)
			_:
				push_error("Unknown performance metric: %s" % key)

## Helper methods

func set_game_property(obj, property: String, value) -> void:
	if not obj:
		push_error("Cannot set property on null object")
		return
		
	if property.is_empty():
		push_error("Property name cannot be empty")
		return
		
	# Check if the object has the method directly, or try a generic setter
	if obj.has_method("set_" + property):
		_call_node_method_bool(obj, "set_" + property, [value])
	elif obj.has_method("set"):
		_call_node_method_bool(obj, "set", [property, value])
	else:
		# If no setter method exists, try direct property assignment
		if property in obj:
			obj[property] = value
		else:
			push_error("No method 'set_%s' or property '%s' found on object" % [property, property])

func get_game_property(obj, property: String, default_value = null):
	if not obj:
		push_error("Cannot get property from null object")
		return default_value
		
	if property.is_empty():
		push_error("Property name cannot be empty")
		return default_value
		
	# Check if the object has the method directly, or try a generic getter
	var result = null
	if obj.has_method("get_" + property):
		result = _call_node_method(obj, "get_" + property, [])
	elif obj.has_method("get"):
		result = _call_node_method(obj, "get", [property])
	elif property in obj:
		# Direct property access
		result = obj.get(property)
	else:
		push_error("No method 'get_%s' or property '%s' found on object" % [property, property])
		
	return result if result != null else default_value

# Custom assertion helpers
func assert_fail(message: String) -> void:
	assert_true(false, message)

# Add missing assertion helpers
func assert_le(got, expected, text = ""):
	var passed = (got <= expected)
	var msg = text
	if msg == "":
		msg = "Expected [" + str(got) + "] to be less than or equal to [" + str(expected) + "]"
	
	if passed:
		_pass(msg)
	else:
		_fail(msg)
	return passed

func assert_ge(got, expected, text = ""):
	var passed = (got >= expected)
	var msg = text
	if msg == "":
		msg = "Expected [" + str(got) + "] to be greater than or equal to [" + str(expected) + "]"
	
	if passed:
		_pass(msg)
	else:
		_fail(msg)
	return passed

func verify_signal_emitted(emitter, signal_name: String, message = ""):
	assert_signal_emitted(emitter, signal_name, message if message else "Signal %s should have been emitted" % signal_name)

func verify_signal_not_emitted(emitter, signal_name: String, message = ""):
	assert_signal_not_emitted(emitter, signal_name, message if message else "Signal %s should not have been emitted" % signal_name)