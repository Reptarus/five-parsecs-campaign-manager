@tool
extends GutTest
class_name BaseTest

# Base test class that all test scripts should extend from
const GutMainClass := preload("res://addons/gut/gut.gd")
const GutUtilsClass := preload("res://addons/gut/utils.gd")
const GlobalEnumsClass := preload("res://src/core/systems/GlobalEnums.gd")

const SIGNAL_TIMEOUT := 1.0 # seconds to wait for signals
const FRAME_TIMEOUT := 3.0 # Timeout for frame-based operations
const ASYNC_TIMEOUT := 5.0 # 5 second timeout for async operations
const STABILIZATION_TIME := 0.1 # seconds to wait for engine to stabilize

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
var _logger: Node = null
var _original_engine_config: Dictionary = {}

# This is the property that GUT will set directly
var gut: GutMainClass:
	get:
		return _gut
	set(value):
		_gut = value

var _tracked_nodes: Array[Node] = []
var _tracked_resources: Array[Resource] = []
var _signal_watcher: SignalWatcher = null
var _gut: GutMainClass = null

# Signal tracking
var _signal_emissions: Dictionary = {}

# Inner class for signal watching
class SignalWatcher:
	var _watched_signals: Dictionary = {}
	var _signal_emissions: Dictionary = {}
	var _parent: Node
	
	func _init(parent: Node) -> void:
		_parent = parent
	
	func watch_signals(emitter: Object) -> void:
		if not _watched_signals.has(emitter):
			_watched_signals[emitter] = []
			_signal_emissions[emitter] = {}
			
			for signal_info in emitter.get_signal_list():
				var signal_name: String = signal_info.get("name", "")
				if signal_name.is_empty():
					continue
				
				if _watched_signals[emitter] is Array:
					_watched_signals[emitter].append(signal_name)
				_signal_emissions[emitter][signal_name] = []
				
				# Connect with CONNECT_DEFERRED to avoid immediate callback
				if emitter.has_signal(signal_name):
					var connect_result := emitter.connect(signal_name,
						func(arg1: Variant = null, arg2: Variant = null, arg3: Variant = null,
								arg4: Variant = null, arg5: Variant = null) -> void:
							var args: Array = [arg1, arg2, arg3, arg4, arg5]
							# Remove null values from the end
							while not args.is_empty() and args[-1] == null:
								args.pop_back()
							_on_signal_emitted.call_deferred(emitter, signal_name, args),
						CONNECT_DEFERRED)
					if connect_result != OK:
						push_warning("Failed to connect signal %s" % signal_name)
	
	func _on_signal_emitted(emitter: Object, signal_name: String, args: Array) -> void:
		if _signal_emissions.has(emitter) and \
		   _signal_emissions[emitter] is Dictionary and \
		   _signal_emissions[emitter].has(signal_name) and \
		   _signal_emissions[emitter][signal_name] is Array:
			_signal_emissions[emitter][signal_name].append(args)
	
	func clear() -> void:
		for emitter: Object in _watched_signals:
			if is_instance_valid(emitter):
				for signal_name: String in _watched_signals[emitter]:
					if emitter.has_signal(signal_name):
						# Disconnect all signals
						var connections: Array = emitter.get_signal_connection_list(signal_name)
						for connection: Dictionary in connections:
							var callable: Callable = connection.get("callable", Callable())
							if callable.is_valid() and callable.get_object() == self:
								# Since disconnect() returns void, we just call it
								emitter.disconnect(signal_name, callable)
		_watched_signals.clear()
		_signal_emissions.clear()
	
	func has_signal_record(emitter: Object, signal_name: String) -> bool:
		return _signal_emissions.has(emitter) and _signal_emissions[emitter].has(signal_name)
	
	func get_signal_records(emitter: Object, signal_name: String) -> Array:
		if has_signal_record(emitter, signal_name):
			return _signal_emissions[emitter][signal_name]
		return []
	
	func assert_signal_emitted(emitter: Object, signal_name: String) -> bool:
		if has_signal_record(emitter, signal_name):
			var records: Array = get_signal_records(emitter, signal_name)
			return not records.is_empty()
		return false
	
	func assert_signal_not_emitted(emitter: Object, signal_name: String) -> bool:
		if has_signal_record(emitter, signal_name):
			var records: Array = get_signal_records(emitter, signal_name)
			return records.is_empty()
		return true
	
	func get_emit_count(emitter: Object, signal_name: String) -> int:
		if has_signal_record(emitter, signal_name):
			return get_signal_records(emitter, signal_name).size()
		return 0

# GUT Required Methods
func get_gut() -> GutMainClass:
	if not _gut:
		_gut = get_parent() as GutMainClass
	return _gut

func set_gut(gut: GutMainClass) -> void:
	_gut = gut

func get_skip_reason() -> String:
	return _skip_reason

func should_skip_script() -> bool:
	return _skip_script

func _do_ready_stuff() -> void:
	_was_ready_called = true

# Lifecycle Methods
func before_all() -> void:
	await get_tree().process_frame

func after_all() -> void:
	cleanup_resources()
	await get_tree().process_frame

func before_each() -> void:
	_tracked_nodes.clear()
	_tracked_resources.clear()
	clear_signal_watcher()
	
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
	
	clear_signal_watcher()

# Resource Management
func track_test_node(node: Node) -> void:
	if node and not _tracked_nodes.has(node):
		_tracked_nodes.append(node)

func track_test_resource(resource: Resource) -> void:
	if resource and not _tracked_resources.has(resource):
		_tracked_resources.append(resource)

func cleanup_nodes() -> void:
	for node in _tracked_nodes:
		if is_instance_valid(node) and not node.is_queued_for_deletion():
			node.queue_free()
	_tracked_nodes.clear()

func cleanup_resources() -> void:
	# Clean up nodes first
	for node in _tracked_nodes:
		if is_instance_valid(node):
			if node.get_parent():
				node.get_parent().remove_child(node)
			node.queue_free()
	_tracked_nodes.clear()
	
	# Let engine process the node cleanup
	await get_tree().process_frame
	
	# Now handle resources
	for resource in _tracked_resources:
		if resource and not resource.is_queued_for_deletion():
			# Only unreference resources, don't try to free them
			resource = null
	_tracked_resources.clear()

# Signal Management
func watch_signals(emitter: Object) -> void:
	if not _signal_watcher:
		_signal_watcher = SignalWatcher.new(self)
	_signal_watcher.watch_signals(emitter)

func clear_signal_watcher() -> void:
	if _signal_watcher:
		_signal_watcher.clear()
		_signal_watcher = null

func verify_signal_emitted(emitter: Object, signal_name: String, message: String = "") -> void:
	if not _signal_watcher:
		assert_false(true, "Signal watcher not initialized")
		return
	
	var records: Array = _signal_watcher.get_signal_records(emitter, signal_name)
	assert_true(not records.is_empty(), message if message else "Signal '%s' was not emitted" % signal_name)

func verify_signal_not_emitted(emitter: Object, signal_name: String, message: String = "") -> void:
	if not _signal_watcher:
		assert_false(true, "Signal watcher not initialized")
		return
	
	var records: Array = _signal_watcher.get_signal_records(emitter, signal_name)
	assert_true(records.is_empty(), message if message else "Signal '%s' was emitted" % signal_name)

func get_signal_emit_count(emitter: Object, signal_name: String) -> int:
	if _signal_watcher:
		return _signal_watcher.get_emit_count(emitter, signal_name)
	return 0

# State Management
func verify_state(subject: Object, expected_states: Dictionary) -> void:
	for property: String in expected_states:
		assert_eq(subject[property], expected_states[property],
			"Property %s should match expected state" % property)

# Engine Stabilization
func stabilize_engine(time: float = STABILIZATION_TIME) -> void:
	await get_tree().create_timer(time).timeout

func wait_frames(frames: int) -> void:
	for _i in range(frames):
		await get_tree().process_frame

func wait_physics_frames(frames: int) -> void:
	for _i in range(frames):
		await get_tree().physics_frame

# Async Operation Helpers
func with_timeout(operation: Callable, timeout: float = FRAME_TIMEOUT) -> Variant:
	var timer: SceneTreeTimer = get_tree().create_timer(timeout)
	var done := false
	var result: Variant = null
	
	operation.call_deferred(func(value: Variant = null) -> void:
		result = value
		done = true
	)
	
	timer.timeout.connect(func() -> void: done = true, CONNECT_ONE_SHOT)
	
	while not done:
		await get_tree().process_frame
	
	return result

# Performance Testing
func measure_performance(callable: Callable, iterations: int = 1000) -> Dictionary:
	var start_time: int = Time.get_ticks_msec()
	var memory_start: float = Performance.get_monitor(Performance.MEMORY_STATIC)
	
	for _i in range(iterations):
		callable.call()
	
	var end_time: int = Time.get_ticks_msec()
	var memory_end: float = Performance.get_monitor(Performance.MEMORY_STATIC)
	
	return {
		"duration_ms": end_time - start_time,
		"avg_duration_ms": float(end_time - start_time) / float(iterations),
		"memory_delta": memory_end - memory_start,
		"iterations": iterations
	}

# Memory Leak Detection
func assert_no_leaks() -> void:
	var leaked_nodes: Array[Node] = []
	for node in _tracked_nodes:
		if is_instance_valid(node) and not node.is_queued_for_deletion():
			leaked_nodes.append(node)
	
	var leaked_resources: Array[Resource] = []
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
	var master_bus_idx: int = AudioServer.get_bus_index("Master")
	if master_bus_idx >= 0:
		AudioServer.set_bus_mute(master_bus_idx, TEST_CONFIG.audio_enabled)

func _restore_engine_config() -> void:
	Engine.physics_ticks_per_second = _original_engine_config.physics_fps
	Engine.max_fps = _original_engine_config.max_fps
	get_tree().set_debug_collisions_hint(_original_engine_config.debug_collisions)
	get_tree().set_debug_navigation_hint(_original_engine_config.debug_navigation)
	
	# Restore audio
	var master_bus := AudioServer.get_bus_index("Master")
	if master_bus >= 0:
		AudioServer.set_bus_mute(master_bus, _original_engine_config.audio_enabled)

# Standard Assertions
func assert_signal_emitted(object: Object, signal_name: String, text: String = "") -> void:
	if not _signal_watcher:
		assert_true(false, "Signal watcher not initialized. Did you call watch_signals()?")
		return
	var did_emit: bool = _signal_watcher.assert_signal_emitted(object, signal_name)
	assert_true(did_emit, text if text else "Signal '%s' was not emitted" % signal_name)

func assert_signal_not_emitted(object: Object, signal_name: String, text: String = "") -> void:
	if not _signal_watcher:
		assert_true(false, "Signal watcher not initialized. Did you call watch_signals()?")
		return
	var did_emit: bool = _signal_watcher.assert_signal_not_emitted(object, signal_name)
	assert_false(did_emit, text if text else "Signal '%s' was emitted" % signal_name)

func assert_signal_emit_count(object: Object, signal_name: String, times: int, text: String = "") -> void:
	if not _signal_watcher:
		assert_true(false, "Signal watcher not initialized. Did you call watch_signals()?")
		return
	var count: int = _signal_watcher.get_emit_count(object, signal_name)
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
	var size: Vector2i = MOBILE_RESOLUTIONS.get(resolution, MOBILE_RESOLUTIONS.phone_portrait)
	var screen_dpi: int = MOBILE_DPI.get(dpi, MOBILE_DPI.xhdpi)
	
	DisplayServer.window_set_size(size)
	# Note: DPI can't be changed at runtime, this is for test verification only
	assert_eq(DisplayServer.screen_get_dpi(), screen_dpi,
		"Screen DPI should match target mobile density")

func simulate_touch_event(position: Vector2, pressed: bool = true) -> void:
	var event: InputEventScreenTouch = InputEventScreenTouch.new()
	event.position = position
	event.pressed = pressed
	Input.parse_input_event(event)

func simulate_touch_drag(from: Vector2, to: Vector2, steps: int = 10) -> void:
	var event: InputEventScreenDrag = InputEventScreenDrag.new()
	var step: Vector2 = (to - from) / float(steps)
	
	for i in range(steps):
		event.position = from + step * float(i)
		event.relative = step
		Input.parse_input_event(event)
		await get_tree().process_frame

func assert_fits_mobile_screen(control: Control, resolution: String = "phone_portrait") -> void:
	var size: Vector2i = MOBILE_RESOLUTIONS.get(resolution, MOBILE_RESOLUTIONS.phone_portrait)
	assert_true(control.get_rect().size.x <= size.x,
		"Control width should fit mobile screen")
	assert_true(control.get_rect().size.y <= size.y,
		"Control height should fit mobile screen")

func assert_touch_target_size(control: Control) -> void:
	var min_touch_size: Vector2 = Vector2(40, 40) # Minimum recommended touch target size
	var size: Vector2 = control.get_rect().size
	assert_true(size.x >= min_touch_size.x and size.y >= min_touch_size.y,
		"Touch target size should be at least %s pixels" % str(min_touch_size))

# Mobile performance helpers
func measure_mobile_performance(callable: Callable, iterations: int = 100) -> Dictionary:
	var fps_samples: Array[float] = []
	var memory_start: float = Performance.get_monitor(Performance.MEMORY_STATIC)
	var draw_calls_start: int = Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
	var objects_start: int = Performance.get_monitor(Performance.OBJECT_NODE_COUNT)
	
	for _i in range(iterations):
		var start_time: int = Time.get_ticks_usec()
		callable.call()
		await get_tree().process_frame
		var end_time: int = Time.get_ticks_usec()
		var frame_time: float = float(end_time - start_time) / 1000.0 # Convert to milliseconds
		fps_samples.append(frame_time > 0.0?1000.0 / frame_time: 0.0)
	
	var memory_end: float = Performance.get_monitor(Performance.MEMORY_STATIC)
	var draw_calls_end: int = Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
	var objects_end: int = Performance.get_monitor(Performance.OBJECT_NODE_COUNT)
	
	# Calculate statistics
	fps_samples.sort()
	var avg_fps: float = fps_samples.reduce(func(accum: float, fps: float) -> float: return accum + fps, 0.0) / float(iterations)
	var percentile_95_fps: float = fps_samples[int(float(iterations) * 0.95)]
	var min_fps: float = fps_samples[0]
	
	return {
		"average_fps": avg_fps,
		"95th_percentile_fps": percentile_95_fps,
		"minimum_fps": min_fps,
		"memory_delta_kb": (memory_end - memory_start) / 1024.0,
		"draw_calls_delta": draw_calls_end - draw_calls_start,
		"objects_delta": objects_end - objects_start,
		"iterations": iterations
	}

# Logger Methods
func set_logger(logger: Node) -> void:
	_logger = logger

func get_logger() -> Node:
	return _logger

# Async signal assertions
func assert_async_signal(emitter: Object, signal_name: String, timeout: float = SIGNAL_TIMEOUT) -> bool:
	var timer: SceneTreeTimer = get_tree().create_timer(timeout)
	var signal_received := false
	
	# Connect to signal
	var callable := func() -> void:
		signal_received = true
	emitter.connect(signal_name, callable, CONNECT_ONE_SHOT)
	
	# Wait for either signal or timeout
	timer.timeout.connect(func() -> void: signal_received = false, CONNECT_ONE_SHOT)
	while not signal_received and not timer.is_stopped():
		await get_tree().process_frame
	
	return signal_received

func assert_signal_emitted_with_args(emitter: Object, signal_name: String, expected_args: Array, timeout: float = ASYNC_TIMEOUT) -> void:
	watch_signals(emitter)
	var start_time: int = Time.get_ticks_msec()
	
	while Time.get_ticks_msec() - start_time < timeout * 1000:
		if _signal_emissions.has(emitter):
			var emissions: Dictionary = _signal_emissions[emitter] as Dictionary
			if emissions.has(signal_name):
				var emission_list: Array = emissions[signal_name] as Array
				for emission in emission_list:
					if emission is Array and emission == expected_args:
						assert_true(true, "Signal %s emitted with expected args" % signal_name)
						return
		await get_tree().process_frame
	
	assert_true(false, "Signal %s not emitted with expected args within %f seconds" % [signal_name, timeout])

# Signal waiting utilities
func await_signals(signals: Array[Array], timeout: float = ASYNC_TIMEOUT) -> Array[Array]:
	var results: Array[Array] = []
	var start_time: int = Time.get_ticks_msec()
	
	for signal_info in signals:
		if signal_info.size() >= 2:
			var emitter: Object = signal_info[0] as Object
			var signal_name: String = signal_info[1] as String
			if emitter and signal_name:
				watch_signals(emitter)
	
	while Time.get_ticks_msec() - start_time < timeout * 1000:
		var all_received: bool = true
		results.clear()
		
		for signal_info in signals:
			if signal_info.size() < 2:
				continue
				
			var emitter: Object = signal_info[0] as Object
			var signal_name: String = signal_info[1] as String
			
			if emitter and signal_name and _signal_emissions.has(emitter):
				var emissions: Dictionary = _signal_emissions[emitter] as Dictionary
				if emissions.has(signal_name):
					var emission_list: Array = emissions[signal_name] as Array
					if not emission_list.is_empty():
						results.append(emission_list.pop_front())
						continue
			all_received = false
			break
		
		if all_received:
			return results
		
		await get_tree().process_frame
	
	return []

func wait_for_signal(emitter: Object, signal_name: String, timeout: float = SIGNAL_TIMEOUT) -> Array:
	var timer: SceneTreeTimer = get_tree().create_timer(timeout)
	var signal_data: Array = []
	var signal_received: bool = false
	var timer_expired: bool = false
	
	# Connect to signal with strongly typed arguments
	var callable := func(arg1: Variant = null, arg2: Variant = null, arg3: Variant = null,
			arg4: Variant = null, arg5: Variant = null) -> void:
		signal_received = true
		var args: Array = []
		for arg in [arg1, arg2, arg3, arg4, arg5]:
			if arg != null:
				args.append(arg)
		signal_data = args
	
	# Handle connect result
	var connect_result: Error = emitter.connect(signal_name, callable, CONNECT_ONE_SHOT)
	if connect_result != OK:
		push_warning("Failed to connect to signal %s" % signal_name)
		return []
	
	# Wait for either signal or timeout
	timer.timeout.connect(func() -> void: timer_expired = true, CONNECT_ONE_SHOT)
	while not signal_received and timer and not timer.is_stopped():
		await get_tree().process_frame
	
	return signal_data

# Required GUT methods
func get_assert_count() -> int:
	return gut.get_assert_count() if gut else 0

func get_pass_count() -> int:
	return gut.get_pass_count() if gut else 0

func get_fail_count() -> int:
	return gut.get_fail_count() if gut else 0

func get_pending_count() -> int:
	return gut.get_pending_count() if gut else 0

func get_test_count() -> int:
	return gut.get_test_count() if gut else 0
