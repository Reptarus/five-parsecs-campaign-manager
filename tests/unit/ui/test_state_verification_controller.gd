@tool
extends "res://tests/test_base.gd"

const StateVerificationController := preload("res://src/ui/components/combat/state/state_verification_controller.tscn")
const TestHelper := preload("res://tests/fixtures/test_helper.gd")

var controller: Node
var mock_combat_manager: Node

func before_each() -> void:
    super.before_each()
    controller = StateVerificationController.instantiate()
    mock_combat_manager = Node.new()
    mock_combat_manager.name = "CombatManager"
    add_child(mock_combat_manager)
    add_child(controller)

func after_each() -> void:
    super.after_each()
    controller = null
    mock_combat_manager = null

func test_initialization() -> void:
    assert_not_null(controller, "State verification controller should be initialized")
    assert_true(controller.has_method("request_verification"), "Should have request_verification method")
    assert_true(controller.verification_rules.size() > 0, "Should have default verification rules")

func test_verification_rules() -> void:
    var rules = controller.verification_rules
    assert_has(rules, GameEnums.VerificationType.COMBAT, "Should have combat verification rules")
    assert_has(rules, GameEnums.VerificationType.STATE, "Should have state verification rules")
    assert_has(rules, GameEnums.VerificationType.RULES, "Should have rules verification rules")

func test_add_verification_rule() -> void:
    var test_rule = {
        "required_fields": ["test_field"],
        "validators": ["_validate_test"]
    }
    controller.add_verification_rule(GameEnums.VerificationType.RULES, test_rule)
    assert_has(controller.verification_rules, GameEnums.VerificationType.RULES, "Should add new rule")

func test_verify_combat_state() -> void:
    var test_state = {
        "phase": GameEnums.CombatPhase.SETUP,
        "active_unit": null,
        "modifiers": {}
    }
    var result = controller._verify_state(GameEnums.VerificationType.COMBAT, test_state)
    assert_eq(result.status, GameEnums.VerificationResult.SUCCESS, "Valid combat state should pass verification")

func test_verify_invalid_combat_state() -> void:
    var test_state = {
        "phase": - 1, # Invalid phase
        "active_unit": null,
        "modifiers": {}
    }
    var result = controller._verify_state(GameEnums.VerificationType.COMBAT, test_state)
    assert_eq(result.status, GameEnums.VerificationResult.ERROR, "Invalid combat state should fail verification")

func test_verify_position() -> void:
    var test_state = {
        "position": Vector2i(0, 0),
        "character": MockCharacter.new()
    }
    var result = controller._verify_state(GameEnums.VerificationType.MOVEMENT, test_state)
    assert_eq(result.status, GameEnums.VerificationResult.SUCCESS, "Valid position should pass verification")

func test_verify_status() -> void:
    var test_state = {
        "status": GameEnums.CombatStatus.NONE,
        "character": MockCharacter.new()
    }
    var result = controller._verify_state(GameEnums.VerificationType.STATE, test_state)
    assert_eq(result.status, GameEnums.VerificationResult.SUCCESS, "Valid status should pass verification")

func test_verification_history() -> void:
    var test_state = {
        "phase": GameEnums.CombatPhase.SETUP,
        "active_unit": null,
        "modifiers": {}
    }
    controller._verify_state(GameEnums.VerificationType.COMBAT, test_state)
    assert_eq(controller.verification_history.size(), 1, "Should add verification result to history")

func test_clear_verification_history() -> void:
    var test_state = {
        "phase": GameEnums.CombatPhase.SETUP,
        "active_unit": null,
        "modifiers": {}
    }
    controller._verify_state(GameEnums.VerificationType.COMBAT, test_state)
    controller.clear_verification_history()
    assert_eq(controller.verification_history.size(), 0, "Should clear verification history")

func test_auto_verify() -> void:
    watch_signals(controller)
    controller.auto_verify = true
    mock_combat_manager.combat_state_changed.emit({})
    assert_signal_emitted(controller, "verification_started")

class MockCharacter extends Node:
    func is_enemy() -> bool:
        return false