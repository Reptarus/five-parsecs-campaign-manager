class_name BattlefieldGenerator
extends Node

signal battlefield_generated(data: Dictionary)
signal terrain_placed(piece: Node3D)
signal deployment_zone_created(zone: Node3D)
signal objective_placed(objective: Node3D)

# Terrain type definitions
const TERRAIN_CONFIGS := {
	"CITY": {
		"cover_density": 0.3,
		"building_density": 0.4,
		"hazard_density": 0.1,
		"elevation_chance": 0.2
	},
	"INDUSTRIAL": {
		"cover_density": 0.4,
		"building_density": 0.3,
		"hazard_density": 0.3,
		"elevation_chance": 0.3
	},
	"WILDERNESS": {
		"cover_density": 0.5,
		"building_density": 0.1,
		"hazard_density": 0.2,
		"elevation_chance": 0.4
	}
}

# Deployment zone configurations
const DEPLOYMENT_CONFIGS := {
	"STANDARD": {
		"player_zone": {"x": [0, 6], "y": [0, 20]},
		"enemy_zone": {"x": [14, 20], "y": [0, 20]}
	},
	"FLANK": {
		"player_zone": {"x": [0, 20], "y": [0, 6]},
		"enemy_zone": {"x": [0, 20], "y": [14, 20]}
	},
	"SCATTERED": {
		"zones": [
			{"x": [0, 6], "y": [0, 6]},
			{"x": [14, 20], "y": [14, 20]},
			{"x": [0, 6], "y": [14, 20]},
			{"x": [14, 20], "y": [0, 6]}
		]
	}
}

var current_mission: Mission
var terrain_nodes: Array[Node3D] = []
var objective_nodes: Array[Node3D] = []
var deployment_zones: Array[Node3D] = []
var grid_size := Vector2i(20, 20)
var cell_size := Vector2(32, 32)
var current_battle_state: Dictionary

func generate_battlefield(mission: Mission) -> Dictionary:
	current_mission = mission
	var terrain_config = _get_terrain_config(mission.type)
	var deployment_config = _get_deployment_config(mission.deployment_type)
	
	var battlefield_data = {
		"terrain": _generate_terrain(terrain_config),
		"objectives": _generate_objectives(mission),
		"deployment": _generate_deployment_zones(deployment_config),
		"grid_size": grid_size,
		"cell_size": cell_size
	}
	
	battlefield_generated.emit(battlefield_data)
	return battlefield_data

func _get_terrain_config(mission_type: int) -> Dictionary:
	match mission_type:
		GlobalEnums.Type.STREET_FIGHT:
			return TERRAIN_CONFIGS.CITY
		GlobalEnums.Type.INFILTRATION:
			return TERRAIN_CONFIGS.INDUSTRIAL
		_:
			return TERRAIN_CONFIGS.WILDERNESS

func _get_deployment_config(deployment_type: GlobalEnums.DeploymentType) -> Dictionary:
	# Convert enum to string for dictionary lookup
	var config_key = GlobalEnums.DeploymentType.keys()[deployment_type]
	return DEPLOYMENT_CONFIGS.get(config_key, DEPLOYMENT_CONFIGS.STANDARD)

func _generate_terrain(config: Dictionary) -> Array:
	var terrain_data = []
	
	# Generate cover
	var cover_count = int(grid_size.x * grid_size.y * config.cover_density)
	for i in range(cover_count):
		var position = _get_valid_terrain_position(terrain_data)
		terrain_data.append({
			"type": "COVER",
			"position": position,
			"rotation": randf() * PI
		})
	
	# Generate buildings
	var building_count = int(grid_size.x * grid_size.y * config.building_density)
	for i in range(building_count):
		var position = _get_valid_terrain_position(terrain_data)
		terrain_data.append({
			"type": "BUILDING",
			"position": position,
			"rotation": randf() * PI
		})
	
	# Add hazards and elevation
	_add_hazards(terrain_data, config)
	_add_elevation(terrain_data, config)
	
	return terrain_data

func export_battlefield(path: String = "") -> void:
	if path.is_empty():
		path = "user://battlefields/"
		if not DirAccess.dir_exists_absolute(path):
			DirAccess.make_dir_recursive_absolute(path)
		path += "battlefield_%d.png" % Time.get_unix_time_from_system()
	
	var viewport = SubViewport.new()
	viewport.size = Vector2(grid_size.x, grid_size.y) * cell_size
	viewport.transparent_bg = true
	
	var battlefield_view = Node2D.new()
	viewport.add_child(battlefield_view)
	
	# Draw terrain
	for terrain in terrain_nodes:
		var sprite = Sprite2D.new()
		sprite.texture = _get_terrain_texture(terrain.type)
		sprite.position = terrain.position
		sprite.rotation = terrain.rotation
		battlefield_view.add_child(sprite)
	
	# Draw objectives and deployment zones
	for objective in objective_nodes:
		var sprite = Sprite2D.new()
		sprite.texture = load("res://assets/textures/objective_marker.png")
		sprite.position = objective.position
		battlefield_view.add_child(sprite)
	
	for zone in deployment_zones:
		var rect = ColorRect.new()
		rect.color = Color(1, 1, 0, 0.3)
		rect.position = zone.position
		rect.size = zone.size
		battlefield_view.add_child(rect)
	
	# Capture the viewport
	var image = viewport.get_texture().get_image()
	image.save_png(path)
	
	# Cleanup
	viewport.queue_free()

func _get_terrain_texture(type: String) -> Texture2D:
	match type:
		"COVER":
			return load("res://assets/textures/cover.png")
		"BUILDING":
			return load("res://assets/textures/building.png")
		"HAZARD":
			return load("res://assets/textures/hazard.png")
		"ELEVATION":
			return load("res://assets/textures/elevation.png")
		_:
			return load("res://assets/textures/default_terrain.png")

func _add_hazards(terrain_data: Array, config: Dictionary) -> void:
	var hazard_count = int(grid_size.x * grid_size.y * config.hazard_density)
	for i in range(hazard_count):
		var position = _get_valid_terrain_position(terrain_data)
		terrain_data.append({
			"type": "HAZARD",
			"position": position,
			"effect": _generate_hazard_effect()
		})

func _add_elevation(terrain_data: Array, config: Dictionary) -> void:
	var elevation_count = int(grid_size.x * grid_size.y * config.elevation_chance)
	for i in range(elevation_count):
		var position = _get_valid_terrain_position(terrain_data)
		terrain_data.append({
			"type": "ELEVATION",
			"position": position,
			"height": randi() % 3 + 1
		})

func _generate_hazard_effect() -> Dictionary:
	var effects = [
		{"type": "DAMAGE", "value": 1},
		{"type": "SLOW", "value": 0.5},
		{"type": "STUN", "value": 1}
	]
	return effects[randi() % effects.size()]

# ... rest of the existing helper functions ...

func generate_tutorial_battlefield(tutorial_step: String) -> Dictionary:
	var layout = TutorialBattlefieldLayouts.get_layout(tutorial_step)
	
	# Clear existing battlefield
	for child in terrain_nodes:
		child.queue_free()
	terrain_nodes.clear()
	
	for child in objective_nodes:
		child.queue_free()
	objective_nodes.clear()
	
	# Generate terrain based on layout
	var terrain_data = []
	for terrain in layout.terrain:
		var terrain_piece = _create_tutorial_terrain(terrain)
		if terrain_piece:
			terrain_nodes.append(terrain_piece)
			terrain_data.append({
				"type": terrain.type,
				"position": terrain.position,
				"rotation": terrain_piece.rotation
			})
	
	# Generate objectives based on layout
	var objective_data = []
	for objective in layout.objectives:
		var obj_marker = _create_tutorial_objective(objective)
		if obj_marker:
			objective_nodes.append(obj_marker)
			objective_data.append({
				"type": objective.type,
				"position": objective.position
			})
	
	return {
		"grid_size": layout.grid_size,
		"player_start": layout.player_start,
		"terrain": terrain_data,
		"objectives": objective_data,
		"enemies": layout.enemies
	}

func _create_tutorial_terrain(terrain_data: Dictionary) -> Node3D:
	var scene_path = "res://Resources/BattlePhase/Scenes/TerrainPieces/"
	match terrain_data.type:
		"COVER":
			scene_path += "CoverPiece.tscn"
		"BUILDING":
			scene_path += "Building.tscn"
		"ELEVATED":
			scene_path += "ElevatedPosition.tscn"
		"HAZARD":
			scene_path += "HazardArea.tscn"
		_:
			return null
	
	var terrain_scene = load(scene_path)
	if terrain_scene:
		var terrain_piece = terrain_scene.instantiate()
		terrain_piece.position = terrain_data.position
		terrain_piece.rotation.y = randf() * PI
		return terrain_piece
	return null

func _create_tutorial_objective(objective_data: Dictionary) -> Node3D:
	var scene_path = "res://Resources/BattlePhase/Scenes/Objectives/ObjectiveMarker.tscn"
	var objective_scene = load(scene_path)
	if objective_scene:
		var obj_marker = objective_scene.instantiate()
		obj_marker.position = objective_data.position
		obj_marker.objective_type = objective_data.type
		return obj_marker
	return null

const STORY_MISSION_CONFIGS := {
	"introduction": {
		"terrain_density": 0.3,
		"enemy_density": 0.2,
		"objective_count": 1,
		"special_features": ["story_marker", "tutorial_zone"]
	},
	"development": {
		"terrain_density": 0.4,
		"enemy_density": 0.3,
		"objective_count": 2,
		"special_features": ["story_objective", "hidden_cache"]
	},
	"climax": {
		"terrain_density": 0.5,
		"enemy_density": 0.4,
		"objective_count": 3,
		"special_features": ["boss_arena", "escape_route"]
	}
}

func generate_story_battlefield(story_phase: String, mission: Mission) -> Dictionary:
	var config = STORY_MISSION_CONFIGS.get(story_phase, STORY_MISSION_CONFIGS.introduction)
	var battlefield_data = generate_battlefield(mission)  # Get base battlefield
	
	# Add story-specific elements
	battlefield_data.story_elements = _generate_story_elements(config)
	battlefield_data.special_features = _create_special_features(config.special_features)
	
	# Adjust terrain and enemy placement for story missions
	_adjust_for_story_mission(battlefield_data, config)
	
	return battlefield_data

func _generate_story_elements(config: Dictionary) -> Array:
	var elements = []
	
	# Add story markers
	if "story_marker" in config.special_features:
		elements.append({
			"type": "story_marker",
			"position": _get_valid_story_position(),
			"interaction_radius": 3
		})
	
	# Add story objectives
	for i in range(config.objective_count):
		elements.append({
			"type": "story_objective",
			"position": _get_valid_story_position(),
			"required": true,
			"completion_effect": _generate_completion_effect()
		})
	
	return elements

func _create_special_features(features: Array) -> Array:
	var special_features = []
	
	for feature in features:
		match feature:
			"boss_arena":
				special_features.append(_create_boss_arena())
			"escape_route":
				special_features.append(_create_escape_route())
			"hidden_cache":
				special_features.append(_create_hidden_cache())
			"tutorial_zone":
				special_features.append(_create_tutorial_zone())
	
	return special_features

func _adjust_for_story_mission(battlefield_data: Dictionary, config: Dictionary) -> void:
	# Adjust terrain placement for story elements
	for story_element in battlefield_data.story_elements:
		_ensure_clear_path_to_element(battlefield_data, story_element)
		_add_surrounding_cover(battlefield_data, story_element)
	
	# Adjust enemy placement
	if "boss_arena" in config.special_features:
		_setup_boss_encounter(battlefield_data)
	
	# Add tutorial guidance if needed
	if "tutorial_zone" in config.special_features:
		_add_tutorial_markers(battlefield_data)

func _create_boss_arena() -> Dictionary:
	return {
		"type": "boss_arena",
		"position": _get_valid_story_position(),
		"size": Vector2(5, 5),
		"cover_points": _generate_cover_points(4),
		"entrance_points": _generate_entrance_points(2)
	}

func _create_escape_route() -> Dictionary:
	return {
		"type": "escape_route",
		"start": _get_valid_story_position(),
		"end": _get_valid_story_position(),
		"checkpoints": _generate_checkpoints(3)
	}

func _create_hidden_cache() -> Dictionary:
	return {
		"type": "hidden_cache",
		"position": _get_valid_story_position(),
		"discovery_radius": 2,
		"contents": _generate_cache_contents()
	}

func _create_tutorial_zone() -> Dictionary:
	return {
		"type": "tutorial_zone",
		"position": _get_valid_story_position(),
		"size": Vector2(4, 4),
		"training_elements": [
			{"type": "movement_marker", "position": Vector2(1, 1)},
			{"type": "combat_dummy", "position": Vector2(2, 2)},
			{"type": "cover_example", "position": Vector2(3, 1)}
		]
	}

# Helper functions for story battlefield generation
func _get_valid_story_position() -> Vector2:
	var position = Vector2.ZERO
	var attempts = 0
	var valid = false
	
	while not valid and attempts < 100:
		position = Vector2(
			randf_range(2, grid_size.x - 2),
			randf_range(2, grid_size.y - 2)
		)
		valid = _is_position_valid_for_story(position)
		attempts += 1
	
	return position

func _is_position_valid_for_story(position: Vector2) -> bool:
	# Check if story_elements exists in current_battle_state
	if not current_battle_state.has("story_elements"):
		return true
		
	# Check distance from other story elements
	for element in current_battle_state.story_elements:
		if position.distance_to(element.position) < 5:
			return false
	
	return true

func _ensure_clear_path_to_element(battlefield_data: Dictionary, element: Dictionary) -> void:
	var path = _find_path_to_element(battlefield_data, element)
	for point in path:
		_clear_obstacles(battlefield_data, point)
		_add_path_markers(battlefield_data, point)

func _add_surrounding_cover(battlefield_data: Dictionary, element: Dictionary) -> void:
	var cover_points = _generate_cover_points(3)
	for point in cover_points:
		var cover_position = element.position + point
		if _is_position_valid_for_story(cover_position):
			battlefield_data.terrain.append({
				"type": "COVER",
				"position": cover_position,
				"rotation": randf() * PI
			})

# Add these missing functions
func _get_valid_terrain_position(terrain_data: Array) -> Vector2:
	var position = Vector2.ZERO
	var attempts = 0
	var valid = false
	
	while not valid and attempts < 100:
		position = Vector2(
			randf_range(2, grid_size.x - 2),
			randf_range(2, grid_size.y - 2)
		)
		valid = true
		
		# Check distance from other terrain
		for terrain in terrain_data:
			if position.distance_to(terrain.position) < 3:
				valid = false
				break
		
		attempts += 1
	
	return position

func _generate_objectives(mission: Mission) -> Array:
	var objectives = []
	match mission.objective:
		GlobalEnums.MissionObjective.ACQUIRE:
			objectives.append({
				"type": "ITEM",
				"position": _get_valid_terrain_position([])
			})
		GlobalEnums.MissionObjective.MOVE_THROUGH:
			objectives.append({
				"type": "EXIT",
				"position": _get_valid_terrain_position([])
			})
		# Add other objective types...
	return objectives

func _generate_deployment_zones(deployment_config: Dictionary) -> Array:
	var zones = []
	if deployment_config.has("player_zone"):
		zones.append({
			"type": "PLAYER",
			"area": deployment_config.player_zone
		})
	if deployment_config.has("enemy_zone"):
		zones.append({
			"type": "ENEMY",
			"area": deployment_config.enemy_zone
		})
	return zones

func _generate_completion_effect() -> Dictionary:
	return {
		"type": "REWARD",
		"value": randi() % 100 + 50
	}

func _setup_boss_encounter(battlefield_data: Dictionary) -> void:
	var boss_arena = _create_boss_arena()
	battlefield_data.special_features.append(boss_arena)

func _add_tutorial_markers(battlefield_data: Dictionary) -> void:
	var tutorial_zone = _create_tutorial_zone()
	battlefield_data.special_features.append(tutorial_zone)

func _generate_cover_points(count: int) -> Array:
	var points = []
	for i in range(count):
		points.append(Vector2(
			randf_range(-2, 2),
			randf_range(-2, 2)
		))
	return points

func _generate_entrance_points(count: int) -> Array:
	var points = []
	for i in range(count):
		points.append(Vector2(
			randf_range(-3, 3),
			randf_range(-3, 3)
		))
	return points

func _generate_checkpoints(count: int) -> Array:
	var points = []
	for i in range(count):
		points.append(_get_valid_story_position())
	return points

func _generate_cache_contents() -> Array:
	return [
		{"type": "AMMO", "amount": randi() % 20 + 10},
		{"type": "MEDKIT", "amount": randi() % 3 + 1}
	]

func _is_position_accessible(position: Vector2) -> bool:
	# Check if position is within grid bounds
	if position.x < 0 or position.x >= grid_size.x:
		return false
	if position.y < 0 or position.y >= grid_size.y:
		return false
		
	# Add additional accessibility checks here
	return true

func _find_path_to_element(battlefield_data: Dictionary, element: Dictionary) -> Array:
	# Simple direct path implementation
	var start = Vector2.ZERO
	var end = element.position
	var path = []
	
	# Add points along the line
	var distance = start.distance_to(end)
	var steps = int(distance / 2)
	for i in range(steps):
		var t = float(i) / steps
		path.append(start.lerp(end, t))
	
	return path

func _clear_obstacles(battlefield_data: Dictionary, point: Vector2) -> void:
	# Remove any terrain pieces at this point
	for terrain in battlefield_data.terrain:
		if terrain.position.distance_to(point) < 1.0:
			battlefield_data.terrain.erase(terrain)

func _add_path_markers(battlefield_data: Dictionary, point: Vector2) -> void:
	battlefield_data.path_markers.append({
		"position": point,
		"type": "PATH"
	})

func initialize(battle_state: Dictionary = {}) -> void:
	current_battle_state = battle_state
