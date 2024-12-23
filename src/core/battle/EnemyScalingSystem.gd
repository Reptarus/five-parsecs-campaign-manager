class_name EnemyScalingSystem
extends Node

const GlobalEnums = preload("res://src/core/systems/GlobalEnums.gd")

var base_power: float = 10.0
var base_stats: Dictionary = {
	"health": 10,
	"armor": 0,
	"damage": 3,
	"accuracy": 65
}
var elite_count: int = 0
var boss_count: int = 0
var total_power: float = 0.0

func calculate_enemy_scaling(difficulty: GlobalEnums.DifficultyMode, player_level: int, mission_type: GlobalEnums.MissionType) -> Dictionary:
	# Reset scaling values
	base_power = 10.0
	elite_count = 0
	boss_count = 0
	total_power = 0.0
	
	# Apply difficulty scaling
	_apply_difficulty_scaling(difficulty)
	
	# Apply level scaling
	_apply_level_scaling(player_level)
	
	# Apply mission type scaling
	_apply_mission_type_scaling(mission_type)
	
	return {
		"base_power": base_power,
		"elite_count": elite_count,
		"boss_count": boss_count,
		"total_power": total_power,
		"base_stats": base_stats
	}

func _apply_difficulty_scaling(difficulty: GlobalEnums.DifficultyMode) -> void:
	match difficulty:
		GlobalEnums.DifficultyMode.EASY:
			base_power *= 0.8
			base_stats.health -= 2
			base_stats.damage -= 1
		GlobalEnums.DifficultyMode.NORMAL:
			# No modification for normal difficulty
			pass
		GlobalEnums.DifficultyMode.CHALLENGING:
			base_power *= 1.2
			base_stats.health += 2
			base_stats.damage += 1
			elite_count += 1
		GlobalEnums.DifficultyMode.HARDCORE:
			base_power *= 1.5
			base_stats.health += 4
			base_stats.damage += 2
			base_stats.armor += 1
			elite_count += 2
			boss_count += 1

func _apply_level_scaling(player_level: int) -> void:
	# Base power increases by 5% per player level
	base_power *= (1.0 + (player_level * 0.05))
	
	# Stats increase every few levels
	var stat_increase = player_level / 3
	base_stats.health += stat_increase * 2
	base_stats.damage += stat_increase
	base_stats.armor += stat_increase / 2
	
	# Elite and boss scaling
	elite_count += player_level / 5
	boss_count += player_level / 10

func _apply_mission_type_scaling(mission_type: GlobalEnums.MissionType) -> void:
	match mission_type:
		GlobalEnums.MissionType.PATROL:
			# Standard scaling
			pass
		GlobalEnums.MissionType.RAID:
			base_power *= 1.2
			elite_count += 1
		GlobalEnums.MissionType.DEFENSE:
			base_power *= 1.3
			base_stats.health += 2
		GlobalEnums.MissionType.ESCORT:
			base_power *= 1.1
			base_stats.damage += 1
		GlobalEnums.MissionType.SABOTAGE:
			base_power *= 1.4
			elite_count += 2
		GlobalEnums.MissionType.RESCUE:
			base_power *= 1.2
			boss_count += 1
		GlobalEnums.MissionType.ASSASSINATION:
			base_power *= 1.5
			boss_count += 1
			base_stats.armor += 2
		GlobalEnums.MissionType.INVESTIGATION:
			base_power *= 1.1
			elite_count += 1
	
	# Calculate total power after all modifications
	total_power = base_power * (1.0 + (elite_count * 0.5) + (boss_count * 1.5))

func get_enemy_stats(enemy_type: String, scaling_data: Dictionary) -> Dictionary:
	var stats = scaling_data.base_stats.duplicate()
	
	match enemy_type:
		"elite":
			stats.health *= 1.5
			stats.damage *= 1.3
			stats.armor += 1
		"boss":
			stats.health *= 2.0
			stats.damage *= 1.5
			stats.armor += 2
			stats.accuracy += 10
	
	return stats

func get_recommended_enemy_count(total_power: float) -> int:
	# Calculate recommended enemy count based on total power
	# Base assumption: each standard enemy represents 10 power
	var base_enemy_power = 10.0
	return int(total_power / base_enemy_power) 