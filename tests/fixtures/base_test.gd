extends "res://addons/gut/test.gd"

# Base test functionality that all tests should inherit from
class_name BaseTest

const GameEnums = preload("res://src/core/systems/GlobalEnums.gd")
const GutMain = preload("res://addons/gut/gut.gd")

var gut: GutMain
var _signal_watcher = null
var _tracked_resources: Array[Resource] = []
var _tracked_nodes: Array[Node] = []

# Signal handling
func watch_signals(object: Object) -> void:
	if not _signal_watcher and gut:
		_signal_watcher = gut.get_signal_watcher()
	if _signal_watcher:
		_signal_watcher.watch_signals(object)

func clear_signal_watcher() -> void:
	if _signal_watcher:
		_signal_watcher.clear()
	_signal_watcher = null

# Signal assertion helpers
func assert_signal_emitted(object: Object, signal_name: String, message: String = "") -> void:
	if not _signal_watcher and gut:
		_signal_watcher = gut.get_signal_watcher()
	if _signal_watcher:
		assert_true(_signal_watcher.did_emit(object, signal_name),
			message if message else "Signal '%s' should have been emitted" % signal_name)

func assert_signal_not_emitted(object: Object, signal_name: String, message: String = "") -> void:
	if not _signal_watcher and gut:
		_signal_watcher = gut.get_signal_watcher()
	if _signal_watcher:
		assert_false(_signal_watcher.did_emit(object, signal_name),
			message if message else "Signal '%s' should not have been emitted" % signal_name)

func assert_signal_emit_count(object: Object, signal_name: String, times: int, message: String = "") -> void:
	if not _signal_watcher and gut:
		_signal_watcher = gut.get_signal_watcher()
	if _signal_watcher:
		assert_eq(_signal_watcher.get_emit_count(object, signal_name), times,
			message if message else "Signal '%s' should have been emitted %d times" % [signal_name, times])

# Resource tracking
func track_test_resource(resource: Resource) -> void:
	if not resource:
		return
	if not _tracked_resources.has(resource):
		_tracked_resources.append(resource)

# Node tracking
func track_test_node(node: Node) -> void:
	if not node:
		return
	if not _tracked_nodes.has(node):
		if not node.is_inside_tree() and not node.is_queued_for_deletion():
			add_child(node)
		_tracked_nodes.append(node)

# Cleanup helpers
func _cleanup_resource(resource: Resource) -> void:
	if not resource:
		return
	if resource is RefCounted:
		resource = null # Let reference counting handle cleanup
	else:
		if is_instance_valid(resource) and not resource.is_queued_for_deletion():
			resource.free()

func _cleanup_node(node: Node) -> void:
	if not node:
		return
	if is_instance_valid(node):
		if node.is_inside_tree() and not node.is_queued_for_deletion():
			node.queue_free()

# Lifecycle methods
func before_each() -> void:
	super.before_each()

func after_each() -> void:
	# Clean up tracked resources
	for resource in _tracked_resources:
		_cleanup_resource(resource)
	_tracked_resources.clear()
	
	# Clean up tracked nodes
	for node in _tracked_nodes:
		_cleanup_node(node)
	_tracked_nodes.clear()
	
	# Clean up signal watchers
	clear_signal_watcher()
	
	super.after_each()

# Common assertions
func assert_has_method(obj: Object, method: String, message: String = "") -> void:
	assert_true(obj.has_method(method), message if message else "Object should have method '%s'" % method)

func assert_has_signal(obj: Object, signal_name: String, message: String = "") -> void:
	assert_true(obj.has_signal(signal_name), message if message else "Object should have signal '%s'" % signal_name)

func assert_resource_valid(resource: Resource, message: String = "") -> void:
	assert_not_null(resource, message if message else "Resource should not be null")
	assert_true(is_instance_valid(resource), message if message else "Resource should be valid")

func assert_node_valid(node: Node, message: String = "") -> void:
	assert_not_null(node, message if message else "Node should not be null")
	assert_true(is_instance_valid(node), message if message else "Node should be valid")
	assert_true(node.is_inside_tree(), message if message else "Node should be in scene tree")

# Utility methods
func wait_frames(frames: int = 1) -> void:
	for i in range(frames):
		await get_tree().process_frame