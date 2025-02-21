class_name BattlefieldManager
extends Node

const GameEnums := preload("res://src/core/systems/GlobalEnums.gd")
const Character := preload("res://src/core/character/Base/Character.gd")
const TerrainTypes := preload("res://src/core/terrain/TerrainTypes.gd")
const TerrainRules := preload("res://src/core/terrain/TerrainRules.gd")

# Signals
signal terrain_updated(position: Vector2i, new_type: TerrainTypes.Type)
signal unit_moved(unit: Character, from: Vector2i, to: Vector2i)
signal unit_added(unit: Character, position: Vector2i)
signal unit_removed(unit: Character, position: Vector2i)
signal cover_changed(position: Vector2i, cover_value: float)
signal line_of_sight_changed(from: Vector2i, to: Vector2i, blocked: bool)
signal tactical_advantage_changed(unit: Character, advantage_type: GameEnums.CombatAdvantage, value: float)
signal deployment_zone_updated(zone_type: int, positions: Array[Vector2i])
signal battlefield_validated(result: Dictionary)
signal terrain_placement_validated(result: Dictionary)

# Configuration
const MOVEMENT_BASE: int = 6 # Base movement from Core Rules
const GRID_SIZE := Vector2i(24, 24) # Standard battlefield size per core rules
const CELL_SIZE := Vector2i(32, 32) # Visual size of each grid cell
const MIN_TERRAIN_PIECES: int = 4 # Core rules minimum terrain requirement
const MAX_TERRAIN_PIECES: int = 12 # Core rules maximum terrain requirement

# Battlefield state
var terrain_map: Array[Array] = [] # Array of TerrainTypes.Type
var unit_positions: Dictionary = {} # Character: Vector2i
var cover_map: Array[Array] = [] # Array of float values
var los_cache: Dictionary = {} # String: bool
var deployment_zones: Dictionary = {
	"player": [],
	"enemy": [],
	"neutral": [],
	"objective": []
}

# Terrain rules from core rules
var terrain_density_rules := {
	"min_pieces": MIN_TERRAIN_PIECES,
	"max_pieces": MAX_TERRAIN_PIECES,
	"min_cover": 2,
	"max_buildings": 4,
	"max_elevated": 3,
	"max_hazards": 2
}

# Current state
var current_phase: GameEnums.BattlePhase = GameEnums.BattlePhase.SETUP
var selected_tool: GameEnums.TerrainFeatureType = GameEnums.TerrainFeatureType.NONE
var terrain_rules: TerrainRules

func _ready() -> void:
	terrain_rules = TerrainRules.new()
	_initialize_battlefield()

func _initialize_battlefield() -> void:
	# Initialize terrain map
	terrain_map.resize(GRID_SIZE.x)
	for x in range(GRID_SIZE.x):
		terrain_map[x] = []
		terrain_map[x].resize(GRID_SIZE.y)
		for y in range(GRID_SIZE.y):
			terrain_map[x][y] = TerrainTypes.Type.EMPTY
	
	# Initialize cover map
	cover_map.resize(GRID_SIZE.x)
	for x in range(GRID_SIZE.x):
		cover_map[x] = []
		cover_map[x].resize(GRID_SIZE.y)
		for y in range(GRID_SIZE.y):
			cover_map[x][y] = 0.0
	
	_clear_deployment_zones()

func _clear_deployment_zones() -> void:
	for zone in deployment_zones.keys():
		deployment_zones[zone].clear()

# Terrain management
func set_terrain(position: Vector2i, type: TerrainTypes.Type) -> void:
	if not _is_valid_position(position):
		return
	
	var old_type: TerrainTypes.Type = terrain_map[position.x][position.y]
	terrain_map[position.x][position.y] = type
	
	# Update cover and LOS
	_update_cover_value(position)
	_invalidate_los_cache()
	
	terrain_updated.emit(position, type)

func get_terrain(position: Vector2i) -> TerrainTypes.Type:
	if not _is_valid_position(position):
		return TerrainTypes.Type.INVALID
	return terrain_map[position.x][position.y]

func set_terrain_feature(position: Vector2i, feature: GameEnums.TerrainFeatureType) -> void:
	if not _is_valid_position(position):
		return
	
	var terrain_type := _get_terrain_type_for_feature(feature)
	set_terrain(position, terrain_type)

# Unit management
func add_unit(unit: Character, position: Vector2i) -> bool:
	if not _can_place_unit(position):
		return false
	
	unit_positions[unit] = position
	unit_added.emit(unit, position)
	return true

func remove_unit(unit: Character) -> void:
	if unit in unit_positions:
		var position: Vector2i = unit_positions[unit]
		unit_positions.erase(unit)
		unit_removed.emit(unit, position)

func move_unit(unit: Character, new_position: Vector2i) -> bool:
	if not unit in unit_positions or not _can_place_unit(new_position):
		return false
	
	var old_position: Vector2i = unit_positions[unit]
	unit_positions[unit] = new_position
	unit_moved.emit(unit, old_position, new_position)
	return true

func get_unit_at(position: Vector2i) -> Character:
	for unit in unit_positions:
		if unit_positions[unit] == position:
			return unit
	return null

func get_all_units() -> Array[Character]:
	return unit_positions.keys()

# Movement and pathfinding
func get_movement_cost(from: Vector2i, to: Vector2i) -> float:
	if not _is_valid_position(from) or not _is_valid_position(to):
		return INF
	
	var terrain_type: TerrainTypes.Type = get_terrain(to)
	var feature_type: GameEnums.TerrainFeatureType = _get_feature_type_for_terrain(terrain_type)
	var environment: GameEnums.PlanetEnvironment = _terrain_to_environment(terrain_type)
	return terrain_rules.get_movement_cost(environment, feature_type)

func get_movement_range(unit: Character, movement_points: float) -> Array[Vector2i]:
	if not unit in unit_positions:
		return []
	
	var start_pos: Vector2i = unit_positions[unit]
	var reachable: Array[Vector2i] = []
	var visited: Dictionary = {}
	var queue: Array = [[start_pos, movement_points]]
	
	while not queue.is_empty():
		var current: Array = queue.pop_front()
		var pos: Vector2i = current[0]
		var points: float = current[1]
		
		if pos in visited and visited[pos] >= points:
			continue
		
		visited[pos] = points
		reachable.append(pos)
		
		for neighbor in _get_adjacent_positions(pos):
			var cost: float = get_movement_cost(pos, neighbor)
			var remaining: float = points - cost
			if remaining >= 0:
				queue.append([neighbor, remaining])
	
	return reachable

func highlight_movement_range(unit: Character, movement_points: float) -> void:
	var range = get_movement_range(unit, movement_points)
	# Implementation for highlighting would be handled by the UI layer

# Line of sight and cover
func has_line_of_sight(from: Vector2i, to: Vector2i) -> bool:
	var cache_key := "%d,%d-%d,%d" % [from.x, from.y, to.x, to.y]
	if cache_key in los_cache:
		return los_cache[cache_key]
	
	var result := _calculate_line_of_sight(from, to)
	los_cache[cache_key] = result
	return result

func get_cover_value(position: Vector2i) -> float:
	if not _is_valid_position(position):
		return 0.0
	return cover_map[position.x][position.y]

# Deployment zones
func set_deployment_zone(zone_type: int, positions: Array[Vector2i]) -> void:
	if not zone_type in deployment_zones:
		return
	
	deployment_zones[zone_type] = positions
	deployment_zone_updated.emit(zone_type, positions)

func is_valid_deployment_position(position: Vector2i, zone_type: String) -> bool:
	if not zone_type in deployment_zones:
		return false
	return position in deployment_zones[zone_type]

# Validation
func validate_terrain_placement() -> Dictionary:
	var terrain_count = _count_terrain_pieces()
	var validation = {
		"valid": true,
		"messages": []
	}
	
	if terrain_count < terrain_density_rules.min_pieces:
		validation.valid = false
		validation.messages.append("Not enough terrain pieces (minimum %d)" % terrain_density_rules.min_pieces)
	
	if terrain_count > terrain_density_rules.max_pieces:
		validation.valid = false
		validation.messages.append("Too many terrain pieces (maximum %d)" % terrain_density_rules.max_pieces)
	
	terrain_placement_validated.emit(validation)
	return validation

func validate_deployment(units: Array[Character]) -> Dictionary:
	var validation = {
		"valid": true,
		"messages": []
	}
	
	for unit in units:
		if not unit in unit_positions:
			validation.valid = false
			validation.messages.append("Unit not placed: %s" % _get_character_name(unit))
			continue
		
		var position = unit_positions[unit]
		if not is_valid_deployment_position(position, "player"):
			validation.valid = false
			validation.messages.append("Unit outside deployment zone: %s" % _get_character_name(unit))
	
	battlefield_validated.emit(validation)
	return validation

# Helper functions
func _is_valid_position(position: Vector2i) -> bool:
	return position.x >= 0 and position.x < GRID_SIZE.x and position.y >= 0 and position.y < GRID_SIZE.y

func _can_place_unit(position: Vector2i) -> bool:
	if not _is_valid_position(position):
		return false
	
	# Check if position is already occupied
	for unit in unit_positions:
		if unit_positions[unit] == position:
			return false
	
	# Check if terrain allows unit placement
	var terrain_type := get_terrain(position)
	return terrain_type != TerrainTypes.Type.INVALID and terrain_type != TerrainTypes.Type.WALL

func _get_adjacent_positions(position: Vector2i) -> Array[Vector2i]:
	var adjacent: Array[Vector2i] = []
	var directions: Array[Vector2i] = [
		Vector2i(1, 0), Vector2i(-1, 0),
		Vector2i(0, 1), Vector2i(0, -1),
		Vector2i(1, 1), Vector2i(-1, -1),
		Vector2i(1, -1), Vector2i(-1, 1)
	]
	
	for dir in directions:
		var new_pos: Vector2i = position + dir
		if _is_valid_position(new_pos):
			adjacent.append(new_pos)
	
	return adjacent

func _calculate_line_of_sight(from: Vector2i, to: Vector2i) -> bool:
	var dx: int = abs(to.x - from.x)
	var dy: int = abs(to.y - from.y)
	var x: int = from.x
	var y: int = from.y
	var n: int = 1 + dx + dy
	var x_inc: int = 1 if to.x > from.x else -1
	var y_inc: int = 1 if to.y > from.y else -1
	var error: int = dx - dy
	dx *= 2
	dy *= 2
	
	for _i in range(n):
		var terrain_type: TerrainTypes.Type = get_terrain(Vector2i(x, y))
		var feature_type: GameEnums.TerrainFeatureType = _get_feature_type_for_terrain(terrain_type)
		var environment: GameEnums.PlanetEnvironment = _terrain_to_environment(terrain_type)
		if terrain_rules.blocks_line_of_sight(environment, feature_type):
			return false
		
		if error > 0:
			x += x_inc
			error -= dy
		else:
			y += y_inc
			error += dx
	
	return true

func _update_cover_value(position: Vector2i) -> void:
	if not _is_valid_position(position):
		return
	
	var terrain_type: TerrainTypes.Type = get_terrain(position)
	var feature_type: GameEnums.TerrainFeatureType = _get_feature_type_for_terrain(terrain_type)
	var environment: GameEnums.PlanetEnvironment = _terrain_to_environment(terrain_type)
	cover_map[position.x][position.y] = terrain_rules.get_cover_value(environment, feature_type)
	cover_changed.emit(position, cover_map[position.x][position.y])

func _invalidate_los_cache() -> void:
	los_cache.clear()

func _count_terrain_pieces() -> int:
	var count = 0
	for x in range(GRID_SIZE.x):
		for y in range(GRID_SIZE.y):
			if terrain_map[x][y] != TerrainTypes.Type.EMPTY:
				count += 1
	return count

func _get_terrain_type_for_feature(feature: GameEnums.TerrainFeatureType) -> TerrainTypes.Type:
	match feature:
		GameEnums.TerrainFeatureType.WALL:
			return TerrainTypes.Type.WALL
		GameEnums.TerrainFeatureType.COVER:
			return TerrainTypes.Type.COVER_LOW
		GameEnums.TerrainFeatureType.OBSTACLE:
			return TerrainTypes.Type.COVER_HIGH
		GameEnums.TerrainFeatureType.HAZARD:
			return TerrainTypes.Type.HAZARD
		_:
			return TerrainTypes.Type.EMPTY

func _get_feature_type_for_terrain(terrain: TerrainTypes.Type) -> GameEnums.TerrainFeatureType:
	match terrain:
		TerrainTypes.Type.WALL:
			return GameEnums.TerrainFeatureType.WALL
		TerrainTypes.Type.COVER_LOW:
			return GameEnums.TerrainFeatureType.COVER
		TerrainTypes.Type.COVER_HIGH:
			return GameEnums.TerrainFeatureType.OBSTACLE
		TerrainTypes.Type.EMPTY:
			return GameEnums.TerrainFeatureType.NONE
		TerrainTypes.Type.HAZARD:
			return GameEnums.TerrainFeatureType.HAZARD
		_:
			return GameEnums.TerrainFeatureType.NONE

# Add required functions
func blocks_line_of_sight(from: Vector2, to: Vector2) -> bool:
	# Check if line of sight is blocked between two points
	var points = get_line(from, to)
	for point in points:
		var terrain = get_terrain_at(point)
		if terrain == GameEnums.TerrainFeatureType.WALL:
			return true
	return false

# Helper function for line of sight
func get_line(from: Vector2, to: Vector2) -> Array[Vector2]:
	var points: Array[Vector2] = []
	var dx: float = to.x - from.x
	var dy: float = to.y - from.y
	var steps: int = int(max(abs(dx), abs(dy)))
	
	if steps == 0:
		points.append(from)
		return points
	
	var x_inc: float = dx / steps
	var y_inc: float = dy / steps
	
	for i in range(steps + 1):
		points.append(Vector2(
			from.x + (x_inc * i),
			from.y + (y_inc * i)
		))
	
	return points

func get_terrain_at(point: Vector2i) -> TerrainTypes.Type:
	if not _is_valid_position(point):
		return TerrainTypes.Type.INVALID
	return terrain_map[point.x][point.y]

# Add conversion function
func _terrain_to_environment(terrain_type: TerrainTypes.Type) -> GameEnums.PlanetEnvironment:
	match terrain_type:
		TerrainTypes.Type.WALL:
			return GameEnums.PlanetEnvironment.URBAN
		TerrainTypes.Type.COVER_HIGH:
			return GameEnums.PlanetEnvironment.URBAN
		TerrainTypes.Type.COVER_LOW:
			return GameEnums.PlanetEnvironment.URBAN
		TerrainTypes.Type.WATER:
			return GameEnums.PlanetEnvironment.RAIN
		TerrainTypes.Type.HAZARD:
			return GameEnums.PlanetEnvironment.HAZARDOUS
		TerrainTypes.Type.DIFFICULT:
			return GameEnums.PlanetEnvironment.FOREST
		_:
			return GameEnums.PlanetEnvironment.NONE

## Gets the position of a character on the battlefield
func get_character_position(character: FiveParsecsCharacter) -> Vector2:
	if character in unit_positions:
		return Vector2(unit_positions[character].x, unit_positions[character].y)
	return Vector2.ZERO

## Safe Property Access Methods
func _get_character_name(character: Character) -> String:
	if not character:
		push_error("Trying to access name of null character")
		return "Unknown"
	return character.character_name if "character_name" in character else "Unknown"

func _is_character_bot(character: Character) -> bool:
	if not character:
		push_error("Trying to access bot status of null character")
		return false
	return character.is_bot if "is_bot" in character else false

## Gets all player characters on the battlefield
func get_player_characters() -> Array[Character]:
	var players: Array[Character] = []
	for unit in unit_positions.keys():
		if unit is Character and not _is_character_bot(unit):
			players.append(unit)
	return players

## Gets all enemy characters on the battlefield
func get_enemy_characters() -> Array[Character]:
	var enemies: Array[Character] = []
	for unit in unit_positions.keys():
		if unit is Character and _is_character_bot(unit):
			enemies.append(unit)
	return enemies

## Gets the cover value at a position
func get_cover_at_position(position: Vector2) -> float:
	var grid_pos := Vector2i(position)
	if not _is_valid_position(grid_pos):
		return 0.0
	return cover_map[grid_pos.x][grid_pos.y]

## Checks if a position has cover
func position_has_cover(position: Vector2) -> bool:
	return get_cover_at_position(position) > 0.0

## Checks if a position is valid on the battlefield
func is_valid_position(position: Vector2) -> bool:
	var grid_pos := Vector2i(position)
	return grid_pos.x >= 0 and grid_pos.x < GRID_SIZE.x and grid_pos.y >= 0 and grid_pos.y < GRID_SIZE.y

## Checks line of sight between two positions
func check_line_of_sight(from: Vector2, to: Vector2) -> bool:
	var from_grid := Vector2i(from)
	var to_grid := Vector2i(to)
	return has_line_of_sight(from_grid, to_grid)

## Gets characters within a radius of a position
func get_characters_in_radius(center: Vector2, radius: float) -> Array[FiveParsecsCharacter]:
	var in_range: Array[FiveParsecsCharacter] = []
	for unit in unit_positions.keys():
		if unit is FiveParsecsCharacter:
			var unit_pos := Vector2(unit_positions[unit].x, unit_positions[unit].y)
			if center.distance_to(unit_pos) <= radius:
				in_range.append(unit)
	return in_range
