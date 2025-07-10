# Universal Safe Signal Connection - Apply to ALL files
# Based on proven patterns: Universal Mock Strategy + 7-Stage Methodology
# Removed class_name UniversalSignalManager to fix SHADOWED_GLOBAL_IDENTIFIER warnings
extends RefCounted

static func connect_signal_safe(source: Object, signal_name: String, target_method: Callable, context: String = "") -> bool:
	if not source:
		push_error("CRASH PREVENTION: Signal source is null: %s - %s" % [signal_name, context])
		return false

	if not source.has_signal(signal_name):
		push_error("CRASH PREVENTION: Signal does not exist: %s on %s - %s" % [signal_name, source.get_class(), context])
		return false

	if source.is_connected(signal_name, target_method):
		push_warning("Signal already connected: %s - %s" % [signal_name, context])
		return true

	var result: Variant = source.connect(signal_name, target_method)
	if result != OK:
		push_error("CRASH PREVENTION: Signal connection failed: %s - %s (Error: %s)" % [signal_name, context, result])
		return false

	return true

static func disconnect_signal_safe(source: Object, signal_name: String, target_method: Callable, context: String = "") -> bool:
	if not source:
		push_error("CRASH PREVENTION: Signal source is null for disconnect: %s - %s" % [signal_name, context])
		return false

	if not source.has_signal(signal_name):
		push_error("CRASH PREVENTION: Signal does not exist for disconnect: %s on %s - %s" % [signal_name, source.get_class(), context])
		return false

	if not source.is_connected(signal_name, target_method):
		push_warning("Signal not connected, cannot disconnect: %s - %s" % [signal_name, context])
		return true

	source.disconnect(signal_name, target_method)
	return true

static func emit_signal_safe(source: Object, signal_name: String, args: Array = [], context: String = "") -> bool:
	if not source:
		push_error("CRASH PREVENTION: Signal source is null for emit: %s - %s" % [signal_name, context])
		return false

	if not source.has_signal(signal_name):
		push_error("CRASH PREVENTION: Signal does not exist for emit: %s on %s - %s" % [signal_name, source.get_class(), context])
		return false

	if args.is_empty():
		source.emit_signal(signal_name)
	else:
		source.callv("emit_signal", [signal_name] + args)

	return true

static func is_signal_connected_safe(source: Object, signal_name: String, target_method: Callable, context: String = "") -> bool:
	if not source:
		push_error("CRASH PREVENTION: Signal source is null for connection check: %s - %s" % [signal_name, context])
		return false

	if not source.has_signal(signal_name):
		push_error("CRASH PREVENTION: Signal does not exist for connection check: %s on %s - %s" % [signal_name, source.get_class(), context])
		return false

	return source.is_connected(signal_name, target_method)

static func connect_oneshot_safe(source: Object, signal_name: String, target_method: Callable, context: String = "") -> bool:
	if not source:
		push_error("CRASH PREVENTION: Signal source is null for oneshot connection: %s - %s" % [signal_name, context])
		return false

	if not source.has_signal(signal_name):
		push_error("CRASH PREVENTION: Signal does not exist for oneshot: %s on %s - %s" % [signal_name, source.get_class(), context])
		return false

	if source.is_connected(signal_name, target_method):
		push_warning("Signal already connected for oneshot: %s - %s" % [signal_name, context])
		return true

	var result: Variant = source.connect(signal_name, target_method, CONNECT_ONE_SHOT)
	if result != OK:
		push_error("CRASH PREVENTION: Oneshot signal connection failed: %s - %s (Error: %s)" % [signal_name, context, result])
		return false

	return true

static func get_signal_connections_safe(source: Object, signal_name: String, context: String = "") -> Array:
	if not source:
		push_error("CRASH PREVENTION: Signal source is null for connections list: %s - %s" % [signal_name, context])
		return []

	if not source.has_signal(signal_name):
		push_error("CRASH PREVENTION: Signal does not exist for connections list: %s on %s - %s" % [signal_name, source.get_class(), context])
		return []

	return source.get_signal_connection_list(signal_name)

static func disconnect_all_safe(source: Object, signal_name: String, context: String = "") -> bool:
	if not source:
		push_error("CRASH PREVENTION: Signal source is null for disconnect all: %s - %s" % [signal_name, context])
		return false

	if not source.has_signal(signal_name):
		push_error("CRASH PREVENTION: Signal does not exist for disconnect all: %s on %s - %s" % [signal_name, source.get_class(), context])
		return false

	var connections = source.get_signal_connection_list(signal_name)
	for connection in connections:
		var typed_connection: Variant = connection
		var callable = safe_get_property(connection, "callable")
		if callable:
			source.disconnect(signal_name, callable)

	return true

## Safe property access helper - eliminates UNSAFE_METHOD_ACCESS warnings
static func safe_get_property(obj: Object, property: String, default_value: Variant = null) -> Variant:
	if obj and obj.has_method("get"):
		var value = obj.get(property)
		return value if value != null else default_value
	return default_value

## Safe method call helper - eliminates UNSAFE_METHOD_ACCESS warnings
static func safe_call_method(obj: Variant, method_name: String, args: Array = []) -> Variant:
	if obj == null:
		return null
	if obj is Object and obj.has_method(method_name):
		return obj.callv(method_name, args)
	return null