class_name BattlefieldGenerator
extends Node

const GameEnums := preload("res://src/core/systems/GlobalEnums.gd")
const TerrainTypes := preload("res://src/core/terrain/TerrainTypes.gd")

# Signals
signal terrain_generated(terrain_data: Dictionary)
signal deployment_zones_created(zones: Array[Dictionary])
signal objectives_placed(objectives: Array[Dictionary])

# Constants
const MIN_BATTLEFIELD_SIZE := Vector2i(16, 16)
const MAX_BATTLEFIELD_SIZE := Vector2i(32, 32)
const MIN_COVER_DENSITY := 0.1 # 10% of tiles should be cover
const MAX_COVER_DENSITY := 0.3 # 30% of tiles should be cover
const MIN_DISTANCE_BETWEEN_COVER := 2 # Minimum tiles between cover pieces
const MIN_DEPLOYMENT_ZONE_SIZE := 4 # Minimum size of deployment zones

# Generation configuration
var config: Dictionary = {
	"size": Vector2i(24, 24),
	"battlefield_type": GameEnums.BattlefieldType.URBAN,
	"environment": GameEnums.BattleEnvironment.URBAN,
	"cover_density": 0.2,
	"symmetrical": true,
	"deployment_zone_size": 6,
	"objective_count": 1
}

# Battlefield state
var terrain_grid: Array[Array] = [] # Array of Arrays of TerrainCell
var deployment_zones: Dictionary = {} # String: Array[Vector2i]
var objectives: Array[Dictionary] = []
var cover_points: Array[Vector2i] = []
var walkable_tiles: Array[Vector2i] = []

class TerrainCell:
	var type: TerrainTypes.Type = TerrainTypes.Type.NONE
	var walkable: bool = true
	var cover: bool = false
	var elevation: int = 0
	var objective: bool = false
	var feature: GameEnums.BattlefieldFeature = GameEnums.BattlefieldFeature.NONE
	var zone: GameEnums.BattlefieldZone = GameEnums.BattlefieldZone.NEUTRAL

	func serialize() -> Dictionary:
		return {
			"type": type,
			"walkable": walkable,
			"cover": cover,
			"elevation": elevation,
			"objective": objective,
			"feature": feature,
			"zone": zone
		}

func generate_battlefield(generation_config: Dictionary = {}) -> Dictionary:
	# Merge provided config with defaults
	for key in generation_config:
		config[key] = generation_config[key]
	
	# Validate config
	_validate_config()
	
	# Initialize battlefield
	_initialize_grid()
	
	# Generate terrain based on environment
	_generate_terrain()
	
	# Create deployment zones
	_create_deployment_zones()
	
	# Place objectives
	_place_objectives()
	
	# Return complete battlefield data
	return {
		"size": config.size,
		"battlefield_type": config.battlefield_type,
		"environment": config.environment,
		"terrain": _serialize_terrain(),
		"deployment_zones": deployment_zones,
		"objectives": objectives,
		"walkable_tiles": walkable_tiles
	}

func _validate_config() -> void:
	# Ensure size is within bounds
	config.size.x = clampi(config.size.x, MIN_BATTLEFIELD_SIZE.x, MAX_BATTLEFIELD_SIZE.x)
	config.size.y = clampi(config.size.y, MIN_BATTLEFIELD_SIZE.y, MAX_BATTLEFIELD_SIZE.y)
	
	# Validate cover density
	config.cover_density = clampf(config.cover_density, MIN_COVER_DENSITY, MAX_COVER_DENSITY)
	
	# Ensure deployment zone size is valid
	config.deployment_zone_size = clampi(config.deployment_zone_size, MIN_DEPLOYMENT_ZONE_SIZE, config.size.y / 3)

func _initialize_grid() -> void:
	terrain_grid.clear()
	walkable_tiles.clear()
	cover_points.clear()
	
	# Create empty grid
	for x in range(config.size.x):
		terrain_grid.append([])
		for y in range(config.size.y):
			var cell := TerrainCell.new()
			terrain_grid[x].append(cell)
			walkable_tiles.append(Vector2i(x, y))

func _serialize_terrain() -> Array[Dictionary]:
	var serialized: Array[Dictionary] = []
	for x in range(config.size.x):
		var row: Array[Dictionary] = []
		for y in range(config.size.y):
			row.append(terrain_grid[x][y].serialize())
		serialized.append({"row": row})
	return serialized

func _generate_terrain() -> void:
	match config.environment:
		GameEnums.BattleEnvironment.URBAN:
			_generate_urban_terrain()
		GameEnums.BattleEnvironment.WILDERNESS:
			_generate_wilderness_terrain()
		GameEnums.BattleEnvironment.SPACE_STATION:
			_generate_space_station_terrain()
		GameEnums.BattleEnvironment.SHIP_INTERIOR:
			_generate_ship_interior_terrain()
		_:
			_generate_basic_terrain()
	
	terrain_generated.emit(_serialize_terrain())

func _create_deployment_zones() -> void:
	var zone_size: int = config.deployment_zone_size as int
	
	# Player deployment zone (bottom)
	deployment_zones["player"] = _create_zone(
		Vector2i(0, config.size.y - zone_size),
		Vector2i(config.size.x, zone_size)
	)
	
	# Enemy deployment zone (top)
	deployment_zones["enemy"] = _create_zone(
		Vector2i(0, 0),
		Vector2i(config.size.x, zone_size)
	)
	
	# Optional neutral zone (middle)
	if config.get("create_neutral_zone", false):
		var neutral_y = (config.size.y - zone_size) / 2
		deployment_zones["neutral"] = _create_zone(
			Vector2i(0, neutral_y),
			Vector2i(config.size.x, zone_size)
		)
	
	deployment_zones_created.emit(deployment_zones.values())

func _place_objectives() -> void:
	objectives.clear()
	
	var objective_count: int = config.objective_count as int
	var available_positions := _get_valid_objective_positions()
	
	for i in range(objective_count):
		if available_positions.is_empty():
			break
		
		var pos_index := randi() % available_positions.size()
		var position := available_positions[pos_index]
		available_positions.remove_at(pos_index)
		
		var objective := {
			"position": position,
			"type": GameEnums.BattleObjective.CAPTURE_POINT,
			"radius": 2,
			"control_points": 0,
			"controlled_by": "none"
		}
		
		objectives.append(objective)
		
		# Mark area around objective as special
		for x in range(max(0, position.x - 1), min(config.size.x, position.x + 2)):
			for y in range(max(0, position.y - 1), min(config.size.y, position.y + 2)):
				terrain_grid[x][y].objective = true
	
	objectives_placed.emit(objectives)

# Environment-specific generation
func _generate_urban_terrain() -> void:
	# Generate buildings
	var building_count := randi_range(3, 6)
	for i in range(building_count):
		_place_building()
	
	# Add street cover
	var cover_count := int(walkable_tiles.size() * config.cover_density)
	for i in range(cover_count):
		_place_cover(TerrainTypes.Type.COVER_LOW)

func _generate_wilderness_terrain() -> void:
	# Generate elevation variations
	_generate_elevation_noise()
	
	# Add natural cover (trees, rocks)
	var cover_count := int(walkable_tiles.size() * config.cover_density * 1.5)
	for i in range(cover_count):
		if randf() < 0.7:
			_place_cover(TerrainTypes.Type.COVER_HIGH)
		else:
			_place_cover(TerrainTypes.Type.COVER_LOW)

func _generate_space_station_terrain() -> void:
	# Generate corridors and rooms
	_generate_space_station_layout()
	
	# Add cover points
	var cover_count := int(walkable_tiles.size() * config.cover_density * 0.8)
	for i in range(cover_count):
		_place_cover(TerrainTypes.Type.COVER_LOW)

func _generate_ship_interior_terrain() -> void:
	# Generate ship layout
	_generate_ship_layout()
	
	# Add cover points
	var cover_count := int(walkable_tiles.size() * config.cover_density * 0.7)
	for i in range(cover_count):
		_place_cover(TerrainTypes.Type.COVER_LOW)

func _generate_basic_terrain() -> void:
	# Simple random cover placement
	var cover_count := int(walkable_tiles.size() * config.cover_density)
	for i in range(cover_count):
		_place_cover(TerrainTypes.Type.COVER_LOW)

# Helper functions
func _place_building() -> void:
	var size: Vector2i = Vector2i(
		randi_range(2, 4),
		randi_range(2, 4)
	)
	
	var valid_positions: Array[Vector2i] = _get_valid_building_positions(size)
	if valid_positions.is_empty():
		return
	
	var position: Vector2i = valid_positions[randi() % valid_positions.size()]
	
	# Place building walls
	for x in range(position.x, position.x + size.x):
		for y in range(position.y, position.y + size.y):
			if x == position.x or x == position.x + size.x - 1 or \
			   y == position.y or y == position.y + size.y - 1:
				terrain_grid[x][y].type = TerrainTypes.Type.WALL
				terrain_grid[x][y].walkable = false
				walkable_tiles.erase(Vector2i(x, y))
			else:
				terrain_grid[x][y].type = TerrainTypes.Type.NONE
				terrain_grid[x][y].elevation = 0

func _place_cover(cover_type: TerrainTypes.Type) -> void:
	var valid_positions := _get_valid_cover_positions()
	if valid_positions.is_empty():
		return
	
	var position := valid_positions[randi() % valid_positions.size()]
	terrain_grid[position.x][position.y].type = cover_type
	terrain_grid[position.x][position.y].cover = true
	cover_points.append(position)

func _generate_elevation_noise() -> void:
	# Simple random elevation for now
	# TODO: Implement proper noise generation
	for x in range(config.size.x):
		for y in range(config.size.y):
			if randf() < 0.2:
				terrain_grid[x][y].elevation = randi_range(1, 2)

func _generate_space_station_layout() -> void:
	# TODO: Implement proper space station layout generation
	# For now, just create a simple room layout
	_place_building()

func _generate_ship_layout() -> void:
	# TODO: Implement proper ship layout generation
	# For now, just create a simple corridor layout
	_place_building()

func _create_zone(position: Vector2i, size: Vector2i) -> Array[Vector2i]:
	var zone: Array[Vector2i] = []
	for x in range(position.x, position.x + size.x):
		for y in range(position.y, position.y + size.y):
			if x >= 0 and x < config.size.x and y >= 0 and y < config.size.y:
				if terrain_grid[x][y].walkable:
					zone.append(Vector2i(x, y))
	return zone

func _get_valid_building_positions(size: Vector2i) -> Array[Vector2i]:
	var valid_positions: Array[Vector2i] = []
	
	for x in range(config.size.x - size.x):
		for y in range(config.size.y - size.y):
			var valid: bool = true
			
			# Check if area is clear
			for dx in range(size.x + 2): # +2 for buffer
				for dy in range(size.y + 2):
					var check_x: int = x + dx - 1 # -1 for buffer
					var check_y: int = y + dy - 1
					
					if check_x >= 0 and check_x < config.size.x and \
					   check_y >= 0 and check_y < config.size.y:
						if not terrain_grid[check_x][check_y].walkable:
							valid = false
							break
				if not valid:
					break
			
			if valid:
				valid_positions.append(Vector2i(x, y))
	
	return valid_positions

func _get_valid_cover_positions() -> Array[Vector2i]:
	var valid_positions: Array[Vector2i] = []
	
	for pos in walkable_tiles:
		var valid := true
		
		# Check minimum distance from other cover
		for cover_pos in cover_points:
			if pos.distance_to(cover_pos) < MIN_DISTANCE_BETWEEN_COVER:
				valid = false
				break
		
		# Check if not in deployment zones
		for zone in deployment_zones.values():
			if pos in zone:
				valid = false
				break
		
		if valid:
			valid_positions.append(pos)
	
	return valid_positions

func _get_valid_objective_positions() -> Array[Vector2i]:
	var valid_positions: Array[Vector2i] = []
	
	# Get center area of map
	var center_start := Vector2i(
		config.size.x / 4,
		config.size.y / 4
	)
	var center_end := Vector2i(
		config.size.x * 3 / 4,
		config.size.y * 3 / 4
	)
	
	for x in range(center_start.x, center_end.x):
		for y in range(center_start.y, center_end.y):
			if terrain_grid[x][y].walkable and not terrain_grid[x][y].cover:
				valid_positions.append(Vector2i(x, y))
	
	return valid_positions

# Validation functions
func validate_battlefield() -> Dictionary:
	var validation := {
		"valid": true,
		"errors": []
	}
	
	# Check minimum battlefield size
	if config.size.x < MIN_BATTLEFIELD_SIZE.x or config.size.y < MIN_BATTLEFIELD_SIZE.y:
		validation.valid = false
		validation.errors.append("Battlefield size too small")
	
	# Check maximum battlefield size
	if config.size.x > MAX_BATTLEFIELD_SIZE.x or config.size.y > MAX_BATTLEFIELD_SIZE.y:
		validation.valid = false
		validation.errors.append("Battlefield size too large")
	
	# Check cover density
	var cover_density := float(cover_points.size()) / float(walkable_tiles.size())
	if cover_density < MIN_COVER_DENSITY:
		validation.valid = false
		validation.errors.append("Insufficient cover density")
	elif cover_density > MAX_COVER_DENSITY:
		validation.valid = false
		validation.errors.append("Excessive cover density")
	
	# Check deployment zones
	if not _validate_deployment_zones():
		validation.valid = false
		validation.errors.append("Invalid deployment zones")
	
	return validation

func _validate_deployment_zones() -> bool:
	# Check minimum deployment zone size
	for zone in deployment_zones.values():
		var typed_zone: Array[Vector2i] = zone
		if typed_zone.size() < MIN_DEPLOYMENT_ZONE_SIZE:
			return false
	
	# Check deployment zone separation
	var player_zone: Array[Vector2i] = deployment_zones.get("player", [])
	var enemy_zone: Array[Vector2i] = deployment_zones.get("enemy", [])
	
	for player_pos in player_zone:
		for enemy_pos in enemy_zone:
			if player_pos.distance_to(enemy_pos) < MIN_DEPLOYMENT_ZONE_SIZE:
				return false
	
	return true

# Utility functions
func get_terrain_at(position: Vector2i) -> Dictionary:
	if position.x >= 0 and position.x < config.size.x and \
	   position.y >= 0 and position.y < config.size.y:
		return terrain_grid[position.x][position.y]
	return {
		"type": TerrainTypes.Type.NONE,
		"walkable": false,
		"cover": false,
		"elevation": 0
	}

func is_position_walkable(position: Vector2i) -> bool:
	return position in walkable_tiles

func is_position_cover(position: Vector2i) -> bool:
	return position in cover_points

func get_deployment_zone(zone_type: String) -> Array[Vector2i]:
	return deployment_zones.get(zone_type, [])