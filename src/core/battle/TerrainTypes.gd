extends Resource

## Terrain type enumeration
enum Type {
	EMPTY,
	WALL,
	BLOCKING_TERRAIN,
	COVER_HIGH,
	COVER_LOW,
	DIFFICULT,
	HAZARD,
	WATER,
	INVALID
}

## Get cover value for terrain type
static func get_cover_value(type: int) -> float:
	match type:
		Type.COVER_HIGH:
			return 2.0
		Type.COVER_LOW:
			return 1.0
		Type.WALL:
			return 3.0
		_:
			return 0.0

## Get elevation for terrain type
static func get_elevation(type: int) -> float:
	match type:
		Type.WALL:
			return 2.0
		Type.COVER_HIGH:
			return 1.5
		Type.COVER_LOW:
			return 0.5
		_:
			return 0.0

## Get movement cost for terrain type
static func get_movement_cost(type: int) -> float:
	match type:
		Type.EMPTY:
			return 1.0
		Type.DIFFICULT:
			return 2.0
		Type.WATER:
			return 1.5
		Type.WALL, Type.BLOCKING_TERRAIN:
			return -1.0 # Impassable
		_:
			return 1.0

## Check if terrain blocks line of sight
static func blocks_line_of_sight(type: int) -> bool:
	return type in [Type.WALL, Type.BLOCKING_TERRAIN, Type.COVER_HIGH]

## Check if terrain blocks movement
static func blocks_movement(type: int) -> bool:
	return type in [Type.WALL, Type.BLOCKING_TERRAIN]