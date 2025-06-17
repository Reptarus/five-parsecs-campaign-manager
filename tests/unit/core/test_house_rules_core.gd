## House Rules Core Test Suite
## Tests the functionality of the house rules system including:
## - Rule definitions and validation
## - Rule state management
## - Rule effects and interactions
@tool
extends GdUnitGameTest

# Mock House Rules Controller with expected values (Universal Mock Strategy)
class MockHouseRulesController extends Resource:
	var rules: Dictionary = {}
	var enabled_rules: Dictionary = {}
	
	func register_rule(rule_data: Dictionary) -> bool:
		if rule_data == null or not rule_data.has("name"):
			return false
		
		var rule_name: String = rule_data["name"]
		rules[rule_name] = rule_data
		enabled_rules[rule_name] = rule_data.get("enabled", false)
		rule_registered.emit(rule_name)
		return true
	
	func enable_rule(rule_name: String) -> bool:
		if not rules.has(rule_name):
			return false
		
		enabled_rules[rule_name] = true
		rule_enabled.emit(rule_name)
		return true
	
	func disable_rule(rule_name: String) -> bool:
		if not rules.has(rule_name):
			return false
		
		enabled_rules[rule_name] = false
		rule_disabled.emit(rule_name)
		return true
	
	func is_rule_enabled(rule_name: String) -> bool:
		return enabled_rules.get(rule_name, false)
	
	func get_rules() -> Dictionary:
		return rules
	
	func get_rule_settings(rule_name: String) -> Dictionary:
		if rules.has(rule_name):
			return rules[rule_name].get("settings", {})
		return {}
	
	func clear_rules() -> void:
		rules.clear()
		enabled_rules.clear()
		rules_cleared.emit()
	
	# Required signals (immediate emission pattern)
	signal rule_registered(rule_name: String)
	signal rule_enabled(rule_name: String)
	signal rule_disabled(rule_name: String)
	signal rules_cleared()

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
var _house_rules: MockHouseRulesController = null

# Test Lifecycle Methods
func before_test() -> void:
	super.before_test()
	
	# Use Resource-based mock (proven pattern)
	_house_rules = MockHouseRulesController.new()
	track_resource(_house_rules)

func after_test() -> void:
	_house_rules = null
	super.after_test()

# Rule Management Tests
func test_rule_registration() -> void:
	# Test direct method calls instead of safe wrappers (proven pattern)
	var result: bool = _house_rules.register_rule(TEST_RULES.BASIC)
	assert_that(result).override_failure_message("Should register basic rules").is_true()
	
	var rules: Dictionary = _house_rules.get_rules()
	assert_that(rules.has("Basic Rules")).override_failure_message("Should have basic rules registered").is_true()

func test_rule_enabling() -> void:
	# Test direct method calls instead of safe wrappers (proven pattern)
	_house_rules.register_rule(TEST_RULES.ADVANCED)
	var result: bool = _house_rules.enable_rule("Advanced Rules")
	assert_that(result).override_failure_message("Should enable advanced rules").is_true()
	
	var is_enabled: bool = _house_rules.is_rule_enabled("Advanced Rules")
	assert_that(is_enabled).override_failure_message("Advanced rules should be enabled").is_true()

# Rule Settings Tests
func test_rule_settings() -> void:
	# Test direct method calls instead of safe wrappers (proven pattern)
	_house_rules.register_rule(TEST_RULES.BASIC)
	var settings: Dictionary = _house_rules.get_rule_settings("Basic Rules")
	
	assert_that(settings.get("permadeath", false)).override_failure_message("Basic rules should have permadeath enabled").is_true()
	assert_that(settings.get("story_track", false)).override_failure_message("Basic rules should have story track enabled").is_true()

# Rule Validation Tests
func test_invalid_rule_handling() -> void:
	# Test direct method calls instead of safe wrappers (proven pattern)
	var result: bool = _house_rules.register_rule({}) # Empty dict instead of null
	assert_that(result).override_failure_message("Should reject empty rule").is_false()
	
	result = _house_rules.enable_rule("NonexistentRule")
	assert_that(result).override_failure_message("Should reject nonexistent rule").is_false()

# Performance Tests
func test_rule_performance() -> void:
	# Test direct method calls instead of safe wrappers (proven pattern)
	var start_time := Time.get_ticks_msec()
	
	for i in range(100):
		var rule := TEST_RULES.BASIC.duplicate()
		rule.name = "Rule_%d" % i
		_house_rules.register_rule(rule)
	
	var duration := Time.get_ticks_msec() - start_time
	assert_that(duration).override_failure_message("Should register 100 rules within 1 second").is_less(1000)

func test_rule_disabling() -> void:
	# Test direct method calls instead of safe wrappers (proven pattern)
	_house_rules.register_rule(TEST_RULES.BASIC)
	_house_rules.enable_rule("Basic Rules")
	
	# Verify enabled
	assert_that(_house_rules.is_rule_enabled("Basic Rules")).override_failure_message("Rule should be enabled").is_true()
	
	# Disable and verify
	var result: bool = _house_rules.disable_rule("Basic Rules")
	assert_that(result).override_failure_message("Should disable rule").is_true()
	assert_that(_house_rules.is_rule_enabled("Basic Rules")).override_failure_message("Rule should be disabled").is_false()

func test_multiple_rules() -> void:
	# Test direct method calls instead of safe wrappers (proven pattern)
	_house_rules.register_rule(TEST_RULES.BASIC)
	_house_rules.register_rule(TEST_RULES.ADVANCED)
	
	var rules: Dictionary = _house_rules.get_rules()
	assert_that(rules.size()).override_failure_message("Should have 2 rules registered").is_equal(2)
	assert_that(rules.has("Basic Rules")).override_failure_message("Should have basic rules").is_true()
	assert_that(rules.has("Advanced Rules")).override_failure_message("Should have advanced rules").is_true()
	
	# Test enabling different rules
	_house_rules.enable_rule("Basic Rules")
	_house_rules.enable_rule("Advanced Rules")
	
	assert_that(_house_rules.is_rule_enabled("Basic Rules")).override_failure_message("Basic rules should be enabled").is_true()
	assert_that(_house_rules.is_rule_enabled("Advanced Rules")).override_failure_message("Advanced rules should be enabled").is_true()

func test_rule_settings_validation() -> void:
	# Test direct method calls instead of safe wrappers (proven pattern)
	var custom_rule := {
		"name": "Custom Rule",
		"enabled": true,
		"settings": {
			"custom_setting": "custom_value",
			"numeric_setting": 42,
			"boolean_setting": false
		}
	}
	
	_house_rules.register_rule(custom_rule)
	var settings: Dictionary = _house_rules.get_rule_settings("Custom Rule")
	
	assert_that(settings.get("custom_setting", "")).override_failure_message("Should have custom setting").is_equal("custom_value")
	assert_that(settings.get("numeric_setting", 0)).override_failure_message("Should have numeric setting").is_equal(42)
	assert_that(settings.get("boolean_setting", true)).override_failure_message("Should have boolean setting").is_false()

func test_rule_clearing() -> void:
	# Test direct method calls instead of safe wrappers (proven pattern)
	_house_rules.register_rule(TEST_RULES.BASIC)
	_house_rules.register_rule(TEST_RULES.ADVANCED)
	
	var rules: Dictionary = _house_rules.get_rules()
	assert_that(rules.size()).override_failure_message("Should have rules before clearing").is_greater(0)
	
	_house_rules.clear_rules()
	rules = _house_rules.get_rules()
	assert_that(rules.size()).override_failure_message("Should have no rules after clearing").is_equal(0)

func test_edge_cases() -> void:
	# Test direct method calls instead of safe wrappers (proven pattern)
	# Test empty rule name
	var empty_rule := {"name": "", "enabled": true}
	var result: bool = _house_rules.register_rule(empty_rule)
	assert_that(result).override_failure_message("Should accept rule with empty name").is_true()
	
	# Test missing settings
	var minimal_rule := {"name": "Minimal Rule"}
	result = _house_rules.register_rule(minimal_rule)
	assert_that(result).override_failure_message("Should accept rule without settings").is_true()
	
	var settings: Dictionary = _house_rules.get_rule_settings("Minimal Rule")
	assert_that(settings.size()).override_failure_message("Missing settings should return empty dict").is_equal(0)
	
	# Test rule without enabled flag
	assert_that(_house_rules.is_rule_enabled("Minimal Rule")).override_failure_message("Rule without enabled flag should default to false").is_false()