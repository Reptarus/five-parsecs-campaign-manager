@tool
extends "res://tests/fixtures/base_test.gd"

const StateVerificationController: PackedScene = preload("res://src/ui/components/combat/state/state_verification_controller.tscn")


var controller: Node
var mock_combat_manager: Node

# Lifecycle Methods
func before_each() -> void:
	await super.before_each()
	controller = StateVerificationController.instantiate()
	mock_combat_manager = Node.new()
	mock_combat_manager.name = "CombatManager"
	mock_combat_manager.add_user_signal("combat_state_changed")
	mock_combat_manager.add_user_signal("verification_requested")
	add_child(mock_combat_manager)
	add_child(controller)
	track_test_node(controller)
	watch_signals(controller)
	watch_signals(mock_combat_manager)
	await get_tree().process_frame

func after_each() -> void:
	await super.after_each()
	controller = null
	mock_combat_manager = null

# Helper Methods
func create_test_state(type: int = GameEnums.VerificationType.COMBAT) -> Dictionary:
	match type:
		GameEnums.VerificationType.COMBAT:
			return {
				"phase": GameEnums.BattlePhase.SETUP,
				"active_unit": null,
				"modifiers": {},
				"type": type
			}
		GameEnums.VerificationType.MOVEMENT:
			return {
				"position": Vector2i(0, 0),
				"character": MockCharacter.new(),
				"type": type
			}
		GameEnums.VerificationType.STATE:
			return {
				"status": GameEnums.CombatStatus.NONE,
				"character": MockCharacter.new(),
				"type": type
			}
		_:
			return {"type": type}

# Basic State Tests
func test_initialization() -> void:
	assert_not_null(controller, "State verification controller should be initialized")
	assert_true(controller.has_method("request_verification"), "Should have request_verification method")
	assert_true(controller.verification_rules.size() > 0, "Should have default verification rules")
	assert_false(controller.auto_verify, "Should start with auto verify disabled")

# Rule Management Tests
func test_verification_rules() -> void:
	var rules = controller.verification_rules
	assert_has(rules, GameEnums.VerificationType.COMBAT, "Should have combat verification rules")
	assert_has(rules, GameEnums.VerificationType.STATE, "Should have state verification rules")
	assert_has(rules, GameEnums.VerificationType.RULES, "Should have rules verification rules")
	assert_has(rules, GameEnums.VerificationType.MOVEMENT, "Should have movement verification rules")

func test_add_verification_rule() -> void:
	var test_rule = {
		"required_fields": ["test_field"],
		"validators": ["_validate_test"],
		"scope": GameEnums.VerificationScope.SINGLE
	}
	controller.add_verification_rule(GameEnums.VerificationType.RULES, test_rule)
	assert_has(controller.verification_rules[GameEnums.VerificationType.RULES], test_rule, "Should add new rule")
	assert_signal_emitted(controller, "rules_updated")

func test_remove_verification_rule() -> void:
	var test_rule = {
		"required_fields": ["test_field"],
		"validators": ["_validate_test"],
		"scope": GameEnums.VerificationScope.SINGLE
	}
	controller.add_verification_rule(GameEnums.VerificationType.RULES, test_rule)
	controller.remove_verification_rule(GameEnums.VerificationType.RULES, test_rule)
	assert_does_not_have(controller.verification_rules[GameEnums.VerificationType.RULES], test_rule, "Should remove rule")
	assert_signal_emitted(controller, "rules_updated")

# Verification Tests
func test_verify_combat_state() -> void:
	var test_state = create_test_state(GameEnums.VerificationType.COMBAT)
	var result = controller._verify_state(GameEnums.VerificationType.COMBAT, test_state)
	assert_eq(result.status, GameEnums.VerificationResult.SUCCESS, "Valid combat state should pass verification")
	assert_signal_emitted(controller, "verification_completed")

func test_verify_invalid_combat_state() -> void:
	var test_state = create_test_state(GameEnums.VerificationType.COMBAT)
	test_state.phase = -1 # Invalid phase
	var result = controller._verify_state(GameEnums.VerificationType.COMBAT, test_state)
	assert_eq(result.status, GameEnums.VerificationResult.ERROR, "Invalid combat state should fail verification")
	assert_signal_emitted(controller, "verification_failed")

func test_verify_movement_state() -> void:
	var test_state = create_test_state(GameEnums.VerificationType.MOVEMENT)
	var result = controller._verify_state(GameEnums.VerificationType.MOVEMENT, test_state)
	assert_eq(result.status, GameEnums.VerificationResult.SUCCESS, "Valid position should pass verification")
	assert_signal_emitted(controller, "verification_completed")

func test_verify_status_state() -> void:
	var test_state = create_test_state(GameEnums.VerificationType.STATE)
	var result = controller._verify_state(GameEnums.VerificationType.STATE, test_state)
	assert_eq(result.status, GameEnums.VerificationResult.SUCCESS, "Valid status should pass verification")
	assert_signal_emitted(controller, "verification_completed")

# History Management Tests
func test_verification_history() -> void:
	var test_states = [
		create_test_state(GameEnums.VerificationType.COMBAT),
		create_test_state(GameEnums.VerificationType.MOVEMENT),
		create_test_state(GameEnums.VerificationType.STATE)
	]
	
	for state in test_states:
		controller._verify_state(state.type, state)
	
	assert_eq(controller.verification_history.size(), test_states.size(), "Should add all verification results to history")
	assert_eq(controller.verification_history[0].type, GameEnums.VerificationType.COMBAT, "Should preserve verification order")

func test_clear_verification_history() -> void:
	var test_state = create_test_state()
	controller._verify_state(test_state.type, test_state)
	controller.clear_verification_history()
	assert_eq(controller.verification_history.size(), 0, "Should clear verification history")
	assert_signal_emitted(controller, "history_cleared")

# Auto Verification Tests
func test_auto_verify_enabled() -> void:
	controller.auto_verify = true
	var test_state = create_test_state()
	mock_combat_manager.emit_signal("combat_state_changed", test_state)
	assert_signal_emitted(controller, "verification_started")
	assert_signal_emitted(controller, "verification_completed")

func test_auto_verify_disabled() -> void:
	controller.auto_verify = false
	var test_state = create_test_state()
	mock_combat_manager.emit_signal("combat_state_changed", test_state)
	assert_signal_not_emitted(controller, "verification_started")

# Error Handling Tests
func test_invalid_verification_type() -> void:
	var test_state = create_test_state(-1)
	var result = controller._verify_state(-1, test_state)
	assert_eq(result.status, GameEnums.VerificationResult.ERROR, "Should handle invalid verification type")
	assert_signal_emitted(controller, "verification_failed")

func test_missing_required_fields() -> void:
	var test_state = {} # Empty state
	var result = controller._verify_state(GameEnums.VerificationType.COMBAT, test_state)
	assert_eq(result.status, GameEnums.VerificationResult.ERROR, "Should fail on missing required fields")
	assert_signal_emitted(controller, "verification_failed")

# Performance Tests
func test_rapid_verifications() -> void:
	var start_time = Time.get_unix_time_from_system()
	var verification_count = 100
	
	for i in range(verification_count):
		var test_state = create_test_state()
		controller._verify_state(test_state.type, test_state)
	
	var end_time = Time.get_unix_time_from_system()
	var time_taken = end_time - start_time
	
	assert_eq(controller.verification_history.size(), verification_count, "Should handle all verifications")
	assert_true(time_taken < 1.0, "Should process verifications efficiently")

class MockCharacter extends Node:
	func is_enemy() -> bool:
		return false