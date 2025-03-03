# Content from src/core/battle/TerrainTypes.gd
## TerrainTypes
# Defines terrain types and their properties for the Five Parsecs battle system.
@tool
extends Node

## Terrain Type Definitions
enum TerrainType {
	INVALID = -1,
	OPEN = 0,
	DIFFICULT = 1,
	OBSTACLE = 2,
	IMPASSABLE = 3,
	HAZARDOUS = 4,
	COVER_LIGHT = 5,
	COVER_MEDIUM = 6,
	COVER_HEAVY = 7,
	ELEVATED = 8,
	WATER = 9
}

## Movement costs for each terrain type
const MOVEMENT_COSTS = {
	TerrainType.INVALID: - 1,
	TerrainType.OPEN: 1.0,
	TerrainType.DIFFICULT: 2.0,
	TerrainType.OBSTACLE: - 1,
	TerrainType.IMPASSABLE: - 1,
	TerrainType.HAZARDOUS: 3.0,
	TerrainType.COVER_LIGHT: 1.5,
	TerrainType.COVER_MEDIUM: 2.0,
	TerrainType.COVER_HEAVY: 2.5,
	TerrainType.ELEVATED: 2.0,
	TerrainType.WATER: 2.0
}

## Cover provided by each terrain type
const COVER_VALUES = {
	TerrainType.INVALID: 0,
	TerrainType.OPEN: 0,
	TerrainType.DIFFICULT: 0,
	TerrainType.OBSTACLE: 2,
	TerrainType.IMPASSABLE: 3,
	TerrainType.HAZARDOUS: 0,
	TerrainType.COVER_LIGHT: 1,
	TerrainType.COVER_MEDIUM: 2,
	TerrainType.COVER_HEAVY: 3,
	TerrainType.ELEVATED: 1,
	TerrainType.WATER: 0
}

## Line of sight blocking for each terrain type (0 = no blocking, 1 = partial blocking, 2 = full blocking)
const LINE_OF_SIGHT_BLOCKING = {
	TerrainType.INVALID: 0,
	TerrainType.OPEN: 0,
	TerrainType.DIFFICULT: 0,
	TerrainType.OBSTACLE: 2,
	TerrainType.IMPASSABLE: 2,
	TerrainType.HAZARDOUS: 0,
	TerrainType.COVER_LIGHT: 1,
	TerrainType.COVER_MEDIUM: 1,
	TerrainType.COVER_HEAVY: 2,
	TerrainType.ELEVATED: 0,
	TerrainType.WATER: 0
}

## Terrain type names for display
const TERRAIN_NAMES = {
	TerrainType.INVALID: "Invalid",
	TerrainType.OPEN: "Open Ground",
	TerrainType.DIFFICULT: "Difficult Terrain",
	TerrainType.OBSTACLE: "Obstacle",
	TerrainType.IMPASSABLE: "Impassable",
	TerrainType.HAZARDOUS: "Hazardous",
	TerrainType.COVER_LIGHT: "Light Cover",
	TerrainType.COVER_MEDIUM: "Medium Cover",
	TerrainType.COVER_HEAVY: "Heavy Cover",
	TerrainType.ELEVATED: "Elevated Position",
	TerrainType.WATER: "Water"
}

## Get the movement cost for a terrain type
static func get_movement_cost(terrain_type: int) -> float:
	if MOVEMENT_COSTS.has(terrain_type):
		return MOVEMENT_COSTS[terrain_type]
	return -1.0

## Get the cover value for a terrain type
static func get_cover_value(terrain_type: int) -> int:
	if COVER_VALUES.has(terrain_type):
		return COVER_VALUES[terrain_type]
	return 0

## Get the line of sight blocking value for a terrain type
static func get_los_blocking(terrain_type: int) -> int:
	if LINE_OF_SIGHT_BLOCKING.has(terrain_type):
		return LINE_OF_SIGHT_BLOCKING[terrain_type]
	return 0

## Check if a terrain type blocks movement
static func blocks_movement(terrain_type: int) -> bool:
	if MOVEMENT_COSTS.has(terrain_type):
		return MOVEMENT_COSTS[terrain_type] < 0
	return true

## Get the name of a terrain type
static func get_terrain_name(terrain_type: int) -> String:
	if TERRAIN_NAMES.has(terrain_type):
		return TERRAIN_NAMES[terrain_type]
	return "Unknown"

## Gets terrain properties for a specific type
static func get_terrain_properties(terrain_type: TerrainType) -> Dictionary:
	return {
		"name": get_terrain_name(terrain_type),
		"elevation": get_elevation(terrain_type),
		"provides_cover": get_cover_value(terrain_type) > 0,
		"blocks_los": get_los_blocking(terrain_type) > 0,
		"blocks_movement": blocks_movement(terrain_type),
		"combat_modifier": get_combat_modifier(terrain_type)
	}

## Gets elevation value for a terrain type
static func get_elevation(terrain_type: TerrainType) -> int:
	return 0

## Gets the combat modifier for a terrain type
static func get_combat_modifier(terrain_type: TerrainType) -> float:
	match terrain_type:
		TerrainType.COVER_LIGHT:
			return -0.25
		TerrainType.COVER_MEDIUM:
			return -0.5
		TerrainType.COVER_HEAVY:
			return -0.75
		TerrainType.ELEVATED:
			return -0.25
		TerrainType.DIFFICULT:
			return 0.25
		TerrainType.WATER:
			return 0.25
		_:
			return 0.0