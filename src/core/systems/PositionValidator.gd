class_name PositionValidator
extends Node

## Dependencies
const TerrainSystem := preload("res://src/core/terrain/TerrainSystem.gd")
const Mission := preload("res://src/core/systems/Mission.gd")
const TerrainTypes := preload("res://src/core/battle/TerrainTypes.gd")

## Validation parameters
const MIN_OBJECTIVE_SPACING := 3
const MIN_DEPLOYMENT_SPACING := 4
const MIN_EDGE_DISTANCE := 2
const MAX_DEPLOYMENT_DISTANCE := 8

## References to required systems
@export var terrain_system: TerrainSystem

## Validates a position for terrain feature placement
func validate_feature_position(pos: Vector2, feature_type: int) -> bool:
    if not _is_within_grid(pos):
        return false
        
    # Check if position is empty
    if not _is_position_empty(pos):
        return false
        
    # Check minimum distance from other features
    if not _check_feature_spacing(pos):
        return false
        
    # Check terrain type compatibility
    if not _check_terrain_compatibility(pos, feature_type):
        return false
        
    return true

## Validates a position for objective placement
func validate_objective_position(pos: Vector2, mission: Mission) -> bool:
    if not _is_within_grid(pos):
        return false
        
    # Check if position is accessible
    if not _is_position_accessible(pos):
        return false
        
    # Check minimum distance from other objectives
    if not _check_objective_spacing(pos, mission.get_objective_positions()):
        return false
        
    # Check line of sight to deployment points
    if not _check_line_of_sight_to_deployments(pos, mission.deployment_points):
        return false
        
    return true

## Validates a position for deployment point placement
func validate_deployment_position(pos: Vector2, mission: Mission) -> bool:
    if not _is_within_grid(pos):
        return false
        
    # Check if position is accessible
    if not _is_position_accessible(pos):
        return false
        
    # Check minimum distance from other deployment points
    if not _check_deployment_spacing(pos, mission.deployment_points):
        return false
        
    # Check minimum distance from objectives
    if not _check_objective_distance(pos, mission.get_objective_positions()):
        return false
        
    # Check edge distance requirements
    if not _check_edge_distance(pos):
        return false
        
    return true

## Helper functions
func _is_within_grid(pos: Vector2) -> bool:
    if not terrain_system:
        return false
        
    var grid_size := terrain_system._terrain_grid.size()
    if grid_size == 0:
        return false
        
    var x := int(pos.x)
    var y := int(pos.y)
    
    return x >= 0 and x < grid_size and y >= 0 and y < terrain_system._terrain_grid[0].size()

func _is_position_empty(pos: Vector2) -> bool:
    if not terrain_system:
        return false
        
    return terrain_system._get_terrain_at(pos) == TerrainTypes.Type.EMPTY

func _is_position_accessible(pos: Vector2) -> bool:
    if not terrain_system:
        return false
        
    var terrain_type: int = terrain_system._get_terrain_at(pos)
    # Check if terrain type blocks movement
    return not terrain_type in [TerrainTypes.Type.WALL, TerrainTypes.Type.BLOCKING_TERRAIN]

func _check_feature_spacing(pos: Vector2) -> bool:
    if not terrain_system:
        return false
        
    var features: Array[Vector2] = terrain_system.get_terrain_features()
    for feature_pos in features:
        if pos.distance_to(feature_pos) < 2.0:
            return false
            
    return true

func _check_terrain_compatibility(pos: Vector2, feature_type: int) -> bool:
    if not terrain_system:
        return false
        
    var base_terrain: int = terrain_system._get_terrain_at(pos)
    
    # Define compatibility rules
    match feature_type:
        TerrainTypes.Type.COVER_LOW:
            return base_terrain == TerrainTypes.Type.EMPTY
        TerrainTypes.Type.COVER_HIGH:
            return base_terrain == TerrainTypes.Type.EMPTY
        TerrainTypes.Type.HAZARD:
            return base_terrain == TerrainTypes.Type.EMPTY
        _:
            return false

func _check_objective_spacing(pos: Vector2, objective_positions: Array) -> bool:
    for obj_pos in objective_positions:
        if pos.distance_to(obj_pos) < MIN_OBJECTIVE_SPACING:
            return false
    return true

func _check_deployment_spacing(pos: Vector2, deployment_points: Array) -> bool:
    for dep_pos in deployment_points:
        if pos.distance_to(dep_pos) < MIN_DEPLOYMENT_SPACING:
            return false
    return true

func _check_objective_distance(pos: Vector2, objective_positions: Array) -> bool:
    for obj_pos in objective_positions:
        var distance := pos.distance_to(obj_pos)
        if distance < MIN_DEPLOYMENT_SPACING or distance > MAX_DEPLOYMENT_DISTANCE:
            return false
    return true

func _check_edge_distance(pos: Vector2) -> bool:
    if not terrain_system:
        return false
        
    var grid_size := terrain_system._terrain_grid.size()
    if grid_size == 0:
        return false
        
    var x := int(pos.x)
    var y := int(pos.y)
    
    return x >= MIN_EDGE_DISTANCE and x < grid_size - MIN_EDGE_DISTANCE and \
           y >= MIN_EDGE_DISTANCE and y < terrain_system._terrain_grid[0].size() - MIN_EDGE_DISTANCE

func _check_line_of_sight_to_deployments(pos: Vector2, deployment_points: Array) -> bool:
    if not terrain_system:
        return false
        
    for dep_pos in deployment_points:
        if not terrain_system.is_line_of_sight_blocked(dep_pos, pos):
            return true
    
    return false