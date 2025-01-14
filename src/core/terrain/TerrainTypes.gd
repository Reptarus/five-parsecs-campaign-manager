# Content from src/core/battle/TerrainTypes.gd
## TerrainTypes
# Defines terrain types and their properties for the Five Parsecs battle system.
class_name TerrainTypes
extends Node

const GameEnums := preload("res://src/core/systems/GlobalEnums.gd")

## Terrain type enumeration
enum Type {
	INVALID = -1,
	NONE = 0,
	EMPTY,
	COVER_LOW,
	COVER_HIGH,
	WALL,
	WATER,
	HAZARD,
	DIFFICULT
}

## Terrain type definitions with their properties
const TERRAIN_PROPERTIES: Dictionary = {
	Type.NONE: {
		"name": "Empty",
		"elevation": 0,
		"provides_cover": false,
		"blocks_los": false,
		"blocks_movement": false,
		"combat_modifier": 0.0
	},
	Type.COVER_LOW: {
		"name": "Low Cover",
		"elevation": 0,
		"provides_cover": true,
		"blocks_los": false,
		"blocks_movement": false,
		"combat_modifier": - 0.25
	},
	Type.COVER_HIGH: {
		"name": "High Cover",
		"elevation": 1,
		"provides_cover": true,
		"blocks_los": true,
		"blocks_movement": false,
		"combat_modifier": - 0.5
	},
	Type.WALL: {
		"name": "Wall",
		"elevation": 2,
		"provides_cover": true,
		"blocks_los": true,
		"blocks_movement": true,
		"combat_modifier": - 0.75
	},
	Type.WATER: {
		"name": "Water",
		"elevation": - 1,
		"provides_cover": false,
		"blocks_los": false,
		"blocks_movement": false,
		"combat_modifier": 0.25
	},
	Type.HAZARD: {
		"name": "Hazard",
		"elevation": 0,
		"provides_cover": false,
		"blocks_los": false,
		"blocks_movement": true,
		"combat_modifier": 0.0
	},
	Type.DIFFICULT: {
		"name": "Difficult Terrain",
		"elevation": 0,
		"provides_cover": false,
		"blocks_los": false,
		"blocks_movement": false,
		"combat_modifier": 0.1
	}
}

## Gets terrain properties for a specific type
static func get_terrain_properties(terrain_type: Type) -> Dictionary:
	return TERRAIN_PROPERTIES.get(terrain_type, TERRAIN_PROPERTIES[Type.NONE])

## Gets elevation value for a terrain type
static func get_elevation(terrain_type: Type) -> int:
	return get_terrain_properties(terrain_type).get("elevation", 0)

## Gets cover value for a terrain type
static func get_cover_value(terrain_type: Type) -> float:
	var props := get_terrain_properties(terrain_type)
	return -props.get("combat_modifier", 0.0) if props.get("provides_cover", false) else 0.0

## Checks if terrain blocks movement
static func blocks_movement(terrain_type: Type) -> bool:
	return get_terrain_properties(terrain_type).get("blocks_movement", false)

## Gets movement cost for a terrain type
static func get_movement_cost(terrain_type: Type) -> float:
	var props := get_terrain_properties(terrain_type)
	if props.get("blocks_movement", false):
		return INF
	return 1.0 + abs(props.get("combat_modifier", 0.0))

## Gets the name of a terrain type
static func get_terrain_name(terrain_type: Type) -> String:
	return get_terrain_properties(terrain_type).get("name", "Unknown")

## Checks if terrain blocks line of sight
static func blocks_line_of_sight(terrain_type: Type) -> bool:
	return get_terrain_properties(terrain_type).get("blocks_los", false)

## Gets the combat modifier for a terrain type
static func get_combat_modifier(terrain_type: Type) -> float:
	return get_terrain_properties(terrain_type).get("combat_modifier", 0.0)