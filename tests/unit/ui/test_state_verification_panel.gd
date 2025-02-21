## Test class for state verification panel functionality
##
## Tests the UI components and logic for game state verification
## including state comparison, validation, and result tracking
@tool
extends GameTest

const TestedClass: PackedScene = preload("res://src/ui/components/combat/state/state_verification_panel.tscn")

var _instance: Control
var _verification_complete_signal_emitted := false
var _last_verification_data: Dictionary = {}

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
		
	if _instance.has_signal("verification_complete"):
		_instance.connect("verification_complete", _on_verification_complete)

func _disconnect_signals() -> void:
	if not _instance:
		return
		
	if _instance.has_signal("verification_complete") and _instance.is_connected("verification_complete", _on_verification_complete):
		_instance.disconnect("verification_complete", _on_verification_complete)

func _reset_signals() -> void:
	_verification_complete_signal_emitted = false
	_last_verification_data = {}

func _on_verification_complete(data: Dictionary = {}) -> void:
	_verification_complete_signal_emitted = true
	_last_verification_data = data

# Test Cases
func test_initial_state() -> void:
	assert_not_null(_instance, "Verification panel should be initialized")
	assert_false(_instance.visible, "Panel should be hidden by default")

func test_verification_complete() -> void:
	_instance.visible = true
	var test_data := {"valid": true, "message": "Test passed"}
	_instance.emit_signal("verification_complete", test_data)
	
	assert_true(_verification_complete_signal_emitted, "Verification signal should be emitted")
	assert_eq(_last_verification_data, test_data, "Verification data should match test data")

func test_visibility() -> void:
	_instance.visible = false
	var test_data := {"valid": false}
	_instance.emit_signal("verification_complete", test_data)
	assert_false(_verification_complete_signal_emitted, "Verification signal should not be emitted when hidden")
	
	_instance.visible = true
	_instance.emit_signal("verification_complete", test_data)
	assert_true(_verification_complete_signal_emitted, "Verification signal should be emitted when visible")

func test_child_nodes() -> void:
	var container = _instance.get_node_or_null("Container")
	assert_not_null(container, "Panel should have a Container node")

func test_signals() -> void:
	watch_signals(_instance)
	_instance.emit_signal("verification_complete")
	verify_signal_emitted(_instance, "verification_complete")
	
	_instance.emit_signal("verification_failed")
	verify_signal_emitted(_instance, "verification_failed")

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
	assert_not_null(_instance.get_node("VBoxContainer/VerificationMessage"))
	assert_not_null(_instance.get_node("VBoxContainer/ButtonContainer"))

func test_panel_properties() -> void:
	assert_eq(_instance.verification_message, "")
	assert_false(_instance.is_valid)

func test_verification_message() -> void:
	_instance.set_verification_message("Test message")
	assert_eq(_instance.verification_message, "Test message")
	
	var message_label = _instance.get_node("VBoxContainer/VerificationMessage")
	assert_eq(message_label.text, "Test message")

func test_verification_state() -> void:
	_instance.set_verification_state(true)
	assert_true(_instance.is_valid)
	
	_instance.set_verification_state(false)
	assert_false(_instance.is_valid)
	verify_signal_emitted(_instance, "verification_failed")