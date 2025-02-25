@tool
extends RefCounted

## Helper class for signal testing functionality
## Provides common signal testing methods used across test files

# Type-safe error handling
const ERROR_INVALID_EMITTER := "Invalid signal emitter"
const ERROR_INVALID_SIGNAL := "Invalid signal name"
const ERROR_SIGNAL_NOT_FOUND := "Signal '%s' not found in emitter"
const ERROR_MISSING_METHOD := "Test case missing required method: %s"
const ERROR_TIMEOUT := "Timeout waiting for signal '%s' after %.1f seconds"
const ERROR_ARG_MISMATCH := "Signal '%s' argument count mismatch: expected %d but got %d"
const ERROR_ARG_TYPE := "Signal '%s' argument %d type mismatch: expected %s but got %s"
const ERROR_TIMING := "Signal '%s' timing mismatch: expected %.1f seconds but took %.1f seconds"

# Type-safe constants for signal testing
const SIGNAL_TIMEOUT := 1.0 as float
const MAX_SIGNAL_ARGS := 5 as int
const DRAG_STEP_DELAY := 0.05 as float
const TIMING_TOLERANCE := 0.1 as float

# Type-safe signal awaiter class
const SignalAwaiter: GDScript = preload("res://tests/fixtures/helpers/signal_awaiter.gd")

# Type-safe signal verification methods
static func assert_signal_emitted(test_case: Node, emitter: Object, signal_name: String, message: String = "") -> void:
	if not is_instance_valid(emitter):
		test_case.assert_true(false, ERROR_INVALID_EMITTER)
		return
		
	if signal_name.is_empty():
		test_case.assert_true(false, ERROR_INVALID_SIGNAL)
		return
		
	if not emitter.has_signal(signal_name):
		test_case.assert_true(false, ERROR_SIGNAL_NOT_FOUND % signal_name)
		return
		
	if not test_case.has_method("verify_signal_emitted"):
		test_case.assert_true(false, ERROR_MISSING_METHOD % "verify_signal_emitted")
		return
		
	test_case.verify_signal_emitted(emitter, signal_name, message)

static func assert_signal_emit_count(test_case: Node, emitter: Object, signal_name: String, count: int) -> void:
	if not is_instance_valid(emitter):
		test_case.assert_true(false, ERROR_INVALID_EMITTER)
		return
		
	if signal_name.is_empty():
		test_case.assert_true(false, ERROR_INVALID_SIGNAL)
		return
		
	if not emitter.has_signal(signal_name):
		test_case.assert_true(false, ERROR_SIGNAL_NOT_FOUND % signal_name)
		return
		
	if not test_case.has_method("verify_signal_emit_count"):
		test_case.assert_true(false, ERROR_MISSING_METHOD % "verify_signal_emit_count")
		return
		
	var actual_count := 0
	if test_case.has_method("get_signal_emit_count"):
		actual_count = test_case.get_signal_emit_count(emitter, signal_name)
	
	test_case.assert_eq(actual_count, count,
		ERROR_ARG_MISMATCH % [signal_name, count, actual_count])

# Enhanced signal waiting with type safety
static func wait_for_signal(test_case: Node, emitter: Object, signal_name: String, timeout: float = SIGNAL_TIMEOUT) -> Array[Variant]:
	var awaiter: RefCounted = SignalAwaiter.new(emitter, signal_name, timeout)
	
	if awaiter.has_error():
		test_case.assert_true(false, awaiter.get_error())
		return []
	
	var start_time := Time.get_ticks_msec()
	
	while not awaiter.is_completed():
		if Time.get_ticks_msec() - start_time > timeout * 1000:
			test_case.assert_true(false, ERROR_TIMEOUT % [signal_name, timeout])
			return []
		await test_case.get_tree().process_frame
	
	return awaiter.get_args()

# Enhanced signal simulation for mobile testing
static func simulate_touch_event(test_case: Node, position: Vector2, pressed: bool) -> void:
	var event := InputEventScreenTouch.new()
	event.position = position
	event.pressed = pressed
	event.index = 0 # Primary touch point
	Input.parse_input_event(event)
	await test_case.get_tree().process_frame

# Enhanced signal simulation for drag events
static func simulate_drag_event(test_case: Node, start_pos: Vector2, end_pos: Vector2, steps: int = 10) -> void:
	var step_size := (end_pos - start_pos) / steps
	var current := start_pos
	
	simulate_touch_event(test_case, start_pos, true)
	
	for i in range(steps):
		current += step_size
		var event := InputEventScreenDrag.new()
		event.position = current
		event.relative = step_size
		event.index = 0 # Primary touch point
		Input.parse_input_event(event)
		await test_case.get_tree().create_timer(DRAG_STEP_DELAY).timeout
		await test_case.get_tree().process_frame
	
	simulate_touch_event(test_case, end_pos, false)

# Enhanced signal verification for multiple signals
static func verify_multiple_signals(test_case: Node, emitter: Object, expected_signals: Array[String], timeout: float = SIGNAL_TIMEOUT) -> void:
	if not is_instance_valid(emitter):
		test_case.assert_true(false, ERROR_INVALID_EMITTER)
		return
		
	for signal_name in expected_signals:
		if signal_name.is_empty():
			test_case.assert_true(false, ERROR_INVALID_SIGNAL)
			continue
			
		if not emitter.has_signal(signal_name):
			test_case.assert_true(false, ERROR_SIGNAL_NOT_FOUND % signal_name)
			continue
			
		var awaiter: RefCounted = SignalAwaiter.new(emitter, signal_name, timeout)
		if awaiter.has_error():
			test_case.assert_true(false, awaiter.get_error())
			continue
			
		test_case.verify_signal_emitted(emitter, signal_name)

# Enhanced signal verification with arguments
static func verify_signal_args(test_case: Node, emitter: Object, signal_name: String, expected_args: Array) -> void:
	if not is_instance_valid(emitter):
		test_case.assert_true(false, ERROR_INVALID_EMITTER)
		return
		
	if signal_name.is_empty():
		test_case.assert_true(false, ERROR_INVALID_SIGNAL)
		return
		
	if not emitter.has_signal(signal_name):
		test_case.assert_true(false, ERROR_SIGNAL_NOT_FOUND % signal_name)
		return
		
	var actual_args: Array[Variant] = []
	if test_case.has_method("get_signal_emit_count"):
		var emit_count: int = test_case.get_signal_emit_count(emitter, signal_name)
		if emit_count > 0:
			actual_args = test_case.get_signal_parameters(emitter, signal_name)
	
	test_case.assert_eq(actual_args.size(), expected_args.size(),
		ERROR_ARG_MISMATCH % [signal_name, expected_args.size(), actual_args.size()])
	
	for i in range(min(actual_args.size(), expected_args.size())):
		var actual = actual_args[i]
		var expected = expected_args[i]
		test_case.assert_eq(actual, expected,
			ERROR_ARG_TYPE % [signal_name, i, typeof_as_string(expected), typeof_as_string(actual)])

# Enhanced signal verification with timing
static func verify_signal_timing(test_case: Node, emitter: Object, signal_name: String, expected_time: float) -> void:
	if not is_instance_valid(emitter):
		test_case.assert_true(false, ERROR_INVALID_EMITTER)
		return
		
	if signal_name.is_empty():
		test_case.assert_true(false, ERROR_INVALID_SIGNAL)
		return
		
	if not emitter.has_signal(signal_name):
		test_case.assert_true(false, ERROR_SIGNAL_NOT_FOUND % signal_name)
		return
		
	var start_time := Time.get_ticks_msec()
	await wait_for_signal(test_case, emitter, signal_name)
	var elapsed_time := (Time.get_ticks_msec() - start_time) / 1000.0
	
	test_case.assert_almost_eq(elapsed_time, expected_time, TIMING_TOLERANCE,
		ERROR_TIMING % [signal_name, expected_time, elapsed_time])

# Utility function for type names
static func typeof_as_string(value: Variant) -> String:
	match typeof(value):
		TYPE_NIL: return "null"
		TYPE_BOOL: return "bool"
		TYPE_INT: return "int"
		TYPE_FLOAT: return "float"
		TYPE_STRING: return "String"
		TYPE_VECTOR2: return "Vector2"
		TYPE_VECTOR3: return "Vector3"
		TYPE_ARRAY: return "Array"
		TYPE_DICTIONARY: return "Dictionary"
		TYPE_OBJECT:
			if value == null:
				return "null"
			if value is Node:
				return "Node"
			if value is Resource:
				return "Resource"
			return "Object"
		_: return "Unknown"