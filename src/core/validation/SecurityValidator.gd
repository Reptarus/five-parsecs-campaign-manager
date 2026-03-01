class_name FiveParsecsSecurityValidator
extends RefCounted

## FiveParsecsSecurityValidator: Input validation and sanitization for Five Parsecs
## Provides security-focused validation patterns for campaign manager
## Prevents injection attacks and ensures data integrity

static func validate_character_name(name: String) -> ValidationResult:
	## Validate character name with Five Parsecs specific rules
	var result = ValidationResult.new()
	
	if name.is_empty():
		result.valid = false
		result.error = "Character name cannot be empty"
		return result
	
	# Check length constraints (2-50 characters)
	if name.length() < 2:
		result.valid = false
		result.error = "Character name must be at least 2 characters long"
		return result
	
	if name.length() > 50:
		result.valid = false
		result.error = "Character name cannot exceed 50 characters"
		return result
	
	# Basic sanitization
	var sanitized = name.strip_edges()
	
	# Check for potentially dangerous patterns
	var dangerous_patterns = ["<script", "javascript:", "data:", "vbscript:", "onload=", "onerror="]
	var lower_input = sanitized.to_lower()
	
	for pattern in dangerous_patterns:
		if lower_input.contains(pattern):
			result.valid = false
			result.error = "Character name contains potentially unsafe content"
			return result
	
	# Validate character set (allow letters, numbers, spaces, hyphens, apostrophes)
	var allowed_regex = RegEx.new()
	allowed_regex.compile("^[a-zA-Z0-9\\s\\-']+$")
	
	if not allowed_regex.search(sanitized):
		result.valid = false
		result.error = "Character name contains invalid characters. Only letters, numbers, spaces, hyphens, and apostrophes allowed"
		return result
	
	result.valid = true
	result.sanitized_value = sanitized
	
	if sanitized != name:
		result.add_warning("Character name was trimmed")
	
	return result

static func validate_string_input(input: String, max_length: int = 100, allow_special_chars: bool = false) -> ValidationResult:
	## Validate and sanitize string input with security checks
	var result = ValidationResult.new()
	
	if input.is_empty():
		result.valid = false
		result.error = "Input cannot be empty"
		return result
	
	# Check length constraints
	if input.length() > max_length:
		result.valid = false
		result.error = "Input exceeds maximum length of %d characters" % max_length
		return result
	
	# Basic sanitization
	var sanitized = input.strip_edges()
	
	# Check for potentially dangerous patterns
	var dangerous_patterns = ["<script", "javascript:", "data:", "vbscript:", "onload=", "onerror="]
	var lower_input = sanitized.to_lower()
	
	for pattern in dangerous_patterns:
		if lower_input.contains(pattern):
			result.valid = false
			result.error = "Input contains potentially unsafe content"
			return result
	
	# Validate character set
	if not allow_special_chars:
		var allowed_regex = RegEx.new()
		allowed_regex.compile("^[a-zA-Z0-9\\s\\-_\\.\\(\\)]+$")
		
		if not allowed_regex.search(sanitized):
			result.valid = false
			result.error = "Input contains invalid characters. Only letters, numbers, spaces, and basic punctuation allowed"
			return result
	
	result.valid = true
	result.sanitized_value = sanitized
	
	if sanitized != input:
		result.add_warning("Input was trimmed")
	
	return result

static func validate_numeric_input(input: Variant, min_value: float = -INF, max_value: float = INF) -> ValidationResult:
	## Validate numeric input with range checking
	var result = ValidationResult.new()
	
	var numeric_value: float
	
	if input is String:
		if (input as String).is_empty():
			result.valid = false
			result.error = "Numeric input cannot be empty"
			return result
		
		if not (input as String).is_valid_float():
			result.valid = false
			result.error = "Input must be a valid number"
			return result
		
		numeric_value = (input as String).to_float()
	elif input is int or input is float:
		numeric_value = input as float
	else:
		result.valid = false
		result.error = "Input must be a number"
		return result
	
	if numeric_value < min_value:
		result.valid = false
		result.error = "Value must be at least %s" % str(min_value)
		return result
	
	if numeric_value > max_value:
		result.valid = false
		result.error = "Value cannot exceed %s" % str(max_value)
		return result
	
	result.valid = true
	result.sanitized_value = numeric_value
	return result

static func validate_campaign_data(data: Dictionary) -> ValidationResult:
	## Validate complete campaign data structure
	var result = ValidationResult.new()
	var errors: Array[String] = []
	
	# Required fields
	var required_fields = ["name", "difficulty", "victory_conditions"]
	for field in required_fields:
		if not data.has(field):
			errors.append("Missing required field: %s" % field)
		elif _is_empty_value(data[field]):
			errors.append("Field '%s' cannot be empty" % field)
	
	# Validate campaign name
	if data.has("name"):
		var name_validation = validate_string_input(data["name"], 50)
		if not name_validation.valid:
			errors.append("Campaign name: %s" % name_validation.error)
	
	# Validate difficulty
	if data.has("difficulty"):
		var difficulty_validation = validate_numeric_input(data["difficulty"], 1, 5)
		if not difficulty_validation.valid:
			errors.append("Difficulty: %s" % difficulty_validation.error)
	
	if errors.is_empty():
		result.valid = true
	else:
		result.valid = false
		result.error = errors[0]
		for i in range(1, errors.size()):
			result.add_warning(errors[i])
	
	return result

static func validate_character_data(data: Dictionary) -> ValidationResult:
	## Validate character data structure
	var result = ValidationResult.new()
	var errors: Array[String] = []
	
	# Required character fields
	var required_fields = ["character_name", "combat", "toughness", "savvy", "tech", "speed", "luck"]
	for field in required_fields:
		if not data.has(field):
			errors.append("Missing required character field: %s" % field)
	
	# Validate character name
	if data.has("character_name"):
		var name_validation = validate_string_input(data["character_name"], 30)
		if not name_validation.valid:
			errors.append("Character name: %s" % name_validation.error)
	
	# Validate stats (should be 1-6 for Five Parsecs)
	var stat_fields = ["combat", "toughness", "savvy", "tech", "speed", "luck"]
	for stat in stat_fields:
		if data.has(stat):
			var stat_validation = validate_numeric_input(data[stat], 1, 6)
			if not stat_validation.valid:
				errors.append("%s stat: %s" % [stat.capitalize(), stat_validation.error])
	
	if errors.is_empty():
		result.valid = true
	else:
		result.valid = false
		result.error = errors[0]
		for i in range(1, errors.size()):
			result.add_warning(errors[i])
	
	return result

static func sanitize_file_path(path: String) -> ValidationResult:
	## Validate and sanitize file paths to prevent directory traversal
	var result = ValidationResult.new()
	
	if path.is_empty():
		result.valid = false
		result.error = "File path cannot be empty"
		return result
	
	# Check for directory traversal attempts
	if path.contains("..") or path.contains("~"):
		result.valid = false
		result.error = "Invalid file path: directory traversal not allowed"
		return result
	
	# Sanitize path
	var sanitized = path.strip_edges()
	sanitized = sanitized.replace("\\", "/")  # Normalize path separators
	
	# Validate file extension (if present)
	if sanitized.contains("."):
		var extension = sanitized.get_extension().to_lower()
		var allowed_extensions = ["json", "tres", "dat", "save"]
		if extension and not extension in allowed_extensions:
			result.add_warning("Unusual file extension: %s" % extension)
	
	result.valid = true
	result.sanitized_value = sanitized
	return result

## Private helper methods

static func _is_empty_value(value: Variant) -> bool:
	## Check if a value is considered empty
	if value == null:
		return true
	
	match typeof(value):
		TYPE_STRING:
			return (value as String).is_empty()
		TYPE_ARRAY:
			return (value as Array).is_empty()
		TYPE_DICTIONARY:
			return (value as Dictionary).is_empty()
		_:
			return false

static func log_security_event(event_type: String, message: String, severity: String = "INFO") -> void:
	## Log security-related events for audit trail
	var timestamp = Time.get_datetime_string_from_system()
	var log_entry = "[%s] SECURITY [%s] %s: %s" % [timestamp, severity, event_type, message]
	
	# Print to console for now - could be extended to write to file or send to monitoring
	print(log_entry)
	
	# In debug mode, also push as warning for visibility
	if OS.is_debug_build() and severity in ["WARNING", "ERROR"]:
		push_warning(log_entry)

static func validate_save_path(path: String) -> ValidationResult:
	## Validate save file path for security and correctness
	var result = ValidationResult.new()
	
	if path.is_empty():
		result.valid = false
		result.error = "Save path cannot be empty"
		return result
	
	# Check for directory traversal attempts
	if path.contains("..") or path.contains("~"):
		result.valid = false
		result.error = "Invalid save path: directory traversal not allowed"
		return result
	
	# Ensure path has proper extension
	var valid_extensions = [".save", ".json", ".tres", ".res"]
	var has_valid_extension = false
	for ext in valid_extensions:
		if path.ends_with(ext):
			has_valid_extension = true
			break
	
	if not has_valid_extension:
		result.valid = false
		result.error = "Save file must have a valid extension (.save, .json, .tres, or .res)"
		return result
	
	# Sanitize path
	var sanitized = path.strip_edges()
	sanitized = sanitized.replace("\\", "/")  # Normalize path separators
	
	# Ensure path is within user data directory
	if not sanitized.begins_with("user://") and not sanitized.begins_with("res://"):
		# Convert to user:// path if it's a relative path
		if not sanitized.begins_with("/") and not sanitized.contains(":"):
			sanitized = "user://" + sanitized
		else:
			result.add_warning("Save path should use user:// or res:// prefix")
	
	result.valid = true
	result.sanitized_value = sanitized
	return result

static func validate_campaign_name(name: String) -> ValidationResult:
	## Validate campaign name for proper formatting and content
	var result = ValidationResult.new()
	
	if name.is_empty():
		result.valid = false
		result.error = "Campaign name cannot be empty"
		return result
	
	# Check length
	var min_length = 3
	var max_length = 50
	if name.length() < min_length:
		result.valid = false
		result.error = "Campaign name must be at least %d characters" % min_length
		return result
	
	if name.length() > max_length:
		result.valid = false
		result.error = "Campaign name cannot exceed %d characters" % max_length
		return result
	
	# Check for invalid characters (only allow alphanumeric, spaces, and basic punctuation)
	var allowed_regex = RegEx.new()
	allowed_regex.compile("^[a-zA-Z0-9\\s\\-_\\.\\(\\)\\[\\]]+$")
	
	if not allowed_regex.search(name):
		result.valid = false
		result.error = "Campaign name contains invalid characters"
		return result
	
	# Check for problematic patterns
	var dangerous_patterns = ["<script", "javascript:", "../", "\\\\", "//"]
	var lower_name = name.to_lower()
	
	for pattern in dangerous_patterns:
		if lower_name.contains(pattern):
			result.valid = false
			result.error = "Campaign name contains potentially unsafe content"
			return result
	
	# Sanitize by trimming whitespace
	var sanitized = name.strip_edges()
	
	result.valid = true
	result.sanitized_value = sanitized
	
	if sanitized != name:
		result.add_warning("Campaign name was trimmed")
	
	return result