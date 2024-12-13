## TerrainTypes
# Defines terrain types and their properties for the Five Parsecs battle system.
class_name TerrainTypes
extends Node

## Terrain type enumeration
enum Type {
	EMPTY,
	INVALID,
	IMPASSABLE,
	ROUGH,
	COVER_LOW,
	COVER_HIGH,
	WALL,
	DIFFICULT,
	ELEVATED,
	WATER,
	HAZARD
}

## Check if terrain blocks movement
static func blocks_movement(type: Type) -> bool:
	return type in [Type.IMPASSABLE, Type.WALL]

## Check if terrain blocks line of sight
static func blocks_line_of_sight(type: Type) -> bool:
	return type in [Type.IMPASSABLE, Type.WALL]

## Get elevation value for terrain
static func get_elevation(type: Type) -> float:
	match type:
		Type.ELEVATED:
			return 2.0
		Type.WALL:
			return 3.0
		_:
			return 0.0

## Get cover value for a terrain type
static func get_cover_value(type: Type) -> float:
	match type:
		Type.COVER_LOW:
			return 0.5
		Type.COVER_HIGH:
			return 0.75
		Type.WALL:
			return 1.0
		Type.ELEVATED:
			return 0.25
		_:
			return 0.0

## Check if terrain type can provide cover
static func can_provide_cover(type: Type) -> bool:
	return type in [Type.COVER_LOW, Type.COVER_HIGH, Type.WALL, Type.ELEVATED]

## Check if terrain type affects movement
static func affects_movement(type: Type) -> bool:
	return type in [Type.ROUGH, Type.WATER, Type.HAZARD, Type.DIFFICULT]

## Get movement cost for terrain type
static func get_movement_cost(type: Type) -> float:
	match type:
		Type.ROUGH:
			return 1.5
		Type.DIFFICULT:
			return 2.0
		Type.WATER:
			return 2.5
		Type.HAZARD:
			return 3.0
		_:
			return 1.0

## Check if terrain type is passable
static func is_passable(type: Type) -> bool:
	return not blocks_movement(type)

## Get terrain modifier for type
static func get_terrain_modifier(type: Type) -> GlobalEnums.TerrainModifier:
	match type:
		Type.COVER_LOW:
			return GlobalEnums.TerrainModifier.PARTIAL_COVER
		Type.COVER_HIGH:
			return GlobalEnums.TerrainModifier.FULL_COVER
		Type.WALL:
			return GlobalEnums.TerrainModifier.LINE_OF_SIGHT_BLOCKED
		Type.ROUGH:
			return GlobalEnums.TerrainModifier.MOVEMENT_PENALTY
		Type.DIFFICULT:
			return GlobalEnums.TerrainModifier.DIFFICULT_TERRAIN
		Type.ELEVATED:
			return GlobalEnums.TerrainModifier.HIGH_GROUND
		Type.WATER:
			return GlobalEnums.TerrainModifier.WATER_HAZARD
		Type.HAZARD:
			return GlobalEnums.TerrainModifier.HAZARDOUS
		_:
			return GlobalEnums.TerrainModifier.NONE

## Get combat modifiers for a terrain type
static func get_combat_modifiers(type: Type) -> Dictionary:
	match type:
		Type.COVER_LOW:
			return {"defense": 1, "cover": 0.5}
		Type.COVER_HIGH:
			return {"defense": 2, "cover": 0.75}
		Type.WALL:
			return {"defense": 3, "cover": 1.0}
		Type.ELEVATED:
			return {"attack": 1, "range": 1}
		Type.DIFFICULT:
			return {"movement": -1}
		Type.WATER:
			return {"movement": -2, "defense": -1}
		Type.HAZARD:
			return {"damage": 1, "movement": -2}
		_:
			return {}

## Get special effects for a terrain type
static func get_special_effects(type: Type) -> Dictionary:
	match type:
		Type.HAZARD:
			return {"damage_per_turn": 1, "effect": "poison"}
		Type.WATER:
			return {"effect": "slow"}
		Type.ELEVATED:
			return {"effect": "high_ground"}
		Type.WALL:
			return {"effect": "full_cover"}
		Type.DIFFICULT:
			return {"effect": "rough_terrain"}
		_:
			return {}

## Check if terrain can be destroyed
static func can_be_destroyed(type: Type) -> bool:
	return type in [Type.WALL, Type.COVER_HIGH, Type.COVER_LOW]

## Get default health for destructible terrain
static func get_default_health(type: Type) -> int:
	match type:
		Type.WALL:
			return 100
		Type.COVER_HIGH:
			return 75
		Type.COVER_LOW:
			return 50
		_:
			return 0

## Get terrain type when damaged
static func get_damaged_type(type: Type) -> Type:
	match type:
		Type.WALL:
			return Type.DIFFICULT
		Type.COVER_HIGH:
			return Type.COVER_LOW
		Type.COVER_LOW:
			return Type.EMPTY
		_:
			return type