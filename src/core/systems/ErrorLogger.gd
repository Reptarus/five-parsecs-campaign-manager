@tool
extends Node
class_name ErrorLogger

## Error logging system for tracking, filtering, and resolving errors
##
## Provides centralized error tracking with categorization, severity levels,
## filtering capabilities, and resolution tracking.

# Error Category Enumeration
enum ErrorCategory {
	VALIDATION, ## Data validation errors
	PERSISTENCE, ## File/data storage errors
	NETWORK, ## Network communication errors
	STATE, ## Game state errors
	UI, ## User interface errors
	SYSTEM ## System-level errors
}

# Error Severity Enumeration
enum ErrorSeverity {
	INFO, ## Informational messages
	WARNING, ## Warnings that don't prevent operation
	ERROR, ## Errors that affect functionality
	CRITICAL ## Critical errors that prevent operation
}

# Signals with type annotations
signal error_logged(error_data: Dictionary)
signal error_resolved(error_id: String)
signal error_cleared()

# Error tracking properties with type annotations
var _active_errors: Dictionary = {}
var _error_counter: int = 0
var error_history: Array[Dictionary] = []
var _max_history_size: int = 100

## Initialize the logger
func _ready() -> void:
	# Nothing to initialize
	pass

## Log an error
## @param message The error message
## @param category The error category
## @param severity The error severity
## @param context Additional context information
## @return bool Whether the error was logged successfully
func log_error(message: String, category: ErrorCategory = ErrorCategory.SYSTEM,
			  severity: ErrorSeverity = ErrorSeverity.ERROR,
			  context: Dictionary = {}) -> bool:
	if message.is_empty():
		push_error("Cannot log empty error message")
		return false
		
	# Validate category and severity
	if category < 0 or category >= ErrorCategory.size():
		push_warning("Invalid error category: " + str(category) + ". Using SYSTEM instead.")
		category = ErrorCategory.SYSTEM
		
	if severity < 0 or severity >= ErrorSeverity.size():
		push_warning("Invalid error severity: " + str(severity) + ". Using ERROR instead.")
		severity = ErrorSeverity.ERROR
		
	var error_id: String = _generate_error_id(message)
	var timestamp: String = Time.get_datetime_string_from_system()
	var stack_trace: Array = get_stack()
	
	# Create error data
	var error_data: Dictionary = {
		"id": error_id,
		"message": message,
		"category": category,
		"severity": severity,
		"timestamp": timestamp,
		"context": context.duplicate(),
		"stack_trace": stack_trace,
		"resolved": false,
		"resolution_timestamp": "",
		"resolution_notes": ""
	}
	
	# Store the error
	_active_errors[error_id] = error_data
	
	# Add to history
	error_history.push_front(error_data.duplicate())
	
	# Trim history if needed
	if error_history.size() > _max_history_size:
		error_history.resize(_max_history_size)
	
	# Emit signal
	error_logged.emit(error_data)
	
	# Also print to console for debugging
	_print_error(error_data)
	
	return true

## Resolve an error
## @param error_id The error ID
## @param resolution_notes Notes about the resolution
## @return bool Whether the error was resolved successfully
func resolve_error(error_id: String, resolution_notes: String = "") -> bool:
	if not _active_errors.has(error_id):
		push_warning("Attempted to resolve non-existent error: " + error_id)
		return false
		
	var error_data: Dictionary = _active_errors[error_id]
	error_data.resolved = true
	error_data.resolution_timestamp = Time.get_datetime_string_from_system()
	error_data.resolution_notes = resolution_notes
	
	# Update history
	for i in range(error_history.size()):
		if error_history[i].id == error_id:
			error_history[i].resolved = true
			error_history[i].resolution_timestamp = error_data.resolution_timestamp
			error_history[i].resolution_notes = error_data.resolution_notes
			break
	
	# Emit signal
	error_resolved.emit(error_id)
	
	return true

## Clear all resolved errors
## @return int Number of errors cleared
func clear_resolved_errors() -> int:
	var cleared_count: int = 0
	var keys_to_remove: Array = []
	
	# Find resolved errors
	for error_id in _active_errors:
		if _active_errors[error_id].resolved:
			keys_to_remove.append(error_id)
	
	# Remove resolved errors
	for error_id in keys_to_remove:
		_active_errors.erase(error_id)
		cleared_count += 1
	
	# Emit signal if any errors were cleared
	if cleared_count > 0:
		error_cleared.emit()
	
	return cleared_count

## Clear all errors
## @return int Number of errors cleared
func clear_all_errors() -> int:
	var count: int = _active_errors.size()
	_active_errors.clear()
	
	# Emit signal if any errors were cleared
	if count > 0:
		error_cleared.emit()
	
	return count

## Get all active errors
## @return Array of active errors
func get_active_errors() -> Array:
	var errors: Array = []
	for error_id in _active_errors:
		errors.append(_active_errors[error_id])
	return errors

## Generate a unique error ID
## @param message The error message
## @return String The generated error ID
func _generate_error_id(message: String) -> String:
	_error_counter += 1
	var base_id: String = message.to_lower().strip_edges().replace(" ", "_")
	if base_id.length() > 20:
		base_id = base_id.substr(0, 20)
	return base_id + "_" + str(_error_counter)

## Print error to console
## @param error_data The error data
func _print_error(error_data: Dictionary) -> void:
	var category_str: String = ErrorCategory.keys()[error_data.category]
	var severity_str: String = ErrorSeverity.keys()[error_data.severity]
	
	var message: String = "[%s] [%s] [%s] %s" % [
		error_data.timestamp,
		category_str,
		severity_str,
		error_data.message
	]
	
	match error_data.severity:
		ErrorSeverity.INFO:
			print(message)
		ErrorSeverity.WARNING:
			push_warning(message)
		ErrorSeverity.ERROR, ErrorSeverity.CRITICAL:
			push_error(message)

## Log an error with an error code
## @param message The error message
## @param error_code The error code
## @param source The source of the error
## @return bool Whether the error was logged successfully
func log_error_with_code(message: String, error_code: int, source: String = "") -> bool:
	var context: Dictionary = {"error_code": error_code}
	if not source.is_empty():
		context["source"] = source
		
	var category: ErrorCategory = ErrorCategory.STATE
	var severity: ErrorSeverity = ErrorSeverity.ERROR
	
	# Adjust severity based on error code
	if error_code == ERR_FILE_NOT_FOUND:
		category = ErrorCategory.PERSISTENCE
	elif error_code == ERR_INVALID_DATA:
		category = ErrorCategory.VALIDATION
	
	return log_error(message, category, severity, context)

## Log a simple error with just a message and source
## @param message The error message
## @param source The source of the error
## @return bool Whether the error was logged successfully
func log_error_simple(message: String, source: String = "") -> bool:
	var context: Dictionary = {}
	if not source.is_empty():
		context["source"] = source
		
	return log_error(message, ErrorCategory.STATE, ErrorSeverity.ERROR, context)

## Get the error history
## @return The error history array
func get_error_history() -> Array[Dictionary]:
	return error_history

## Clear the error history
## @return bool Whether the history was cleared
func clear_error_history() -> bool:
	error_history.clear()
	return true

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
	return get_critical_errors().size() > 0

## Set the maximum history size
## @param size The maximum history size
## @return bool Whether the size was set
func set_max_history_size(size: int) -> bool:
	if size <= 0:
		push_warning("Invalid max history size: " + str(size))
		return false
		
	_max_history_size = size
	
	# Trim history if needed
	if error_history.size() > _max_history_size:
		error_history.resize(_max_history_size)
		
	return true

## Get the maximum history size
## @return The maximum history size
func get_max_history_size() -> int:
	return _max_history_size
