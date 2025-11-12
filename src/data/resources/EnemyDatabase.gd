@tool
class_name EnemyDatabase
extends Resource

## Database of all enemy types for Five Parsecs

@export var name: String = "enemy_types"
@export var description: String = ""
@export var enemy_categories: Array[Dictionary] = []
@export var enemies: Array[EnemyData] = []

func get_enemy_by_id(enemy_id: String) -> EnemyData:
	"""Get enemy by ID"""
	for enemy in enemies:
		if enemy.id == enemy_id:
			return enemy
	return null

func get_enemies_by_category(category: String) -> Array[EnemyData]:
	"""Get all enemies in a category"""
	var result: Array[EnemyData] = []
	for enemy in enemies:
		if enemy.category == category:
			result.append(enemy)
	return result