extends "res://addons/gut/test.gd"

var HouseRulesPanel = preload("res://src/ui/components/combat/rules/house_rules_panel.tscn")
var panel: Node

func before_each() -> void:
	panel = HouseRulesPanel.instantiate()
	add_child_autofree(panel)
	await get_tree().process_frame

func test_initial_state() -> void:
	assert_eq(panel.active_rules.size(), 0, "Rules list should start empty")
	assert_true(panel.remove_rule_button.disabled, "Remove button should start disabled")
	assert_true(panel.edit_rule_button.disabled, "Edit button should start disabled")

func test_add_rule() -> void:
	watch_signals(panel)
	var test_rule = {
		"name": "Test Rule",
		"category": "combat",
		"description": "Test description",
		"effects": [
			{
				"type": 0,
				"value": 2,
				"description": "Test effect"
			}
		]
	}
	
	panel.add_rule(test_rule)
	
	assert_eq(panel.active_rules.size(), 1, "Should have one rule")
	assert_signal_emitted(panel, "rule_added")
	var added_rule = get_signal_parameters(panel, "rule_added")[0]
	assert_eq(added_rule.name, "Test Rule", "Added rule should have correct name")

func test_remove_rule() -> void:
	watch_signals(panel)
	var test_rule = {
		"id": "test_id",
		"name": "Test Rule",
		"category": "combat",
		"description": "Test description",
		"effects": []
	}
	
	panel.add_rule(test_rule)
	panel.remove_rule("test_id")
	
	assert_eq(panel.active_rules.size(), 0, "Rules list should be empty")
	assert_signal_emitted(panel, "rule_removed")
	var removed_id = get_signal_parameters(panel, "rule_removed")[0]
	assert_eq(removed_id, "test_id", "Correct rule should be removed")

func test_modify_rule() -> void:
	watch_signals(panel)
	var test_rule = {
		"id": "test_id",
		"name": "Test Rule",
		"category": "combat",
		"description": "Test description",
		"effects": []
	}
	
	panel.add_rule(test_rule)
	
	var modified_rule = test_rule.duplicate()
	modified_rule.name = "Modified Rule"
	panel.modify_rule("test_id", modified_rule)
	
	assert_signal_emitted(panel, "rule_modified")
	var rule = panel.active_rules["test_id"]
	assert_eq(rule.name, "Modified Rule", "Rule should be modified")

func test_filter_rules() -> void:
	var combat_rule = {
		"name": "Combat Rule",
		"category": "combat",
		"description": "Combat description",
		"effects": []
	}
	
	var movement_rule = {
		"name": "Movement Rule",
		"category": "movement",
		"description": "Movement description",
		"effects": []
	}
	
	panel.add_rule(combat_rule)
	panel.add_rule(movement_rule)
	
	panel.category_filter.select(panel.category_filter.get_item_index(1)) # Select combat
	panel._on_category_filter_changed(1)
	
	assert_eq(panel.rules_list.item_count, 1, "Should only show combat rules")

func test_clear_rules() -> void:
	watch_signals(panel)
	var test_rule = {
		"name": "Test Rule",
		"category": "combat",
		"description": "Test description",
		"effects": []
	}
	
	panel.add_rule(test_rule)
	panel.clear_rules()
	
	assert_eq(panel.active_rules.size(), 0, "Rules should be cleared")
	assert_signal_emitted(panel, "rules_cleared")

func test_export_import_rules() -> void:
	var test_rule = {
		"id": "test_id",
		"name": "Test Rule",
		"category": "combat",
		"description": "Test description",
		"effects": []
	}
	
	panel.add_rule(test_rule)
	var exported = panel.export_rules()
	
	panel.clear_rules()
	panel.import_rules(exported)
	
	assert_eq(panel.active_rules.size(), 1, "Rules should be imported")
	assert_eq(panel.active_rules["test_id"].name, "Test Rule", "Imported rule should match")