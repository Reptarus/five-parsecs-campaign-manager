@tool
extends "res://tests/fixtures/base/game_test.gd"

const TestedClass = preload("res://src/ui/components/combat/rules/house_rules_controller.gd")

var _instance: Node
var _rule_added_signal_emitted := false
var _rule_modified_signal_emitted := false
var _rule_removed_signal_emitted := false
var _rule_applied_signal_emitted := false
var _validation_requested_signal_emitted := false
var _last_rule_id: String
var _last_rule_data: Dictionary
var _last_context: String

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
	if _instance.has_signal("rule_added"):
		_instance.rule_added.connect(_on_rule_added)
	if _instance.has_signal("rule_modified"):
		_instance.rule_modified.connect(_on_rule_modified)
	if _instance.has_signal("rule_removed"):
		_instance.rule_removed.connect(_on_rule_removed)
	if _instance.has_signal("rule_applied"):
		_instance.rule_applied.connect(_on_rule_applied)
	if _instance.has_signal("validation_requested"):
		_instance.validation_requested.connect(_on_validation_requested)

func _disconnect_signals() -> void:
	if _instance and not _instance.is_queued_for_deletion():
		if _instance.has_signal("rule_added") and _instance.rule_added.is_connected(_on_rule_added):
			_instance.rule_added.disconnect(_on_rule_added)
		if _instance.has_signal("rule_modified") and _instance.rule_modified.is_connected(_on_rule_modified):
			_instance.rule_modified.disconnect(_on_rule_modified)
		if _instance.has_signal("rule_removed") and _instance.rule_removed.is_connected(_on_rule_removed):
			_instance.rule_removed.disconnect(_on_rule_removed)
		if _instance.has_signal("rule_applied") and _instance.rule_applied.is_connected(_on_rule_applied):
			_instance.rule_applied.disconnect(_on_rule_applied)
		if _instance.has_signal("validation_requested") and _instance.validation_requested.is_connected(_on_validation_requested):
			_instance.validation_requested.disconnect(_on_validation_requested)

func _reset_signals() -> void:
	_rule_added_signal_emitted = false
	_rule_modified_signal_emitted = false
	_rule_removed_signal_emitted = false
	_rule_applied_signal_emitted = false
	_validation_requested_signal_emitted = false
	_last_rule_id = ""
	_last_rule_data = {}
	_last_context = ""

func _on_rule_added(rule_id: String, rule_data: Dictionary) -> void:
	_rule_added_signal_emitted = true
	_last_rule_id = rule_id
	_last_rule_data = rule_data

func _on_rule_modified(rule_id: String, rule_data: Dictionary) -> void:
	_rule_modified_signal_emitted = true
	_last_rule_id = rule_id
	_last_rule_data = rule_data

func _on_rule_removed(rule_id: String) -> void:
	_rule_removed_signal_emitted = true
	_last_rule_id = rule_id

func _on_rule_applied(rule_id: String, context: String) -> void:
	_rule_applied_signal_emitted = true
	_last_rule_id = rule_id
	_last_context = context

func _on_validation_requested(rule: Dictionary, context: String) -> void:
	_validation_requested_signal_emitted = true
	_last_rule_data = rule
	_last_context = context

func test_initial_state() -> void:
	assert_false(_rule_added_signal_emitted)
	assert_false(_rule_modified_signal_emitted)
	assert_false(_rule_removed_signal_emitted)
	assert_false(_rule_applied_signal_emitted)
	assert_false(_validation_requested_signal_emitted)
	assert_true(_instance.active_rules.is_empty())

func test_add_rule() -> void:
	var test_rule = {
		"name": "Test Rule",
		"type": "combat",
		"effect": "test_effect",
		"parameters": {}
	}
	
	_instance._add_rule("test_rule", test_rule)
	
	verify_signal_emitted(_instance, "rule_added")
	assert_true(_rule_added_signal_emitted)
	assert_eq(_last_rule_id, "test_rule")
	assert_eq(_last_rule_data, test_rule)
	assert_false(_instance.active_rules.is_empty())

func test_modify_rule() -> void:
	var initial_rule = {
		"name": "Test Rule",
		"type": "combat",
		"effect": "test_effect",
		"parameters": {}
	}
	var modified_rule = {
		"name": "Modified Rule",
		"type": "combat",
		"effect": "modified_effect",
		"parameters": {"test": "value"}
	}
	
	_instance._add_rule("test_rule", initial_rule)
	_reset_signals()
	
	_instance._add_rule("test_rule", modified_rule)
	
	verify_signal_emitted(_instance, "rule_modified")
	assert_true(_rule_modified_signal_emitted)
	assert_eq(_last_rule_id, "test_rule")
	assert_eq(_last_rule_data, modified_rule)

func test_remove_rule() -> void:
	var test_rule = {
		"name": "Test Rule",
		"type": "combat",
		"effect": "test_effect",
		"parameters": {}
	}
	
	_instance._add_rule("test_rule", test_rule)
	_reset_signals()
	
	_instance._add_rule("test_rule", null)
	
	verify_signal_emitted(_instance, "rule_removed")
	assert_true(_rule_removed_signal_emitted)
	assert_eq(_last_rule_id, "test_rule")
	assert_true(_instance.active_rules.is_empty())

func test_apply_rule() -> void:
	var test_rule = {
		"name": "Test Rule",
		"type": "combat",
		"effect": "test_effect",
		"parameters": {}
	}
	
	_instance._add_rule("test_rule", test_rule)
	_reset_signals()
	
	_instance._apply_rule_effect("test_rule", "combat_state")
	
	verify_signal_emitted(_instance, "rule_applied")
	assert_true(_rule_applied_signal_emitted)
	assert_eq(_last_rule_id, "test_rule")
	assert_eq(_last_context, "combat_state")

func test_validate_rule() -> void:
	var test_rule = {
		"name": "Test Rule",
		"type": "combat",
		"effect": "test_effect",
		"parameters": {}
	}
	
	_instance._validate_rule(test_rule, "combat_state")
	
	verify_signal_emitted(_instance, "validation_requested")
	assert_true(_validation_requested_signal_emitted)
	assert_eq(_last_rule_data, test_rule)
	assert_eq(_last_context, "combat_state")