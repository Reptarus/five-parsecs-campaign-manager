@tool
extends "res://tests/test_base.gd"

const HouseRulesController := preload("res://src/ui/components/combat/rules/house_rules_controller.tscn")
const TestHelper := preload("res://tests/fixtures/test_helper.gd")

var controller: Node

func before_each() -> void:
    super.before_each()
    controller = HouseRulesController.instantiate()
    add_child(controller)

func after_each() -> void:
    super.after_each()
    controller = null

func test_initial_state() -> void:
    assert_eq(controller.active_rules.size(), 0, "Should start with no active rules")
    assert_eq(controller.rule_effects.size(), 0, "Should start with no rule effects")
    assert_false(controller.house_rules_panel.visible, "House rules panel should start hidden")

func test_add_rule() -> void:
    var test_rule = {
        "name": "Test Rule",
        "type": "combat_modifier",
        "fields": [
            {"name": "value", "value": 2},
            {"name": "condition", "value": 0},
            {"name": "target", "value": 0}
        ]
    }
    
    controller._on_rule_added(test_rule)
    
    assert_eq(controller.active_rules.size(), 1, "Should add rule to active rules")
    assert_eq(controller.rule_effects.size(), 1, "Should create rule effect")
    
    var rule_id = controller.active_rules.keys()[0]
    var effect = controller.rule_effects[rule_id]
    assert_eq(effect.value, 2, "Should set correct effect value")
    assert_eq(effect.type, "combat_modifier", "Should set correct effect type")

func test_modify_rule() -> void:
    var test_rule = {
        "name": "Test Rule",
        "type": "combat_modifier",
        "fields": [ {"name": "value", "value": 2}]
    }
    controller._on_rule_added(test_rule)
    var rule_id = controller.active_rules.keys()[0]
    
    var modified_rule = test_rule.duplicate()
    modified_rule.fields[0].value = 3
    controller._on_rule_modified(modified_rule)
    
    var effect = controller.rule_effects[rule_id]
    assert_eq(effect.value, 3, "Should update effect value")

func test_remove_rule() -> void:
    var test_rule = {
        "name": "Test Rule",
        "type": "combat_modifier",
        "fields": []
    }
    controller._on_rule_added(test_rule)
    var rule_id = controller.active_rules.keys()[0]
    
    controller._on_rule_removed(rule_id)
    
    assert_eq(controller.active_rules.size(), 0, "Should remove rule from active rules")
    assert_eq(controller.rule_effects.size(), 0, "Should remove rule effect")

func test_validate_combat_modifier() -> void:
    var valid_rule = {
        "type": "combat_modifier",
        "fields": [ {"name": "value", "value": 2}]
    }
    assert_true(controller._validate_rule(valid_rule, "test"), "Valid combat modifier should pass")
    
    var invalid_rule = {
        "type": "combat_modifier",
        "fields": [ {"name": "value", "value": 4}]
    }
    assert_false(controller._validate_rule(invalid_rule, "test"), "Invalid combat modifier should fail")

func test_validate_resource_modifier() -> void:
    var valid_rule = {
        "type": "resource_modifier",
        "fields": [ {"name": "value", "value": - 3}]
    }
    assert_true(controller._validate_rule(valid_rule, "test"), "Valid resource modifier should pass")
    
    var invalid_rule = {
        "type": "resource_modifier",
        "fields": [ {"name": "value", "value": - 6}]
    }
    assert_false(controller._validate_rule(invalid_rule, "test"), "Invalid resource modifier should fail")

func test_apply_combat_modifier() -> void:
    var test_rule = {
        "name": "Test Rule",
        "type": "combat_modifier",
        "fields": [
            {"name": "value", "value": 2},
            {"name": "condition", "value": 0},
            {"name": "target", "value": 0}
        ]
    }
    controller._on_rule_added(test_rule)
    var rule_id = controller.active_rules.keys()[0]
    
    controller._on_rule_applied(rule_id, "test")
    
    var effect = controller.rule_effects[rule_id]
    assert_eq(effect.value, 2, "Should create correct effect value")
    assert_eq(effect.type, "combat_modifier", "Should create correct effect type")

func test_apply_resource_modifier() -> void:
    var test_rule = {
        "name": "Test Rule",
        "type": "resource_modifier",
        "fields": [
            {"name": "value", "value": - 2},
            {"name": "condition", "value": 0},
            {"name": "target", "value": 0}
        ]
    }
    controller._on_rule_added(test_rule)
    var rule_id = controller.active_rules.keys()[0]
    
    controller._on_rule_applied(rule_id, "test")
    
    var effect = controller.rule_effects[rule_id]
    assert_eq(effect.value, -2, "Should create correct effect value")
    assert_eq(effect.type, "resource_modifier", "Should create correct effect type")

func test_apply_state_condition() -> void:
    var test_rule = {
        "name": "Test Rule",
        "type": "state_condition",
        "fields": [
            {"name": "value", "value": 1},
            {"name": "condition", "value": "equals"},
            {"name": "target", "value": "test_state"}
        ]
    }
    controller._on_rule_added(test_rule)
    var rule_id = controller.active_rules.keys()[0]
    
    controller._on_rule_applied(rule_id, "test")
    
    var effect = controller.rule_effects[rule_id]
    assert_eq(effect.value, 1, "Should create correct effect value")
    assert_eq(effect.type, "state_condition", "Should create correct effect type")

func test_combat_state_changed() -> void:
    var test_rule = {
        "name": "Test Rule",
        "type": "combat_modifier",
        "fields": [ {"name": "value", "value": 2}]
    }
    controller._on_rule_added(test_rule)
    
    controller._on_combat_state_changed({})
    
    assert_true(true, "Should handle combat state change without errors")