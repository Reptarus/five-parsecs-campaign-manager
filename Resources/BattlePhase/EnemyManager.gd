class_name EnemyManager
extends Node

enum EnemyType {
    GRUNT,
    ELITE,
    BOSS,
    MINION,
    SUPPORT,
    HEAVY,
    SPECIALIST,
    COMMANDER
}

# Core Rules enemy group sizes
const GROUP_SIZES = {
    EnemyType.GRUNT: 4,
    EnemyType.ELITE: 2,
    EnemyType.BOSS: 1,
    EnemyType.MINION: 6,
    EnemyType.SUPPORT: 3,
    EnemyType.HEAVY: 2,
    EnemyType.SPECIALIST: 2,
    EnemyType.COMMANDER: 1
}

var current_enemy_force: Dictionary = {}
var deployment_positions: Array = []

func generate_enemy_deployment(enemy_force: Dictionary, deployment_zone: Rect2) -> Dictionary:
    current_enemy_force = enemy_force
    deployment_positions = []
    
    var enemy_data = {
        "groups": _generate_enemy_groups(),
        "positions": _generate_positions(deployment_zone),
        "special_rules": enemy_force.get("special_rules", [])
    }
    
    return enemy_data

func get_enemy_data() -> Dictionary:
    return current_enemy_force

# Private helper methods
func _generate_enemy_groups() -> Array:
    var groups = []
    var base_count = GROUP_SIZES[current_enemy_force.type]
    var total_count = base_count + current_enemy_force.get("count_bonus", 0)
    
    # Create main enemy group
    groups.append({
        "type": current_enemy_force.type,
        "count": total_count,
        "equipment_level": current_enemy_force.get("equipment_level", 1)
    })
    
    # Add reinforcements if specified
    if current_enemy_force.get("reinforcements", false):
        groups.append({
            "type": EnemyType.GRUNT,
            "count": base_count / 2,
            "equipment_level": current_enemy_force.get("equipment_level", 1) - 1
        })
    
    return groups

func _generate_positions(deployment_zone: Rect2) -> Array:
    var positions = []
    var total_enemies = 0
    
    for group in current_enemy_force.groups:
        total_enemies += group.count
    
    # Generate positions within deployment zone
    for i in total_enemies:
        var pos = _get_random_position_in_zone(deployment_zone)
        while pos in positions:
            pos = _get_random_position_in_zone(deployment_zone)
        positions.append(pos)
    
    return positions

func _get_random_position_in_zone(zone: Rect2) -> Vector2:
    return Vector2(
        zone.position.x + randi() % int(zone.size.x),
        zone.position.y + randi() % int(zone.size.y)
    ) 