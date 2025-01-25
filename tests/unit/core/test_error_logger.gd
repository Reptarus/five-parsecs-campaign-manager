## Test class for ErrorLogger functionality
##
## Comprehensive test suite for the ErrorLogger system covering:
## - Basic error logging and management
## - Error categorization and severity handling
## - Game state validation
## - Performance and boundary conditions
## - Signal verification
## - Error context handling
@tool
extends "res://tests/fixtures/base_test.gd"

const ErrorLogger := preload("res://src/core/systems/ErrorLogger.gd")


# Test variables
var logger: ErrorLogger

# Helper Methods
func create_test_error(message: String, category: int, severity: int, context: Dictionary = {}) -> void:
	logger.log_error(message, category, severity, context)
	assert_signal_emitted(logger, "error_logged")

func verify_error_context(error_index: int, expected_context: Dictionary) -> void:
	var error = logger.error_history[error_index]
	for key in expected_context:
		assert_eq(error.context[key], expected_context[key], "Context %s should match" % key)

# Lifecycle Methods
func before_each() -> void:
	await super.before_each()
	logger = ErrorLogger.new()
	track_test_resource(logger)
	watch_signals(logger)

func after_each() -> void:
	await super.after_each()
	logger = null

# Basic Error Logging Tests
func test_initial_state() -> void:
	assert_eq(logger.error_history.size(), 0, "Should start with no errors")

func test_log_error() -> void:
	logger.log_error("Test error", ErrorLogger.ErrorCategory.VALIDATION, ErrorLogger.ErrorSeverity.ERROR)
	assert_eq(logger.error_history.size(), 1, "Should have one error in history")
	var error = logger.error_history[0]
	assert_eq(error.message, "Test error", "Should store error message")
	assert_signal_emitted(logger, "error_logged")

func test_clear_errors() -> void:
	logger.log_error("Test error", ErrorLogger.ErrorCategory.VALIDATION, ErrorLogger.ErrorSeverity.ERROR)
	logger.clear_error_history()
	
	assert_eq(logger.error_history.size(), 0, "Should clear error history")
	assert_signal_emitted(logger, "error_logged")

# Error Categorization Tests
func test_error_severity_levels() -> void:
	logger.log_error("Warning", ErrorLogger.ErrorCategory.VALIDATION, ErrorLogger.ErrorSeverity.WARNING)
	assert_eq(logger.error_history[0].severity, ErrorLogger.ErrorSeverity.WARNING, "Should store warning severity")
	
	logger.log_error("Error", ErrorLogger.ErrorCategory.VALIDATION, ErrorLogger.ErrorSeverity.ERROR)
	assert_eq(logger.error_history[1].severity, ErrorLogger.ErrorSeverity.ERROR, "Should store error severity")
	assert_signal_emitted(logger, "error_logged")

# Game State Validation Tests
func test_phase_transition_errors() -> void:
	# Test invalid phase transitions
	logger.log_error(
		"Invalid phase transition",
		ErrorLogger.ErrorCategory.VALIDATION,
		ErrorLogger.ErrorSeverity.ERROR,
		{
			"from_phase": GameEnums.CampaignPhase.SETUP,
			"to_phase": GameEnums.CampaignPhase.BATTLE_RESOLUTION,
			"expected": GameEnums.CampaignPhase.CAMPAIGN
		}
	)
	
	var error = logger.error_history[0]
	assert_not_null(error.context, "Should include phase transition context")
	assert_eq(error.context.from_phase, GameEnums.CampaignPhase.SETUP, "Should store source phase")
	assert_eq(error.context.to_phase, GameEnums.CampaignPhase.BATTLE_RESOLUTION, "Should store target phase")

func test_combat_validation_errors() -> void:
	# Test combat-related errors
	logger.log_error(
		"Invalid combat action",
		ErrorLogger.ErrorCategory.VALIDATION,
		ErrorLogger.ErrorSeverity.WARNING,
		{
			"action": GameEnums.UnitAction.ATTACK,
			"reason": "Insufficient action points",
			"combat_phase": GameEnums.CombatPhase.ACTION
		}
	)
	
	var error = logger.error_history[0]
	assert_eq(error.context.action, GameEnums.UnitAction.ATTACK, "Should store combat action")
	assert_eq(error.context.combat_phase, GameEnums.CombatPhase.ACTION, "Should store combat phase")

# State Verification Tests
func test_verification_errors() -> void:
	# Test verification system errors
	logger.log_error(
		"State verification failed",
		ErrorLogger.ErrorCategory.VALIDATION,
		ErrorLogger.ErrorSeverity.ERROR,
		{
			"type": GameEnums.VerificationType.STATE,
			"scope": GameEnums.VerificationScope.ALL,
			"result": GameEnums.VerificationResult.ERROR
		}
	)
	
	var error = logger.error_history[0]
	assert_eq(error.context.type, GameEnums.VerificationType.STATE, "Should store verification type")
	assert_eq(error.context.result, GameEnums.VerificationResult.ERROR, "Should store verification result")

# Error Boundary Tests
func test_empty_message_handling() -> void:
	logger.log_error("", ErrorLogger.ErrorCategory.VALIDATION, ErrorLogger.ErrorSeverity.ERROR)
	assert_eq(logger.error_history[0].message, "", "Should handle empty error messages")
	assert_signal_emitted(logger, "error_logged")

func test_invalid_category_handling() -> void:
	# Test with an invalid category value
	logger.log_error("Test error", -1, ErrorLogger.ErrorSeverity.ERROR)
	assert_eq(logger.error_history[0].category, ErrorLogger.ErrorCategory.VALIDATION, "Should default to VALIDATION category for invalid values")

# Performance Tests
func test_large_error_history() -> void:
	# Test logging many errors
	for i in range(1000):
		logger.log_error(
			"Error %d" % i,
			ErrorLogger.ErrorCategory.VALIDATION,
			ErrorLogger.ErrorSeverity.ERROR,
			{"index": i}
		)
	
	assert_true(logger.error_history.size() <= 1000, "Should handle large number of errors")
	assert_signal_emit_count(logger, "error_logged", 1000)

func test_concurrent_operations() -> void:
	# Test logging and clearing concurrently
	logger.log_error(
		"Error 1",
		ErrorLogger.ErrorCategory.VALIDATION,
		ErrorLogger.ErrorSeverity.ERROR,
		{"game_state": GameEnums.GameState.CAMPAIGN}
	)
	logger.clear_error_history()
	logger.log_error(
		"Error 2",
		ErrorLogger.ErrorCategory.VALIDATION,
		ErrorLogger.ErrorSeverity.ERROR,
		{"game_state": GameEnums.GameState.BATTLE}
	)
	
	assert_eq(logger.error_history.size(), 1, "Should handle concurrent operations correctly")
	assert_eq(logger.error_history[0].message, "Error 2", "Should contain only the latest error")
	assert_eq(logger.error_history[0].context.game_state, GameEnums.GameState.BATTLE, "Should maintain context in concurrent operations")

# Signal Verification Tests
func test_error_signal_payload() -> void:
	var test_context := {"test_key": "test_value"}
	var received_message: String = ""
	var received_context: Dictionary = {}
	
	logger.error_logged.connect(func(error_data: Dictionary):
		received_message = error_data.message
		received_context = error_data.context
	)
	
	create_test_error("Signal test", ErrorLogger.ErrorCategory.VALIDATION, ErrorLogger.ErrorSeverity.ERROR, test_context)
	
	assert_eq(received_message, "Signal test", "Signal should contain error message")
	assert_eq(received_context, test_context, "Signal should contain error context")

func test_multiple_error_signals() -> void:
	var signal_count: int = 0
	logger.error_logged.connect(func(_error_data: Dictionary): signal_count += 1)
	
	for i in range(3):
		create_test_error("Error %d" % i, ErrorLogger.ErrorCategory.VALIDATION, ErrorLogger.ErrorSeverity.ERROR)
	
	assert_eq(signal_count, 3, "Should emit correct number of signals")