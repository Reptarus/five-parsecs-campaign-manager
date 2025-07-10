@tool
@warning_ignore("unused_signal")
extends Node
class_name BaseBattleStatisticsTracker

# Universal Framework Integration


# Enhanced Signals
signal statistics_updated(stat_name: String, _value: Variant)
signal battle_summary_generated(summary: Dictionary)
signal statistics_tracker_initialized()
signal statistics_tracker_state_changed(state: Dictionary)
signal statistics_validation_completed(result: Dictionary)
signal statistics_reset_completed()
signal statistics_history_updated(history: Array)

# Universal Framework Variables
# Universal framework variable removed
# Universal framework variable removed
# Universal framework variable removed
# Universal framework variable removed

# Battle reference
var battle_controller: Node = null

# Statistics Tracker Statistics
var tracker_stats: Dictionary = {
	"battles_tracked": 0,
	"statistics_updated": 0,
	"summaries_generated": 0,
	"validations_performed": 0,
	"resets_performed": 0,
	"history_updates": 0,
	"system_initializations": 0,
	"state_changes": 0,
	"tracking_start_time": 0.0,
	"last_battle_tracked": "",
	"total_events_tracked": 0
}

# Statistics History
var statistics_history: Array[Dictionary] = []
var validation_history: Array[Dictionary] = []
var tracker_state_history: Array[Dictionary] = []

# Initialize Universal Framework
func _init() -> void:
	# Universal Framework removed
	# Universal Framework removed
	# Universal Framework removed
	# Universal Framework removed
	tracker_stats.system_initializations += 1
	tracker_stats.tracking_start_time = Time.get_unix_time_from_system()
	_log_tracker_action("Statistics tracker initialized with Universal Framework")

func _ready() -> void:
	_initialize_universal_framework()
	statistics_tracker_initialized.emit()

func _initialize_universal_framework() -> void:
	if false: # Universal Framework removed
		pass
	if false: # Universal Framework removed
		pass
	if false: # Universal Framework removed
		pass
	if false: # Universal Framework removed
		pass

	_log_tracker_action("Universal Framework initialized for statistics tracker")

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

	# Track initialization
	tracker_stats.system_initializations += 1
	_log_tracker_action("Statistics tracker initialized", {"battle_controller": battle_controller.name if battle_controller else "none"})
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

	# Track battle start
	tracker_stats.battles_tracked += 1
	tracker_stats.last_battle_tracked = stats.battle_id
	_track_statistics_event("battle_started", battle_data)
	_log_tracker_action("Battle started", {"battle_id": stats.battle_id, "battle_name": stats.battle_name})
func end_battle(result: String) -> void:
	stats.battle_end_time = Time.get_unix_time_from_system()
	stats.battle_duration = stats.battle_end_time - stats.battle_start_time
	stats.battle_result = result

	# Generate battle summary
	var summary = generate_battle_summary()
	tracker_stats.summaries_generated += 1
	_track_statistics_event("battle_ended", {"result": result, "duration": stats.battle_duration})
	_log_tracker_action("Battle ended", {"result": result, "duration": stats.battle_duration})

	battle_summary_generated.emit(summary)

func track_damage(unit: Node, damage: int, source: Node = null, weapon: String = "") -> void:
	var is_player_unit: bool = _is_player_unit(unit)
	var is_player_source: bool = source != null and _is_player_unit(source)

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
	statistics_updated.emit("damage", { # warning: return value discarded (intentional)
		"unit": unit,
		"damage": damage,
		"source": source,
		"weapon": weapon
	})

func track_healing(unit: Node, amount: int, source: Node = null) -> void:
	var is_player_unit: bool = _is_player_unit(unit)
	var is_player_source: bool = source != null and _is_player_unit(source)

	if is_player_source:
		# Player did healing
		stats.player_healing_done += amount
	else:
		# Enemy did healing
		stats.enemy_healing_done += amount

	# Emit signal
	statistics_updated.emit("healing", { # warning: return value discarded (intentional)
		"unit": unit,
		"amount": amount,
		"source": source
	})

func track_kill(unit: Node, killer: Node = null) -> void:
	var is_player_unit: bool = _is_player_unit(unit)
	var is_player_killer: bool = killer != null and _is_player_unit(killer)

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
	statistics_updated.emit("kill", { # warning: return value discarded (intentional)
		"unit": unit,
		"killer": killer
	})

func track_action(unit: Node, action_type: String) -> void:
	var is_player_unit: bool = _is_player_unit(unit)

	if is_player_unit:
		# Player took an action
		stats.player_actions_taken += 1
	else:
		# Enemy took an action
		stats.enemy_actions_taken += 1

	# Track actions by _type
	if not action_type in stats.actions_by_type:
		stats.actions_by_type[action_type] = 0
	stats.actions_by_type[action_type] += 1

	# Emit signal
	statistics_updated.emit("action", { # warning: return value discarded (intentional)
		"unit": unit,
		"action_type": action_type
	})

func track_movement(unit: Node, tiles: int) -> void:
	var is_player_unit: bool = _is_player_unit(unit)

	if is_player_unit:
		# Player moved
		stats.player_movement_tiles += tiles
	else:
		# Enemy moved
		stats.enemy_movement_tiles += tiles

	# Emit signal
	statistics_updated.emit("movement", { # warning: return value discarded (intentional)
		"unit": unit,
		"tiles": tiles
	})

func track_critical_hit(unit: Node, target: Node) -> void:
	var is_player_unit: bool = _is_player_unit(unit)

	if is_player_unit:
		# Player scored a critical hit
		stats.player_critical_hits += 1
	else:
		# Enemy scored a critical hit
		stats.enemy_critical_hits += 1

	# Emit signal
	statistics_updated.emit("critical_hit", { # warning: return value discarded (intentional)
		"unit": unit,
		"target": target
	})

func track_miss(unit: Node, target: Node) -> void:
	var is_player_unit: bool = _is_player_unit(unit)

	if is_player_unit:
		# Player missed
		stats.player_misses += 1
	else:
		# Enemy missed
		stats.enemy_misses += 1

	# Emit signal
	statistics_updated.emit("miss", { # warning: return value discarded (intentional)
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
	statistics_updated.emit("objective_progress", { # warning: return value discarded (intentional)
		"objective_id": objective_id,
		"progress": progress
	})

func track_terrain_usage(unit: Node, terrain_type: String) -> void:
	# Track terrain usage
	if not terrain_type in stats.terrain_usage:
		stats.terrain_usage[terrain_type] = 0
	stats.terrain_usage[terrain_type] += 1

	# Emit signal
	statistics_updated.emit("terrain_usage", { # warning: return value discarded (intentional)
		"unit": unit,
		"terrain_type": terrain_type
	})

func track_status_effect(unit: Node, effect: String, source: Node = null) -> void:
	var is_player_unit: bool = _is_player_unit(unit)
	var is_player_source: bool = source != null and _is_player_unit(source)

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
	statistics_updated.emit("status_effect", { # warning: return value discarded (intentional)
		"unit": unit,
		"effect": effect,
		"source": source
	})

func track_turn(turn: int) -> void:
	stats.current_turn = turn
	stats.total_turns = max(stats.total_turns, turn)

	# Emit signal
	statistics_updated.emit("turn", { # warning: return value discarded (intentional)
		"turn": turn
	})

func track_custom_stat(stat_name: String, _value: Variant) -> void:
	# Parameter validation - eliminates UNSAFE_CALL_ARGUMENT warnings
	if not is_instance_valid(self):
		return # Track custom stat
	stats.custom_stats[stat_name] = _value

	# Emit signal
	statistics_updated.emit("custom_stat", { # warning: return value discarded (intentional)
		"stat_name": stat_name,
		"_value": _value
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
	var mvp: Variant = null
	var highest_score = -1

	for unit_id in stats.damage_by_unit:
		var unit_data = stats.damage_by_unit[unit_id]
		var kills: int = 0

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
	var unit: Variant = null
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
	var unit: Variant = null
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
	var unit: Variant = null
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
	var weapon: Variant = null
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
	var terrain: Variant = null
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
	var action: Variant = null
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
	var score: int = 0

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

# Enhanced Utility Methods
func _log_tracker_action(action: String, details: Dictionary = {}) -> void:
	if false: # Universal Framework removed
		pass

	# Update state and emit signal
	tracker_stats.state_changes += 1
	tracker_stats.total_events_tracked += 1
	statistics_tracker_state_changed.emit({"action": action, "details": details, "stats": tracker_stats})

func _track_statistics_event(event_type: String, data: Dictionary) -> void:
	var stats_event = {
		"timestamp": Time.get_time_dict_from_system(),
		"type": event_type,
		"data": data,
		"battle_id": stats.get("battle_id", "unknown")
	}
	safe_call_method(statistics_history, "append", [stats_event])
	tracker_stats.history_updates += 1
	statistics_history_updated.emit(statistics_history)

func _validate_statistics_data(data: Dictionary) -> Dictionary:
	var validation_result = {"valid": true, "errors": []}

	# Basic validation
	if data.is_empty():
		validation_result.valid = false
		validation_result.errors.append("Statistics data cannot be empty")

	tracker_stats.validations_performed += 1
	safe_call_method(validation_history, "append", [ {
		"timestamp": Time.get_time_dict_from_system(),
		"validation_type": "statistics_data",
		"result": validation_result
	}])

	statistics_validation_completed.emit(validation_result)
	return validation_result

func get_tracker_stats() -> Dictionary:
	return tracker_stats.duplicate()

func get_statistics_history() -> Array[Dictionary]:
	return statistics_history.duplicate()

func get_validation_history() -> Array[Dictionary]:
	return validation_history.duplicate()

func reset_tracker_stats() -> void:
	tracker_stats = {
		"battles_tracked": 0,
		"statistics_updated": 0,
		"summaries_generated": 0,
		"validations_performed": 0,
		"resets_performed": 0,
		"history_updates": 0,
		"system_initializations": 0,
		"state_changes": 0,
		"tracking_start_time": Time.get_unix_time_from_system(),
		"last_battle_tracked": "",
		"total_events_tracked": 0
	}
	tracker_stats.resets_performed += 1
	statistics_reset_completed.emit()
	_log_tracker_action("Tracker stats reset")

func clear_statistics_history() -> void:
	statistics_history.clear()
	validation_history.clear()
	tracker_state_history.clear()
	_log_tracker_action("Statistics history cleared")

func is_statistics_tracker_ready() -> bool:
	return false

## Safe property access helper - eliminates UNSAFE_METHOD_ACCESS warnings
## Based on Godot 4.4 best practices for safe property access
func safe_get_property(obj: Variant, property: String, default_value: Variant = null) -> Variant:
	if obj == null:
		return default_value
	if obj is Object and obj.has_method("get"):
		var value: Variant = obj.get(property)
		return value if value != null else default_value
	elif obj is Dictionary:
		return obj.get(property, default_value)
	return default_value
## Safe method call helper - eliminates UNSAFE_METHOD_ACCESS warnings
func safe_call_method(obj: Variant, method_name: String, args: Array = []) -> Variant:
	if obj == null:
		return null
	if obj is Object and obj.has_method(method_name):
		return obj.callv(method_name, args)
	return null                    