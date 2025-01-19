@tool
extends "res://addons/gut/test.gd"

# Base test class that all test scripts should extend from
class_name BaseTest

const GutMain := preload("res://addons/gut/gut.gd")

# Required GUT properties
var _was_ready_called := false
var _skip_script := false
var _skip_reason := ""
var _logger = null

# This is the property that GUT will set directly
var gut: GutMain:
	get:
		return _gut
	set(value):
		_gut = value

var _tracked_nodes: Array[Node] = []
var _tracked_resources: Array[Resource] = []
var _signal_watcher = null
var _gut: GutMain = null

func get_gut() -> GutMain:
	if not _gut:
		_gut = get_parent() as GutMain
	return _gut

func set_gut(gut: GutMain) -> void:
	_gut = gut

func get_skip_reason() -> String:
	return _skip_reason

func should_skip_script() -> bool:
	return _skip_script

func _do_ready_stuff() -> void:
	_was_ready_called = true

# Signal handling
func watch_signals(object: Object) -> void:
	if not _signal_watcher:
		_signal_watcher = get_gut().get_signal_watcher()
	_signal_watcher.watch_signals(object)

func clear_signal_watcher() -> void:
	if _signal_watcher:
		_signal_watcher.clear()
	_signal_watcher = null

# Override GUT's signal assertion methods
func assert_signal_emitted(object: Object, signal_name: String, text: String = "") -> void:
	if not _signal_watcher:
		assert_true(false, "Signal watcher not initialized. Did you call watch_signals()?")
		return
	var did_emit = _signal_watcher.did_emit(object, signal_name)
	assert_true(did_emit, text if text else "Signal '%s' was not emitted" % signal_name)

func assert_signal_not_emitted(object: Object, signal_name: String, text: String = "") -> void:
	if not _signal_watcher:
		assert_true(false, "Signal watcher not initialized. Did you call watch_signals()?")
		return
	var did_emit = _signal_watcher.did_emit(object, signal_name)
	assert_false(did_emit, text if text else "Signal '%s' was emitted" % signal_name)

func assert_signal_emit_count(object: Object, signal_name: String, times: int, text: String = "") -> void:
	if not _signal_watcher:
		assert_true(false, "Signal watcher not initialized. Did you call watch_signals()?")
		return
	var count = _signal_watcher.get_emit_count(object, signal_name)
	assert_eq(count, times, text if text else "Signal '%s' emit count %d != %d" % [signal_name, count, times])

# Lifecycle methods
func before_each() -> void:
	await super.before_each()
	_tracked_nodes = []
	_tracked_resources = []
	_signal_watcher = null

func after_each() -> void:
	await super.after_each()
	clear_signal_watcher()
	
	for node in _tracked_nodes:
		if is_instance_valid(node) and node.is_inside_tree():
			node.queue_free()
	_tracked_nodes.clear()
	
	for resource in _tracked_resources:
		if resource:
			resource.free()
	_tracked_resources.clear()

# Helper methods
func track_test_node(node: Node) -> void:
	_tracked_nodes.append(node)

func track_test_resource(resource: Resource) -> void:
	_tracked_resources.append(resource)

func assert_valid_game_state(game_state: Node) -> void:
	assert_not_null(game_state, "Game state should not be null")
	assert_true(is_instance_valid(game_state), "Game state should be valid")

func set_logger(logger) -> void:
	_logger = logger
