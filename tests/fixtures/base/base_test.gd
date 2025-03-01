@tool
extends "res://addons/gut/test.gd"
class_name BaseTest

# Core test class that all test scripts should extend from
const GutMainClass: GDScript = preload("res://addons/gut/gut.gd")
const GutUtilsClass: GDScript = preload("res://addons/gut/utils.gd")
const GlobalEnumsClass: GDScript = preload("res://src/core/systems/GlobalEnums.gd")
const SignalWatcher: GDScript = preload("res://addons/gut/signal_watcher.gd")
const TypeSafeMixin := preload("res://tests/fixtures/helpers/type_safe_test_mixin.gd")

# Test configuration constants
const BASE_SIGNAL_TIMEOUT: float = 1.0
const FRAME_TIMEOUT: float = 3.0
const ASYNC_TIMEOUT: float = 5.0
const STABILIZATION_TIME: float = 0.1

# Type-safe test configuration
const TEST_CONFIG := {
	"physics_fps": 60 as int,
	"max_fps": 60 as int,
	"debug_collisions": false as bool,
	"debug_navigation": false as bool,
	"audio_enabled": false as bool
}

# Type-safe error handling (from TypeSafeMixin)
const ERROR_INVALID_OBJECT := "Invalid object provided"
const ERROR_INVALID_PROPERTY := "Invalid property name provided"
const ERROR_INVALID_METHOD := "Invalid method name provided"
const ERROR_PROPERTY_NOT_FOUND := "Property '%s' not found in object"
const ERROR_METHOD_NOT_FOUND := "Method '%s' not found in object"
const ERROR_TYPE_MISMATCH := "Type mismatch: expected %s but got %s"
const ERROR_CAST_FAILED := "Failed to cast %s to %s: %s"

# Type-safe instance variables
var _was_ready_called := false
var _skip_script := false
var _skip_reason := ""
var _logger: Node = null
var _original_engine_config := {}
var _tracked_nodes: Array[Node] = []
var _tracked_resources: Array[Resource] = []
var _tracked_signals: Dictionary = {}
var _internal_signal_watcher: SignalWatcher = null
var _signal_emissions: Dictionary = {}
var fps_samples: Array[float] = []
var _error_count: int = 0
var _warning_count: int = 0
var _last_error: String = ""

# Type-safe GUT property
var gut: GutMainClass:
	get: return _gut
	set(value): _gut = value
var _gut: GutMainClass = null

func _init() -> void:
	_logger = GutUtilsClass.get_logger()
	if not _logger:
		push_error("Failed to initialize logger")
		return
	_logger.set_gut(self)
	_internal_signal_watcher = SignalWatcher.new(self)
	if not _internal_signal_watcher:
		push_error("Failed to create signal watcher")
		return

# Lifecycle Methods
func before_all() -> void:
	await get_tree().process_frame

func after_all() -> void:
	cleanup_resources()
	await get_tree().process_frame

func before_each() -> void:
	await super.before_each()
	_reset_tracking()
	_setup_test_environment()
	await stabilize_engine()

func after_each() -> void:
	await _cleanup_test_resources()
	_reset_tracking()
	await super.after_each()

# Type-safe method calls (from TypeSafeMixin)
func _call_node_method(obj: Object, method: String, args: Array = []) -> Variant:
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

func _call_node_method_bool(obj: Object, method: String, args: Array = [], default: bool = false) -> bool:
	var result = _call_node_method(obj, method, args)
	if result == null:
		return default
	if result is bool:
		return result
	if result is int:
		return bool(result)
	push_error(ERROR_TYPE_MISMATCH % ["bool", TypeSafeMixin.typeof_as_string(result)])
	return default

func set_logger(logger: Node) -> void:
	if not logger:
		push_error("Cannot set null logger")
		return
	_logger = logger
	_logger.set_gut(self)

# Signal watching functions
func watch_signals(emitter: Object) -> void:
	if not emitter:
		push_error("Cannot watch signals for null emitter")
		return
	if not _internal_signal_watcher:
		push_error("Signal watcher not initialized")
		return
	_internal_signal_watcher.watch_signals(emitter)
	_tracked_signals[emitter] = true

func assert_signal_emitted(emitter: Object, signal_name: String, text: String = "") -> void:
	if not _internal_signal_watcher:
		push_error("Signal watcher not initialized")
		return
	
	_internal_signal_watcher.assert_signal_emitted(emitter, signal_name)

func assert_signal_not_emitted(emitter: Object, signal_name: String, text: String = "") -> void:
	if not _internal_signal_watcher:
		push_error("Signal watcher not initialized")
		return
	
	_internal_signal_watcher.assert_signal_not_emitted(emitter, signal_name)

func assert_signal_emit_count(emitter: Object, signal_name: String, count: int, text: String = "") -> void:
	if not _internal_signal_watcher:
		push_error("Signal watcher not initialized")
		return
	
	_internal_signal_watcher.assert_signal_emit_count(emitter, signal_name, count, text)

func get_signal_parameters(emitter: Object, signal_name: String, index: int = -1) -> Array:
	if not _internal_signal_watcher:
		push_error("Signal watcher not initialized")
		return []
	return _internal_signal_watcher.get_signal_parameters(emitter, signal_name, index)

func get_signal_emit_count(emitter: Object, signal_name: String) -> int:
	if not _internal_signal_watcher:
		push_error("Signal watcher not initialized")
		return 0
	return _internal_signal_watcher.get_emit_count(emitter, signal_name)


# Performance monitoring with type safety
var _performance_monitors := {
	"memory": Performance.MEMORY_STATIC as int,
	"draw_calls": Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME as int,
	"objects": Performance.OBJECT_NODE_COUNT as int
}


# Type validation helpers
static func _is_valid_number(value: Variant) -> bool:
	var type := typeof(value)
	return type == TYPE_INT or type == TYPE_FLOAT

static func _is_valid_string(value: Variant) -> bool:
	var type := typeof(value)
	return type == TYPE_STRING or type == TYPE_STRING_NAME or type == TYPE_NODE_PATH

static func _is_valid_bool(value: Variant) -> bool:
	var type := typeof(value)
	return type == TYPE_BOOL or type == TYPE_INT or type == TYPE_FLOAT

# Type conversion with validation
static func _to_int_safe(value: Variant) -> int:
	match typeof(value):
		TYPE_INT:
			return value
		TYPE_BOOL:
			return 1 if value else 0
		TYPE_FLOAT:
			var float_val: float = value
			return int(float_val)
		TYPE_STRING:
			var str_val: String = value
			if str_val.is_valid_int():
				return str_val.to_int()
	return 0

static func _to_bool_safe(value: Variant) -> bool:
	match typeof(value):
		TYPE_BOOL:
			return value
		TYPE_INT:
			var int_val: int = value
			return int_val != 0
		TYPE_FLOAT:
			var float_val: float = value
			return float_val != 0.0
		TYPE_STRING:
			var str_val: String = value
			var lower: String = str_val.to_lower()
			return lower == "true" or lower == "1" or lower == "yes" or lower == "on"
	return false

static func _to_string_safe(value: Variant) -> String:
	match typeof(value):
		TYPE_STRING:
			return value
		TYPE_STRING_NAME:
			var str_name: StringName = value
			return String(str_name)
		TYPE_NODE_PATH:
			var path: NodePath = value
			return String(path)
		_:
			if _is_valid_number(value) or _is_valid_bool(value):
				return str(value)
	return ""

# GUT Required Methods with type safety
func get_gut() -> GutMainClass:
	return _gut if _gut else get_parent() as GutMainClass

func set_gut(new_gut: GutMainClass) -> void:
	_gut = new_gut

func get_skip_reason() -> String:
	return _skip_reason

func should_skip_script() -> bool:
	return _skip_script

func _do_ready_stuff() -> void:
	_was_ready_called = true


# Resource Management with type safety
func track_test_node(node: Node) -> void:
	if not node:
		push_error("Cannot track null node")
		return
	if not node in _tracked_nodes:
		_tracked_nodes.append(node)

func track_test_resource(resource: Resource) -> void:
	if not resource:
		push_error("Cannot track null resource")
		return
	if not resource in _tracked_resources:
		_tracked_resources.append(resource)

func cleanup_nodes() -> void:
	if not _tracked_nodes is Array:
		return
		
	for node: Node in _tracked_nodes:
		if node is Node and is_instance_valid(node) and not node.is_queued_for_deletion():
			node.queue_free()
	_tracked_nodes.clear()

func cleanup_resources() -> void:
	cleanup_nodes()
	await get_tree().process_frame
	
	if not _tracked_resources is Array:
		return
		
	for resource: Resource in _tracked_resources:
		if resource is Resource and not resource.is_queued_for_deletion():
			resource = null
	_tracked_resources.clear()

# Type-safe assertion helpers
func _assert_eq_safe(got: Variant, expected: Variant, text: String = "") -> void:
	var got_type := typeof(got)
	var expected_type := typeof(expected)
	
	if got_type != expected_type:
		var converted_got: Variant = got
		match expected_type:
			TYPE_INT:
				if _is_valid_number(got):
					converted_got = int(float(got))
			TYPE_FLOAT:
				if _is_valid_number(got):
					converted_got = float(got)
			TYPE_STRING:
				if _is_valid_string(got):
					converted_got = String(got)
			TYPE_BOOL:
				if _is_valid_bool(got):
					converted_got = bool(got)
		got = converted_got
	
	assert_eq(got, expected, text)

func verify_state(subject: Object, expected_states: Dictionary) -> void:
	if not subject or not expected_states:
		return
		
	for property_name: String in expected_states:
		if not property_name is String:
			continue
			
		var property: String = property_name
		if property in subject:
			var actual_value: Variant = subject.get(property)
			var expected_value: Variant = expected_states[property]
			_assert_eq_safe(actual_value, expected_value,
				"Property %s should match expected state" % property)

# Engine Stabilization with type safety
func stabilize_engine(time: float = STABILIZATION_TIME) -> void:
	await get_tree().create_timer(time).timeout

func wait_frames(frames: int) -> void:
	var i := 0
	while i < frames:
		await get_tree().process_frame
		i += 1

func wait_physics_frames(frames: int) -> void:
	var i := 0
	while i < frames:
		await get_tree().physics_frame
		i += 1

# Async Operation Helpers with type safety
func with_timeout(operation: Callable, timeout: float = FRAME_TIMEOUT) -> Variant:
	var timer := get_tree().create_timer(timeout)
	if not timer:
		push_error("Failed to create timer")
		return null
		
	var result: Variant = null
	var completed := false
	
	operation.call_deferred(func(value: Variant = null) -> void:
		result = value
		completed = true
	)
	
	# Handle timeout
	var timeout_handler := func() -> void: completed = true
	var _connect_result := timer.timeout.connect(timeout_handler, CONNECT_ONE_SHOT)
	
	while not completed and timer and not timer.is_stopped():
		await get_tree().process_frame
	
	return result

# Performance Testing with type safety
func measure_mobile_performance(callable: Callable, iterations: int = 100) -> Dictionary:
	var monitors := {
		"memory": Performance.MEMORY_STATIC as int,
		"draw_calls": Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME as int,
		"objects": Performance.OBJECT_NODE_COUNT as int
	}
	
	var start_values := _get_monitor_values_safe(monitors)
	fps_samples.clear()
	
	for i in range(iterations):
		var frame_time := await _measure_frame_time_safe(callable)
		var fps := _calculate_fps_safe(frame_time)
		fps_samples.push_back(fps)
	
	var end_values := _get_monitor_values_safe(monitors)
	return _calculate_performance_metrics_safe(start_values, end_values, fps_samples)

func _get_monitor_values_safe(monitors: Dictionary) -> Dictionary:
	var values: Dictionary = {} as Dictionary
	for key: String in monitors:
		var monitor_id: int = monitors[key] as int
		var value: int = _to_int_safe(Performance.get_monitor(monitor_id))
		values[key] = value
	return values

func _measure_frame_time_safe(callable: Callable) -> float:
	var start_time := Time.get_ticks_usec()
	callable.call()
	await get_tree().process_frame
	var end_time := Time.get_ticks_usec()
	return float(end_time - start_time) / 1000.0

func _calculate_fps_safe(frame_time: float) -> float:
	return 1000.0 / frame_time if frame_time > 0.0 else 0.0

func _calculate_performance_metrics_safe(start_values: Dictionary, end_values: Dictionary, samples: Array[float]) -> Dictionary:
	var metrics := {
		"average_fps": 0.0,
		"95th_percentile_fps": 0.0,
		"minimum_fps": 0.0,
		"memory_delta_kb": 0.0,
		"draw_calls_delta": 0,
		"objects_delta": 0,
		"iterations": samples.size()
	}
	
	if not samples.is_empty():
		samples.sort()
		metrics.average_fps = _calculate_average_safe(samples)
		metrics["95th_percentile_fps"] = _calculate_percentile_safe(samples, 0.95)
		metrics.minimum_fps = samples[0]
	
	for key in start_values:
		var start := start_values[key] as int
		var end := end_values[key] as int
		var delta := end - start
		
		match key:
			"memory":
				metrics.memory_delta_kb = float(delta) / 1024.0
			"draw_calls":
				metrics.draw_calls_delta = delta
			"objects":
				metrics.objects_delta = delta
	
	return metrics

func _calculate_average_safe(samples: Array[float]) -> float:
	if samples.is_empty():
		return 0.0
	var total: float = samples.reduce(func(accum: float, val: float) -> float: return accum + val)
	return total / float(samples.size())

func _calculate_percentile_safe(samples: Array[float], percentile: float) -> float:
	if samples.is_empty():
		return 0.0
	var index := int(float(samples.size()) * percentile)
	return samples[index]

# Enhanced Resource Management
func _cleanup_tracked_resources() -> void:
	var valid_resources: Array[Resource] = []
	for resource in _tracked_resources:
		if resource is Resource and not resource.is_queued_for_deletion():
			resource.free()
		else:
			valid_resources.push_back(resource)
	_tracked_resources = valid_resources
	
	var valid_nodes: Array[Node] = []
	for node in _tracked_nodes:
		if is_instance_valid(node) and node.is_inside_tree():
			node.queue_free()
		else:
			valid_nodes.push_back(node)
	_tracked_nodes = valid_nodes

# Enhanced Engine Configuration Management
func _store_engine_config() -> void:
	_original_engine_config = {
		"physics_fps": Engine.physics_ticks_per_second as int,
		"max_fps": Engine.max_fps as int,
		"debug_collisions": get_tree().debug_collisions_hint as bool,
		"debug_navigation": get_tree().debug_navigation_hint as bool,
		"audio_enabled": AudioServer.is_bus_mute(AudioServer.get_bus_index("Master")) as bool
	}

func _apply_test_config() -> void:
	for key in TEST_CONFIG:
		match key:
			"physics_fps":
				Engine.physics_ticks_per_second = TEST_CONFIG[key] as int
			"max_fps":
				Engine.max_fps = TEST_CONFIG[key] as int
			"debug_collisions":
				get_tree().set_debug_collisions_hint(TEST_CONFIG[key] as bool)
			"debug_navigation":
				get_tree().set_debug_navigation_hint(TEST_CONFIG[key] as bool)
			"audio_enabled":
				var master_bus := AudioServer.get_bus_index("Master")
				if master_bus >= 0:
					AudioServer.set_bus_mute(master_bus, TEST_CONFIG[key] as bool)

func _restore_engine_config() -> void:
	if not _original_engine_config is Dictionary:
		return
		
	for key in _original_engine_config:
		match key:
			"physics_fps":
				Engine.physics_ticks_per_second = _original_engine_config[key] as int
			"max_fps":
				Engine.max_fps = _original_engine_config[key] as int
			"debug_collisions":
				get_tree().set_debug_collisions_hint(_original_engine_config[key] as bool)
			"debug_navigation":
				get_tree().set_debug_navigation_hint(_original_engine_config[key] as bool)
			"audio_enabled":
				var master_bus := AudioServer.get_bus_index("Master")
				if master_bus >= 0:
					AudioServer.set_bus_mute(master_bus, _original_engine_config[key] as bool)

# Signal verification with type safety
func verify_signal_emitted(emitter: Object, signal_name: String, message: String = "") -> void:
	if not emitter or not signal_name:
		push_error("Invalid emitter or signal name")
		return
	
	assert_true(_internal_signal_watcher.did_emit(emitter, signal_name),
		message if message else "Signal %s should have been emitted" % signal_name)

func verify_signal_not_emitted(emitter: Object, signal_name: String, message: String = "") -> void:
	if not emitter or not signal_name:
		push_error("Invalid emitter or signal name")
		return
	
	assert_false(_internal_signal_watcher.did_emit(emitter, signal_name),
		message if message else "Signal %s should not have been emitted" % signal_name)

# Type-safe property access
func _get_property_safe(obj: Object, property: String, default_value: Variant = null) -> Variant:
	if not obj or not property:
		push_error("Invalid object or property name")
		return default_value
	
	if not property in obj:
		push_error("Property '%s' not found in object" % property)
		return default_value
	
	return obj.get(property)

func _set_property_safe(obj: Object, property: String, value: Variant) -> void:
	if not obj or not property:
		push_error("Invalid object or property name")
		return
	
	if not property in obj:
		push_error("Property '%s' not found in object" % property)
		return
	
	obj.set(property, value)

# Type-safe method calls


func _call_node_method_int(obj: Object, method: String, args: Array = [], default_value: int = 0) -> int:
	var result = _call_node_method(obj, method, args)
	if result is int:
		return result
	push_error("Method '%s' did not return an integer" % method)
	return default_value


func _call_node_method_array(obj: Object, method: String, args: Array = [], default_value: Array = []) -> Array:
	var result = _call_node_method(obj, method, args)
	if result is Array:
		return result
	push_error("Method '%s' did not return an array" % method)
	return default_value

func _call_node_method_dict(obj: Object, method: String, args: Array = [], default_value: Dictionary = {}) -> Dictionary:
	var result = _call_node_method(obj, method, args)
	if result is Dictionary:
		return result
	push_error("Method '%s' did not return a dictionary" % method)
	return default_value

# Mobile testing functions
func simulate_mobile_environment(resolution_key: String, dpi_key: String = "xhdpi") -> void:
	if not resolution_key in MOBILE_RESOLUTIONS:
		push_error("Invalid mobile resolution key: %s" % resolution_key)
		return
	
	if not dpi_key in MOBILE_DPI:
		push_error("Invalid DPI key: %s" % dpi_key)
		return
	
	var resolution: Vector2i = MOBILE_RESOLUTIONS[resolution_key]
	var dpi: int = MOBILE_DPI[dpi_key]
	
	get_tree().root.content_scale_size = resolution
	# Note: DPI is simulated through content scale factor in Godot 4.x
	var scale_factor := float(dpi) / float(MOBILE_DPI["mdpi"])
	get_tree().root.content_scale_factor = scale_factor
	await stabilize_engine()

func assert_fits_mobile_screen(node: Node, resolution_key: String = "phone_portrait") -> void:
	if not node:
		push_error("Cannot check fit for null node")
		return
	
	if not resolution_key in MOBILE_RESOLUTIONS:
		push_error("Invalid mobile resolution key: %s" % resolution_key)
		return
	
	var screen_size: Vector2i = MOBILE_RESOLUTIONS[resolution_key]
	var node_size: Vector2 = node.get_rect().size
	
	assert_true(node_size.x <= screen_size.x,
		"Node width (%d) exceeds screen width (%d)" % [node_size.x, screen_size.x])
	assert_true(node_size.y <= screen_size.y,
		"Node height (%d) exceeds screen height (%d)" % [node_size.y, screen_size.y])

# Game state validation
func assert_valid_game_state(state: Node) -> void:
	if not state:
		push_error("Game state is null")
		assert_false(true, "Game state is null")
		return
	
	assert_true(state.is_inside_tree(), "Game state should be in scene tree")
	assert_true(state.is_processing(), "Game state should be processing")
	
	var required_methods := [
		"get_campaign_phase",
		"get_difficulty_level",
		"is_permadeath_enabled",
		"is_story_track_enabled",
		"is_auto_save_enabled"
	]
	
	for method in required_methods:
		assert_true(state.has_method(method),
			"Game state missing required method: %s" % method)

func verify_game_state(state: Node, expected_state: Dictionary) -> void:
	if not state:
		push_error("Cannot verify null game state")
		return
	
	for property in expected_state:
		var actual_value = _get_property_safe(state, property)
		var expected_value = expected_state[property]
		assert_eq(actual_value, expected_value,
			"Game state %s should be %s but was %s" % [property, expected_value, actual_value])

# Common test helper functions
func create_test_game_state() -> Node:
	var state: Node = Node.new()
	if not state:
		push_error("Failed to create game state node")
		return null
	
	track_test_node(state)
	return state

func create_test_campaign() -> Resource:
	var campaign: Resource = Resource.new()
	if not campaign:
		push_error("Failed to create campaign resource")
		return null
	
	track_test_resource(campaign)
	return campaign

func create_test_mission() -> Resource:
	var mission: Resource = Resource.new()
	if not mission:
		push_error("Failed to create mission resource")
		return null
	
	track_test_resource(mission)
	return mission

func create_test_character() -> Node:
	var character: Node = Node.new()
	if not character:
		push_error("Failed to create character node")
		return null
	
	track_test_node(character)
	return character

# Enhanced node management
func add_child_autofree(node: Node) -> void:
	if not node:
		push_error("Cannot add null node")
		return
	
	add_child(node)
	_tracked_nodes.append(node)

# Enhanced signal testing
func assert_async_signal(emitter: Object, signal_name: String, timeout: float = BASE_SIGNAL_TIMEOUT) -> bool:
	if not emitter or not signal_name:
		push_error("Invalid emitter or signal name")
		return false
	
	var timer := get_tree().create_timer(timeout)
	if not timer:
		push_error("Failed to create timer")
		return false
	
	var signal_received := false
	
	if emitter.has_signal(signal_name):
		var callable := func() -> void: signal_received = true
		emitter.connect(signal_name, callable, CONNECT_ONE_SHOT)
		timer.timeout.connect(func() -> void: signal_received = false, CONNECT_ONE_SHOT)
		
		while not signal_received and not timer.is_stopped():
			await get_tree().process_frame
	
	return signal_received

# Enhanced state verification
func verify_campaign_state(campaign: Resource, expected_state: Dictionary) -> void:
	if not campaign:
		push_error("Cannot verify null campaign")
		return
	
	for property in expected_state:
		var actual_value = _get_property_safe(campaign, property)
		var expected_value = expected_state[property]
		assert_eq(actual_value, expected_value,
			"Campaign %s should be %s but was %s" % [property, expected_value, actual_value])

func verify_mission_state(mission: Resource, expected_state: Dictionary) -> void:
	if not mission:
		push_error("Cannot verify null mission")
		return
	
	for property in expected_state:
		var actual_value = _get_property_safe(mission, property)
		var expected_value = expected_state[property]
		assert_eq(actual_value, expected_value,
			"Mission %s should be %s but was %s" % [property, expected_value, actual_value])

# Enhanced resource management
func verify_resource_cleanup() -> void:
	var resource_count := _tracked_resources.size()
	cleanup_resources()
	await get_tree().process_frame
	assert_eq(_tracked_resources.size(), 0,
		"All resources should be cleaned up (had %d tracked resources)" % resource_count)

func verify_node_cleanup() -> void:
	var node_count := _tracked_nodes.size()
	cleanup_nodes()
	await get_tree().process_frame
	assert_eq(_tracked_nodes.size(), 0,
		"All nodes should be cleaned up (had %d tracked nodes)" % node_count)

# Enhanced error handling
func verify_error_handling(callable: Callable, expected_error: String) -> void:
	var error_messages: Array[String] = []
	
	# Create error collector
	var error_collector := func(message: String) -> void:
		error_messages.append(message)
	
	# Run the test
	callable.call()
	
	# Verify error was received
	var error_found := false
	for message in error_messages:
		if message == expected_error:
			error_found = true
			break
	
	assert_true(error_found,
		"Expected error '%s' was not received" % expected_error)

# Enhanced performance testing
func verify_performance_metrics(metrics: Dictionary, requirements: Dictionary) -> void:
	for key in requirements:
		if key in metrics:
			var actual = metrics[key]
			var required = requirements[key]
			assert_true(actual >= required,
				"Performance metric '%s' (%s) does not meet requirement (%s)" % [key, actual, required])

func _reset_tracking() -> void:
	_tracked_nodes.clear()
	_tracked_resources.clear()
	_tracked_signals.clear()
	_error_count = 0
	_warning_count = 0
	_last_error = ""
	
	if _internal_signal_watcher:
		_internal_signal_watcher.clear()

func _setup_test_environment() -> void:
	Engine.physics_ticks_per_second = TEST_CONFIG.physics_fps
	Engine.max_fps = TEST_CONFIG.max_fps
	
	# Store original engine configuration
	_original_engine_config = {
		"physics_fps": Engine.physics_ticks_per_second as int,
		"max_fps": Engine.max_fps as int,
		"debug_collisions": false as bool,
		"debug_navigation": false as bool,
		"audio_enabled": false as bool
	}

func _cleanup_test_resources() -> void:
	# Clean up nodes in reverse order
	for i in range(_tracked_nodes.size() - 1, -1, -1):
		var node := _tracked_nodes[i]
		if is_instance_valid(node):
			if node.is_inside_tree():
				node.queue_free()
			_tracked_nodes.remove_at(i)
	
	# Clean up resources
	for i in range(_tracked_resources.size() - 1, -1, -1):
		var resource := _tracked_resources[i]
		if resource and not resource.is_queued_for_deletion():
			resource.free()
		_tracked_resources.remove_at(i)
	
	# Reset signal tracking
	_signal_emissions.clear()
	_tracked_signals.clear()

# Enhanced error handling
func push_test_error(error: String) -> void:
	_error_count += 1
	_last_error = error
	push_error(error)

func push_test_warning(warning: String) -> void:
	_warning_count += 1
	push_warning(warning)

# Type-safe utility methods
func wait_for_signal(emitter: Object, signal_name: String, timeout: float = BASE_SIGNAL_TIMEOUT) -> bool:
	if not emitter or not signal_name:
		push_test_error("Invalid emitter or signal name")
		return false
	return await _internal_signal_watcher.wait_for_signal(emitter, signal_name, timeout)

# Performance monitoring
func start_performance_monitoring() -> void:
	fps_samples.clear()
	Performance.get_monitor(Performance.TIME_FPS)
	Performance.get_monitor(Performance.MEMORY_STATIC)
	Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)

func stop_performance_monitoring() -> Dictionary:
	var avg_fps := 0.0
	if not fps_samples.is_empty():
		for fps in fps_samples:
			avg_fps += fps
		avg_fps /= fps_samples.size()
	
	return {
		"average_fps": avg_fps,
		"memory_usage": Performance.get_monitor(Performance.MEMORY_STATIC),
		"draw_calls": Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
	}

# Additional type-safe method calls
func _call_node_method_float(obj: Object, method: String, args: Array = [], default: float = 0.0) -> float:
	var result = _call_node_method(obj, method, args)
	if result == null:
		return default
	if result is float:
		return result
	if result is int:
		return float(result)
	if result is String and result.is_valid_float():
		return result.to_float()
	push_error(ERROR_TYPE_MISMATCH % ["float", TypeSafeMixin.typeof_as_string(result)])
	return default

func _call_node_method_string(obj: Object, method: String, args: Array = [], default: String = "") -> String:
	var result = _call_node_method(obj, method, args)
	if result == null:
		return default
	if result is String:
		return result
	push_error(ERROR_TYPE_MISMATCH % ["String", TypeSafeMixin.typeof_as_string(result)])
	return default

func _call_node_method_object(obj: Object, method: String, args: Array = [], default: Object = null) -> Object:
	var result = _call_node_method(obj, method, args)
	if result == null:
		return default
	if result is Object:
		return result
	push_error(ERROR_TYPE_MISMATCH % ["Object", TypeSafeMixin.typeof_as_string(result)])
	return default
	
func _call_node_method_vector2(obj: Object, method: String, args: Array = [], default: Vector2 = Vector2.ZERO) -> Vector2:
	var result = _call_node_method(obj, method, args)
	if result == null:
		return default
	if result is Vector2:
		return result
	push_error(ERROR_TYPE_MISMATCH % ["Vector2", TypeSafeMixin.typeof_as_string(result)])
	return default

# Mobile test configuration
const MOBILE_RESOLUTIONS := {
	"phone_portrait": Vector2i(1080, 1920),
	"phone_landscape": Vector2i(1920, 1080),
	"tablet_portrait": Vector2i(1600, 2560),
	"tablet_landscape": Vector2i(2560, 1600)
}

const MOBILE_DPI := {
	"mdpi": 160 as int,
	"hdpi": 240 as int,
	"xhdpi": 320 as int,
	"xxhdpi": 480 as int,
	"xxxhdpi": 640 as int
}

# Note: Touch target testing functionality moved to mobile_test.gd
# to avoid duplicate function declarations
