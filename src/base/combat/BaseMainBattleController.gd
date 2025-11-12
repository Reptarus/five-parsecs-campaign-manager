@tool
@warning_ignore("unused_signal")
extends Node
class_name FiveParsecsMainBattleController

## Enhanced Main Battle Controller
##
## Base class for managing battle flow, turn sequences, and combat coordination.
## Provides comprehensive battle state management with simplified data handling.
##
## Features:
	## - Turn-based battle flow management
## - Unit activation and action processing
## - Objective tracking and completion
## - Enhanced logging with action history
## - Streamlined data caching system
##
## Architecture: Simplified from Universal framework to direct GDScript patterns
## Performance: Optimized with reduced dependencies and enhanced logging

# Enhanced battle controller - Universal framework removed for simplification

# Dependencies
const FiveParsecsBattlefieldManager = preload("res://src/base/combat/battlefield/BaseBattlefieldManager.gd")
const FiveParsecsBattlefieldGenerator = preload("res://src/base/combat/battlefield/BaseBattlefieldGenerator.gd")
const FiveParsecsCombatManager = preload("res://src/base/combat/BaseCombatManager.gd")
const FiveParsecsBattleRules = preload("res://src/base/combat/BaseBattleRules.gd")
const FiveParsecsBattleData = preload("res://src/base/combat/BaseBattleData.gd")

# Enhanced Signals
signal battle_initialized(battle_data: Dictionary)
signal battle_started()
signal battle_ended(result: Dictionary)
signal turn_started(turn_number: int, active_faction: int)
signal turn_ended(turn_number: int, active_faction: int)
signal phase_changed(phase: int)
signal unit_activated(unit: Node)
signal unit_deactivated(unit: Node)
signal action_performed(unit: Node, action: Dictionary)
signal objective_completed(objective_id: String, faction: int)
signal battle_controller_initialized()
signal battle_controller_state_changed(state: Dictionary)
signal battle_flow_updated(flow_data: Dictionary)
signal battle_validation_completed(validation_result: Dictionary)
signal battle_statistics_updated(stats: Dictionary)

# Enhanced battle controller data management
var _action_log: Array[Dictionary] = []
var _data_cache: Dictionary = {}

# Battle state
var battle_data: Dictionary = {}
var current_turn: int = 0
var current_phase: int = 0
var active_faction: int = 0
var active_unit: Node = null
var battle_active: bool = false
var battle_result: Dictionary = {}
var objectives: Array[Dictionary] = []
var completed_objectives: Dictionary = {}

# System references
var battlefield_manager: FiveParsecsBattlefieldManager = null
var battlefield_generator: FiveParsecsBattlefieldGenerator = null
var combat_manager: FiveParsecsCombatManager = null
var _battle_rules: FiveParsecsBattleRules = null

# Battle Controller Statistics
var battle_controller_stats: Dictionary = {
	"battles_initialized": 0,
	"battles_started": 0,
	"battles_completed": 0,
	"total_turns_processed": 0,
	"phases_processed": 0,
	"units_activated": 0,
	"actions_performed": 0,
	"objectives_completed": 0,
	"battle_validations": 0,
	"system_initializations": 0,
	"signal_connections": 0,
	"battlefield_generations": 0,
	"unit_initializations": 0,
	"state_changes": 0,
	"last_battle_duration": 0.0,
	"average_battle_duration": 0.0,
	"battle_durations": []
}

# Battle Flow History
var battle_flow_history: Array[Dictionary] = []
var battle_state_history: Array[Dictionary] = []
var battle_validation_history: Array[Dictionary] = []

# Initialize battle controller
func _init() -> void:
	battle_controller_stats.system_initializations += 1
	_log_battle_controller_action("Battle controller initialized")

# Virtual methods to be implemented by derived classes
func _ready() -> void:
	_initialize_systems()
	_connect_signals()
	_initialize_universal_framework()
	battle_controller_initialized.emit()

func _initialize_universal_framework() -> void:
	# Framework initialization simplified
	_log_battle_controller_action("Battle controller framework initialized")

func _initialize_systems() -> void:
	# Override in derived classes to initialize game-specific systems
	battle_controller_stats.system_initializations += 1
	_log_battle_controller_action("Battle controller systems initialized")

func _connect_signals() -> void:
	# Connect signals from battlefield manager
	if battlefield_manager and battlefield_manager.has_method("has_signal") and battlefield_manager.has_signal("unit_moved"):
		if not battlefield_manager.unit_moved.is_connected(_on_unit_moved):
			battlefield_manager.unit_moved.connect(_on_unit_moved)
		if not battlefield_manager.unit_added.is_connected(_on_unit_added):
			battlefield_manager.unit_added.connect(_on_unit_added)
		if not battlefield_manager.unit_removed.is_connected(_on_unit_removed):
			battlefield_manager.unit_removed.connect(_on_unit_removed)
		battle_controller_stats.signal_connections += 3

	# Connect signals from combat manager
	if combat_manager and combat_manager.has_method("has_signal") and combat_manager.has_signal("combat_state_changed"):
		if not combat_manager.combat_state_changed.is_connected(_on_combat_state_changed):
			combat_manager.combat_state_changed.connect(_on_combat_state_changed)
		if not combat_manager.combat_result_calculated.is_connected(_on_combat_result_calculated):
			combat_manager.combat_result_calculated.connect(_on_combat_result_calculated)
		if not combat_manager.character_position_updated.is_connected(_on_character_position_updated):
			combat_manager.character_position_updated.connect(_on_character_position_updated)
		battle_controller_stats.signal_connections += 3

	# Connect signals from battlefield generator
	if battlefield_generator and battlefield_generator.has_signal("generation_completed"):
		if not battlefield_generator.generation_completed.is_connected(_on_battlefield_generation_completed):
			battlefield_generator.generation_completed.connect(_on_battlefield_generation_completed)
		battle_controller_stats.signal_connections += 1

	_log_battle_controller_action("Battle controller signals connected", {"connections": battle_controller_stats.signal_connections})

# Battle initialization and control
func initialize_battle(battle_config: Dictionary = {}) -> void:
	var battle_start_time: Dictionary = Time.get_time_dict_from_system()

	battle_active = false
	current_turn = 0
	current_phase = 0
	active_faction = 0
	active_unit = null
	battle_result = {}
	objectives = []
	completed_objectives = {}

	# Validate battle configuration
	var validation_result: Dictionary = _validate_battle_config(battle_config)
	if not validation_result.valid:
		_log_battle_controller_action("Battle initialization failed", {"reason": validation_result.error})
		return

	# Generate battlefield if not provided
	if not "battlefield" in battle_config:
		_generate_battlefield(battle_config.get("battlefield_config", {}))
	else:
		_load_battlefield(battle_config.battlefield)

	# Initialize units
	_initialize_units(battle_config.get("units", {}))

	# Initialize objectives
	_initialize_objectives(battle_config.get("objectives", []))

	# Compile battle data
	battle_data = {
		"_config": battle_config,
		"battlefield": battlefield_manager.validate_battlefield() if battlefield_manager and battlefield_manager.has_method("validate_battlefield") else {},
		"units": _get_units_data(),
		"objectives": objectives,
		"initialization_time": battle_start_time,
		"controller_stats": battle_controller_stats.duplicate()
	}

	battle_controller_stats.battles_initialized += 1
	_track_battle_flow("battle_initialized", battle_data)
	_log_battle_controller_action("Battle initialized", {"config": battle_config})

	battle_initialized.emit(battle_data)

func start_battle() -> void:
	if not battle_active:
		var battle_start_time: Dictionary = Time.get_time_dict_from_system()
		battle_active = true
		current_turn = 1
		current_phase = 0

		# Determine starting faction
		active_faction = _determine_starting_faction()

		battle_controller_stats.battles_started += 1
		_track_battle_flow("battle_started", {"start_time": battle_start_time, "starting_faction": active_faction})
		_log_battle_controller_action("Battle started", {"faction": active_faction})

		battle_started.emit()
		_start_turn()

func end_battle(result: Dictionary = {}) -> void:
	if battle_active:
		var battle_end_time: Dictionary = Time.get_time_dict_from_system()
		battle_active = false
		battle_result = result

		# Calculate battle duration
		var duration: float = _calculate_battle_duration()
		battle_controller_stats.last_battle_duration = duration
		battle_controller_stats.battle_durations.append(duration)
		battle_controller_stats.average_battle_duration = _calculate_average_duration()
		battle_controller_stats.battles_completed += 1

		_track_battle_flow("battle_ended", {"result": result, "duration": duration, "end_time": battle_end_time})
		_log_battle_controller_action("Battle ended", {"result": result, "duration": duration})

		battle_ended.emit(result)

func next_turn() -> void:
	if battle_active:
		current_turn += 1
		battle_controller_stats.total_turns_processed += 1
		_track_battle_flow("turn_advanced", {"turn": current_turn})
		_log_battle_controller_action("Turn advanced", {"turn": current_turn})
		_start_turn()

func next_phase() -> void:
	if battle_active:
		current_phase += 1
		battle_controller_stats.phases_processed += 1
		_track_battle_flow("phase_advanced", {"phase": current_phase})
		_log_battle_controller_action("Phase advanced", {"phase": current_phase})
		phase_changed.emit(current_phase)
		_process_phase()

func activate_unit(unit: Node) -> void:
	if battle_active and unit:
		active_unit = unit
		battle_controller_stats.units_activated += 1
		_track_battle_flow("unit_activated", {"unit": unit.name})
		_log_battle_controller_action("Unit activated", {"unit": unit.name})
		unit_activated.emit(unit)

func deactivate_unit() -> void:
	if battle_active and active_unit:
		var unit: Node = active_unit
		active_unit = null
		_track_battle_flow("unit_deactivated", {"unit": unit.name})
		_log_battle_controller_action("Unit deactivated", {"unit": unit.name})
		unit_deactivated.emit(unit)

func perform_action(unit: Node, action: Dictionary) -> void:
	if battle_active and unit:
		battle_controller_stats.actions_performed += 1
		_track_battle_flow("action_performed", {"unit": unit.name, "action": action})
		_log_battle_controller_action("Action performed", {"unit": unit.name, "action": action})
		_process_action(unit, action)
		action_performed.emit(unit, action)

# Battlefield management
func _generate_battlefield(config: Dictionary = {}) -> void:
	if battlefield_generator:
		# Apply configuration with safe property access
		var grid_size_value: Variant = config.get("grid_size", null) if config else null
		if grid_size_value != null and battlefield_generator and battlefield_generator.has_method("set_grid_size"):
			battlefield_generator.set_grid_size(grid_size_value)
		elif grid_size_value != null and "grid_size" in battlefield_generator:
			battlefield_generator.grid_size = grid_size_value

		var terrain_pattern_value: Variant = config.get("terrain_pattern", null) if config else null
		if terrain_pattern_value != null and battlefield_generator and battlefield_generator.has_method("set_terrain_pattern"):
			battlefield_generator.set_terrain_pattern(terrain_pattern_value)
		elif terrain_pattern_value != null and "terrain_pattern" in battlefield_generator:
			battlefield_generator.terrain_pattern = terrain_pattern_value

		var deployment_style_value: Variant = config.get("deployment_style", null) if config else null
		if deployment_style_value != null and "deployment_style" in battlefield_generator:
			battlefield_generator.deployment_style = deployment_style_value

		var seed_value: Variant = safe_get_property(battlefield_generator, "seed") if config else null
		if seed_value != null and "generation_seed" in battlefield_generator:
			battlefield_generator.generation_seed = seed_value
			if "use_random_seed" in battlefield_generator:
				battlefield_generator.use_random_seed = false

		battle_controller_stats.battlefield_generations += 1
		_track_battle_flow("battlefield_generated", {"config": config})
		_log_battle_controller_action("Battlefield generated", {"config": config})

		# Generate battlefield
		battlefield_generator.generate_battlefield()

func _load_battlefield(battlefield_data: Dictionary) -> void:
	if battlefield_manager and battlefield_manager.has_method("initialize_battlefield"):
		# Initialize battlefield with safe method calling
		var grid_size_value: Variant = battlefield_data.get("grid_size", Vector2i(24, 24))
		battlefield_manager.initialize_battlefield(grid_size_value)

		# Load terrain with safe property access
		var terrain_array: Variant = battlefield_data.get("terrain", [])
		if terrain_array is Array:
			for terrain in terrain_array:
				if terrain is Dictionary and battlefield_manager and battlefield_manager.has_method("set_terrain"):
					var position_value: Variant = terrain.get("position", null)
					var type_value: Variant = terrain.get("type", null)
					if position_value != null and type_value != null:
						battlefield_manager.set_terrain(position_value, type_value)

		# Load deployment zones with safe access
		var deployment_zones_value: Variant = battlefield_data.get("deployment_zones", {})
		if deployment_zones_value is Dictionary:
			for zone_type in deployment_zones_value.keys():
				if battlefield_manager and battlefield_manager.has_method("set_deployment_zone"):
					battlefield_manager.set_deployment_zone(zone_type, deployment_zones_value[zone_type])

		_track_battle_flow("battlefield_loaded", {"data": battlefield_data})
		_log_battle_controller_action("Battlefield loaded", {"data": battlefield_data})

# Unit management
func _initialize_units(units_data: Dictionary) -> void:
	# Clear existing units
	if battlefield_manager:
		for unit in battlefield_manager.unit_positions.keys():
			battlefield_manager.remove_unit(unit)

	# Add player units
	for unit_data in units_data.get("player", []):
		_add_unit(unit_data, 1) # 1 = player faction

	# Add enemy units
	for unit_data in units_data.get("enemy", []):
		_add_unit(unit_data, 2) # 2 = enemy faction

	battle_controller_stats.unit_initializations += 1
	_track_battle_flow("units_initialized", {"data": units_data})
	_log_battle_controller_action("Units initialized", {"data": units_data})

func _add_unit(unit_data: Dictionary, faction: int) -> Node:
	# To be implemented by derived classes
	_log_battle_controller_action("Unit added", {"data": unit_data, "faction": faction})
	return null

func _get_units_data() -> Dictionary:
	var units_data: Dictionary = {
		"player": [],
		"enemy": []
	}

	# To be implemented by derived classes
	_log_battle_controller_action("Units data retrieved", {"data": units_data})
	return units_data

# Objective management
func _initialize_objectives(objectives_data: Array[Dictionary]) -> void:
	objectives = objectives_data.duplicate()
	completed_objectives = {}
	_track_battle_flow("objectives_initialized", {"objectives": objectives_data})
	_log_battle_controller_action("Objectives initialized", {"count": objectives_data.size()})

func complete_objective(objective_id: String, faction: int) -> void:
	if objective_id in objectives and not objective_id in completed_objectives:
		completed_objectives[objective_id] = faction
		battle_controller_stats.objectives_completed += 1
		_track_battle_flow("objective_completed", {"id": objective_id, "faction": faction})
		_log_battle_controller_action("Objective completed", {"id": objective_id, "faction": faction})
		objective_completed.emit(objective_id, faction)
		_check_victory_conditions()

func _check_victory_conditions() -> void:
	# To be implemented by derived classes
	_log_battle_controller_action("Victory conditions checked")

# Turn and phase management
func _start_turn() -> void:
	current_phase = 0
	_track_battle_flow("turn_started", {"turn": current_turn, "faction": active_faction})
	_log_battle_controller_action("Turn started", {"turn": current_turn, "faction": active_faction})
	turn_started.emit(current_turn, active_faction)
	next_phase()

func _end_turn() -> void:
	_track_battle_flow("turn_ended", {"turn": current_turn, "faction": active_faction})
	_log_battle_controller_action("Turn ended", {"turn": current_turn, "faction": active_faction})
	turn_ended.emit(current_turn, active_faction)
	_switch_faction()

	if active_faction == 1: # Back to player faction
		next_turn()
	else:
		_start_turn()

func _switch_faction() -> void:
	active_faction = 3 - active_faction # Toggle between 1 and 2
	_track_battle_flow("faction_switched", {"faction": active_faction})
	_log_battle_controller_action("Faction switched", {"faction": active_faction})

func _determine_starting_faction() -> int:
	# To be implemented by derived classes
	return 1 # Default to player

func _process_phase() -> void:
	# To be implemented by derived classes
	_log_battle_controller_action("Phase processed", {"phase": current_phase})

func _process_action(unit: Node, action: Dictionary) -> void:
	# To be implemented by derived classes
	_log_battle_controller_action("Action processed", {"unit": unit.name, "action": action})

# Validation and Utility Methods
func _validate_battle_config(config: Dictionary) -> Dictionary:
	var validation_result: Dictionary = {"valid": true, "error": ""}

	# Basic validation
	if config.is_empty():
		validation_result.valid = false
		validation_result.error = "Battle configuration cannot be empty"

	battle_controller_stats.battle_validations += 1
	_track_battle_validation("config_validation", validation_result)

	return validation_result

func _calculate_battle_duration() -> float:
	# Calculate duration based on turn count and other factors
	return float(current_turn) * 2.5 # Example calculation

func _calculate_average_duration() -> float:
	if battle_controller_stats.battle_durations.size() > 0:
		var total: float = 0.0
		for duration in battle_controller_stats.battle_durations:
			total += duration
		return total / float(battle_controller_stats.battle_durations.size())
	return 0.0

func _track_battle_flow(event_type: String, data: Dictionary) -> void:
	var flow_event: Dictionary = {
		"timestamp": Time.get_time_dict_from_system(),
		"type": event_type,
		"data": data,
		"battle_id": battle_data.get("id", "unknown")
	}
	battle_flow_history.append(flow_event)
	battle_flow_updated.emit(flow_event)

func _track_battle_validation(validation_type: String, result: Dictionary) -> void:
	var validation_event: Dictionary = {
		"timestamp": Time.get_time_dict_from_system(),
		"type": validation_type,
		"result": result,
		"battle_id": battle_data.get("id", "unknown")
	}
	battle_validation_history.append(validation_event)
	battle_validation_completed.emit(validation_event)

func _log_battle_controller_action(action: String, details: Dictionary = {}) -> void:
	# Log action to internal log
	_action_log.append({
		"timestamp": Time.get_unix_time_from_system(),
		"action": action,
		"details": details
	})

	# Limit log size
	if _action_log.size() > 100:
		_action_log.pop_front()

	# Update state and emit signal
	battle_controller_stats.state_changes += 1
	battle_controller_state_changed.emit({"action": action, "details": details, "stats": battle_controller_stats})

# Utility Methods
func get_battle_controller_stats() -> Dictionary:
	return battle_controller_stats.duplicate()

func get_battle_flow_history() -> Array[Dictionary]:
	return battle_flow_history.duplicate()

func get_battle_validation_history() -> Array[Dictionary]:
	return battle_validation_history.duplicate()

func get_action_log() -> Array[Dictionary]:
	return _action_log.duplicate()

func get_data_cache() -> Dictionary:
	return _data_cache.duplicate()

func clear_action_log() -> void:
	_action_log.clear()
	_log_battle_controller_action("Action log cleared")

func clear_data_cache() -> void:
	_data_cache.clear()
	_log_battle_controller_action("Data cache cleared")

func reset_battle_controller_stats() -> void:
	battle_controller_stats = {
		"battles_initialized": 0,
		"battles_started": 0,
		"battles_completed": 0,
		"total_turns_processed": 0,
		"phases_processed": 0,
		"units_activated": 0,
		"actions_performed": 0,
		"objectives_completed": 0,
		"battle_validations": 0,
		"system_initializations": 0,
		"signal_connections": 0,
		"battlefield_generations": 0,
		"unit_initializations": 0,
		"state_changes": 0,
		"last_battle_duration": 0.0,
		"average_battle_duration": 0.0,
		"battle_durations": []
	}
	_log_battle_controller_action("Battle controller stats reset")

func clear_battle_history() -> void:
	battle_flow_history.clear()
	battle_state_history.clear()
	battle_validation_history.clear()
	_log_battle_controller_action("Battle history cleared")

func is_battle_controller_ready() -> bool:
	# Simple readiness check - battle controller systems initialized
	return battle_controller_stats.system_initializations > 0

# Signal handlers
func _on_unit_moved(unit: Node, from: Vector2i, to: Vector2i) -> void:
	# To be implemented by derived classes
	_log_battle_controller_action("Unit moved", {"unit": unit.name, "from": from, "to": to})

func _on_unit_added(unit: Node, position: Vector2i) -> void:
	# To be implemented by derived classes
	_log_battle_controller_action("Unit added", {"unit": unit.name, "position": position})

func _on_unit_removed(unit: Node, position: Vector2i) -> void:
	# To be implemented by derived classes
	_log_battle_controller_action("Unit removed", {"unit": unit.name, "position": position})

func _on_combat_state_changed(new_state: Dictionary) -> void:
	# To be implemented by derived classes
	_log_battle_controller_action("Combat state changed", {"state": new_state})

func _on_combat_result_calculated(attacker: Node, target: Node, result: Dictionary) -> void:
	# To be implemented by derived classes
	_log_battle_controller_action("Combat result calculated", {"attacker": attacker.name, "target": target.name, "result": result})

func _on_character_position_updated(character: Node, position: Vector2i) -> void:
	# To be implemented by derived classes
	_log_battle_controller_action("Character position updated", {"character": character.name, "position": position})

func _on_battlefield_generation_completed(battlefield_data: Dictionary) -> void:
	# To be implemented by derived classes
	_log_battle_controller_action("Battlefield generation completed", {"data": battlefield_data})

## Safe property access helper - eliminates UNSAFE_METHOD_ACCESS warnings
func safe_get_property(obj: Object, property: String, default_value: Variant = null) -> Variant:
	# Parameter validation - eliminates UNSAFE_CALL_ARGUMENT warnings
	if not is_instance_valid(obj):
		return default_value
	if obj and obj.has_method("get"):
		var value = obj.get(property)
		return value if value != null else default_value
	return default_value
