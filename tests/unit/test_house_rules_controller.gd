@tool
extends "res://tests/fixtures/game_test.gd"

const HouseRulesController := preload("res://src/ui/components/combat/rules/house_rules_controller.gd")

# Test variables
var controller: Node # Using Node type to avoid casting issues

# Lifecycle Methods
func before_each() -> void:
	await super.before_each()
	controller = HouseRulesController.new()
	add_child(controller)
	track_test_node(controller)
	await get_tree().process_frame

func after_each() -> void:
	await super.after_each()
	controller = null

# Test Methods
func test_initial_state() -> void:
	assert_false(controller.house_rules_panel.visible, "Panel should start hidden")
	assert_eq(controller.active_rules.size(), 0, "Should start with no active rules")

func test_add_rule() -> void:
	watch_signals(controller)
	
	var test_rule = {
		"id": "test_rule",
		"name": "Test Rule",
		"description": "A test rule",
		"enabled": true
	}
	
	controller.add_rule(test_rule)
	assert_eq(controller.active_rules.size(), 1, "Should add rule")
	assert_eq(controller.active_rules[0].id, "test_rule", "Should set rule ID")
	assert_signal_emitted(controller, "rule_added")

func test_remove_rule() -> void:
	watch_signals(controller)
	
	var test_rule = {
		"id": "test_rule",
		"enabled": true
	}
	controller.add_rule(test_rule)
	
	controller.remove_rule("test_rule")
	assert_eq(controller.active_rules.size(), 0, "Should remove rule")
	assert_signal_emitted(controller, "rule_removed")

func test_toggle_rule() -> void:
	watch_signals(controller)
	
	var test_rule = {
		"id": "test_rule",
		"enabled": true
	}
	controller.add_rule(test_rule)
	
	controller.toggle_rule("test_rule")
	assert_false(controller.active_rules[0].enabled, "Should disable rule")
	assert_signal_emitted(controller, "rule_toggled")
	
	controller.toggle_rule("test_rule")
	assert_true(controller.active_rules[0].enabled, "Should enable rule")
	assert_signal_emitted(controller, "rule_toggled")

func test_toggle_panel() -> void:
	watch_signals(controller)
	
	controller.show_panel()
	assert_true(controller.house_rules_panel.visible, "Panel should be visible")
	assert_signal_emitted(controller, "panel_visibility_changed")
	
	controller.hide_panel()
	assert_false(controller.house_rules_panel.visible, "Panel should be hidden")
	assert_signal_emitted(controller, "panel_visibility_changed")