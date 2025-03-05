@tool
extends Resource
class_name GameWorldTrait

const GameDataManager = preload("res://src/core/managers/GameDataManager.gd")
const GameEnums = preload("res://src/core/systems/GlobalEnums.gd")

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

var _data_manager: Object = null

func _init() -> void:
	if Engine.is_editor_hint():
		return
		
	# Use the singleton instance
	_data_manager = GameDataManager.get_instance()
	GameDataManager.ensure_data_loaded()

## Initialize this trait from a trait ID in the database
func initialize_from_id(id: String) -> bool:
	if _data_manager == null:
		_data_manager = GameDataManager.get_instance()
		GameDataManager.ensure_data_loaded()
		
	var trait_data = _data_manager.get_world_trait(id)
	if trait_data.is_empty():
		push_error("GameWorldTrait: Could not find trait with ID '%s'" % id)
		return false
		
	return initialize_from_data(trait_data)

## Initialize from data dictionary
func initialize_from_data(data: Dictionary) -> bool:
	if data.is_empty():
		return false
		
	trait_id = data.get("id", "")
	trait_name = data.get("name", "")
	trait_description = data.get("description", "")
	effects = data.get("effects", [])
	
	# Handle complex data
	encounter_modifiers = data.get("encounter_modifiers", {})
	resource_modifiers = data.get("resource_modifiers", {})
	faction_influence = data.get("faction_influence", {})
	tech_requirements = data.get("tech_requirements", {})
	tags = data.get("tags", [])
	
	return true

## Get resource modifier for a specific resource type
func get_resource_modifier(resource_type: int) -> float:
	var resource_key = str(resource_type)
	return resource_modifiers.get(resource_key, 1.0)

## Get encounter modifier for a specific encounter type
func get_encounter_modifier(encounter_type: int) -> float:
	var encounter_key = str(encounter_type)
	return encounter_modifiers.get(encounter_key, 1.0)

## Get faction influence modifier for a specific faction
func get_faction_influence(faction_type: int) -> int:
	var faction_key = str(faction_type)
	return faction_influence.get(faction_key, 0)

## Check if this trait has a specific tag
func has_tag(tag: String) -> bool:
	return tag in tags

## Check if this trait meets tech requirements
func meets_tech_requirements(available_tech: Dictionary) -> bool:
	for tech_id in tech_requirements:
		var required_level = tech_requirements[tech_id]
		var available_level = available_tech.get(tech_id, 0)
		
		if available_level < required_level:
			return false
			
	return true

## Convert trait to string representation
func _to_string() -> String:
	return "%s (%s)" % [trait_name, trait_id]

## Serialize trait to dictionary
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

## Create a GameWorldTrait instance from serialized data
static func deserialize(data: Dictionary) -> GameWorldTrait:
	var world_trait = GameWorldTrait.new()
	world_trait.initialize_from_data(data)
	return world_trait