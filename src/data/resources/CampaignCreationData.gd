class_name CampaignCreationData
extends Resource

## Enterprise-grade Campaign Creation Data Model
## Replaces Dictionary-based data structures with type-safe resources
## Provides validation, serialization, and upgrade path compatibility

# Import required classes
const ValidationResult = preload("res://src/core/validation/ValidationResult.gd")
const Character = preload("res://src/core/character/Character.gd")

@export var config: Resource # Will be CampaignConfig when available
@export var crew_data: CrewData
@export var captain: Character
@export var ship: Resource # Will be ShipData when available
@export var equipment: Resource # Will be EquipmentData when available
@export var world: Resource # Will be WorldData when available
@export var metadata: Resource # Will be CampaignMetadata when available

## Validation framework for data integrity
func validate() -> ValidationResult:
	var result = ValidationResult.new()
	
	# Validate required components
	if not config:
		result.add_error("Campaign configuration is required")
	elif not config.validate().is_valid():
		result.add_error("Campaign configuration is invalid")
	
	if not crew_data:
		result.add_error("Crew data is required")
	elif not crew_data.validate().is_valid():
		result.add_error("Crew data is invalid")
	
	# Validate data consistency
	if crew_data and crew_data.captain and captain:
		if crew_data.captain != captain:
			result.add_warning("Captain mismatch between crew data and main captain reference")
	
	return result

## Safe data access with fallbacks
func get_crew_size() -> int:
	return crew_data.total_size if crew_data else 0

func get_creation_timestamp() -> String:
	return metadata.created_at if metadata else ""

func is_complete() -> bool:
	var validation = validate()
	return validation.is_valid() and _check_completion_requirements()

func _check_completion_requirements() -> bool:
	return (config != null and
			crew_data != null and
			crew_data.is_complete and
			captain != null and
			ship != null)

## Export compatibility for save/load operations
func to_dictionary() -> Dictionary:
	return {
		"config": config.to_dictionary() if config else {},
		"crew_data": crew_data.to_dictionary() if crew_data else {},
		"captain": captain.to_dictionary() if captain else {},
		"ship": ship.to_dictionary() if ship else {},
		"equipment": equipment.to_dictionary() if equipment else {},
		"world": world.to_dictionary() if world else {},
		"metadata": metadata.to_dictionary() if metadata else {}
	}

## Factory method for safe instantiation
static func create_new() -> CampaignCreationData:
	var data = CampaignCreationData.new()
	data.config = Resource.new() # Placeholder for CampaignConfig
	data.crew_data = CrewData.new()
	data.equipment = Resource.new() # Placeholder for EquipmentData
	data.world = Resource.new() # Placeholder for WorldData
	data.metadata = Resource.new() # Placeholder for CampaignMetadata
	return data
