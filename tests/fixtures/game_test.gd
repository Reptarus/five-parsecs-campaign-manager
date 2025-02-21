@tool
extends "res://tests/fixtures/base_test.gd"
class_name GameTest

# Core game script references with type safety
const GameStateScript: GDScript = preload("res://src/core/state/GameState.gd")
const TypeSafeMixin: GDScript = preload("res://tests/fixtures/type_safe_test_mixin.gd")

# Type-safe test state tracking
var _test_nodes: Array[Node] = []
var _test_resources: Array[Resource] = []

func before_each() -> void:
	await super.before_each()
	_test_nodes.clear()
	_test_resources.clear()
	_signal_watcher = SignalWatcher.new(self)

func after_each() -> void:
	_cleanup_test_resources()
	if _signal_watcher:
		_signal_watcher.clear()
		_signal_watcher = null
	await super.after_each()

func _cleanup_test_resources() -> void:
	for node in _test_nodes:
		if is_instance_valid(node) and node.is_inside_tree():
			node.queue_free()
	_test_nodes.clear()
	
	for resource in _test_resources:
		if resource and not resource.is_queued_for_deletion():
			resource.free()
	_test_resources.clear()

# Node management
func add_child_autofree(node: Node) -> Node:
	if not node:
		push_error("Attempting to add null node")
		return null
	add_child(node)
	_test_nodes.append(node)
	return node

func track_test_node(node: Node) -> void:
	if not node:
		push_error("Attempting to track null node")
		return
	if not node in _test_nodes:
		_test_nodes.append(node)

func track_test_resource(resource: Resource) -> void:
	if not resource:
		push_error("Attempting to track null resource")
		return
	if not resource in _test_resources:
		_test_resources.append(resource)

# Signal management
func watch_signals(emitter: Object) -> void:
	if not _signal_watcher:
		push_error("Signal watcher not initialized")
		return
	_signal_watcher.watch_signals(emitter)

func verify_signal_emitted(emitter: Object, signal_name: String, text: String = "") -> void:
	if not _signal_watcher:
		push_error("Signal watcher not initialized")
		return
	if not _signal_watcher.assert_signal_emitted(emitter, signal_name):
		assert_false(true, "Signal '%s' was not emitted. %s" % [signal_name, text])

func verify_signal_not_emitted(emitter: Object, signal_name: String, text: String = "") -> void:
	if not _signal_watcher:
		push_error("Signal watcher not initialized")
		return
	if _signal_watcher.assert_signal_emitted(emitter, signal_name):
		assert_false(true, "Signal '%s' was emitted unexpectedly. %s" % [signal_name, text])

func verify_signal_emit_count(emitter: Object, signal_name: String, count: int, text: String = "") -> void:
	if not _signal_watcher:
		push_error("Signal watcher not initialized")
		return
	var actual_count: int = _signal_watcher.get_emit_count(emitter, signal_name)
	assert_eq(actual_count, count, "Expected signal '%s' to be emitted %d times, but was emitted %d times. %s" % [
		signal_name, count, actual_count, text
	])

# Type-safe property access
func _get_property_safe(obj: Object, property: String, default_value: Variant = null) -> Variant:
	return TypeSafeMixin._get_property_safe(obj, property, default_value)

func _set_property_safe(obj: Object, property: String, value: Variant) -> void:
	TypeSafeMixin._set_property_safe(obj, property, value)

# Type-safe method calls
func _call_node_method(obj: Object, method: String, args: Array = [], default: Variant = null) -> Variant:
	if not obj or not method:
		push_error("Invalid object or method name")
		return default
	return TypeSafeMixin._call_node_method(obj, method, args)

func _call_node_method_int(obj: Object, method: String, args: Array = [], default: int = 0) -> int:
	if not obj or not method:
		push_error("Invalid object or method name")
		return default
	return TypeSafeMixin._call_node_method_int(obj, method, args)

func _call_node_method_bool(obj: Object, method: String, args: Array = [], default: bool = false) -> bool:
	if not obj or not method:
		push_error("Invalid object or method name")
		return default
	return TypeSafeMixin._call_node_method_bool(obj, method, args)

func _call_node_method_array(obj: Object, method: String, args: Array = [], default: Array = []) -> Array:
	if not obj or not method:
		push_error("Invalid object or method name")
		return default
	return TypeSafeMixin._call_node_method_array(obj, method, args)

func _call_node_method_dict(obj: Object, method: String, args: Array = [], default: Dictionary = {}) -> Dictionary:
	if not obj or not method:
		push_error("Invalid object or method name")
		return default
	return TypeSafeMixin._call_node_method_dict(obj, method, args)

# Type-safe casting
func _safe_cast_int(value: Variant, error_message: String = "") -> int:
	return TypeSafeMixin._safe_cast_int(value, error_message)

func _safe_cast_float(value: Variant, error_message: String = "") -> float:
	return TypeSafeMixin._safe_cast_float(value, error_message)

func _safe_cast_array(value: Variant, error_message: String = "") -> Array:
	return TypeSafeMixin._safe_cast_array(value, error_message)

func _safe_cast_to_node(value: Variant, expected_type: String = "") -> Node:
	return TypeSafeMixin._safe_cast_to_node(value, expected_type)

func _safe_cast_vector2(value: Variant, error_message: String = "") -> Vector2:
	return TypeSafeMixin._safe_cast_vector2(value, error_message)

# Engine stabilization helper
func stabilize_engine(time: float = STABILIZATION_TIME) -> void:
	await get_tree().create_timer(time).timeout

# Type-safe game state creation
func create_test_game_state() -> Node:
	var state := Node.new()
	state.set_script(GameStateScript)
	if not state:
		push_error("Failed to create game state")
		return null
	return state

# Type-safe property access with casting
func _get_property_with_cast(node: Node, property: String, type: int, default_value: Variant = null) -> Variant:
	if not node or not property:
		push_error("Invalid node or property")
		return default_value
	
	if not property in node:
		push_error("Property '%s' not found in node" % property)
		return default_value
	
	var value = node.get(property)
	if typeof(value) != type:
		push_error("Property '%s' has wrong type: expected %d, got %d" % [property, type, typeof(value)])
		return default_value
	return value

# Type-safe method calls with casting
func _call_method_with_cast(obj: Object, method: String, args: Array, type: int, default_value: Variant = null) -> Variant:
	if not obj or not method:
		push_error("Invalid object or method")
		return default_value
	
	if not obj.has_method(method):
		push_error("Method '%s' not found in object" % method)
		return default_value
	
	var result = obj.callv(method, args)
	if typeof(result) != type:
		push_error("Method '%s' returned wrong type: expected %d, got %d" % [method, type, typeof(result)])
		return default_value
	return result

# Async signal helpers
func assert_async_signal(emitter: Object, signal_name: String, timeout: float = SIGNAL_TIMEOUT) -> bool:
	if not emitter or not signal_name:
		push_error("Invalid emitter or signal name")
		return false
	
	var start_time := Time.get_ticks_msec()
	while Time.get_ticks_msec() - start_time < timeout * 1000:
		if _signal_watcher and _signal_watcher.assert_signal_emitted(emitter, signal_name):
			return true
		await get_tree().process_frame
	
	return false

func wait_for_signal(emitter: Object, signal_name: String, timeout: float = SIGNAL_TIMEOUT) -> Array:
	if not emitter or not signal_name:
		push_error("Invalid emitter or signal name")
		return []
	
	var start_time := Time.get_ticks_msec()
	while Time.get_ticks_msec() - start_time < timeout * 1000:
		if _signal_watcher and _signal_watcher.assert_signal_emitted(emitter, signal_name):
			return _signal_watcher.get_signal_records(emitter, signal_name)[-1]
		await get_tree().process_frame
	
	push_error("Timeout waiting for signal '%s'" % signal_name)
	return []

# Resource method calls with type safety
func _call_resource_method(resource: Resource, method: String, args: Array = []) -> Variant:
	return TypeSafeMixin._call_node_method(resource, method, args)

func _call_resource_method_int(resource: Resource, method: String, args: Array = []) -> int:
	return TypeSafeMixin._call_node_method_int(resource, method, args)

func _call_resource_method_bool(resource: Resource, method: String, args: Array = []) -> bool:
	return TypeSafeMixin._call_node_method_bool(resource, method, args)

func _call_resource_method_array(resource: Resource, method: String, args: Array = []) -> Array:
	return TypeSafeMixin._call_node_method_array(resource, method, args)

func _call_resource_method_dict(resource: Resource, method: String, args: Array = []) -> Dictionary:
	return TypeSafeMixin._call_node_method_dict(resource, method, args)

# Campaign state verification
func verify_campaign_state(campaign: Resource, expected_state: Dictionary) -> void:
	if not campaign:
		push_error("Campaign not initialized")
		return
		
	if expected_state.has("phase"):
		var phase: int = _call_resource_method_int(campaign, "get_phase")
		var expected_phase: int = TypeSafeMixin._safe_cast_int(expected_state.get("phase", 0))
		assert_eq(phase, expected_phase, "Campaign phase should match expected state")
	
	if expected_state.has("resources"):
		var resources: Dictionary = _call_resource_method_dict(campaign, "get_resources")
		var expected_resources: Dictionary = expected_state.get("resources", {})
		for key in expected_resources:
			assert_eq(resources.get(key), expected_resources[key],
				"Resource '%s' should match expected value" % key)

# Game state verification
func verify_game_state(state: Node, expected_state: Dictionary) -> void:
	if not state:
		push_error("Game state not initialized")
		return
		
	assert_true(state.is_inside_tree(), "Game state should be in scene tree")
	assert_true(state.is_processing(), "Game state should be processing")
	
	for key in expected_state:
		var actual_value = _get_property_safe(state, key)
		var expected_value = expected_state[key]
		assert_eq(actual_value, expected_value,
			"Game state property '%s' should be %s but was %s" % [key, expected_value, actual_value])

# Mobile test helpers
func simulate_touch_event(position: Vector2, is_pressed: bool) -> void:
	var event := InputEventScreenTouch.new()
	event.pressed = is_pressed
	event.position = position
	Input.parse_input_event(event)
	await get_tree().process_frame

func assert_fits_mobile_screen(node: Node, orientation: String = "") -> void:
	if not node:
		push_error("Node not initialized")
		return
		
	var viewport_size := get_viewport().get_visible_rect().size
	var node_size: Vector2 = node.get_rect().size
	
	assert_true(node_size.x <= viewport_size.x, "Node width should fit screen")
	assert_true(node_size.y <= viewport_size.y, "Node height should fit screen")

func assert_touch_target_size(node: Node, min_size: Vector2 = Vector2(44, 44)) -> void:
	if not node:
		push_error("Cannot check touch target size for null node")
		return
	
	if not node is Control:
		push_error("Node must be a Control node for touch target size check")
		return
	
	var node_size := (node as Control).get_size()
	assert_true(node_size.x >= min_size.x,
		"Touch target width (%d) is smaller than minimum (%d)" % [node_size.x, min_size.x])
	assert_true(node_size.y >= min_size.y,
		"Touch target height (%d) is smaller than minimum (%d)" % [node_size.y, min_size.y])

# Mobile testing helpers
func simulate_mobile_environment(mode: String, orientation: String = "portrait") -> void:
	var resolution: Vector2
	match mode:
		"phone":
			resolution = Vector2(360, 640) if orientation == "portrait" else Vector2(640, 360)
		"tablet":
			resolution = Vector2(768, 1024) if orientation == "portrait" else Vector2(1024, 768)
		_:
			resolution = Vector2(360, 640)
	
	DisplayServer.window_set_size(resolution)
	await get_tree().process_frame

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

# Statistical helper functions
func _calculate_average(values: Array) -> float:
	if values.is_empty():
		return 0.0
	var sum := 0.0
	for value in values:
		sum += float(value)
	return sum / float(values.size())

func _calculate_minimum(values: Array) -> float:
	if values.is_empty():
		return 0.0
	var min_value := float(values[0])
	for value in values:
		min_value = min(min_value, float(value))
	return min_value

func _calculate_maximum(values: Array) -> float:
	if values.is_empty():
		return 0.0
	var max_value := float(values[0])
	for value in values:
		max_value = max(max_value, float(value))
	return max_value

func _calculate_percentile(values: Array, percentile: float) -> float:
	if values.is_empty():
		return 0.0
	var sorted_values := values.duplicate()
	sorted_values.sort()
	var index := int(float(sorted_values.size() - 1) * percentile)
	return float(sorted_values[index])

# Touch input helpers
func simulate_touch_drag(start_pos: Vector2, end_pos: Vector2, duration: float = 0.1) -> void:
	await simulate_touch_event(start_pos, true)
	
	var steps := int(duration / 0.016) # ~60fps
	for i in range(steps):
		var t := float(i) / float(steps)
		var current_pos := start_pos.lerp(end_pos, t)
		var event := InputEventScreenDrag.new()
		event.position = current_pos
		event.relative = (end_pos - start_pos) / steps
		Input.parse_input_event(event)
		await get_tree().process_frame
	
	await simulate_touch_event(end_pos, false)

# Node access helper
func _get_node_safe(parent: Node, path: String) -> Node:
	if not parent:
		push_error("Parent node is null")
		return null
	var node := parent.get_node(path)
	if not node:
		push_error("Failed to get node at path: %s" % path)
	return node

# State property helper
func _set_state_property(state: Node, property: String, value: Variant) -> void:
	if not state:
		push_error("Cannot set property on null state")
		return
	if not state.has_method("set"):
		push_error("State object does not have set method")
		return
	TypeSafeMixin._safe_method_call_bool(state, "set", [property, value])
