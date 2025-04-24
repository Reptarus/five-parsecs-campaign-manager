@tool
extends "res://tests/unit/ui/base/controller_test_base.gd"

const GUT_TIMEOUT := 5.0
const StateVerificationController: GDScript = preload("res://src/ui/components/combat/state/state_verification_controller.gd")
const TestHelper = preload("res://tests/fixtures/base/test_helper.gd")

# Test variables with explicit types
var verification_updated_signal_emitted: bool = false
var last_verification_data: Dictionary = {}

# Override _create_controller_instance to provide the specific controller
func _create_controller_instance() -> Node:
	return StateVerificationController.new()

# Override _get_required_methods to specify required methods
func _get_required_methods() -> Array[String]:
	return [
		"request_verification",
		"add_verification_rule",
		"remove_verification_rule",
		"set_auto_verify",
		"get_auto_verify",
		"get_verification_rules"
	]

func before_each() -> void:
	await super.before_each()
	_reset_signals()
	_connect_signals()

func after_each() -> void:
	await super.after_each()
	verification_updated_signal_emitted = false
	last_verification_data.clear()

func _reset_signals() -> void:
	verification_updated_signal_emitted = false
	last_verification_data.clear()

func _connect_signals() -> void:
	if not is_instance_valid(_controller):
		assert_fail("Cannot connect signals: controller is null")
		return
		
	if _controller.has_signal("verification_updated"):
		_controller.verification_updated.connect(func(data: Dictionary):
			verification_updated_signal_emitted = true
			last_verification_data = data.duplicate()
		)

func _get_test_data(type: int) -> Dictionary:
	match type:
		GameEnums.VerificationType.COMBAT:
			return {
				"status": GameEnums.CombatStatus.NONE,
				"type": type
			}
		GameEnums.VerificationType.STATE:
			var test_character = null
			var helper_instance = TestHelper.get_instance()
			if helper_instance and helper_instance.has_method("create_test_character"):
				test_character = helper_instance.create_test_character()
			return {
				"status": GameEnums.CombatStatus.NONE,
				"character": test_character,
				"type": type
			}
		_:
			return {"type": type}

# Basic State Tests
func test_initialization() -> void:
	assert_not_null(_controller, "State verification controller should be initialized")
	assert_true(_controller.has_method("request_verification"), "Should have request_verification method")
	
	var rules: Dictionary = TypeSafeMixin._call_node_method_dict(_controller, "get_verification_rules", [])
	var auto_verify: bool = TypeSafeMixin._call_node_method_bool(_controller, "get_auto_verify", [])
	
	assert_true(rules.size() > 0, "Should have default verification rules")
	assert_false(auto_verify, "Should start with auto verify disabled")

# Rule Management Tests
func test_verification_rules() -> void:
	var rules: Dictionary = TypeSafeMixin._call_node_method_dict(_controller, "get_verification_rules", [])
	
	var has_combat: bool = GameEnums.VerificationType.COMBAT in rules
	var has_state: bool = GameEnums.VerificationType.STATE in rules
	var has_rules: bool = GameEnums.VerificationType.RULES in rules
	var has_movement: bool = GameEnums.VerificationType.MOVEMENT in rules
	
	assert_true(has_combat, "Should have combat verification rules")
	assert_true(has_state, "Should have state verification rules")
	assert_true(has_rules, "Should have rules verification rules")
	assert_true(has_movement, "Should have movement verification rules")

func test_add_verification_rule() -> void:
	var test_rule: Dictionary = {
		"required_fields": ["test_field"],
		"validation_method": "test_validation",
		"error_message": "Test error"
	}
	
	var result: bool = TypeSafeMixin._call_node_method_bool(
		_controller,
		"add_verification_rule",
		[GameEnums.VerificationType.RULES, test_rule]
	)
	assert_true(result, "Should successfully add rule")
	
	var rules: Dictionary = TypeSafeMixin._call_node_method_dict(_controller, "get_verification_rules", [])
	assert_true(GameEnums.VerificationType.RULES in rules, "Should have rules rule")

func test_remove_verification_rule() -> void:
	var result: bool = TypeSafeMixin._call_node_method_bool(
		_controller,
		"remove_verification_rule",
		[GameEnums.VerificationType.COMBAT]
	)
	assert_true(result, "Should successfully remove rule")
	
	var rules: Dictionary = TypeSafeMixin._call_node_method_dict(_controller, "get_verification_rules", [])
	assert_false(GameEnums.VerificationType.COMBAT in rules, "Should not have combat rule")

func test_verification_request() -> void:
	var test_data: Dictionary = _get_test_data(GameEnums.VerificationType.COMBAT)
	var result: bool = TypeSafeMixin._call_node_method_bool(_controller, "request_verification", [test_data])
	
	assert_true(result, "Should successfully request verification")
	assert_true(verification_updated_signal_emitted, "Should emit verification updated signal")
	
	# Safely check if the key exists in the dictionary before accessing it
	assert_true(last_verification_data.has("type"), "Verification data should contain type field")
	if last_verification_data.has("type"):
		assert_eq(last_verification_data.get("type"), GameEnums.VerificationType.COMBAT, "Should pass correct verification type")

func test_auto_verify_toggle() -> void:
	var result: bool = TypeSafeMixin._call_node_method_bool(_controller, "set_auto_verify", [true])
	assert_true(result, "Should successfully enable auto verify")
	
	var auto_verify: bool = TypeSafeMixin._call_node_method_bool(_controller, "get_auto_verify", [])
	assert_true(auto_verify, "Auto verify should be enabled")
	
	result = TypeSafeMixin._call_node_method_bool(_controller, "set_auto_verify", [false])
	assert_true(result, "Should successfully disable auto verify")
	
	auto_verify = TypeSafeMixin._call_node_method_bool(_controller, "get_auto_verify", [])
	assert_false(auto_verify, "Auto verify should be disabled")

# Override parent methods to specify properties that can be null
func _is_nullable_property(property_name: String) -> bool:
	var nullable_properties := [
		"_auto_verify",
		"_verification_rules"
	]
	return property_name in nullable_properties

# Specify which properties should be compared during reset tests
func _is_simple_property(property_name: String) -> bool:
	# Only compare simple data types, not complex structures like dictionaries
	var simple_properties := [
		"_auto_verify"
	]
	return property_name in simple_properties

# Override parent test_accessibility to provide a Control parameter
func test_accessibility(control: Control = null) -> void:
	if not is_instance_valid(_controller):
		assert_fail("Skipping test_accessibility: controller is null")
		return
		
	# Create a test control if none provided
	if control == null:
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
	if control == null:
		control = Control.new()
		add_child_autofree(control)
	
	# Call parent implementation with the control parameter
	await super.test_animations(control)