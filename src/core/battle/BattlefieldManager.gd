class_name BattlefieldManager
extends Node

const GameEnums := preload("res://src/core/systems/GlobalEnums.gd")
const Character := preload("res://src/core/character/Base/Character.gd")
const TerrainTypes := preload("res://src/core/battle/TerrainTypes.gd")
const TerrainRules := preload("res://src/core/battle/TerrainRules.gd")

# Signals
signal terrain_updated(position: Vector2i, new_type: TerrainTypes.Type)
signal unit_moved(unit: Character, from: Vector2i, to: Vector2i)
signal unit_added(unit: Character, position: Vector2i)
signal unit_removed(unit: Character, position: Vector2i)
signal cover_changed(position: Vector2i, cover_value: float)
signal line_of_sight_changed(from: Vector2i, to: Vector2i, blocked: bool)
signal tactical_advantage_changed(unit: Character, advantage_type: GameEnums.CombatAdvantage, value: float)
signal deployment_zone_updated(zone_type: int, positions: Array[Vector2i])
signal battlefield_validated(result: Dictionary)
signal terrain_placement_validated(result: Dictionary)

# Configuration
const MOVEMENT_BASE: int = 6  # Base movement from Core Rules
const GRID_SIZE = Vector2i(24, 24)  # Standard battlefield size per core rules
const CELL_SIZE = Vector2i(32, 32)  # Visual size of each grid cell
const MIN_TERRAIN_PIECES = 4  # Core rules minimum terrain requirement
const MAX_TERRAIN_PIECES = 12  # Core rules maximum terrain requirement

# Battlefield state
var terrain_map: Array[Array] = []  # Array of TerrainTypes.Type
var unit_positions: Dictionary = {}  # Character: Vector2i
var cover_map: Array[Array] = []  # Array of float values
var los_cache: Dictionary = {}  # String: bool
var deployment_zones: Dictionary = {
    GameEnums.DeploymentZone.PLAYER: [],
    GameEnums.DeploymentZone.ENEMY: [],
    GameEnums.DeploymentZone.NEUTRAL: [],
    GameEnums.DeploymentZone.OBJECTIVE: []
}

# Terrain rules from core rules
var terrain_density_rules := {
    "min_pieces": MIN_TERRAIN_PIECES,
    "max_pieces": MAX_TERRAIN_PIECES,
    "min_cover": 2,
    "max_buildings": 4,
    "max_elevated": 3,
    "max_hazards": 2
}

# Current state
var current_phase: GameEnums.BattlePhase = GameEnums.BattlePhase.SETUP
var selected_tool: GameEnums.TerrainFeatureType = GameEnums.TerrainFeatureType.NONE
var terrain_rules: TerrainRules

func _ready() -> void:
    terrain_rules = TerrainRules.new()
    _initialize_battlefield()

func _initialize_battlefield() -> void:
    # Initialize terrain map
    terrain_map.resize(GRID_SIZE.x)
    for x in range(GRID_SIZE.x):
        terrain_map[x] = []
        terrain_map[x].resize(GRID_SIZE.y)
        for y in range(GRID_SIZE.y):
            terrain_map[x][y] = TerrainTypes.Type.EMPTY
    
    # Initialize cover map
    cover_map.resize(GRID_SIZE.x)
    for x in range(GRID_SIZE.x):
        cover_map[x] = []
        cover_map[x].resize(GRID_SIZE.y)
        for y in range(GRID_SIZE.y):
            cover_map[x][y] = 0.0
    
    _clear_deployment_zones()

func _clear_deployment_zones() -> void:
    for zone in deployment_zones.keys():
        deployment_zones[zone].clear()

# Terrain management
func set_terrain(position: Vector2i, type: TerrainTypes.Type) -> void:
    if not _is_valid_position(position):
        return
    
    var old_type = terrain_map[position.x][position.y]
    terrain_map[position.x][position.y] = type
    
    # Update cover and LOS
    _update_cover_value(position)
    _invalidate_los_cache()
    
    terrain_updated.emit(position, type)

func get_terrain(position: Vector2i) -> TerrainTypes.Type:
    if not _is_valid_position(position):
        return TerrainTypes.Type.INVALID
    return terrain_map[position.x][position.y]

func set_terrain_feature(position: Vector2i, feature: GameEnums.TerrainFeatureType) -> void:
    if not _is_valid_position(position):
        return
    
    var terrain_type = _get_terrain_type_for_feature(feature)
    set_terrain(position, terrain_type)

# Unit management
func add_unit(unit: Character, position: Vector2i) -> bool:
    if not _can_place_unit(position):
        return false
    
    unit_positions[unit] = position
    unit_added.emit(unit, position)
    return true

func remove_unit(unit: Character) -> void:
    if unit in unit_positions:
        var position = unit_positions[unit]
        unit_positions.erase(unit)
        unit_removed.emit(unit, position)

func move_unit(unit: Character, new_position: Vector2i) -> bool:
    if not unit in unit_positions or not _can_place_unit(new_position):
        return false
    
    var old_position = unit_positions[unit]
    unit_positions[unit] = new_position
    unit_moved.emit(unit, old_position, new_position)
    return true

func get_unit_at(position: Vector2i) -> Character:
    for unit in unit_positions:
        if unit_positions[unit] == position:
            return unit
    return null

func get_all_units() -> Array[Character]:
    return unit_positions.keys()

# Movement and pathfinding
func get_movement_cost(from: Vector2i, to: Vector2i) -> float:
    if not _is_valid_position(from) or not _is_valid_position(to):
        return INF
    
    var terrain_type = get_terrain(to)
    var feature_type = _get_feature_type_for_terrain(terrain_type)
    return terrain_rules.get_movement_cost(terrain_type, feature_type)

func get_movement_range(unit: Character, movement_points: float) -> Array[Vector2i]:
    if not unit in unit_positions:
        return []
    
    var start_pos = unit_positions[unit]
    var reachable = []
    var visited = {}
    var queue = [[start_pos, movement_points]]
    
    while not queue.is_empty():
        var current = queue.pop_front()
        var pos = current[0]
        var points = current[1]
        
        if pos in visited and visited[pos] >= points:
            continue
        
        visited[pos] = points
        reachable.append(pos)
        
        for neighbor in _get_adjacent_positions(pos):
            var cost = get_movement_cost(pos, neighbor)
            var remaining = points - cost
            if remaining >= 0:
                queue.append([neighbor, remaining])
    
    return reachable

func highlight_movement_range(unit: Character, movement_points: float) -> void:
    var range = get_movement_range(unit, movement_points)
    # Implementation for highlighting would be handled by the UI layer

# Line of sight and cover
func has_line_of_sight(from: Vector2i, to: Vector2i) -> bool:
    var cache_key = "%d,%d-%d,%d" % [from.x, from.y, to.x, to.y]
    if cache_key in los_cache:
        return los_cache[cache_key]
    
    var result = _calculate_line_of_sight(from, to)
    los_cache[cache_key] = result
    return result

func get_cover_value(position: Vector2i) -> float:
    if not _is_valid_position(position):
        return 0.0
    return cover_map[position.x][position.y]

# Deployment zones
func set_deployment_zone(zone_type: int, positions: Array[Vector2i]) -> void:
    if not zone_type in deployment_zones:
        return
    
    deployment_zones[zone_type] = positions
    deployment_zone_updated.emit(zone_type, positions)

func is_valid_deployment_position(position: Vector2i, zone_type: int) -> bool:
    if not zone_type in deployment_zones:
        return false
    return position in deployment_zones[zone_type]

# Validation
func validate_terrain_placement() -> Dictionary:
    var terrain_count = _count_terrain_pieces()
    var validation = {
        "valid": true,
        "messages": []
    }
    
    if terrain_count < terrain_density_rules.min_pieces:
        validation.valid = false
        validation.messages.append("Not enough terrain pieces (minimum %d)" % terrain_density_rules.min_pieces)
    
    if terrain_count > terrain_density_rules.max_pieces:
        validation.valid = false
        validation.messages.append("Too many terrain pieces (maximum %d)" % terrain_density_rules.max_pieces)
    
    terrain_placement_validated.emit(validation)
    return validation

func validate_deployment(units: Array[Character]) -> Dictionary:
    var validation = {
        "valid": true,
        "messages": []
    }
    
    for unit in units:
        if not unit in unit_positions:
            validation.valid = false
            validation.messages.append("Unit not placed: %s" % unit.name)
            continue
        
        var position = unit_positions[unit]
        if not is_valid_deployment_position(position, GameEnums.DeploymentZone.PLAYER):
            validation.valid = false
            validation.messages.append("Unit outside deployment zone: %s" % unit.name)
    
    battlefield_validated.emit(validation)
    return validation

# Helper functions
func _is_valid_position(position: Vector2i) -> bool:
    return position.x >= 0 and position.x < GRID_SIZE.x and position.y >= 0 and position.y < GRID_SIZE.y

func _can_place_unit(position: Vector2i) -> bool:
    if not _is_valid_position(position):
        return false
    
    # Check if position is already occupied
    for unit in unit_positions:
        if unit_positions[unit] == position:
            return false
    
    # Check if terrain allows unit placement
    var terrain_type = get_terrain(position)
    return terrain_type != TerrainTypes.Type.INVALID and terrain_type != TerrainTypes.Type.BLOCKED

func _get_adjacent_positions(position: Vector2i) -> Array[Vector2i]:
    var adjacent: Array[Vector2i] = []
    var directions = [
        Vector2i(1, 0), Vector2i(-1, 0),
        Vector2i(0, 1), Vector2i(0, -1),
        Vector2i(1, 1), Vector2i(-1, -1),
        Vector2i(1, -1), Vector2i(-1, 1)
    ]
    
    for dir in directions:
        var new_pos = position + dir
        if _is_valid_position(new_pos):
            adjacent.append(new_pos)
    
    return adjacent

func _calculate_line_of_sight(from: Vector2i, to: Vector2i) -> bool:
    var dx = abs(to.x - from.x)
    var dy = abs(to.y - from.y)
    var x = from.x
    var y = from.y
    var n = 1 + dx + dy
    var x_inc = 1 if to.x > from.x else -1
    var y_inc = 1 if to.y > from.y else -1
    var error = dx - dy
    dx *= 2
    dy *= 2
    
    for _i in range(n):
        var terrain_type = get_terrain(Vector2i(x, y))
        var feature_type = _get_feature_type_for_terrain(terrain_type)
        if terrain_rules.blocks_line_of_sight(terrain_type, feature_type):
            return false
        
        if error > 0:
            x += x_inc
            error -= dy
        else:
            y += y_inc
            error += dx
    
    return true

func _update_cover_value(position: Vector2i) -> void:
    if not _is_valid_position(position):
        return
    
    var terrain_type = get_terrain(position)
    var feature_type = _get_feature_type_for_terrain(terrain_type)
    cover_map[position.x][position.y] = terrain_rules.get_cover_value(terrain_type, feature_type)
    cover_changed.emit(position, cover_map[position.x][position.y])

func _invalidate_los_cache() -> void:
    los_cache.clear()

func _count_terrain_pieces() -> int:
    var count = 0
    for x in range(GRID_SIZE.x):
        for y in range(GRID_SIZE.y):
            if terrain_map[x][y] != TerrainTypes.Type.EMPTY:
                count += 1
    return count

func _get_terrain_type_for_feature(feature: GameEnums.TerrainFeatureType) -> TerrainTypes.Type:
    match feature:
        GameEnums.TerrainFeatureType.WALL:
            return TerrainTypes.Type.WALL
        GameEnums.TerrainFeatureType.COVER_LOW:
            return TerrainTypes.Type.COVER_LOW
        GameEnums.TerrainFeatureType.COVER_HIGH:
            return TerrainTypes.Type.COVER_HIGH
        GameEnums.TerrainFeatureType.HIGH_GROUND:
            return TerrainTypes.Type.ELEVATED
        GameEnums.TerrainFeatureType.WATER:
            return TerrainTypes.Type.WATER
        GameEnums.TerrainFeatureType.HAZARD:
            return TerrainTypes.Type.HAZARD
        GameEnums.TerrainFeatureType.DIFFICULT:
            return TerrainTypes.Type.DIFFICULT
        _:
            return TerrainTypes.Type.EMPTY

func _get_feature_type_for_terrain(terrain: TerrainTypes.Type) -> GameEnums.TerrainFeatureType:
    match terrain:
        TerrainTypes.Type.WALL:
            return GameEnums.TerrainFeatureType.WALL
        TerrainTypes.Type.COVER_LOW:
            return GameEnums.TerrainFeatureType.COVER_LOW
        TerrainTypes.Type.COVER_HIGH:
            return GameEnums.TerrainFeatureType.COVER_HIGH
        TerrainTypes.Type.ELEVATED:
            return GameEnums.TerrainFeatureType.HIGH_GROUND
        TerrainTypes.Type.WATER:
            return GameEnums.TerrainFeatureType.WATER
        TerrainTypes.Type.HAZARD:
            return GameEnums.TerrainFeatureType.HAZARD
        TerrainTypes.Type.DIFFICULT:
            return GameEnums.TerrainFeatureType.DIFFICULT
        _:
            return GameEnums.TerrainFeatureType.NONE
