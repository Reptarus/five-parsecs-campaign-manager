@tool
class_name FiveParsecsSecurityValidator
extends RefCounted

## SecurityValidator: Input sanitization and security validation
## Critical component for preventing injection attacks and data corruption
## All user inputs must pass through appropriate validation methods

# GlobalEnums available as autoload singleton

const FiveParsecsValidationResult = preload("res://src/core/validation/ValidationResult.gd")

## Character name validation with XSS prevention
static func validate_character_name(name: String) -> FiveParsecsValidationResult:
	var result := FiveParsecsValidationResult.new()
	
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
	var sanitized := name.strip_edges()
	
	# Prevent script injection
	if sanitized.contains("<") or sanitized.contains(">"):
		result.valid = false
		result.error = "Invalid characters in name (< or > not allowed)"
		return result
	
	# Prevent null bytes and control characters
	if sanitized.contains("\u0000") or _contains_control_chars(sanitized):
		result.valid = false
		result.error = "Invalid control characters in name"
		return result
	
	# Check for potentially dangerous patterns
	var dangerous_patterns := ["script", "javascript", "eval", "function"]
	var lower_name := sanitized.to_lower()
	for pattern in dangerous_patterns:
		if lower_name.contains(pattern):
			result.add_warning("Name contains potentially dangerous pattern: " + pattern)
	
	result.valid = true
	result.sanitized_value = sanitized
	return result

## Campaign name validation
static func validate_campaign_name(name: String) -> FiveParsecsValidationResult:
	var result := FiveParsecsValidationResult.new()
	
	if name.length() < 3:
		result.valid = false
		result.error = "Campaign name must be at least 3 characters"
		return result
		
	if name.length() > 100:
		result.valid = false
		result.error = "Campaign name cannot exceed 100 characters"
		return result
	
	var sanitized := name.strip_edges()
	
	# File system safety - prevent path traversal
	if sanitized.contains("..") or sanitized.contains("/") or sanitized.contains("\\"):
		result.valid = false
		result.error = "Campaign name contains invalid path characters"
		return result
	
	# Prevent reserved names
	var reserved_names := ["con", "prn", "aux", "nul", "com1", "com2", "lpt1", "lpt2"]
	if sanitized.to_lower() in reserved_names:
		result.valid = false
		result.error = "Campaign name cannot be a reserved system name"
		return result
	
	result.valid = true
	result.sanitized_value = sanitized
	return result

## File path validation for save operations
static func validate_save_path(path: String) -> FiveParsecsValidationResult:
	var result := FiveParsecsValidationResult.new()
	
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
	var normalized := path.simplify_path()
	
	result.valid = true
	result.sanitized_value = normalized
	return result

## Numeric input validation with bounds checking
static func validate_numeric_input(value: int, min_val: int, max_val: int, field_name: String) -> FiveParsecsValidationResult:
	var result := FiveParsecsValidationResult.new()
	
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
static func validate_text_input(text: String, max_length: int = 1000, field_name: String = "Text") -> FiveParsecsValidationResult:
	var result := FiveParsecsValidationResult.new()
	
	if text.length() > max_length:
		result.valid = false
		result.error = "%s cannot exceed %d characters" % [field_name, max_length]
		return result
	
	var sanitized := text.strip_edges()
	
	# Remove potentially dangerous HTML-like tags
	sanitized = _strip_html_tags(sanitized)
	
	# Check for excessive whitespace
	if sanitized.length() < text.length() * 0.1 and text.length() > 50:
		result.add_warning("Input contains excessive whitespace")
	
	result.valid = true
	result.sanitized_value = sanitized
	return result

## Generic string input validation - CRITICAL METHOD for ConfigPanel
static func validate_string_input(input: String, max_length: int) -> Dictionary:
	"""Generic string validation with sanitization - returns Dictionary for compatibility"""
	var result = {
		"valid": false,
		"sanitized_value": "",
		"error": ""
	}
	
	if input.is_empty():
		result.error = "Input cannot be empty"
		return result
	
	if input.length() > max_length:
		result.error = "Input exceeds maximum length of %d characters" % max_length
		return result
	
	# Sanitize input - remove potentially harmful characters
	var sanitized = input.strip_edges()
	
	# Allow alphanumeric, spaces, and basic punctuation
	var regex = RegEx.new()
	regex.compile("^[a-zA-Z0-9 _\\-\\.,'!\\(\\)]+$")
	if not regex.search(sanitized):
		result.error = "Input contains invalid characters"
		return result
	
	# Prevent script injection patterns
	var dangerous_patterns = ["<script", "javascript:", "eval(", "function("]
	var lower_input = sanitized.to_lower()
	for pattern in dangerous_patterns:
		if lower_input.contains(pattern):
			result.error = "Input contains potentially dangerous content"
			return result
	
	result.valid = true
	result.sanitized_value = sanitized
	return result

## Helper function to detect control characters
static func _contains_control_chars(text: String) -> bool:
	for i in range(text.length()):
		var char_code := text.unicode_at(i)
		# Check for control characters (0-31, excluding tab, newline, carriage return)
		if char_code < 32 and char_code != 9 and char_code != 10 and char_code != 13:
			return true
	return false

## Helper function to strip HTML-like tags
static func _strip_html_tags(text: String) -> String:
	var regex := RegEx.new()
	regex.compile("<[^>]*>")
	return regex.sub(text, "", true)

## Batch validation for multiple inputs
static func validate_batch(validations: Array[Dictionary]) -> Array[FiveParsecsValidationResult]:
	var results: Array[FiveParsecsValidationResult] = []
	
	for validation in validations:
		var type: String = validation.get("type", "")
		var value: String = validation.get("value", "")
		var params: Dictionary = validation.get("params", {})
		
		var result: FiveParsecsValidationResult
		match type:
			"character_name":
				result = validate_character_name(value)
			"campaign_name":
				result = validate_campaign_name(value)
			"save_path":
				result = validate_save_path(value)
			"text":
				var max_len: int = params.get("max_length", 1000)
				var field_name: String = params.get("field_name", "Text")
				result = validate_text_input(value, max_len, field_name)
			_:
				result = FiveParsecsValidationResult.new(false, "Unknown validation type: " + type)
		
		results.append(result)
	
	return results

## Data structure validation for complex objects
static func validate_data_structure(data: Dictionary, expected_structure: Dictionary = {}) -> FiveParsecsValidationResult:
	"""Validate complex data structures for security and integrity"""
	var result := FiveParsecsValidationResult.new()
	
	# Basic data validation
	if data.is_empty():
		result.valid = false
		result.error = "Data structure cannot be empty"
		return result
	
	# Check for excessive nesting (potential DoS)
	var max_depth = _get_max_nesting_depth(data)
	if max_depth > 20:
		result.valid = false
		result.error = "Data structure nested too deeply (max 20 levels)"
		return result
	
	# Check data size
	var data_string = JSON.stringify(data)
	if data_string.length() > 5 * 1024 * 1024:  # 5MB limit
		result.valid = false
		result.error = "Data structure too large (max 5MB)"
		return result
	
	# Validate against expected structure if provided
	if not expected_structure.is_empty():
		var structure_validation = _validate_against_structure(data, expected_structure)
		if not structure_validation.valid:
			return structure_validation
	
	# Check for suspicious patterns
	var suspicious_check = _check_for_suspicious_patterns(data_string)
	if not suspicious_check.valid:
		return suspicious_check
	
	result.valid = true
	result.sanitized_value = data
	return result

static func _get_max_nesting_depth(obj, current_depth: int = 0) -> int:
	"""Calculate maximum nesting depth safely"""
	if current_depth > 25:  # Prevent stack overflow
		return current_depth
	
	var max_depth = current_depth
	
	if obj is Dictionary:
		for value in obj.values():
			if value is Dictionary or value is Array:
				var child_depth = _get_max_nesting_depth(value, current_depth + 1)
				max_depth = max(max_depth, child_depth)
	elif obj is Array:
		for item in obj:
			if item is Dictionary or item is Array:
				var child_depth = _get_max_nesting_depth(item, current_depth + 1)
				max_depth = max(max_depth, child_depth)
	
	return max_depth

static func _validate_against_structure(data: Dictionary, expected: Dictionary) -> FiveParsecsValidationResult:
	"""Validate data against expected structure"""
	var result := FiveParsecsValidationResult.new()
	
	# Check required fields
	for key in expected.keys():
		if not data.has(key):
			result.valid = false
			result.error = "Missing required field: %s" % key
			return result
	
	result.valid = true
	return result

static func _check_for_suspicious_patterns(data_string: String) -> FiveParsecsValidationResult:
	"""Check for suspicious patterns in data"""
	var result := FiveParsecsValidationResult.new()
	
	var suspicious_patterns = [
		"<script", "javascript:", "eval(", "exec(", "system(", 
		"subprocess", "os.system", "shell_exec", "cmd.exe",
		"powershell", "/bin/sh", "rm -rf", "format c:"
	]
	
	var lower_data = data_string.to_lower()
	for pattern in suspicious_patterns:
		if lower_data.contains(pattern):
			result.valid = false
			result.error = "Suspicious pattern detected: %s" % pattern
			log_security_event("SUSPICIOUS_PATTERN", "Pattern: %s in data" % pattern)
			return result
	
	result.valid = true
	return result

## Enhanced security validation for campaign data
static func validate_campaign_data(data: Dictionary) -> FiveParsecsValidationResult:
	"""Comprehensive validation for campaign data"""
	var result := FiveParsecsValidationResult.new()
	
	# Basic structure validation
	var structure_result = validate_data_structure(data)
	if not structure_result.valid:
		return structure_result
	
	# Campaign-specific validation
	var required_fields = ["campaign_name", "version", "created_at"]
	for field in required_fields:
		if not data.has(field):
			result.valid = false
			result.error = "Missing required campaign field: %s" % field
			return result
	
	# Validate campaign name
	if data.has("campaign_name"):
		var name_result = validate_campaign_name(str(data["campaign_name"]))
		if not name_result.valid:
			return name_result
	
	# Validate version format
	if data.has("version"):
		var version_result = _validate_version_format(str(data["version"]))
		if not version_result.valid:
			return version_result
	
	result.valid = true
	result.sanitized_value = data
	return result

static func _validate_version_format(version: String) -> FiveParsecsValidationResult:
	"""Validate version string format"""
	var result := FiveParsecsValidationResult.new()
	
	var version_regex = RegEx.new()
	version_regex.compile("^\\d+\\.\\d+(\\.\\d+)?$")
	
	if not version_regex.search(version):
		result.valid = false
		result.error = "Invalid version format (expected x.y or x.y.z)"
		return result
	
	result.valid = true
	result.sanitized_value = version
	return result

## Integration with CampaignSecurityManager
static func validate_with_security_context(data: Dictionary, security_level: String = "STANDARD") -> FiveParsecsValidationResult:
	"""Validate data with security context awareness"""
	var result := FiveParsecsValidationResult.new()
	
	# Basic validation first
	var basic_result = validate_data_structure(data)
	if not basic_result.valid:
		return basic_result
	
	# Enhanced validation based on security level
	match security_level.to_upper():
		"PARANOID":
			# Most strict validation
			result = _validate_paranoid_level(data)
		"ENHANCED":
			# Strict validation with audit logging
			result = _validate_enhanced_level(data)
		"STANDARD":
			# Standard validation
			result = _validate_standard_level(data)
		"BASIC":
			# Minimal validation
			result = basic_result
		_:
			result.valid = false
			result.error = "Unknown security level: %s" % security_level
	
	return result

static func _validate_paranoid_level(data: Dictionary) -> FiveParsecsValidationResult:
	"""Paranoid level validation - maximum security"""
	var result := FiveParsecsValidationResult.new()
	
	# Very strict nesting limit
	if _get_max_nesting_depth(data) > 10:
		result.valid = false
		result.error = "Data nesting too deep for paranoid security level (max 10)"
		return result
	
	# Strict size limit
	var data_string = JSON.stringify(data)
	if data_string.length() > 1024 * 1024:  # 1MB limit
		result.valid = false
		result.error = "Data too large for paranoid security level (max 1MB)"
		return result
	
	# Enhanced pattern checking
	var suspicious_check = _check_for_suspicious_patterns(data_string)
	if not suspicious_check.valid:
		return suspicious_check
	
	# Additional checks for paranoid level
	if _contains_binary_data(data_string):
		result.valid = false
		result.error = "Binary data not allowed in paranoid security level"
		return result
	
	result.valid = true
	result.sanitized_value = data
	return result

static func _validate_enhanced_level(data: Dictionary) -> FiveParsecsValidationResult:
	"""Enhanced level validation with audit logging"""
	var result := validate_data_structure(data)
	
	if result.valid:
		log_security_event("DATA_VALIDATION_SUCCESS", "Enhanced validation passed for %d keys" % data.size())
	else:
		log_security_event("DATA_VALIDATION_FAILED", "Enhanced validation failed: %s" % result.error)
	
	return result

static func _validate_standard_level(data: Dictionary) -> FiveParsecsValidationResult:
	"""Standard level validation"""
	return validate_data_structure(data)

static func _contains_binary_data(data_string: String) -> bool:
	"""Check if string contains binary data patterns"""
	# Look for high concentration of non-printable characters
	var non_printable_count = 0
	for i in range(min(1000, data_string.length())):  # Check first 1000 chars
		var char_code = data_string.unicode_at(i)
		if char_code < 32 and char_code != 9 and char_code != 10 and char_code != 13:
			non_printable_count += 1
	
	# If more than 10% non-printable, consider it binary
	return non_printable_count > (min(1000, data_string.length()) * 0.1)

## Security audit logging with enhanced integration
static func log_security_event(event_type: String, details: String) -> void:
	var timestamp := Time.get_datetime_string_from_system()
	var log_entry := "[SECURITY] %s - %s: %s" % [timestamp, event_type, details]
	print(log_entry)
	
	# Integrate with CampaignSecurityManager if available
	var security_manager_class = load("res://src/core/security/CampaignSecurityManager.gd")
	if security_manager_class:
		var security_manager = security_manager_class.get_instance()
		if security_manager:
			security_manager.log_security_violation(event_type, details)