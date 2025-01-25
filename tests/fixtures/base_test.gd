@tool
extends "res://addons/gut/test.gd"

# Base test class that all test scripts should extend from
class_name BaseTest

const GutMain := preload("res://addons/gut/gut.gd")
const GutUtils := preload("res://addons/gut/utils.gd")
const GameEnums := preload("res://src/core/systems/GlobalEnums.gd")

const SIGNAL_TIMEOUT := 5.0 # Global timeout for all async operations
const FRAME_TIMEOUT := 3.0 # Timeout for frame-based operations
const ASYNC_TIMEOUT := 5.0 # 5 second timeout for async operations
const STABILIZATION_TIME := 0.1 # 100ms for engine stabilization

# Test environment configuration
const TEST_CONFIG := {
	"physics_fps": 60,
	"max_fps": 60,
	"debug_collisions": false,
	"debug_navigation": false,
	"audio_enabled": false
}

# Mobile test constants
const MOBILE_RESOLUTIONS := {
	"phone_portrait": Vector2i(1080, 1920),
	"phone_landscape": Vector2i(1920, 1080),
	"tablet_portrait": Vector2i(1600, 2560),
	"tablet_landscape": Vector2i(2560, 1600)
}

const MOBILE_DPI := {
	"mdpi": 160,
	"hdpi": 240,
	"xhdpi": 320,
	"xxhdpi": 480,
	"xxxhdpi": 640
}

# Required GUT properties
var _was_ready_called := false
var _skip_script := false
var _skip_reason := ""
var _logger = null
var _original_window_size: Vector2i
var _original_screen_dpi: float
var _original_engine_config := {}

# This is the property that GUT will set directly
var gut: GutMain:
	get:
		return _gut
	set(value):
		_gut = value

var _tracked_nodes: Array[Node] = []
var _tracked_resources: Array[Resource] = []
var _signal_watcher = null
var _gut: GutMain = null

# Signal tracking
var _watched_signals := {}
var _signal_emissions := {}

# GUT Required Methods
func get_gut() -> GutMain:
	if not _gut:
		_gut = get_parent() as GutMain
	return _gut

func set_gut(gut: GutMain) -> void:
	_gut = gut

func get_skip_reason() -> String:
	return _skip_reason

func should_skip_script() -> bool:
	return _skip_script

func _do_ready_stuff() -> void:
	_was_ready_called = true

# Lifecycle Methods
func before_each() -> void:
	_tracked_nodes.clear()
	_tracked_resources.clear()
	if _signal_watcher:
		_signal_watcher.clear()
	
	# Store original engine configuration
	_store_engine_config()
	
	# Apply test configuration
	_apply_test_config()
	
	# Wait for engine to stabilize
	await stabilize_engine()

func after_each() -> void:
	# Restore engine configuration
	_restore_engine_config()
	
	# Clean up resources
	cleanup_resources()
	
	# Clean up nodes
	cleanup_nodes()
	
	if _signal_watcher:
		_signal_watcher.clear()

# Resource Management
func track_test_node(node: Node) -> void:
	if node:
		_tracked_nodes.append(node)

func track_test_resource(resource: Resource) -> void:
	if resource:
		_tracked_resources.append(resource)

func cleanup_nodes() -> void:
	for node in _tracked_nodes:
		if is_instance_valid(node) and not node.is_queued_for_deletion():
			node.queue_free()
	_tracked_nodes.clear()

func cleanup_resources() -> void:
	for resource in _tracked_resources:
		if resource and not resource.is_queued_for_deletion():
			resource.free()
	_tracked_resources.clear()

# Signal Management
func watch_signals(emitter: Object) -> void:
	if not _watched_signals.has(emitter):
		_watched_signals[emitter] = []
		_signal_emissions[emitter] = {}
	
	for signal_info in emitter.get_signal_list():
		var signal_name = signal_info["name"]
		if not signal_name in _watched_signals[emitter]:
			_watched_signals[emitter].append(signal_name)
			_signal_emissions[emitter][signal_name] = []
			# warning-ignore:return_value_discarded
			emitter.connect(signal_name, _on_watched_signal.bind(emitter, signal_name))

func _on_watched_signal(emitter: Object, signal_name: String, args := []) -> void:
	if _signal_emissions.has(emitter) and _signal_emissions[emitter].has(signal_name):
		_signal_emissions[emitter][signal_name].append(args)

# State Management
func verify_state(subject: Object, expected_states: Dictionary) -> void:
	for property in expected_states:
		assert_eq(subject[property], expected_states[property],
			"Property %s should match expected state" % property)

# Engine Stabilization
func stabilize_engine(time: float = STABILIZATION_TIME) -> void:
	await get_tree().create_timer(time).timeout

func wait_frames(frames: int) -> void:
	for i in range(frames):
		await get_tree().process_frame

func wait_physics_frames(frames: int) -> void:
	for i in range(frames):
		await get_tree().physics_frame

# Async Operation Helpers
func with_timeout(operation: Callable, timeout: float = FRAME_TIMEOUT) -> Variant:
	var timer = get_tree().create_timer(timeout)
	var done = false
	var result = null
	
	operation.call_deferred(func(value = null):
		result = value
		done = true
	)
	
	timer.timeout.connect(func(): done = true, CONNECT_ONE_SHOT)
	
	while not done:
		await get_tree().process_frame
	
	return result

# Performance Testing
func measure_performance(callable: Callable, iterations: int = 1000) -> Dictionary:
	var start_time = Time.get_ticks_msec()
	var memory_start = Performance.get_monitor(Performance.MEMORY_STATIC)
	
	for i in range(iterations):
		callable.call()
	
	var end_time = Time.get_ticks_msec()
	var memory_end = Performance.get_monitor(Performance.MEMORY_STATIC)
	
	return {
		"duration_ms": end_time - start_time,
		"avg_duration_ms": float(end_time - start_time) / iterations,
		"memory_delta": memory_end - memory_start,
		"iterations": iterations
	}

# Memory Leak Detection
func assert_no_leaks() -> void:
	var leaked_nodes = []
	for node in _tracked_nodes:
		if is_instance_valid(node) and not node.is_queued_for_deletion():
			leaked_nodes.append(node)
	
	var leaked_resources = []
	for resource in _tracked_resources:
		if resource and not resource.is_queued_for_deletion():
			leaked_resources.append(resource)
	
	assert_eq(leaked_nodes.size(), 0, "Found %d leaked nodes" % leaked_nodes.size())
	assert_eq(leaked_resources.size(), 0, "Found %d leaked resources" % leaked_resources.size())

# Internal Helpers
func _store_engine_config() -> void:
	_original_engine_config = {
		"physics_fps": Engine.physics_ticks_per_second,
		"max_fps": Engine.max_fps,
		"debug_collisions": get_tree().debug_collisions_hint,
		"debug_navigation": get_tree().debug_navigation_hint,
		"audio_enabled": AudioServer.is_bus_mute(AudioServer.get_bus_index("Master"))
	}

func _apply_test_config() -> void:
	Engine.physics_ticks_per_second = TEST_CONFIG.physics_fps
	Engine.max_fps = TEST_CONFIG.max_fps
	get_tree().set_debug_collisions_hint(TEST_CONFIG.debug_collisions)
	get_tree().set_debug_navigation_hint(TEST_CONFIG.debug_navigation)
	
	# Mute audio during tests
	var master_bus = AudioServer.get_bus_index("Master")
	if master_bus >= 0:
		AudioServer.set_bus_mute(master_bus, TEST_CONFIG.audio_enabled)

func _restore_engine_config() -> void:
	Engine.physics_ticks_per_second = _original_engine_config.physics_fps
	Engine.max_fps = _original_engine_config.max_fps
	get_tree().set_debug_collisions_hint(_original_engine_config.debug_collisions)
	get_tree().set_debug_navigation_hint(_original_engine_config.debug_navigation)
	
	# Restore audio
	var master_bus = AudioServer.get_bus_index("Master")
	if master_bus >= 0:
		AudioServer.set_bus_mute(master_bus, _original_engine_config.audio_enabled)

# Standard Assertions
func assert_signal_emitted(object: Object, signal_name: String, text: String = "") -> void:
	if not _signal_watcher:
		assert_true(false, "Signal watcher not initialized. Did you call watch_signals()?")
		return
	var did_emit = _signal_watcher.did_emit(object, signal_name)
	assert_true(did_emit, text if text else "Signal '%s' was not emitted" % signal_name)

func assert_signal_not_emitted(object: Object, signal_name: String, text: String = "") -> void:
	if not _signal_watcher:
		assert_true(false, "Signal watcher not initialized. Did you call watch_signals()?")
		return
	var did_emit = _signal_watcher.did_emit(object, signal_name)
	assert_false(did_emit, text if text else "Signal '%s' was emitted" % signal_name)

func assert_signal_emit_count(object: Object, signal_name: String, times: int, text: String = "") -> void:
	if not _signal_watcher:
		assert_true(false, "Signal watcher not initialized. Did you call watch_signals()?")
		return
	var count = _signal_watcher.get_emit_count(object, signal_name)
	assert_eq(count, times, text if text else "Signal '%s' emit count %d != %d" % [signal_name, count, times])

func assert_valid_game_state(game_state: Node) -> void:
	assert_not_null(game_state, "Game state should not be null")
	assert_true(is_instance_valid(game_state), "Game state should be valid")

# Utility Methods
func add_child_autofree(node: Node) -> Node:
	add_child(node)
	track_test_node(node)
	return node

func create_resource_autofree(resource: Resource) -> Resource:
	if resource and not resource.is_connected("tree_exited", _on_resource_freed):
		resource.connect("tree_exited", _on_resource_freed)
	return resource

func _on_resource_freed() -> void:
	await get_tree().process_frame

# Mobile test helpers
func simulate_mobile_environment(resolution: String = "phone_portrait", dpi: String = "xhdpi") -> void:
	var size = MOBILE_RESOLUTIONS.get(resolution, MOBILE_RESOLUTIONS.phone_portrait)
	var screen_dpi = MOBILE_DPI.get(dpi, MOBILE_DPI.xhdpi)
	
	DisplayServer.window_set_size(size)
	# Note: DPI can't be changed at runtime, this is for test verification only
	assert_eq(DisplayServer.screen_get_dpi(), screen_dpi,
		"Screen DPI should match target mobile density")

func simulate_touch_event(position: Vector2, pressed: bool = true) -> void:
	var event = InputEventScreenTouch.new()
	event.position = position
	event.pressed = pressed
	Input.parse_input_event(event)

func simulate_touch_drag(from: Vector2, to: Vector2, steps: int = 10) -> void:
	var event = InputEventScreenDrag.new()
	var step = (to - from) / steps
	
	for i in range(steps):
		event.position = from + step * i
		event.relative = step
		Input.parse_input_event(event)
		await get_tree().process_frame

func assert_fits_mobile_screen(control: Control, resolution: String = "phone_portrait") -> void:
	var size = MOBILE_RESOLUTIONS.get(resolution, MOBILE_RESOLUTIONS.phone_portrait)
	assert_true(control.get_rect().size.x <= size.x,
		"Control width should fit mobile screen")
	assert_true(control.get_rect().size.y <= size.y,
		"Control height should fit mobile screen")

func assert_touch_target_size(control: Control) -> void:
	var min_touch_size = Vector2(40, 40) # Minimum recommended touch target size
	var size = control.get_rect().size
	assert_true(size.x >= min_touch_size.x and size.y >= min_touch_size.y,
		"Touch target size should be at least %s pixels" % str(min_touch_size))

# Mobile performance helpers
func measure_mobile_performance(callable: Callable, iterations: int = 100) -> Dictionary:
	var fps_samples = []
	var memory_start = Performance.get_monitor(Performance.MEMORY_STATIC)
	var draw_calls_start = Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
	var objects_start = Performance.get_monitor(Performance.OBJECT_NODE_COUNT)
	
	for i in range(iterations):
		var start_time = Time.get_ticks_usec()
		callable.call()
		await get_tree().process_frame
		var end_time = Time.get_ticks_usec()
		var frame_time = (end_time - start_time) / 1000.0 # Convert to milliseconds
		fps_samples.append(1000.0 / frame_time if frame_time > 0 else 0)
	
	var memory_end = Performance.get_monitor(Performance.MEMORY_STATIC)
	var draw_calls_end = Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
	var objects_end = Performance.get_monitor(Performance.OBJECT_NODE_COUNT)
	
	# Calculate statistics
	fps_samples.sort()
	var avg_fps = fps_samples.reduce(func(accum, fps): return accum + fps, 0.0) / iterations
	var percentile_95_fps = fps_samples[int(iterations * 0.95)]
	var min_fps = fps_samples[0]
	
	return {
		"average_fps": avg_fps,
		"95th_percentile_fps": percentile_95_fps,
		"minimum_fps": min_fps,
		"memory_delta_kb": (memory_end - memory_start) / 1024,
		"draw_calls_delta": draw_calls_end - draw_calls_start,
		"objects_delta": objects_end - objects_start,
		"iterations": iterations
	}

# Logger Methods
func set_logger(logger) -> void:
	_logger = logger

func get_logger():
	return _logger

# Async signal assertions
func assert_async_signal(emitter: Object, signal_name: String, timeout: float = ASYNC_TIMEOUT) -> bool:
	watch_signals(emitter)
	var start_time = Time.get_ticks_msec()
	
	while Time.get_ticks_msec() - start_time < timeout * 1000:
		if _signal_emissions.has(emitter) and \
		   _signal_emissions[emitter].has(signal_name) and \
		   not _signal_emissions[emitter][signal_name].is_empty():
			return true
		await get_tree().process_frame
	
	return false

func assert_signal_emitted_with_args(emitter: Object, signal_name: String, args: Array, timeout: float = ASYNC_TIMEOUT) -> void:
	watch_signals(emitter)
	var start_time = Time.get_ticks_msec()
	
	while Time.get_ticks_msec() - start_time < timeout * 1000:
		if _signal_emissions.has(emitter) and \
		   _signal_emissions[emitter].has(signal_name):
			for emission in _signal_emissions[emitter][signal_name]:
				if emission == args:
					assert_true(true, "Signal %s emitted with expected args" % signal_name)
					return
		await get_tree().process_frame
	
	assert_true(false, "Signal %s not emitted with expected args within %f seconds" % [signal_name, timeout])

# Signal waiting utilities
func await_signals(signals: Array, timeout: float = ASYNC_TIMEOUT) -> Array:
	var results = []
	var start_time = Time.get_ticks_msec()
	
	for signal_info in signals:
		var emitter = signal_info[0]
		var signal_name = signal_info[1]
		watch_signals(emitter)
	
	while Time.get_ticks_msec() - start_time < timeout * 1000:
		var all_received = true
		results.clear()
		
		for signal_info in signals:
			var emitter = signal_info[0]
			var signal_name = signal_info[1]
			
			if _signal_emissions.has(emitter) and \
			   _signal_emissions[emitter].has(signal_name) and \
			   not _signal_emissions[emitter][signal_name].is_empty():
				results.append(_signal_emissions[emitter][signal_name].pop_front())
			else:
				all_received = false
				break
		
		if all_received:
			return results
		
		await get_tree().process_frame
	
	return []

func wait_for_signal(emitter: Object, signal_name: String, timeout: float = ASYNC_TIMEOUT) -> Array:
	watch_signals(emitter)
	var start_time = Time.get_ticks_msec()
	
	while Time.get_ticks_msec() - start_time < timeout * 1000:
		if _signal_emissions.has(emitter) and \
		   _signal_emissions[emitter].has(signal_name) and \
		   not _signal_emissions[emitter][signal_name].is_empty():
			return _signal_emissions[emitter][signal_name].pop_front()
		await get_tree().process_frame
	
	return []
