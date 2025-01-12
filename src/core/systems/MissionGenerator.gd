@tool
class_name MissionGenerator
extends Node

## Dependencies
const Mission := preload("res://src/core/systems/Mission.gd")
const TerrainSystem := preload("res://src/core/terrain/TerrainSystem.gd")
const RivalSystem := preload("res://src/core/rivals/RivalSystem.gd")
const PositionValidator := preload("res://src/core/systems/PositionValidator.gd")

## Mission generation parameters
const MIN_OBJECTIVES := 1
const MAX_OBJECTIVES := 3
const MIN_DEPLOYMENT_POINTS := 2
const MAX_DEPLOYMENT_POINTS := 4

## References to required systems
@export var terrain_system: TerrainSystem
@export var rival_system: RivalSystem
var position_validator: PositionValidator

func _ready() -> void:
	position_validator = PositionValidator.new()
	position_validator.terrain_system = terrain_system
	add_child(position_validator)

func _exit_tree() -> void:
	if position_validator:
		position_validator.queue_free()

## Generates a complete mission from a template
func generate_mission(template: MissionTemplate) -> Mission:
	if not _validate_requirements(template):
		push_error("Failed to validate mission template requirements")
		return null
	
	var mission := Mission.new()
	_apply_template(mission, template)
	_setup_rival_involvement(mission)
	_generate_terrain_layout(mission)
	_place_objectives(mission)
	_setup_deployment_zones(mission)
	
	return mission

## Validates mission template requirements
func _validate_requirements(template: MissionTemplate) -> bool:
	if not template.validate():
		return false
	
	if not terrain_system:
		push_error("No terrain system assigned to mission generator")
		return false
	
	return true

## Applies template data to mission
func _apply_template(mission: Mission, template: MissionTemplate) -> void:
	mission.mission_type = template.type
	mission.mission_name = _generate_mission_name(template)
	mission.difficulty = _get_difficulty_from_range(template.difficulty_range)
	
	# Set rewards
	var reward_amount := _calculate_reward(template.reward_range, mission.difficulty)
	mission.rewards = {
		"credits": reward_amount,
		"items": _generate_reward_items(mission.difficulty),
		"reputation": _calculate_reputation_reward(mission.difficulty)
	}

## Sets up rival involvement in the mission
func _setup_rival_involvement(mission: Mission) -> void:
	if not rival_system:
		return
	
	var rival_data: Dictionary = rival_system.get_active_rival()
	if not rival_data.is_empty():
		mission.rival_involvement = {
			"rival_id": rival_data.id,
			"involvement_type": _determine_rival_involvement(),
			"rival_force": rival_data.force_composition
		}

## Determines the type of rival involvement
func _determine_rival_involvement() -> int:
	var roll := randf()
	if roll < 0.4:
		return 3 # Direct involvement
	elif roll < 0.7:
		return 2 # Indirect involvement
	else:
		return 1 # Background presence

## Generates the terrain layout for the mission
func _generate_terrain_layout(mission: Mission) -> void:
	var layout_type := _get_layout_type(mission.mission_type)
	terrain_system.initialize_terrain(Vector2i(10, 10), mission.battle_environment)
	
	# Add required features based on mission type
	var required_features := _get_required_features(mission.mission_type)
	for feature in required_features:
		terrain_system._set_terrain_feature(
			_find_valid_feature_position(),
			feature
		)

## Places mission objectives
func _place_objectives(mission: Mission) -> void:
	var objective_count := _get_objective_count(mission.mission_type)
	var placed_objectives := 0
	
	while placed_objectives < objective_count:
		var pos := _find_valid_objective_position(mission)
		if pos != Vector2.ZERO:
			var objective_type := _get_objective_type(mission.mission_type, placed_objectives)
			mission.add_objective(objective_type, pos)
			placed_objectives += 1

## Sets up deployment zones
func _setup_deployment_zones(mission: Mission) -> void:
	var deployment_count := _get_deployment_point_count(mission.deployment_type)
	var placed_points := 0
	
	while placed_points < deployment_count:
		var pos := _find_valid_deployment_position(mission)
		if pos != Vector2.ZERO:
			mission.deployment_points.append(pos)
			placed_points += 1

## Helper functions
func _generate_mission_name(template: MissionTemplate) -> String:
	if template.title_templates.is_empty():
		return "Unnamed Mission"
	return template.title_templates[randi() % template.title_templates.size()]

func _get_difficulty_from_range(range: Vector2) -> int:
	return randi_range(int(range.x), int(range.y))

func _calculate_reward(range: Vector2, difficulty: int) -> int:
	var base_reward := randi_range(int(range.x), int(range.y))
	return base_reward * (1 + difficulty * 0.2)

func _generate_reward_items(difficulty: int) -> Array:
	# Implement item generation based on difficulty
	return []

func _calculate_reputation_reward(difficulty: int) -> int:
	return difficulty * 10

## Gets layout type based on mission type
func _get_layout_type(mission_type: int) -> int:
	match mission_type:
		1: # PATROL
			return 0 # Open layout
		2: # RAID
			return 1 # Dense layout
		_:
			return 0

## Gets required features based on mission type
func _get_required_features(mission_type: int) -> Array:
	match mission_type:
		1: # PATROL
			return [1] # COVER_LOW
		2: # RAID
			return [2, 5] # COVER_HIGH, HAZARD
		_:
			return []

## Gets objective count based on mission type
func _get_objective_count(mission_type: int) -> int:
	match mission_type:
		1: # PATROL
			return 1
		2: # RAID
			return randi_range(2, 3)
		_:
			return 1

## Gets objective type based on mission type and index
func _get_objective_type(mission_type: int, index: int) -> int:
	if index == 0:
		# Primary objective
		match mission_type:
			1: # PATROL
				return 2 # PATROL
			2: # RAID
				return 3 # SEEK_AND_DESTROY
			_:
				return 2 # PATROL
	else:
		# Secondary objectives
		var secondary_objectives := [
			7, # RECON
			8 # SABOTAGE
		]
		return secondary_objectives[randi() % secondary_objectives.size()]

## Gets deployment point count based on deployment type
func _get_deployment_point_count(deployment_type: int) -> int:
	match deployment_type:
		1: # STANDARD
			return 2
		2: # SCATTERED
			return 4
		_:
			return 2

## Position finding functions
func _find_valid_feature_position() -> Vector2:
	var max_attempts := 50
	var attempt := 0
	
	while attempt < max_attempts:
		var grid_size: int = terrain_system._terrain_grid.size()
		var x: int = randi() % grid_size
		var y: int = randi() % terrain_system._terrain_grid[0].size()
		var pos := Vector2(x, y)
		
		if position_validator.validate_feature_position(pos, 1):
			return pos
			
		attempt += 1
	
	return Vector2.ZERO

func _find_valid_objective_position(mission: Mission) -> Vector2:
	var max_attempts := 50
	var attempt := 0
	
	while attempt < max_attempts:
		var grid_size: int = terrain_system._terrain_grid.size()
		var x: int = randi() % grid_size
		var y: int = randi() % terrain_system._terrain_grid[0].size()
		var pos := Vector2(x, y)
		
		if position_validator.validate_objective_position(pos, mission):
			return pos
			
		attempt += 1
	
	return Vector2.ZERO

func _find_valid_deployment_position(mission: Mission) -> Vector2:
	var max_attempts := 50
	var attempt := 0
	
	while attempt < max_attempts:
		var grid_size: int = terrain_system._terrain_grid.size()
		var x: int = randi() % grid_size
		var y: int = randi() % terrain_system._terrain_grid[0].size()
		var pos := Vector2(x, y)
		
		if position_validator.validate_deployment_position(pos, mission):
			return pos
			
		attempt += 1
	
	return Vector2.ZERO
    