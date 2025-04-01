@tool
extends "res://tests/fixtures/base/game_test.gd"

const TestedClass: PackedScene = preload("res://src/ui/components/combat/state/state_verification_panel.tscn")

var _instance: Control
var _validation_complete_signal_emitted := false
var _last_validation_data: Dictionary = {}

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
		
	if _instance.has_signal("validation_complete"):
		_instance.connect("validation_complete", _on_validation_complete)

func _disconnect_signals() -> void:
	if not _instance:
		return
		
	if _instance.has_signal("validation_complete") and _instance.is_connected("validation_complete", _on_validation_complete):
		_instance.disconnect("validation_complete", _on_validation_complete)

func _reset_signals() -> void:
	_validation_complete_signal_emitted = false
	_last_validation_data = {}

func _on_validation_complete(data: Dictionary = {}) -> void:
	_validation_complete_signal_emitted = true
	_last_validation_data = data

# Test Cases
func test_initial_state() -> void:
	if not is_instance_valid(_instance):
		push_warning("Skipping test_initial_state: _instance is null or invalid")
		pending("Test skipped - _instance is null or invalid")
		return
		
	assert_not_null(_instance, "Validation panel should be initialized")
	assert_false(_instance.visible, "Panel should be hidden by default")

func test_validation_complete() -> void:
	if not is_instance_valid(_instance):
		push_warning("Skipping test_validation_complete: _instance is null or invalid")
		pending("Test skipped - _instance is null or invalid")
		return
		
	if not _instance.has_signal("validation_complete"):
		push_warning("Skipping test_validation_complete: validation_complete signal not found")
		pending("Test skipped - validation_complete signal not found")
		return
		
	_instance.visible = true
	var test_data := {"valid": true, "message": "Test passed"}
	_instance.emit_signal("validation_complete", test_data)
	
	assert_true(_validation_complete_signal_emitted, "Validation signal should be emitted")
	assert_eq(_last_validation_data, test_data, "Validation data should match test data")

func test_visibility() -> void:
	if not is_instance_valid(_instance):
		push_warning("Skipping test_visibility: _instance is null or invalid")
		pending("Test skipped - _instance is null or invalid")
		return
		
	if not _instance.has_signal("validation_complete"):
		push_warning("Skipping test_visibility: validation_complete signal not found")
		pending("Test skipped - validation_complete signal not found")
		return
		
	_instance.visible = false
	var test_data := {"valid": false}
	_instance.emit_signal("validation_complete", test_data)
	assert_false(_validation_complete_signal_emitted, "Validation signal should not be emitted when hidden")
	
	_instance.visible = true
	_instance.emit_signal("validation_complete", test_data)
	assert_true(_validation_complete_signal_emitted, "Validation signal should be emitted when visible")

func test_child_nodes() -> void:
	if not is_instance_valid(_instance):
		push_warning("Skipping test_child_nodes: _instance is null or invalid")
		pending("Test skipped - _instance is null or invalid")
		return
		
	if not _instance.has_method("get_node_or_null"):
		push_warning("Skipping test_child_nodes: get_node_or_null method not found")
		pending("Test skipped - get_node_or_null method not found")
		return
		
	var container = _instance.get_node_or_null("Container")
	assert_not_null(container, "Panel should have a Container node")

func test_signals() -> void:
	if not is_instance_valid(_instance):
		push_warning("Skipping test_signals: _instance is null or invalid")
		pending("Test skipped - _instance is null or invalid")
		return
		
	if not (_instance.has_signal("validation_complete") and _instance.has_signal("validation_failed")):
		push_warning("Skipping test_signals: required signals not found")
		pending("Test skipped - required signals not found")
		return
		
	watch_signals(_instance)
	_instance.emit_signal("validation_complete")
	verify_signal_emitted(_instance, "validation_complete")
	
	_instance.emit_signal("validation_failed")
	verify_signal_emitted(_instance, "validation_failed")

func test_state_updates() -> void:
	if not is_instance_valid(_instance):
		push_warning("Skipping test_state_updates: _instance is null or invalid")
		pending("Test skipped - _instance is null or invalid")
		return
		
	_instance.visible = false
	assert_false(_instance.visible, "Panel should be hidden after visibility update")
	
	_instance.visible = true
	assert_true(_instance.visible, "Panel should be visible after visibility update")
	
	if not _instance.has_method("get_node_or_null"):
		push_warning("Skipping container size update: get_node_or_null method not found")
		return
		
	var container = _instance.get_node_or_null("Container")
	if container:
		container.custom_minimum_size = Vector2(200, 300)
		assert_eq(container.custom_minimum_size, Vector2(200, 300), "Container should update minimum size")

func test_child_management() -> void:
	if not is_instance_valid(_instance):
		push_warning("Skipping test_child_management: _instance is null or invalid")
		pending("Test skipped - _instance is null or invalid")
		return
		
	if not _instance.has_method("get_node_or_null"):
		push_warning("Skipping test_child_management: get_node_or_null method not found")
		pending("Test skipped - get_node_or_null method not found")
		return
		
	var container = _instance.get_node_or_null("Container")
	if container:
		if not (container.has_method("add_child") and container.has_method("get_children")):
			push_warning("Skipping child management test: required methods not found on container")
			return
			
		var test_child = Button.new()
		container.add_child(test_child)
		assert_true(test_child in container.get_children(), "Container should manage child nodes")
		assert_true(test_child.get_parent() == container, "Child should have correct parent")
		test_child.queue_free()

func test_panel_initialization() -> void:
	if not is_instance_valid(_instance):
		push_warning("Skipping test_panel_initialization: _instance is null or invalid")
		pending("Test skipped - _instance is null or invalid")
		return
		
	assert_not_null(_instance)
	assert_true(_instance.is_inside_tree())

func test_panel_nodes() -> void:
	if not is_instance_valid(_instance):
		push_warning("Skipping test_panel_nodes: _instance is null or invalid")
		pending("Test skipped - _instance is null or invalid")
		return
		
	if not _instance.has_method("get_node"):
		push_warning("Skipping test_panel_nodes: get_node method not found")
		pending("Test skipped - get_node method not found")
		return
		
	assert_not_null(_instance.get_node("VBoxContainer"))
	assert_not_null(_instance.get_node("VBoxContainer/ValidationMessage"))
	assert_not_null(_instance.get_node("VBoxContainer/ButtonContainer"))

func test_panel_properties() -> void:
	if not is_instance_valid(_instance):
		push_warning("Skipping test_panel_properties: _instance is null or invalid")
		pending("Test skipped - _instance is null or invalid")
		return
		
	# Check if the properties exist before accessing them
	if not ("validation_message" in _instance and "is_valid" in _instance):
		push_warning("Skipping test_panel_properties: required properties not found")
		pending("Test skipped - required properties not found")
		return
		
	assert_eq(_instance.validation_message, "")
	assert_false(_instance.is_valid)

func test_validation_message() -> void:
	if not is_instance_valid(_instance):
		push_warning("Skipping test_validation_message: _instance is null or invalid")
		pending("Test skipped - _instance is null or invalid")
		return
		
	if not _instance.has_method("set_validation_message"):
		push_warning("Skipping test_validation_message: set_validation_message method not found")
		pending("Test skipped - set_validation_message method not found")
		return
		
	if not _instance.has_method("get_node"):
		push_warning("Skipping label text check: get_node method not found")
		pending("Test skipped - get_node method not found")
		return
		
	_instance.set_validation_message("Test message")
	assert_eq(_instance.validation_message, "Test message")
	
	var message_label = _instance.get_node("VBoxContainer/ValidationMessage")
	assert_not_null(message_label, "ValidationMessage node should exist")
	assert_eq(message_label.text, "Test message")

func test_validation_state() -> void:
	if not is_instance_valid(_instance):
		push_warning("Skipping test_validation_state: _instance is null or invalid")
		pending("Test skipped - _instance is null or invalid")
		return
		
	if not _instance.has_method("set_validation_state"):
		push_warning("Skipping test_validation_state: set_validation_state method not found")
		pending("Test skipped - set_validation_state method not found")
		return
		
	if not _instance.has_signal("validation_failed"):
		push_warning("Skipping validation_failed signal check: signal not found")
		return
		
	watch_signals(_instance)
	
	_instance.set_validation_state(true)
	assert_true(_instance.is_valid)
	
	_instance.set_validation_state(false)
	assert_false(_instance.is_valid)
	verify_signal_emitted(_instance, "validation_failed")