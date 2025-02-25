@tool
extends "res://tests/unit/ui/base/controller_test_base.gd"

const GUT_TIMEOUT := 5.0
const StateVerificationController: GDScript = preload("res://src/ui/components/combat/state/state_verification_controller.gd")

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
			return {
				"status": GameEnums.CombatStatus.NONE,
				"character": TestHelper.create_test_character(),
				"type": type
			}
		_:
			return {"type": type}

# Basic State Tests
func test_initialization() -> void:
	assert_not_null(_controller, "State verification controller should be initialized")
	assert_true(_controller.has_method("request_verification"), "Should have request_verification method")
	
	var rules: Dictionary = TypeSafeMixin._safe_method_call_dict(_controller, "get_verification_rules", [], {})
	var auto_verify: bool = TypeSafeMixin._safe_method_call_bool(_controller, "get_auto_verify", [], false)
	
	assert_true(rules.size() > 0, "Should have default verification rules")
	assert_false(auto_verify, "Should start with auto verify disabled")

# Rule Management Tests
func test_verification_rules() -> void:
	var rules: Dictionary = TypeSafeMixin._safe_method_call_dict(_controller, "get_verification_rules", [], {})
	
	var has_combat: bool = rules.has(GameEnums.VerificationType.COMBAT)
	var has_state: bool = rules.has(GameEnums.VerificationType.STATE)
	var has_rules: bool = rules.has(GameEnums.VerificationType.RULES)
	var has_movement: bool = rules.has(GameEnums.VerificationType.MOVEMENT)
	
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
	
	var result: bool = TypeSafeMixin._safe_method_call_bool(
		_controller,
		"add_verification_rule",
		[GameEnums.VerificationType.RULES, test_rule]
	)
	assert_true(result, "Should successfully add rule")
	
	var rules: Dictionary = TypeSafeMixin._safe_method_call_dict(_controller, "get_verification_rules", [], {})
	assert_true(rules.has(GameEnums.VerificationType.RULES), "Should have rules rule")

func test_remove_verification_rule() -> void:
	var result: bool = TypeSafeMixin._safe_method_call_bool(
		_controller,
		"remove_verification_rule",
		[GameEnums.VerificationType.COMBAT]
	)
	assert_true(result, "Should successfully remove rule")
	
	var rules: Dictionary = TypeSafeMixin._safe_method_call_dict(_controller, "get_verification_rules", [], {})
	assert_false(rules.has(GameEnums.VerificationType.COMBAT), "Should not have combat rule")

func test_verification_request() -> void:
	var test_data: Dictionary = _get_test_data(GameEnums.VerificationType.COMBAT)
	var result: bool = TypeSafeMixin._safe_method_call_bool(_controller, "request_verification", [test_data])
	
	assert_true(result, "Should successfully request verification")
	assert_true(verification_updated_signal_emitted, "Should emit verification updated signal")
	assert_eq(last_verification_data.type, GameEnums.VerificationType.COMBAT, "Should pass correct verification type")

func test_auto_verify_toggle() -> void:
	var result: bool = TypeSafeMixin._safe_method_call_bool(_controller, "set_auto_verify", [true])
	assert_true(result, "Should successfully enable auto verify")
	
	var auto_verify: bool = TypeSafeMixin._safe_method_call_bool(_controller, "get_auto_verify", [], false)
	assert_true(auto_verify, "Auto verify should be enabled")
	
	result = TypeSafeMixin._safe_method_call_bool(_controller, "set_auto_verify", [false])
	assert_true(result, "Should successfully disable auto verify")
	
	auto_verify = TypeSafeMixin._safe_method_call_bool(_controller, "get_auto_verify", [], true)
	assert_false(auto_verify, "Auto verify should be disabled")