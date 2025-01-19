@tool
extends "res://tests/fixtures/game_test.gd"

const ErrorLogger := preload("res://src/core/systems/ErrorLogger.gd")

# Test variables
var logger: Resource # Using Resource type since ErrorLogger extends Resource

# Lifecycle Methods
func before_each() -> void:
	await super.before_each()
	logger = ErrorLogger.new()

func after_each() -> void:
	await super.after_each()
	logger = null

# Test Methods
func test_initial_state() -> void:
	assert_eq(logger.error_history.size(), 0, "Should start with no errors")

func test_log_error() -> void:
	watch_signals(logger)
	
	logger.log_error("Test error", ErrorLogger.ErrorCategory.VALIDATION, ErrorLogger.ErrorSeverity.ERROR)
	assert_eq(logger.error_history.size(), 1, "Should have one error in history")
	var error = logger.error_history[0]
	assert_eq(error.message, "Test error", "Should store error message")
	assert_signal_emitted(logger, "error_logged")

func test_clear_errors() -> void:
	watch_signals(logger)
	
	logger.log_error("Test error", ErrorLogger.ErrorCategory.VALIDATION, ErrorLogger.ErrorSeverity.ERROR)
	logger.clear_error_history()
	
	assert_eq(logger.error_history.size(), 0, "Should clear error history")
	assert_signal_emitted(logger, "error_logged")

func test_error_severity_levels() -> void:
	watch_signals(logger)
	
	logger.log_error("Warning", ErrorLogger.ErrorCategory.VALIDATION, ErrorLogger.ErrorSeverity.WARNING)
	assert_eq(logger.error_history[0].severity, ErrorLogger.ErrorSeverity.WARNING, "Should store warning severity")
	
	logger.log_error("Error", ErrorLogger.ErrorCategory.VALIDATION, ErrorLogger.ErrorSeverity.ERROR)
	assert_eq(logger.error_history[1].severity, ErrorLogger.ErrorSeverity.ERROR, "Should store error severity")
	assert_signal_emitted(logger, "error_logged")