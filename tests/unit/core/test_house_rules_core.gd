## House Rules Core Test Suite
## Tests the functionality of the house rules system including:
## - Rule definitions and validation
## - Rule state management
## - Rule effects and interactions
@tool
extends "res://tests/fixtures/base/game_test.gd"
# Use explicit preloads instead of global class names

# Type-safe script references
const HouseRulesController := preload("res://src/ui/components/combat/rules/house_rules_controller.gd")

# Type-safe constants
const TEST_TIMEOUT := 2.0

# Type-safe test data
const TEST_RULES := {
    "BASIC": {
        "name": "Basic Rules",
        "enabled": true,
        "settings": {
            "permadeath": true,
            "story_track": true
        }
    },
    "ADVANCED": {
        "name": "Advanced Rules",
        "enabled": false,
        "settings": {
            "permadeath": false,
            "story_track": false
        }
    }
}

# Type-safe instance variables
var _house_rules: Node = null

# Test Lifecycle Methods
func before_each() -> void:
    await super.before_each()
    
    # Initialize house rules
    var house_rules_instance: Node = HouseRulesController.new()
    _house_rules = TypeSafeMixin._safe_cast_to_node(house_rules_instance)
    if not _house_rules:
        push_error("Failed to create house rules")
        return
    add_child_autofree(_house_rules)
    track_test_node(_house_rules)
    
    watch_signals(_house_rules)
    await stabilize_engine()

func after_each() -> void:
    _house_rules = null
    await super.after_each()

# Rule Management Tests
func test_rule_registration() -> void:
    watch_signals(_house_rules)
    
    var result: bool = TypeSafeMixin._call_node_method_bool(_house_rules, "register_rule", [TEST_RULES.BASIC])
    assert_true(result, "Should register basic rules")
    verify_signal_emitted(_house_rules, "rule_registered")
    
    var rules: Dictionary = TypeSafeMixin._call_node_method_dict(_house_rules, "get_rules", [])
    assert_true(rules.has("Basic Rules"), "Should have basic rules registered")

func test_rule_enabling() -> void:
    watch_signals(_house_rules)
    
    TypeSafeMixin._call_node_method_bool(_house_rules, "register_rule", [TEST_RULES.ADVANCED])
    var result: bool = TypeSafeMixin._call_node_method_bool(_house_rules, "enable_rule", ["Advanced Rules"])
    assert_true(result, "Should enable advanced rules")
    verify_signal_emitted(_house_rules, "rule_state_changed")
    
    var is_enabled: bool = TypeSafeMixin._call_node_method_bool(_house_rules, "is_rule_enabled", ["Advanced Rules"])
    assert_true(is_enabled, "Advanced rules should be enabled")

# Rule Settings Tests
func test_rule_settings() -> void:
    watch_signals(_house_rules)
    
    TypeSafeMixin._call_node_method_bool(_house_rules, "register_rule", [TEST_RULES.BASIC])
    var settings: Dictionary = TypeSafeMixin._call_node_method_dict(_house_rules, "get_rule_settings", ["Basic Rules"])
    
    assert_true(settings.permadeath, "Basic rules should have permadeath enabled")
    assert_true(settings.story_track, "Basic rules should have story track enabled")

# Rule Validation Tests
func test_invalid_rule_handling() -> void:
    watch_signals(_house_rules)
    
    var result: bool = TypeSafeMixin._call_node_method_bool(_house_rules, "register_rule", [null])
    assert_false(result, "Should reject null rule")
    verify_signal_not_emitted(_house_rules, "rule_registered")
    
    result = TypeSafeMixin._call_node_method_bool(_house_rules, "enable_rule", ["NonexistentRule"])
    assert_false(result, "Should reject nonexistent rule")
    verify_signal_not_emitted(_house_rules, "rule_state_changed")

# Performance Tests
func test_rule_performance() -> void:
    watch_signals(_house_rules)
    var start_time := Time.get_ticks_msec()
    
    for i in range(100):
        var rule := TEST_RULES.BASIC.duplicate()
        rule.name = "Rule_%d" % i
        TypeSafeMixin._call_node_method_bool(_house_rules, "register_rule", [rule])
    
    var duration := Time.get_ticks_msec() - start_time
    assert_true(duration < 1000, "Should register 100 rules within 1 second")
    verify_signal_emitted(_house_rules, "rule_registered")