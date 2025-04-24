@tool
extends "res://tests/unit/ui/base/ui_test_base.gd"

# Base class for controller testing
# Do not use class_name to avoid conflicts

# Type-safe instance variables
var _controller: Node
var _controlled_nodes: Array[Node] = []
var _controller_signal_watcher: Node
var _mock_state: Node
var _connected_controller_signals: Array[String] = []

func before_each() -> void:
	await super.before_each()
	_setup_controller()

func after_each() -> void:
	_cleanup_controller()
	await super.after_each()

func _setup_controller() -> void:
	_controller = _create_controller_instance()
	if not is_instance_valid(_controller):
		push_warning("Failed to create controller instance in _setup_controller")
		return
		
	# Add with proper ownership handling and lifecycle management
	call_deferred("add_child_autofree", _controller)
	track_test_node(_controller)
	
	# Setup signal watcher with deferred call to prevent bad address index
	_controller_signal_watcher = Node.new()
	_controller_signal_watcher.name = "ControllerSignalWatcher"
	call_deferred("add_child_autofree", _controller_signal_watcher)
	track_test_node(_controller_signal_watcher)
	
	# Create mock state with deferred call
	_mock_state = _create_mock_state()
	
	# Use a deferred call for setting state to avoid ordering issues
	if _controller.has_method("set_state"):
		call_deferred("_set_controller_state")
	
	# Allow deferred calls to complete
	await get_tree().process_frame
	await stabilize_engine()

# Helper method for deferred state setting
func _set_controller_state() -> void:
	if is_instance_valid(_controller) and is_instance_valid(_mock_state) and _controller.has_method("set_state"):
		_controller.set_state(_mock_state)

func _cleanup_controller() -> void:
	_disconnect_controller_signals()
	_controller = null
	_controlled_nodes.clear()
	_controller_signal_watcher = null
	_mock_state = null
	_connected_controller_signals.clear()

# Virtual method to be overridden by specific controller tests
func _create_controller_instance() -> Node:
	push_warning("_create_controller_instance() must be implemented by derived class")
	return null

# Common Controller Tests
func test_controller_initialization() -> void:
	if not is_instance_valid(_controller):
		assert_fail("Skipping test_controller_initialization: controller is null or invalid")
		pending("Cannot test controller initialization: controller is null or invalid")
		return
		
	assert_not_null(_controller, "Controller instance should be created")
	assert_true(_controller.is_inside_tree(), "Controller should be in scene tree")

func test_controller_signals() -> void:
	if not is_instance_valid(_controller):
		assert_fail("Skipping test_controller_signals: controller is null or invalid")
		pending("Cannot test controller signals: controller is null or invalid")
		return
		
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
	if not is_instance_valid(_controller):
		assert_fail("Skipping test_controller_state: controller is null or invalid")
		pending("Cannot test controller state: controller is null or invalid")
		return
		
	# Test initial state
	var initial_state := _get_controller_state()
	if initial_state.is_empty():
		push_warning("Initial controller state is empty")
		pending("Controller state test skipped: empty initial state")
		return
		
	assert_valid_controller_state(initial_state)
	
	# Test state after reset
	if _controller.has_method("reset"):
		var reset_result = TypeSafeMixin._call_node_method(_controller, "reset", [])
		
		# Allow a brief moment for reset to take effect
		await get_tree().process_frame
		
		var reset_state := _get_controller_state()
		if reset_state.is_empty():
			push_warning("Reset controller state is empty")
			pending("Controller state test skipped: empty reset state")
			return
			
		assert_valid_controller_state(reset_state)
		assert_state_reset(initial_state, reset_state)
	else:
		pending("Controller reset method not available")

func _get_controller_state() -> Dictionary:
	if not is_instance_valid(_controller):
		push_warning("Cannot get state: controller is null or invalid")
		return {}
		
	var state := {}
	var properties := _controller.get_property_list()
	
	for property in properties:
		if property.usage & PROPERTY_USAGE_SCRIPT_VARIABLE:
			var value = null
			if _controller.has_method("get_" + property.name):
				value = TypeSafeMixin._call_node_method(_controller, "get_" + property.name, [])
			else:
				value = _controller.get(property.name)
			state[property.name] = value
	
	return state

func assert_valid_controller_state(state: Dictionary) -> void:
	if not state:
		assert_fail("Controller state dictionary is null or empty")
		return
		
	for property in state.keys():
		var value = state[property]
		if value == null and not _is_nullable_property(property):
			assert_fail("Controller property %s should not be null" % property)

func _is_nullable_property(property_name: String) -> bool:
	# Override in derived classes to specify which properties can be null
	return false

func assert_state_reset(initial_state: Dictionary, reset_state: Dictionary) -> void:
	assert_eq(initial_state.size(), reset_state.size(),
		"Reset state should have same number of properties as initial state")
	
	for property in initial_state.keys():
		# Compare only non-reference properties or simple data types
		if _is_simple_property(property):
			assert_eq(initial_state[property], reset_state[property],
				"Reset state property %s should match initial state" % property)

func _is_simple_property(property_name: String) -> bool:
	# Override in derived classes to specify which properties are simple data types
	return true

# Signal Testing
func connect_controller_signals() -> void:
	if not _controller:
		assert_fail("Cannot connect signals: controller is null")
		return
		
	var signals := _controller.get_signal_list()
	
	for signal_info in signals:
		var signal_name: String = signal_info.name
		_connect_controller_signal(signal_name)

func _connect_controller_signal(signal_name: String) -> void:
	if not is_instance_valid(_controller):
		return
		
	if not _controller.has_signal(signal_name):
		push_warning("Controller does not have signal: %s" % signal_name)
		return
		
	# Create the callable with proper binding
	var callable = Callable(self, "_on_controller_signal").bind(signal_name)
	
	# Skip if already connected to avoid double connections
	if _controller.is_connected(signal_name, callable):
		return
		
	_controller.connect(signal_name, callable)
	if not _connected_controller_signals.has(signal_name):
		_connected_controller_signals.append(signal_name)

func _disconnect_controller_signals() -> void:
	if not is_instance_valid(_controller) or _controller.is_queued_for_deletion():
		return
	
	# Make array copy to avoid modification during iteration
	var signals_to_disconnect = _connected_controller_signals.duplicate()
	for signal_name in signals_to_disconnect:
		var callable = Callable(self, "_on_controller_signal").bind(signal_name)
		if _controller.is_connected(signal_name, callable):
			_controller.disconnect(signal_name, callable)
			
	_connected_controller_signals.clear()

func _on_controller_signal(args: Variant = null, signal_name: String = "") -> void:
	if not is_instance_valid(_controller_signal_watcher) or signal_name.is_empty():
		return
	
	# Store signal emission for verification
	if not _controller_signal_watcher.has_meta(signal_name):
		_controller_signal_watcher.set_meta(signal_name, [])
	
	var emissions: Array = _controller_signal_watcher.get_meta(signal_name)
	emissions.append(args)
	_controller_signal_watcher.set_meta(signal_name, emissions)

func verify_controller_signal_emitted(signal_name: String, expected_args: Variant = null) -> bool:
	if not _controller_signal_watcher or not _controller_signal_watcher.has_meta(signal_name):
		return false
	
	var emissions: Array = _controller_signal_watcher.get_meta(signal_name)
	if emissions.is_empty():
		return false
		
	if expected_args == null:
		return true
	
	return emissions.any(func(args): return args == expected_args)

func verify_controller_signal_not_emitted(signal_name: String) -> bool:
	return not _controller_signal_watcher or not _controller_signal_watcher.has_meta(signal_name)

func get_signal_emission_count(signal_name: String) -> int:
	if not _controller_signal_watcher or not _controller_signal_watcher.has_meta(signal_name):
		return 0
	
	var emissions: Array = _controller_signal_watcher.get_meta(signal_name)
	return emissions.size()

# Controlled Node Management
func add_controlled_node(node: Node) -> void:
	if not node:
		assert_fail("Cannot add null controlled node")
		return
		
	add_child_autofree(node)
	track_test_node(node)
	_controlled_nodes.append(node)

func remove_controlled_node(node: Node) -> void:
	if not node:
		return
		
	var index := _controlled_nodes.find(node)
	if index != -1:
		_controlled_nodes.remove_at(index)

func get_controlled_nodes() -> Array[Node]:
	return _controlled_nodes.duplicate()

# Performance Testing
func test_controller_performance() -> void:
	if not _controller:
		assert_fail("Cannot test performance: controller is null")
		return
		
	start_performance_monitoring()
	
	# Perform standard controller operations
	if _controller.has_method("update"):
		for i in range(10):
			TypeSafeMixin._call_node_method_bool(_controller, "update", [0.016]) # Simulate 60 FPS
			await get_tree().process_frame
	
	var metrics := stop_performance_monitoring()
	assert_performance_metrics(metrics, {
		"layout_updates": 20,
		"draw_calls": 10,
		"theme_lookups": 30
	})

# Helper Methods
func simulate_controller_update(delta: float = 0.016) -> void:
	if not _controller:
		assert_fail("Cannot simulate update: controller is null")
		return
		
	if _controller.has_method("update"):
		TypeSafeMixin._call_node_method_bool(_controller, "update", [delta])
		await get_tree().process_frame

func wait_for_controller_ready() -> void:
	await get_tree().process_frame
	if not _controller:
		assert_fail("Controller is null after waiting for ready")
		return
		
	assert_true(_controller.is_inside_tree(), "Controller should be ready")

func _create_mock_state() -> Node:
	_mock_state = Node.new()
	add_child_autofree(_mock_state)
	return _mock_state

func assert_fail(message: String) -> void:
	assert_true(false, message)
