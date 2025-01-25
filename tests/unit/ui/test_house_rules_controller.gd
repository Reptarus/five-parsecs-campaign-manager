@tool
extends "res://tests/fixtures/base_test.gd"

const HouseRulesController := preload("res://src/ui/components/combat/rules/house_rules_controller.gd")


var controller: HouseRulesController

func before_each() -> void:
	await super.before_each()
	controller = HouseRulesController.new()
	add_child(controller)
	track_test_node(controller)
	watch_signals(controller)
	await get_tree().process_frame

func after_each() -> void:
	await super.after_each()
	controller = null

# Basic State Tests
func test_initial_state() -> void:
	assert_false(controller.house_rules_panel.visible, "Panel should start hidden")
	assert_eq(controller.active_rules.size(), 0, "Should start with no active rules")
	assert_eq(controller.get_edit_mode(), GameEnums.EditMode.NONE, "Should start in NONE edit mode")

# Rule Management Tests
func test_add_valid_rule() -> void:
	var test_rule = {
		"id": "test_rule",
		"name": "Test Rule",
		"description": "A test rule",
		"enabled": true,
		"type": GameEnums.VerificationType.COMBAT,
		"priority": 1
	}
	
	controller.add_rule(test_rule)
	assert_eq(controller.active_rules.size(), 1, "Should have one active rule")
	assert_signal_emitted(controller, "rule_added")
	assert_eq(controller.active_rules[0].type, GameEnums.VerificationType.COMBAT, "Should preserve rule type")

func test_add_invalid_rule() -> void:
	var invalid_rules = [
		{
			"id": "",
			"name": "",
			"description": "",
			"enabled": true,
			"type": GameEnums.VerificationType.NONE
		},
		{
			"id": "test",
			"name": "Test",
			"description": "Description",
			"enabled": true,
			"type": - 1
		}
	]
	
	for rule in invalid_rules:
		controller.add_rule(rule)
		assert_eq(controller.active_rules.size(), 0, "Should not add invalid rule")
		assert_signal_not_emitted(controller, "rule_added")

func test_remove_rule() -> void:
	var test_rule = {
		"id": "test_rule",
		"name": "Test Rule",
		"description": "A test rule",
		"enabled": true,
		"type": GameEnums.VerificationType.MOVEMENT
	}
	
	controller.add_rule(test_rule)
	controller.remove_rule("test_rule")
	assert_eq(controller.active_rules.size(), 0, "Should have no active rules")
	assert_signal_emitted(controller, "rule_removed")

func test_toggle_rule() -> void:
	var test_rule = {
		"id": "test_rule",
		"enabled": true,
		"type": GameEnums.VerificationType.COMBAT
	}
	controller.add_rule(test_rule)
	
	controller.toggle_rule("test_rule")
	assert_false(controller.active_rules[0].enabled, "Should disable rule")
	assert_signal_emitted(controller, "rule_toggled")
	
	controller.toggle_rule("test_rule")
	assert_true(controller.active_rules[0].enabled, "Should enable rule")
	assert_signal_emitted(controller, "rule_toggled")

# Rule Priority Tests
func test_rule_priority_ordering() -> void:
	var rules = [
		{
			"id": "rule1",
			"name": "Rule 1",
			"type": GameEnums.VerificationType.COMBAT,
			"priority": 2,
			"enabled": true
		},
		{
			"id": "rule2",
			"name": "Rule 2",
			"type": GameEnums.VerificationType.MOVEMENT,
			"priority": 1,
			"enabled": true
		}
	]
	
	for rule in rules:
		controller.add_rule(rule)
	
	assert_eq(controller.active_rules[0].priority, 1, "Rules should be ordered by priority")
	assert_eq(controller.active_rules[1].priority, 2, "Rules should be ordered by priority")

# Rule Type Tests
func test_rule_type_filtering() -> void:
	var combat_rule = {
		"id": "combat_rule",
		"type": GameEnums.VerificationType.COMBAT,
		"enabled": true
	}
	
	var movement_rule = {
		"id": "movement_rule",
		"type": GameEnums.VerificationType.MOVEMENT,
		"enabled": true
	}
	
	controller.add_rule(combat_rule)
	controller.add_rule(movement_rule)
	
	var combat_rules = controller.get_rules_by_type(GameEnums.VerificationType.COMBAT)
	assert_eq(combat_rules.size(), 1, "Should filter combat rules")
	assert_eq(combat_rules[0].id, "combat_rule", "Should return correct rule")

# Panel Interaction Tests
func test_panel_visibility() -> void:
	controller.show_panel()
	assert_true(controller.house_rules_panel.visible, "Panel should be visible")
	assert_signal_emitted(controller, "panel_visibility_changed")
	
	controller.hide_panel()
	assert_false(controller.house_rules_panel.visible, "Panel should be hidden")
	assert_signal_emitted(controller, "panel_visibility_changed")

func test_panel_edit_mode() -> void:
	var test_rule = {
		"id": "test_rule",
		"type": GameEnums.VerificationType.COMBAT
	}
	
	controller.add_rule(test_rule)
	controller.edit_rule("test_rule")
	assert_eq(controller.get_edit_mode(), GameEnums.EditMode.EDIT, "Should enter edit mode")
	
	controller.cancel_edit()
	assert_eq(controller.get_edit_mode(), GameEnums.EditMode.NONE, "Should exit edit mode")

# Error Condition Tests
func test_error_conditions() -> void:
	# Test removing non-existent rule
	controller.remove_rule("non_existent")
	assert_signal_not_emitted(controller, "rule_removed")
	
	# Test toggling non-existent rule
	controller.toggle_rule("non_existent")
	assert_signal_not_emitted(controller, "rule_toggled")
	
	# Test editing non-existent rule
	controller.edit_rule("non_existent")
	assert_eq(controller.get_edit_mode(), GameEnums.EditMode.NONE, "Should not enter edit mode for non-existent rule")

# Boundary Tests
func test_rule_limit() -> void:
	for i in range(100):
		var rule = {
			"id": "rule_%d" % i,
			"type": GameEnums.VerificationType.COMBAT,
			"enabled": true
		}
		controller.add_rule(rule)
	
	assert_true(controller.active_rules.size() <= 100, "Should not exceed reasonable rule limit")

func test_rapid_operations() -> void:
	var test_rule = {
		"id": "test_rule",
		"type": GameEnums.VerificationType.COMBAT,
		"enabled": true
	}
	
	# Rapid add/remove
	for i in range(10):
		controller.add_rule(test_rule)
		controller.remove_rule("test_rule")
	
	assert_eq(controller.active_rules.size(), 0, "Should handle rapid operations correctly")