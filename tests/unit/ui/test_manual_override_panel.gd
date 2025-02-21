## Test class for manual override panel functionality
##
## Tests the UI components and logic for manual combat overrides
## including value management, validation, and state tracking
@tool
extends GameTest

const TestedClass: PackedScene = preload("res://src/ui/components/combat/overrides/manual_override_panel.tscn")

var _instance: Control
var _override_applied_signal_emitted := false
var _last_override_data: Dictionary = {}

func before_each() -> void:
	await super.before_each()
	_instance = TestedClass.instantiate()
	add_child_autofree(_instance)
	track_test_node(_instance)
	_connect_signals()
	_reset_signals()

func after_each() -> void:
	_disconnect_signals()
	_reset_signals()
	await super.after_each()
	_instance = null

func _connect_signals() -> void:
	if not _instance:
		return
		
	if _instance.has_signal("override_applied"):
		_instance.connect("override_applied", _on_override_applied)

func _disconnect_signals() -> void:
	if not _instance:
		return
		
	if _instance.has_signal("override_applied") and _instance.is_connected("override_applied", _on_override_applied):
		_instance.disconnect("override_applied", _on_override_applied)

func _reset_signals() -> void:
	_override_applied_signal_emitted = false
	_last_override_data = {}

func _on_override_applied(data: Dictionary = {}) -> void:
	_override_applied_signal_emitted = true
	_last_override_data = data

# Test Cases
func test_initial_state() -> void:
	assert_not_null(_instance, "Override panel should be initialized")
	assert_false(_instance.visible, "Panel should be hidden by default")

func test_override_application() -> void:
	_instance.visible = true
	var test_data := {"type": "movement", "value": 2}
	_instance.emit_signal("override_applied", test_data)
	
	assert_true(_override_applied_signal_emitted, "Override signal should be emitted")
	assert_eq(_last_override_data, test_data, "Override data should match test data")

func test_visibility() -> void:
	_instance.visible = false
	var test_data := {"type": "movement"}
	_instance.emit_signal("override_applied", test_data)
	assert_false(_override_applied_signal_emitted, "Override signal should not be emitted when hidden")
	
	_instance.visible = true
	_instance.emit_signal("override_applied", test_data)
	assert_true(_override_applied_signal_emitted, "Override signal should be emitted when visible")

func test_child_nodes() -> void:
	var container = _instance.get_node_or_null("Container")
	assert_not_null(container, "Panel should have a Container node")

func test_signals() -> void:
	watch_signals(_instance)
	_instance.emit_signal("override_applied")
	verify_signal_emitted(_instance, "override_applied")
	
	_instance.emit_signal("override_cancelled")
	verify_signal_emitted(_instance, "override_cancelled")

func test_state_updates() -> void:
	_instance.visible = false
	assert_false(_instance.visible, "Panel should be hidden after visibility update")
	
	_instance.visible = true
	assert_true(_instance.visible, "Panel should be visible after visibility update")
	
	var container = _instance.get_node_or_null("Container")
	if container:
		container.custom_minimum_size = Vector2(200, 300)
		assert_eq(container.custom_minimum_size, Vector2(200, 300), "Container should update minimum size")

func test_child_management() -> void:
	var container = _instance.get_node_or_null("Container")
	if container:
		var test_child = Button.new()
		container.add_child(test_child)
		assert_true(test_child in container.get_children(), "Container should manage child nodes")
		assert_true(test_child.get_parent() == container, "Child should have correct parent")
		test_child.queue_free()

func test_panel_initialization() -> void:
	assert_not_null(_instance)
	assert_true(_instance.is_inside_tree())

func test_panel_nodes() -> void:
	assert_not_null(_instance.get_node("VBoxContainer"))
	assert_not_null(_instance.get_node("VBoxContainer/OverrideValue"))
	assert_not_null(_instance.get_node("VBoxContainer/ButtonContainer"))

func test_panel_properties() -> void:
	assert_eq(_instance.override_value, 0)
	assert_false(_instance.is_override_active)

func test_override_value() -> void:
	_instance.set_override_value(5)
	assert_eq(_instance.override_value, 5)
	
	var value_spinbox = _instance.get_node("VBoxContainer/OverrideValue")
	assert_eq(value_spinbox.value, 5)

func test_override_state() -> void:
	_instance.activate_override()
	assert_true(_instance.is_override_active)
	
	_instance.deactivate_override()
	assert_false(_instance.is_override_active)
	verify_signal_emitted(_instance, "override_cancelled")