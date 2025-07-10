class_name IGameSystem
extends RefCounted

## Standardized Game System Interface
##
## All consolidated managers must implement this interface
## for consistent data flow and system integration according
## to the Senior Developer Consolidation Strategy

## Initialize the system with dependencies
## @return: true if initialization successful, false otherwise
func initialize() -> bool:
	push_error("IGameSystem.initialize() must be implemented by subclass")
	return false

## Get all system data in a serializable format
## @return: Dictionary containing all system state
func get_data() -> Dictionary:
	push_error("IGameSystem.get_data() must be implemented by subclass")
	return {}

## Update system state with provided data
## @param data: Dictionary containing state updates
## @return: true if update successful, false otherwise
func update_data(data: Dictionary) -> bool:
	push_error("IGameSystem.update_data() must be implemented by subclass")
	return false

## Clean up system resources and connections
func cleanup() -> void:
	push_error("IGameSystem.cleanup() must be implemented by subclass")

## Get system status information
## @return: Dictionary with system health and status info
func get_status() -> Dictionary:
	return {
		"initialized": false,
		"active": false,
		"errors": [],
		"last_update": 0
	}

## Validate system state integrity
## @return: Dictionary with validation results
func validate_state() -> Dictionary:
	return {
		"valid": true,
		"errors": [],
		"warnings": []
	}