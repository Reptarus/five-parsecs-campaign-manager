@tool
class_name GameTest
extends BaseTest

## Base class for game-specific tests
##
## Provides common functionality for testing game features, state management,
## and game-specific assertions.

# Type-safe script references
const GameStateScript: GDScript = preload("res://src/core/state/GameState.gd")
const GameEnums: GDScript = preload("res://src/core/systems/GlobalEnums.gd")
const TestHelper: GDScript = preload("res://tests/fixtures/helpers/test_helper.gd")

# Game test constants with explicit types  
# Note: STABILIZE_TIME inherited from BaseTest

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

func before_test() -> void:
	await super.before_test()
	_test_nodes.clear()
	_test_resources.clear()
	_setup_game_environment()
	await stabilize_engine(STABILIZE_TIME)

func after_test() -> void:
	_restore_game_environment()
	await _cleanup_game_resources()
	await super.after_test()

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
		if resource and not resource.is_queued_for_deletion():
			resource.free()
		_test_resources.remove_at(i)

## Resource management

func create_test_game_state() -> Node:
	var state_instance: Node = GameStateScript.new()
	if not state_instance:
		push_error("Failed to create game state instance")
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
	
	for property in expected_state:
		var actual_value = TypeSafeMixin._call_node_method(state, "get_" + property, [])
		var expected_value = expected_state[property]
		assert_that(actual_value).is_equal(expected_value)

func assert_valid_game_state(state: Node) -> void:
	if not state:
		push_error("Game state is null")
		assert_that(false).is_true()
		return
	
	assert_that(state.is_inside_tree()).is_true()
	assert_that(state.is_processing()).is_true()
	
	# Verify essential properties
	var phase: int = TypeSafeMixin._call_node_method_int(state, "get_current_phase", [], GameEnums.FiveParcsecsCampaignPhase.NONE)
	var turn: int = TypeSafeMixin._call_node_method_int(state, "get_turn_number", [], 0)
	
	assert_that(phase >= GameEnums.FiveParcsecsCampaignPhase.NONE).is_true()
	assert_that(turn >= 0).is_true()

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
	var actual_value = TypeSafeMixin._call_node_method(obj, "get_" + property, [])
	if message.is_empty():
		message = "Game property %s should be %s but was %s" % [property, expected_value, actual_value]
	assert_that(actual_value).override_failure_message(message).is_equal(expected_value)

func assert_game_state(state_value: int, message: String = "") -> void:
	if not _game_state:
		push_error("Game state is null")
		assert_that(false).override_failure_message("Game state is null").is_true()
		return
	
	var current_state: int = TypeSafeMixin._call_node_method_int(_game_state, "get_current_phase", [], GameEnums.FiveParcsecsCampaignPhase.NONE)
	if message.is_empty():
		message = "Game state should be %s but was %s" % [state_value, current_state]
	assert_that(current_state).override_failure_message(message).is_equal(state_value)

func assert_game_turn(turn_value: int, message: String = "") -> void:
	if not _game_state:
		push_error("Game state is null")
		assert_that(false).override_failure_message("Game state is null").is_true()
		return
	
	var current_turn: int = TypeSafeMixin._call_node_method_int(_game_state, "get_turn_number", [], 0)
	if message.is_empty():
		message = "Game turn should be %s but was %s" % [turn_value, current_turn]
	assert_that(current_turn).override_failure_message(message).is_equal(turn_value)

## Performance testing

func measure_game_performance(test_function: Callable, iterations: int = 30) -> Dictionary:
	_fps_samples.clear()
	var memory_before := Performance.get_monitor(Performance.MEMORY_STATIC)
	var draw_calls_before := Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
	
	var start_time := Time.get_ticks_msec()
	
	for i in range(iterations):
		await test_function.call()
		_fps_samples.append(Engine.get_frames_per_second())
	
	var end_time := Time.get_ticks_msec()
	var memory_after := Performance.get_monitor(Performance.MEMORY_STATIC)
	var draw_calls_after := Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
	
	# Calculate metrics
	var total_fps := 0.0
	var min_fps := 1000.0
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
	for key in thresholds:
		assert_that(metrics.has(key)).override_failure_message("Performance metrics should include %s" % key).is_true()
		
		match key:
			"average_fps", "minimum_fps":
				# Higher is better
				assert_that(metrics[key]).override_failure_message("%s should exceed threshold" % key).is_greater(thresholds[key])
			"execution_time_ms", "memory_delta_kb", "draw_calls_delta":
				# Lower is better
				assert_that(metrics[key]).override_failure_message("%s should be below threshold" % key).is_less(thresholds[key])
			_:
				push_error("Unknown performance metric: %s" % key)

## Helper methods

func set_game_property(obj: Object, property: String, value) -> void:
	TypeSafeMixin._call_node_method_bool(obj, "set_" + property, [value])

func get_game_property(obj: Object, property: String, default_value = null):
	var result = TypeSafeMixin._call_node_method(obj, "get_" + property, [])
	return result if result != null else default_value

func add_child_autofree(node: Node) -> void:
	add_child(node)
	node.queue_free_on_exit = true
