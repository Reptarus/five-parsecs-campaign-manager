@tool
extends GameTest

const TestedClass: PackedScene = preload("res://src/scenes/campaign/components/ActionButton.tscn")

var _instance: Control
var _clicked_signal_emitted := false
var _last_click_data: Dictionary = {}

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
		
	if _instance.has_signal("clicked"):
		_instance.connect("clicked", _on_button_clicked)

func _disconnect_signals() -> void:
	if not _instance:
		return
		
	if _instance.has_signal("clicked") and _instance.is_connected("clicked", _on_button_clicked):
		_instance.disconnect("clicked", _on_button_clicked)

func _reset_signals() -> void:
	_clicked_signal_emitted = false
	_last_click_data = {}

func _on_button_clicked(data: Dictionary = {}) -> void:
	_clicked_signal_emitted = true
	_last_click_data = data

# Test Cases
func test_initial_state() -> void:
	assert_not_null(_instance, "Button should be initialized")
	assert_false(_instance.disabled, "Button should be enabled by default")
	assert_false(_instance.visible, "Button should be hidden by default")

func test_button_click() -> void:
	_instance.visible = true
	_instance.disabled = false
	
	_instance.emit_signal("pressed")
	assert_true(_clicked_signal_emitted, "Click signal should be emitted")

func test_disabled_state() -> void:
	_instance.disabled = true
	_instance.emit_signal("pressed")
	assert_false(_clicked_signal_emitted, "Click signal should not be emitted when disabled")

func test_visibility() -> void:
	_instance.visible = false
	_instance.emit_signal("pressed")
	assert_false(_clicked_signal_emitted, "Click signal should not be emitted when hidden")
	
	_instance.visible = true
	_instance.emit_signal("pressed")
	assert_true(_clicked_signal_emitted, "Click signal should be emitted when visible")

func test_custom_data() -> void:
	var test_data := {"action": "test", "value": 42}
	_instance.set_meta("click_data", test_data)
	
	_instance.visible = true
	_instance.emit_signal("pressed")
	
	assert_true(_clicked_signal_emitted, "Click signal should be emitted")
	assert_eq(_last_click_data, test_data, "Click data should match set data")

func test_child_nodes() -> void:
	var label = _instance.get_node_or_null("Label")
	assert_not_null(label, "Button should have a Label node")