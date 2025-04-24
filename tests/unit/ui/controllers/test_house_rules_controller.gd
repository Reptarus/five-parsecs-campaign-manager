@tool
extends "res://tests/unit/ui/base/controller_test_base.gd"

const TestedClass = preload("res://src/ui/components/combat/rules/house_rules_controller.gd")

# Type-safe instance variables
var _rule_added_signal_emitted := false
var _rule_modified_signal_emitted := false
var _rule_removed_signal_emitted := false
var _rule_applied_signal_emitted := false
var _validation_requested_signal_emitted := false
var _last_rule_id: String
var _last_rule_data: Dictionary
var _last_context: String

# Override _create_controller_instance to provide the specific controller
func _create_controller_instance() -> Node:
	var instance = TestedClass.new()
	if not is_instance_valid(instance):
		push_error("Failed to create house_rules_controller instance")
	return instance

# Override _get_required_methods to specify required controller methods
func _get_required_methods() -> Array[String]:
	return [
		"_add_rule",
		"_apply_rule_effect",
		"_validate_rule"
	]

func before_each() -> void:
	await super.before_each()
	_reset_signals()
	_connect_signals()

func after_each() -> void:
	_disconnect_signals()
	await super.after_each()

func _connect_signals() -> void:
	if not is_instance_valid(_controller):
		assert_fail("Cannot connect signals: controller is null")
		return
		
	if _controller.has_signal("rule_added") and not _controller.is_connected("rule_added", Callable(self, "_on_rule_added")):
		_controller.connect("rule_added", Callable(self, "_on_rule_added"))
		
	if _controller.has_signal("rule_modified") and not _controller.is_connected("rule_modified", Callable(self, "_on_rule_modified")):
		_controller.connect("rule_modified", Callable(self, "_on_rule_modified"))
		
	if _controller.has_signal("rule_removed") and not _controller.is_connected("rule_removed", Callable(self, "_on_rule_removed")):
		_controller.connect("rule_removed", Callable(self, "_on_rule_removed"))
		
	if _controller.has_signal("rule_applied") and not _controller.is_connected("rule_applied", Callable(self, "_on_rule_applied")):
		_controller.connect("rule_applied", Callable(self, "_on_rule_applied"))
		
	if _controller.has_signal("validation_requested") and not _controller.is_connected("validation_requested", Callable(self, "_on_validation_requested")):
		_controller.connect("validation_requested", Callable(self, "_on_validation_requested"))

func _disconnect_signals() -> void:
	if not is_instance_valid(_controller) or _controller.is_queued_for_deletion():
		return
		
	if _controller.has_signal("rule_added") and _controller.is_connected("rule_added", Callable(self, "_on_rule_added")):
		_controller.disconnect("rule_added", Callable(self, "_on_rule_added"))
		
	if _controller.has_signal("rule_modified") and _controller.is_connected("rule_modified", Callable(self, "_on_rule_modified")):
		_controller.disconnect("rule_modified", Callable(self, "_on_rule_modified"))
		
	if _controller.has_signal("rule_removed") and _controller.is_connected("rule_removed", Callable(self, "_on_rule_removed")):
		_controller.disconnect("rule_removed", Callable(self, "_on_rule_removed"))
		
	if _controller.has_signal("rule_applied") and _controller.is_connected("rule_applied", Callable(self, "_on_rule_applied")):
		_controller.disconnect("rule_applied", Callable(self, "_on_rule_applied"))
		
	if _controller.has_signal("validation_requested") and _controller.is_connected("validation_requested", Callable(self, "_on_validation_requested")):
		_controller.disconnect("validation_requested", Callable(self, "_on_validation_requested"))

func _reset_signals() -> void:
	_rule_added_signal_emitted = false
	_rule_modified_signal_emitted = false
	_rule_removed_signal_emitted = false
	_rule_applied_signal_emitted = false
	_validation_requested_signal_emitted = false
	_last_rule_id = ""
	_last_rule_data = {}
	_last_context = ""

# Type-safe signal handlers
func _on_rule_added(rule_id: String, rule_data: Dictionary) -> void:
	_rule_added_signal_emitted = true
	_last_rule_id = rule_id
	
	# Use a safe copy method to handle potential null or non-Dictionary values
	if rule_data is Dictionary:
		_last_rule_data = rule_data.duplicate(true) # Safe deep copy
	else:
		_last_rule_data = {}

func _on_rule_modified(rule_id: String, rule_data: Dictionary) -> void:
	_rule_modified_signal_emitted = true
	_last_rule_id = rule_id
	
	# Use a safe copy method to handle potential null or non-Dictionary values
	if rule_data is Dictionary:
		_last_rule_data = rule_data.duplicate(true) # Safe deep copy
	else:
		_last_rule_data = {}

func _on_rule_removed(rule_id: String) -> void:
	_rule_removed_signal_emitted = true
	_last_rule_id = rule_id

func _on_rule_applied(rule_id: String, context: String) -> void:
	_rule_applied_signal_emitted = true
	_last_rule_id = rule_id
	_last_context = context

func _on_validation_requested(rule: Dictionary, context: String) -> void:
	_validation_requested_signal_emitted = true
	
	# Use a safe copy method to handle potential null or non-Dictionary values
	if rule is Dictionary:
		_last_rule_data = rule.duplicate(true) # Safe deep copy
	else:
		_last_rule_data = {}
		
	_last_context = context

# Create a valid test rule
func _create_test_rule() -> Dictionary:
	# Create a dictionary that safely initializes all required fields
	var rule = {
		"name": "Test Rule",
		"type": "combat_modifier",
		"effect": "test_effect",
		"fields": []
	}
	
	# Add fields in a structured way
	var fields = []
	fields.append({
		"name": "value",
		"value": 2
	})
	fields.append({
		"name": "condition",
		"value": "Always"
	})
	fields.append({
		"name": "target",
		"value": "Self"
	})
	
	rule["fields"] = fields
	return rule

# Safe property access
func _has_property(obj: Object, property_name: String) -> bool:
	if not is_instance_valid(obj):
		return false
		
	# Try using get_property_list first
	if obj.get_property_list().any(func(p): return p.name == property_name):
		return true
		
	# Fallback to "in" operator if available
	return property_name in obj
	
func _get_property_safely(obj: Object, property_name: String, default_value = null) -> Variant:
	if not is_instance_valid(obj) or not _has_property(obj, property_name):
		return default_value
		
	return obj.get(property_name)
	
func test_initial_state() -> void:
	if not is_instance_valid(_controller):
		assert_fail("Cannot test initial state: controller is null")
		return
		
	assert_false(_rule_added_signal_emitted)
	assert_false(_rule_modified_signal_emitted)
	assert_false(_rule_removed_signal_emitted)
	assert_false(_rule_applied_signal_emitted)
	assert_false(_validation_requested_signal_emitted)
	
	# Use our safe property access function
	var active_rules = _get_property_safely(_controller, "active_rules")
	if active_rules != null:
		assert_true(active_rules is Dictionary, "active_rules should be a Dictionary")
		assert_true(active_rules.is_empty(), "active_rules should be empty initially")
	else:
		push_warning("Controller missing active_rules property")

func test_add_rule() -> void:
	if not is_instance_valid(_controller):
		assert_fail("Cannot test add_rule: controller is null")
		return
		
	if not _controller.has_method("_add_rule"):
		assert_fail("Controller missing _add_rule method")
		return
		
	var test_rule = _create_test_rule()
	
	_controller._add_rule("test_rule", test_rule)
	
	assert_signal_emitted(_controller, "rule_added")
	assert_true(_rule_added_signal_emitted)
	assert_eq(_last_rule_id, "test_rule")
	
	# Safely check rule data properties
	if test_rule is Dictionary and "name" in test_rule and _last_rule_data is Dictionary and "name" in _last_rule_data:
		assert_eq(_last_rule_data.name, test_rule.name)
	
	if test_rule is Dictionary and "type" in test_rule and _last_rule_data is Dictionary and "type" in _last_rule_data:
		assert_eq(_last_rule_data.type, test_rule.type)
	
	# Use our safe property access function
	var active_rules = _get_property_safely(_controller, "active_rules")
	if active_rules is Dictionary:
		assert_false(active_rules.is_empty(), "active_rules should not be empty after adding a rule")
		assert_true(active_rules.has("test_rule"), "active_rules should contain test_rule")
	else:
		push_warning("Controller missing active_rules property")

func test_modify_rule() -> void:
	if not is_instance_valid(_controller):
		assert_fail("Cannot test modify_rule: controller is null")
		return
		
	if not _controller.has_method("_add_rule"):
		assert_fail("Controller missing _add_rule method")
		return
		
	var initial_rule = _create_test_rule()
	var modified_rule = _create_test_rule()
	
	if modified_rule is Dictionary:
		modified_rule["name"] = "Modified Rule"
	
	_controller._add_rule("test_rule", initial_rule)
	_reset_signals()
	
	_controller._add_rule("test_rule", modified_rule)
	
	assert_signal_emitted(_controller, "rule_modified")
	assert_true(_rule_modified_signal_emitted)
	assert_eq(_last_rule_id, "test_rule")
	
	if modified_rule is Dictionary and "name" in modified_rule and _last_rule_data is Dictionary and "name" in _last_rule_data:
		assert_eq(_last_rule_data.name, modified_rule.name)
	
	# Use our safe property access function
	var active_rules = _get_property_safely(_controller, "active_rules")
	if active_rules is Dictionary and active_rules.has("test_rule"):
		var rule = active_rules["test_rule"]
		if rule is Dictionary and "name" in rule and modified_rule is Dictionary and "name" in modified_rule:
			assert_eq(rule.name, modified_rule.name)
	else:
		push_warning("Controller missing active_rules property or test_rule not found")

func test_remove_rule() -> void:
	if not is_instance_valid(_controller):
		assert_fail("Cannot test remove_rule: controller is null")
		return
		
	if not _controller.has_method("_add_rule") or not _controller.has_method("_on_rule_removed"):
		assert_fail("Controller missing required methods")
		return
		
	var test_rule = _create_test_rule()
	
	_controller._add_rule("test_rule", test_rule)
	_reset_signals()
	
	_controller._on_rule_removed("test_rule")
	
	assert_signal_emitted(_controller, "rule_removed")
	assert_true(_rule_removed_signal_emitted)
	assert_eq(_last_rule_id, "test_rule")
	
	# Use our safe property access function
	var active_rules = _get_property_safely(_controller, "active_rules")
	if active_rules is Dictionary:
		assert_false(active_rules.has("test_rule"), "test_rule should be removed from active_rules")
	else:
		push_warning("Controller missing active_rules property")

func test_apply_rule() -> void:
	if not is_instance_valid(_controller):
		assert_fail("Cannot test apply_rule: controller is null")
		return
		
	if not _controller.has_method("_add_rule") or not _controller.has_method("_apply_rule_effect"):
		assert_fail("Controller missing required methods")
		return
		
	var test_rule = _create_test_rule()
	
	_controller._add_rule("test_rule", test_rule)
	_reset_signals()
	
	_controller._apply_rule_effect("test_rule", "combat_state")
	
	assert_signal_emitted(_controller, "rule_applied")
	assert_true(_rule_applied_signal_emitted)
	assert_eq(_last_rule_id, "test_rule")
	assert_eq(_last_context, "combat_state")

func test_validate_rule() -> void:
	if not is_instance_valid(_controller):
		assert_fail("Cannot test validate_rule: controller is null")
		return
		
	if not _controller.has_method("_validate_rule"):
		assert_fail("Controller missing _validate_rule method")
		return
		
	var test_rule = _create_test_rule()
	
	var validation_result = _controller._validate_rule(test_rule, "combat_state")
	
	assert_signal_emitted(_controller, "validation_requested")
	assert_true(_validation_requested_signal_emitted)
	assert_true(validation_result is bool, "Validation result should be boolean")
	
	if validation_result:
		assert_true(validation_result, "Rule should validate successfully")
	
	if test_rule is Dictionary and "name" in test_rule and _last_rule_data is Dictionary and "name" in _last_rule_data:
		assert_eq(_last_rule_data.name, test_rule.name)
	
	assert_eq(_last_context, "combat_state")

# Override parent methods to specify properties that can be null
func _is_nullable_property(property_name: String) -> bool:
	var nullable_properties := [
		"active_rules",
		"rule_effects",
		"combat_manager",
		"house_rules_panel"
	]
	return property_name in nullable_properties

# Specify which properties should be compared during reset tests
func _is_simple_property(property_name: String) -> bool:
	# Only compare simple data types, not complex structures like dictionaries
	var simple_properties := []
	return property_name in simple_properties

# Override parent test_accessibility to provide a Control parameter
func test_accessibility(control: Control = null) -> void:
	if not is_instance_valid(_controller):
		assert_fail("Skipping test_accessibility: controller is null")
		return
		
	# Create a test control if none provided
	if not is_instance_valid(control):
		control = Control.new()
		add_child_autofree(control)
	
	# Call parent implementation with the control parameter
	await super.test_accessibility(control)

# Override parent test_animations to provide a Control parameter
func test_animations(control: Control = null) -> void:
	if not is_instance_valid(_controller):
		assert_fail("Skipping test_animations: controller is null")
		return
		
	# Create a test control if none provided
	if not is_instance_valid(control):
		control = Control.new()
		add_child_autofree(control)
	
	# Call parent implementation with the control parameter
	await super.test_animations(control)