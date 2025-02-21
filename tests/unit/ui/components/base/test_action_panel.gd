@tool
extends GameTest

const TestedClass: PackedScene = preload("res://src/scenes/campaign/components/ActionPanel.tscn")

var _instance: Control
var _action_triggered_signal_emitted := false
var _last_action_data: Dictionary = {}

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
		
	if _instance.has_signal("action_triggered"):
		_instance.connect("action_triggered", _on_action_triggered)

func _disconnect_signals() -> void:
	if not _instance:
		return
		
	if _instance.has_signal("action_triggered") and _instance.is_connected("action_triggered", _on_action_triggered):
		_instance.disconnect("action_triggered", _on_action_triggered)

func _reset_signals() -> void:
	_action_triggered_signal_emitted = false
	_last_action_data = {}

func _on_action_triggered(data: Dictionary = {}) -> void:
	_action_triggered_signal_emitted = true
	_last_action_data = data

# Test Cases
func test_initial_state() -> void:
	assert_not_null(_instance, "Panel should be initialized")
	assert_false(_instance.visible, "Panel should be hidden by default")

func test_action_trigger() -> void:
	_instance.visible = true
	var test_data := {"action": "test", "value": 42}
	_instance.emit_signal("action_triggered", test_data)
	
	assert_true(_action_triggered_signal_emitted, "Action signal should be emitted")
	assert_eq(_last_action_data, test_data, "Action data should match test data")

func test_visibility() -> void:
	_instance.visible = false
	var test_data := {"action": "test"}
	_instance.emit_signal("action_triggered", test_data)
	assert_false(_action_triggered_signal_emitted, "Action signal should not be emitted when hidden")
	
	_instance.visible = true
	_instance.emit_signal("action_triggered", test_data)
	assert_true(_action_triggered_signal_emitted, "Action signal should be emitted when visible")

func test_child_nodes() -> void:
	var container = _instance.get_node_or_null("Container")
	assert_not_null(container, "Panel should have a Container node")

func test_initial_setup() -> void:
	assert_not_null(_instance, "Action panel should be instantiated")
	assert_true(_instance.is_inside_tree(), "Panel should be in scene tree")
	assert_true(_instance.visible, "Panel should be visible by default")

func test_layout() -> void:
	assert_true(_instance.has_node("Container"), "Panel should have container node")
	var container = _instance.get_node("Container")
	assert_not_null(container, "Container node should exist")
	assert_true(container.visible, "Container should be visible")
	assert_true(container is Control, "Container should be a Control node")

func test_signals() -> void:
	watch_signals(_instance)
	_instance.emit_signal("action_selected")
	verify_signal_emitted(_instance, "action_selected")
	
	_instance.emit_signal("panel_closed")
	verify_signal_emitted(_instance, "panel_closed")

func test_state_updates() -> void:
	_instance.visible = false
	assert_false(_instance.visible, "Panel should be hidden after visibility update")
	
	_instance.visible = true
	assert_true(_instance.visible, "Panel should be visible after visibility update")
	
	var container = _instance.get_node("Container")
	container.custom_minimum_size = Vector2(200, 300)
	assert_eq(container.custom_minimum_size, Vector2(200, 300), "Container should update minimum size")

func test_child_management() -> void:
	var container = _instance.get_node("Container")
	var test_child = Button.new()
	container.add_child(test_child)
	assert_true(test_child in container.get_children(), "Container should manage child nodes")
	assert_true(test_child.get_parent() == container, "Child should have correct parent")
	
	test_child.queue_free()
	await get_tree().process_frame
	assert_false(container.get_children().has(test_child), "Container should remove freed children")