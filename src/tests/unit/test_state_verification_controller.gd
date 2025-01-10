extends "res://addons/gut/test.gd"
class_name TestStateVerificationController

const GlobalEnums := preload("res://src/core/systems/GlobalEnums.gd")

var state_verification_controller: Node
var mock_combat_manager: Node

func before_each() -> void:
	state_verification_controller = preload("res://src/ui/components/combat/state/state_verification_controller.tscn").instantiate()
	mock_combat_manager = Node.new()
	mock_combat_manager.name = "CombatManager"
	add_child_autoqfree(mock_combat_manager)
	add_child_autoqfree(state_verification_controller)

func after_each() -> void:
	state_verification_controller.queue_free()
	mock_combat_manager.queue_free()

func test_initialization() -> void:
	assert_not_null(state_verification_controller, "State verification controller should be initialized")
	assert_true(state_verification_controller.has_method("request_verification"), "Should have request_verification method")
	assert_true(state_verification_controller.verification_rules.size() > 0, "Should have default verification rules")

func test_verification_rules() -> void:
	var rules = state_verification_controller.verification_rules
	assert_has(rules, GlobalEnums.VerificationType.COMBAT, "Should have combat verification rules")
	assert_has(rules, GlobalEnums.VerificationType.POSITION, "Should have position verification rules")
	assert_has(rules, GlobalEnums.VerificationType.STATUS, "Should have status verification rules")

func test_add_verification_rule() -> void:
	var test_rule = {
		"required_fields": ["test_field"],
		"validators": ["_validate_test"]
	}
	state_verification_controller.add_verification_rule(GlobalEnums.VerificationType.RULE, test_rule)
	assert_has(state_verification_controller.verification_rules, GlobalEnums.VerificationType.RULE, "Should add new rule")

func test_verify_combat_state() -> void:
	var test_state = {
		"phase": GlobalEnums.CombatPhase.SETUP,
		"active_unit": null,
		"modifiers": {}
	}
	var result = state_verification_controller._verify_state(GlobalEnums.VerificationType.COMBAT, test_state)
	assert_eq(result.status, GlobalEnums.VerificationResult.SUCCESS, "Valid combat state should pass verification")

func test_verify_invalid_combat_state() -> void:
	var test_state = {
		"phase": - 1, # Invalid phase
		"active_unit": null,
		"modifiers": {}
	}
	var result = state_verification_controller._verify_state(GlobalEnums.VerificationType.COMBAT, test_state)
	assert_eq(result.status, GlobalEnums.VerificationResult.ERROR, "Invalid combat state should fail verification")

func test_verify_position() -> void:
	var test_state = {
		"position": Vector2i(0, 0),
		"character": MockCharacter.new()
	}
	var result = state_verification_controller._verify_state(GlobalEnums.VerificationType.POSITION, test_state)
	assert_eq(result.status, GlobalEnums.VerificationResult.SUCCESS, "Valid position should pass verification")

func test_verify_status() -> void:
	var test_state = {
		"status": GlobalEnums.CombatStatus.NONE,
		"character": MockCharacter.new()
	}
	var result = state_verification_controller._verify_state(GlobalEnums.VerificationType.STATUS, test_state)
	assert_eq(result.status, GlobalEnums.VerificationResult.SUCCESS, "Valid status should pass verification")

func test_verification_history() -> void:
	var test_state = {
		"phase": GlobalEnums.CombatPhase.SETUP,
		"active_unit": null,
		"modifiers": {}
	}
	state_verification_controller._verify_state(GlobalEnums.VerificationType.COMBAT, test_state)
	assert_eq(state_verification_controller.verification_history.size(), 1, "Should add verification result to history")

func test_clear_verification_history() -> void:
	var test_state = {
		"phase": GlobalEnums.CombatPhase.SETUP,
		"active_unit": null,
		"modifiers": {}
	}
	state_verification_controller._verify_state(GlobalEnums.VerificationType.COMBAT, test_state)
	state_verification_controller.clear_verification_history()
	assert_eq(state_verification_controller.verification_history.size(), 0, "Should clear verification history")

func test_auto_verify() -> void:
	watch_signals(state_verification_controller)
	state_verification_controller.auto_verify = true
	mock_combat_manager.combat_state_changed.emit({})
	assert_signal_emitted(state_verification_controller, "verification_started")

class MockCharacter extends Node:
	func is_enemy() -> bool:
		return false