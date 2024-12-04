class_name BattlefieldManager
extends Node

const GlobalEnums = preload("res://Resources/GameData/GlobalEnums.gd")
const Character = preload("res://Resources/CrewAndCharacters/Character.gd")
const BattlefieldGenerator = preload("res://Resources/BattlePhase/BattlefieldGenerator.gd")
const Mission = preload("res://Resources/GameData/Mission.gd")
const TerrainTypes = preload("res://Battle/TerrainTypes.gd")

signal cover_state_changed(unit: Character, in_cover: bool, cover_type: int)
signal line_of_sight_changed(attacker: Character, target: Character, has_los: bool)
signal movement_validated(unit: Character, path: Array[Vector2], is_valid: bool)
signal terrain_effect_applied(unit: Character, effect: String)
signal unit_entered_zone(unit: Character, zone_type: String)
signal tactical_advantage_changed(unit: Character, advantage_type: String, value: float)

@export var battlefield_generator: BattlefieldGenerator
@export var battle_state_machine: BattleStateMachine

# Battlefield state
var grid_size: Vector2i
var cell_size: Vector2
var terrain_map: Array[Array] = []  # 2D array of terrain types
var unit_positions: Dictionary = {}  # Character -> Vector2
var cover_map: Array[Array] = []    # 2D array of cover values
var height_map: Array[Array] = []   # 2D array of elevation values
var zone_map: Array[Array] = []     # 2D array of tactical zones
var objective_positions: Array[Vector2] = []

# Tactical zones
enum TacticalZone {
	NEUTRAL,
	CONTROL_POINT,
	DEPLOYMENT,
	HAZARD,
	VANTAGE_POINT,
	CHOKE_POINT
}

# Cache for performance
var _los_cache: Dictionary = {}
var _path_cache: Dictionary = {}
var _threat_cache: Dictionary = {}
var _advantage_cache: Dictionary = {}

# Movement directions for pathfinding and tactical analysis
var _movement_directions := [
	Vector2i(1, 0),   # Right
	Vector2i(-1, 0),  # Left
	Vector2i(0, 1),   # Down
	Vector2i(0, -1),  # Up
	Vector2i(1, 1),   # Down-Right
	Vector2i(-1, 1),  # Down-Left
	Vector2i(1, -1),  # Up-Right
	Vector2i(-1, -1)  # Up-Left
]

# Tactical zones for strategic control
var tactical_zones: Array[Dictionary] = []

func _ready() -> void:
	if battlefield_generator:
		battlefield_generator.battlefield_generated.connect(_on_battlefield_generated)
		battlefield_generator.terrain_placed.connect(_on_terrain_placed)

func initialize_battlefield(mission: Mission) -> void:
	grid_size = battlefield_generator.grid_size
	cell_size = battlefield_generator.cell_size
	_initialize_maps()
	_initialize_tactical_zones(mission)
	
	# Store objective positions
	objective_positions.clear()
	for objective in mission.objectives:
		objective_positions.append(objective.position)
	
	# Generate battlefield through the existing generator
	battlefield_generator.generate_battlefield(mission)
	_update_tactical_analysis()

func _initialize_maps() -> void:
	terrain_map.clear()
	cover_map.clear()
	height_map.clear()
	zone_map.clear()
	
	for x in range(grid_size.x):
		terrain_map.append([])
		cover_map.append([])
		height_map.append([])
		zone_map.append([])
		for y in range(grid_size.y):
			terrain_map[x].append(TerrainTypes.Type.EMPTY)
			cover_map[x].append(0)
			height_map[x].append(0)
			zone_map[x].append(TacticalZone.NEUTRAL)

func get_units_in_range(position: Vector2, range: float, friendly: bool = true) -> Array[Character]:
	var units: Array[Character] = []
	for unit in unit_positions.keys():
		if unit.is_friendly() == friendly:
			var distance = position.distance_to(unit_positions[unit])
			if distance <= range:
				units.append(unit)
	return units

func get_flanking_positions(target: Character) -> Array[Vector2]:
	if not unit_positions.has(target):
		return []
		
	var target_pos = unit_positions[target]
	var facing = target.get_facing_direction()
	var flanking_positions: Array[Vector2] = []
	
	# Check positions in a 120-degree arc behind the target
	for angle in range(-150, 151, 30):
		var check_dir = facing.rotated(deg_to_rad(angle))
		var check_pos = target_pos + check_dir * 2.0  # 2 units behind target
		
		if _is_position_valid(check_pos) and not _is_position_occupied(check_pos):
			flanking_positions.append(check_pos)
	
	return flanking_positions

func get_tactical_advantage(unit: Character) -> float:
	if not unit_positions.has(unit):
		return 0.0
		
	var pos = unit_positions[unit]
	var grid_pos = _world_to_grid(pos)
	var advantage = 0.0
	
	# Height advantage
	advantage += height_map[grid_pos.x][grid_pos.y] * 0.5
	
	# Cover bonus
	advantage += cover_map[grid_pos.x][grid_pos.y] * 0.3
	
	# Zone control
	match zone_map[grid_pos.x][grid_pos.y]:
		TacticalZone.VANTAGE_POINT:
			advantage += 1.0
		TacticalZone.CONTROL_POINT:
			advantage += 0.5
		TacticalZone.CHOKE_POINT:
			advantage -= 0.5
	
	return advantage

func apply_terrain_effects(unit: Character) -> void:
	if not unit_positions.has(unit):
		return
		
	var pos = _world_to_grid(unit_positions[unit])
	var terrain_type = terrain_map[pos.x][pos.y]
	
	match terrain_type:
		TerrainTypes.Type.HAZARDOUS:
			var damage = TerrainTypes.get_hazard_damage(terrain_type)
			if damage > 0:
				unit.take_damage(damage)
				terrain_effect_applied.emit(unit, "hazard_damage")
		TerrainTypes.Type.DIFFICULT:
			unit.apply_movement_penalty(0.5)
			terrain_effect_applied.emit(unit, "movement_penalty")

func get_optimal_path(unit: Character, target_pos: Vector2) -> Array[Vector2]:
	var start_pos = unit_positions[unit]
	var path_finder = PathFinder.new(self)
	return path_finder.find_path(start_pos, target_pos, unit.get_movement_range())

func _update_tactical_analysis() -> void:
	_update_threat_map()
	_update_advantage_points()
	_identify_choke_points()
	_update_control_zones()

func _update_threat_map() -> void:
	_threat_cache.clear()
	for unit in unit_positions.keys():
		var threat_range = unit.get_attack_range()
		var threat_value = unit.get_threat_value()
		
		for x in range(grid_size.x):
			for y in range(grid_size.y):
				var pos = _grid_to_world(Vector2i(x, y))
				var distance = pos.distance_to(unit_positions[unit])
				if distance <= threat_range:
					var threat = threat_value * (1.0 - distance / threat_range)
					_threat_cache[Vector2i(x, y)] = _threat_cache.get(Vector2i(x, y), 0.0) + threat

func _identify_choke_points() -> void:
	for x in range(1, grid_size.x - 1):
		for y in range(1, grid_size.y - 1):
			if _is_choke_point(Vector2i(x, y)):
				zone_map[x][y] = TacticalZone.CHOKE_POINT

func _is_choke_point(pos: Vector2i) -> bool:
	var walkable_neighbors = 0
	var directions = [Vector2i(1,0), Vector2i(-1,0), Vector2i(0,1), Vector2i(0,-1)]
	
	for dir in directions:
		var check_pos = pos + dir
		if _is_valid_grid_position(check_pos) and not TerrainTypes.blocks_movement(terrain_map[check_pos.x][check_pos.y]):
			walkable_neighbors += 1
	
	return walkable_neighbors == 2

func _is_position_occupied(pos: Vector2) -> bool:
	for unit_pos in unit_positions.values():
		if unit_pos.distance_to(pos) < 1.0:  # Using 1.0 as minimum unit spacing
			return true
	return false

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
	
	cover_state_changed.emit(unit, in_cover, cover_map[grid_pos.x][grid_pos.y])

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

func _update_advantage_points() -> void:
	_advantage_cache.clear()
	
	for x in range(grid_size.x):
		for y in range(grid_size.y):
			var pos = Vector2i(x, y)
			var advantage = 0.0
			
			# Calculate height advantage
			advantage += height_map[x][y] * 0.5
			
			# Calculate cover value
			advantage += cover_map[x][y] * 0.3
			
			# Calculate strategic value
			advantage += _calculate_strategic_value(pos)
			
			_advantage_cache[pos] = advantage

func _update_control_zones() -> void:
	var contested_positions = []
	
	# Find contested positions
	for unit in unit_positions.keys():
		var control_range = unit.get_control_range()
		var positions = get_positions_in_range(unit_positions[unit], control_range)
		
		for pos in positions:
			if not contested_positions.has(pos):
				contested_positions.append(pos)
	
	# Update zone control
	for pos in contested_positions:
		_update_zone_control(pos)

func _calculate_strategic_value(pos: Vector2i) -> float:
	var value = 0.0
	
	# Distance to objectives
	for obj_pos in objective_positions:
		var distance = Vector2(pos).distance_to(obj_pos)
		value += 1.0 / max(distance, 1.0)
	
	# Line of sight value
	value += _calculate_los_value(pos)
	
	# Movement options value
	value += _calculate_movement_value(pos)
	
	return value

func get_positions_in_range(center: Vector2, range: float) -> Array[Vector2]:
	var positions: Array[Vector2] = []
	var range_squared = range * range
	
	for x in range(-int(range), int(range) + 1):
		for y in range(-int(range), int(range) + 1):
			var check_pos = center + Vector2(x, y)
			if check_pos.distance_squared_to(center) <= range_squared:
				if _is_position_valid(check_pos):
					positions.append(check_pos)
	
	return positions

func _initialize_tactical_zones(mission: Mission) -> void:
	# Initialize control zones and strategic points
	var zones = []
	
	# Add objective-based zones
	for objective in mission.objectives:
		zones.append(_create_tactical_zone(objective.position, objective.radius))
	
	# Add strategic points based on terrain
	for x in range(grid_size.x):
		for y in range(grid_size.y):
			var pos = Vector2i(x, y)
			if _is_strategic_position(pos):
				zones.append(_create_tactical_zone(pos, 2))

func _update_zone_control(pos: Vector2i) -> void:
	var friendly_power = 0.0
	var enemy_power = 0.0
	
	# Calculate power in zone
	for unit in unit_positions.keys():
		var unit_pos = _world_to_grid(unit_positions[unit])
		if unit_pos.distance_to(Vector2(pos)) <= 3:  # Zone radius
			var power = _calculate_unit_power(unit)
			if unit.is_enemy():
				enemy_power += power
			else:
				friendly_power += power
	
	# Update control status
	if friendly_power > enemy_power * 1.5:
		_set_zone_control(pos, "friendly")
	elif enemy_power > friendly_power * 1.5:
		_set_zone_control(pos, "enemy")
	else:
		_set_zone_control(pos, "contested")

func _calculate_los_value(pos: Vector2i) -> float:
	var value = 0.0
	var visible_positions = 0
	
	# Check line of sight to key positions
	for x in range(grid_size.x):
		for y in range(grid_size.y):
			var target_pos = Vector2i(x, y)
			if _check_line_of_sight_path(pos, target_pos):
				visible_positions += 1
				if _is_strategic_position(target_pos):
					value += 2.0
	
	return value * (float(visible_positions) / (grid_size.x * grid_size.y))

func _calculate_movement_value(pos: Vector2i) -> float:
	var value = 0.0
	var accessible_positions = 0
	
	# Check movement options in 5-tile radius
	for x in range(max(0, pos.x - 5), min(grid_size.x, pos.x + 6)):
		for y in range(max(0, pos.y - 5), min(grid_size.y, pos.y + 6)):
			var target_pos = Vector2i(x, y)
			if _is_position_valid(Vector2(target_pos)):
				accessible_positions += 1
				if _is_strategic_position(target_pos):
					value += 1.0
	
	return value * (float(accessible_positions) / 25.0)  # Normalize by max possible positions

func _is_strategic_position(pos: Vector2i) -> bool:
	if not _is_valid_grid_position(pos):
		return false
	
	var terrain_type = terrain_map[pos.x][pos.y]
	
	# High ground is strategic
	if TerrainTypes.get_elevation(terrain_type) > 0:
		return true
	
	# Good cover positions are strategic
	if TerrainTypes.get_cover_value(terrain_type) >= 2:
		return true
	
	# Positions controlling multiple paths are strategic
	var adjacent_paths = 0
	for dir in _movement_directions:
		var check_pos = pos + dir
		if _is_valid_grid_position(check_pos) and not TerrainTypes.blocks_movement(terrain_map[check_pos.x][check_pos.y]):
			adjacent_paths += 1
	
	return adjacent_paths >= 3

func _create_tactical_zone(center: Vector2i, radius: int) -> Dictionary:
	return {
		"center": center,
		"radius": radius,
		"control": "neutral",
		"strategic_value": _calculate_strategic_value(center)
	}

func _set_zone_control(pos: Vector2i, control: String) -> void:
	for zone in tactical_zones:
		if zone.center == pos:
			zone.control = control
			break

func _calculate_unit_power(unit: Character) -> float:
	var power = unit.get_combat_power()
	
	# Modify power based on position
	var pos = _world_to_grid(unit_positions[unit])
	var terrain_type = terrain_map[pos.x][pos.y]
	
	# Elevation bonus
	power *= (1.0 + 0.2 * TerrainTypes.get_elevation(terrain_type))
	
	# Cover bonus
	power *= (1.0 + 0.1 * TerrainTypes.get_cover_value(terrain_type))
	
	# Health factor
	power *= float(unit.get_current_health()) / unit.get_max_health()
	
	return power
	