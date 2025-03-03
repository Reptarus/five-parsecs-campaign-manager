@tool
extends Node
class_name BaseBattlefieldManager

# Signals
signal terrain_updated(position: Vector2i, new_type: int)
signal unit_moved(unit: Node, from: Vector2i, to: Vector2i)
signal unit_added(unit: Node, position: Vector2i)
signal unit_removed(unit: Node, position: Vector2i)
signal cover_changed(position: Vector2i, cover_value: float)
signal line_of_sight_changed(from: Vector2i, to: Vector2i, blocked: bool)
signal tactical_advantage_changed(unit: Node, advantage_type: int, value: float)
signal deployment_zone_updated(zone_type: int, positions: Array[Vector2i])
signal battlefield_validated(result: Dictionary)
signal terrain_placement_validated(result: Dictionary)

# Configuration
var MOVEMENT_BASE: int = 6 # Base movement points
var GRID_SIZE := Vector2i(24, 24) # Default battlefield size
var CELL_SIZE := Vector2i(32, 32) # Default visual size of each grid cell
var MIN_TERRAIN_PIECES: int = 4 # Minimum terrain requirement
var MAX_TERRAIN_PIECES: int = 12 # Maximum terrain requirement

# Battlefield state
var terrain_map: Array[Array] = [] # Array of terrain types
var unit_positions: Dictionary = {} # Unit: Vector2i
var cover_map: Array[Array] = [] # Array of cover values
var los_cache: Dictionary = {} # Dictionary of line of sight results
var deployment_zones: Dictionary = {} # Dictionary of deployment zones

# Virtual methods to be implemented by derived classes
func initialize_battlefield(size: Vector2i = GRID_SIZE) -> void:
	GRID_SIZE = size
	_create_empty_maps()

func _create_empty_maps() -> void:
	# Initialize terrain map
	terrain_map.clear()
	for x in range(GRID_SIZE.x):
		var column: Array = []
		for y in range(GRID_SIZE.y):
			column.append(0) # Default terrain type (empty)
		terrain_map.append(column)
	
	# Initialize cover map
	cover_map.clear()
	for x in range(GRID_SIZE.x):
		var column: Array = []
		for y in range(GRID_SIZE.y):
			column.append(0.0) # Default cover value (none)
		cover_map.append(column)

# Terrain management
func set_terrain(position: Vector2i, terrain_type: int) -> void:
	if _is_valid_position(position):
		terrain_map[position.x][position.y] = terrain_type
		_update_cover_at_position(position)
		terrain_updated.emit(position, terrain_type)

func get_terrain(position: Vector2i) -> int:
	if _is_valid_position(position):
		return terrain_map[position.x][position.y]
	return 0 # Default terrain type (empty)

# Unit management
func add_unit(unit: Node, position: Vector2i) -> bool:
	if _is_valid_position(position) and not _is_position_occupied(position):
		unit_positions[unit] = position
		unit_added.emit(unit, position)
		return true
	return false

func remove_unit(unit: Node) -> bool:
	if unit in unit_positions:
		var position = unit_positions[unit]
		unit_positions.erase(unit)
		unit_removed.emit(unit, position)
		return true
	return false

func move_unit(unit: Node, new_position: Vector2i) -> bool:
	if unit in unit_positions and _is_valid_position(new_position) and not _is_position_occupied(new_position):
		var old_position = unit_positions[unit]
		unit_positions[unit] = new_position
		unit_moved.emit(unit, old_position, new_position)
		return true
	return false

func get_unit_position(unit: Node) -> Vector2i:
	if unit in unit_positions:
		return unit_positions[unit]
	return Vector2i(-1, -1) # Invalid position

func get_unit_at_position(position: Vector2i) -> Node:
	for unit in unit_positions:
		if unit_positions[unit] == position:
			return unit
	return null

# Cover management
func get_cover_value(position: Vector2i) -> float:
	if _is_valid_position(position):
		return cover_map[position.x][position.y]
	return 0.0

func _update_cover_at_position(position: Vector2i) -> void:
	if _is_valid_position(position):
		var cover_value = _calculate_cover_value(position)
		cover_map[position.x][position.y] = cover_value
		cover_changed.emit(position, cover_value)

func _calculate_cover_value(position: Vector2i) -> float:
	# To be implemented by derived classes
	return 0.0

# Line of sight
func check_line_of_sight(from: Vector2i, to: Vector2i) -> bool:
	var key = str(from) + "-" + str(to)
	if key in los_cache:
		return los_cache[key]
	
	var has_los = _calculate_line_of_sight(from, to)
	los_cache[key] = has_los
	return has_los

func _calculate_line_of_sight(from: Vector2i, to: Vector2i) -> bool:
	# To be implemented by derived classes
	return true

# Utility methods
func _is_valid_position(position: Vector2i) -> bool:
	return position.x >= 0 and position.x < GRID_SIZE.x and position.y >= 0 and position.y < GRID_SIZE.y

func _is_position_occupied(position: Vector2i) -> bool:
	for unit in unit_positions:
		if unit_positions[unit] == position:
			return true
	return false

# Deployment zones
func set_deployment_zone(zone_type: int, positions: Array[Vector2i]) -> void:
	deployment_zones[zone_type] = positions
	deployment_zone_updated.emit(zone_type, positions)

func get_deployment_zone(zone_type: int) -> Array[Vector2i]:
	if zone_type in deployment_zones:
		return deployment_zones[zone_type]
	return []

# Validation
func validate_battlefield() -> Dictionary:
	var result = {
		"valid": true,
		"errors": [],
		"warnings": []
	}
	
	# To be implemented by derived classes
	
	battlefield_validated.emit(result)
	return result

func validate_terrain_placement(terrain_type: int, position: Vector2i) -> Dictionary:
	var result = {
		"valid": true,
		"errors": [],
		"warnings": []
	}
	
	# To be implemented by derived classes
	
	terrain_placement_validated.emit(result)
	return result