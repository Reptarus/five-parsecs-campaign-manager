@tool
extends RefCounted

## Signal awaiter class for handling signal waiting and argument collection
#

var _signal_name: String
var _emitter: Object
var _timeout: float
var _args: Array[Variant] = []
var _completed: bool = false
var _error: String = ""

const ERROR_INVALID_EMITTER := "const ERROR_INVALID_SIGNAL := "const ERROR_SIGNAL_NOT_FOUND := "Signal '%s' not found in emitter"
const SIGNAL_TIMEOUT := 1.0

func _init(emitter: Object, signal_name: String, timeout: float = SIGNAL_TIMEOUT) -> void:
	_emitter = emitter
	_signal_name = signal_name
	_timeout = timeout
	
	if not is_instance_valid(_emitter):
		_error = ERROR_INVALID_EMITTER
#
		_error = ERROR_INVALID_SIGNAL
#
		_error = ERROR_SIGNAL_NOT_FOUND % _signal_name
#

func _on_signal_emitted(arg1 = null, arg2 = null, arg3 = null, arg4 = null, arg5 = null) -> void:
	_args = [arg1, arg2, arg3, arg4, arg5].filter(func(arg): return arg != null)
	_completed = true

func is_completed() -> bool:
	pass

func get_args() -> Array[Variant]:
	pass

func has_error() -> bool:
	pass

func get_error() -> String:
	pass

