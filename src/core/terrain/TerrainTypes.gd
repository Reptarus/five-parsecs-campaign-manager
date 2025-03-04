# Content from src/core/battle/TerrainTypes.gd
## TerrainTypes
# Defines terrain types and their properties for the Five Parsecs battle system.
@tool
extends Resource
class_name FPCM_TerrainTypes

## Terrain Type Definitions
enum Type {
	EMPTY = 0,
	WALL = 1,
	COVER_LOW = 2,
	COVER_HIGH = 3,
	BUILDING = 4,
	WATER = 5,
	FOREST = 6,
	OBSTACLE = 7,
	ELEVATED = 8,
	HAZARD = 9,
	SPECIAL = 10,
	DIFFICULT = 11
}

## Store terrain properties for each type
const TERRAIN_PROPERTIES = {
	Type.EMPTY: {
		"name": "Empty",
		"traversable": true,
		"cover_value": 0,
		"blocks_los": false,
		"movement_cost": 1.0,
		"elevation": 0
	},
	Type.WALL: {
		"name": "Wall",
		"traversable": false,
		"cover_value": 0,
		"blocks_los": true,
		"movement_cost": 0.0,
		"elevation": 0
	},
	Type.COVER_LOW: {
		"name": "Low Cover",
		"traversable": true,
		"cover_value": 1,
		"blocks_los": false,
		"movement_cost": 1.5,
		"elevation": 0
	},
	Type.COVER_HIGH: {
		"name": "High Cover",
		"traversable": true,
		"cover_value": 2,
		"blocks_los": true,
		"movement_cost": 2.0,
		"elevation": 0
	},
	Type.BUILDING: {
		"name": "Building",
		"traversable": false,
		"cover_value": 0,
		"blocks_los": true,
		"movement_cost": 0.0,
		"elevation": 1
	},
	Type.WATER: {
		"name": "Water",
		"traversable": true,
		"cover_value": 0,
		"blocks_los": false,
		"movement_cost": 2.5,
		"elevation": 0
	},
	Type.FOREST: {
		"name": "Forest",
		"traversable": true,
		"cover_value": 1,
		"blocks_los": true,
		"movement_cost": 2.0,
		"elevation": 0
	},
	Type.OBSTACLE: {
		"name": "Obstacle",
		"traversable": false,
		"cover_value": 0,
		"blocks_los": false,
		"movement_cost": 0.0,
		"elevation": 0
	},
	Type.ELEVATED: {
		"name": "Elevated",
		"traversable": true,
		"cover_value": 1,
		"blocks_los": false,
		"movement_cost": 1.5,
		"elevation": 1
	},
	Type.HAZARD: {
		"name": "Hazard",
		"traversable": true,
		"cover_value": 0,
		"blocks_los": false,
		"movement_cost": 3.0,
		"elevation": 0,
		"damage": 5
	},
	Type.SPECIAL: {
		"name": "Special",
		"traversable": true,
		"cover_value": 0,
		"blocks_los": false,
		"movement_cost": 1.0,
		"elevation": 0
	},
	Type.DIFFICULT: {
		"name": "Difficult Terrain",
		"traversable": true,
		"cover_value": 0,
		"blocks_los": false,
		"movement_cost": 2.5,
		"elevation": 0
	}
}

## Get terrain properties for a given type
static func get_terrain_properties(type: Type) -> Dictionary:
	if type in TERRAIN_PROPERTIES:
		return TERRAIN_PROPERTIES[type].duplicate()
	return TERRAIN_PROPERTIES[Type.EMPTY].duplicate()

## Check if terrain type is traversable
static func is_traversable(type: Type) -> bool:
	return get_terrain_properties(type).get("traversable", false)

## Get movement cost for a terrain type
static func get_movement_cost(type: Type) -> float:
	return get_terrain_properties(type).get("movement_cost", 1.0)

## Check if terrain blocks line of sight
static func blocks_line_of_sight(type: Type) -> bool:
	return get_terrain_properties(type).get("blocks_los", false)

## Get cover value for a terrain type
static func get_cover_value(type: Type) -> int:
	return get_terrain_properties(type).get("cover_value", 0)

## Get terrain elevation
static func get_elevation(type: Type) -> int:
	return get_terrain_properties(type).get("elevation", 0)

## Get terrain display name
static func get_display_name(type: Type) -> String:
	return get_terrain_properties(type).get("name", "Unknown")

## Get special properties for terrain (if any)
static func get_special_properties(type: Type) -> Dictionary:
	var props = get_terrain_properties(type)
	var special = {}
	
	for key in props:
		if key not in ["name", "traversable", "cover_value", "blocks_los", "movement_cost", "elevation"]:
			special[key] = props[key]
			
	return special

## Check if terrain blocks movement
static func blocks_movement(type: Type) -> bool:
	return not is_traversable(type)