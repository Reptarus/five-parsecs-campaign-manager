extends "res://addons/gut/test.gd"

var HouseRulesPanel = preload("res://src/ui/components/combat/rules/house_rules_panel.tscn")
var panel: Node

func before_each() -> void:
	panel = HouseRulesPanel.instantiate()
	add_child_autofree(panel)
	await get_tree().process_frame

func test_initial_state() -> void:
	assert_eq(panel.active_rules.size(), 0, "Should start with no rules")
	assert_false(panel.rule_editor.visible, "Rule editor should start hidden")
	assert_false(panel.validation_panel.visible, "Validation panel should start hidden")

func test_add_rule() -> void:
	watch_signals(panel)
	var test_rule = {
		"name": "Test Rule",
		"type": "combat_modifier",
		"description": "Test description",
		"fields": [
			{"name": "value", "value": 2},
			{"name": "condition", "value": 0},
			{"name": "target", "value": 0}
		]
	}
	
	var rule_id = panel.add_rule(test_rule)
	
	assert_true(panel.active_rules.has(rule_id), "Rule should be added to active rules")
	assert_signal_emitted(panel, "rule_added")
	var params = get_signal_parameters(panel, "rule_added")
	assert_eq(params[0], test_rule, "Should emit correct rule data")

func test_modify_rule() -> void:
	watch_signals(panel)
	var test_rule = {
		"name": "Test Rule",
		"type": "combat_modifier",
		"fields": []
	}
	var rule_id = panel.add_rule(test_rule)
	
	var modified_rule = test_rule.duplicate()
	modified_rule.name = "Modified Rule"
	panel.modify_rule(rule_id, modified_rule)
	
	assert_eq(panel.active_rules[rule_id].name, "Modified Rule", "Rule should be modified")
	assert_signal_emitted(panel, "rule_modified")

func test_remove_rule() -> void:
	watch_signals(panel)
	var test_rule = {
		"name": "Test Rule",
		"type": "combat_modifier",
		"fields": []
	}
	var rule_id = panel.add_rule(test_rule)
	
	panel.remove_rule(rule_id)
	
	assert_false(panel.active_rules.has(rule_id), "Rule should be removed")
	assert_signal_emitted(panel, "rule_removed")
	var params = get_signal_parameters(panel, "rule_removed")
	assert_eq(params[0], rule_id, "Should emit correct rule ID")

func test_validate_rule() -> void:
	watch_signals(panel)
	var test_rule = {
		"name": "Test Rule",
		"type": "combat_modifier",
		"fields": [
			{"name": "value", "value": 2}
		]
	}
	
	var result = panel.validate_rule(test_rule, "test_context")
	
	assert_true(result, "Valid rule should pass validation")
	assert_signal_emitted(panel, "validation_requested")

func test_validate_invalid_rule() -> void:
	watch_signals(panel)
	var test_rule = {
		"name": "Invalid Rule",
		"type": "invalid_type",
		"fields": []
	}
	
	var result = panel.validate_rule(test_rule, "test_context")
	
	assert_false(result, "Invalid rule should fail validation")

func test_apply_rule() -> void:
	watch_signals(panel)
	var test_rule = {
		"name": "Test Rule",
		"type": "combat_modifier",
		"fields": [
			{"name": "value", "value": 2}
		]
	}
	var rule_id = panel.add_rule(test_rule)
	
	panel.apply_rule(rule_id, "test_context")
	
	assert_signal_emitted(panel, "rule_applied")
	var params = get_signal_parameters(panel, "rule_applied")
	assert_eq(params[0], rule_id, "Should emit correct rule ID")
	assert_eq(params[1], "test_context", "Should emit correct context")

func test_get_active_rules() -> void:
	var test_rules = [
		{"name": "Rule 1", "type": "combat_modifier", "fields": []},
		{"name": "Rule 2", "type": "resource_modifier", "fields": []},
		{"name": "Rule 3", "type": "state_condition", "fields": []}
	]
	
	for rule in test_rules:
		panel.add_rule(rule)
	
	var active_rules = panel.get_active_rules()
	assert_eq(active_rules.size(), test_rules.size(), "Should return all active rules")

func test_rule_templates() -> void:
	assert_true(panel.rule_templates.has("combat_modifier"), "Should have combat modifier template")
	assert_true(panel.rule_templates.has("resource_modifier"), "Should have resource modifier template")
	assert_true(panel.rule_templates.has("state_condition"), "Should have state condition template")

func test_template_validation() -> void:
	var combat_rule = {
		"type": "combat_modifier",
		"fields": [
			{"name": "value", "value": 2}
		]
	}
	assert_true(panel.validate_rule(combat_rule, "test"), "Valid combat modifier should pass")
	
	combat_rule.fields[0].value = 4
	assert_true(panel.validate_rule(combat_rule, "test"), "Combat modifier within range should pass")
	
	var resource_rule = {
		"type": "resource_modifier",
		"fields": [
			{"name": "value", "value": - 6}
		]
	}
	assert_false(panel.validate_rule(resource_rule, "test"), "Resource modifier out of range should fail")