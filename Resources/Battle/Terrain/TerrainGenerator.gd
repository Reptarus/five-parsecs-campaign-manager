extends Node

# Constants for terrain generation
const MIN_TERRAIN_FEATURES = 3
const MAX_TERRAIN_FEATURES = 8
const MIN_FEATURE_SIZE = 2
const MAX_FEATURE_SIZE = 4

# Reference to terrain system
var terrain_system: Node2D

func _ready() -> void:
	# Get reference to terrain system from parent
	terrain_system = get_parent() as Node2D
	if not terrain_system:
		push_error("TerrainGenerator: Parent must be a Node2D containing terrain system")

func generate_terrain() -> void:
	if not terrain_system:
		push_error("TerrainGenerator: No terrain system reference")
		return
		
	# Clear existing terrain
	terrain_system.clear_terrain()
	
	# Generate basic terrain features
	_generate_cover()
	_generate_difficult_terrain()
	_generate_high_ground()
	_generate_linear_obstacles()

func _generate_cover() -> void:
	var num_features = randi_range(MIN_TERRAIN_FEATURES, MAX_TERRAIN_FEATURES)
	
	for _i in range(num_features):
		var size = Vector2i(
			randi_range(MIN_FEATURE_SIZE, MAX_FEATURE_SIZE),
			randi_range(MIN_FEATURE_SIZE, MAX_FEATURE_SIZE)
		)
		
		var pos = Vector2i(
			randi_range(0, terrain_system.grid_size.x - size.x),
			randi_range(0, terrain_system.grid_size.y - size.y)
		)
		
		# Avoid placing cover in deployment zones (first and last quarter of the map)
		if pos.x < terrain_system.grid_size.x * 0.25 or pos.x > terrain_system.grid_size.x * 0.75:
			continue
			
		_place_terrain_feature(pos, size, terrain_system.TERRAIN_TYPES.COVER)

func _generate_difficult_terrain() -> void:
	var num_features = randi_range(MIN_TERRAIN_FEATURES / 2, MAX_TERRAIN_FEATURES / 2)
	
	for _i in range(num_features):
		var size = Vector2i(
			randi_range(MIN_FEATURE_SIZE, MAX_FEATURE_SIZE),
			randi_range(MIN_FEATURE_SIZE, MAX_FEATURE_SIZE)
		)
		
		var pos = Vector2i(
			randi_range(0, terrain_system.grid_size.x - size.x),
			randi_range(0, terrain_system.grid_size.y - size.y)
		)
		
		_place_terrain_feature(pos, size, terrain_system.TERRAIN_TYPES.DIFFICULT)

func _generate_high_ground() -> void:
	var num_features = randi_range(1, 3)
	
	for _i in range(num_features):
		var size = Vector2i(
			randi_range(MIN_FEATURE_SIZE, MAX_FEATURE_SIZE),
			randi_range(MIN_FEATURE_SIZE, MAX_FEATURE_SIZE)
		)
		
		var pos = Vector2i(
			randi_range(0, terrain_system.grid_size.x - size.x),
			randi_range(0, terrain_system.grid_size.y - size.y)
		)
		
		_place_terrain_feature(pos, size, terrain_system.TERRAIN_TYPES.HIGH_GROUND)

func _generate_linear_obstacles() -> void:
	var num_obstacles = randi_range(2, 5)
	
	for _i in range(num_obstacles):
		var length = randi_range(3, 6)
		var horizontal = randf() > 0.5
		
		var pos = Vector2i(
			randi_range(0, terrain_system.grid_size.x - (horizontal * length)),
			randi_range(0, terrain_system.grid_size.y - (!horizontal * length))
		)
		
		_place_linear_obstacle(pos, length, horizontal)

func _place_terrain_feature(pos: Vector2i, size: Vector2i, type: int) -> void:
	for x in range(size.x):
		for y in range(size.y):
			var feature_pos = Vector2i(pos.x + x, pos.y + y)
			if terrain_system.is_position_valid(feature_pos):
				terrain_system.set_terrain_at_position(feature_pos, type)

func _place_linear_obstacle(pos: Vector2i, length: int, horizontal: bool) -> void:
	for i in range(length):
		var obstacle_pos = Vector2i(
			pos.x + (horizontal * i),
			pos.y + (!horizontal * i)
		)
		if terrain_system.is_position_valid(obstacle_pos):
			terrain_system.set_terrain_at_position(obstacle_pos, terrain_system.TERRAIN_TYPES.LINEAR)

func _to_string() -> String:
	return "TerrainGenerator: Generates 2D top-down terrain for Five Parsecs tabletop battles"
