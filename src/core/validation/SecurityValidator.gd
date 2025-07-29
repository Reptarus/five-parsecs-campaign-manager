@tool
extends RefCounted
class_name SecurityValidator

## SecurityValidator: Input sanitization and security validation
## Critical component for preventing injection attacks and data corruption
## All user inputs must pass through appropriate validation methods

# GlobalEnums available as autoload singleton

const ValidationResult = preload("res://src/core/validation/ValidationResult.gd")

## Character name validation with XSS prevention
static func validate_character_name(name: String) -> ValidationResult:
	var result = ValidationResult.new()
	
	# Length validation
	if name.length() < 2:
		result.valid = false
		result.error = "Character name must be at least 2 characters"
		return result
		
	if name.length() > 50:
		result.valid = false
		result.error = "Character name cannot exceed 50 characters"
		return result
	
	# Sanitization and security checks
	var sanitized = name.strip_edges()
	
	# Prevent script injection
	if sanitized.contains("<") or sanitized.contains(">"):
		result.valid = false
		result.error = "Invalid characters in name (< or > not allowed)"
		return result
	
	# Prevent null bytes and control characters
	if sanitized.contains("\0") or _contains_control_chars(sanitized):
		result.valid = false
		result.error = "Invalid control characters in name"
		return result
	
	# Check for potentially dangerous patterns
	var dangerous_patterns = ["script", "javascript", "eval", "function"]
	var lower_name = sanitized.to_lower()
	for pattern in dangerous_patterns:
		if lower_name.contains(pattern):
			result.add_warning("Name contains potentially dangerous pattern: " + pattern)
	
	result.valid = true
	result.sanitized_value = sanitized
	return result

## Campaign name validation
static func validate_campaign_name(name: String) -> ValidationResult:
	var result = ValidationResult.new()
	
	if name.length() < 3:
		result.valid = false
		result.error = "Campaign name must be at least 3 characters"
		return result
		
	if name.length() > 100:
		result.valid = false
		result.error = "Campaign name cannot exceed 100 characters"
		return result
	
	var sanitized = name.strip_edges()
	
	# File system safety - prevent path traversal
	if sanitized.contains("..") or sanitized.contains("/") or sanitized.contains("\\"):
		result.valid = false
		result.error = "Campaign name contains invalid path characters"
		return result
	
	# Prevent reserved names
	var reserved_names = ["con", "prn", "aux", "nul", "com1", "com2", "lpt1", "lpt2"]
	if sanitized.to_lower() in reserved_names:
		result.valid = false
		result.error = "Campaign name cannot be a reserved system name"
		return result
	
	result.valid = true
	result.sanitized_value = sanitized
	return result

## File path validation for save operations
static func validate_save_path(path: String) -> ValidationResult:
	var result = ValidationResult.new()
	
	if path.is_empty():
		result.valid = false
		result.error = "Save path cannot be empty"
		return result
	
	# Prevent path traversal attacks
	if path.contains(".."):
		result.valid = false
		result.error = "Path traversal not allowed"
		return result
	
	# Ensure valid file extension
	if not path.ends_with(".save") and not path.ends_with(".json"):
		result.valid = false
		result.error = "Invalid file extension (must be .save or .json)"
		return result
	
	# Normalize path and validate
	var normalized = path.simplify_path()
	
	result.valid = true
	result.sanitized_value = normalized
	return result

## Numeric input validation with bounds checking
static func validate_numeric_input(value: int, min_val: int, max_val: int, field_name: String) -> ValidationResult:
	var result = ValidationResult.new()
	
	if value < min_val:
		result.valid = false
		result.error = "%s must be at least %d" % [field_name, min_val]
		return result
	
	if value > max_val:
		result.valid = false
		result.error = "%s cannot exceed %d" % [field_name, max_val]
		return result
	
	result.valid = true
	result.sanitized_value = value
	return result

## Text input validation for descriptions and notes
static func validate_text_input(text: String, max_length: int = 1000, field_name: String = "Text") -> ValidationResult:
	var result = ValidationResult.new()
	
	if text.length() > max_length:
		result.valid = false
		result.error = "%s cannot exceed %d characters" % [field_name, max_length]
		return result
	
	var sanitized = text.strip_edges()
	
	# Remove potentially dangerous HTML-like tags
	sanitized = _strip_html_tags(sanitized)
	
	# Check for excessive whitespace
	if sanitized.length() < text.length() * 0.1 and text.length() > 50:
		result.add_warning("Input contains excessive whitespace")
	
	result.valid = true
	result.sanitized_value = sanitized
	return result

## Helper function to detect control characters
static func _contains_control_chars(text: String) -> bool:
	for i in range(text.length()):
		var char_code = text.unicode_at(i)
		# Check for control characters (0-31, excluding tab, newline, carriage return)
		if char_code < 32 and char_code != 9 and char_code != 10 and char_code != 13:
			return true
	return false

## Helper function to strip HTML-like tags
static func _strip_html_tags(text: String) -> String:
	var regex = RegEx.new()
	regex.compile("<[^>]*>")
	return regex.sub(text, "", true)

## Batch validation for multiple inputs
static func validate_batch(validations: Array[Dictionary]) -> Array[ValidationResult]:
	var results: Array[ValidationResult] = []
	
	for validation in validations:
		var type = validation.get("type", "")
		var value = validation.get("value", "")
		var params = validation.get("params", {})
		
		var result: ValidationResult
		match type:
			"character_name":
				result = validate_character_name(value)
			"campaign_name":
				result = validate_campaign_name(value)
			"save_path":
				result = validate_save_path(value)
			"text":
				var max_len = params.get("max_length", 1000)
				var field_name = params.get("field_name", "Text")
				result = validate_text_input(value, max_len, field_name)
			_:
				result = ValidationResult.new(false, "Unknown validation type: " + type)
		
		results.append(result)
	
	return results

## Security audit logging
static func log_security_event(event_type: String, details: String) -> void:
	var timestamp = Time.get_datetime_string_from_system()
	var log_entry = "[SECURITY] %s - %s: %s" % [timestamp, event_type, details]
	print(log_entry)
	
	# In production, this would write to a secure log file
	# For now, we use print to ensure visibility during development