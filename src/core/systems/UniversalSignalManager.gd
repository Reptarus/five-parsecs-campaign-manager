## UniversalSignalManager.gd
## Provides safe signal connection and emission utilities
## Created: 2025-11-19 (Boot error fix)

class_name UniversalSignalManager
extends Object

## Safely connects a signal to a callable with null checks
## Returns true if connection successful, false otherwise
static func connect_signal_safe(obj: Object, signal_name: String, callable: Callable, context: String = "") -> bool:
	if not obj:
		push_warning("UniversalSignalManager: Null object passed to connect_signal_safe (context: %s)" % context)
		return false

	if not obj.has_signal(signal_name):
		push_warning("UniversalSignalManager: Object does not have signal '%s' (context: %s)" % [signal_name, context])
		return false

	if obj.is_connected(signal_name, callable):
		# Already connected, skip
		return true

	obj.connect(signal_name, callable)
	return true

## Safely emits a signal with null checks and argument handling
## Args can be empty array or array of arguments to pass
static func emit_signal_safe(obj: Object, signal_name: String, args: Array = [], context: String = "") -> void:
	if not obj:
		push_warning("UniversalSignalManager: Null object passed to emit_signal_safe (context: %s)" % context)
		return

	if not obj.has_signal(signal_name):
		push_warning("UniversalSignalManager: Object does not have signal '%s' (context: %s)" % [signal_name, context])
		return

	# Emit with arguments if provided
	if args.is_empty():
		obj.emit_signal(signal_name)
	elif args.size() == 1:
		obj.emit_signal(signal_name, args[0])
	elif args.size() == 2:
		obj.emit_signal(signal_name, args[0], args[1])
	elif args.size() == 3:
		obj.emit_signal(signal_name, args[0], args[1], args[2])
	else:
		# For more than 3 args, use callv
		push_warning("UniversalSignalManager: Signal '%s' has %d args, using callv (context: %s)" % [signal_name, args.size(), context])
		obj.callv("emit_signal", [signal_name] + args)

## Safely disconnects a signal
static func disconnect_signal_safe(obj: Object, signal_name: String, callable: Callable, context: String = "") -> bool:
	if not obj:
		push_warning("UniversalSignalManager: Null object passed to disconnect_signal_safe (context: %s)" % context)
		return false

	if not obj.has_signal(signal_name):
		return false

	if obj.is_connected(signal_name, callable):
		obj.disconnect(signal_name, callable)
		return true

	return false
