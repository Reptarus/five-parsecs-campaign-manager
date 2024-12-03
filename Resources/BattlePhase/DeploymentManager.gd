class_name DeploymentManager
extends Node

# Core Rules deployment zone sizes
const ZONE_SIZES = {
    GlobalEnums.DeploymentType.STANDARD: Vector2(6, 4),
    GlobalEnums.DeploymentType.LINE: Vector2(8, 2),
    GlobalEnums.DeploymentType.FLANK: Vector2(4, 6),
    GlobalEnums.DeploymentType.SCATTERED: Vector2(3, 3),
    GlobalEnums.DeploymentType.DEFENSIVE: Vector2(5, 5),
    GlobalEnums.DeploymentType.CONCEALED: Vector2(4, 4)
}

var current_deployment_type: int = GlobalEnums.DeploymentType.STANDARD
var deployment_zones: Dictionary = {}  # "crew" or "enemy": Rect2
var terrain_layout: Array = []

func generate_deployment_zones(deployment_type: int) -> Dictionary:
    current_deployment_type = deployment_type
    var zone_size = ZONE_SIZES.get(deployment_type, Vector2(6, 4))
    
    match deployment_type:
        GlobalEnums.DeploymentType.STANDARD:
            deployment_zones = _generate_standard_zones(zone_size)
        GlobalEnums.DeploymentType.LINE:
            deployment_zones = _generate_line_zones(zone_size)
        GlobalEnums.DeploymentType.FLANK:
            deployment_zones = _generate_flank_zones(zone_size)
        GlobalEnums.DeploymentType.SCATTERED:
            deployment_zones = _generate_scattered_zones(zone_size)
        GlobalEnums.DeploymentType.DEFENSIVE:
            deployment_zones = _generate_defensive_zones(zone_size)
        GlobalEnums.DeploymentType.CONCEALED:
            deployment_zones = _generate_concealed_zones(zone_size)
    
    return deployment_zones

func generate_terrain_layout(terrain_features: Array) -> Array:
    terrain_layout = []
    
    # Core Rules: Generate terrain based on deployment type
    match current_deployment_type:
        GlobalEnums.DeploymentType.STANDARD:
            _generate_standard_terrain(terrain_features)
        GlobalEnums.DeploymentType.LINE:
            _generate_line_terrain(terrain_features)
        GlobalEnums.DeploymentType.SCATTERED:
            _generate_scattered_terrain(terrain_features)
        _:
            _generate_standard_terrain(terrain_features)
    
    return terrain_layout

func get_crew_deployment_zone() -> Rect2:
    return deployment_zones.get("crew", Rect2())

func get_enemy_deployment_zone() -> Rect2:
    return deployment_zones.get("enemy", Rect2())

func get_valid_crew_positions() -> Array:
    var positions = []
    var crew_zone = get_crew_deployment_zone()
    
    # Generate valid positions within crew deployment zone
    for x in range(crew_zone.position.x, crew_zone.end.x):
        for y in range(crew_zone.position.y, crew_zone.end.y):
            if _is_valid_position(Vector2(x, y)):
                positions.append(Vector2(x, y))
    
    return positions

func get_deployment_data() -> Dictionary:
    return {
        "type": current_deployment_type,
        "zones": deployment_zones,
        "terrain": terrain_layout
    }

# Private helper methods for zone generation
func _generate_standard_zones(size: Vector2) -> Dictionary:
    return {
        "crew": Rect2(Vector2.ZERO, size),
        "enemy": Rect2(Vector2(24 - size.x, 24 - size.y), size)
    }

func _generate_line_zones(size: Vector2) -> Dictionary:
    return {
        "crew": Rect2(Vector2(0, 10), size),
        "enemy": Rect2(Vector2(24 - size.x, 10), size)
    }

# Additional zone generation methods
func _generate_flank_zones(size: Vector2) -> Dictionary:
    return {
        "crew": Rect2(Vector2(0, 0), size),
        "enemy": Rect2(Vector2(24 - size.x, 24 - size.y), size)
    }

func _generate_scattered_zones(size: Vector2) -> Dictionary:
    var zones = {}
    var crew_positions = [
        Vector2(0, 0),
        Vector2(0, 24 - size.y),
        Vector2(12 - size.x/2, 12 - size.y/2)
    ]
    var enemy_positions = [
        Vector2(24 - size.x, 0),
        Vector2(24 - size.x, 24 - size.y),
        Vector2(12 - size.x/2, 12 - size.y/2)
    ]
    
    zones["crew"] = Rect2(crew_positions[randi() % crew_positions.size()], size)
    zones["enemy"] = Rect2(enemy_positions[randi() % enemy_positions.size()], size)
    return zones

func _generate_defensive_zones(size: Vector2) -> Dictionary:
    return {
        "crew": Rect2(Vector2(8, 8), size * 1.5),
        "enemy": Rect2(Vector2(0, 0), Vector2(24, 24))
    }

func _generate_concealed_zones(size: Vector2) -> Dictionary:
    var zones = {}
    var possible_positions = []
    
    # Generate possible positions near cover/terrain
    for x in range(0, 24 - int(size.x), 4):
        for y in range(0, 24 - int(size.y), 4):
            if _has_nearby_cover(Vector2(x, y)):
                possible_positions.append(Vector2(x, y))
    
    # Select random positions for crew and enemy
    if possible_positions.size() >= 2:
        var crew_index = randi() % possible_positions.size()
        var crew_pos = possible_positions[crew_index]
        possible_positions.remove_at(crew_index)
        
        var enemy_index = randi() % possible_positions.size()
        var enemy_pos = possible_positions[enemy_index]
        
        zones["crew"] = Rect2(crew_pos, size)
        zones["enemy"] = Rect2(enemy_pos, size)
    else:
        # Fallback to standard deployment if not enough valid positions
        zones = _generate_standard_zones(size)
    
    return zones

# Private helper methods for terrain generation
func _generate_standard_terrain(features: Array) -> void:
    for feature in features:
        var position = _get_random_valid_position()
        terrain_layout.append({
            "type": feature,
            "position": position,
            "size": _get_feature_size(feature)
        })

# Additional terrain generation methods
func _generate_line_terrain(features: Array) -> void:
    var center_line = 12  # Middle of the battlefield
    
    for feature in features:
        var position = Vector2(
            center_line + randf_range(-2, 2),
            randf_range(4, 20)
        )
        terrain_layout.append({
            "type": feature,
            "position": position,
            "size": _get_feature_size(feature)
        })

func _generate_scattered_terrain(features: Array) -> void:
    var quadrants = [
        Rect2(Vector2(0, 0), Vector2(12, 12)),
        Rect2(Vector2(12, 0), Vector2(12, 12)),
        Rect2(Vector2(0, 12), Vector2(12, 12)),
        Rect2(Vector2(12, 12), Vector2(12, 12))
    ]
    
    for feature in features:
        var quadrant = quadrants[randi() % quadrants.size()]
        var position = Vector2(
            quadrant.position.x + randf() * quadrant.size.x,
            quadrant.position.y + randf() * quadrant.size.y
        )
        terrain_layout.append({
            "type": feature,
            "position": position,
            "size": _get_feature_size(feature)
        })

func _is_valid_position(pos: Vector2) -> bool:
    # Check if position is within board bounds and not occupied
    if pos.x < 0 or pos.x >= 24 or pos.y < 0 or pos.y >= 24:
        return false
        
    # Check if position overlaps with terrain
    for terrain in terrain_layout:
        var terrain_rect = Rect2(terrain.position, terrain.size)
        if terrain_rect.has_point(pos):
            return false
    
    return true

func _get_random_valid_position() -> Vector2:
    var attempts = 0
    while attempts < 100:  # Prevent infinite loops
        var pos = Vector2(
            randi() % 24,
            randi() % 24
        )
        if _is_valid_position(pos):
            return pos
        attempts += 1
    return Vector2.ZERO

func _get_feature_size(feature_type: int) -> Vector2:
    match feature_type:
        GlobalEnums.TerrainFeature.BUILDING:
            return Vector2(2, 2)
        GlobalEnums.TerrainFeature.COVER:
            return Vector2(1, 1)
        _:
            return Vector2(1, 1)

# Helper methods
func _has_nearby_cover(position: Vector2) -> bool:
    for terrain in terrain_layout:
        var distance = position.distance_to(terrain.position)
        if distance < 3:  # Within 3 units of existing terrain
            return true
    return false
  