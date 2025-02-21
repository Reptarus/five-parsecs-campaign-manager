@tool
extends GameTest

const TestedClass = preload("res://src/ui/components/combat/overrides/override_controller.gd")

var _instance: Node
var _override_applied_signal_emitted := false
var _override_cancelled_signal_emitted := false
var _last_context: String
var _last_value: int

func before_each() -> void:
	_instance = TestedClass.new()
	add_child(_instance)
	_connect_signals()
	_reset_signals()

func after_each() -> void:
	_disconnect_signals()
	_instance.queue_free()
	_instance = null

func _connect_signals() -> void:
	if _instance.has_signal("override_applied"):
		_instance.override_applied.connect(_on_override_applied)
	if _instance.has_signal("override_cancelled"):
		_instance.override_cancelled.connect(_on_override_cancelled)

func _disconnect_signals() -> void:
	if _instance and not _instance.is_queued_for_deletion():
		if _instance.has_signal("override_applied") and _instance.override_applied.is_connected(_on_override_applied):
			_instance.override_applied.disconnect(_on_override_applied)
		if _instance.has_signal("override_cancelled") and _instance.override_cancelled.is_connected(_on_override_cancelled):
			_instance.override_cancelled.disconnect(_on_override_cancelled)

func _reset_signals() -> void:
	_override_applied_signal_emitted = false
	_override_cancelled_signal_emitted = false
	_last_context = ""
	_last_value = 0

func _on_override_applied(context: String, value: int) -> void:
	_override_applied_signal_emitted = true
	_last_context = context
	_last_value = value

func _on_override_cancelled(context: String) -> void:
	_override_cancelled_signal_emitted = true
	_last_context = context

func test_initial_state() -> void:
	assert_false(_override_applied_signal_emitted)
	assert_false(_override_cancelled_signal_emitted)
	assert_eq(_instance.active_context, "")

func test_request_override() -> void:
	var test_context = "combat"
	var test_value = 3
	
	_instance.request_override(test_context, test_value)
	
	assert_eq(_instance.active_context, test_context)

func test_apply_override() -> void:
	var test_context = "combat"
	var test_value = 3
	
	_instance.request_override(test_context, test_value)
	_instance._on_override_applied(test_value)
	
	verify_signal_emitted(_instance, "override_applied")
	assert_true(_override_applied_signal_emitted)
	assert_eq(_last_context, test_context)
	assert_eq(_last_value, test_value)

func test_cancel_override() -> void:
	var test_context = "combat"
	var test_value = 3
	
	_instance.request_override(test_context, test_value)
	_instance._on_override_cancelled()
	
	verify_signal_emitted(_instance, "override_cancelled")
	assert_true(_override_cancelled_signal_emitted)
	assert_eq(_last_context, test_context)

func test_validate_override() -> void:
	var test_context = "combat"
	var test_value = 3
	
	var is_valid = _instance.validate_override(test_context, test_value)
	
	assert_true(is_valid)

func test_combat_system_setup() -> void:
	var mock_resolver = Node.new()
	var mock_manager = Node.new()
	
	_instance.setup_combat_system(mock_resolver, mock_manager)
	
	assert_not_null(_instance.combat_resolver)
	assert_not_null(_instance.combat_manager)
	
	mock_resolver.queue_free()
	mock_manager.queue_free()