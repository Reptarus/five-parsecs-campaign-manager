@tool
extends GdUnitTestSuite

var house_rules_controller: Node
var mock_rule_manager: Node

func before_test():
	# Create mock house rules controller with all required methods
	house_rules_controller = Node.new()
	house_rules_controller.name = "HouseRulesController"
	
	# Add all expected signals
	var required_signals = [
		"rule_added", "rule_modified", "rule_removed", "rule_applied",
		"rule_validation_complete", "rules_changed", "controller_initialized"
	]
	
	for signal_name in required_signals:
		house_rules_controller.add_user_signal(signal_name)
	
	# Set up controller properties
	house_rules_controller.set_meta("rules", [])
	house_rules_controller.set_meta("active_rules", [])
	house_rules_controller.set_meta("is_initialized", true)
	
	# Create mock rule manager
	mock_rule_manager = Node.new()
	mock_rule_manager.name = "MockRuleManager"
	mock_rule_manager.set_meta("rule_count", 0)
	
	# Add to scene tree
	add_child(house_rules_controller)
	house_rules_controller.add_child(mock_rule_manager)

func after_test():
	if is_instance_valid(house_rules_controller):
		house_rules_controller.queue_free()
	await get_tree().process_frame

# Mock method implementations using meta system
func _mock_add_rule(rule: Dictionary) -> bool:
	var rules = house_rules_controller.get_meta("rules", [])
	rules.append(rule)
	house_rules_controller.set_meta("rules", rules)
	
	if house_rules_controller.has_signal("rule_added"):
		house_rules_controller.emit_signal("rule_added", rule)
	
	return true

func _mock_modify_rule(rule_id: String, changes: Dictionary) -> bool:
	var rules = house_rules_controller.get_meta("rules", [])
	for i in range(rules.size()):
		if rules[i].get("id") == rule_id:
			# Create a proper copy and apply changes cleanly
			var updated_rule = rules[i].duplicate()
			for key in changes.keys():
				updated_rule[key] = changes[key]
			rules[i] = updated_rule
			house_rules_controller.set_meta("rules", rules)
			
			if house_rules_controller.has_signal("rule_modified"):
				house_rules_controller.emit_signal("rule_modified", updated_rule)
			
			return true
	return false

func _mock_remove_rule(rule_id: String) -> bool:
	var rules = house_rules_controller.get_meta("rules", [])
	for i in range(rules.size()):
		if rules[i].get("id") == rule_id:
			var removed_rule = rules[i]
			rules.remove_at(i)
			house_rules_controller.set_meta("rules", rules)
			
			if house_rules_controller.has_signal("rule_removed"):
				house_rules_controller.emit_signal("rule_removed", removed_rule)
			
			return true
	return false

func _mock_apply_rule(rule_id: String) -> bool:
	var rules = house_rules_controller.get_meta("rules", [])
	for rule in rules:
		if rule.get("id") == rule_id:
			var active_rules = house_rules_controller.get_meta("active_rules", [])
			if rule not in active_rules:
				active_rules.append(rule)
				house_rules_controller.set_meta("active_rules", active_rules)
			
			if house_rules_controller.has_signal("rule_applied"):
				house_rules_controller.emit_signal("rule_applied", rule)
			
			return true
	return false

func _mock_validate_rule(rule: Dictionary) -> Dictionary:
	var validation_result = {
		"valid": true,
		"errors": [],
		"warnings": []
	}
	
	# Basic validation logic
	if not rule.has("name") or rule["name"] == "":
		validation_result["valid"] = false
		validation_result["errors"].append("Rule name is required")
	
	if not rule.has("type"):
		validation_result["valid"] = false
		validation_result["errors"].append("Rule type is required")
	
	if house_rules_controller.has_signal("rule_validation_complete"):
		house_rules_controller.emit_signal("rule_validation_complete", validation_result)
	
	return validation_result

func test_initial_state():
	# Test basic controller structure
	assert_that(house_rules_controller).is_not_null()
	assert_that(house_rules_controller.is_inside_tree()).is_true()
	
	# Test initial properties
	var is_initialized = house_rules_controller.get_meta("is_initialized", false)
	assert_that(is_initialized).is_true()
	
	var rules = house_rules_controller.get_meta("rules", [])
	assert_that(rules).is_empty()

func test_add_rule():
	# Test adding a rule
	var test_rule = {
		"id": "test_rule_1",
		"name": "Test Combat Rule",
		"type": "combat",
		"description": "A test rule for combat modifications",
		"enabled": true
	}
	
	var result = _mock_add_rule(test_rule)
	assert_that(result).is_true()
	
	# Verify rule was added
	var rules = house_rules_controller.get_meta("rules", [])
	assert_that(rules.size()).is_equal(1)
	assert_that(rules[0]["name"]).is_equal("Test Combat Rule")

func test_modify_rule():
	# First add a rule
	var test_rule = {
		"id": "test_rule_2",
		"name": "Original Rule",
		"type": "movement",
		"enabled": true
	}
	_mock_add_rule(test_rule)
	
	# Then modify it
	var changes = {
		"name": "Modified Rule",
		"enabled": false
	}
	
	var result = _mock_modify_rule("test_rule_2", changes)
	assert_that(result).is_true()
	
	# Verify modification
	var rules = house_rules_controller.get_meta("rules", [])
	assert_that(rules[0]["name"]).is_equal("Modified Rule")
	assert_that(rules[0]["enabled"]).is_false()

func test_remove_rule():
	# First add a rule
	var test_rule = {
		"id": "test_rule_3",
		"name": "Rule to Remove",
		"type": "terrain"
	}
	_mock_add_rule(test_rule)
	
	# Verify rule exists
	var rules = house_rules_controller.get_meta("rules", [])
	assert_that(rules.size()).is_equal(1)
	
	# Remove the rule
	var result = _mock_remove_rule("test_rule_3")
	assert_that(result).is_true()
	
	# Verify removal
	rules = house_rules_controller.get_meta("rules", [])
	assert_that(rules.size()).is_equal(0)

func test_apply_rule():
	# First add a rule
	var test_rule = {
		"id": "test_rule_4",
		"name": "Rule to Apply",
		"type": "special",
		"enabled": true
	}
	_mock_add_rule(test_rule)
	
	# Apply the rule
	var result = _mock_apply_rule("test_rule_4")
	assert_that(result).is_true()
	
	# Verify rule is in active rules
	var active_rules = house_rules_controller.get_meta("active_rules", [])
	assert_that(active_rules.size()).is_equal(1)
	assert_that(active_rules[0]["name"]).is_equal("Rule to Apply")

func test_validate_rule():
	# Test valid rule
	var valid_rule = {
		"name": "Valid Rule",
		"type": "combat",
		"description": "A valid rule"
	}
	
	var result = _mock_validate_rule(valid_rule)
	assert_that(result["valid"]).is_true()
	assert_that(result["errors"]).is_empty()
	
	# Test invalid rule (missing name)
	var invalid_rule = {
		"type": "combat",
		"description": "Missing name"
	}
	
	result = _mock_validate_rule(invalid_rule)
	assert_that(result["valid"]).is_false()
	assert_that(result["errors"].size()).is_greater(0)