@tool
extends Resource

## A class representing a world trait that can be applied to planets and locations
## These traits define special characteristics, modifiers, and effects

# Basic trait information
@export var trait_id: String = ""
@export var trait_name: String = ""
@export var trait_description: String = ""

# Effects and modifiers
@export var effects: Array[String] = []
@export var encounter_modifiers: Dictionary = {}
@export var resource_modifiers: Dictionary = {}

# Optional additional data
@export var faction_influence: Dictionary = {}
@export var tech_requirements: Dictionary = {}
@export var tags: Array[String] = []

var _data_manager: GameDataManager = null

func _init() -> void:
	if Engine.is_editor_hint():
		return
		
	# Create the data manager instance if needed
	if _data_manager == null:
		_data_manager = GameDataManager.new()
		_data_manager.load_world_traits()

## Initialize this trait from a trait ID in the database
func initialize_from_id(id: String) -> bool:
	if _data_manager == null:
		_data_manager = GameDataManager.new()
		_data_manager.load_world_traits()
		
	var trait_data = _data_manager.get_world_trait(id)
	if trait_data.is_empty():
		push_error("Failed to find world trait with ID: " + id)
		return false
		
	return initialize_from_data(trait_data)

## Initialize this trait from a data dictionary
func initialize_from_data(data: Dictionary) -> bool:
	if data.is_empty():
		push_error("Cannot initialize world trait from empty data")
		return false
		
	trait_id = data.get("id", "")
	trait_name = data.get("name", "")
	trait_description = data.get("description", "")
	
	# Handle effects
	effects = []
	var effects_data = data.get("effects", [])
	if effects_data is Array:
		for effect in effects_data:
			effects.append(effect)
	
	# Handle encounter modifiers
	encounter_modifiers = data.get("encounter_modifiers", {})
	
	# Handle resource modifiers
	resource_modifiers = data.get("resource_modifiers", {})
	
	# Handle optional data
	faction_influence = data.get("faction_influence", {})
	tech_requirements = data.get("tech_requirements", {})
	
	# Handle tags
	tags = []
	var tags_data = data.get("tags", [])
	if tags_data is Array:
		for tag in tags_data:
			tags.append(tag)
	
	return true

## Get a specific resource modifier value
func get_resource_modifier(resource_key: String) -> float:
	return resource_modifiers.get(resource_key, 0.0)

## Get a specific encounter modifier value
func get_encounter_modifier(encounter_key: String) -> int:
	return encounter_modifiers.get(encounter_key, 0)

## Check if this trait has a specific tag
func has_tag(tag: String) -> bool:
	return tag in tags

## Serialize this trait into a dictionary
func serialize() -> Dictionary:
	return {
		"id": trait_id,
		"name": trait_name,
		"description": trait_description,
		"effects": effects,
		"encounter_modifiers": encounter_modifiers,
		"resource_modifiers": resource_modifiers,
		"faction_influence": faction_influence,
		"tech_requirements": tech_requirements,
		"tags": tags
	}

## For backward compatibility
func to_dict() -> Dictionary:
	return serialize()

## Create a GameWorldTrait instance from serialized data
static func deserialize(data: Dictionary) -> GameWorldTrait:
	var world_trait = GameWorldTrait.new()
	world_trait.initialize_from_data(data)
	return world_trait