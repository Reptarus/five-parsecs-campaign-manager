## Manages enemy forces and their deployment in the Five Parsecs battle system
class_name EnemyManager
extends Node

## Core Rules enemy group sizes - maps EnemyType to base group size
const GROUP_SIZES: Dictionary = {
	GlobalEnums.EnemyType.GRUNT: 4,
	GlobalEnums.EnemyType.ELITE: 2,
	GlobalEnums.EnemyType.BOSS: 1,
	GlobalEnums.EnemyType.MINION: 6,
	GlobalEnums.EnemyType.SUPPORT: 3,
	GlobalEnums.EnemyType.HEAVY: 2,
	GlobalEnums.EnemyType.SPECIALIST: 2,
	GlobalEnums.EnemyType.COMMANDER: 1
}

## Current enemy force configuration
var current_enemy_force: Dictionary = {}
## List of deployment positions for enemy units
var deployment_positions: Array[Vector2] = []

## Generates deployment data for an enemy force
## Parameters:
## - enemy_force: Dictionary containing enemy force configuration
## - deployment_zone: Rectangle defining the deployment area
## Returns: Dictionary containing groups, positions, and special rules
func generate_enemy_deployment(enemy_force: Dictionary, deployment_zone: Rect2) -> Dictionary:
	if not _validate_enemy_force(enemy_force):
		push_error("Invalid enemy force configuration")
		return {}
		
	current_enemy_force = enemy_force
	deployment_positions.clear()
	
	var enemy_data: Dictionary = {
		"groups": _generate_enemy_groups(),
		"positions": _generate_positions(deployment_zone),
		"special_rules": enemy_force.get("special_rules", [])
	}
	
	return enemy_data

## Returns the current enemy force configuration
func get_enemy_data() -> Dictionary:
	return current_enemy_force

## Validates the enemy force configuration
## Returns: bool indicating if the force is valid
func _validate_enemy_force(force: Dictionary) -> bool:
	if not force.has("type") or not force.has("groups"):
		return false
	if not GROUP_SIZES.has(force.type):
		return false
	return true

## Generates enemy group data based on current force configuration
## Returns: Array of group configurations
func _generate_enemy_groups() -> Array[Dictionary]:
	var groups: Array[Dictionary] = []
	var base_count: int = GROUP_SIZES[current_enemy_force.type]
	var total_count: int = base_count + current_enemy_force.get("count_bonus", 0)
	
	groups.append({
		"type": current_enemy_force.type,
		"count": total_count,
		"equipment_level": current_enemy_force.get("equipment_level", 1)
	})
	
	if current_enemy_force.get("reinforcements", false):
		groups.append({
			"type": GlobalEnums.EnemyType.GRUNT,
			"count": base_count / 2,
			"equipment_level": maxi(1, current_enemy_force.get("equipment_level", 1) - 1)
		})
	
	return groups

## Generates deployment positions for all enemy units
## Parameters:
## - deployment_zone: Rectangle defining the deployment area
## Returns: Array of Vector2 positions
func _generate_positions(deployment_zone: Rect2) -> Array[Vector2]:
	var positions: Array[Vector2] = []
	var total_enemies: int = 0
	
	for group in current_enemy_force.groups:
		total_enemies += group.count
	
	for i in total_enemies:
		var pos: Vector2 = _get_random_position_in_zone(deployment_zone)
		var attempts: int = 0
		while pos in positions and attempts < 100:
			pos = _get_random_position_in_zone(deployment_zone)
			attempts += 1
		
		if attempts >= 100:
			push_warning("Could not find unique position for enemy after 100 attempts")
		
		positions.append(pos)
	
	return positions

## Generates a random position within the deployment zone
## Parameters:
## - zone: Rectangle defining the deployment area
## Returns: Vector2 position within the zone
func _get_random_position_in_zone(zone: Rect2) -> Vector2:
	return Vector2(
		zone.position.x + randf() * zone.size.x,
		zone.position.y + randf() * zone.size.y
	) 