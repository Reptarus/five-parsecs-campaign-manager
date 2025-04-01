extends Resource

const GameEnums := preload("res://src/core/enums/GameEnums.gd")
const Character := preload("res://src/core/character/Base/Character.gd")
const TerrainTypes := preload("res://src/core/terrain/TerrainTypes.gd")

# Local constants for terrain feature types not defined in GameEnums
const TERRAIN_FEATURE_SPAWN_POINT = 100
const TERRAIN_FEATURE_EXIT_POINT = 101
const TERRAIN_FEATURE_OBJECTIVE = 102

signal deployment_zones_generated(zones: Array[Dictionary])
signal terrain_generated(terrain: Array[Dictionary])

## Current deployment type being used
var current_deployment_type: GameEnums.DeploymentType = GameEnums.DeploymentType.STANDARD
## Current terrain layout
var terrain_layout: Array[Dictionary] = []
## Size of the deployment grid
var grid_size: Vector2i = Vector2i(24, 24)

## Returns the size of a deployment zone based on its type
## Parameters:
## - deployment_type: The type of deployment zone
## Returns: Vector2 representing the size of the zone
static func get_zone_size(deployment_type: GameEnums.DeploymentType) -> Vector2:
	match deployment_type:
		GameEnums.DeploymentType.STANDARD:
			return Vector2(6, 4)
		GameEnums.DeploymentType.LINE:
			return Vector2(8, 2)
		GameEnums.DeploymentType.AMBUSH:
			return Vector2(4, 6)
		GameEnums.DeploymentType.SCATTERED:
			return Vector2(3, 3)
		GameEnums.DeploymentType.DEFENSIVE:
			return Vector2(5, 5)
		GameEnums.DeploymentType.INFILTRATION:
			return Vector2(4, 4)
		GameEnums.DeploymentType.REINFORCEMENT:
			return Vector2(6, 3)
		GameEnums.DeploymentType.OFFENSIVE:
			return Vector2(5, 4)
		GameEnums.DeploymentType.CONCEALED:
			return Vector2(4, 4)
		GameEnums.DeploymentType.BOLSTERED_LINE:
			return Vector2(10, 2)
		_:
			return Vector2(6, 4)

## Generates deployment zones based on the current deployment type
## Returns: Array of deployment zone dictionaries
func generate_deployment_zones() -> Array[Dictionary]:
	var zones: Array[Dictionary] = []
	var zone_size := get_zone_size(current_deployment_type)
	
	match current_deployment_type:
		GameEnums.DeploymentType.STANDARD:
			zones.append(_create_zone(Vector2(2, 2), zone_size, current_deployment_type))
			zones.append(_create_zone(Vector2(grid_size.x - zone_size.x - 2, 2), zone_size, current_deployment_type))
		GameEnums.DeploymentType.LINE:
			zones.append(_create_zone(Vector2(2, grid_size.y / 2 - zone_size.y / 2), zone_size, current_deployment_type))
			zones.append(_create_zone(Vector2(grid_size.x - zone_size.x - 2, grid_size.y / 2 - zone_size.y / 2), zone_size, current_deployment_type))
		GameEnums.DeploymentType.AMBUSH:
			zones.append(_create_zone(Vector2(2, 2), zone_size, current_deployment_type))
			zones.append(_create_zone(Vector2(grid_size.x - zone_size.x - 2, grid_size.y - zone_size.y - 2), zone_size, current_deployment_type))
		GameEnums.DeploymentType.SCATTERED:
			for i in range(4):
				var pos := Vector2(
					randf_range(2, grid_size.x - zone_size.x - 2),
					randf_range(2, grid_size.y - zone_size.y - 2)
				)
				zones.append(_create_zone(pos, zone_size, current_deployment_type))
		GameEnums.DeploymentType.DEFENSIVE:
			zones.append(_create_zone(Vector2(grid_size.x / 2 - zone_size.x / 2, 2), zone_size, current_deployment_type))
		GameEnums.DeploymentType.INFILTRATION:
			zones.append(_create_zone(Vector2(2, 2), zone_size, current_deployment_type))
			zones.append(_create_zone(Vector2(grid_size.x - zone_size.x - 2, grid_size.y - zone_size.y - 2), zone_size, current_deployment_type))
		GameEnums.DeploymentType.REINFORCEMENT:
			zones.append(_create_zone(Vector2(2, 2), zone_size, current_deployment_type))
			zones.append(_create_zone(Vector2(grid_size.x / 2 - zone_size.x / 2, grid_size.y - zone_size.y - 2), zone_size, current_deployment_type))
		GameEnums.DeploymentType.OFFENSIVE:
			zones.append(_create_zone(Vector2(2, 2), zone_size, current_deployment_type))
			zones.append(_create_zone(Vector2(grid_size.x - zone_size.x - 2, 2), zone_size, current_deployment_type))
			zones.append(_create_zone(Vector2(grid_size.x / 2 - zone_size.x / 2, grid_size.y - zone_size.y - 2), zone_size, current_deployment_type))
		GameEnums.DeploymentType.CONCEALED:
			for i in range(3):
				var pos := Vector2(
					randf_range(2, grid_size.x - zone_size.x - 2),
					randf_range(2, grid_size.y - zone_size.y - 2)
				)
				zones.append(_create_zone(pos, zone_size, current_deployment_type))
		GameEnums.DeploymentType.BOLSTERED_LINE:
			zones.append(_create_zone(Vector2(2, grid_size.y / 2 - zone_size.y / 2), zone_size, current_deployment_type))
			zones.append(_create_zone(Vector2(grid_size.x - zone_size.x - 2, grid_size.y / 2 - zone_size.y / 2), zone_size, current_deployment_type))
			zones.append(_create_zone(Vector2(grid_size.x / 2 - zone_size.x / 2, grid_size.y / 2 - zone_size.y / 2), zone_size, current_deployment_type))
	
	deployment_zones_generated.emit(zones)
	return zones

## Creates a deployment zone with the given parameters
## Parameters:
## - position: Position of the zone
## - size: Size of the zone
## - type: Type of deployment zone
## Returns: Dictionary containing zone data
func _create_zone(position: Vector2, size: Vector2, type: GameEnums.DeploymentType) -> Dictionary:
	return {
		"position": position,
		"size": size,
		"type": type
	}

## Generates terrain layout based on the current deployment type and terrain features
## Parameters:
## - terrain_features: Array of terrain feature types to include
## Returns: Array of terrain feature dictionaries
func generate_terrain_layout(terrain_features: Array[GameEnums.TerrainFeatureType]) -> Array[Dictionary]:
	terrain_layout.clear()
	
	# Add required terrain features
	_add_required_terrain_features()
	
	# Add optional terrain features
	for feature_type in terrain_features:
		var feature_count := _calculate_feature_count(feature_type)
		for i in feature_count:
			var pos := _get_valid_terrain_position()
			if pos != Vector2.ZERO:
				terrain_layout.append({
					"type": feature_type,
					"position": pos
				})
	
	terrain_generated.emit(terrain_layout)
	return terrain_layout

## Adds required terrain features based on deployment type
func _add_required_terrain_features() -> void:
	# Add spawn points
	terrain_layout.append({
		"type": TERRAIN_FEATURE_SPAWN_POINT,
		"position": Vector2(2, 2)
	})
	
	# Add exit points
	terrain_layout.append({
		"type": TERRAIN_FEATURE_EXIT_POINT,
		"position": Vector2(grid_size.x - 2, grid_size.y - 2)
	})
	
	# Add objectives based on deployment type
	match current_deployment_type:
		GameEnums.DeploymentType.DEFENSIVE:
			terrain_layout.append({
				"type": TERRAIN_FEATURE_OBJECTIVE,
				"position": Vector2(grid_size.x / 2, grid_size.y / 2)
			})

## Gets a valid position for terrain placement
## Returns: Vector2 position that doesn't overlap with existing terrain
func _get_valid_terrain_position() -> Vector2:
	var attempts := 0
	while attempts < 100:
		var pos := Vector2(
			randf_range(2, grid_size.x - 2),
			randf_range(2, grid_size.y - 2)
		)
		
		var valid := true
		for feature in terrain_layout:
			if feature.position.distance_to(pos) < 2:
				valid = false
				break
		
		if valid:
			return pos
		
		attempts += 1
	
	return Vector2.ZERO

## Calculates the number of features to generate based on type
## Parameters:
## - feature_type: The type of terrain feature
## Returns: Number of features to generate
func _calculate_feature_count(feature_type: GameEnums.TerrainFeatureType) -> int:
	match feature_type:
		GameEnums.TerrainFeatureType.COVER:
			return 8
		GameEnums.TerrainFeatureType.OBSTACLE:
			return 6
		GameEnums.TerrainFeatureType.HAZARD:
			return 4
		GameEnums.TerrainFeatureType.WALL:
			return 3
		_:
			return 0
