extends Node

const ErrorLogger = preload("res://src/core/systems/ErrorLogger.gd")

var error_logger: ErrorLogger

func _init() -> void:
	error_logger = ErrorLogger.new()

func _exit_tree() -> void:
	if is_instance_valid(error_logger):
		error_logger.free()

func test_error_logger_initialization() -> void:
	assert(error_logger != null, "ErrorLogger should be instantiated")
	assert(error_logger.error_history.size() == 0, "Error history should start empty")

func test_log_error() -> void:
	var test_message = "Test error message"
	var test_category = ErrorLogger.ErrorCategory.VALIDATION
	var test_severity = ErrorLogger.ErrorSeverity.ERROR
	var test_context = {"test": "context"}
	
	error_logger.log_error(test_message, test_category, test_severity, test_context)
	
	assert(error_logger.error_history.size() == 1, "Should have one error in history")
	var logged_error = error_logger.error_history[0]
	assert(logged_error.message == test_message, "Error message should match")
	assert(logged_error.category == test_category, "Error category should match")
	assert(logged_error.severity == test_severity, "Error severity should match")
	assert(logged_error.context == test_context, "Error context should match")

func test_error_history_limit() -> void:
	for i in range(ErrorLogger.MAX_ERROR_HISTORY + 10):
		error_logger.log_error(
			"Test error %d" % i,
			ErrorLogger.ErrorCategory.VALIDATION,
			ErrorLogger.ErrorSeverity.INFO
		)
	
	assert(
		error_logger.error_history.size() == ErrorLogger.MAX_ERROR_HISTORY,
		"Error history should be limited to MAX_ERROR_HISTORY"
	)

func test_clear_error_history() -> void:
	error_logger.log_error(
		"Test error",
		ErrorLogger.ErrorCategory.VALIDATION,
		ErrorLogger.ErrorSeverity.INFO
	)
	
	assert(error_logger.error_history.size() == 1)
	error_logger.clear_error_history()
	assert(error_logger.error_history.size() == 0)

func test_error_logged_signal() -> void:
	var signal_received = false
	var received_error = null
	
	error_logger.error_logged.connect(
		func(error_data):
			signal_received = true
			received_error = error_data
	)
	
	var test_message = "Test error message"
	var test_category = ErrorLogger.ErrorCategory.VALIDATION
	var test_severity = ErrorLogger.ErrorSeverity.ERROR
	var test_context = {"test": "context"}
	
	error_logger.log_error(test_message, test_category, test_severity, test_context)
	
	assert(signal_received, "Signal should be emitted")
	assert(received_error != null, "Signal data should not be null")
	assert(received_error.message == test_message, "Signal data should contain correct message")