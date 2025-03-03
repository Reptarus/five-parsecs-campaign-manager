@tool
extends Node
class_name BaseBattleStatisticsTracker

# Signals
signal statistics_updated(stat_name: String, value: Variant)
signal battle_summary_generated(summary: Dictionary)

# Battle reference
var battle_controller: Node = null

# Statistics storage
var stats: Dictionary = {
	# General battle stats
	"battle_id": "",
	"battle_name": "",
	"battle_type": "",
	"battle_start_time": 0,
	"battle_end_time": 0,
	"battle_duration": 0,
	"battle_result": "",
	"total_turns": 0,
	"current_turn": 0,
	
	# Player stats
	"player_units": 0,
	"player_units_lost": 0,
	"player_damage_dealt": 0,
	"player_damage_taken": 0,
	"player_healing_done": 0,
	"player_kills": 0,
	"player_objectives_completed": 0,
	"player_actions_taken": 0,
	"player_movement_tiles": 0,
	"player_critical_hits": 0,
	"player_misses": 0,
	
	# Enemy stats
	"enemy_units": 0,
	"enemy_units_lost": 0,
	"enemy_damage_dealt": 0,
	"enemy_damage_taken": 0,
	"enemy_healing_done": 0,
	"enemy_kills": 0,
	"enemy_actions_taken": 0,
	"enemy_movement_tiles": 0,
	"enemy_critical_hits": 0,
	"enemy_misses": 0,
	
	# Detailed stats
	"damage_by_unit": {},
	"damage_by_weapon": {},
	"kills_by_unit": {},
	"actions_by_type": {},
	"objectives_progress": {},
	"terrain_usage": {},
	"status_effects_applied": {},
	"status_effects_received": {},
	
	# Custom stats
	"custom_stats": {}
}

# Virtual methods to be implemented by derived classes
func initialize(battle_controller_ref: Node = null) -> void:
	battle_controller = battle_controller_ref
	
	# Reset stats
	reset_statistics()
	
	# Connect signals
	_connect_signals()

func reset_statistics() -> void:
	# Reset general battle stats
	stats.battle_id = ""
	stats.battle_name = ""
	stats.battle_type = ""
	stats.battle_start_time = 0
	stats.battle_end_time = 0
	stats.battle_duration = 0
	stats.battle_result = ""
	stats.total_turns = 0
	stats.current_turn = 0
	
	# Reset player stats
	stats.player_units = 0
	stats.player_units_lost = 0
	stats.player_damage_dealt = 0
	stats.player_damage_taken = 0
	stats.player_healing_done = 0
	stats.player_kills = 0
	stats.player_objectives_completed = 0
	stats.player_actions_taken = 0
	stats.player_movement_tiles = 0
	stats.player_critical_hits = 0
	stats.player_misses = 0
	
	# Reset enemy stats
	stats.enemy_units = 0
	stats.enemy_units_lost = 0
	stats.enemy_damage_dealt = 0
	stats.enemy_damage_taken = 0
	stats.enemy_healing_done = 0
	stats.enemy_kills = 0
	stats.enemy_actions_taken = 0
	stats.enemy_movement_tiles = 0
	stats.enemy_critical_hits = 0
	stats.enemy_misses = 0
	
	# Reset detailed stats
	stats.damage_by_unit = {}
	stats.damage_by_weapon = {}
	stats.kills_by_unit = {}
	stats.actions_by_type = {}
	stats.objectives_progress = {}
	stats.terrain_usage = {}
	stats.status_effects_applied = {}
	stats.status_effects_received = {}
	
	# Reset custom stats
	stats.custom_stats = {}

func start_battle(battle_data: Dictionary) -> void:
	stats.battle_id = battle_data.get("id", "")
	stats.battle_name = battle_data.get("name", "")
	stats.battle_type = battle_data.get("type", "")
	stats.battle_start_time = Time.get_unix_time_from_system()
	
	# Count initial units
	stats.player_units = battle_data.get("player_units", 0)
	stats.enemy_units = battle_data.get("enemy_units", 0)

func end_battle(result: String) -> void:
	stats.battle_end_time = Time.get_unix_time_from_system()
	stats.battle_duration = stats.battle_end_time - stats.battle_start_time
	stats.battle_result = result
	
	# Generate battle summary
	var summary = generate_battle_summary()
	battle_summary_generated.emit(summary)

func track_damage(unit: Node, damage: int, source: Node = null, weapon: String = "") -> void:
	var is_player_unit = _is_player_unit(unit)
	var is_player_source = source != null and _is_player_unit(source)
	
	if is_player_source:
		# Player dealt damage
		stats.player_damage_dealt += damage
		
		# Track damage by unit
		var source_id = source.get_instance_id()
		if not source_id in stats.damage_by_unit:
			stats.damage_by_unit[source_id] = {
				"name": source.name,
				"damage_dealt": 0,
				"damage_taken": 0
			}
		stats.damage_by_unit[source_id].damage_dealt += damage
		
		# Track damage by weapon
		if not weapon.is_empty():
			if not weapon in stats.damage_by_weapon:
				stats.damage_by_weapon[weapon] = 0
			stats.damage_by_weapon[weapon] += damage
	else:
		# Enemy dealt damage
		stats.enemy_damage_dealt += damage
	
	if is_player_unit:
		# Player took damage
		stats.player_damage_taken += damage
		
		# Track damage by unit
		var unit_id = unit.get_instance_id()
		if not unit_id in stats.damage_by_unit:
			stats.damage_by_unit[unit_id] = {
				"name": unit.name,
				"damage_dealt": 0,
				"damage_taken": 0
			}
		stats.damage_by_unit[unit_id].damage_taken += damage
	else:
		# Enemy took damage
		stats.enemy_damage_taken += damage
	
	# Emit signal
	statistics_updated.emit("damage", {
		"unit": unit,
		"damage": damage,
		"source": source,
		"weapon": weapon
	})

func track_healing(unit: Node, amount: int, source: Node = null) -> void:
	var is_player_unit = _is_player_unit(unit)
	var is_player_source = source != null and _is_player_unit(source)
	
	if is_player_source:
		# Player did healing
		stats.player_healing_done += amount
	else:
		# Enemy did healing
		stats.enemy_healing_done += amount
	
	# Emit signal
	statistics_updated.emit("healing", {
		"unit": unit,
		"amount": amount,
		"source": source
	})

func track_kill(unit: Node, killer: Node = null) -> void:
	var is_player_unit = _is_player_unit(unit)
	var is_player_killer = killer != null and _is_player_unit(killer)
	
	if is_player_unit:
		# Player lost a unit
		stats.player_units_lost += 1
	else:
		# Enemy lost a unit
		stats.enemy_units_lost += 1
	
	if is_player_killer:
		# Player got a kill
		stats.player_kills += 1
		
		# Track kills by unit
		var killer_id = killer.get_instance_id()
		if not killer_id in stats.kills_by_unit:
			stats.kills_by_unit[killer_id] = {
				"name": killer.name,
				"kills": 0
			}
		stats.kills_by_unit[killer_id].kills += 1
	else:
		# Enemy got a kill
		stats.enemy_kills += 1
	
	# Emit signal
	statistics_updated.emit("kill", {
		"unit": unit,
		"killer": killer
	})

func track_action(unit: Node, action_type: String) -> void:
	var is_player_unit = _is_player_unit(unit)
	
	if is_player_unit:
		# Player took an action
		stats.player_actions_taken += 1
	else:
		# Enemy took an action
		stats.enemy_actions_taken += 1
	
	# Track actions by type
	if not action_type in stats.actions_by_type:
		stats.actions_by_type[action_type] = 0
	stats.actions_by_type[action_type] += 1
	
	# Emit signal
	statistics_updated.emit("action", {
		"unit": unit,
		"action_type": action_type
	})

func track_movement(unit: Node, tiles: int) -> void:
	var is_player_unit = _is_player_unit(unit)
	
	if is_player_unit:
		# Player moved
		stats.player_movement_tiles += tiles
	else:
		# Enemy moved
		stats.enemy_movement_tiles += tiles
	
	# Emit signal
	statistics_updated.emit("movement", {
		"unit": unit,
		"tiles": tiles
	})

func track_critical_hit(unit: Node, target: Node) -> void:
	var is_player_unit = _is_player_unit(unit)
	
	if is_player_unit:
		# Player scored a critical hit
		stats.player_critical_hits += 1
	else:
		# Enemy scored a critical hit
		stats.enemy_critical_hits += 1
	
	# Emit signal
	statistics_updated.emit("critical_hit", {
		"unit": unit,
		"target": target
	})

func track_miss(unit: Node, target: Node) -> void:
	var is_player_unit = _is_player_unit(unit)
	
	if is_player_unit:
		# Player missed
		stats.player_misses += 1
	else:
		# Enemy missed
		stats.enemy_misses += 1
	
	# Emit signal
	statistics_updated.emit("miss", {
		"unit": unit,
		"target": target
	})

func track_objective_progress(objective_id: String, progress: float) -> void:
	# Track objective progress
	if not objective_id in stats.objectives_progress:
		stats.objectives_progress[objective_id] = 0.0
	
	var previous_progress = stats.objectives_progress[objective_id]
	stats.objectives_progress[objective_id] = progress
	
	# Check if objective was completed
	if previous_progress < 1.0 and progress >= 1.0:
		stats.player_objectives_completed += 1
	
	# Emit signal
	statistics_updated.emit("objective_progress", {
		"objective_id": objective_id,
		"progress": progress
	})

func track_terrain_usage(unit: Node, terrain_type: String) -> void:
	# Track terrain usage
	if not terrain_type in stats.terrain_usage:
		stats.terrain_usage[terrain_type] = 0
	stats.terrain_usage[terrain_type] += 1
	
	# Emit signal
	statistics_updated.emit("terrain_usage", {
		"unit": unit,
		"terrain_type": terrain_type
	})

func track_status_effect(unit: Node, effect: String, source: Node = null) -> void:
	var is_player_unit = _is_player_unit(unit)
	var is_player_source = source != null and _is_player_unit(source)
	
	if is_player_source:
		# Player applied status effect
		if not effect in stats.status_effects_applied:
			stats.status_effects_applied[effect] = 0
		stats.status_effects_applied[effect] += 1
	
	if is_player_unit:
		# Player received status effect
		if not effect in stats.status_effects_received:
			stats.status_effects_received[effect] = 0
		stats.status_effects_received[effect] += 1
	
	# Emit signal
	statistics_updated.emit("status_effect", {
		"unit": unit,
		"effect": effect,
		"source": source
	})

func track_turn(turn: int) -> void:
	stats.current_turn = turn
	stats.total_turns = max(stats.total_turns, turn)
	
	# Emit signal
	statistics_updated.emit("turn", {
		"turn": turn
	})

func track_custom_stat(stat_name: String, value: Variant) -> void:
	# Track custom stat
	stats.custom_stats[stat_name] = value
	
	# Emit signal
	statistics_updated.emit("custom_stat", {
		"stat_name": stat_name,
		"value": value
	})

func get_stat(stat_name: String) -> Variant:
	if stat_name in stats:
		return stats[stat_name]
	elif stat_name in stats.custom_stats:
		return stats.custom_stats[stat_name]
	else:
		return null

func get_all_stats() -> Dictionary:
	return stats

func generate_battle_summary() -> Dictionary:
	var summary = {
		"general": {
			"battle_name": stats.battle_name,
			"battle_type": stats.battle_type,
			"battle_result": stats.battle_result,
			"duration_seconds": stats.battle_duration,
			"total_turns": stats.total_turns
		},
		"player": {
			"units": stats.player_units,
			"units_lost": stats.player_units_lost,
			"survival_rate": _calculate_survival_rate(stats.player_units, stats.player_units_lost),
			"damage_dealt": stats.player_damage_dealt,
			"damage_taken": stats.player_damage_taken,
			"healing_done": stats.player_healing_done,
			"kills": stats.player_kills,
			"objectives_completed": stats.player_objectives_completed,
			"actions_taken": stats.player_actions_taken,
			"movement_tiles": stats.player_movement_tiles,
			"critical_hits": stats.player_critical_hits,
			"misses": stats.player_misses,
			"accuracy": _calculate_accuracy(stats.player_critical_hits + (stats.player_damage_dealt / max(1, stats.enemy_damage_taken)), stats.player_misses)
		},
		"enemy": {
			"units": stats.enemy_units,
			"units_lost": stats.enemy_units_lost,
			"survival_rate": _calculate_survival_rate(stats.enemy_units, stats.enemy_units_lost),
			"damage_dealt": stats.enemy_damage_dealt,
			"damage_taken": stats.enemy_damage_taken,
			"healing_done": stats.enemy_healing_done,
			"kills": stats.enemy_kills,
			"actions_taken": stats.enemy_actions_taken,
			"movement_tiles": stats.enemy_movement_tiles,
			"critical_hits": stats.enemy_critical_hits,
			"misses": stats.enemy_misses,
			"accuracy": _calculate_accuracy(stats.enemy_critical_hits + (stats.enemy_damage_dealt / max(1, stats.player_damage_taken)), stats.enemy_misses)
		},
		"mvp": _determine_mvp(),
		"most_damage_dealt": _determine_most_damage_dealt(),
		"most_damage_taken": _determine_most_damage_taken(),
		"most_kills": _determine_most_kills(),
		"most_used_weapon": _determine_most_used_weapon(),
		"most_used_terrain": _determine_most_used_terrain(),
		"most_common_action": _determine_most_common_action(),
		"performance_score": _calculate_performance_score()
	}
	
	return summary

# Helper methods
func _connect_signals() -> void:
	# To be implemented by derived classes
	# Connect to battle controller signals to track statistics
	pass

func _is_player_unit(unit: Node) -> bool:
	# To be implemented by derived classes
	# Determine if a unit belongs to the player
	return false

func _calculate_survival_rate(total: int, lost: int) -> float:
	if total == 0:
		return 0.0
	
	return float(total - lost) / float(total) * 100.0

func _calculate_accuracy(hits: int, misses: int) -> float:
	var total_attempts = hits + misses
	
	if total_attempts == 0:
		return 0.0
	
	return float(hits) / float(total_attempts) * 100.0

func _determine_mvp() -> Dictionary:
	var mvp = null
	var highest_score = -1
	
	for unit_id in stats.damage_by_unit:
		var unit_data = stats.damage_by_unit[unit_id]
		var kills = 0
		
		if unit_id in stats.kills_by_unit:
			kills = stats.kills_by_unit[unit_id].kills
		
		var score = unit_data.damage_dealt * 0.5 + kills * 10 - unit_data.damage_taken * 0.2
		
		if score > highest_score:
			highest_score = score
			mvp = {
				"id": unit_id,
				"name": unit_data.name,
				"damage_dealt": unit_data.damage_dealt,
				"damage_taken": unit_data.damage_taken,
				"kills": kills,
				"score": score
			}
	
	return mvp if mvp != null else {}

func _determine_most_damage_dealt() -> Dictionary:
	var unit = null
	var highest_damage = -1
	
	for unit_id in stats.damage_by_unit:
		var unit_data = stats.damage_by_unit[unit_id]
		
		if unit_data.damage_dealt > highest_damage:
			highest_damage = unit_data.damage_dealt
			unit = {
				"id": unit_id,
				"name": unit_data.name,
				"damage_dealt": unit_data.damage_dealt
			}
	
	return unit if unit != null else {}

func _determine_most_damage_taken() -> Dictionary:
	var unit = null
	var highest_damage = -1
	
	for unit_id in stats.damage_by_unit:
		var unit_data = stats.damage_by_unit[unit_id]
		
		if unit_data.damage_taken > highest_damage:
			highest_damage = unit_data.damage_taken
			unit = {
				"id": unit_id,
				"name": unit_data.name,
				"damage_taken": unit_data.damage_taken
			}
	
	return unit if unit != null else {}

func _determine_most_kills() -> Dictionary:
	var unit = null
	var highest_kills = -1
	
	for unit_id in stats.kills_by_unit:
		var unit_data = stats.kills_by_unit[unit_id]
		
		if unit_data.kills > highest_kills:
			highest_kills = unit_data.kills
			unit = {
				"id": unit_id,
				"name": unit_data.name,
				"kills": unit_data.kills
			}
	
	return unit if unit != null else {}

func _determine_most_used_weapon() -> Dictionary:
	var weapon = null
	var highest_damage = -1
	
	for weapon_name in stats.damage_by_weapon:
		var damage = stats.damage_by_weapon[weapon_name]
		
		if damage > highest_damage:
			highest_damage = damage
			weapon = {
				"name": weapon_name,
				"damage": damage
			}
	
	return weapon if weapon != null else {}

func _determine_most_used_terrain() -> Dictionary:
	var terrain = null
	var highest_usage = -1
	
	for terrain_type in stats.terrain_usage:
		var usage = stats.terrain_usage[terrain_type]
		
		if usage > highest_usage:
			highest_usage = usage
			terrain = {
				"type": terrain_type,
				"usage": usage
			}
	
	return terrain if terrain != null else {}

func _determine_most_common_action() -> Dictionary:
	var action = null
	var highest_count = -1
	
	for action_type in stats.actions_by_type:
		var count = stats.actions_by_type[action_type]
		
		if count > highest_count:
			highest_count = count
			action = {
				"type": action_type,
				"count": count
			}
	
	return action if action != null else {}

func _calculate_performance_score() -> float:
	var score = 0.0
	
	# Factors to consider
	score += stats.player_kills * 10
	score += stats.player_damage_dealt * 0.1
	score -= stats.player_damage_taken * 0.1
	score += stats.player_objectives_completed * 20
	score -= stats.player_units_lost * 15
	
	if stats.total_turns > 0:
		score -= min(stats.total_turns * 2, 20) # Penalty for longer battles, capped at -20
	
	if stats.battle_result == "victory":
		score += 50
	elif stats.battle_result == "defeat":
		score -= 30
	
	return max(0, score)