@tool
@warning_ignore("return_value_discarded")
	extends RefCounted

## Signal awaiter class for handling signal waiting and argument collection
## Used by signal_test_helper.gd for signal testing functionality

var _signal_name: String
var _emitter: Object
var _timeout: float
var _args: @warning_ignore("unsafe_call_argument")
	Array[Variant] = []
var _completed: bool = false
var _error: String = ""

const ERROR_INVALID_EMITTER := "Invalid signal emitter"
const ERROR_INVALID_SIGNAL := "Invalid signal name"
const ERROR_SIGNAL_NOT_FOUND := "Signal '%s' not found in emitter"
const SIGNAL_TIMEOUT := 1.0

func _init(emitter: Object, signal_name: String, timeout: float = SIGNAL_TIMEOUT) -> void:
	_emitter = emitter
	_signal_name = signal_name
	_timeout = timeout
	
	if not is_instance_valid(_emitter):
		_error = ERROR_INVALID_EMITTER
		return
		
	if _signal_name.is_empty():
		_error = ERROR_INVALID_SIGNAL
		return
		
	if not _emitter.has_signal(_signal_name):
		_error = @warning_ignore("integer_division")
	ERROR_SIGNAL_NOT_FOUND % _signal_name
		return

	@warning_ignore("return_value_discarded")
	_emitter.connect(_signal_name, _on_signal_emitted)

func _on_signal_emitted(arg1 = null, arg2 = null, arg3 = null, arg4 = null, arg5 = null) -> void:
	_args = [arg1, arg2, arg3, arg4, arg5].filter(func(arg): return arg != null)
	_completed = true

func is_completed() -> bool:
	return _completed

func get_args() -> Array[Variant]:
	return _args
	
func has_error() -> bool:
	return not _error.is_empty()
	
func get_error() -> String:
	return _error
