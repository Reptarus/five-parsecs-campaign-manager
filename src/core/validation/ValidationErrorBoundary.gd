class_name ValidationErrorBoundary
extends RefCounted

## Validation Error Boundary for UI-Backend Integration
## Provides safe execution of UI-backend integration calls with comprehensive error handling
## Extends the Universal Error Boundary pattern for validation-specific use cases

# Removed UIBackendIntegrationValidator dependency to avoid circular reference

## Error handling modes for validation operations
enum ValidationErrorMode {
	SILENT,        # Log errors but don't interrupt flow
	GRACEFUL,      # Show user-friendly messages and continue with fallbacks
	STRICT,        # Stop execution on any validation error
	DEVELOPMENT    # Show detailed error information for debugging
}

## Error severity levels for validation
enum ValidationErrorSeverity {
	LOW,           # Non-critical issues that don't affect functionality
	MEDIUM,        # Issues that may affect some features but allow continued operation
	HIGH,          # Critical issues that require user attention
	CRITICAL       # System-breaking issues that require immediate action
}

## Validation error result
class ValidationErrorResult:
	var success: bool = false
	var error_message: String = ""
	var error_code: String = ""
	var severity: ValidationErrorSeverity = ValidationErrorSeverity.LOW
	var fallback_data: Variant = null
	var performance_data: Dictionary = {}
	var context: Dictionary = {}
	
	func _init(
		p_success: bool = false,
		p_error_message: String = "",
		p_error_code: String = "",
		p_severity: ValidationErrorSeverity = ValidationErrorSeverity.LOW
	) -> void:
		success = p_success
		error_message = p_error_message
		error_code = p_error_code
		severity = p_severity

var error_mode: ValidationErrorMode = ValidationErrorMode.GRACEFUL
var error_log: Array[ValidationErrorResult] = []

## Safe execution of UI-backend integration calls
static func safe_backend_call(
	target_object: Object,
	method_name: String,
	args: Array = [],
	fallback_value: Variant = null,
	timeout_ms: int = 5000,
	error_mode: ValidationErrorMode = ValidationErrorMode.GRACEFUL
) -> ValidationErrorResult:
	
	var result = ValidationErrorResult.new(true)
	var start_time = Time.get_ticks_msec()
	
	print("ValidationErrorBoundary: Executing safe backend call - %s.%s()" % [target_object.get_class() if target_object else "null", method_name])
	
	# Validate inputs
	if not target_object:
		result.success = false
		result.error_message = "Target object is null"
		result.error_code = "NULL_OBJECT"
		result.severity = ValidationErrorSeverity.HIGH
		result.fallback_data = fallback_value
		_handle_validation_error(result, error_mode)
		return result
	
	# Check method availability
	if not target_object.has_method(method_name):
		result.success = false
		result.error_message = "Method '%s' not found on object '%s'" % [method_name, target_object.get_class()]
		result.error_code = "METHOD_NOT_FOUND"
		result.severity = ValidationErrorSeverity.MEDIUM
		result.fallback_data = fallback_value
		_handle_validation_error(result, error_mode)
		return result
	
	# Execute method with error protection (GDScript doesn't have try/catch)
	var call_result = target_object.callv(method_name, args)
	var end_time = Time.get_ticks_msec()
	var duration = end_time - start_time
	
	# Check for timeout
	if duration > timeout_ms:
		result.success = false
		result.error_message = "Backend call timeout after %dms (limit: %dms)" % [duration, timeout_ms]
		result.error_code = "TIMEOUT"
		result.severity = ValidationErrorSeverity.HIGH
		result.fallback_data = fallback_value
	else:
		result.success = true
		result.fallback_data = call_result
		result.performance_data["duration_ms"] = duration
		print("ValidationErrorBoundary: Backend call successful - %dms" % duration)
	
	if not result.success:
		_handle_validation_error(result, error_mode)
	
	return result

## Safe crew generation with backend integration
static func safe_crew_generation(
	crew_size: int,
	character_creator_class: Object = null,
	error_mode: ValidationErrorMode = ValidationErrorMode.GRACEFUL
) -> ValidationErrorResult:
	
	print("ValidationErrorBoundary: Starting safe crew generation for %d members" % crew_size)
	
	var result = ValidationErrorResult.new(true)
	var start_time = Time.get_ticks_msec()
	
	# Load SimpleCharacterCreator if not provided
	var SimpleCharacterCreator = character_creator_class
	if not SimpleCharacterCreator:
		SimpleCharacterCreator = load("res://src/core/character/Generation/SimpleCharacterCreator.gd")
		if not SimpleCharacterCreator:
			result.success = false
			result.error_message = "SimpleCharacterCreator class not available"
			result.error_code = "CLASS_NOT_FOUND"
			result.severity = ValidationErrorSeverity.HIGH
			result.fallback_data = []
			_handle_validation_error(result, error_mode)
			return result
	
	var generated_crew: Array = []
	var errors: Array[String] = []
	
	# Generate each crew member with individual error handling
	for i in range(crew_size):
		var character_result = safe_backend_call(
			SimpleCharacterCreator,
			"create_character",
			[],
			null,
			1000,  # 1 second timeout per character
			error_mode
		)
		
		if character_result.success and character_result.fallback_data:
			var character = character_result.fallback_data
			# Mark first character as captain
			if i == 0:
				if character.has_method("set"):
					character.set("is_captain", true)
				elif "is_captain" in character:
					character.is_captain = true
			generated_crew.append(character)
		else:
			errors.append("Failed to generate character %d: %s" % [i + 1, character_result.error_message])
	
	var end_time = Time.get_ticks_msec()
	result.performance_data["duration_ms"] = end_time - start_time
	result.performance_data["crew_generated"] = generated_crew.size()
	result.performance_data["errors"] = errors.size()
	
	if generated_crew.size() == crew_size:
		result.success = true
		result.fallback_data = generated_crew
		print("ValidationErrorBoundary: Successfully generated %d crew members" % generated_crew.size())
	else:
		result.success = false
		result.error_message = "Only generated %d/%d crew members. Errors: %s" % [generated_crew.size(), crew_size, ", ".join(errors)]
		result.error_code = "PARTIAL_GENERATION"
		result.severity = ValidationErrorSeverity.MEDIUM
		result.fallback_data = generated_crew  # Return partial crew
		_handle_validation_error(result, error_mode)
	
	return result

## Safe equipment generation with backend integration
static func safe_equipment_generation(
	crew_data: Array,
	equipment_generator_class: Object = null,
	error_mode: ValidationErrorMode = ValidationErrorMode.GRACEFUL
) -> ValidationErrorResult:
	
	print("ValidationErrorBoundary: Starting safe equipment generation for %d crew members" % crew_data.size())
	
	var result = ValidationErrorResult.new(true)
	var start_time = Time.get_ticks_msec()
	
	# Load StartingEquipmentGenerator if not provided
	var StartingEquipmentGenerator = equipment_generator_class
	if not StartingEquipmentGenerator:
		StartingEquipmentGenerator = load("res://src/core/character/Equipment/StartingEquipmentGenerator.gd")
		if not StartingEquipmentGenerator:
			result.success = false
			result.error_message = "StartingEquipmentGenerator class not available"
			result.error_code = "CLASS_NOT_FOUND"
			result.severity = ValidationErrorSeverity.HIGH
			result.fallback_data = {"equipment": [], "credits": 0}
			_handle_validation_error(result, error_mode)
			return result
	
	var all_equipment: Array = []
	var total_credits: int = 0
	var errors: Array[String] = []
	
	# Generate equipment for each crew member with individual error handling
	for character in crew_data:
		if not character:
			errors.append("Null character in crew data")
			continue
		
		var equipment_result = safe_backend_call(
			StartingEquipmentGenerator,
			"generate_starting_equipment",
			[character, null],  # null for dice_manager (uses default)
			{"weapons": [], "armor": [], "gear": [], "credits": 0},
			2000,  # 2 second timeout per character
			error_mode
		)
		
		if equipment_result.success and equipment_result.fallback_data:
			var character_equipment = equipment_result.fallback_data
			var character_name = character.get("character_name", "Unknown") if character.has_method("get") else "Unknown"
			
			# Process equipment types
			for weapon in character_equipment.get("weapons", []):
				weapon["type"] = "Weapon"
				weapon["owner"] = character_name
				all_equipment.append(weapon)
			
			for armor in character_equipment.get("armor", []):
				armor["type"] = "Armor" 
				armor["owner"] = character_name
				all_equipment.append(armor)
			
			for gear in character_equipment.get("gear", []):
				gear["type"] = "Gear"
				gear["owner"] = character_name
				all_equipment.append(gear)
			
			total_credits += character_equipment.get("credits", 0)
		else:
			errors.append("Failed to generate equipment for character: %s" % equipment_result.error_message)
	
	var end_time = Time.get_ticks_msec()
	result.performance_data["duration_ms"] = end_time - start_time
	result.performance_data["equipment_generated"] = all_equipment.size()
	result.performance_data["credits_generated"] = total_credits
	result.performance_data["errors"] = errors.size()
	
	var equipment_data = {
		"equipment": all_equipment,
		"credits": total_credits,
		"errors": errors
	}
	
	if errors.is_empty():
		result.success = true
		result.fallback_data = equipment_data
		print("ValidationErrorBoundary: Successfully generated %d equipment items, %d credits" % [all_equipment.size(), total_credits])
	else:
		result.success = false
		result.error_message = "Equipment generation completed with errors: %s" % ", ".join(errors)
		result.error_code = "PARTIAL_GENERATION"
		result.severity = ValidationErrorSeverity.MEDIUM
		result.fallback_data = equipment_data  # Return partial equipment
		_handle_validation_error(result, error_mode)
	
	return result

## Handle validation errors based on error mode
static func _handle_validation_error(error_result: ValidationErrorResult, error_mode: ValidationErrorMode) -> void:
	match error_mode:
		ValidationErrorMode.SILENT:
			print("ValidationErrorBoundary: Silent error - %s" % error_result.error_message)
		
		ValidationErrorMode.GRACEFUL:
			print("ValidationErrorBoundary: Graceful error handling - %s" % error_result.error_message)
			push_warning("UI-Backend Integration Warning: %s" % error_result.error_message)
		
		ValidationErrorMode.STRICT:
			print("ValidationErrorBoundary: Strict error mode - %s" % error_result.error_message)
			push_error("UI-Backend Integration Error: %s" % error_result.error_message)
			assert(false, "Strict validation mode - stopping execution")
		
		ValidationErrorMode.DEVELOPMENT:
			print("ValidationErrorBoundary: Development error details:")
			print("  Message: %s" % error_result.error_message)
			print("  Code: %s" % error_result.error_code)
			print("  Severity: %s" % ValidationErrorSeverity.keys()[error_result.severity])
			print("  Context: %s" % str(error_result.context))
			push_warning("Development Mode: %s" % error_result.error_message)

## Validate integration health across multiple backend systems
static func validate_integration_health(
	systems_to_check: Array[String] = ["SimpleCharacterCreator", "StartingEquipmentGenerator", "ContactManager", "PlanetDataManager", "RivalBattleGenerator"]
) -> Array[ValidationErrorResult]:
	
	var results: Array[ValidationErrorResult] = []
	
	print("ValidationErrorBoundary: Validating integration health for %d systems" % systems_to_check.size())
	
	var system_paths = {
		"SimpleCharacterCreator": "res://src/core/character/Generation/SimpleCharacterCreator.gd",
		"StartingEquipmentGenerator": "res://src/core/character/Equipment/StartingEquipmentGenerator.gd",
		"ContactManager": "res://src/core/world/ContactManager.gd",
		"PlanetDataManager": "res://src/core/world/PlanetDataManager.gd",
		"RivalBattleGenerator": "res://src/core/rivals/RivalBattleGenerator.gd",
		"PatronJobGenerator": "res://src/core/patrons/PatronJobGenerator.gd"
	}
	
	for system_name in systems_to_check:
		var result = ValidationErrorResult.new(true)
		
		if not system_paths.has(system_name):
			result.success = false
			result.error_message = "Unknown system: %s" % system_name
			result.error_code = "UNKNOWN_SYSTEM"
			result.severity = ValidationErrorSeverity.MEDIUM
		else:
			var system_path = system_paths[system_name]
			var system_class = load(system_path)
			
			if not system_class:
				result.success = false
				result.error_message = "Failed to load system: %s from %s" % [system_name, system_path]
				result.error_code = "LOAD_FAILED"
				result.severity = ValidationErrorSeverity.HIGH
			else:
				result.success = true
				result.error_message = "System available: %s" % system_name
				result.error_code = "AVAILABLE"
				result.severity = ValidationErrorSeverity.LOW
		
		result.context["system_name"] = system_name
		results.append(result)
	
	var available_systems = results.filter(func(r): return r.success).size()
	print("ValidationErrorBoundary: Integration health check complete - %d/%d systems available" % [available_systems, systems_to_check.size()])
	
	return results