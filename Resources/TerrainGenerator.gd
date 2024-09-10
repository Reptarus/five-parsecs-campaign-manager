# TerrainGenerator.gd
class_name TerrainGenerator
extends Node

enum TerrainType { LARGE, SMALL, LINEAR }

const TABLE_SIZES = {
	"2x2": Vector2i(24, 24),
	"2.5x2.5": Vector2i(30, 30),
	"3x3": Vector2i(36, 36)
}

const TERRAIN_COUNTS = {
	"2x2": {"LARGE": 2, "SMALL": 4, "LINEAR": 2},
	"2.5x2.5": {"LARGE": 2, "SMALL": 5, "LINEAR": 4},
	"3x3": {"LARGE": 3, "SMALL": 6, "LINEAR": 3}
}

var game_state: GameState
var table_size: Vector2i
var terrain_map: Array

func _init(_game_state: GameState):
	game_state = _game_state
	table_size = TABLE_SIZES["2x2"]
	terrain_map = []
	for x in range(table_size.x):
		terrain_map.append([])
		for y in range(table_size.y):
			terrain_map[x].append(null)

func generate_terrain():
	clear_terrain()
	place_center_feature()
	for terrain_type in TerrainType.values():
		place_terrain_features(terrain_type, TERRAIN_COUNTS[get_table_size_key()][TerrainType.keys()[terrain_type]])

func clear_terrain():
	for x in range(table_size.x):
		for y in range(table_size.y):
			terrain_map[x][y] = null

func place_center_feature():
	var center = table_size / 2
	place_terrain(TerrainType.LARGE, center)

func place_terrain_features(type: int, count: int):
	for i in range(count):
		var position = find_valid_position(type)
		if position:
			place_terrain(type, position)

func find_valid_position(type: int) -> Vector2i:
	# Implementation to find a valid position for terrain placement
	# This will need to consider existing terrain and placement rules
	return Vector2i.ZERO  # Placeholder return

func place_terrain(type: int, position: Vector2i):
	# Implementation to place terrain on the map
	# This will need to consider the size and shape of different terrain types
	pass

func get_table_size_key() -> String:
	for key in TABLE_SIZES.keys():
		if TABLE_SIZES[key] == table_size:
			return key
	return "2x2"  # Default if not found

func get_terrain_map() -> Array:
	return terrain_map
