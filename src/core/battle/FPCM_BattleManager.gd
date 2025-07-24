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

# FSM States - explicit battle flow control
enum BattlePhase {
	NONE,
	PRE_BATTLE,
	TACTICAL_BATTLE,
	BATTLE_RESOLUTION,
	POST_BATTLE,
	BATTLE_COMPLETE
}

# Core signals - following DiceSystem signal architecture
signal phase_changed(old_phase: BattlePhase, new_phase: BattlePhase)
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
	@export var experience_gained: Array[Dictionary] = []
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
@export var current_phase: BattlePhase = BattlePhase.NONE
@export var battle_state: FPCM_BattleState = null
@export var battle_result: BattleResult = null
@export var is_active: bool = false
@export var auto_advance: bool = true
@export var debug_mode: bool = false

# System references - lazy loaded for safety
var dice_system: DiceSystem = null
var battle_events_system: BattleEventsSystem = null
var story_system: Node = null

# UI references - managed dynamically
var active_ui_components: Dictionary = {}
var ui_history: Array[BattlePhase] = []

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
func initialize_battle(mission_data: Resource, crew_members: Array[Resource], enemy_forces: Array[Resource]) -> bool:
	if is_active:
		battle_error.emit("BATTLE_ALREADY_ACTIVE", {"current_phase": current_phase})
		return false
	
	# Initialize battle state
	battle_state = FPCM_BattleState.new()
	battle_state.mission_data = mission_data
	battle_state.crew_members = crew_members.duplicate()
	battle_state.enemy_forces = enemy_forces.duplicate()
	battle_state.current_phase = BattlePhase.PRE_BATTLE
	
	# Initialize systems
	if battle_events_system:
		battle_events_system.initialize_battle()
	
	# Reset tracking
	is_active = true
	current_phase = BattlePhase.NONE
	ui_history.clear()
	phase_start_time = Time.get_ticks_msec() / 1000.0
	
	# Transition to pre-battle phase
	transition_to_phase(BattlePhase.PRE_BATTLE)
	
	if debug_mode:
		print("Battle initialized: Mission=%s, Crew=%d, Enemies=%d" % [
			safe_get_property(mission_data, "name", "Unknown") if mission_data else "None",
			crew_members.size(),
			enemy_forces.size()
		])
	
	return true

## Transition between battle phases with full validation
func transition_to_phase(new_phase: BattlePhase) -> bool:
	if not is_active and new_phase != BattlePhase.NONE:
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
	
	var old_phase: BattlePhase = current_phase
	
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
			BattlePhase.keys()[old_phase],
			BattlePhase.keys()[new_phase],
			ui_name
		])
	
	return true

## Validate phase transitions according to battle flow
func _is_valid_transition(from_phase: BattlePhase, to_phase: BattlePhase) -> bool:
	match from_phase:
		BattlePhase.NONE:
			return to_phase == BattlePhase.PRE_BATTLE
		BattlePhase.PRE_BATTLE:
			return to_phase in [BattlePhase.TACTICAL_BATTLE, BattlePhase.BATTLE_RESOLUTION]
		BattlePhase.TACTICAL_BATTLE:
			return to_phase in [BattlePhase.BATTLE_RESOLUTION, BattlePhase.POST_BATTLE]
		BattlePhase.BATTLE_RESOLUTION:
			return to_phase == BattlePhase.POST_BATTLE
		BattlePhase.POST_BATTLE:
			return to_phase == BattlePhase.BATTLE_COMPLETE
		BattlePhase.BATTLE_COMPLETE:
			return to_phase == BattlePhase.NONE
		_:
			return false

## Get UI component name for phase
func _get_ui_name_for_phase(phase: BattlePhase) -> String:
	match phase:
		BattlePhase.PRE_BATTLE:
			return "PreBattleUI"
		BattlePhase.TACTICAL_BATTLE:
			return "TacticalBattleUI"
		BattlePhase.BATTLE_RESOLUTION:
			return "BattleResolutionUI"
		BattlePhase.POST_BATTLE:
			return "PostBattleUI"
		_:
			return ""

## Get data package for phase transition
func _get_phase_data(phase: BattlePhase) -> Dictionary:
	var data: Dictionary = {
		"battle_state": battle_state,
		"phase": phase,
		"timestamp": Time.get_ticks_msec() / 1000.0
	}
	
	match phase:
		BattlePhase.PRE_BATTLE:
			data["mission_data"] = battle_state.mission_data if battle_state else null
			data["crew_members"] = battle_state.crew_members if battle_state else []
			data["enemy_forces"] = battle_state.enemy_forces if battle_state else []
		BattlePhase.BATTLE_RESOLUTION:
			data["battle_result"] = battle_result
		BattlePhase.POST_BATTLE:
			data["battle_result"] = battle_result
			data["rewards"] = _calculate_rewards()
	
	return data

## Phase entry logic
func _enter_phase(phase: BattlePhase) -> void:
	match phase:
		BattlePhase.PRE_BATTLE:
			_setup_pre_battle()
		BattlePhase.TACTICAL_BATTLE:
			_setup_tactical_battle()
		BattlePhase.BATTLE_RESOLUTION:
			_setup_battle_resolution()
		BattlePhase.POST_BATTLE:
			_setup_post_battle()
		BattlePhase.BATTLE_COMPLETE:
			_complete_battle()

## Phase exit logic  
func _exit_phase(phase: BattlePhase) -> void:
	match phase:
		BattlePhase.PRE_BATTLE:
			_finalize_pre_battle()
		BattlePhase.TACTICAL_BATTLE:
			_finalize_tactical_battle()
		BattlePhase.BATTLE_RESOLUTION:
			_finalize_battle_resolution()
		BattlePhase.POST_BATTLE:
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
	current_phase = BattlePhase.NONE
	battle_state = null
	battle_result = null

## Phase finalization methods (placeholder for future logic)
func _finalize_pre_battle() -> void:
	pass

func _finalize_tactical_battle() -> void:
	pass

func _finalize_battle_resolution() -> void:
	pass

func _finalize_post_battle() -> void:
	pass

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
		print("Battle dice roll: %s = %d" % [result.context, result.total])

## Handle battle events
func _on_battle_event_triggered(event: BattleEventsSystem.BattleEvent) -> void:
	battle_event_activated.emit(event)
	if debug_mode:
		print("Battle event triggered: %s" % event.title)

## Force advance to next phase (for UI automation)
func advance_phase() -> bool:
	var next_phase: BattlePhase
	
	match current_phase:
		BattlePhase.PRE_BATTLE:
			next_phase = BattlePhase.BATTLE_RESOLUTION # Default to automatic resolution
		BattlePhase.TACTICAL_BATTLE:
			next_phase = BattlePhase.BATTLE_RESOLUTION
		BattlePhase.BATTLE_RESOLUTION:
			next_phase = BattlePhase.POST_BATTLE
		BattlePhase.POST_BATTLE:
			next_phase = BattlePhase.BATTLE_COMPLETE
		BattlePhase.BATTLE_COMPLETE:
			next_phase = BattlePhase.NONE
		_:
			return false
	
	return transition_to_phase(next_phase)

## Get current battle status for UI display
func get_battle_status() -> Dictionary:
	return {
		"is_active": is_active,
		"current_phase": current_phase,
		"phase_name": BattlePhase.keys()[current_phase] if current_phase < BattlePhase.size() else "UNKNOWN",
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
	current_phase = BattlePhase.NONE
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