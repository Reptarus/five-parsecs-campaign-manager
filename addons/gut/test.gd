## This is the base class for all test scripts.  Extend this...test the world!
@tool
extends Node

# Base class for all GUT test scripts
# Provides common testing functionality

const SIGNAL_TIMEOUT: float = 1.0

# Signal watcher for test signals
var _signal_watcher: Node = null
var _signal_counts: Dictionary = {}

func _init() -> void:
	_signal_watcher = Node.new()
	add_child(_signal_watcher)

func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		if _signal_watcher:
			_signal_watcher.queue_free()
			_signal_watcher = null

func before_all():
	await get_tree().process_frame

func after_all():
	await get_tree().process_frame

func before_each():
	await get_tree().process_frame

func after_each():
	await get_tree().process_frame

# Assertion methods
func assert_true(condition: bool, text: String = "") -> void:
	if not condition:
		push_test_error("Assertion failed: %s" % text)

func assert_false(condition: bool, text: String = "") -> void:
	if condition:
		push_test_error("Assertion failed: %s" % text)

func assert_eq(actual: Variant, expected: Variant, text: String = "") -> void:
	if actual != expected:
		push_test_error("Expected %s but got %s: %s" % [expected, actual, text])

func assert_ne(actual: Variant, expected: Variant, text: String = "") -> void:
	if actual == expected:
		push_test_error("Expected values to be different: %s" % text)

func assert_gt(actual: float, expected: float, text: String = "") -> void:
	if not actual > expected:
		push_test_error("Expected %s > %s: %s" % [actual, expected, text])

func assert_lt(actual: float, expected: float, text: String = "") -> void:
	if not actual < expected:
		push_test_error("Expected %s < %s: %s" % [actual, expected, text])

func assert_ge(actual, expected, text: String = "") -> void:
	assert(actual >= expected, text)

func assert_le(actual, expected, text: String = "") -> void:
	assert(actual <= expected, text)

func assert_not_null(value: Variant, text: String = "") -> void:
	if value == null:
		push_test_error("Expected non-null value: %s" % text)

func assert_null(value: Variant, text: String = "") -> void:
	if value != null:
		push_test_error("Expected null value: %s" % text)

func assert_has(collection: Variant, value: Variant, text: String = "") -> void:
	if not value in collection:
		push_test_error("Expected collection to contain %s: %s" % [value, text])

func assert_does_not_have(collection: Variant, value: Variant, text: String = "") -> void:
	if value in collection:
		push_test_error("Expected collection to not contain %s: %s" % [value, text])

func assert_file_exists(path: String, text: String = "") -> void:
	assert(FileAccess.file_exists(path), text)

func assert_file_does_not_exist(path: String, text: String = "") -> void:
	assert(!FileAccess.file_exists(path), text)

func assert_is_instance(instance: Object, type: String, text: String = "") -> void:
	assert(instance.is_class(type), text)

# Signal assertion methods
func assert_signal_emitted(object: Object, signal_name: String, text: String = "") -> void:
	var signal_key := _get_signal_key(object, signal_name)
	if not _signal_counts.has(signal_key) or _signal_counts[signal_key] == 0:
		push_test_error("Signal %s not emitted: %s" % [signal_name, text])

func assert_signal_not_emitted(object: Object, signal_name: String, text: String = "") -> void:
	var signal_key := _get_signal_key(object, signal_name)
	if _signal_counts.has(signal_key) and _signal_counts[signal_key] > 0:
		push_test_error("Signal %s should not be emitted: %s" % [signal_name, text])

func assert_signal_emit_count(object: Object, signal_name: String, expected_count: int, text: String = "") -> void:
	var signal_key := _get_signal_key(object, signal_name)
	var actual_count: int = _signal_counts.get(signal_key, 0)
	if actual_count != expected_count:
		push_test_error("Expected signal %s to be emitted %d times but was emitted %d times: %s" % [
			signal_name, expected_count, actual_count, text
		])

# Error handling
func push_test_error(message: String) -> void:
	push_error("Test Error: %s" % message)

# Node management
func add_child_autofree(node: Node) -> void:
	add_child(node)
	node.queue_free()

# Signal watching
func watch_signals(object: Object) -> void:
	if not _signal_watcher:
		push_test_error("Signal watcher not initialized")
		return
	
	for signal_info in object.get_signal_list():
		var signal_name: String = signal_info["name"]
		var signal_key := _get_signal_key(object, signal_name)
		_signal_counts[signal_key] = 0
		
		# Create a callable that will increment the signal count
		var callable := Callable(self, "_on_signal_emitted").bind(object, signal_name)
		if not object.is_connected(signal_name, callable):
			object.connect(signal_name, callable)

func _on_signal_emitted(object: Object, signal_name: String) -> void:
	var signal_key := _get_signal_key(object, signal_name)
	_signal_counts[signal_key] = _signal_counts.get(signal_key, 0) + 1

func _get_signal_key(object: Object, signal_name: String) -> String:
	return "%s_%s" % [object.get_instance_id(), signal_name]
