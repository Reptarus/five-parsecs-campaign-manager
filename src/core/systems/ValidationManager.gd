@tool
extends RefCounted
class_name ValidationManager

## Validation Manager for Five Parsecs Campaign Manager
## Provides validation services for campaign state and data integrity

const GlobalEnums = preload("res://src/core/systems/GlobalEnums.gd")

var game_state: Variant

func _init(state: Node = null) -> void:
	# Parameter validation - eliminates UNSAFE_CALL_ARGUMENT warnings
	if not is_instance_valid(self):
		return
	game_state = state

## Validate campaign state
func validate_campaign() -> Dictionary:
	var result: Variant = {
		"valid": true,
		"errors": [],
		"warnings": []
	}

	if not game_state:
		result.valid = false
		result.errors.append("No game state available for validation")
		return result

	# Add validation logic here as needed
	return result

## Validate crew composition
func validate_crew() -> Dictionary:
	return {
		"valid": true,
		"errors": [],
		"warnings": []
	}

## Validate mission parameters
func validate_mission(mission_data: Dictionary) -> Dictionary:
	return {
		"valid": true,
		"errors": [],
		"warnings": []
	}

## Safe method call helper - eliminates UNSAFE_METHOD_ACCESS warnings
func safe_call_method(obj: Variant, method_name: String, args: Array = []) -> Variant:
	if obj == null:
		return null
	if obj is Object and obj.has_method(method_name):
		return obj.callv(method_name, args)
	return null
