class_name FPCM_BattleManager
extends Resource

## Enterprise-grade Battle Manager for Five Parsecs Campaign Manager
## Coordinates all battle UI phases using FSM and signal architecture
## Integrates with DiceSystem, StoryTrack, and BattleEvents systems
##
## Architecture: Resource-based design following DiceSystem patterns
## Performance: Optimized for 60 FPS with proper state management
## Integration: Full signal-driven communication with core systems

# Dependencies - following DiceSystem pattern
const BattleTypes = preload("res://src/core/battle/BattlefieldTypes.gd")
const DiceSystem = preload("res://src/core/systems/DiceSystem.gd")
const BattleEventsSystem = preload("res://src/core/battle/BattleEventsSystem.gd")
const Godot4Utils = preload("res://src/utils/Godot4Utils.gd")

# FSM States - explicit battle flow control
enum BattleManagerPhase {
	NONE,
	PRE_BATTLE,
	TACTICAL_BATTLE,
	BATTLE_RESOLUTION,
	POST_BATTLE,
	BATTLE_COMPLETE
}


# Core signals - following DiceSystem signal architecture
signal phase_changed(old_phase: BattleManagerPhase, new_phase: BattleManagerPhase)
signal battle_state_updated(state: FPCM_BattleState)
signal battle_completed(results: BattleResult)
signal battle_error(error_code: String, context: Dictionary)

# UI coordination signals
signal ui_transition_requested(target_ui: String, data: Dictionary)
signal ui_lock_requested(locked: bool, reason: String)
signal ui_refresh_requested(components: Array[String])

# System integration signals  
signal dice_roll_requested(pattern: DiceSystem.DicePattern, context: String)
signal story_event_triggered(event_id: String, context: Dictionary)
signal battle_event_activated(event: BattleEventsSystem.BattleEvent)

# Battle Result Resource Class - following DiceSystem.DiceRoll pattern
class BattleResult extends Resource:
	@export var victory: bool = false
	@export var crew_casualties: Array[Resource] = []
	@export var crew_injuries: Array[Resource] = []
	@export var loot_found: Array[Resource] = []
	@export var credits_earned: int = 0
	@export var experience_gained: Dictionary = {}
	@export var story_points: int = 0
	@export var battle_duration: int = 0 # rounds
	@export var events_triggered: Array[String] = []
	@export var is_complete: bool = false
	@export var timestamp: float = 0.0
	
	func _init(p_victory: bool = false) -> void:
		victory = p_victory
		timestamp = Time.get_ticks_msec() / 1000.0
	
	func get_summary_text() -> String:
		var result_text: String = "Victory" if victory else "Defeat"
		var casualties_text: String = str(crew_casualties.size()) + " casualties"
		var credits_text: String = str(credits_earned) + " credits"
		return "%s - %s, %s earned" % [result_text, casualties_text, credits_text]

# Core system properties - following BattleEventsSystem pattern
@export var current_phase: BattleManagerPhase = BattleManagerPhase.NONE
@export var battle_state: FPCM_BattleState = null
@export var battle_result: BattleResult = null
@export var is_active: bool = false
@export var auto_advance: bool = true
@export var debug_mode: bool = false

# System references - lazy loaded for safety
var dice_system: DiceSystem = null
var battle_events_system: BattleEventsSystem = null
var story_system: Node = null

# Tier controller reference (set by TacticalBattleUI)
var tier_controller: Resource = null

# UI references - managed dynamically
var active_ui_components: Dictionary = {}
var ui_history: Array[BattleManagerPhase] = []

# Performance tracking
var phase_start_time: float = 0.0
var update_frequency: float = 1.0 / 60.0 # 60 FPS target
var last_update_time: float = 0.0

func _init() -> void:
	_initialize_systems()

## Initialize battle manager with proper system connections
func _initialize_systems() -> void:
	# Lazy load systems to avoid circular dependencies
	if not dice_system:
		dice_system = DiceSystem.new()
		dice_system.dice_rolled.connect(_on_dice_rolled)
	
	if not battle_events_system:
		battle_events_system = BattleEventsSystem.new()
		battle_events_system.battle_event_triggered.connect(_on_battle_event_triggered)
	
	# Initialize empty battle state
	if not battle_state:
		battle_state = FPCM_BattleState.new()

## Start a new battle with mission data
func initialize_battle(mission_data: Resource, crew_members: Array, enemy_forces: Array) -> bool:
	if is_active:
		battle_error.emit("BATTLE_ALREADY_ACTIVE", {"current_phase": current_phase})
		return false

	# CRITICAL VALIDATION: Ensure crew is available for battle
	if crew_members.is_empty():
		battle_error.emit("NO_CREW_AVAILABLE", {
			"reason": "Cannot start battle with 0 crew members",
			"crew_count": 0
		})
		return false

	# VALIDATION: Check minimum crew composition (at least 1 crew member)
	var valid_crew_count: int = 0
	for crew in crew_members:
		if crew != null:
			valid_crew_count += 1

	if valid_crew_count == 0:
		battle_error.emit("NO_VALID_CREW", {
			"reason": "All crew members are null or invalid",
			"provided_count": crew_members.size()
		})
		return false

	# VALIDATION: Check crew equipment (at least one weapon required for battle)
	var has_weapon: bool = false
	var total_equipment: int = 0

	for crew in crew_members:
		if crew != null:
			# Check for equipment property (Character resources should have this)
			var crew_equipment: Variant = Godot4Utils.safe_get_property(crew, "equipment", [])

			if crew_equipment is Array:
				total_equipment += (crew_equipment as Array).size()
				# Check if any equipment is a weapon
				for item in crew_equipment:
					if item is Dictionary:
						var category = item.get("category", "")
						if category == "WEAPON" or category == "weapon":
							has_weapon = true
							break

			if has_weapon:
				break

	# Warn if no weapons detected (not blocking, but important for gameplay)
	if not has_weapon and total_equipment == 0:
		if debug_mode:
			pass
		battle_error.emit("NO_EQUIPMENT_WARNING", {
			"reason": "No weapons or equipment detected on crew members",
			"crew_count": valid_crew_count,
			"severity": "warning"
		})

	# Initialize battle state
	battle_state = FPCM_BattleState.new()
	battle_state.mission_data = mission_data
	battle_state.crew_members = crew_members.duplicate()
	battle_state.enemy_forces = enemy_forces.duplicate()
	battle_state.current_phase = BattleManagerPhase.PRE_BATTLE
	
	# Initialize systems
	if battle_events_system:
		battle_events_system.initialize_battle()
	
	# Reset tracking
	is_active = true
	current_phase = BattleManagerPhase.NONE
	ui_history.clear()
	phase_start_time = Time.get_ticks_msec() / 1000.0
	
	# Transition to pre-battle phase
	transition_to_phase(BattleManagerPhase.PRE_BATTLE)
	
	if debug_mode:
		print("Battle initialized: Mission=%s, Crew=%d, Enemies=%d" % [
			Godot4Utils.safe_get_property(mission_data, "name", "Unknown") if mission_data else "None",
			crew_members.size(),
			enemy_forces.size()
		])
	
	return true

## Transition between battle phases with full validation
func transition_to_phase(new_phase: BattleManagerPhase) -> bool:
	if not is_active and new_phase != BattleManagerPhase.NONE:
		battle_error.emit("INVALID_TRANSITION", {"reason": "Battle not active", "target_phase": new_phase})
		return false
	
	# Validate transition
	if not _is_valid_transition(current_phase, new_phase):
		battle_error.emit("INVALID_TRANSITION", {
			"from_phase": current_phase,
			"to_phase": new_phase,
			"reason": "Invalid phase sequence"
		})
		return false
	
	var old_phase: BattleManagerPhase = current_phase
	
	# Execute phase exit logic
	_exit_phase(old_phase)
	
	# Update state
	current_phase = new_phase
	if battle_state:
		battle_state.current_phase = new_phase
	
	# Execute phase entry logic
	_enter_phase(new_phase)
	
	# Update tracking
	ui_history.append(old_phase)
	phase_start_time = Time.get_ticks_msec() / 1000.0
	
	# Emit signals
	phase_changed.emit(old_phase, new_phase)
	if battle_state:
		battle_state_updated.emit(battle_state)
	
	# Request UI transition
	var ui_name: String = _get_ui_name_for_phase(new_phase)
	if ui_name != "":
		ui_transition_requested.emit(ui_name, _get_phase_data(new_phase))
	
	if debug_mode:
		print("Phase transition: %s -> %s (UI: %s)" % [
			BattleManagerPhase.keys()[old_phase],
			BattleManagerPhase.keys()[new_phase],
			ui_name
		])
	
	return true

## Validate phase transitions according to battle flow
func _is_valid_transition(from_phase: BattleManagerPhase, to_phase: BattleManagerPhase) -> bool:
	match from_phase:
		BattleManagerPhase.NONE:
			return to_phase == BattleManagerPhase.PRE_BATTLE
		BattleManagerPhase.PRE_BATTLE:
			return to_phase in [BattleManagerPhase.TACTICAL_BATTLE, BattleManagerPhase.BATTLE_RESOLUTION]
		BattleManagerPhase.TACTICAL_BATTLE:
			return to_phase in [BattleManagerPhase.BATTLE_RESOLUTION, BattleManagerPhase.POST_BATTLE]
		BattleManagerPhase.BATTLE_RESOLUTION:
			return to_phase == BattleManagerPhase.POST_BATTLE
		BattleManagerPhase.POST_BATTLE:
			return to_phase == BattleManagerPhase.BATTLE_COMPLETE
		BattleManagerPhase.BATTLE_COMPLETE:
			return to_phase == BattleManagerPhase.NONE
		_:
			return false

## Get UI component name for phase
func _get_ui_name_for_phase(phase: BattleManagerPhase) -> String:
	match phase:
		BattleManagerPhase.PRE_BATTLE:
			return "PreBattleUI"
		BattleManagerPhase.TACTICAL_BATTLE:
			return "TacticalBattleUI"
		BattleManagerPhase.BATTLE_RESOLUTION:
			return "BattleTransitionUI"
		BattleManagerPhase.POST_BATTLE:
			return "PostBattleUI"
		_:
			return ""

## Get data package for phase transition
func _get_phase_data(phase: BattleManagerPhase) -> Dictionary:
	var data: Dictionary = {
		"battle_state": battle_state,
		"phase": phase,
		"timestamp": Time.get_ticks_msec() / 1000.0
	}
	
	match phase:
		BattleManagerPhase.PRE_BATTLE:
			data["mission_data"] = battle_state.mission_data if battle_state else null
			data["crew_members"] = battle_state.crew_members if battle_state else []
			data["enemy_forces"] = battle_state.enemy_forces if battle_state else []
		BattleManagerPhase.BATTLE_RESOLUTION:
			data["battle_result"] = battle_result
		BattleManagerPhase.POST_BATTLE:
			data["battle_result"] = battle_result
			data["rewards"] = _calculate_rewards()
	
	return data

## Phase entry logic
func _enter_phase(phase: BattleManagerPhase) -> void:
	match phase:
		BattleManagerPhase.PRE_BATTLE:
			_setup_pre_battle()
		BattleManagerPhase.TACTICAL_BATTLE:
			_setup_tactical_battle()
		BattleManagerPhase.BATTLE_RESOLUTION:
			_setup_battle_resolution()
		BattleManagerPhase.POST_BATTLE:
			_setup_post_battle()
		BattleManagerPhase.BATTLE_COMPLETE:
			_complete_battle()

## Phase exit logic  
func _exit_phase(phase: BattleManagerPhase) -> void:
	match phase:
		BattleManagerPhase.PRE_BATTLE:
			_finalize_pre_battle()
		BattleManagerPhase.TACTICAL_BATTLE:
			_finalize_tactical_battle()
		BattleManagerPhase.BATTLE_RESOLUTION:
			_finalize_battle_resolution()
		BattleManagerPhase.POST_BATTLE:
			_finalize_post_battle()

## Pre-battle setup
func _setup_pre_battle() -> void:
	if battle_state:
		battle_state.battle_start_time = Time.get_ticks_msec() / 1000.0

## Tactical battle setup
func _setup_tactical_battle() -> void:
	if battle_events_system:
		battle_events_system.advance_round()

## Battle resolution setup
func _setup_battle_resolution() -> void:
	# Prepare battle result
	battle_result = BattleResult.new()

## Post-battle setup
func _setup_post_battle() -> void:
	if battle_result:
		battle_result.is_complete = true

## Complete battle and cleanup
func _complete_battle() -> void:
	is_active = false
	if battle_result:
		battle_completed.emit(battle_result)
	
	# Reset state
	current_phase = BattleManagerPhase.NONE
	battle_state = null
	battle_result = null

## Phase finalization methods
func _finalize_pre_battle() -> void:
	## Finalize pre-battle phase - save initial state and emit completion
	if not battle_state:
		return
	
	# Create checkpoint of pre-battle state
	battle_state.create_checkpoint("pre_battle_complete")
	
	# Log phase completion
	if debug_mode:
		pass
	
	# Notify systems that setup is complete
	ui_refresh_requested.emit(["deployment_complete", "ready_for_combat"])

func _finalize_tactical_battle() -> void:
	## Finalize tactical battle phase - calculate statistics and prepare for resolution
	if not battle_state:
		return
	
	# Calculate battle statistics
	var rounds_fought: int = battle_state.current_round if battle_state else 0
	var total_damage_dealt: int = battle_state.total_damage_dealt if battle_state else 0
	var total_damage_taken: int = battle_state.total_damage_taken if battle_state else 0
	
	# Create checkpoint before resolution
	battle_state.create_checkpoint("tactical_complete")
	
	# Log tactical phase completion
	if debug_mode:
		pass
	
	# Prepare for battle resolution
	ui_transition_requested.emit("battle_resolution", {
		"rounds": rounds_fought,
		"damage_dealt": total_damage_dealt,
		"damage_taken": total_damage_taken
	})

func _finalize_battle_resolution() -> void:
	## Finalize battle resolution - apply PostBattleProcessor results and update character states
	if not battle_state or not battle_result:
		return
	
	# Mark battle result as complete
	battle_result.is_complete = true
	battle_result.timestamp = Time.get_ticks_msec() / 1000.0
	
	# Apply casualties and injuries to battle state
	for casualty in battle_result.crew_casualties:
		if battle_state.has_method("mark_unit_casualty"):
			battle_state.mark_unit_casualty(casualty)
	
	for injured in battle_result.crew_injuries:
		if battle_state.has_method("mark_unit_injured"):
			battle_state.mark_unit_injured(injured)
	
	# Create final checkpoint
	battle_state.create_checkpoint("resolution_complete")
	
	# Log resolution completion
	if debug_mode:
		print("FPCM_BattleManager: Resolution complete - %s, %d casualties, %d injuries" % [
			"Victory" if battle_result.victory else "Defeat",
			battle_result.crew_casualties.size(),
			battle_result.crew_injuries.size()
		])
	
	# Notify systems that results are ready
	ui_refresh_requested.emit(["battle_results", "post_battle_ready"])

func _finalize_post_battle() -> void:
	## Finalize post-battle phase - clean up resources and emit final results for campaign integration
	if not battle_result:
		return
	
	# Calculate final rewards
	var rewards = _calculate_rewards()
	
	# Add battle statistics to result
	if battle_state:
		battle_result.battle_duration = battle_state.current_round
		battle_result.events_triggered = battle_state.triggered_events
	
	# Log post-battle finalization
	if debug_mode:
		print("FPCM_BattleManager: Post-battle complete - %d credits, %d XP awards" % [
			battle_result.credits_earned,
			battle_result.experience_gained.size()
		])
	
	# Emit final battle completion with comprehensive results
	battle_completed.emit(battle_result)
	
	# Notify UI systems
	ui_transition_requested.emit("campaign_return", {
		"victory": battle_result.victory,
		"rewards": rewards,
		"casualties": battle_result.crew_casualties.size()
	})

## Calculate battle rewards based on outcome
func _calculate_rewards() -> Dictionary:
	if not battle_result:
		return {}
	
	var rewards: Dictionary = {
		"credits": battle_result.credits_earned,
		"experience": battle_result.experience_gained,
		"loot": battle_result.loot_found,
		"story_points": battle_result.story_points
	}
	
	return rewards

## Integration with DiceSystem for battle rolls
func request_dice_roll(pattern: DiceSystem.DicePattern, context: String) -> DiceSystem.DiceRoll:
	if dice_system:
		dice_roll_requested.emit(pattern, context)
		return dice_system.roll_dice(pattern, context)
	else:
		battle_error.emit("DICE_SYSTEM_UNAVAILABLE", {"context": context})
		return null

## Handle dice roll results
func _on_dice_rolled(result: DiceSystem.DiceRoll) -> void:
	if debug_mode:
		pass

## Handle battle events
func _on_battle_event_triggered(event: BattleEventsSystem.BattleEvent) -> void:
	battle_event_activated.emit(event)
	if debug_mode:
		pass

## Force advance to next phase (for UI automation)
func advance_phase() -> bool:
	var next_phase: BattleManagerPhase
	
	match current_phase:
		BattleManagerPhase.PRE_BATTLE:
			next_phase = BattleManagerPhase.BATTLE_RESOLUTION # Default to automatic resolution
		BattleManagerPhase.TACTICAL_BATTLE:
			next_phase = BattleManagerPhase.BATTLE_RESOLUTION
		BattleManagerPhase.BATTLE_RESOLUTION:
			next_phase = BattleManagerPhase.POST_BATTLE
		BattleManagerPhase.POST_BATTLE:
			next_phase = BattleManagerPhase.BATTLE_COMPLETE
		BattleManagerPhase.BATTLE_COMPLETE:
			next_phase = BattleManagerPhase.NONE
		_:
			return false
	
	return transition_to_phase(next_phase)

## Get current battle status for UI display
func get_battle_status() -> Dictionary:
	return {
		"is_active": is_active,
		"current_phase": current_phase,
		"phase_name": BattleManagerPhase.keys()[current_phase] if current_phase < BattleManagerPhase.size() else "UNKNOWN",
		"phase_duration": Time.get_ticks_msec() / 1000.0 - phase_start_time,
		"battle_state": battle_state,
		"battle_result": battle_result
	}

## Register UI component for management
func register_ui_component(component_name: String, component: Control) -> void:
	active_ui_components[component_name] = component
	
	# Connect common signals if available
	if component.has_signal("phase_completed"):
		component.phase_completed.connect(_on_ui_phase_completed.bind(component_name))
	if component.has_signal("error_occurred"):
		component.error_occurred.connect(_on_ui_error.bind(component_name))

## Unregister UI component
func unregister_ui_component(component_name: String) -> void:
	if component_name in active_ui_components:
		var component: Control = active_ui_components[component_name]
		
		# Disconnect signals
		if component.has_signal("phase_completed") and component.phase_completed.is_connected(_on_ui_phase_completed):
			component.phase_completed.disconnect(_on_ui_phase_completed)
		if component.has_signal("error_occurred") and component.error_occurred.is_connected(_on_ui_error):
			component.error_occurred.disconnect(_on_ui_error)
		
		active_ui_components.erase(component_name)

## Handle UI phase completion
func _on_ui_phase_completed(component_name: String) -> void:
	if auto_advance:
		advance_phase()

## Handle UI errors
func _on_ui_error(component_name: String, error: String, context: Dictionary) -> void:
	battle_error.emit("UI_ERROR", {
		"component": component_name,
		"error": error,
		"context": context
	})

## Emergency reset for error recovery
func emergency_reset() -> void:
	is_active = false
	current_phase = BattleManagerPhase.NONE
	battle_state = null
	battle_result = null
	active_ui_components.clear()
	ui_history.clear()
	
	battle_error.emit("EMERGENCY_RESET", {"timestamp": Time.get_ticks_msec() / 1000.0})

## Performance monitoring
func get_performance_stats() -> Dictionary:
	return {
		"update_frequency": update_frequency,
		"phase_duration": Time.get_ticks_msec() / 1000.0 - phase_start_time,
		"active_components": active_ui_components.size(),
		"memory_usage": get_memory_usage()
	}

## Get memory usage (placeholder for future profiling)
func get_memory_usage() -> int:
	# This would integrate with Godot's profiling in a real implementation
	return 0

