@tool
extends "res://tests/fixtures/game_test.gd"

const HouseRulesPanel := preload("res://src/ui/components/combat/rules/house_rules_panel.gd")

# Test variables
var panel: Node # Using Node type to avoid casting issues

# Lifecycle Methods
func before_each() -> void:
	await super.before_each()
	panel = HouseRulesPanel.new()
	add_child(panel)
	track_test_node(panel)
	await get_tree().process_frame

func after_each() -> void:
	await super.after_each()
	panel = null

# Test Methods
func test_initial_state() -> void:
	assert_false(panel.visible, "Panel should start hidden")
	assert_eq(panel.rules_container.get_child_count(), 0, "Should start with no rules")

func test_add_rule_ui() -> void:
	watch_signals(panel)
	
	var test_rule = {
		"id": "test_rule",
		"name": "Test Rule",
		"description": "A test rule",
		"enabled": true
	}
	
	panel.add_rule_ui(test_rule)
	assert_eq(panel.rules_container.get_child_count(), 1, "Should add rule UI")
	assert_signal_emitted(panel, "rule_ui_added")

func test_remove_rule_ui() -> void:
	watch_signals(panel)
	
	var test_rule = {
		"id": "test_rule",
		"enabled": true
	}
	panel.add_rule_ui(test_rule)
	
	panel.remove_rule_ui("test_rule")
	assert_eq(panel.rules_container.get_child_count(), 0, "Should remove rule UI")
	assert_signal_emitted(panel, "rule_ui_removed")

func test_toggle_rule_ui() -> void:
	watch_signals(panel)
	
	var test_rule = {
		"id": "test_rule",
		"enabled": true
	}
	panel.add_rule_ui(test_rule)
	
	panel.toggle_rule_ui("test_rule")
	var rule_ui = panel.rules_container.get_child(0)
	assert_false(rule_ui.enabled, "Should disable rule UI")
	assert_signal_emitted(panel, "rule_ui_toggled")
	
	panel.toggle_rule_ui("test_rule")
	assert_true(rule_ui.enabled, "Should enable rule UI")
	assert_signal_emitted(panel, "rule_ui_toggled")