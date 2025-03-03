@tool
extends Node
class_name BaseBattlefieldGenerator

const BaseBattlefieldManager = preload("res://src/base/combat/battlefield/BaseBattlefieldManager.gd")

# Signals
signal generation_started()
signal generation_completed(battlefield_data: Dictionary)
signal generation_failed(error: String)
signal terrain_placed(terrain_type: int, position: Vector2i)
signal deployment_zone_created(zone_type: int, positions: Array[Vector2i])

# Dependencies
var battlefield_manager: BaseBattlefieldManager = null

# Configuration
var grid_size := Vector2i(24, 24)
var min_terrain_pieces: int = 4
var max_terrain_pieces: int = 12
var terrain_density: float = 0.3
var terrain_distribution: Dictionary = {
	# Default terrain distribution - to be overridden by derived classes
	# terrain_type: weight
	0: 1.0 # Empty
}

# Generation parameters
var generation_seed: int = 0
var use_random_seed: bool = true
var terrain_pattern: String = "random" # "random", "clustered", "scattered", "symmetrical"
var deployment_style: String = "opposite" # "opposite", "corners", "sides", "random"

# Virtual methods to be implemented by derived classes
func initialize(manager: BaseBattlefieldManager) -> void:
	battlefield_manager = manager
	grid_size = battlefield_manager.GRID_SIZE
	min_terrain_pieces = battlefield_manager.MIN_TERRAIN_PIECES
	max_terrain_pieces = battlefield_manager.MAX_TERRAIN_PIECES

func generate_battlefield() -> Dictionary:
	generation_started.emit()
	
	if not battlefield_manager:
		var error = "BattlefieldGenerator: No battlefield manager assigned"
		push_error(error)
		generation_failed.emit(error)
		return {}
	
	# Initialize random number generator
	var rng = RandomNumberGenerator.new()
	if use_random_seed:
		rng.randomize()
		generation_seed = rng.seed
	else:
		rng.seed = generation_seed
	
	# Create empty battlefield
	battlefield_manager.initialize_battlefield(grid_size)
	
	# Generate terrain
	var terrain_data = _generate_terrain(rng)
	
	# Create deployment zones
	var deployment_data = _create_deployment_zones(rng)
	
	# Compile battlefield data
	var battlefield_data = {
		"seed": generation_seed,
		"grid_size": grid_size,
		"terrain": terrain_data,
		"deployment_zones": deployment_data
	}
	
	generation_completed.emit(battlefield_data)
	return battlefield_data

func _generate_terrain(rng: RandomNumberGenerator) -> Array:
	var terrain_data = []
	
	# Number of terrain pieces to place
	var num_terrain_pieces = rng.randi_range(min_terrain_pieces, max_terrain_pieces)
	
	# Generate terrain based on pattern
	match terrain_pattern:
		"random":
			terrain_data = _generate_random_terrain(rng, num_terrain_pieces)
		"clustered":
			terrain_data = _generate_clustered_terrain(rng, num_terrain_pieces)
		"scattered":
			terrain_data = _generate_scattered_terrain(rng, num_terrain_pieces)
		"symmetrical":
			terrain_data = _generate_symmetrical_terrain(rng, num_terrain_pieces)
		_:
			terrain_data = _generate_random_terrain(rng, num_terrain_pieces)
	
	return terrain_data

func _generate_random_terrain(rng: RandomNumberGenerator, num_pieces: int) -> Array:
	var terrain_data = []
	
	for i in range(num_pieces):
		var terrain_type = _select_random_terrain_type(rng)
		var position = _find_valid_terrain_position(rng)
		
		if position != Vector2i(-1, -1):
			battlefield_manager.set_terrain(position, terrain_type)
			terrain_data.append({
				"type": terrain_type,
				"position": position
			})
			terrain_placed.emit(terrain_type, position)
	
	return terrain_data

func _generate_clustered_terrain(rng: RandomNumberGenerator, num_pieces: int) -> Array:
	# To be implemented by derived classes
	return _generate_random_terrain(rng, num_pieces)

func _generate_scattered_terrain(rng: RandomNumberGenerator, num_pieces: int) -> Array:
	# To be implemented by derived classes
	return _generate_random_terrain(rng, num_pieces)

func _generate_symmetrical_terrain(rng: RandomNumberGenerator, num_pieces: int) -> Array:
	# To be implemented by derived classes
	return _generate_random_terrain(rng, num_pieces)

func _create_deployment_zones(rng: RandomNumberGenerator) -> Dictionary:
	var deployment_data = {}
	
	# Create deployment zones based on style
	match deployment_style:
		"opposite":
			deployment_data = _create_opposite_deployment_zones()
		"corners":
			deployment_data = _create_corner_deployment_zones()
		"sides":
			deployment_data = _create_side_deployment_zones()
		"random":
			deployment_data = _create_random_deployment_zones(rng)
		_:
			deployment_data = _create_opposite_deployment_zones()
	
	return deployment_data

func _create_opposite_deployment_zones() -> Dictionary:
	var player_zone = []
	var enemy_zone = []
	
	# Player zone (bottom)
	for x in range(grid_size.x):
		for y in range(3): # 3 rows at the bottom
			player_zone.append(Vector2i(x, grid_size.y - 1 - y))
	
	# Enemy zone (top)
	for x in range(grid_size.x):
		for y in range(3): # 3 rows at the top
			enemy_zone.append(Vector2i(x, y))
	
	battlefield_manager.set_deployment_zone(1, player_zone) # 1 = player
	battlefield_manager.set_deployment_zone(2, enemy_zone) # 2 = enemy
	
	deployment_zone_created.emit(1, player_zone)
	deployment_zone_created.emit(2, enemy_zone)
	
	return {
		"player": player_zone,
		"enemy": enemy_zone
	}

func _create_corner_deployment_zones() -> Dictionary:
	# To be implemented by derived classes
	return _create_opposite_deployment_zones()

func _create_side_deployment_zones() -> Dictionary:
	# To be implemented by derived classes
	return _create_opposite_deployment_zones()

func _create_random_deployment_zones(rng: RandomNumberGenerator) -> Dictionary:
	# To be implemented by derived classes
	return _create_opposite_deployment_zones()

# Utility methods
func _select_random_terrain_type(rng: RandomNumberGenerator) -> int:
	var total_weight = 0.0
	for terrain_type in terrain_distribution:
		total_weight += terrain_distribution[terrain_type]
	
	var random_value = rng.randf() * total_weight
	var current_weight = 0.0
	
	for terrain_type in terrain_distribution:
		current_weight += terrain_distribution[terrain_type]
		if random_value <= current_weight:
			return terrain_type
	
	return 0 # Default terrain type (empty)

func _find_valid_terrain_position(rng: RandomNumberGenerator) -> Vector2i:
	var max_attempts = 50
	var attempts = 0
	
	while attempts < max_attempts:
		var x = rng.randi_range(0, grid_size.x - 1)
		var y = rng.randi_range(0, grid_size.y - 1)
		var position = Vector2i(x, y)
		
		# Check if position is valid for terrain placement
		if battlefield_manager.get_terrain(position) == 0: # Empty
			return position
		
		attempts += 1
	
	return Vector2i(-1, -1) # Invalid position