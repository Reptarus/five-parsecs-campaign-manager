# Content from src/core/battle/TerrainTypes.gd
## TerrainTypes
# Defines terrain types and their properties for the Five Parsecs battle system.
@tool
extends RefCounted
class_name TerrainTypes

## Terrain type definitions for Five Parsecs Campaign Manager

enum Type {
	NONE,
	OPEN,
	COVER,
	COVER_LOW, # Light cover
	COVER_HIGH, # Heavy cover
	DIFFICULT,
	IMPASSABLE,
	WALL, # Solid barrier
	HAZARD, # Dangerous terrain
	WATER,
	BUILDING,
	VEHICLE,
	FOREST,
	ROCK,
	HILL
}

enum MovementType {
	NORMAL,
	DIFFICULT,
	IMPASSABLE
}

enum CoverType {
	NONE,
	LIGHT,
	HEAVY,
	FULL
}

## Terrain type names for display
const TYPE_NAMES = {
	Type.NONE: "None",
	Type.OPEN: "Open",
	Type.COVER: "Cover",
	Type.COVER_LOW: "Light Cover",
	Type.COVER_HIGH: "Heavy Cover",
	Type.DIFFICULT: "Difficult",
	Type.IMPASSABLE: "Impassable",
	Type.WALL: "Wall",
	Type.HAZARD: "Hazard",
	Type.WATER: "Water",
	Type.BUILDING: "Building",
	Type.VEHICLE: "Vehicle",
	Type.FOREST: "Forest",
	Type.ROCK: "Rock",
	Type.HILL: "Hill"
}

## Terrain type descriptions
const TYPE_DESCRIPTIONS = {
	Type.NONE: "No terrain",
	Type.OPEN: "Open ground with no obstructions",
	Type.COVER: "Partial cover that provides defensive bonuses",
	Type.COVER_LOW: "Light cover that provides minor defensive bonuses",
	Type.COVER_HIGH: "Heavy cover that provides significant defensive bonuses",
	Type.DIFFICULT: "Rough terrain that impedes movement",
	Type.IMPASSABLE: "Solid barrier that blocks movement and line of sight",
	Type.WALL: "Solid wall that blocks movement and line of sight",
	Type.HAZARD: "Dangerous terrain that may cause damage",
	Type.WATER: "Water feature that slows movement",
	Type.BUILDING: "Building",
	Type.VEHICLE: "Vehicle",
	Type.FOREST: "Forest",
	Type.ROCK: "Rock",
	Type.HILL: "Hill"
}

## Check if terrain blocks movement (referenced by other files)
static func blocks_movement(terrain_type: Type) -> bool:
	match terrain_type:
		Type.IMPASSABLE, Type.WALL:
			return true
		_:
			return false

## Check if terrain type is traversable
static func is_traversable(terrain_type: Type) -> bool:
	match terrain_type:
		Type.IMPASSABLE, Type.WALL, Type.WATER:
			return false
		_:
			return true

## Get movement cost for terrain type
static func get_movement_cost(terrain_type: Type) -> float:
	match terrain_type:
		Type.OPEN:
			return 1.0
		Type.DIFFICULT, Type.FOREST, Type.HILL:
			return 2.0
		Type.HAZARD:
			return 1.5
		Type.ROCK:
			return 1.5
		Type.IMPASSABLE, Type.WALL, Type.WATER:
			return 999.0
		_:
			return 1.0

## Get cover _value for terrain type
static func get_cover_value(terrain_type: Type) -> CoverType:
	match terrain_type:
		Type.COVER, Type.COVER_LOW, Type.FOREST:
			return CoverType.LIGHT
		Type.COVER_HIGH, Type.BUILDING, Type.ROCK, Type.WALL:
			return CoverType.HEAVY
		Type.VEHICLE:
			return CoverType.FULL
		_:
			return CoverType.NONE

## Get terrain name string
static func get_terrain_name(terrain_type: Type) -> String:
	return TYPE_NAMES.get(terrain_type, "Unknown")

## Get description for terrain type
static func get_type_description(terrain_type: Type) -> String:
	return TYPE_DESCRIPTIONS.get(terrain_type, "No description available")

## Validate terrain type
static func is_valid_terrain_type(terrain_type: int) -> bool:
	return terrain_type >= Type.NONE and terrain_type <= Type.HILL