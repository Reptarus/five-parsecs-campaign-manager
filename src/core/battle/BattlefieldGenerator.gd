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
	"battlefield_type": GameEnums.PlanetEnvironment.URBAN,
	"environment": GameEnums.PlanetEnvironment.URBAN,
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
	var feature: TerrainTypes.Type = TerrainTypes.Type.NONE
	var zone: String = "neutral"

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
	
	# Apply environment-specific effects
	_apply_environment_effects()
	
	# Add dynamic hazards
	_distribute_dynamic_hazards()
	
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
		GameEnums.PlanetEnvironment.URBAN:
			_generate_urban_terrain()
		GameEnums.PlanetEnvironment.FOREST:
			_generate_wilderness_terrain()
		GameEnums.PlanetEnvironment.DESERT:
			_generate_wilderness_terrain()
		GameEnums.PlanetEnvironment.ICE:
			_generate_wilderness_terrain()
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
			"type": GameEnums.TerrainFeatureType.OBJECTIVE,
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
	# Generate building clusters
	var cluster_count := randi_range(2, 4)
	var clusters := []
	
	# Create building clusters
	for _i in range(cluster_count):
		var cluster_center := Vector2i(
			randi_range(4, config.size.x - 4),
			randi_range(4, config.size.y - 4)
		)
		clusters.append(cluster_center)
		
		# Generate buildings around cluster center
		var building_count := randi_range(2, 4)
		for _j in range(building_count):
			var offset := Vector2i(
				randi_range(-3, 3),
				randi_range(-3, 3)
			)
			var building_pos := cluster_center + offset
			_place_building_at(building_pos)
	
	# Add streets between clusters
	for i in range(clusters.size()):
		for j in range(i + 1, clusters.size()):
			_create_street(clusters[i], clusters[j])
	
	# Add street cover
	var cover_count := int(walkable_tiles.size() * config.cover_density)
	for _i in range(cover_count):
		_place_cover(TerrainTypes.Type.COVER_LOW)

func _generate_wilderness_terrain() -> void:
	# Generate elevation variations using noise
	_generate_elevation_noise()
	
	# Create terrain clusters
	var cluster_count := randi_range(3, 5)
	var clusters := []
	
	# Generate main terrain clusters
	for _i in range(cluster_count):
		var cluster_center := Vector2i(
			randi_range(4, config.size.x - 4),
			randi_range(4, config.size.y - 4)
		)
		clusters.append(cluster_center)
		
		# Generate terrain features around cluster center
		var feature_count := randi_range(4, 7)
		for _j in range(feature_count):
			var offset := Vector2i(
				randi_range(-3, 3),
				randi_range(-3, 3)
			)
			var feature_pos := cluster_center + offset
			_place_wilderness_feature(feature_pos)
	
	# Create paths between clusters
	for i in range(clusters.size()):
		for j in range(i + 1, clusters.size()):
			if randf() < 0.7: # 70% chance to connect clusters
				_create_wilderness_path(clusters[i], clusters[j])
	
	# Add scattered cover
	var cover_count := int(walkable_tiles.size() * config.cover_density * 1.5)
	for _i in range(cover_count):
		if randf() < 0.7:
			_place_cover(TerrainTypes.Type.COVER_HIGH)
		else:
			_place_cover(TerrainTypes.Type.COVER_LOW)

func _place_wilderness_feature(position: Vector2i) -> void:
	if position.x < 0 or position.y < 0 or \
	   position.x >= config.size.x or position.y >= config.size.y:
		return
	
	# Determine feature type based on environment
	var feature_type: TerrainTypes.Type
	match config.environment:
		GameEnums.PlanetEnvironment.FOREST:
			feature_type = TerrainTypes.Type.COVER_HIGH if randf() < 0.8 else TerrainTypes.Type.COVER_LOW
		GameEnums.PlanetEnvironment.DESERT:
			feature_type = TerrainTypes.Type.COVER_LOW if randf() < 0.7 else TerrainTypes.Type.HAZARD
		GameEnums.PlanetEnvironment.ICE:
			feature_type = TerrainTypes.Type.DIFFICULT if randf() < 0.6 else TerrainTypes.Type.COVER_LOW
		_:
			feature_type = TerrainTypes.Type.COVER_LOW
	
	# Place the feature
	terrain_grid[position.x][position.y].type = feature_type
	terrain_grid[position.x][position.y].walkable = feature_type != TerrainTypes.Type.HAZARD
	terrain_grid[position.x][position.y].cover = feature_type in [TerrainTypes.Type.COVER_LOW, TerrainTypes.Type.COVER_HIGH]
	
	# Add to appropriate tracking lists
	if terrain_grid[position.x][position.y].cover:
		cover_points.append(Vector2i(position.x, position.y))
	if not terrain_grid[position.x][position.y].walkable:
		walkable_tiles.erase(Vector2i(position.x, position.y))

func _create_wilderness_path(start: Vector2i, end: Vector2i) -> void:
	var current := start
	var path_tiles := []
	
	# Create a winding path between points
	while current != end:
		path_tiles.append(current)
		
		# Randomly decide whether to move horizontally or vertically
		if randf() < 0.5 and current.x != end.x:
			current.x += sign(end.x - current.x)
		elif current.y != end.y:
			current.y += sign(end.y - current.y)
		else:
			current.x += sign(end.x - current.x)
	
	# Place path tiles with some variation
	for tile in path_tiles:
		if tile.x >= 0 and tile.x < config.size.x and \
		   tile.y >= 0 and tile.y < config.size.y:
			terrain_grid[tile.x][tile.y].type = TerrainTypes.Type.EMPTY
			terrain_grid[tile.x][tile.y].elevation = 0
			terrain_grid[tile.x][tile.y].walkable = true
			
			# Add some path-side cover
			if randf() < 0.3: # 30% chance for path-side cover
				var offset := Vector2i(
					randi_range(-1, 1),
					randi_range(-1, 1)
				)
				var cover_pos: Vector2i = tile + offset
				if cover_pos.x >= 0 and cover_pos.x < config.size.x and \
				   cover_pos.y >= 0 and cover_pos.y < config.size.y:
					_place_wilderness_feature(cover_pos)

func _generate_space_station_terrain() -> void:
	# Initialize grid with walls
	for x in range(config.size.x):
		for y in range(config.size.y):
			terrain_grid[x][y].type = TerrainTypes.Type.WALL
			terrain_grid[x][y].walkable = false
			walkable_tiles.erase(Vector2i(x, y))
	
	# Generate main corridors
	var corridors := _generate_space_station_corridors()
	
	# Generate rooms
	var rooms := _generate_space_station_rooms(corridors)
	
	# Add cover and features
	_add_space_station_features(corridors, rooms)
	
	# Add cover points
	var cover_count := int(walkable_tiles.size() * config.cover_density * 0.8)
	for _i in range(cover_count):
		_place_cover(TerrainTypes.Type.COVER_LOW)

func _generate_space_station_corridors() -> Array[Array]:
	var corridors: Array[Array] = []
	var start_points := [
		Vector2i(config.size.x / 4, config.size.y / 2),
		Vector2i(config.size.x * 3 / 4, config.size.y / 2),
		Vector2i(config.size.x / 2, config.size.y / 4),
		Vector2i(config.size.x / 2, config.size.y * 3 / 4)
	]
	
	# Create main corridors
	for i in range(start_points.size()):
		var corridor := []
		var current: Vector2i = start_points[i]
		var target: Vector2i = start_points[(i + 1) % start_points.size()]
		
		while current != target:
			corridor.append(current)
			_place_corridor_tile(current)
			
			if randf() < 0.7: # 70% chance to move towards target
				if abs(target.x - current.x) > abs(target.y - current.y):
					current.x += sign(target.x - current.x)
				else:
					current.y += sign(target.y - current.y)
			else: # 30% chance for slight deviation
				if randf() < 0.5:
					current.x += sign(target.x - current.x)
				else:
					current.y += sign(target.y - current.y)
		
		corridors.append(corridor)
	
	return corridors

func _generate_space_station_rooms(corridors: Array[Array]) -> Array[Rect2i]:
	var rooms: Array[Rect2i] = []
	var room_attempts := 10
	
	# Try to place rooms near corridor intersections
	for corridor in corridors:
		for point in corridor:
			if randf() < 0.3 and room_attempts > 0: # 30% chance to try placing a room
				var room_size := Vector2i(
					randi_range(3, 5),
					randi_range(3, 5)
				)
				var room_pos := Vector2i(
					point.x - room_size.x / 2,
					point.y - room_size.y / 2
				)
				
				var room := Rect2i(room_pos, room_size)
				if _is_valid_room_position(room, rooms):
					_place_room(room)
					rooms.append(room)
					room_attempts -= 1
	
	return rooms

func _place_corridor_tile(position: Vector2i) -> void:
	if position.x < 0 or position.y < 0 or \
	   position.x >= config.size.x or position.y >= config.size.y:
		return
	
	terrain_grid[position.x][position.y].type = TerrainTypes.Type.EMPTY
	terrain_grid[position.x][position.y].walkable = true
	terrain_grid[position.x][position.y].elevation = 0
	
	# Add to walkable tiles if not already present
	if not Vector2i(position.x, position.y) in walkable_tiles:
		walkable_tiles.append(Vector2i(position.x, position.y))

func _place_room(room: Rect2i) -> void:
	for x in range(room.position.x, room.position.x + room.size.x):
		for y in range(room.position.y, room.position.y + room.size.y):
			if x >= 0 and x < config.size.x and y >= 0 and y < config.size.y:
				terrain_grid[x][y].type = TerrainTypes.Type.EMPTY
				terrain_grid[x][y].walkable = true
				terrain_grid[x][y].elevation = 0
				
				# Add to walkable tiles if not already present
				if not Vector2i(x, y) in walkable_tiles:
					walkable_tiles.append(Vector2i(x, y))

func _is_valid_room_position(new_room: Rect2i, existing_rooms: Array[Rect2i]) -> bool:
	# Check bounds
	if new_room.position.x < 1 or new_room.position.y < 1 or \
	   new_room.position.x + new_room.size.x >= config.size.x - 1 or \
	   new_room.position.y + new_room.size.y >= config.size.y - 1:
		return false
	
	# Check overlap with existing rooms
	for room in existing_rooms:
		if new_room.intersects(room):
			return false
	
	return true

func _add_space_station_features(corridors: Array[Array], rooms: Array[Rect2i]) -> void:
	# Add features at corridor intersections
	for i in range(corridors.size()):
		for point in corridors[i]:
			for j in range(i + 1, corridors.size()):
				for other_point in corridors[j]:
					if point.distance_to(other_point) < 2:
						_place_intersection_feature(point)
	
	# Add features in rooms
	for room in rooms:
		var feature_count := randi_range(1, 3)
		for _i in range(feature_count):
			var feature_pos := Vector2i(
				room.position.x + randi_range(1, room.size.x - 2),
				room.position.y + randi_range(1, room.size.y - 2)
			)
			_place_room_feature(feature_pos)

func _place_intersection_feature(position: Vector2i) -> void:
	if randf() < 0.5: # 50% chance for cover
		terrain_grid[position.x][position.y].type = TerrainTypes.Type.COVER_LOW
		terrain_grid[position.x][position.y].cover = true
		cover_points.append(position)
	else: # 50% chance for hazard
		terrain_grid[position.x][position.y].type = TerrainTypes.Type.HAZARD
		terrain_grid[position.x][position.y].walkable = false
		walkable_tiles.erase(position)

func _place_room_feature(position: Vector2i) -> void:
	var feature_roll := randf()
	if feature_roll < 0.4: # 40% chance for low cover
		terrain_grid[position.x][position.y].type = TerrainTypes.Type.COVER_LOW
		terrain_grid[position.x][position.y].cover = true
		cover_points.append(position)
	elif feature_roll < 0.7: # 30% chance for high cover
		terrain_grid[position.x][position.y].type = TerrainTypes.Type.COVER_HIGH
		terrain_grid[position.x][position.y].cover = true
		cover_points.append(position)
	else: # 30% chance for hazard
		terrain_grid[position.x][position.y].type = TerrainTypes.Type.HAZARD
		terrain_grid[position.x][position.y].walkable = false
		walkable_tiles.erase(position)

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
	# Create a noise generator for more natural elevation patterns
	var noise := FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_PERLIN
	noise.seed = randi()
	noise.frequency = 0.1
	
	for x in range(config.size.x):
		for y in range(config.size.y):
			var noise_val := noise.get_noise_2d(x * 2.0, y * 2.0)
			# Convert noise value (-1 to 1) to elevation (0 to 3)
			var elevation := int((noise_val + 1.0) * 1.5)
			terrain_grid[x][y].elevation = elevation

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
		"errors": [],
		"warnings": [],
		"metrics": {}
	}
	
	# Core validation checks
	_validate_battlefield_size(validation)
	_validate_cover_density(validation)
	_validate_deployment_zones(validation)
	_validate_objectives(validation)
	_validate_hazards(validation)
	_validate_environment_rules(validation)
	
	# Calculate metrics
	validation.metrics = _calculate_battlefield_metrics()
	
	return validation

func _validate_battlefield_size(validation: Dictionary) -> void:
	if config.size.x < MIN_BATTLEFIELD_SIZE.x or config.size.y < MIN_BATTLEFIELD_SIZE.y:
		validation.valid = false
		validation.errors.append("Battlefield size too small")
	
	if config.size.x > MAX_BATTLEFIELD_SIZE.x or config.size.y > MAX_BATTLEFIELD_SIZE.y:
		validation.valid = false
		validation.errors.append("Battlefield size too large")
	
	# Check aspect ratio
	var aspect_ratio := float(config.size.x) / float(config.size.y)
	if aspect_ratio < 0.5 or aspect_ratio > 2.0:
		validation.warnings.append("Unusual battlefield aspect ratio may affect gameplay balance")

func _validate_cover_density(validation: Dictionary) -> void:
	var cover_density := float(cover_points.size()) / float(walkable_tiles.size())
	validation.metrics["cover_density"] = cover_density
	
	if cover_density < MIN_COVER_DENSITY:
		validation.valid = false
		validation.errors.append("Insufficient cover density")
	elif cover_density > MAX_COVER_DENSITY:
		validation.valid = false
		validation.errors.append("Excessive cover density")
	
	# Check cover distribution
	var sectors := _analyze_cover_distribution()
	var min_sector_density := 1.0
	var max_sector_density := 0.0
	
	for sector in sectors:
		min_sector_density = min(min_sector_density, sector.density)
		max_sector_density = max(max_sector_density, sector.density)
	
	if max_sector_density - min_sector_density > 0.3:
		validation.warnings.append("Uneven cover distribution may affect gameplay balance")

func _validate_deployment_zones(validation: Dictionary) -> void:
	# Check minimum deployment zone size
	for zone_type in deployment_zones:
		var zone: Array[Vector2i] = deployment_zones[zone_type]
		if zone.size() < MIN_DEPLOYMENT_ZONE_SIZE:
			validation.valid = false
			validation.errors.append("Deployment zone '%s' is too small" % zone_type)
	
	# Check deployment zone separation
	var player_zone: Array[Vector2i] = deployment_zones.get("player", [])
	var enemy_zone: Array[Vector2i] = deployment_zones.get("enemy", [])
	
	for player_pos in player_zone:
		for enemy_pos in enemy_zone:
			if player_pos.distance_to(enemy_pos) < MIN_DEPLOYMENT_ZONE_SIZE:
				validation.valid = false
				validation.errors.append("Deployment zones are too close")
	
	# Check deployment zone accessibility
	for zone_type in deployment_zones:
		var zone: Array[Vector2i] = deployment_zones[zone_type]
		var accessible_tiles := 0
		for pos in zone:
			if terrain_grid[pos.x][pos.y].walkable:
				accessible_tiles += 1
		
		var accessibility := float(accessible_tiles) / float(zone.size())
		if accessibility < 0.7:
			validation.warnings.append("Deployment zone '%s' has limited accessible space" % zone_type)

func _validate_objectives(validation: Dictionary) -> void:
	if objectives.is_empty() and config.objective_count > 0:
		validation.valid = false
		validation.errors.append("No objectives placed despite configuration")
	
	for objective in objectives:
		# Check objective accessibility
		var accessible_tiles := 0
		var total_tiles := 0
		
		for x in range(max(0, objective.position.x - 2), min(config.size.x, objective.position.x + 3)):
			for y in range(max(0, objective.position.y - 2), min(config.size.y, objective.position.y + 3)):
				total_tiles += 1
				if terrain_grid[x][y].walkable:
					accessible_tiles += 1
		
		var accessibility := float(accessible_tiles) / float(total_tiles)
		if accessibility < 0.6:
			validation.warnings.append("Objective at %s has limited accessibility" % objective.position)
		
		# Check objective balance
		var dist_to_player := _get_min_distance_to_zone(objective.position, "player")
		var dist_to_enemy := _get_min_distance_to_zone(objective.position, "enemy")
		
		if abs(dist_to_player - dist_to_enemy) > 5:
			validation.warnings.append("Objective at %s may favor one side" % objective.position)

func _validate_hazards(validation: Dictionary) -> void:
	var hazard_count := 0
	var hazard_clusters := 0
	var current_cluster_size := 0
	
	for x in range(config.size.x):
		for y in range(config.size.y):
			if terrain_grid[x][y].type == TerrainTypes.Type.HAZARD:
				hazard_count += 1
				current_cluster_size += 1
			elif current_cluster_size > 0:
				if current_cluster_size > 3:
					hazard_clusters += 1
				current_cluster_size = 0
	
	validation.metrics["hazard_count"] = hazard_count
	validation.metrics["hazard_clusters"] = hazard_clusters
	
	var hazard_density := float(hazard_count) / float(config.size.x * config.size.y)
	if hazard_density > 0.2:
		validation.warnings.append("High hazard density may impact gameplay flow")
	
	if hazard_clusters > 3:
		validation.warnings.append("Multiple large hazard clusters may create dead zones")

func _validate_environment_rules(validation: Dictionary) -> void:
	match config.environment:
		GameEnums.PlanetEnvironment.URBAN:
			_validate_urban_rules(validation)
		GameEnums.PlanetEnvironment.FOREST:
			_validate_forest_rules(validation)
		GameEnums.PlanetEnvironment.DESERT:
			_validate_desert_rules(validation)
		GameEnums.PlanetEnvironment.ICE:
			_validate_ice_rules(validation)

func _validate_urban_rules(validation: Dictionary) -> void:
	var building_count := 0
	var max_elevation := 0
	
	for x in range(config.size.x):
		for y in range(config.size.y):
			if terrain_grid[x][y].type == TerrainTypes.Type.WALL:
				building_count += 1
			max_elevation = max(max_elevation, terrain_grid[x][y].elevation)
	
	if building_count < 10:
		validation.warnings.append("Urban environment has few buildings")
	
	if max_elevation < 2:
		validation.warnings.append("Urban environment lacks vertical elements")

func _validate_forest_rules(validation: Dictionary) -> void:
	var vegetation_count := 0
	var open_spaces := 0
	
	for x in range(config.size.x):
		for y in range(config.size.y):
			if terrain_grid[x][y].type == TerrainTypes.Type.DIFFICULT:
				vegetation_count += 1
			elif terrain_grid[x][y].walkable:
				open_spaces += 1
	
	if vegetation_count < open_spaces * 0.3:
		validation.warnings.append("Forest environment has limited vegetation")

func _validate_desert_rules(validation: Dictionary) -> void:
	var elevation_changes := 0
	var prev_elevation := 0
	
	for x in range(config.size.x):
		for y in range(config.size.y):
			if abs(terrain_grid[x][y].elevation - prev_elevation) > 0:
				elevation_changes += 1
			prev_elevation = terrain_grid[x][y].elevation
	
	if elevation_changes < config.size.x * config.size.y * 0.2:
		validation.warnings.append("Desert environment lacks terrain variation")

func _validate_ice_rules(validation: Dictionary) -> void:
	var difficult_terrain := 0
	
	for x in range(config.size.x):
		for y in range(config.size.y):
			if terrain_grid[x][y].type == TerrainTypes.Type.DIFFICULT:
				difficult_terrain += 1
	
	if difficult_terrain < walkable_tiles.size() * 0.15:
		validation.warnings.append("Ice environment has few hazardous areas")

func _analyze_cover_distribution() -> Array:
	var sector_size := Vector2i(8, 8)
	var sectors := []
	
	for sx in range((config.size.x + sector_size.x - 1) / sector_size.x):
		for sy in range((config.size.y + sector_size.y - 1) / sector_size.y):
			var sector := {
				"position": Vector2i(sx * sector_size.x, sy * sector_size.y),
				"cover_count": 0,
				"walkable_count": 0,
				"density": 0.0
			}
			
			for x in range(sector.position.x, min(sector.position.x + sector_size.x, config.size.x)):
				for y in range(sector.position.y, min(sector.position.y + sector_size.y, config.size.y)):
					if Vector2i(x, y) in cover_points:
						sector.cover_count += 1
					if Vector2i(x, y) in walkable_tiles:
						sector.walkable_count += 1
			
			if sector.walkable_count > 0:
				sector.density = float(sector.cover_count) / float(sector.walkable_count)
			sectors.append(sector)
	
	return sectors

func _get_min_distance_to_zone(position: Vector2i, zone_type: String) -> float:
	var min_distance := INF
	var zone: Array[Vector2i] = deployment_zones.get(zone_type, [])
	
	for zone_pos in zone:
		min_distance = min(min_distance, position.distance_to(zone_pos))
	
	return min_distance

func _calculate_battlefield_metrics() -> Dictionary:
	return {
		"total_tiles": config.size.x * config.size.y,
		"walkable_tiles": walkable_tiles.size(),
		"cover_points": cover_points.size(),
		"cover_density": float(cover_points.size()) / float(walkable_tiles.size()),
		"average_elevation": _calculate_average_elevation(),
		"line_of_sight_coverage": _calculate_line_of_sight_coverage()
	}

func _calculate_average_elevation() -> float:
	var total_elevation := 0
	var count := 0
	
	for x in range(config.size.x):
		for y in range(config.size.y):
			total_elevation += terrain_grid[x][y].elevation
			count += 1
	
	return float(total_elevation) / float(count)

func _calculate_line_of_sight_coverage() -> float:
	var total_los_points := 0
	var blocked_los_points := 0
	
	# Sample points for line of sight calculation
	var sample_interval := 4
	for x1 in range(0, config.size.x, sample_interval):
		for y1 in range(0, config.size.y, sample_interval):
			for x2 in range(0, config.size.x, sample_interval):
				for y2 in range(0, config.size.y, sample_interval):
					if x1 == x2 and y1 == y2:
						continue
					
					total_los_points += 1
					if _is_line_of_sight_blocked(Vector2i(x1, y1), Vector2i(x2, y2)):
						blocked_los_points += 1
	
	return float(blocked_los_points) / float(total_los_points)

func _is_line_of_sight_blocked(start: Vector2i, end: Vector2i) -> bool:
	var line := _get_line(start, end)
	
	for point in line:
		if point.x < 0 or point.x >= config.size.x or \
		   point.y < 0 or point.y >= config.size.y:
			continue
		
		if terrain_grid[point.x][point.y].type == TerrainTypes.Type.WALL:
			return true
	
	return false

func _get_line(start: Vector2i, end: Vector2i) -> Array[Vector2i]:
	var line: Array[Vector2i] = []
	
	var dx: int = abs(end.x - start.x)
	var dy: int = abs(end.y - start.y)
	var x: int = start.x
	var y: int = start.y
	var n: int = 1 + dx + dy
	var x_inc: int = 1 if end.x > start.x else -1
	var y_inc: int = 1 if end.y > start.y else -1
	var error: int = dx - dy
	dx *= 2
	dy *= 2
	
	for _i in range(n):
		line.append(Vector2i(x, y))
		
		if error > 0:
			x += x_inc
			error -= dy
		else:
			y += y_inc
			error += dx
	
	return line

# Utility functions
func get_terrain_at(position: Vector2i) -> Dictionary:
	if position.x >= 0 and position.x < config.size.x and \
	   position.y >= 0 and position.y < config.size.y:
		return terrain_grid[position.x][position.y].serialize()
	return {
		"type": TerrainTypes.Type.NONE,
		"walkable": false,
		"cover": false,
		"elevation": 0,
		"objective": false,
		"feature": TerrainTypes.Type.NONE,
		"zone": "none"
	}

func is_position_walkable(position: Vector2i) -> bool:
	return position in walkable_tiles

func is_position_cover(position: Vector2i) -> bool:
	return position in cover_points

func get_deployment_zone(zone_type: String) -> Array[Vector2i]:
	return deployment_zones.get(zone_type, [])

func _place_building_at(position: Vector2i) -> void:
	var size := Vector2i(
		randi_range(2, 4),
		randi_range(2, 4)
	)
	
	# Ensure building fits within bounds
	if position.x < 0 or position.y < 0 or \
	   position.x + size.x >= config.size.x or \
	   position.y + size.y >= config.size.y:
		return
	
	# Place building walls
	for x in range(position.x, position.x + size.x):
		for y in range(position.y, position.y + size.y):
			if x == position.x or x == position.x + size.x - 1 or \
			   y == position.y or y == position.y + size.y - 1:
				terrain_grid[x][y].type = TerrainTypes.Type.WALL
				terrain_grid[x][y].walkable = false
				terrain_grid[x][y].elevation = 2
				walkable_tiles.erase(Vector2i(x, y))
			else:
				terrain_grid[x][y].type = TerrainTypes.Type.EMPTY
				terrain_grid[x][y].elevation = 2

func _create_street(start: Vector2i, end: Vector2i) -> void:
	var current := start
	
	# Create horizontal street
	while current.x != end.x:
		var step := 1 if end.x > current.x else -1
		current.x += step
		_place_street_tile(current)
	
	# Create vertical street
	while current.y != end.y:
		var step := 1 if end.y > current.y else -1
		current.y += step
		_place_street_tile(current)

func _place_street_tile(position: Vector2i) -> void:
	if position.x < 0 or position.y < 0 or \
	   position.x >= config.size.x or position.y >= config.size.y:
		return
	
	terrain_grid[position.x][position.y].type = TerrainTypes.Type.EMPTY
	terrain_grid[position.x][position.y].elevation = 0
	terrain_grid[position.x][position.y].walkable = true
	
	# Add street to walkable tiles if not already present
	if not Vector2i(position.x, position.y) in walkable_tiles:
		walkable_tiles.append(Vector2i(position.x, position.y))

func _apply_environment_effects() -> void:
	match config.environment:
		GameEnums.PlanetEnvironment.URBAN:
			_apply_urban_effects()
		GameEnums.PlanetEnvironment.FOREST:
			_apply_forest_effects()
		GameEnums.PlanetEnvironment.DESERT:
			_apply_desert_effects()
		GameEnums.PlanetEnvironment.ICE:
			_apply_ice_effects()

func _distribute_dynamic_hazards() -> void:
	var hazard_count := int(walkable_tiles.size() * 0.05) # 5% of walkable tiles
	for _i in range(hazard_count):
		var valid_positions := _get_valid_hazard_positions()
		if valid_positions.is_empty():
			break
		var position := valid_positions[randi() % valid_positions.size()]
		terrain_grid[position.x][position.y].type = TerrainTypes.Type.HAZARD
		terrain_grid[position.x][position.y].walkable = false
		walkable_tiles.erase(position)

func _get_valid_hazard_positions() -> Array[Vector2i]:
	var valid_positions: Array[Vector2i] = []
	for pos in walkable_tiles:
		if not pos in cover_points and not _is_near_objective(pos):
			valid_positions.append(pos)
	return valid_positions

func _is_near_objective(position: Vector2i) -> bool:
	for objective in objectives:
		if position.distance_to(objective.position) < 3:
			return true
	return false

func _apply_urban_effects() -> void:
	# Add urban-specific effects like increased cover height
	for x in range(config.size.x):
		for y in range(config.size.y):
			if terrain_grid[x][y].type == TerrainTypes.Type.WALL:
				terrain_grid[x][y].elevation += 1

func _apply_forest_effects() -> void:
	# Add forest-specific effects like scattered vegetation
	for x in range(config.size.x):
		for y in range(config.size.y):
			if terrain_grid[x][y].walkable and randf() < 0.2:
				terrain_grid[x][y].type = TerrainTypes.Type.DIFFICULT

func _apply_desert_effects() -> void:
	# Add desert-specific effects like elevation changes
	for x in range(config.size.x):
		for y in range(config.size.y):
			if terrain_grid[x][y].walkable and randf() < 0.15:
				terrain_grid[x][y].elevation += 1

func _apply_ice_effects() -> void:
	# Add ice-specific effects like slippery terrain
	for x in range(config.size.x):
		for y in range(config.size.y):
			if terrain_grid[x][y].walkable and randf() < 0.25:
				terrain_grid[x][y].type = TerrainTypes.Type.DIFFICULT

# ... existing code ...