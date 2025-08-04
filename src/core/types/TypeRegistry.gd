# Five Parsecs Campaign Manager - Type Registry
# Central type definitions for consistent typing across the project

class_name FPCM_TypeRegistry
extends RefCounted

# === Core System Types ===
# Note: GDScript doesn't have typedef, but we can define type aliases using class_name

# === Error Handling Types ===
enum ErrorCategory {SYSTEM, VALIDATION, NETWORK, USER_INPUT}
enum ErrorSeverity {INFO, WARNING, ERROR, CRITICAL}

# === Validation Result Class ===
class ValidationResult extends RefCounted:
	var is_valid: bool = false
	var errors: Array[String] = []
	var sanitized_value: Variant = null
	var error: String = ""
	
	static func success(value: Variant = null) -> ValidationResult:
		var result := ValidationResult.new()
		result.is_valid = true
		result.sanitized_value = value
		return result
		
	static func failure(error_messages: Array[String]) -> ValidationResult:
		var result := ValidationResult.new()
		result.is_valid = false
		result.errors = error_messages
		if error_messages.size() > 0:
			result.error = error_messages[0]
		return result
	
	static func single_error(error_message: String) -> ValidationResult:
		var result := ValidationResult.new()
		result.is_valid = false
		result.errors = [error_message]
		result.error = error_message
		return result

# === Game Error Class ===
class GameError extends RefCounted:
	var id: String
	var timestamp: float
	var category: ErrorCategory
	var severity: ErrorSeverity
	var message: String
	var context: Dictionary = {}
	var resolved: bool = false
	
	func _init(error_id: String = "", error_message: String = "", error_category: ErrorCategory = ErrorCategory.SYSTEM, error_severity: ErrorSeverity = ErrorSeverity.ERROR):
		id = error_id
		message = error_message
		category = error_category
		severity = error_severity
		timestamp = Time.get_unix_time_from_system()

# === Static Type Helper Methods ===
static func create_campaign_state_data() -> Dictionary:
	return {
		"config": {},
		"crew": {},
		"captain": {},
		"ship": {},
		"equipment": {},
		"world": {},
		"metadata": {}
	}

static func create_character_data() -> Dictionary:
	return {
		"name": "",
		"background": 0,
		"motivation": 0,
		"stats": {},
		"equipment": [],
		"traits": []
	}

static func create_mission_data() -> Dictionary:
	return {
		"id": "",
		"type": 0,
		"objectives": [],
		"rewards": {},
		"requirements": {}
	}

static func create_terrain_data() -> Dictionary:
	return {
		"type": "",
		"features": [],
		"hazards": [],
		"size": Vector2i.ZERO
	}

static func create_battle_data() -> Dictionary:
	return {
		"participants": [],
		"terrain": {},
		"conditions": [],
		"turn": 0
	}

# === Validation Helpers ===
static func validate_campaign_state_data(data: Dictionary) -> ValidationResult:
	var required_keys = ["config", "crew", "captain", "ship", "equipment", "world", "metadata"]
	for key in required_keys:
		if not data.has(key):
			return ValidationResult.single_error("Missing required key: " + key)
	return ValidationResult.success(data)

static func validate_character_data(data: Dictionary) -> ValidationResult:
	var required_keys = ["name", "background", "motivation", "stats"]
	for key in required_keys:
		if not data.has(key):
			return ValidationResult.single_error("Missing required character key: " + key)
	
	if data.get("name", "").strip_edges().is_empty():
		return ValidationResult.single_error("Character name cannot be empty")
	
	return ValidationResult.success(data)

static func validate_mission_data(data: Dictionary) -> ValidationResult:
	var required_keys = ["id", "type", "objectives"]
	for key in required_keys:
		if not data.has(key):
			return ValidationResult.single_error("Missing required mission key: " + key)
	
	if data.get("id", "").strip_edges().is_empty():
		return ValidationResult.single_error("Mission ID cannot be empty")
	
	return ValidationResult.success(data)