class_name ValidationResult
extends RefCounted

## ValidationResult: Standardized validation response container
## Used across all validation systems to ensure consistent error handling
## Compatible alias for FiveParsecsValidationResult

@export var valid: bool = false
@export var error: String = ""
@export var sanitized_value: Variant = null
@export var warnings: Array[String] = []

func _init(is_valid: bool = false, error_message: String = "", sanitized: Variant = null) -> void:
	valid = is_valid
	error = error_message
	sanitized_value = sanitized

func add_warning(warning: String) -> void:
	"""Add a warning message to the result"""
	warnings.append(warning)

func has_warnings() -> bool:
	"""Check if result has any warnings"""
	return warnings.size() > 0

func get_all_messages() -> String:
	"""Get all error and warning messages combined"""
	var messages = []
	if error:
		messages.append("Error: " + error)
	for warning in warnings:
		messages.append("Warning: " + warning)
	return "\n".join(messages)

## Static factory methods for common cases

static func success(sanitized: Variant = null) -> ValidationResult:
	"""Create a successful validation result"""
	var result = ValidationResult.new(true)
	result.sanitized_value = sanitized
	return result

static func failure(error_message: String) -> ValidationResult:
	"""Create a failed validation result with error message"""
	return ValidationResult.new(false, error_message)

static func with_warnings(is_valid: bool, main_error: String = "", warning_list: Array[String] = []) -> ValidationResult:
	"""Create a validation result with multiple warnings"""
	var result = ValidationResult.new(is_valid, main_error)
	for warning in warning_list:
		result.add_warning(warning)
	return result