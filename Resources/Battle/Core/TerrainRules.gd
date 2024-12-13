## TerrainRules
# Enforces Core Rules terrain mechanics and validation.
# Handles terrain placement rules, deployment zone validation, and terrain-specific rules.
class_name TerrainRules
extends RefCounted

const TerrainTypes = preload("res://Resources/Battle/Core/TerrainTypes.gd")

## Core Rules Constants
# Minimum distance required between terrain features
const MIN_DISTANCE_BETWEEN_FEATURES := 3
# Maximum number of terrain features allowed in an area
const MAX_FEATURES_PER_AREA := 5
# Minimum number of terrain features required in an area
const MIN_FEATURES_PER_AREA := 2
# Minimum distance required from deployment zones
const MIN_DISTANCE_FROM_DEPLOYMENT := 4

## Public Methods

# Validates terrain placement according to Core Rules
# Parameters:
# - terrain_map: Array - Current terrain layout
# - position: Vector2 - Position to check
# - terrain_type: TerrainTypes.Type - Type of terrain to place
# Returns: bool - Whether placement is valid
static func validate_terrain_placement(terrain_map: Array[Array], position: Vector2, terrain_type: TerrainTypes.Type) -> bool:
	if terrain_map.is_empty() or not _is_valid_position(terrain_map, position):
		push_error("Invalid terrain map or position")
		return false
		
	# Check spacing between features
	if not _check_feature_spacing(terrain_map, position):
		return false
	
	# Check terrain type specific rules
	match terrain_type:
		TerrainTypes.Type.WALL:
			return _validate_wall_placement(terrain_map, position)
		TerrainTypes.Type.HIGH_GROUND, TerrainTypes.Type.ELEVATION_HIGH:
			return _validate_elevation_placement(terrain_map, position)
		TerrainTypes.Type.WATER:
			return _validate_water_placement(terrain_map, position)
		TerrainTypes.Type.HAZARD:
			return _validate_hazard_placement(terrain_map, position)
		_:
			return true

# Validates deployment zone according to Core Rules
# Parameters:
# - terrain_map: Array - Current terrain layout
# - zone: Rect2 - Deployment zone to validate
# Returns: bool - Whether deployment zone is valid
static func validate_deployment_zone(terrain_map: Array[Array], zone: Rect2) -> bool:
	if terrain_map.is_empty():
		push_error("Invalid terrain map")
		return false
		
	var blocked_count := 0
	var total_cells := int(zone.size.x * zone.size.y)
	
	for x in range(zone.position.x, zone.position.x + zone.size.x):
		for y in range(zone.position.y, zone.position.y + zone.size.y):
			var pos := Vector2(x, y)
			if not _is_valid_position(terrain_map, pos):
				continue
			
			var terrain_type := terrain_map[pos.x][pos.y] as TerrainTypes.Type
			if TerrainTypes.blocks_movement(terrain_type):
				blocked_count += 1
	
	# Deployment zone shouldn't be more than 25% blocked
	return (blocked_count / float(total_cells)) <= 0.25

## Private Methods

# Checks minimum spacing between terrain features
static func _check_feature_spacing(terrain_map: Array[Array], position: Vector2) -> bool:
	for x in range(max(0, position.x - MIN_DISTANCE_BETWEEN_FEATURES), 
					min(terrain_map.size(), position.x + MIN_DISTANCE_BETWEEN_FEATURES + 1)):
		for y in range(max(0, position.y - MIN_DISTANCE_BETWEEN_FEATURES),
					min(terrain_map[0].size(), position.y + MIN_DISTANCE_BETWEEN_FEATURES + 1)):
			if terrain_map[x][y] != TerrainTypes.Type.EMPTY:
				return false
	return true

# Validates wall placement according to Core Rules
static func _validate_wall_placement(terrain_map: Array[Array], position: Vector2) -> bool:
	# Walls shouldn't completely block paths
	var neighbors := _get_neighbors(position)
	var blocked_neighbors := 0
	
	for neighbor in neighbors:
		if not _is_valid_position(terrain_map, neighbor):
			continue
		if TerrainTypes.blocks_movement(terrain_map[neighbor.x][neighbor.y]):
			blocked_neighbors += 1
	
	return blocked_neighbors < 2

# Validates elevation placement according to Core Rules
static func _validate_elevation_placement(terrain_map: Array[Array], position: Vector2) -> bool:
	# Elevated terrain should be accessible
	var neighbors := _get_neighbors(position)
	var accessible := false
	
	for neighbor in neighbors:
		if not _is_valid_position(terrain_map, neighbor):
			continue
		if not TerrainTypes.blocks_movement(terrain_map[neighbor.x][neighbor.y]):
			accessible = true
			break
	
	return accessible

# Validates water placement according to Core Rules
static func _validate_water_placement(terrain_map: Array[Array], position: Vector2) -> bool:
	# Water features should form continuous bodies
	var neighbors := _get_neighbors(position)
	var water_neighbors := 0
	
	for neighbor in neighbors:
		if not _is_valid_position(terrain_map, neighbor):
			continue
		if terrain_map[neighbor.x][neighbor.y] == TerrainTypes.Type.WATER:
			water_neighbors += 1
	
	return water_neighbors > 0

# Validates hazard placement according to Core Rules
static func _validate_hazard_placement(terrain_map: Array[Array], position: Vector2) -> bool:
	# Hazards shouldn't block critical paths
	return _validate_wall_placement(terrain_map, position)

# Gets adjacent positions
static func _get_neighbors(position: Vector2) -> Array[Vector2]:
	return [
		Vector2(position.x + 1, position.y),
		Vector2(position.x - 1, position.y),
		Vector2(position.x, position.y + 1),
		Vector2(position.x, position.y - 1)
	]

# Validates position is within terrain map bounds
static func _is_valid_position(terrain_map: Array[Array], pos: Vector2) -> bool:
	return pos.x >= 0 and pos.x < terrain_map.size() and pos.y >= 0 and pos.y < terrain_map[0].size() 