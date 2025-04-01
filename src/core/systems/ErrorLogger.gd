@tool
extends Resource

signal error_logged(error: Dictionary)

## Error categories for classification
enum ErrorCategory {
	VALIDATION,
	STATE,
	PHASE_TRANSITION,
	COMBAT,
	NETWORK,
	PERSISTENCE,
	RESOURCE,
	TEST
}

## Error severity levels
enum ErrorSeverity {
	INFO,
	WARNING,
	ERROR,
	CRITICAL
}

## Error history array with typed elements
var error_history: Array[Dictionary] = []
const MAX_ERROR_HISTORY: int = 100

## Initialize the ErrorLogger with a valid resource path for testing
func _init() -> void:
	# Ensure resource has valid path for serialization
	if resource_path.is_empty():
		var timestamp = Time.get_unix_time_from_system()
		var random_suffix = randi() % 1000000 # Add a random number for uniqueness
		resource_path = "res://tests/generated/error_logger_%d_%d.tres" % [timestamp, random_suffix]

## Log an error with category and severity
## @param message The error message
## @param category The error category
## @param severity The error severity
## @param context Additional contextual information
func log_error(message: String, category: ErrorCategory, severity: ErrorSeverity, context: Dictionary = {}) -> void:
	var error = {
		"message": message,
		"category": category,
		"severity": severity,
		"context": context.duplicate(), # Duplicate to prevent reference issues
		"timestamp": Time.get_unix_time_from_system()
	}
	
	error_history.append(error)
	
	# Trim history if needed
	if error_history.size() > MAX_ERROR_HISTORY:
		error_history = error_history.slice(-MAX_ERROR_HISTORY)
	
	error_logged.emit(error)
	
	# Print critical errors to the console for easier debugging
	if severity == ErrorSeverity.CRITICAL:
		push_error("CRITICAL: " + message)
	elif severity == ErrorSeverity.ERROR:
		push_error(message)
	elif severity == ErrorSeverity.WARNING:
		push_warning(message)

## Log an error with error code
## @param message The error message
## @param error_code The error code
## @param source The source of the error
func log_error_with_code(message: String, error_code: int, source: String = "") -> void:
	var context = {"error_code": error_code}
	if not source.is_empty():
		context["source"] = source
		
	var category = ErrorCategory.STATE
	var severity = ErrorSeverity.ERROR
	
	# Adjust severity based on error code
	if error_code == ERR_FILE_NOT_FOUND:
		category = ErrorCategory.PERSISTENCE
	elif error_code == ERR_INVALID_DATA:
		category = ErrorCategory.VALIDATION
	
	log_error(message, category, severity, context)

## Log a simple error with just a message and source
## @param message The error message
## @param source The source of the error
func log_error_simple(message: String, source: String = "") -> void:
	var context = {}
	if not source.is_empty():
		context["source"] = source
		
	log_error(message, ErrorCategory.STATE, ErrorSeverity.ERROR, context)

## Get the error history
## @return The error history array
func get_error_history() -> Array[Dictionary]:
	return error_history

## Clear the error history
func clear_error_history() -> void:
	error_history.clear()

## Get errors by category
## @param category The category to filter by
## @return Array of errors in the specified category
func get_errors_by_category(category: ErrorCategory) -> Array[Dictionary]:
	var filtered: Array[Dictionary] = []
	for error in error_history:
		if error.category == category:
			filtered.append(error)
	return filtered

## Get errors by severity
## @param severity The severity to filter by
## @return Array of errors with the specified severity
func get_errors_by_severity(severity: ErrorSeverity) -> Array[Dictionary]:
	var filtered: Array[Dictionary] = []
	for error in error_history:
		if error.severity == severity:
			filtered.append(error)
	return filtered

## Get critical errors
## @return Array of critical errors
func get_critical_errors() -> Array[Dictionary]:
	return get_errors_by_severity(ErrorSeverity.CRITICAL)

## Check if any critical errors exist
## @return Whether any critical errors exist
func has_critical_errors() -> bool:
	for error in error_history:
		if error.severity == ErrorSeverity.CRITICAL:
			return true
	return false
