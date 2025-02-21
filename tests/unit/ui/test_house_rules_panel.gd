## Test class for house rules panel functionality
##
## Tests the UI components and logic for managing house rules
## including rule addition, removal, and state management
@tool
extends GameTest

const TestedClass: PackedScene = preload("res://src/ui/components/combat/rules/house_rules_panel.tscn")

var _instance: Control
var _rule_updated_signal_emitted := false
var _last_rule_data: Dictionary = {}

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
		
	if _instance.has_signal("rule_updated"):
		_instance.connect("rule_updated", _on_rule_updated)

func _disconnect_signals() -> void:
	if not _instance:
		return
		
	if _instance.has_signal("rule_updated") and _instance.is_connected("rule_updated", _on_rule_updated):
		_instance.disconnect("rule_updated", _on_rule_updated)

func _reset_signals() -> void:
	_rule_updated_signal_emitted = false
	_last_rule_data = {}

func _on_rule_updated(data: Dictionary = {}) -> void:
	_rule_updated_signal_emitted = true
	_last_rule_data = data

# Test Cases
func test_initial_state() -> void:
	assert_not_null(_instance, "House rules panel should be initialized")
	assert_false(_instance.visible, "Panel should be hidden by default")

func test_rule_update() -> void:
	_instance.visible = true
	var test_data := {"name": "Test Rule", "enabled": true}
	_instance.emit_signal("rule_updated", test_data)
	
	assert_true(_rule_updated_signal_emitted, "Rule update signal should be emitted")
	assert_eq(_last_rule_data, test_data, "Rule data should match test data")

func test_visibility() -> void:
	_instance.visible = false
	var test_data := {"name": "Test"}
	_instance.emit_signal("rule_updated", test_data)
	assert_false(_rule_updated_signal_emitted, "Rule signal should not be emitted when hidden")
	
	_instance.visible = true
	_instance.emit_signal("rule_updated", test_data)
	assert_true(_rule_updated_signal_emitted, "Rule signal should be emitted when visible")

func test_child_nodes() -> void:
	var container = _instance.get_node_or_null("Container")
	assert_not_null(container, "Panel should have a Container node")

func test_signals() -> void:
	watch_signals(_instance)
	_instance.emit_signal("rule_updated")
	verify_signal_emitted(_instance, "rule_updated")
	
	_instance.emit_signal("rule_saved")
	verify_signal_emitted(_instance, "rule_saved")

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
	assert_not_null(_instance.get_node("VBoxContainer/RuleList"))
	assert_not_null(_instance.get_node("VBoxContainer/ButtonContainer"))

func test_panel_properties() -> void:
	assert_eq(_instance.rule_count, 0)
	assert_false(_instance.has_unsaved_changes)

func test_rule_list() -> void:
	var test_rules = [
		{"name": "Rule 1", "enabled": true},
		{"name": "Rule 2", "enabled": false}
	]
	
	_instance.set_rules(test_rules)
	assert_eq(_instance.rule_count, 2)
	
	var rule_list = _instance.get_node("VBoxContainer/RuleList")
	assert_eq(rule_list.get_child_count(), 2)

func test_rule_changes() -> void:
	_instance.set_rule_enabled("Rule 1", true)
	assert_true(_instance.has_unsaved_changes)
	
	_instance.save_changes()
	assert_false(_instance.has_unsaved_changes)
	verify_signal_emitted(_instance, "rule_saved")