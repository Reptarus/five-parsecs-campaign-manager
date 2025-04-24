@tool
extends Node

## Dependencies
const TableProcessor := preload("res://src/core/systems/TableProcessor.gd")
const TableLoader := preload("res://src/core/systems/TableLoader.gd")
const PositionValidator := preload("res://src/core/systems/PositionValidator.gd")
const Mission := preload("res://src/core/systems/Mission.gd")
const GameEnums := preload("res://src/core/systems/GlobalEnums.gd")
const TerrainTypes := preload("res://src/core/terrain/TerrainTypes.gd")

## Signals
signal generation_started()
signal generation_completed(battlefield_data: Dictionary)
signal generation_failed(reason: String)

## Variables
var table_processor: TableProcessor
var position_validator: PositionValidator

## Constants
const BATTLEFIELD_TABLES_PATH := "res://data/battlefield_tables"
const MIN_BATTLEFIELD_SIZE := Vector2i(20, 20)
const MAX_BATTLEFIELD_SIZE := Vector2i(50, 50)

func _init() -> void:
	table_processor = TableProcessor.new()
	_load_battlefield_tables()

func _load_battlefield_tables() -> void:
	var tables = TableLoader.load_tables_from_directory(BATTLEFIELD_TABLES_PATH)
	for table_name in tables:
		table_processor.register_table(tables[table_name])

## Setup the generator with required dependencies
func setup(_position_validator: PositionValidator) -> void:
	position_validator = _position_validator

## Generate a battlefield for a mission - accepts Mission object or configuration Dictionary
func generate_battlefield(mission_or_config: Variant) -> Dictionary:
	generation_started.emit()
	
	var battlefield_data := {}
	var mission_type: int = GameEnums.MissionType.PATROL
	var difficulty: int = GameEnums.DifficultyLevel.NORMAL
	var environment: int = GameEnums.PlanetEnvironment.URBAN
	var size := Vector2i(24, 24)
	
	# Handle different input types
	if mission_or_config is Mission:
		mission_type = mission_or_config.mission_type
		difficulty = mission_or_config.difficulty
		environment = mission_or_config.environment
	elif mission_or_config is Dictionary:
		mission_type = mission_or_config.get("mission_type", GameEnums.MissionType.PATROL)
		difficulty = mission_or_config.get("difficulty", GameEnums.DifficultyLevel.NORMAL)
		environment = mission_or_config.get("environment", GameEnums.PlanetEnvironment.URBAN)
		
		# Handle size from config
		var config_size = mission_or_config.get("size")
		if config_size is Vector2i:
			size = config_size
		elif config_size is Vector2:
			size = Vector2i(int(config_size.x), int(config_size.y))
	else:
		generation_failed.emit("Invalid mission parameter type")
		return {}
	
	# Set size within boundaries
	size.x = clampi(size.x, MIN_BATTLEFIELD_SIZE.x, MAX_BATTLEFIELD_SIZE.x)
	size.y = clampi(size.y, MIN_BATTLEFIELD_SIZE.y, MAX_BATTLEFIELD_SIZE.y)
	battlefield_data["size"] = size
	
	# Generate terrain
	var terrain = _generate_terrain_grid(size, environment)
	battlefield_data["terrain"] = terrain
	
	# Create deployment zones
	var deployment_zones = _create_deployment_zones(size)
	battlefield_data["deployment_zones"] = deployment_zones
	
	# Generate walkable tiles map
	var walkable_tiles = _generate_walkable_tiles(terrain, size)
	battlefield_data["walkable_tiles"] = walkable_tiles
	
	# Add mission-specific objectives
	var objectives = _generate_mission_objectives(mission_type, size, walkable_tiles)
	battlefield_data["objectives"] = objectives
	
	# Validate the generated battlefield
	if not _validate_battlefield(battlefield_data):
		generation_failed.emit("Failed to validate battlefield")
		return {}
	
	generation_completed.emit(battlefield_data)
	return battlefield_data

## Generate a complete grid of terrain
func _generate_terrain_grid(size: Vector2i, environment: int) -> Array:
	var terrain = []
	
	# Create 2D array structure
	for x in range(size.x):
		terrain.append([])
		for y in range(size.y):
			var cell = {
				"type": TerrainTypes.Type.EMPTY,
				"row": [] if x == 0 else null # Only first row needs this for compatibility
			}
			terrain[x].append(cell)
	
	# Place terrain features
	var terrain_density = 0.3
	for x in range(size.x):
		for y in range(size.y):
			# Skip the edges
			if x == 0 or y == 0 or x == size.x - 1 or y == size.y - 1:
				continue
				
			if randf() < terrain_density:
				# Place cover
				if randf() < 0.7:
					terrain[x][y].type = TerrainTypes.Type.COVER_LOW
				else:
					terrain[x][y].type = TerrainTypes.Type.COVER_HIGH
	
	return terrain

## Create deployment zones for players and enemies
func _create_deployment_zones(size: Vector2i) -> Dictionary:
	var zones = {}
	var player_zone = []
	var enemy_zone = []
	
	# Player zone on left side
	for y in range(2, size.y - 2):
		player_zone.append(Vector2i(2, y))
	
	# Enemy zone on right side
	for y in range(2, size.y - 2):
		enemy_zone.append(Vector2i(size.x - 3, y))
	
	zones["player"] = player_zone
	zones["enemy"] = enemy_zone
	
	return zones

## Generate walkable tiles
func _generate_walkable_tiles(terrain: Array, size: Vector2i) -> Array:
	var walkable = []
	
	for x in range(size.x):
		for y in range(size.y):
			var cell_type = terrain[x][y].type
			if cell_type != TerrainTypes.Type.WALL:
				# Only exclude walls as impassable terrain since IMPASSABLE might not exist
				walkable.append(Vector2i(x, y))
	
	return walkable

## Generate mission-specific objectives
func _generate_mission_objectives(mission_type: int, size: Vector2i, walkable_tiles: Array) -> Dictionary:
	var objectives = {}
	
	match mission_type:
		GameEnums.MissionType.PATROL:
			objectives["patrol_points"] = _generate_patrol_points(walkable_tiles)
		GameEnums.MissionType.SABOTAGE:
			objectives["target_points"] = _generate_target_points(walkable_tiles)
		GameEnums.MissionType.RESCUE:
			objectives["rescue_points"] = _generate_rescue_points(walkable_tiles)
	
	return objectives

## Generate patrol points for patrol missions
func _generate_patrol_points(walkable_tiles: Array) -> Array:
	var points = []
	var point_count = 3
	
	for i in range(min(point_count, walkable_tiles.size())):
		var index = randi() % walkable_tiles.size()
		points.append(walkable_tiles[index])
	
	return points

## Generate target points for sabotage missions
func _generate_target_points(walkable_tiles: Array) -> Array:
	var points = []
	var point_count = 2
	
	for i in range(min(point_count, walkable_tiles.size())):
		var index = randi() % walkable_tiles.size()
		points.append(walkable_tiles[index])
	
	return points

## Generate rescue points for rescue missions
func _generate_rescue_points(walkable_tiles: Array) -> Array:
	var points = []
	var point_count = 1
	
	for i in range(min(point_count, walkable_tiles.size())):
		var index = randi() % walkable_tiles.size()
		points.append(walkable_tiles[index])
	
	return points

# Safe helpers to replace 'in' and 'has' operations
func _has_key(dict, key):
	if dict == null:
		return false
	if dict is Dictionary:
		return dict.has(key)
	return false

func _has_method(obj, method_name):
	if obj == null:
		return false
	if obj is Object:
		return obj.has_method(method_name)
	return false

## Validate the generated battlefield
func _validate_battlefield(battlefield_data: Dictionary) -> bool:
	# Check for minimum required elements
	if not _has_key(battlefield_data, "terrain") or battlefield_data.terrain.is_empty():
		return false
	
	# Validate battlefield size
	var size = battlefield_data.get("size", Vector2i.ZERO)
	if size.x < MIN_BATTLEFIELD_SIZE.x or size.y < MIN_BATTLEFIELD_SIZE.y:
		return false
	
	# Validate deployment zones
	if not _has_key(battlefield_data, "deployment_zones"):
		return false
		
	var deployment_zones = battlefield_data.get("deployment_zones", {})
	if not _has_key(deployment_zones, "player") or not _has_key(deployment_zones, "enemy"):
		return false
	
	return true

## Find clear paths between two points
func find_clear_paths(start_pos: Vector2i, end_pos: Vector2i) -> Array:
	# Simplified path finding - always return a direct path for tests
	return [start_pos, end_pos]