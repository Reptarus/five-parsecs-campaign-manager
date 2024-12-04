class_name BattlefieldGenerator
extends Node

const TerrainTypes = preload("res://Battle/TerrainTypes.gd")
const GlobalEnums = preload("res://Resources/GameData/GlobalEnums.gd")

signal battlefield_generated(data: Dictionary)
signal generation_progress(step: String, progress: float)

enum GenerationStep {
	TERRAIN,
	OBJECTIVES,
	DEPLOYMENT,
	VALIDATION
}

# Configuration constants
const MIN_DISTANCE_BETWEEN_TERRAIN := 2.0
const MIN_DISTANCE_FROM_EDGE := 1
const MIN_DISTANCE_BETWEEN_OBJECTIVES := 5.0
const MIN_PATH_WIDTH := 2

# Objective placement configurations
const OBJECTIVE_CONFIGS = {
	GlobalEnums.MissionObjective.MOVE_THROUGH: {
		"count": 2,
		"placement": "linear",
		"spacing": 12
	},
	GlobalEnums.MissionObjective.RETRIEVE: {
		"count": 1,
		"placement": "center",
		"spacing": 0
	},
	GlobalEnums.MissionObjective.CONTROL_POINT: {
		"count": 3,
		"placement": "scattered",
		"spacing": 8
	},
	GlobalEnums.MissionObjective.DEFEND: {
		"count": 1,
		"placement": "player_zone",
		"spacing": 0
	},
	GlobalEnums.MissionObjective.ELIMINATE_TARGET: {
		"count": 1,
		"placement": "enemy_zone",
		"spacing": 0
	},
	GlobalEnums.MissionObjective.PENETRATE_LINES: {
		"count": 1,
		"placement": "enemy_edge",
		"spacing": 0
	},
	GlobalEnums.MissionObjective.SABOTAGE: {
		"count": 2,
		"placement": "enemy_zone",
		"spacing": 6
	},
	GlobalEnums.MissionObjective.SECURE_INTEL: {
		"count": 3,
		"placement": "scattered",
		"spacing": 10
	},
	GlobalEnums.MissionObjective.CLEAR_ZONE: {
		"count": 4,
		"placement": "quadrants",
		"spacing": 0
	},
	GlobalEnums.MissionObjective.RESCUE: {
		"count": 1,
		"placement": "enemy_zone",
		"spacing": 0
	},
	GlobalEnums.MissionObjective.ESCORT: {
		"count": 2,
		"placement": "linear",
		"spacing": 16
	}
}

# Terrain type definitions
const TERRAIN_CONFIGS = {
	"urban": {
		"cover_density": 0.3,
		"building_density": 0.4,
		"elevation_chance": 0.2
	},
	"industrial": {
		"cover_density": 0.4,
		"building_density": 0.3,
		"hazard_density": 0.3,
		"elevation_chance": 0.15
	},
	"wilderness": {
		"cover_density": 0.5,
		"building_density": 0.1,
		"hazard_density": 0.2,
		"elevation_chance": 0.3
	}
}

# Deployment zone configurations
const DEPLOYMENT_CONFIGS = {
	GlobalEnums.DeploymentType.STANDARD: {
		"player_zone": {"x": 0, "y": 0, "width": 6, "height": 24},
		"enemy_zone": {"x": 18, "y": 0, "width": 6, "height": 24}
	},
	GlobalEnums.DeploymentType.FLANK: {
		"player_zone": {"x": 0, "y": 0, "width": 24, "height": 6},
		"enemy_zone": {"x": 0, "y": 18, "width": 24, "height": 6}
	},
	GlobalEnums.DeploymentType.SCATTERED: {
		"zones": [
			{"x": 0, "y": 0, "width": 6, "height": 6},
			{"x": 18, "y": 18, "width": 6, "height": 6},
			{"x": 0, "y": 18, "width": 6, "height": 6},
			{"x": 18, "y": 0, "width": 6, "height": 6}
		]
	},
	GlobalEnums.DeploymentType.SURROUNDED: {
		"player_zone": {"x": 9, "y": 9, "width": 6, "height": 6},
		"enemy_zones": [
			{"x": 0, "y": 0, "width": 24, "height": 6},
			{"x": 0, "y": 18, "width": 24, "height": 6},
			{"x": 0, "y": 6, "width": 6, "height": 12},
			{"x": 18, "y": 6, "width": 6, "height": 12}
		]
	},
	GlobalEnums.DeploymentType.ASYMMETRIC: {
		"player_zone": {"x": 0, "y": 0, "width": 8, "height": 24},
		"enemy_zone": {"x": 16, "y": 8, "width": 8, "height": 8}
	},
	GlobalEnums.DeploymentType.CORNER: {
		"player_zone": {"x": 0, "y": 0, "width": 8, "height": 8},
		"enemy_zone": {"x": 16, "y": 16, "width": 8, "height": 8}
	},
	GlobalEnums.DeploymentType.DIAGONAL: {
		"zones": [
			{"x": 0, "y": 0, "width": 6, "height": 6},
			{"x": 6, "y": 6, "width": 6, "height": 6},
			{"x": 12, "y": 12, "width": 6, "height": 6},
			{"x": 18, "y": 18, "width": 6, "height": 6}
		]
	}
}

var current_mission: Dictionary
var grid_size := Vector2i(24, 24)
var cell_size := Vector2(32, 32)
var rng := RandomNumberGenerator.new()
var terrain_densities: Dictionary = {}

func _ready() -> void:
	rng.randomize()

func generate_battlefield(mission: Dictionary) -> Dictionary:
	current_mission = mission
	generation_progress.emit("Starting generation", 0.0)
	
	var battlefield_data = {
		"grid_size": grid_size,
		"cell_size": cell_size,
		"terrain": [],
		"objectives": [],
		"deployment_zones": [],
		"path_markers": []
	}
	
	# Generate in steps
	_generate_terrain(battlefield_data)
	_generate_objectives(battlefield_data)
	_generate_deployment_zones(battlefield_data)
	_validate_and_fix_battlefield(battlefield_data)
	
	generation_progress.emit("Generation complete", 1.0)
	battlefield_generated.emit(battlefield_data)
	return battlefield_data

func update_terrain_density(terrain_type: int, density: float) -> void:
	terrain_densities[terrain_type] = density

func _calculate_terrain_densities() -> Dictionary:
	var densities = {}
	
	# Use custom densities if set, otherwise use defaults
	for terrain_type in TerrainTypes.Type.values():
		if terrain_type == TerrainTypes.Type.EMPTY:
			continue
			
		if terrain_densities.has(terrain_type):
			densities[terrain_type] = terrain_densities[terrain_type]
		else:
			densities[terrain_type] = _get_default_density(terrain_type)
	
	# Adjust based on mission type
	match current_mission.mission_type:
		"urban":
			densities[TerrainTypes.Type.WALL] *= 1.5
			densities[TerrainTypes.Type.COVER_HIGH] *= 1.3
		"wilderness":
			densities[TerrainTypes.Type.COVER_LOW] *= 1.5
			densities[TerrainTypes.Type.DIFFICULT] *= 1.3
		"industrial":
			densities[TerrainTypes.Type.HAZARDOUS] *= 1.5
			densities[TerrainTypes.Type.ELEVATED] *= 1.3
	
	return densities

func _get_default_density(terrain_type: int) -> float:
	match terrain_type:
		TerrainTypes.Type.WALL: return 0.05
		TerrainTypes.Type.COVER_LOW: return 0.15
		TerrainTypes.Type.COVER_HIGH: return 0.10
		TerrainTypes.Type.DIFFICULT: return 0.08
		TerrainTypes.Type.HAZARDOUS: return 0.05
		TerrainTypes.Type.ELEVATED: return 0.07
		TerrainTypes.Type.WATER: return 0.03
		_: return 0.0

func _generate_terrain(battlefield_data: Dictionary) -> void:
	generation_progress.emit("Generating terrain", 0.1)
	
	var densities = _calculate_terrain_densities()
	
	for terrain_type in TerrainTypes.Type.values():
		if terrain_type == TerrainTypes.Type.EMPTY:
			continue
			
		var count = int(densities[terrain_type] * (grid_size.x * grid_size.y))
		for i in range(count):
			var position = _find_valid_terrain_position(battlefield_data.terrain)
			if position != Vector2.ZERO:
				battlefield_data.terrain.append({
					"type": terrain_type,
					"position": position,
					"rotation": rng.randf() * PI * 2
				})
			
			var progress = float(i) / count
			generation_progress.emit(
				"Generating %s terrain" % TerrainTypes.Type.keys()[terrain_type],
				0.1 + progress * 0.3
			)

func _generate_objectives(battlefield_data: Dictionary) -> void:
	generation_progress.emit("Generating objectives", 0.4)
	
	var mission_type = current_mission.get("mission_type", GlobalEnums.MissionType.GREEN_ZONE)
	var objective_type = _get_mission_objective_type(mission_type)
	var config = OBJECTIVE_CONFIGS.get(objective_type, {"count": 1, "placement": "center", "spacing": 0})
	
	var objective_positions = _generate_objective_positions(battlefield_data, config)
	for i in range(len(objective_positions)):
		battlefield_data.objectives.append({
			"type": objective_type,
			"position": objective_positions[i],
			"properties": _get_objective_properties(objective_type)
		})
		
		generation_progress.emit(
			"Placing objective %d" % (i + 1),
			0.4 + float(i) / len(objective_positions) * 0.3
		)

func _get_mission_objective_type(mission_type: GlobalEnums.MissionType) -> GlobalEnums.MissionObjective:
	match mission_type:
		GlobalEnums.MissionType.ASSASSINATION:
			return GlobalEnums.MissionObjective.ELIMINATE_TARGET
		GlobalEnums.MissionType.SABOTAGE:
			return GlobalEnums.MissionObjective.SABOTAGE
		GlobalEnums.MissionType.RESCUE:
			return GlobalEnums.MissionObjective.RESCUE
		GlobalEnums.MissionType.DEFENSE:
			return GlobalEnums.MissionObjective.DEFEND
		GlobalEnums.MissionType.ESCORT:
			return GlobalEnums.MissionObjective.ESCORT
		_:
			# For zone missions, randomly select between common objectives
			var zone_objectives = [
				GlobalEnums.MissionObjective.MOVE_THROUGH,
				GlobalEnums.MissionObjective.RETRIEVE,
				GlobalEnums.MissionObjective.CONTROL_POINT,
				GlobalEnums.MissionObjective.SECURE_INTEL,
				GlobalEnums.MissionObjective.CLEAR_ZONE
			]
			return zone_objectives[rng.randi() % zone_objectives.size()]

func _generate_objective_positions(battlefield_data: Dictionary, config: Dictionary) -> Array:
	var positions = []
	var count = config.get("count", 1)
	var placement = config.get("placement", "center")
	var spacing = config.get("spacing", 0)
	
	match placement:
		"center":
			positions.append(Vector2(grid_size.x / 2, grid_size.y / 2))
		"linear":
			var start_x = grid_size.x / 4
			var step = spacing if spacing > 0 else grid_size.x / (count + 1)
			for i in range(count):
				positions.append(Vector2(start_x + i * step, grid_size.y / 2))
		"scattered":
			for i in range(count):
				var pos = _find_valid_objective_position(battlefield_data, positions)
				if pos != Vector2.ZERO:
					positions.append(pos)
		"quadrants":
			var quadrant_size = Vector2(grid_size.x / 2, grid_size.y / 2)
			for i in range(min(count, 4)):
				var quadrant = Vector2(i % 2, i / 2)
				positions.append(quadrant * quadrant_size + quadrant_size / 2)
		"player_zone", "enemy_zone", "enemy_edge":
			var zones = battlefield_data.get("deployment_zones", [])
			var target_zone = null
			for zone in zones:
				if (placement == "player_zone" and zone.type == "player") or \
				   (placement in ["enemy_zone", "enemy_edge"] and zone.type == "enemy"):
					target_zone = zone
					break
			
			if target_zone:
				var zone_pos = target_zone.position
				var zone_size = target_zone.size
				for i in range(count):
					var pos = Vector2(
						zone_pos.x + rng.randf() * zone_size.x,
						zone_pos.y + rng.randf() * zone_size.y
					)
					positions.append(pos)
	
	return positions

func _get_objective_properties(objective_type: GlobalEnums.MissionObjective) -> Dictionary:
	var properties = {
		"victory_points": 1,
		"required": true,
		"visible": true
	}
	
	match objective_type:
		GlobalEnums.MissionObjective.CONTROL_POINT:
			properties.victory_points = 2
			properties.capture_time = 2
		GlobalEnums.MissionObjective.ELIMINATE_TARGET:
			properties.victory_points = 3
			properties.target_health = 3
		GlobalEnums.MissionObjective.SABOTAGE:
			properties.victory_points = 2
			properties.sabotage_time = 2
		GlobalEnums.MissionObjective.SECURE_INTEL:
			properties.victory_points = 1
			properties.intel_value = rng.randi_range(1, 3)
		GlobalEnums.MissionObjective.RESCUE:
			properties.victory_points = 3
			properties.escort_required = true
		_:
			pass
	
	return properties

func _generate_deployment_zones(battlefield_data: Dictionary) -> void:
	generation_progress.emit("Generating deployment zones", 0.7)
	
	var deployment_type = current_mission.get("deployment_type", GlobalEnums.DeploymentType.STANDARD)
	if not DEPLOYMENT_CONFIGS.has(deployment_type):
		deployment_type = GlobalEnums.DeploymentType.STANDARD
		push_warning("Invalid deployment type specified, falling back to STANDARD")
	
	var config = DEPLOYMENT_CONFIGS[deployment_type]
	
	if config.has("player_zone"):
		battlefield_data.deployment_zones.append({
			"type": "player",
			"position": Vector2(config.player_zone.x, config.player_zone.y),
			"size": Vector2(config.player_zone.width, config.player_zone.height)
		})
	
	if config.has("enemy_zone"):
		battlefield_data.deployment_zones.append({
			"type": "enemy",
			"position": Vector2(config.enemy_zone.x, config.enemy_zone.y),
			"size": Vector2(config.enemy_zone.width, config.enemy_zone.height)
		})
	elif config.has("enemy_zones"):
		for zone in config.enemy_zones:
			battlefield_data.deployment_zones.append({
				"type": "enemy",
				"position": Vector2(zone.x, zone.y),
				"size": Vector2(zone.width, zone.height)
			})
	elif config.has("zones"):
		var is_player = true
		for zone in config.zones:
			battlefield_data.deployment_zones.append({
				"type": "player" if is_player else "enemy",
				"position": Vector2(zone.x, zone.y),
				"size": Vector2(zone.width, zone.height)
			})
			is_player = not is_player
	
	generation_progress.emit("Deployment zones placed", 0.8)

func _validate_and_fix_battlefield(battlefield_data: Dictionary) -> void:
	generation_progress.emit("Validating battlefield", 0.9)
	
	# Ensure paths between objectives are accessible
	_ensure_objective_accessibility(battlefield_data)
	
	# Ensure deployment zones are accessible
	_ensure_deployment_zone_accessibility(battlefield_data)
	
	# Balance terrain distribution
	_balance_terrain_distribution(battlefield_data)
	
	generation_progress.emit("Validation complete", 0.95)

# Helper functions
func _find_valid_terrain_position(existing_terrain: Array) -> Vector2:
	var attempts := 0
	while attempts < 100:
		var pos = Vector2(
			rng.randi_range(MIN_DISTANCE_FROM_EDGE, grid_size.x - MIN_DISTANCE_FROM_EDGE),
			rng.randi_range(MIN_DISTANCE_FROM_EDGE, grid_size.y - MIN_DISTANCE_FROM_EDGE)
		)
		
		if _is_position_valid_for_terrain(pos, existing_terrain):
			return pos
			
		attempts += 1
	
	return Vector2.ZERO

func _is_position_valid_for_terrain(pos: Vector2, existing_terrain: Array) -> bool:
	# Check distance from other terrain
	for terrain in existing_terrain:
		if pos.distance_to(terrain.position) < MIN_DISTANCE_BETWEEN_TERRAIN:
			return false
	
	return true

func _find_valid_objective_position(battlefield_data: Dictionary, existing_objectives: Array) -> Vector2:
	var attempts := 0
	while attempts < 100:
		var pos = Vector2(
			rng.randi_range(MIN_DISTANCE_FROM_EDGE, grid_size.x - MIN_DISTANCE_FROM_EDGE),
			rng.randi_range(MIN_DISTANCE_FROM_EDGE, grid_size.y - MIN_DISTANCE_FROM_EDGE)
		)
		
		if _is_position_valid_for_objective(pos, battlefield_data, existing_objectives):
			return pos
			
		attempts += 1
	
	return Vector2.ZERO

func _is_position_valid_for_objective(pos: Vector2, battlefield_data: Dictionary, existing_objectives: Array) -> bool:
	# Check distance from terrain
	for terrain in battlefield_data.terrain:
		if pos.distance_to(terrain.position) < MIN_DISTANCE_BETWEEN_TERRAIN:
			return false
	
	# Check distance from other objectives
	for obj_pos in existing_objectives:
		if pos.distance_to(obj_pos) < MIN_DISTANCE_BETWEEN_OBJECTIVES:
			return false
	
	return true

func _ensure_objective_accessibility(battlefield_data: Dictionary) -> void:
	var pathfinder = AStar2D.new()
	
	# Add all valid points to the pathfinder
	for x in range(grid_size.x):
		for y in range(grid_size.y):
			var pos = Vector2(x, y)
			if _is_position_walkable(pos, battlefield_data):
				pathfinder.add_point(
					_get_point_id(pos),
					pos,
					1.0
				)
	
	# Connect adjacent points
	for x in range(grid_size.x):
		for y in range(grid_size.y):
			var pos = Vector2(x, y)
			var point_id = _get_point_id(pos)
			
			if not pathfinder.has_point(point_id):
				continue
			
			for dx in [-1, 0, 1]:
				for dy in [-1, 0, 1]:
					if dx == 0 and dy == 0:
						continue
					
					var next_pos = pos + Vector2(dx, dy)
					var next_id = _get_point_id(next_pos)
					
					if pathfinder.has_point(next_id):
						pathfinder.connect_points(point_id, next_id)
	
	# Ensure paths between objectives
	for i in range(len(battlefield_data.objectives)):
		for j in range(i + 1, len(battlefield_data.objectives)):
			var start_pos = battlefield_data.objectives[i].position
			var end_pos = battlefield_data.objectives[j].position
			
			var path = pathfinder.get_point_path(
				_get_point_id(start_pos),
				_get_point_id(end_pos)
			)
			
			if path.is_empty():
				_clear_path_between_points(battlefield_data, start_pos, end_pos)

func _ensure_deployment_zone_accessibility(battlefield_data: Dictionary) -> void:
	for zone in battlefield_data.deployment_zones:
		var zone_center = zone.position + zone.size / 2
		
		# Clear immediate area around deployment zone
		for x in range(zone.position.x - 1, zone.position.x + zone.size.x + 1):
			for y in range(zone.position.y - 1, zone.position.y + zone.size.y + 1):
				var pos = Vector2(x, y)
				_remove_terrain_at_position(battlefield_data, pos)
		
		# Ensure path to center of map
		var map_center = Vector2(grid_size.x / 2, grid_size.y / 2)
		_clear_path_between_points(battlefield_data, zone_center, map_center)

func _balance_terrain_distribution(battlefield_data: Dictionary) -> void:
	# Calculate terrain density in each quadrant
	var quadrants = []
	var quadrant_size = Vector2(grid_size.x / 2, grid_size.y / 2)
	
	for x in range(2):
		for y in range(2):
			var quadrant = {
				"position": Vector2(x * quadrant_size.x, y * quadrant_size.y),
				"size": quadrant_size,
				"terrain_count": 0
			}
			
			for terrain in battlefield_data.terrain:
				if _is_position_in_rect(terrain.position, quadrant.position, quadrant.size):
					quadrant.terrain_count += 1
			
			quadrants.append(quadrant)
	
	# Balance terrain between quadrants
	var avg_terrain = 0
	for quadrant in quadrants:
		avg_terrain += quadrant.terrain_count
	avg_terrain /= len(quadrants)
	
	for quadrant in quadrants:
		while quadrant.terrain_count > avg_terrain * 1.5:
			# Remove excess terrain
			for terrain in battlefield_data.terrain:
				if _is_position_in_rect(terrain.position, quadrant.position, quadrant.size):
					battlefield_data.terrain.erase(terrain)
					quadrant.terrain_count -= 1
					break

func _get_point_id(pos: Vector2) -> int:
	return int(pos.x + pos.y * grid_size.x)

func _is_position_walkable(pos: Vector2, battlefield_data: Dictionary) -> bool:
	# Check if position is within grid
	if pos.x < 0 or pos.x >= grid_size.x or pos.y < 0 or pos.y >= grid_size.y:
		return false
	
	# Check if position has blocking terrain
	for terrain in battlefield_data.terrain:
		if terrain.position == pos:
			var terrain_type = terrain.type
			if TerrainTypes.blocks_movement(terrain_type):
				return false
	
	return true

func _clear_path_between_points(battlefield_data: Dictionary, start: Vector2, end: Vector2) -> void:
	var direction = (end - start).normalized()
	var distance = start.distance_to(end)
	var current = start
	
	while current.distance_to(end) > 1.0:
		# Clear terrain in a width around the path
		for dx in range(-MIN_PATH_WIDTH, MIN_PATH_WIDTH + 1):
			for dy in range(-MIN_PATH_WIDTH, MIN_PATH_WIDTH + 1):
				var clear_pos = current + Vector2(dx, dy)
				_remove_terrain_at_position(battlefield_data, clear_pos)
		
		current += direction * MIN_PATH_WIDTH

func _remove_terrain_at_position(battlefield_data: Dictionary, pos: Vector2) -> void:
	battlefield_data.terrain = battlefield_data.terrain.filter(
		func(terrain): return terrain.position != pos
	)

func _is_position_in_rect(pos: Vector2, rect_pos: Vector2, rect_size: Vector2) -> bool:
	return pos.x >= rect_pos.x and pos.x < rect_pos.x + rect_size.x and \
		   pos.y >= rect_pos.y and pos.y < rect_pos.y + rect_size.y
