@tool
extends ControllerTestBase

const TestedClass := preload("res://src/ui/components/combat/overrides/override_controller.gd")

# Type-safe instance variables
var _last_context: String
var _last_value: int

# Override _create_controller_instance to provide the specific controller
func _create_controller_instance() -> Node:
	return TestedClass.new()

# Override _get_required_methods to specify required controller methods
func _get_required_methods() -> Array[String]:
	return [
		"request_override",
		"validate_override",
		"setup_combat_system"
	]

func before_each() -> void:
	await super.before_each()
	_reset_state()
	connect_controller_signals()

func after_each() -> void:
	_reset_state()
	await super.after_each()

func _reset_state() -> void:
	_last_context = ""
	_last_value = 0

func _on_override_applied(context: String, value: int) -> void:
	_last_context = context
	_last_value = value

func _on_override_cancelled(context: String) -> void:
	_last_context = context

func test_initial_state() -> void:
	await test_controller_state()
	
	# Additional state checks for override controller
	assert_signal_not_emitted(_controller, "override_applied")
	assert_signal_not_emitted(_controller, "override_cancelled")
	assert_eq(_controller.active_context, "")

func test_request_override() -> void:
	var test_context := "combat"
	var test_value := 3
	
	_controller.request_override(test_context, test_value)
	
	assert_eq(_controller.active_context, test_context)

func test_apply_override() -> void:
	var test_context := "combat"
	var test_value := 3
	
	_controller.request_override(test_context, test_value)
	_controller._on_override_applied(test_value)
	
	assert_signal_emitted(_controller, "override_applied")
	assert_eq(_last_context, test_context)
	assert_eq(_last_value, test_value)

func test_cancel_override() -> void:
	var test_context := "combat"
	var test_value := 3
	
	_controller.request_override(test_context, test_value)
	_controller._on_override_cancelled()
	
	assert_signal_emitted(_controller, "override_cancelled")
	assert_eq(_last_context, test_context)

func test_validate_override() -> void:
	var test_context := "combat"
	var test_value := 3
	
	var is_valid: bool = _controller.validate_override(test_context, test_value)
	
	assert_true(is_valid)

func test_combat_system_setup() -> void:
	var mock_resolver := Node.new()
	var mock_manager := Node.new()
	
	add_controlled_node(mock_resolver)
	add_controlled_node(mock_manager)
	
	_controller.setup_combat_system(mock_resolver, mock_manager)
	
	assert_not_null(_controller.combat_resolver)
	assert_not_null(_controller.combat_manager)

# Additional tests using base class functionality
func test_controller_signals() -> void:
	await super.test_controller_signals()
	
	# Additional signal checks for override controller
	var required_signals := [
		"override_applied",
		"override_cancelled"
	]
	
	for signal_name in required_signals:
		assert_true(_controller.has_signal(signal_name),
			"Controller should have signal %s" % signal_name)

func test_controller_state() -> void:
	await super.test_controller_state()
	
	# Additional state checks for override controller
	assert_valid_controller_state({
		"active_context": "",
		"combat_resolver": null,
		"combat_manager": null
	})

func test_override_sequence() -> void:
	var test_context := "combat"
	var test_values := [1, 2, 3, 4, 5]
	
	for value in test_values:
		_controller.request_override(test_context, value)
		assert_eq(_controller.active_context, test_context)
		
		_controller._on_override_applied(value)
		assert_signal_emitted(_controller, "override_applied")
		assert_eq(_last_value, value)
		
		_controller._on_override_cancelled()
		assert_signal_emitted(_controller, "override_cancelled")
		assert_eq(_last_context, test_context)

func test_controller_performance() -> void:
	start_performance_monitoring()
	
	# Perform override controller specific operations
	var test_context := "combat"
	var test_values := [1, 2, 3, 4, 5]
	
	for value in test_values:
		_controller.request_override(test_context, value)
		_controller._on_override_applied(value)
		_controller._on_override_cancelled()
		await get_tree().process_frame
	
	var metrics := stop_performance_monitoring()
	assert_performance_metrics(metrics, {
		"layout_updates": 10,
		"draw_calls": 5,
		"theme_lookups": 15
	})

func test_invalid_overrides() -> void:
	# Test invalid context
	var invalid_context := ""
	var test_value := 3
	
	var is_valid: bool = _controller.validate_override(invalid_context, test_value)
	assert_false(is_valid)
	
	# Test invalid value
	var test_context := "combat"
	var invalid_value := -1
	
	is_valid = _controller.validate_override(test_context, invalid_value)
	assert_false(is_valid)
	
	# Test with null combat system
	_controller.request_override(test_context, test_value)
	assert_eq(_controller.active_context, test_context)
	assert_null(_controller.combat_resolver)
	assert_null(_controller.combat_manager)

func test_combat_system_cleanup() -> void:
	var mock_resolver := Node.new()
	var mock_manager := Node.new()
	
	add_controlled_node(mock_resolver)
	add_controlled_node(mock_manager)
	
	_controller.setup_combat_system(mock_resolver, mock_manager)
	assert_not_null(_controller.combat_resolver)
	assert_not_null(_controller.combat_manager)
	
	mock_resolver.queue_free()
	mock_manager.queue_free()
	
	await get_tree().process_frame
	
	assert_null(_controller.combat_resolver)
	assert_null(_controller.combat_manager)