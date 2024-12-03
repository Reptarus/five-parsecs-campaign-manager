class_name TerrainTypes
extends Node

enum Type {
	EMPTY,
	WALL,
	COVER_LOW,
	COVER_HIGH,
	DIFFICULT,
	HAZARDOUS,
	ELEVATED,
	WATER
}

const TERRAIN_PROPERTIES = {
	Type.EMPTY: {
		"blocks_los": false,
		"blocks_movement": false,
		"cover_value": 0,
		"movement_cost": 1.0,
		"elevation": 0,
		"hazard_damage": 0
	},
	Type.WALL: {
		"blocks_los": true,
		"blocks_movement": true,
		"cover_value": 0,
		"movement_cost": INF,
		"elevation": 2,
		"hazard_damage": 0
	},
	Type.COVER_LOW: {
		"blocks_los": false,
		"blocks_movement": false,
		"cover_value": 2,
		"movement_cost": 1.0,
		"elevation": 0,
		"hazard_damage": 0
	},
	Type.COVER_HIGH: {
		"blocks_los": true,
		"blocks_movement": false,
		"cover_value": 4,
		"movement_cost": 1.0,
		"elevation": 1,
		"hazard_damage": 0
	},
	Type.DIFFICULT: {
		"blocks_los": false,
		"blocks_movement": false,
		"cover_value": 0,
		"movement_cost": 2.0,
		"elevation": 0,
		"hazard_damage": 0
	},
	Type.HAZARDOUS: {
		"blocks_los": false,
		"blocks_movement": false,
		"cover_value": 0,
		"movement_cost": 1.5,
		"elevation": 0,
		"hazard_damage": 1
	},
	Type.ELEVATED: {
		"blocks_los": false,
		"blocks_movement": false,
		"cover_value": 1,
		"movement_cost": 2.0,
		"elevation": 1,
		"hazard_damage": 0
	},
	Type.WATER: {
		"blocks_los": false,
		"blocks_movement": false,
		"cover_value": 0,
		"movement_cost": 2.0,
		"elevation": -1,
		"hazard_damage": 0
	}
}

static func get_property(terrain_type: Type, property: String) -> Variant:
	if not TERRAIN_PROPERTIES.has(terrain_type):
		return null
	return TERRAIN_PROPERTIES[terrain_type].get(property, null)

static func blocks_los(terrain_type: Type) -> bool:
	return get_property(terrain_type, "blocks_los")

static func blocks_movement(terrain_type: Type) -> bool:
	return get_property(terrain_type, "blocks_movement")

static func get_cover_value(terrain_type: Type) -> int:
	return get_property(terrain_type, "cover_value")

static func get_movement_cost(terrain_type: Type) -> float:
	return get_property(terrain_type, "movement_cost")

static func get_elevation(terrain_type: Type) -> int:
	return get_property(terrain_type, "elevation")

static func get_hazard_damage(terrain_type: Type) -> int:
	return get_property(terrain_type, "hazard_damage") 