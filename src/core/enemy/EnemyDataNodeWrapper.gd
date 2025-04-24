@tool
extends Node
class_name EnemyDataNodeWrapper

# This script serves as a wrapper for EnemyData resources
# It forwards method calls to the underlying resource, allowing
# EnemyData (which is a Resource) to be used in contexts expecting Nodes

# Use explicit preload instead of global class name
const EnemyDataScript = preload("res://src/core/enemy/EnemyData.gd")

# Cache the underlying EnemyData resource - use Resource type for safety
var _enemy_data: Resource = null

func _ready() -> void:
	# Get the EnemyData resource from metadata
	_enemy_data = EnemyDataScript.get_from_node(self)
	
	# Check if we have valid enemy data
	if not _enemy_data:
		push_error("EnemyDataNodeWrapper: No enemy data found in metadata")

# Forward property getters to the underlying resource
func get_id() -> String:
	return _get_enemy_data().get_id() if _get_enemy_data() else ""
	
func get_enemy_name() -> String:
	return _get_enemy_data().get_name() if _get_enemy_data() else ""
	
func get_type() -> int:
	return _get_enemy_data().get_type() if _get_enemy_data() else 0
	
func get_level() -> int:
	return _get_enemy_data().get_level() if _get_enemy_data() else 0
	
func get_health() -> float:
	return _get_enemy_data().get_health() if _get_enemy_data() else 0.0
	
func get_max_health() -> float:
	return _get_enemy_data().get_max_health() if _get_enemy_data() else 0.0
	
func get_armor() -> float:
	return _get_enemy_data().get_armor() if _get_enemy_data() else 0.0
	
func get_damage() -> float:
	return _get_enemy_data().get_damage() if _get_enemy_data() else 0.0
	
func get_movement_range() -> float:
	return _get_enemy_data().get_movement_range() if _get_enemy_data() else 0.0
	
func get_weapon_range() -> float:
	return _get_enemy_data().get_weapon_range() if _get_enemy_data() else 0.0

# Forward methods to the underlying resource
func take_damage(amount: float) -> float:
	return _get_enemy_data().take_damage(amount) if _get_enemy_data() else 0.0
	
func heal(amount: float) -> float:
	return _get_enemy_data().heal(amount) if _get_enemy_data() else 0.0
	
func set_health(value: float) -> void:
	if _get_enemy_data():
		_get_enemy_data().set_health(value)
		
func is_dead() -> bool:
	return _get_enemy_data().is_dead() if _get_enemy_data() else true
	
func apply_status_effect(effect_name: String, duration: int = 3) -> bool:
	return _get_enemy_data().apply_status_effect(effect_name, duration) if _get_enemy_data() else false
	
func remove_status_effect(effect_name: String) -> bool:
	return _get_enemy_data().remove_status_effect(effect_name) if _get_enemy_data() else false
	
func clear_status_effects() -> void:
	if _get_enemy_data():
		_get_enemy_data().clear_status_effects()

# Get the underlying EnemyData resource
func get_enemy_data() -> Resource:
	return _get_enemy_data()

# Helper method to get the enemy data, refreshing from metadata if needed
func _get_enemy_data() -> Resource:
	if not _enemy_data:
		_enemy_data = EnemyDataScript.get_from_node(self)
	return _enemy_data