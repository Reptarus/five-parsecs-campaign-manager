class_name BattlefieldManager
extends Node

const GameEnums = preload("res://Resources/Core/Systems/GlobalEnums.gd")
const Character = preload("res://Resources/Core/Character/Base/Character.gd")
const TerrainTypes = preload("res://Resources/Battle/Core/TerrainTypes.gd")
const Mission = preload("res://Resources/Campaign/Mission/Mission.gd")

signal terrain_updated(position: Vector2i, new_type: int)
signal unit_moved(unit: Character, from: Vector2i, to: Vector2i)
signal unit_added(unit: Character, position: Vector2i)
signal unit_removed(unit: Character, position: Vector2i)
signal cover_changed(position: Vector2i, cover_value: float)
signal line_of_sight_changed(from: Vector2i, to: Vector2i, blocked: bool)
signal tactical_advantage_changed(unit: Character, advantage_type: String, value: float)

@export var grid_size: Vector2i = Vector2i(20, 20)
@export var cell_size: float = 32.0

var terrain_map: Array[Array] = []
var unit_positions: Dictionary = {}  # Character: Vector2i
var cover_map: Array[Array] = []
var los_cache: Dictionary = {}
var tactical_advantages: Dictionary = {}  # Character: Dictionary of advantages

func _init() -> void:
	_initialize_maps()

func _initialize_maps() -> void:
	# Initialize terrain map
	terrain_map.resize(grid_size.x)
	for x in range(grid_size.x):
		terrain_map[x] = []
		terrain_map[x].resize(grid_size.y)
		for y in range(grid_size.y):
			terrain_map[x][y] = TerrainTypes.Type.EMPTY
	
	# Initialize cover map
	cover_map.resize(grid_size.x)
	for x in range(grid_size.x):
		cover_map[x] = []
		cover_map[x].resize(grid_size.y)
		for y in range(grid_size.y):
			cover_map[x][y] = 0.0

func set_terrain(position: Vector2i, type: int) -> void:
	if _is_valid_position(position):
		terrain_map[position.x][position.y] = type
		_update_cover_at(position)
		_invalidate_los_cache()
		terrain_updated.emit(position, type)

func get_terrain(position: Vector2i) -> TerrainTypes.Type:
	if _is_valid_position(position):
		return terrain_map[position.x][position.y]
	return TerrainTypes.Type.INVALID

func add_unit(unit: Character, position: Vector2i) -> bool:
	if not _is_valid_position(position) or _is_position_occupied(position):
		return false
	
	unit_positions[unit] = position
	_update_tactical_advantages(unit)
	unit_added.emit(unit, position)
	return true

func remove_unit(unit: Character) -> void:
	if unit in unit_positions:
		var position = unit_positions[unit]
		unit_positions.erase(unit)
		tactical_advantages.erase(unit)
		unit_removed.emit(unit, position)

func move_unit(unit: Character, new_position: Vector2i) -> bool:
	if not unit in unit_positions or not _is_valid_position(new_position) or _is_position_occupied(new_position):
		return false
	
	var old_position = unit_positions[unit]
	unit_positions[unit] = new_position
	_update_tactical_advantages(unit)
	unit_moved.emit(unit, old_position, new_position)
	return true

func get_unit_at(position: Vector2i) -> Character:
	for unit in unit_positions:
		if unit_positions[unit] == position:
			return unit
	return null

func get_unit_position(unit: Character) -> Vector2i:
	return unit_positions.get(unit, Vector2i(-1, -1))

func get_cover_value(position: Vector2i) -> float:
	if _is_valid_position(position):
		return cover_map[position.x][position.y]
	return 0.0

func has_line_of_sight(from: Vector2i, to: Vector2i) -> bool:
	var cache_key = str(from) + str(to)
	if cache_key in los_cache:
		return los_cache[cache_key]
	
	var result = _calculate_line_of_sight(from, to)
	los_cache[cache_key] = result
	return result

func get_tactical_advantages(unit: Character) -> Dictionary:
	return tactical_advantages.get(unit, {})

func _update_cover_at(position: Vector2i) -> void:
	var terrain_type = get_terrain(position)
	var cover_value = TerrainTypes.get_cover_value(terrain_type)
	cover_map[position.x][position.y] = cover_value
	cover_changed.emit(position, cover_value)

func _update_tactical_advantages(unit: Character) -> void:
	var advantages = {}
	var position = get_unit_position(unit)
	
	# Height advantage
	advantages["height"] = _calculate_height_advantage(position)
	
	# Cover advantage
	advantages["cover"] = get_cover_value(position)
	
	# Flanking advantage
	advantages["flanking"] = _calculate_flanking_advantage(unit)
	
	tactical_advantages[unit] = advantages
	for advantage_type in advantages:
		tactical_advantage_changed.emit(unit, advantage_type, advantages[advantage_type])

func _calculate_height_advantage(position: Vector2i) -> float:
	var terrain_type = get_terrain(position)
	return TerrainTypes.get_elevation(terrain_type)

func _calculate_flanking_advantage(unit: Character) -> float:
	# Implement flanking calculations based on unit positions and facing
	return 0.0

func _calculate_line_of_sight(from: Vector2i, to: Vector2i) -> bool:
	# Implement line of sight calculation using Bresenham's line algorithm
	# and checking for blocking terrain
	return true

func _is_valid_position(position: Vector2i) -> bool:
	return position.x >= 0 and position.x < grid_size.x and \
		   position.y >= 0 and position.y < grid_size.y

func _is_position_occupied(position: Vector2i) -> bool:
	return get_unit_at(position) != null

func _invalidate_los_cache() -> void:
	los_cache.clear()

func world_to_grid(world_position: Vector2) -> Vector2i:
	return Vector2i(int(world_position.x / cell_size), int(world_position.y / cell_size))

func grid_to_world(grid_position: Vector2i) -> Vector2:
	return Vector2(grid_position.x * cell_size + cell_size/2, grid_position.y * cell_size + cell_size/2)
	