@tool
extends "res://tests/unit/ui/base/controller_test_base.gd"

const StateVerificationController: GDScript = preload("res://src/ui/components/combat/state/state_verification_controller.gd")
const TestHelper = preload("res://tests/fixtures/base/test_helper.gd")

# Test variables with explicit types
var verification_updated_signal_emitted: bool = false
var verification_completed_signal_emitted: bool = false
var last_verification_data: Dictionary = {}

# Override _create_controller_instance to provide the specific controller
func _create_controller_instance() -> Node:
	var instance = StateVerificationController.new()
	if not is_instance_valid(instance):
		push_error("Failed to create state verification controller instance")
	return instance

func before_each() -> void:
	await super.before_each()
	_reset_signals()
	_connect_signals()

func after_each() -> void:
	_disconnect_signals()
	await super.after_each()
	verification_updated_signal_emitted = false
	verification_completed_signal_emitted = false
	last_verification_data.clear()

func _reset_signals() -> void:
	verification_updated_signal_emitted = false
	verification_completed_signal_emitted = false
	last_verification_data.clear()

func _connect_signals() -> void:
	if not is_instance_valid(_controller):
		assert_fail("Cannot connect signals: controller is null")
		return
		
	if _controller.has_signal("verification_updated") and not _controller.is_connected("verification_updated", _on_verification_updated):
		var callable_updated = Callable(self, "_on_verification_updated")
		_controller.connect("verification_updated", callable_updated)
		
	if _controller.has_signal("verification_completed") and not _controller.is_connected("verification_completed", _on_verification_completed):
		var callable_completed = Callable(self, "_on_verification_completed")
		_controller.connect("verification_completed", callable_completed)

func _disconnect_signals() -> void:
	if not is_instance_valid(_controller) or _controller.is_queued_for_deletion():
		return
		
	if _controller.has_signal("verification_updated") and _controller.is_connected("verification_updated", _on_verification_updated):
		var callable_updated = Callable(self, "_on_verification_updated")
		_controller.disconnect("verification_updated", callable_updated)
		
	if _controller.has_signal("verification_completed") and _controller.is_connected("verification_completed", _on_verification_completed):
		var callable_completed = Callable(self, "_on_verification_completed")
		_controller.disconnect("verification_completed", callable_completed)

func _on_verification_updated(verification_data: Dictionary) -> void:
	verification_updated_signal_emitted = true
	# Use a proper deep copy to avoid reference issues
	last_verification_data = verification_data.duplicate(true)

func _on_verification_completed() -> void:
	verification_completed_signal_emitted = true

func _get_test_data(type: int) -> Dictionary:
	# Safely handle enum values
	if typeof(type) != TYPE_INT:
		push_warning("Invalid verification type provided to _get_test_data")
		return {"type": 0}
		
	# Ensure GameEnums is defined
	if not "GameEnums" in get_parent():
		push_warning("GameEnums not available, using hardcoded values")
		match type:
			0: # COMBAT
				return {
					"status": 0, # NONE
					"type": type
				}
			1: # STATE
				return {
					"status": 0, # NONE
					"character": null,
					"type": type
				}
			_:
				return {"type": type}
	
	# Use GameEnums if available
	match type:
		GameEnums.VerificationType.COMBAT:
			return {
				"status": GameEnums.CombatStatus.NONE,
				"type": type
			}
		GameEnums.VerificationType.STATE:
			var character = null
			var helper_instance = TestHelper.get_instance()
			if helper_instance and helper_instance.has_method("create_test_character"):
				character = helper_instance.create_test_character()
				if not is_instance_valid(character):
					push_warning("Failed to create test character")
			return {
				"status": GameEnums.CombatStatus.NONE,
				"character": character,
				"type": type
			}
		_:
			return {"type": type}

# Basic State Tests
func test_initialization() -> void:
	if not is_instance_valid(_controller):
		assert_fail("State verification controller should be initialized")
		return
		
	assert_true(_controller.has_method("request_verification"), "Should have request_verification method")
	
	# Safely get properties
	var rules = {}
	var auto_verify = false
	
	if _controller.has_method("get_verification_rules"):
		rules = TypeSafeMixin._call_node_method_dict(_controller, "get_verification_rules", [])
	else:
		push_warning("Controller missing get_verification_rules method")
		
	if _controller.has_method("get_auto_verify"):
		auto_verify = TypeSafeMixin._call_node_method_bool(_controller, "get_auto_verify", [])
	else:
		push_warning("Controller missing get_auto_verify method")
	
	assert_true(rules.size() > 0, "Should have default verification rules")
	assert_false(auto_verify, "Should start with auto verify disabled")

# Rule Management Tests
func test_verification_rules() -> void:
	if not is_instance_valid(_controller):
		assert_fail("State verification controller should be initialized")
		return
		
	if not _controller.has_method("get_verification_rules"):
		assert_fail("Controller missing get_verification_rules method")
		return
		
	var rules: Dictionary = TypeSafeMixin._call_node_method_dict(_controller, "get_verification_rules", [])
	
	# Safely check rules
	var has_combat = false
	var has_state = false
	var has_rules = false
	var has_movement = false
	
	# Ensure GameEnums is defined
	if "GameEnums" in get_parent() and "VerificationType" in GameEnums:
		has_combat = rules.has(GameEnums.VerificationType.COMBAT)
		has_state = rules.has(GameEnums.VerificationType.STATE)
		has_rules = rules.has(GameEnums.VerificationType.RULES)
		has_movement = rules.has(GameEnums.VerificationType.MOVEMENT)
	else:
		# Fallback to checking by integer keys
		has_combat = rules.has(0) # COMBAT
		has_state = rules.has(1) # STATE
		has_rules = rules.has(2) # RULES
		has_movement = rules.has(3) # MOVEMENT
	
	assert_true(has_combat, "Should have combat verification rules")
	assert_true(has_state, "Should have state verification rules")
	assert_true(has_rules, "Should have rules verification rules")
	assert_true(has_movement, "Should have movement verification rules")

func test_add_verification_rule() -> void:
	if not is_instance_valid(_controller):
		assert_fail("State verification controller should be initialized")
		return
		
	if not _controller.has_method("add_verification_rule") or not _controller.has_method("get_verification_rules"):
		assert_fail("Controller missing required methods")
		return
		
	var test_rule: Dictionary = {
		"required_fields": ["test_field"],
		"validation_method": "test_validation",
		"error_message": "Test error"
	}
	
	var rule_type = 2 # RULES
	if "GameEnums" in get_parent() and "VerificationType" in GameEnums:
		rule_type = GameEnums.VerificationType.RULES
	
	var result: bool = TypeSafeMixin._call_node_method_bool(
		_controller,
		"add_verification_rule",
		[rule_type, test_rule]
	)
	assert_true(result, "Should successfully add rule")
	
	var rules: Dictionary = TypeSafeMixin._call_node_method_dict(_controller, "get_verification_rules", [])
	assert_true(rules.has(rule_type), "Should have rules rule")

func test_remove_verification_rule() -> void:
	if not is_instance_valid(_controller):
		assert_fail("State verification controller should be initialized")
		return
		
	if not _controller.has_method("remove_verification_rule") or not _controller.has_method("get_verification_rules"):
		assert_fail("Controller missing required methods")
		return
		
	var rule_type = 0 # COMBAT
	if "GameEnums" in get_parent() and "VerificationType" in GameEnums:
		rule_type = GameEnums.VerificationType.COMBAT
	
	var result: bool = TypeSafeMixin._call_node_method_bool(
		_controller,
		"remove_verification_rule",
		[rule_type]
	)
	assert_true(result, "Should successfully remove rule")
	
	var rules: Dictionary = TypeSafeMixin._call_node_method_dict(_controller, "get_verification_rules", [])
	assert_false(rules.has(rule_type), "Should not have combat rule")

func test_verification_request() -> void:
	if not is_instance_valid(_controller):
		assert_fail("State verification controller should be initialized")
		return
		
	if not _controller.has_method("request_verification"):
		assert_fail("Controller missing request_verification method")
		return
		
	var rule_type = 0 # COMBAT
	if "GameEnums" in get_parent() and "VerificationType" in GameEnums:
		rule_type = GameEnums.VerificationType.COMBAT
		
	var test_data: Dictionary = _get_test_data(rule_type)
	var result: bool = TypeSafeMixin._call_node_method_bool(_controller, "request_verification", [test_data])
	
	assert_true(result, "Should successfully request verification")
	assert_true(verification_updated_signal_emitted, "Should emit verification updated signal")
	
	# Safely check if the key exists in the dictionary before accessing it
	assert_true(last_verification_data.has("type"), "Verification data should contain type field")
	if last_verification_data.has("type"):
		assert_eq(last_verification_data.get("type"), rule_type, "Should pass correct verification type")

func test_auto_verify_toggle() -> void:
	if not is_instance_valid(_controller):
		assert_fail("State verification controller should be initialized")
		return
		
	if not _controller.has_method("set_auto_verify") or not _controller.has_method("get_auto_verify"):
		assert_fail("Controller missing required methods")
		return
		
	var result: bool = TypeSafeMixin._call_node_method_bool(_controller, "set_auto_verify", [true])
	assert_true(result, "Should successfully enable auto verify")
	
	var auto_verify: bool = TypeSafeMixin._call_node_method_bool(_controller, "get_auto_verify", [])
	assert_true(auto_verify, "Auto verify should be enabled")
	
	result = TypeSafeMixin._call_node_method_bool(_controller, "set_auto_verify", [false])
	assert_true(result, "Should successfully disable auto verify")
	
	auto_verify = TypeSafeMixin._call_node_method_bool(_controller, "get_auto_verify", [])
	assert_false(auto_verify, "Auto verify should be disabled")

# Add inherited controller tests
func test_controller_initialization() -> void:
	if not is_instance_valid(_controller):
		assert_fail("Cannot test initialization: controller is null")
		return
		
	await super.test_controller_initialization()
	
	# Additional StateVerificationController-specific structure tests
	assert_true(_controller.has_method("request_verification"), "Should have request_verification method")
	assert_true(_controller.has_method("add_verification_rule"), "Should have add_verification_rule method")
	assert_true(_controller.has_method("remove_verification_rule"), "Should have remove_verification_rule method")
	assert_true(_controller.has_method("set_auto_verify"), "Should have set_auto_verify method")

func test_controller_state() -> void:
	if not is_instance_valid(_controller):
		assert_fail("Cannot test state: controller is null")
		return
		
	await super.test_controller_state()
	
	# Additional StateVerificationController-specific state tests
	if not _controller.has_method("get_verification_rules") or not _controller.has_method("get_auto_verify"):
		assert_fail("Controller missing required methods")
		return
		
	var rules: Dictionary = TypeSafeMixin._call_node_method_dict(_controller, "get_verification_rules", [])
	assert_true(rules.size() > 0, "Should have default verification rules")
	
	var auto_verify: bool = TypeSafeMixin._call_node_method_bool(_controller, "get_auto_verify", [])
	assert_false(auto_verify, "Should start with auto verify disabled")

func test_controller_signals() -> void:
	if not is_instance_valid(_controller):
		assert_fail("Cannot test signals: controller is null")
		return
		
	await super.test_controller_signals()
	
	# Additional StateVerificationController-specific signal tests
	assert_true(_controller.has_signal("verification_updated"), "Should have verification_updated signal")
	assert_true(_controller.has_signal("verification_error"), "Should have verification_error signal")
	assert_true(_controller.has_signal("verification_completed"), "Should have verification_completed signal")

# Override parent methods to specify properties that can be null
func _is_nullable_property(property_name: String) -> bool:
	var nullable_properties := [
		"_auto_verify",
		"_verification_rules",
		"_current_verification"
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
