class_name BattlefieldManager
extends Node

const GlobalEnums = preload("res://Resources/GameData/GlobalEnums.gd")
const Character = preload("res://Resources/CrewAndCharacters/Character.gd")
const BattlefieldGenerator = preload("res://Resources/BattlePhase/BattlefieldGenerator.gd")
const Mission = preload("res://Resources/GameData/Mission.gd")

signal cover_state_changed(unit: Character, in_cover: bool)
signal line_of_sight_changed(attacker: Character, target: Character, has_los: bool)
signal movement_validated(unit: Character, path: Array[Vector2], is_valid: bool)
signal terrain_effect_applied(unit: Character, effect: String)

@export var battlefield_generator: BattlefieldGenerator
@export var battle_state_machine: BattleStateMachine

# Battlefield state
var grid_size: Vector2i
var cell_size: Vector2
var terrain_map: Array[Array] = []  # 2D array of terrain types
var unit_positions: Dictionary = {}  # Character -> Vector2
var cover_map: Array[Array] = []    # 2D array of cover values
var height_map: Array[Array] = []   # 2D array of elevation values

# Cache for performance
var _los_cache: Dictionary = {}
var _path_cache: Dictionary = {}

func _ready() -> void:
	if battlefield_generator:
		battlefield_generator.battlefield_generated.connect(_on_battlefield_generated)
		battlefield_generator.terrain_placed.connect(_on_terrain_placed)

func initialize_battlefield(mission: Mission) -> void:
	grid_size = battlefield_generator.grid_size
	cell_size = battlefield_generator.cell_size
	_initialize_maps()
	
	# Convert mission to the format expected by the generator
	var mission_data = {
		"type": mission.type,
		"terrain": mission.terrain,
		"objectives": mission.objectives,
		"deployment": mission.deployment
	}
	
	# Generate battlefield through the existing generator
	battlefield_generator.generate_battlefield(mission)

func _initialize_maps() -> void:
	terrain_map.clear()
	cover_map.clear()
	height_map.clear()
	
	for x in range(grid_size.x):
		terrain_map.append([])
		cover_map.append([])
		height_map.append([])
		for y in range(grid_size.y):
			terrain_map[x].append(0)  # Empty terrain
			cover_map[x].append(0)    # No cover
			height_map[x].append(0)   # Ground level

func register_unit(unit: Character, position: Vector2) -> void:
	unit_positions[unit] = position
	_update_unit_cover_state(unit)
	_invalidate_caches_for_unit(unit)

func unregister_unit(unit: Character) -> void:
	if unit_positions.has(unit):
		unit_positions.erase(unit)
		_invalidate_caches_for_unit(unit)

func validate_movement(unit: Character, path: Array[Vector2]) -> bool:
	if not unit_positions.has(unit):
		return false
	
	# Check path cache
	var cache_key = _get_path_cache_key(unit, path)
	if _path_cache.has(cache_key):
		return _path_cache[cache_key]
	
	# Validate each step of the path
	var current_pos = unit_positions[unit]
	var total_distance = 0.0
	
	for next_pos in path:
		if not _is_position_valid(next_pos):
			_path_cache[cache_key] = false
			return false
		
		var step_distance = current_pos.distance_to(next_pos)
		total_distance += step_distance
		
		if total_distance > unit.get_movement_range():
			_path_cache[cache_key] = false
			return false
		
		current_pos = next_pos
	
	_path_cache[cache_key] = true
	return true

func check_line_of_sight(attacker: Character, target: Character) -> bool:
	if not (unit_positions.has(attacker) and unit_positions.has(target)):
		return false
	
	# Check LOS cache
	var cache_key = _get_los_cache_key(attacker, target)
	if _los_cache.has(cache_key):
		return _los_cache[cache_key]
	
	var start_pos = unit_positions[attacker]
	var end_pos = unit_positions[target]
	
	# Implement Bresenham's line algorithm for LOS check
	var has_los = _check_line_of_sight_path(start_pos, end_pos)
	_los_cache[cache_key] = has_los
	
	line_of_sight_changed.emit(attacker, target, has_los)
	return has_los

func get_cover_bonus(unit: Character) -> int:
	if not unit_positions.has(unit):
		return 0
	
	var pos = unit_positions[unit]
	var grid_pos = _world_to_grid(pos)
	
	if not _is_valid_grid_position(grid_pos):
		return 0
	
	return cover_map[grid_pos.x][grid_pos.y]

func get_elevation_bonus(attacker: Character, defender: Character) -> int:
	if not (unit_positions.has(attacker) and unit_positions.has(defender)):
		return 0
	
	var attacker_pos = _world_to_grid(unit_positions[attacker])
	var defender_pos = _world_to_grid(unit_positions[defender])
	
	if not (_is_valid_grid_position(attacker_pos) and _is_valid_grid_position(defender_pos)):
		return 0
	
	var height_diff = height_map[attacker_pos.x][attacker_pos.y] - height_map[defender_pos.x][defender_pos.y]
	return height_diff

func _on_battlefield_generated(data: Dictionary) -> void:
	grid_size = data.grid_size
	cell_size = data.cell_size
	_initialize_maps()
	
	# Process terrain data
	for terrain in data.terrain:
		var grid_pos = _world_to_grid(Vector2(terrain.position.x, terrain.position.z))
		if _is_valid_grid_position(grid_pos):
			terrain_map[grid_pos.x][grid_pos.y] = terrain.type
			cover_map[grid_pos.x][grid_pos.y] = terrain.cover_value
			height_map[grid_pos.x][grid_pos.y] = terrain.elevation

func _on_terrain_placed(piece: Node3D) -> void:
	var piece_pos = Vector2(piece.position.x, piece.position.z)
	var grid_pos = _world_to_grid(piece_pos)
	if _is_valid_grid_position(grid_pos):
		# Update terrain maps based on the placed piece
		_update_terrain_at_position(grid_pos, piece)

func _update_terrain_at_position(grid_pos: Vector2i, terrain_piece: Node3D) -> void:
	# Update terrain maps based on the terrain piece properties
	# This implementation will depend on your terrain piece structure
	pass

func _update_unit_cover_state(unit: Character) -> void:
	if not unit_positions.has(unit):
		return
	
	var pos = unit_positions[unit]
	var grid_pos = _world_to_grid(pos)
	var in_cover = cover_map[grid_pos.x][grid_pos.y] > 0
	
	cover_state_changed.emit(unit, in_cover)

func _check_line_of_sight_path(start: Vector2, end: Vector2) -> bool:
	var start_grid = _world_to_grid(start)
	var end_grid = _world_to_grid(end)
	
	# Bresenham's line algorithm
	var dx = abs(end_grid.x - start_grid.x)
	var dy = abs(end_grid.y - start_grid.y)
	var x = start_grid.x
	var y = start_grid.y
	var step_x = 1 if end_grid.x > start_grid.x else -1
	var step_y = 1 if end_grid.y > start_grid.y else -1
	var err = dx - dy
	
	while x != end_grid.x or y != end_grid.y:
		if _blocks_line_of_sight(Vector2i(x, y)):
			return false
		
		var err2 = 2 * err
		if err2 > -dy:
			err -= dy
			x += step_x
		if err2 < dx:
			err += dx
			y += step_y
	
	return true

func _blocks_line_of_sight(grid_pos: Vector2i) -> bool:
	if not _is_valid_grid_position(grid_pos):
		return true
	
	# Check if terrain at this position blocks LOS
	# This will depend on your terrain types
	return false

func _world_to_grid(pos: Vector2) -> Vector2i:
	return Vector2i(
		floor(pos.x / cell_size.x),
		floor(pos.y / cell_size.y)
	)

func _grid_to_world(grid_pos: Vector2i) -> Vector2:
	return Vector2(
		grid_pos.x * cell_size.x + cell_size.x / 2,
		grid_pos.y * cell_size.y + cell_size.y / 2
	)

func _is_valid_grid_position(pos: Vector2i) -> bool:
	return pos.x >= 0 and pos.x < grid_size.x and pos.y >= 0 and pos.y < grid_size.y

func _is_position_valid(pos: Vector2) -> bool:
	var grid_pos = _world_to_grid(pos)
	return _is_valid_grid_position(grid_pos) and terrain_map[grid_pos.x][grid_pos.y] != -1  # -1 represents impassable terrain

func _get_los_cache_key(attacker: Character, target: Character) -> String:
	return "%s_%s" % [attacker.get_instance_id(), target.get_instance_id()]

func _get_path_cache_key(unit: Character, path: Array[Vector2]) -> String:
	return "%s_%s" % [unit.get_instance_id(), path.hash()]

func _invalidate_caches_for_unit(unit: Character) -> void:
	# Clear cached LOS calculations involving this unit
	var invalid_keys = []
	for key in _los_cache:
		if key.begins_with(str(unit.get_instance_id())):
			invalid_keys.append(key)
	
	for key in invalid_keys:
		_los_cache.erase(key)
	
	# Clear cached paths for this unit
	invalid_keys.clear()
	for key in _path_cache:
		if key.begins_with(str(unit.get_instance_id())):
			invalid_keys.append(key)
	
	for key in invalid_keys:
		_path_cache.erase(key) 