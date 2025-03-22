@tool
extends "res://tests/fixtures/base/base_test.gd"
# Use explicit preloads instead of global class names
const GameTestScript = preload("res://tests/fixtures/base/game_test.gd")
const TestHelperScript = preload("res://tests/fixtures/base/test_helper.gd")

# Make GameEnums a reference to GlobalEnums for backward compatibility
# All test code should use GameEnums or GlobalEnums consistently
const GameEnums = preload("res://src/core/systems/GlobalEnums.gd")

# Add TestEnums constant to make the test helper available to all tests
const TestEnums = preload("res://tests/fixtures/base/test_helper.gd")

## Base class for game-specific tests
##
## Provides common functionality for testing game features, state management,
## and game-specific assertions.

# Type-safe script references with null checks
const GameStateScript: GDScript = preload("res://src/core/state/GameState.gd")
const TestHelper: GDScript = preload("res://tests/fixtures/helpers/test_helper.gd")
# TypeSafeMixin is already imported in the parent class

# Game test constants with explicit types
const STABILIZE_TIME: float = 0.1 as float

# Game test configuration
const GAME_TEST_CONFIG := {
	"auto_save": false as bool,
	"debug_mode": true as bool,
	"test_mode": true as bool
}

# Default game state
const DEFAULT_GAME_STATE := {
	"difficulty_level": GameEnums.DifficultyLevel.NORMAL as int,
	"enable_permadeath": true as bool,
	"use_story_track": true as bool,
	"auto_save_enabled": true as bool,
	"last_save_time": 0 as int
}

# Type-safe instance variables
var _game_state: Node = null
var _test_nodes: Array[Node] = []
var _test_resources: Array[Resource] = []
var _game_settings: Dictionary = {}
var _original_window_size: Vector2i
var _original_window_mode: DisplayServer.WindowMode
var _fps_samples: Array[float] = []

## Lifecycle methods

func before_each() -> void:
	await super.before_each()
	_test_nodes.clear()
	_test_resources.clear()
	_setup_game_environment()
	await stabilize_engine(STABILIZE_TIME)

func after_each() -> void:
	_restore_game_environment()
	await _cleanup_game_resources()
	await super.after_each()

## Environment management

func _setup_game_environment() -> void:
	# Store original window settings
	_original_window_size = DisplayServer.window_get_size()
	_original_window_mode = DisplayServer.window_get_mode()
	
	# Set up test environment
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	get_tree().root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	
	# Initialize game state
	_game_state = create_test_game_state()
	if _game_state:
		add_child_autofree(_game_state)
		track_test_node(_game_state)

func _restore_game_environment() -> void:
	# Restore window settings
	DisplayServer.window_set_size(_original_window_size)
	DisplayServer.window_set_mode(_original_window_mode)
	
	# Cleanup game state
	_game_state = null
	_game_settings.clear()

func _cleanup_game_resources() -> void:
	# Clean up in reverse order
	for i in range(_test_nodes.size() - 1, -1, -1):
		var node := _test_nodes[i]
		if is_instance_valid(node):
			if node.is_inside_tree():
				node.queue_free()
			_test_nodes.remove_at(i)
	
	for i in range(_test_resources.size() - 1, -1, -1):
		var resource := _test_resources[i]
		if resource:
			# Don't try to free RefCounted resources - just remove the reference
			# and let reference counting handle cleanup
			resource = null
		_test_resources.remove_at(i)

## Resource management

func create_test_game_state() -> Node:
	if not GameStateScript:
		push_error("GameStateScript is null, cannot create game state")
		return null
		
	# Create a new state instance
	var state_instance: Node = null
	
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
			push_error("Game state instance missing required method: %s" % method)
			return null
	
	# Initialize with default state
	TypeSafeMixin._call_node_method_bool(state_instance, "set_difficulty_level", [DEFAULT_GAME_STATE.difficulty_level])
	TypeSafeMixin._call_node_method_bool(state_instance, "set_enable_permadeath", [DEFAULT_GAME_STATE.enable_permadeath])
	TypeSafeMixin._call_node_method_bool(state_instance, "set_use_story_track", [DEFAULT_GAME_STATE.use_story_track])
	TypeSafeMixin._call_node_method_bool(state_instance, "set_auto_save_enabled", [DEFAULT_GAME_STATE.auto_save_enabled])
	TypeSafeMixin._call_node_method_bool(state_instance, "set_last_save_time", [DEFAULT_GAME_STATE.last_save_time])
	
	return state_instance

func track_test_node(node: Node) -> void:
	if not node:
		return
	
	if _test_nodes.has(node):
		return
	
	_test_nodes.append(node)

func track_test_resource(resource: Resource) -> void:
	if not resource:
		return
	
	if _test_resources.has(resource):
		return
	
	_test_resources.append(resource)

func create_test_resource(resource_type: GDScript) -> Resource:
	if not resource_type:
		push_error("Cannot create resource from null type")
		return null
	
	var resource: Resource = resource_type.new()
	if not resource:
		push_error("Failed to create resource instance")
		return null
	
	track_test_resource(resource)
	return resource

func create_test_node(node_type: GDScript) -> Node:
	if not node_type:
		push_error("Cannot create node from null type")
		return null
	
	var node: Node = node_type.new()
	if not node:
		push_error("Failed to create node instance")
		return null
	
	add_child_autofree(node)
	track_test_node(node)
	return node

## Game state verification

func verify_game_state(state: Node, expected_state: Dictionary) -> void:
	if not state:
		push_error("Cannot verify null game state")
		return
	
	if not expected_state:
		push_error("Expected state dictionary is empty or null")
		return
	
	for property in expected_state:
		# Ensure the property is a string for method construction
		var property_name: String = property as String
		if property_name.is_empty():
			push_error("Invalid property name in expected state")
			continue
			
		# Try to get method name
		var method_name: String = "get_" + property_name
		
		# Check if the method exists
		if not state.has_method(method_name):
			push_error("State object missing method: %s" % method_name)
			continue
			
		# Get values and compare
		var actual_value = TypeSafeMixin._call_node_method(state, method_name, [])
		var expected_value = expected_state[property]
		
		# Handle null values
		if actual_value == null:
			push_warning("State property '%s' returned null" % property_name)
			
		# Perform the comparison with detailed error message
		assert_eq(actual_value, expected_value,
			"Game state %s should be %s but was %s" % [property, expected_value, actual_value])

func assert_valid_game_state(state: Node) -> void:
	if not state:
		push_error("Game state is null")
		assert_false(true, "Game state is null")
		return
	
	assert_true(state.is_inside_tree(), "Game state should be in scene tree")
	assert_true(state.is_processing(), "Game state should be processing")
	
	# Verify essential properties
	var phase: int = TypeSafeMixin._call_node_method_int(state, "get_current_phase", [], GlobalEnums.FiveParcsecsCampaignPhase.NONE)
	var turn: int = TypeSafeMixin._call_node_method_int(state, "get_turn_number", [], 0)
	
	assert_true(phase >= GlobalEnums.FiveParcsecsCampaignPhase.NONE, "Invalid game phase")
	assert_true(turn >= 0, "Invalid turn number")

## Stabilization helpers

func stabilize_engine(time: float = STABILIZE_TIME) -> void:
	await get_tree().create_timer(time).timeout
	await get_tree().process_frame
	await get_tree().process_frame

func stabilize_game_state(time: float = STABILIZE_TIME) -> void:
	if _game_state:
		await stabilize_engine(time)

## Game-specific assertions

func assert_game_property(obj: Object, property: String, expected_value, message: String = "") -> void:
	if not obj:
		push_error("Cannot assert property on null object")
		assert_true(false, "Object is null")
		return
		
	if property.is_empty():
		push_error("Property name cannot be empty")
		assert_true(false, "Empty property name")
		return
		
	# Try to get the property value using our helper method
	var actual_value = get_game_property(obj, property)
	
	# Generate a default message if none provided
	if message.is_empty():
		message = "Game property %s should be %s but was %s" % [property, expected_value, actual_value]
		
	# Perform the comparison
	assert_eq(actual_value, expected_value, message)

func assert_game_state(state_value: int, message: String = "") -> void:
	if not _game_state:
		push_error("Game state is null")
		assert_false(true, "Game state is null")
		return
	
	var current_state: int = TypeSafeMixin._call_node_method_int(_game_state, "get_current_phase", [], GlobalEnums.FiveParcsecsCampaignPhase.NONE)
	if message.is_empty():
		message = "Game state should be %s but was %s" % [state_value, current_state]
	assert_eq(current_state, state_value, message)

func assert_game_turn(turn_value: int, message: String = "") -> void:
	if not _game_state:
		push_error("Game state is null")
		assert_false(true, "Game state is null")
		return
	
	var current_turn: int = TypeSafeMixin._call_node_method_int(_game_state, "get_turn_number", [], 0)
	if message.is_empty():
		message = "Game turn should be %s but was %s" % [turn_value, current_turn]
	assert_eq(current_turn, turn_value, message)

## Performance testing

func measure_game_performance(test_function: Callable, iterations: int = 30) -> Dictionary:
	if not test_function.is_valid():
		push_error("Invalid test function provided")
		return {}
		
	if iterations <= 0:
		push_error("Iterations must be > 0")
		return {}
		
	_fps_samples.clear()
	var memory_before: int = Performance.get_monitor(Performance.MEMORY_STATIC)
	var draw_calls_before: int = Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
	
	var start_time: int = Time.get_ticks_msec()
	
	for i in range(iterations):
		await test_function.call()
		_fps_samples.append(Engine.get_frames_per_second())
	
	var end_time: int = Time.get_ticks_msec()
	var memory_after: int = Performance.get_monitor(Performance.MEMORY_STATIC)
	var draw_calls_after: int = Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
	
	# Calculate metrics
	var total_fps: float = 0.0
	var min_fps: float = 1000.0
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

func verify_performance_metrics(metrics: Dictionary, thresholds: Dictionary) -> void:
	if metrics == null or thresholds == null:
		push_error("Cannot verify null metrics or thresholds")
		return
		
	for key in thresholds:
		if not metrics.has(key):
			push_error("Performance metrics missing required key: %s" % key)
			assert_true(false, "Performance metrics should include %s" % key)
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

func set_game_property(obj: Object, property: String, value) -> void:
	if not obj:
		push_error("Cannot set property on null object")
		return
		
	if property.is_empty():
		push_error("Property name cannot be empty")
		return
		
	# Check if the object has the method directly, or try a generic setter
	if obj.has_method("set_" + property):
		TypeSafeMixin._call_node_method_bool(obj, "set_" + property, [value])
	elif obj.has_method("set"):
		TypeSafeMixin._call_node_method_bool(obj, "set", [property, value])
	else:
		# If no setter method exists, try direct property assignment
		if property in obj:
			obj[property] = value
		else:
			push_error("No method 'set_%s' or property '%s' found on object" % [property, property])

func get_game_property(obj: Object, property: String, default_value = null) -> Variant:
	if not obj:
		push_error("Cannot get property from null object")
		return default_value
		
	if property.is_empty():
		push_error("Property name cannot be empty")
		return default_value
		
	# Check if the object has the method directly, or try a generic getter
	var result = null
	if obj.has_method("get_" + property):
		result = TypeSafeMixin._call_node_method(obj, "get_" + property, [])
	elif obj.has_method("get"):
		result = TypeSafeMixin._call_node_method(obj, "get", [property])
	elif property in obj:
		# Direct property access
		result = obj.get(property)
	else:
		push_error("No method 'get_%s' or property '%s' found on object" % [property, property])
		
	return result if result != null else default_value

func add_child_autofree(node: Node, call_ready: bool = true) -> void:
	if not node:
		push_error("Cannot add null node")
		return
		
	add_child(node, call_ready)
	track_test_node(node) # This will ensure the node gets freed during cleanup

func _init() -> void:
	# Verify critical dependencies
	if not GameStateScript:
		push_warning("GameStateScript dependency is not loaded")
