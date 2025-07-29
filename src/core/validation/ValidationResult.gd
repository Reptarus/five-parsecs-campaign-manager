@tool
extends RefCounted
class_name ValidationResult

## ValidationResult: Standardized validation response container
## Used across all validation systems to ensure consistent error handling

@export var valid: bool = false
@export var error: String = ""
@export var sanitized_value: Variant = null
@export var warnings: Array[String] = []

func _init(is_valid: bool = false, error_message: String = "", sanitized: Variant = null) -> void:
	valid = is_valid
	error = error_message
	sanitized_value = sanitized

func add_warning(warning: String) -> void:
	warnings.append(warning)

func has_warnings() -> bool:
	return warnings.size() > 0

func get_all_messages() -> String:
	var messages = []
	if error:
		messages.append("Error: " + error)
	for warning in warnings:
		messages.append("Warning: " + warning)
	return "\n".join(messages)