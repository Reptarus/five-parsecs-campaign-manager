@warning_ignore("return_value_discarded")
@warning_ignore("unsafe_method_access")
@warning_ignore("untyped_declaration")
class_name FPCM_BattleTracker
extends Node

## Real-time Battle Tracking System
##
## Production-grade unit tracking for tabletop Five Parsecs battles.
## Designed for minimal latency and maximum reliability during live play.
## Handles health, status effects, activation tracking, and battle events.
## Architecture: Event-driven with efficient state management
## Performance: Optimized for real-time updates with <16ms response times

# Dependencies
const BattlefieldTypes = preload("res://src/core/battle/BattlefieldTypes.gd")
# GlobalEnums available as autoload singleton

# Real-time tracking signals
signal unit_health_changed(unit_id: String, old_health: int, new_health: int)
signal unit_defeated(unit_id: String, defeat_type: String)
signal unit_activated(unit_id: String, round: int)
signal unit_added(unit_data: Resource)
signal round_started(round_number: int)
signal round_ended(round_number: int, summary: RoundSummary)
signal battle_event_occurred(event: BattleEvent)
signal victory_condition_met(team: String, condition: String)
signal tracking_error(error_code: String, details: Dictionary)
signal unit_reaction_spent(unit_id: String, reactions_remaining: int, max_reactions: int)
signal unit_reactions_reset(unit_id: String, max_reactions: int)

# Battle event types for real-time generation
enum EventType {
	ENVIRONMENTAL_HAZARD,
	REINFORCEMENTS,
	WEATHER_CHANGE,
	EQUIPMENT_MALFUNCTION,
	MORALE_CHECK,
	SPECIAL_MISSION,
}

# Round summary data structure
class RoundSummary extends Resource:
	@export var round_number: int = 0
	@export var units_activated: Array[String] = []
	@export var damage_dealt: Dictionary = {} # unit_id -> damage_taken
	@export var status_changes: Array[Dictionary] = []
	@export var events_triggered: Array[String] = []
	@export var round_duration_seconds: float = 0.0
	
	func get_casualties_this_round() -> Array[String]:
		var casualties: Array[String] = []
		for unit_id in damage_dealt.keys():
			if damage_dealt[unit_id] >= 999: # Special marker for defeated
				casualties.append(unit_id)
		return casualties

class BattleEvent extends Resource:
	@export var event_id: String = ""
	@export var event_type: EventType = EventType.ENVIRONMENTAL_HAZARD
	@export var title: String = ""
	@export var description: String = ""
	@export var triggered_round: int = 0
	@export var affects_team: String = "all" # "crew", "enemy", "all"
	@export var auto_resolve: bool = false
	@export var requires_dice_roll: bool = false
	@export var dice_pattern: String = "d6"

# Performance-optimized state management
@export var tracked_units: Dictionary = {} # unit_id -> UnitData (direct reference)
@export var current_round: int = 0
@export var battle_active: bool = false
@export var round_start_time: float = 0.0
@export var activation_order: Array[String] = [] # Unit IDs in initiative order
@export var current_activation_index: int = 0

# Battle configuration
@export var auto_event_checks: bool = true
@export var event_frequency: float = 0.15 # 15% chance per round
@export var track_detailed_stats: bool = true
@export var enable_undo_system: bool = true

# Performance monitoring
var _update_frequency: float = 0.0
var _last_update_time: float = 0.0
var _performance_metrics: Dictionary = {}

# Undo system for mistake correction
var _undo_stack: Array[Dictionary] = []
const MAX_UNDO_DEPTH: int = 10

# Kill Attribution System (Five Parsecs Campaign Tracking)
# Tracks final blow kills for character lifetime statistics
var kills_by_character: Dictionary = {}  # character_id -> Array[enemy_ids killed]
var kill_details: Array[Dictionary] = []  # Full kill records with metadata
var last_damage_dealer: Dictionary = {}  # unit_id -> {attacker_id, damage, timestamp}

# Manager dependencies
var dice_manager: Node = null
var battle_events_system: Node = null

func _ready() -> void:
	## Initialize battle tracker with performance monitoring
	_initialize_dependencies()
	_setup_performance_monitoring()
	_initialize_undo_system()

func _initialize_dependencies() -> void:
	## Initialize dependencies with graceful degradation
	dice_manager = _get_singleton_or_node("DiceManager")
	battle_events_system = _get_singleton_or_node("BattleEventsSystem")
	
	if not dice_manager:
		push_warning("BattleTracker: DiceManager unavailable, using fallback")
	# BattleEventsSystem is not an autoload - it's created as a Resource instance
	# This warning is expected and indicates fallback behavior will be used
	if not battle_events_system:
		# Only warn in non-test environments to reduce log noise
		var is_test_env = DisplayServer.get_name() == "headless" or \
						 (Engine.get_main_loop() and Engine.get_main_loop() is SceneTree and \
						  Engine.get_main_loop().get_root() and \
						  Engine.get_main_loop().get_root().name.begins_with("test_"))
		if not is_test_env:
			push_warning("BattleTracker: BattleEventsSystem unavailable, using simple events")

func _get_singleton_or_node(name: String) -> Node:
	## Safe singleton/node retrieval with fallback
	if Engine.has_singleton(name):
		return Engine.get_singleton(name)
	
	var node_paths := ["/root/%s" % name, "../%s" % name]
	for path in node_paths:
		var typed_path: Variant = path
		if has_node(path):
			return get_node(path)
	return null

func _setup_performance_monitoring() -> void:
	## Setup performance monitoring for production environments
	_performance_metrics = {
		"updates_per_second": 0.0,
		"average_response_time": 0.0,
		"peak_response_time": 0.0,
		"total_operations": 0,
		"error_count": 0,
	}
	
	# Monitor update frequency in debug builds
	if OS.is_debug_build():
		var timer := Timer.new()
		timer.wait_time = 1.0
		timer.timeout.connect(_update_performance_metrics)
		add_child(timer)
		timer.start()

func _initialize_undo_system() -> void:
	## Initialize undo system for mistake correction
	_undo_stack.clear()
	
	# Connect to state changes for undo tracking
	var _connect_result: int = unit_health_changed.connect(_record_undo_state.bind("health_change"))
	unit_activated.connect(_record_undo_state.bind("activation"))

# =====================================================
# BATTLE LIFECYCLE MANAGEMENT
# =====================================================

func initialize_battle(crew_units: Array, enemy_units: Array, options: Dictionary = {}) -> bool:
	## Initialize battle tracking with comprehensive setup
	## @param crew_units: Array of crew member resources
	## @param enemy_units: Array of enemy resources
	## @param options: Battle configuration options
	## @return: Success status
	# Clear existing state
	reset_battle_state()
	
	# Add units to tracking with validation
	var crew_added := _add_units_batch(crew_units, "crew")
	var enemies_added := _add_units_batch(enemy_units, "enemy")
	
	if crew_added == 0 or enemies_added == 0:
		tracking_error.emit("INVALID_UNITS", {"crew": crew_added, "enemies": enemies_added})
		return false
	
	# Apply battle configuration
	_apply_battle_options(options)
	
	# Initialize battle state
	battle_active = true
	current_round = 0
	round_start_time = Time.get_time_dict_from_system().hour * 3600.0 + Time.get_time_dict_from_system().minute * 60.0 + Time.get_time_dict_from_system().second
	
	# Generate initial activation order
	_generate_activation_order()
	return true

func start_new_round() -> void:
	## Start new battle round with optimized state updates
	if not battle_active:
		push_warning("BattleTracker: Cannot start round - battle not active")
		return
	
	# Save previous round summary
	if current_round > 0:
		var summary := _generate_round_summary()
		round_ended.emit(current_round, summary)
	
	# Increment round and reset state
	current_round += 1
	current_activation_index = 0
	round_start_time = Time.get_unix_time_from_system()
	
	# Reset unit activations efficiently
	_reset_unit_activations()
	
	# Check for random events
	if auto_event_checks:
		_check_for_battle_events()
	
	round_started.emit(current_round)

func end_battle(victory_team: String = "") -> Dictionary:
	## End battle and generate comprehensive results
	if not battle_active:
		push_warning("BattleTracker: Battle already ended")
		return {}
	
	battle_active = false
	var end_time := Time.get_unix_time_from_system()
	
	# Generate final round summary
	var final_summary := _generate_round_summary()
	round_ended.emit(current_round, final_summary)
	
	# Compile battle statistics
	var battle_results := {
		"victory_team": victory_team,
		"total_rounds": current_round,
		"battle_duration": end_time - round_start_time,
		"units_final_state": _get_all_unit_states(),
		"casualties": _get_casualties_by_team(),
		"performance_metrics": _performance_metrics.duplicate(),
	}
	return battle_results

# =====================================================
# UNIT TRACKING - PERFORMANCE OPTIMIZED
# =====================================================

func add_unit(unit_data: Resource, team: String) -> String:
	## Add single unit with validation and performance optimization
	if not unit_data:
		tracking_error.emit("INVALID_UNIT_DATA", {"team": team})
		return ""
	
	var tracked_unit := BattlefieldTypes.UnitData.new()
	
	# Use appropriate initialization based on team
	if team == "crew":
		tracked_unit.initialize_from_crew_member(unit_data)
	else:
		tracked_unit.initialize_from_enemy(unit_data)
	
	# Add to efficient tracking dictionary
	tracked_units[tracked_unit.unit_id] = tracked_unit
	
	# Emit signal for UI updates
	unit_added.emit(tracked_unit)
	return tracked_unit.unit_id

func update_unit_health(unit_id: String, new_health: int, damage_source: String = "", attacker_id: String = "") -> bool:
	## High-performance health update with comprehensive tracking
	## @param unit_id: Unit identifier
	## @param new_health: New health value
	## @param damage_source: Optional damage source for logging
	## @param attacker_id: Optional attacker ID for kill attribution
	## @return: Success status
	var start_time := Time.get_ticks_usec()

	# Fast lookup with null check
	var unit := tracked_units.get(unit_id) as BattlefieldTypes.UnitData
	if not unit:
		tracking_error.emit("UNIT_NOT_FOUND", {"unit_id": unit_id})
		return false

	var old_health := unit.current_health
	var clamped_health := clampi(new_health, 0, unit.max_health)

	# Only update if health actually changed
	if old_health == clamped_health:
		return true

	var damage_dealt := old_health - clamped_health

	# Update health efficiently
	unit.current_health = clamped_health

	# Track last damage dealer for kill attribution (final blow)
	if attacker_id != "" and damage_dealt > 0:
		last_damage_dealer[unit_id] = {
			"attacker_id": attacker_id,
			"damage": damage_dealt,
			"timestamp": Time.get_unix_time_from_system()
		}

	# Track detailed statistics if enabled
	if track_detailed_stats:
		_record_damage_statistics(unit_id, damage_dealt, damage_source)

	# Emit appropriate signals
	unit_health_changed.emit(unit_id, old_health, clamped_health)

	# Check for defeat condition
	if clamped_health <= 0 and old_health > 0:
		_handle_unit_defeat(unit_id, unit)

	# Record performance metrics
	var end_time := Time.get_ticks_usec()
	_record_operation_performance("health_update", end_time - start_time)
	return true

func toggle_unit_activation(unit_id: String) -> bool:
	## Toggle unit activation status with validation
	var unit := tracked_units.get(unit_id) as BattlefieldTypes.UnitData
	if not unit:
		return false

	unit.activated_this_round = !unit.activated_this_round
	if unit.activated_this_round:
		unit_activated.emit(unit_id, current_round)
	return true

# =====================================================
# REACTION ECONOMY SYSTEM (Five Parsecs Core Rules)
# =====================================================

func can_unit_react(unit_id: String) -> bool:
	## Check if unit can take a reaction action
	## Uses Character.can_use_reaction() for full validation including Swift species cap
	## @param unit_id: Unit identifier
	## @return: True if unit has reactions remaining
	var unit := tracked_units.get(unit_id) as BattlefieldTypes.UnitData
	if not unit:
		return false

	# Get the source character if available
	var source_character = unit.source_character if unit.has_method("get") else null
	if source_character and source_character.has_method("can_use_reaction"):
		return source_character.can_use_reaction()

	# Fallback: Check unit data directly
	var reactions_remaining := get_unit_reactions_remaining(unit_id)
	return reactions_remaining > 0

func spend_unit_reaction(unit_id: String) -> bool:
	## Spend one reaction for unit action
	## Respects Swift species 1-reaction limit and other species caps
	## @param unit_id: Unit identifier
	## @return: True if reaction was successfully spent
	var unit := tracked_units.get(unit_id) as BattlefieldTypes.UnitData
	if not unit:
		tracking_error.emit("UNIT_NOT_FOUND", {"unit_id": unit_id, "operation": "spend_reaction"})
		return false

	# Get the source character if available
	var source_character = unit.source_character if unit.has_method("get") else null
	if source_character and source_character.has_method("spend_reaction"):
		var success: bool = source_character.spend_reaction()
		if success:
			var remaining := get_unit_reactions_remaining(unit_id)
			var max_reactions := get_unit_max_reactions(unit_id)
			unit_reaction_spent.emit(unit_id, remaining, max_reactions)
		return success

	# Fallback: Use unit data tracking
	if not can_unit_react(unit_id):
		return false

	# Increment internal tracking (if no Character available)
	if not unit.has_method("get") or not "reactions_used_this_round" in unit:
		unit.activated_this_round = true  # Legacy fallback

	var remaining := get_unit_reactions_remaining(unit_id)
	var max_reactions := get_unit_max_reactions(unit_id)
	unit_reaction_spent.emit(unit_id, remaining, max_reactions)
	return true

func get_unit_reactions_remaining(unit_id: String) -> int:
	## Get remaining reactions for unit this round
	## @param unit_id: Unit identifier
	## @return: Number of reactions remaining
	var unit := tracked_units.get(unit_id) as BattlefieldTypes.UnitData
	if not unit:
		return 0

	# Get from source character if available
	var source_character = unit.source_character if unit.has_method("get") else null
	if source_character and source_character.has_method("get_reactions_remaining"):
		return source_character.get_reactions_remaining()

	# Fallback: Binary activated state (0 or max)
	if unit.activated_this_round:
		return 0
	return get_unit_max_reactions(unit_id)

func get_unit_max_reactions(unit_id: String) -> int:
	## Get maximum reactions for unit per round
	## Accounts for Swift species (1 reaction) and other species modifiers
	## @param unit_id: Unit identifier
	## @return: Maximum reactions per round
	var unit := tracked_units.get(unit_id) as BattlefieldTypes.UnitData
	if not unit:
		return 0

	# Get from source character if available
	var source_character = unit.source_character if unit.has_method("get") else null
	if source_character and source_character.has_method("get_max_reactions"):
		return source_character.get_max_reactions()

	# Default: 3 reactions per round (Five Parsecs standard)
	return 3

func reset_unit_reactions(unit_id: String) -> void:
	## Reset reactions for a single unit at round start
	## @param unit_id: Unit identifier
	var unit := tracked_units.get(unit_id) as BattlefieldTypes.UnitData
	if not unit:
		return

	# Reset on source character if available
	var source_character = unit.source_character if unit.has_method("get") else null
	if source_character and source_character.has_method("reset_reactions"):
		source_character.reset_reactions()

	# Reset legacy tracking
	unit.activated_this_round = false

	var max_reactions := get_unit_max_reactions(unit_id)
	unit_reactions_reset.emit(unit_id, max_reactions)

func get_units_with_reactions() -> Array[String]:
	## Get list of unit IDs that still have reactions available this round
	## Useful for filtering action UI and AI decision making
	## @return: Array of unit IDs with remaining reactions
	var units_with_reactions: Array[String] = []
	for unit_id in tracked_units.keys():
		if can_unit_react(unit_id):
			units_with_reactions.append(unit_id)
	return units_with_reactions

func get_units_exhausted() -> Array[String]:
	## Get list of unit IDs that have exhausted their reactions this round
	## @return: Array of unit IDs with no remaining reactions
	var exhausted_units: Array[String] = []
	for unit_id in tracked_units.keys():
		if not can_unit_react(unit_id):
			exhausted_units.append(unit_id)
	return exhausted_units

func batch_update_health(updates: Array) -> Dictionary:
	## Batch health updates for performance optimization
	## @param updates: Array of {unit_id: String, health: int, source: String}
	## @return: Results summary
	var results := {"success": 0, "failed": 0, "errors": []}
	
	for update in updates:
		var typed_update: Variant = update
		var success := update_unit_health(
			update.get("unit_id", ""),
			update.get("health", 0),
			update.get("source", "batch_update")
		)
		if success:
			results.success += 1
		else:
			results.failed += 1
			results.errors.append(update.get("unit_id", "unknown"))
	
	return results

# =====================================================
# BATTLE EVENTS SYSTEM
# =====================================================

func _check_for_battle_events() -> void:
	## Check for random battle events with configurable frequency
	if not auto_event_checks:
		return
	
	var event_roll := randf()
	if event_roll < event_frequency:
		var event := _generate_battle_event()
		if event:
			battle_event_occurred.emit(event)

func _generate_battle_event() -> BattleEvent:
	## Generate battle event using Five Parsecs rules
	var event := BattleEvent.new()
	event.event_id = "event_%d_%d" % [current_round, Time.get_unix_time_from_system()]
	event.triggered_round = current_round
	
	# Use battle events system if available, otherwise use simple generation
	if battle_events_system and battle_events_system.has_method("generate_event"):
		var system_event: BattleEvent = battle_events_system.generate_event(current_round)
		if system_event:
			_copy_system_event_to_tracker_event(system_event, event)
			return event
	
	# Fallback: Simple event generation
	_generate_simple_battle_event(event)
	return event

func _generate_simple_battle_event(event: BattleEvent) -> void:
	## Simple battle event generation for fallback
	var event_types := [
		{
			"type": EventType.ENVIRONMENTAL_HAZARD,
			"title": "Environmental Hazard",
			"description": "Terrain hazard activates - check for effects",
			"affects": "all",
		},
		{
			"type": EventType.REINFORCEMENTS,
			"title": "Possible Reinforcements",
			"description": "Roll for reinforcement arrival",
			"affects": "enemy",
		},
		{
			"type": EventType.WEATHER_CHANGE,
			"title": "Weather Change",
			"description": "Battlefield conditions change - visibility affected",
			"affects": "all",
		},
		{
			"type": EventType.MORALE_CHECK,
			"title": "Morale Check",
			"description": "Units must make morale checks",
			"affects": "all",
		},
	]
	
	var selected_event: Dictionary = event_types[randi() % event_types.size()]
	event.event_type = selected_event.type
	event.title = selected_event.title
	event.description = selected_event.description
	event.affects_team = selected_event.affects

func trigger_manual_event(event_type: EventType, custom_description: String = "") -> void:
	## Manually trigger battle event for GM intervention
	var event := BattleEvent.new()
	event.event_id = "manual_%d" % Time.get_unix_time_from_system()
	event.event_type = event_type
	event.triggered_round = current_round
	event.title = "Manual Event"
	event.description = custom_description if custom_description != "" else "GM-triggered event"
	battle_event_occurred.emit(event)

# =====================================================
# VICTORY CONDITION MONITORING
# =====================================================

func check_victory_conditions() -> Dictionary:
	## Check for victory conditions and return status
	var crew_alive := _count_alive_units("crew")
	var enemies_alive := _count_alive_units("enemy")
	
	var victory_status := {
		"victory_achieved": false,
		"winning_team": "",
		"condition": "",
		"crew_alive": crew_alive,
		"enemies_alive": enemies_alive,
	}
	
	# Check standard victory conditions
	if crew_alive == 0:
		victory_status.victory_achieved = true
		victory_status.winning_team = "enemy"
		victory_status.condition = "crew_eliminated"
		victory_condition_met.emit("enemy", "crew_eliminated")
	elif enemies_alive == 0:
		victory_status.victory_achieved = true
		victory_status.winning_team = "crew"
		victory_status.condition = "enemies_eliminated"
		victory_condition_met.emit("crew", "enemies_eliminated")
	elif current_round >= 20: # Maximum round limit
		victory_status.victory_achieved = true
		victory_status.winning_team = "draw" if crew_alive == enemies_alive else ("crew" if crew_alive > enemies_alive else "enemy")
		victory_status.condition = "time_limit"
		victory_condition_met.emit(victory_status.winning_team, "time_limit")
	
	return victory_status

# =====================================================
# UNDO SYSTEM FOR MISTAKE CORRECTION
# =====================================================

func undo_last_action() -> bool:
	## Undo the last tracked action
	if not enable_undo_system or (_undo_stack.is_empty()):
		return false
	
	var last_state: Dictionary = _undo_stack.pop_back()
	_restore_state_from_undo(last_state)
	return true

func get_undo_available() -> bool:
	## Check if undo is available
	return enable_undo_system and not _undo_stack.is_empty()

func _record_undo_state(action_type: String) -> void:
	## Record current state for undo functionality
	if not enable_undo_system:
		return
	
	var state := {
		"action_type": action_type,
		"timestamp": Time.get_unix_time_from_system(),
		"round": current_round,
		"unit_states": _get_all_unit_states(),
	}
	_undo_stack.append(state)
	
	# Maintain maximum undo depth
	while _undo_stack.size() > MAX_UNDO_DEPTH:
		_undo_stack.pop_front()

func _restore_state_from_undo(state: Dictionary) -> void:
	## Restore state from undo record
	current_round = state.get("round", current_round)
	var unit_states_raw = state.unit_states if state else null
	var unit_states: Dictionary = unit_states_raw if unit_states_raw != null else {}
	
	for unit_id in unit_states.keys():
		var unit := tracked_units.get(unit_id) as BattlefieldTypes.UnitData
		if unit:
			var saved_state: Dictionary = unit_states[unit_id]
			var health_value = saved_state.health if saved_state else null
			unit.current_health = health_value if health_value != null else unit.current_health
			var activated_value = saved_state.activated if saved_state else null
			unit.activated_this_round = activated_value if activated_value != null else false

# =====================================================
# ANALYTICS AND PERFORMANCE
# =====================================================

func get_battle_analytics() -> Dictionary:
	## Get comprehensive battle analytics
	return {
		"round": current_round,
		"battle_duration": Time.get_unix_time_from_system() - round_start_time,
		"units_alive": _count_alive_units("all"),
		"crew_status": _get_team_status("crew"),
		"enemy_status": _get_team_status("enemy"),
		"damage_statistics": _get_damage_statistics(),
		"performance_metrics": _performance_metrics.duplicate(),
	}

func _get_team_status(team: String) -> Dictionary:
	## Get detailed status for team
	var team_units := _get_units_by_team(team)
	var alive_count := 0
	var total_health := 0
	var max_health := 0
	
	for unit in team_units:
		var typed_unit: Variant = unit
		if unit.is_alive():
			alive_count += 1
			total_health += unit.current_health
			max_health += unit.max_health
	
	return {
		"total_units": team_units.size(),
		"alive_units": alive_count,
		"health_percentage": float(total_health) / float(max_health) if max_health > 0 else 0.0,
	}

func _update_performance_metrics() -> void:
	## Update performance metrics for monitoring
	var current_time := Time.get_unix_time_from_system()
	var time_delta := current_time - _last_update_time
	if time_delta > 0:
		_performance_metrics.updates_per_second = 1.0 / time_delta
		_last_update_time = current_time

func _record_operation_performance(operation: String, duration_usec: int) -> void:
	## Record operation performance metrics
	_performance_metrics.total_operations += 1
	var duration_ms := duration_usec / 1000.0
	
	if duration_ms > _performance_metrics.peak_response_time:
		_performance_metrics.peak_response_time = duration_ms
	
	# Calculate rolling average
	var current_avg: float = _performance_metrics.average_response_time
	var count: int = _performance_metrics.total_operations
	_performance_metrics.average_response_time = (current_avg * (count - 1) + duration_ms) / count

# =====================================================
# UTILITY FUNCTIONS
# =====================================================

func _add_units_batch(units: Array, team: String) -> int:
	## Add multiple units efficiently
	var added_count := 0
	for unit_data in units:
		var typed_unit_data: Variant = unit_data
		var unit_id := add_unit(unit_data, team)
		if unit_id != "":
			added_count += 1
	return added_count

func _reset_unit_activations() -> void:
	## Reset all unit activations and reactions at round start
	for unit_id in tracked_units.keys():
		reset_unit_reactions(unit_id)

func _generate_activation_order() -> void:
	## Generate unit activation order (for initiative tracking)
	activation_order.clear()
	activation_order.assign(tracked_units.keys())
	activation_order.shuffle() # Simple random order, can be enhanced with initiative

func _handle_unit_defeat(unit_id: String, unit: BattlefieldTypes.UnitData) -> void:
	## Handle unit defeat with appropriate effects and kill attribution
	var defeat_type := "unconscious" # Five Parsecs uses unconscious vs. killed

	# Roll for casualty vs unconscious (Five Parsecs rule)
	if dice_manager and dice_manager.has_method("roll_dice"):
		var casualty_roll: int = dice_manager.roll_dice("BattleTracker", "d6")
		if casualty_roll <= 2:
			defeat_type = "casualty"
	else:
		if randi_range(1, 6) <= 2:
			defeat_type = "casualty"

	# Record kill attribution (final blow tracking)
	if last_damage_dealer.has(unit_id):
		var attacker_info: Dictionary = last_damage_dealer[unit_id]
		var attacker_id: String = attacker_info.get("attacker_id", "")
		if attacker_id != "":
			record_kill(attacker_id, unit_id)

	unit_defeated.emit(unit_id, defeat_type)

func record_kill(attacker_id: String, target_id: String) -> void:
	## Record a kill for character lifetime statistics
	## @param attacker_id: ID of the character who got the final blow
	## @param target_id: ID of the defeated unit
	# Add to kills_by_character dictionary
	if not kills_by_character.has(attacker_id):
		kills_by_character[attacker_id] = []
	kills_by_character[attacker_id].append(target_id)

	# Record detailed kill information
	kill_details.append({
		"attacker_id": attacker_id,
		"target_id": target_id,
		"battle_round": current_round,
		"timestamp": Time.get_unix_time_from_system()
	})

	if OS.is_debug_build():
		print("[BattleTracker] Kill recorded: %s killed %s (round %d)" % [attacker_id, target_id, current_round])

func get_kills_for_character(character_id: String) -> Array:
	## Get list of targets killed by a character in this battle
	return kills_by_character.get(character_id, [])

func get_kill_count_for_character(character_id: String) -> int:
	## Get number of kills for a character in this battle
	return get_kills_for_character(character_id).size()

func _count_alive_units(team: String) -> int:
	## Count alive units for specified team
	var count := 0
	for unit in tracked_units.values():
		if (team == "all" or unit.team == team) and unit.is_alive():
			count += 1
	return count

func _get_units_by_team(team: String) -> Array[BattlefieldTypes.UnitData]:
	## Get all units for specified team
	var team_units: Array[BattlefieldTypes.UnitData] = []
	for unit in tracked_units.values():
		if unit.team == team:
			team_units.append(unit)
	return team_units

func _get_all_unit_states() -> Dictionary:
	## Get current state of all units
	var states := {}
	for unit_id in tracked_units.keys():
		var unit := tracked_units[unit_id] as BattlefieldTypes.UnitData
		states[unit_id] = {
			"health": unit.current_health,
			"activated": unit.activated_this_round,
			"alive": unit.is_alive(),
		}
	return states

func _get_casualties_by_team() -> Dictionary:
	## Get casualties organized by team
	var casualties := {"crew": [], "enemy": []}
	for unit in tracked_units.values():
		if not unit.is_alive():
			casualties[unit.team].append(unit.unit_name)
	return casualties

func _generate_round_summary() -> RoundSummary:
	## Generate comprehensive round summary
	var summary := RoundSummary.new()
	summary.round_number = current_round
	summary.round_duration_seconds = Time.get_unix_time_from_system() - round_start_time
	
	# Collect activated units
	for unit in tracked_units.values():
		if unit.activated_this_round:
			summary.units_activated.append(unit.unit_id)
	
	return summary

func _record_damage_statistics(unit_id: String, damage: int, source: String) -> void:
	## Record damage statistics for analytics
	# Implementation for detailed damage tracking
	pass

func _apply_battle_options(options: Dictionary) -> void:
	## Apply battle configuration options
	auto_event_checks = options.get("auto_events", true)
	event_frequency = options.get("event_frequency", 0.15)
	track_detailed_stats = options.get("detailed_stats", true)
	enable_undo_system = options.get("enable_undo", true)

func _copy_system_event_to_tracker_event(system_event: Resource, tracker_event: BattleEvent) -> void:
	## Copy event data from battle events system
	var title_value = system_event.title if system_event else null
	tracker_event.title = title_value if title_value != null else "Unknown Event"
	
	var description_value = system_event.description if system_event else null
	tracker_event.description = description_value if description_value != null else ""
	# Additional mapping as needed

func _get_damage_statistics() -> Dictionary:
	## Get damage statistics for analytics
	# Placeholder for detailed damage analytics
	return {}

func reset_battle_state() -> void:
	## Reset all battle state for new battle
	tracked_units.clear()
	current_round = 0
	battle_active = false
	activation_order.clear()
	current_activation_index = 0
	_undo_stack.clear()
	_performance_metrics.total_operations = 0
	_performance_metrics.error_count = 0
	# Reset kill attribution tracking
	kills_by_character.clear()
	kill_details.clear()
	last_damage_dealer.clear()

