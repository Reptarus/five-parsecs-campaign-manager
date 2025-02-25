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
extends "res://tests/fixtures/specialized/enemy_test_base.gd"

const ErrorLogger := preload("res://src/core/systems/ErrorLogger.gd")


# Test variables
var logger: ErrorLogger

# Helper Methods
func create_test_error(message: String, category: int, severity: int, context: Dictionary = {}) -> void:
	logger.log_error(message, category, severity, context)
	verify_signal_emitted(logger, "error_logged")

func verify_error_context(error_index: int, expected_context: Dictionary) -> void:
	var error = logger.error_history[error_index]
	for key in expected_context:
		assert_eq(error.context[key], expected_context[key], "Context %s should match" % key)

# Lifecycle Methods
func before_each() -> void:
	await super.before_each()
	logger = ErrorLogger.new()
	var logger_node := _safe_cast_to_node(logger, "ErrorLogger")
	add_child_autofree(logger_node)
	track_test_node(logger_node)
	watch_signals(logger)

func after_each() -> void:
	await super.after_each()
	logger = null

# Test Cases
func test_basic_error_logging() -> void:
	create_test_error("Test error", 0, 1)
	assert_eq(logger.error_history.size(), 1, "Should have one error in history")
	verify_signal_emitted(logger, "error_logged", "Error logged signal should be emitted")

func test_error_with_context() -> void:
	var context = {"source": "test", "details": "test details"}
	create_test_error("Test error with context", 0, 1, context)
	verify_error_context(0, context)
	verify_signal_emitted(logger, "error_logged", "Error logged signal should be emitted")

func test_multiple_errors() -> void:
	create_test_error("First error", 0, 1)
	create_test_error("Second error", 1, 2)
	assert_eq(logger.error_history.size(), 2, "Should have two errors in history")
	var emit_count: int = _signal_watcher.get_emit_count(logger, "error_logged")
	assert_eq(emit_count, 2, "Should emit error_logged signal twice")

func test_error_categories() -> void:
	create_test_error("Category 0 error", 0, 1)
	create_test_error("Category 1 error", 1, 1)
	create_test_error("Category 2 error", 2, 1)
	
	assert_eq(logger.error_history[0].category, 0, "First error should be category 0")
	assert_eq(logger.error_history[1].category, 1, "Second error should be category 1")
	assert_eq(logger.error_history[2].category, 2, "Third error should be category 2")
	verify_signal_emitted(logger, "error_logged", "Error logged signal should be emitted")

func test_error_severity() -> void:
	create_test_error("Low severity error", 0, 0)
	create_test_error("Medium severity error", 0, 1)
	create_test_error("High severity error", 0, 2)
	
	assert_eq(logger.error_history[0].severity, 0, "First error should be low severity")
	assert_eq(logger.error_history[1].severity, 1, "Second error should be medium severity")
	assert_eq(logger.error_history[2].severity, 2, "Third error should be high severity")
	verify_signal_emitted(logger, "error_logged", "Error logged signal should be emitted")

# Basic Error Logging Tests
func test_initial_state() -> void:
	assert_eq(logger.error_history.size(), 0, "Should start with no errors")

func test_log_error() -> void:
	logger.log_error("Test error", ErrorLogger.ErrorCategory.VALIDATION, ErrorLogger.ErrorSeverity.ERROR)
	assert_eq(logger.error_history.size(), 1, "Should have one error in history")
	var error = logger.error_history[0]
	assert_eq(error.message, "Test error", "Should store error message")
	verify_signal_emitted(logger, "error_logged")

func test_clear_errors() -> void:
	logger.log_error("Test error", ErrorLogger.ErrorCategory.VALIDATION, ErrorLogger.ErrorSeverity.ERROR)
	logger.clear_error_history()
	
	assert_eq(logger.error_history.size(), 0, "Should clear error history")
	verify_signal_emitted(logger, "error_logged")

# Error Categorization Tests
func test_error_severity_levels() -> void:
	logger.log_error("Warning", ErrorLogger.ErrorCategory.VALIDATION, ErrorLogger.ErrorSeverity.WARNING)
	assert_eq(logger.error_history[0].severity, ErrorLogger.ErrorSeverity.WARNING, "Should store warning severity")
	
	logger.log_error("Error", ErrorLogger.ErrorCategory.VALIDATION, ErrorLogger.ErrorSeverity.ERROR)
	assert_eq(logger.error_history[1].severity, ErrorLogger.ErrorSeverity.ERROR, "Should store error severity")
	verify_signal_emitted(logger, "error_logged")

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
	verify_signal_emitted(logger, "error_logged")

func test_invalid_category_handling() -> void:
	# Test with an invalid category value
	logger.log_error("Test error", -1, ErrorLogger.ErrorSeverity.ERROR)
	assert_eq(logger.error_history[0].category, ErrorLogger.ErrorCategory.VALIDATION, "Should default to VALIDATION category for invalid values")

# Performance Tests
func test_large_error_count() -> void:
	for i in range(1000):
		logger.log_error("Error %d" % i, 0, 1)
	
	assert_true(logger.error_history.size() <= 1000, "Should handle large number of errors")
	var emit_count: int = _signal_watcher.get_emit_count(logger, "error_logged")
	assert_eq(emit_count, 1000, "Should emit signal for each error")

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