@tool
extends RefCounted
class_name SignalTestHelper

## Helper class for signal testing functionality
## Provides common signal testing methods used across test files

const SIGNAL_TIMEOUT := 1.0

class SignalAwaiter:
	var _signal_name: String
	var _emitter: Object
	var _timeout: float
	var _args: Array
	var _completed: bool = false
	
	func _init(emitter: Object, signal_name: String, timeout: float = SIGNAL_TIMEOUT) -> void:
		_emitter = emitter
		_signal_name = signal_name
		_timeout = timeout
		
		if _emitter and _emitter.has_signal(_signal_name):
			_emitter.connect(_signal_name, _on_signal_emitted)
	
	func _on_signal_emitted(arg1 = null, arg2 = null, arg3 = null, arg4 = null, arg5 = null) -> void:
		_args = [arg1, arg2, arg3, arg4, arg5].filter(func(arg): return arg != null)
		_completed = true
	
	func is_completed() -> bool:
		return _completed
	
	func get_args() -> Array:
		return _args

static func assert_signal_emitted(test_case: Object, emitter: Object, signal_name: String, message: String = "") -> void:
	if not emitter or not signal_name:
		test_case.assert_true(false, "Invalid emitter or signal name")
		return
		
	if not test_case.has_method("verify_signal_emitted"):
		test_case.assert_true(false, "Test case missing verify_signal_emitted method")
		return
		
	test_case.verify_signal_emitted(emitter, signal_name, message)

static func assert_signal_emit_count(test_case: Object, emitter: Object, signal_name: String, count: int) -> void:
	if not emitter or not signal_name:
		test_case.assert_true(false, "Invalid emitter or signal name")
		return
		
	if not test_case.has_method("verify_signal_emit_count"):
		test_case.assert_true(false, "Test case missing verify_signal_emit_count method")
		return
		
	var actual_count := 0
	if test_case.has_method("get_signal_emit_count"):
		actual_count = test_case.get_signal_emit_count(emitter, signal_name)
	
	test_case.assert_eq(actual_count, count,
		"Expected signal '%s' to be emitted %d times, but was emitted %d times" % [signal_name, count, actual_count])

static func wait_for_signal(test_case: Object, emitter: Object, signal_name: String, timeout: float = SIGNAL_TIMEOUT) -> Array:
	var awaiter := SignalAwaiter.new(emitter, signal_name, timeout)
	var start_time := Time.get_ticks_msec()
	
	while not awaiter.is_completed():
		if Time.get_ticks_msec() - start_time > timeout * 1000:
			test_case.assert_true(false, "Timeout waiting for signal '%s'" % signal_name)
			return []
		await test_case.get_tree().process_frame
	
	return awaiter.get_args()

static func simulate_touch_event(test_case: Object, position: Vector2, pressed: bool) -> void:
	var event := InputEventScreenTouch.new()
	event.position = position
	event.pressed = pressed
	Input.parse_input_event(event)
	await test_case.get_tree().process_frame