@tool
extends "res://tests/unit/ui/base/ui_test_base.gd"

# Base class for controller testing
# Do not use class_name to avoid conflicts

# Type-safe instance variables
var _controller: Node
var _controlled_nodes: Array[Node] = []
var _controller_signal_watcher: Node

func before_each() -> void:
	await super.before_each()
	_setup_controller()

func after_each() -> void:
	_cleanup_controller()
	await super.after_each()

func _setup_controller() -> void:
	_controller = _create_controller_instance()
	if not _controller:
		return
		
	add_child_autofree(_controller)
	track_test_node(_controller)
	
	# Setup signal watcher
	_controller_signal_watcher = Node.new()
	add_child_autofree(_controller_signal_watcher)
	track_test_node(_controller_signal_watcher)
	
	await stabilize_engine()

func _cleanup_controller() -> void:
	_controller = null
	_controlled_nodes.clear()
	_controller_signal_watcher = null

# Virtual method to be overridden by specific controller tests
func _create_controller_instance() -> Node:
	push_error("_create_controller_instance() must be implemented by derived class")
	return null

# Common Controller Tests
func test_controller_initialization() -> void:
	assert_not_null(_controller, "Controller instance should be created")
	assert_true(_controller.is_inside_tree(), "Controller should be in scene tree")

func test_controller_signals() -> void:
	var signals := _controller.get_signal_list()
	assert_gt(signals.size(), 0, "Controller should have signals")
	
	for signal_info in signals:
		var signal_name: String = signal_info.name
		assert_true(_controller.has_signal(signal_name),
			"Controller should have signal %s" % signal_name)

func test_controller_methods() -> void:
	var methods := _controller.get_method_list()
	var required_methods := _get_required_methods()
	
	for method in required_methods:
		assert_true(methods.any(func(m): return m.name == method),
			"Controller should have method %s" % method)

# Virtual method to be overridden by specific controller tests
func _get_required_methods() -> Array[String]:
	return []

func test_controller_state() -> void:
	# Test initial state
	var initial_state := _get_controller_state()
	assert_valid_controller_state(initial_state)
	
	# Test state after reset
	if _controller.has_method("reset"):
		_controller.reset()
		var reset_state := _get_controller_state()
		assert_valid_controller_state(reset_state)
		assert_state_reset(initial_state, reset_state)

func _get_controller_state() -> Dictionary:
	var state := {}
	var properties := _controller.get_property_list()
	
	for property in properties:
		if property.usage & PROPERTY_USAGE_SCRIPT_VARIABLE:
			state[property.name] = _controller.get(property.name)
	
	return state

func assert_valid_controller_state(state: Dictionary) -> void:
	for property in state:
		assert_not_null(state[property],
			"Controller property %s should not be null" % property)

func assert_state_reset(initial_state: Dictionary, reset_state: Dictionary) -> void:
	assert_eq(initial_state.size(), reset_state.size(),
		"Reset state should have same number of properties as initial state")
	
	for property in initial_state:
		assert_eq(initial_state[property], reset_state[property],
			"Reset state property %s should match initial state" % property)

# Signal Testing
func connect_controller_signals() -> void:
	var signals := _controller.get_signal_list()
	
	for signal_info in signals:
		var signal_name: String = signal_info.name
		_controller.connect(signal_name,
			func(args = []): _on_controller_signal(signal_name, args))

func _on_controller_signal(signal_name: String, args: Array = []) -> void:
	if not _controller_signal_watcher:
		return
	
	# Store signal emission for verification
	if not _controller_signal_watcher.has_meta(signal_name):
		_controller_signal_watcher.set_meta(signal_name, [])
	
	var emissions: Array = _controller_signal_watcher.get_meta(signal_name)
	emissions.append(args)
	_controller_signal_watcher.set_meta(signal_name, emissions)

func verify_controller_signal_emitted(signal_name: String, expected_args: Array = []) -> bool:
	if not _controller_signal_watcher.has_meta(signal_name):
		return false
	
	var emissions: Array = _controller_signal_watcher.get_meta(signal_name)
	if expected_args.is_empty():
		return true
	
	return emissions.any(func(args): return args == expected_args)

func verify_controller_signal_not_emitted(signal_name: String) -> bool:
	return not _controller_signal_watcher.has_meta(signal_name)

func get_signal_emission_count(signal_name: String) -> int:
	if not _controller_signal_watcher.has_meta(signal_name):
		return 0
	
	var emissions: Array = _controller_signal_watcher.get_meta(signal_name)
	return emissions.size()

# Controlled Node Management
func add_controlled_node(node: Node) -> void:
	add_child_autofree(node)
	track_test_node(node)
	_controlled_nodes.append(node)

func remove_controlled_node(node: Node) -> void:
	var index := _controlled_nodes.find(node)
	if index != -1:
		_controlled_nodes.remove_at(index)

func get_controlled_nodes() -> Array[Node]:
	return _controlled_nodes.duplicate()

# Performance Testing
func test_controller_performance() -> void:
	start_performance_monitoring()
	
	# Perform standard controller operations
	if _controller.has_method("update"):
		for i in range(10):
			_controller.update(0.016) # Simulate 60 FPS
			await get_tree().process_frame
	
	var metrics := stop_performance_monitoring()
	assert_performance_metrics(metrics, {
		"layout_updates": 20,
		"draw_calls": 10,
		"theme_lookups": 30
	})

# Helper Methods
func simulate_controller_update(delta: float = 0.016) -> void:
	if _controller.has_method("update"):
		_controller.update(delta)
		await get_tree().process_frame

func wait_for_controller_ready() -> void:
	await get_tree().process_frame
	assert_true(_controller.is_inside_tree(), "Controller should be ready")