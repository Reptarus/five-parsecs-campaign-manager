@tool
class_name BaseTest
extends "res://addons/gut/test.gd"

const GameEnums := preload("res://src/core/systems/GlobalEnums.gd")
const GameState := preload("res://src/core/state/GameState.gd")
const ResourceManager := preload("res://src/core/managers/ResourceManager.gd")
const StoryQuestData := preload("res://src/core/story/StoryQuestData.gd")

# Test configuration
var _performance_monitoring := false
var _start_time: int
var _memory_start: int
var _test_resources: Array[Resource]
var _test_nodes: Array[Node]

# Test lifecycle methods
func before_all() -> void:
	super.before_all()
	_test_resources = []
	_test_nodes = []

func after_all() -> void:
	super.after_all()
	_cleanup_test_resources()
	_cleanup_test_nodes()

func before_each() -> void:
	super.before_each()
	if _performance_monitoring:
		_start_performance_monitoring()

func after_each() -> void:
	super.after_each()
	if _performance_monitoring:
		_end_performance_monitoring()

# Resource Management
func track_resource(resource: Resource) -> void:
	_test_resources.append(resource)

func track_node(node: Node) -> void:
	_test_nodes.append(node)

func cleanup_node(node: Node) -> void:
	if is_instance_valid(node):
		node.queue_free()
		await node.tree_exited
		var idx := _test_nodes.find(node)
		if idx != -1:
			_test_nodes.remove_at(idx)

# State Management
func create_test_game_state() -> GameState:
	var state := GameState.new()
	track_resource(state)
	return state

func create_test_resource_manager() -> ResourceManager:
	var manager := ResourceManager.new()
	track_resource(manager)
	return manager

# Performance Monitoring
func enable_performance_monitoring() -> void:
	_performance_monitoring = true

func disable_performance_monitoring() -> void:
	_performance_monitoring = false

func _start_performance_monitoring() -> void:
	_start_time = Time.get_ticks_msec()
	_memory_start = OS.get_static_memory_usage()

func _end_performance_monitoring() -> void:
	var end_time := Time.get_ticks_msec()
	var memory_end := OS.get_static_memory_usage()
	
	var duration := end_time - _start_time
	var memory_delta := memory_end - _memory_start
	
	print("Performance Report for %s:" % [gut.get_current_test_object().name])
	print("  Duration: %d ms" % duration)
	print("  Memory Delta: %d bytes" % memory_delta)

# Common Assertions
func assert_between(value: float, min_value: float, max_value: float, message: String = "") -> void:
	var in_range := value >= min_value and value <= max_value
	assert_true(in_range, "%s Expected value between %f and %f, got %f" % [
		message if message else "",
		min_value,
		max_value,
		value
	])

func assert_string_contains(value: Variant, search: Variant, match_case: bool = true) -> Variant:
	var text := str(value)
	var substring := str(search)
	var contains := text.contains(substring) if match_case else text.to_lower().contains(substring.to_lower())
	assert_true(contains, "Expected '%s' to contain '%s'" % [text, substring])
	return null

func assert_has(dict: Dictionary, key: String, message: String = "") -> void:
	var has_key := dict.has(key)
	assert_true(has_key, "%s Expected dictionary to have key '%s'" % [
		message if message else "",
		key
	])

func assert_valid_resource(resource: Resource, message: String = "") -> void:
	assert_not_null(resource, "%s Expected resource to be valid" % [message if message else ""])
	assert_true(is_instance_valid(resource), "%s Expected resource to be valid instance" % [message if message else ""])

func assert_signal_emitted_with_data(obj: Object, signal_name: String, expected_data: Array, message: String = "") -> void:
	assert_signal_emitted(obj, signal_name, message)
	var emissions: int = get_signal_emit_count(obj, signal_name)
	if emissions > 0:
		var emit_data: Array = get_signal_parameters(obj, signal_name, emissions - 1)
		assert_eq(emit_data.size(), expected_data.size(), "Signal parameter count mismatch")
		for i in range(min(emit_data.size(), expected_data.size())):
			assert_eq(emit_data[i], expected_data[i], "Signal parameter %d mismatch" % i)

# Resource Cleanup
func _cleanup_test_resources() -> void:
	for resource in _test_resources:
		if is_instance_valid(resource):
			resource.free()
	_test_resources.clear()

func _cleanup_test_nodes() -> void:
	for node in _test_nodes:
		if is_instance_valid(node):
			node.queue_free()
	_test_nodes.clear()

# State Validation
func validate_game_state(state: GameState) -> bool:
	if not is_instance_valid(state):
		return false
		
	var is_valid := true
	is_valid = is_valid and state.resources.size() > 0
	is_valid = is_valid and state.campaign_turn >= 0
	is_valid = is_valid and state.story_points >= 0
	
	return is_valid

func validate_resource_manager(manager: ResourceManager) -> bool:
	if not is_instance_valid(manager):
		return false
		
	var is_valid := true
	is_valid = is_valid and manager.resources.size() > 0
	is_valid = is_valid and manager.resource_history.size() >= 0
	
	return is_valid