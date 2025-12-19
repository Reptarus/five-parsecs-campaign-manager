extends Node

## FPCM Battle Event Bus - Autoload Singleton
## Decouples UI components from direct dependencies following DiceSystem patterns
## Provides centralized signal management for all battle-related communications
##
## Architecture: Signal bus pattern for loose coupling
## Performance: Minimal overhead with efficient signal routing
## Integration: Connects all battle UI components and core systems

# Dependencies for type safety
const FPCM_BattleManager = preload("res://src/core/battle/FPCM_BattleManager.gd")
const FPCM_BattleState = preload("res://src/core/battle/FPCM_BattleState.gd")
const FPCM_DiceSystem = preload("res://src/core/systems/DiceSystem.gd")
const FPCM_BattleEventsSystem = preload("res://src/core/battle/BattleEventsSystem.gd")

# =====================================================
# BATTLE FLOW SIGNALS
# =====================================================

# Phase management
signal battle_initialized(battle_data: Dictionary)
signal battle_phase_changed(old_phase: FPCM_BattleManager.BattleManagerPhase, new_phase: FPCM_BattleManager.BattleManagerPhase)
signal battle_completed(results: FPCM_BattleManager.BattleResult)
signal battle_error(error_code: String, context: Dictionary)

# UI coordination signals
signal ui_transition_requested(target_ui: String, data: Dictionary)
signal ui_component_ready(component_name: String, component: Control)
signal ui_component_removed(component_name: String)
signal ui_lock_requested(locked: bool, reason: String)
signal ui_refresh_requested(components: Array[String])

# Battle state management
signal battle_state_updated(state: FPCM_BattleState)
signal battle_state_saved(save_data: Dictionary)
signal battle_state_loaded(save_data: Dictionary)

# =====================================================
# SYSTEM INTEGRATION SIGNALS
# =====================================================

# DiceSystem integration
signal dice_roll_requested(pattern: FPCM_DiceSystem.DicePattern, context: String)
signal dice_roll_completed(result: FPCM_DiceSystem.DiceRoll)
signal dice_manual_input_requested(dice_roll: FPCM_DiceSystem.DiceRoll)

# StoryTrack integration  
signal story_event_triggered(event_id: String, context: Dictionary)
signal story_progress_updated(progress: int, context: String)

# BattleEvents integration
signal battle_event_activated(event: FPCM_BattleEventsSystem.BattleEvent)
signal environmental_hazard_triggered(hazard: Dictionary)
signal round_advanced(round_number: int)

# Campaign system integration
signal campaign_update_requested(update_type: String, data: Dictionary)
signal campaign_rewards_applied(rewards: Dictionary)

# =====================================================
# UI COMPONENT SPECIFIC SIGNALS
# =====================================================

# Pre-battle phase
signal pre_battle_setup_complete(setup_data: Dictionary)
signal crew_deployment_changed(deployment: Dictionary)
signal enemy_deployment_changed(deployment: Dictionary)

# Tactical battle phase
signal tactical_action_requested(action: String, data: Dictionary)
signal unit_moved(unit_id: String, from_pos: Vector2i, to_pos: Vector2i)
signal combat_resolved(attacker_id: String, target_id: String, result: Dictionary)

# Battle resolution phase
signal battle_resolution_triggered(victory_conditions: Dictionary)
signal automatic_resolution_completed(result: FPCM_BattleManager.BattleResult)
signal tactical_resolution_completed(result: FPCM_BattleManager.BattleResult)

# Post-battle phase
signal post_battle_acknowledged(continue_data: Dictionary)
signal rewards_calculated(rewards: Dictionary)
signal experience_applied(experience_data: Dictionary)

# =====================================================
# PERFORMANCE AND DEBUGGING
# =====================================================

# Performance monitoring
signal performance_warning(component: String, issue: String, data: Dictionary)
signal fps_drop_detected(fps: float, component: String)

# Debug and logging
signal debug_message(level: String, message: String, context: Dictionary)
signal battle_log_entry(message: String, color: Color, timestamp: float)

# =====================================================
# EVENT BUS MANAGEMENT
# =====================================================

# Component registry for management
var registered_components: Dictionary = {}
var active_battle_manager: FPCM_BattleManager = null
var dice_system_instance: FPCM_DiceSystem = null

# Bound callable registry for proper signal disconnection
# Maps component_name -> {"signal_name": bound_callable, ...}
var _bound_callables: Dictionary = {}

# Performance tracking
var signal_count: int = 0
var _performance_timer: Timer

func _ready() -> void:
	"""Initialize the battle event bus"""
	_connect_internal_signals()
	_setup_performance_monitoring()
	print("FPCM Battle Event Bus initialized")

func _setup_performance_monitoring() -> void:
	"""Setup performance monitoring timer"""
	_performance_timer = Timer.new()
	add_child(_performance_timer)
	_performance_timer.wait_time = 5.0  # Check every 5 seconds
	_performance_timer.timeout.connect(_check_performance)
	_performance_timer.start()
	print("FPCM Battle Event Bus: Performance monitoring timer started")

## Register UI component with the event bus
func register_ui_component(component_name: String, component: Control) -> void:
	if component_name in registered_components:
		print("Warning: UI component '%s' already registered, replacing" % component_name)
	
	registered_components[component_name] = component
	ui_component_ready.emit(component_name, component)
	
	# Auto-connect common signals if they exist
	_auto_connect_component_signals(component_name, component)
	
	print("UI component registered: %s" % component_name)

## Unregister UI component from the event bus
func unregister_ui_component(component_name: String) -> void:
	if not registered_components.has(component_name):
		return
	var component = registered_components.get(component_name)
	if not is_instance_valid(component):
		registered_components.erase(component_name)
		return

	if component_name in registered_components:
		_auto_disconnect_component_signals(component_name, component)
		registered_components.erase(component_name)
		ui_component_removed.emit(component_name)
		print("UI component unregistered: %s" % component_name)

## Auto-connect common component signals
func _auto_connect_component_signals(component_name: String, component: Control) -> void:
	if not is_instance_valid(component):
		return

	# Initialize bound callable storage for this component
	var callables: Dictionary = {}

	# Connect phase_completed signal if it exists
	if component.has_signal("phase_completed"):
		var bound_callable = _on_component_phase_completed.bind(component_name)
		component.connect("phase_completed", bound_callable)
		callables["phase_completed"] = bound_callable

	# Connect dice_roll_requested signal if it exists
	if component.has_signal("dice_roll_requested"):
		var bound_callable = _on_component_dice_request.bind(component_name)
		component.connect("dice_roll_requested", bound_callable)
		callables["dice_roll_requested"] = bound_callable

	# Connect ui_error_occurred signal if it exists
	if component.has_signal("ui_error_occurred"):
		var bound_callable = _on_component_error.bind(component_name)
		component.connect("ui_error_occurred", bound_callable)
		callables["ui_error_occurred"] = bound_callable

	# Store the bound callables for later disconnection
	_bound_callables[component_name] = callables

## Auto-disconnect component signals using stored bound callables
func _auto_disconnect_component_signals(component_name: String, component: Control) -> void:
	if not is_instance_valid(component):
		return

	# Get stored bound callables for this component
	if not _bound_callables.has(component_name):
		return

	var callables: Dictionary = _bound_callables[component_name]

	# Disconnect phase_completed using the stored bound callable
	if component.has_signal("phase_completed") and callables.has("phase_completed"):
		var bound_callable = callables["phase_completed"]
		if component.is_connected("phase_completed", bound_callable):
			component.disconnect("phase_completed", bound_callable)

	# Disconnect dice_roll_requested using the stored bound callable
	if component.has_signal("dice_roll_requested") and callables.has("dice_roll_requested"):
		var bound_callable = callables["dice_roll_requested"]
		if component.is_connected("dice_roll_requested", bound_callable):
			component.disconnect("dice_roll_requested", bound_callable)

	# Disconnect ui_error_occurred using the stored bound callable
	if component.has_signal("ui_error_occurred") and callables.has("ui_error_occurred"):
		var bound_callable = callables["ui_error_occurred"]
		if component.is_connected("ui_error_occurred", bound_callable):
			component.disconnect("ui_error_occurred", bound_callable)

	# Clean up the stored callables
	_bound_callables.erase(component_name)

## Set the active battle manager
func set_battle_manager(battle_manager: FPCM_BattleManager) -> void:
	if active_battle_manager != battle_manager:
		# Disconnect old manager
		if active_battle_manager:
			_disconnect_battle_manager_signals(active_battle_manager)
		
		# Connect new manager
		active_battle_manager = battle_manager
		if active_battle_manager:
			_connect_battle_manager_signals(active_battle_manager)

## Connect battle manager signals to event bus
func _connect_battle_manager_signals(battle_manager: FPCM_BattleManager) -> void:
	battle_manager.phase_changed.connect(_on_battle_phase_changed)
	battle_manager.battle_state_updated.connect(_on_battle_state_updated)
	battle_manager.battle_completed.connect(_on_battle_completed)
	battle_manager.battle_error.connect(_on_battle_error)
	battle_manager.ui_transition_requested.connect(_on_ui_transition_requested)

## Disconnect battle manager signals
func _disconnect_battle_manager_signals(battle_manager: FPCM_BattleManager) -> void:
	if battle_manager.phase_changed.is_connected(_on_battle_phase_changed):
		battle_manager.phase_changed.disconnect(_on_battle_phase_changed)
	if battle_manager.battle_state_updated.is_connected(_on_battle_state_updated):
		battle_manager.battle_state_updated.disconnect(_on_battle_state_updated)
	if battle_manager.battle_completed.is_connected(_on_battle_completed):
		battle_manager.battle_completed.disconnect(_on_battle_completed)
	if battle_manager.battle_error.is_connected(_on_battle_error):
		battle_manager.battle_error.disconnect(_on_battle_error)
	if battle_manager.ui_transition_requested.is_connected(_on_ui_transition_requested):
		battle_manager.ui_transition_requested.disconnect(_on_ui_transition_requested)

## Connect internal event bus signals
func _connect_internal_signals() -> void:
	# Connect dice system integration
	dice_roll_requested.connect(_handle_dice_roll_request)
	
	# Connect UI coordination
	ui_lock_requested.connect(_handle_ui_lock_request)
	ui_refresh_requested.connect(_handle_ui_refresh_request)

## Handle dice roll requests through event bus
func _handle_dice_roll_request(pattern: FPCM_DiceSystem.DicePattern, context: String) -> void:
	if not dice_system_instance:
		dice_system_instance = FPCM_DiceSystem.new()
		dice_system_instance.dice_rolled.connect(_on_dice_roll_completed)
	
	var result: FPCM_DiceSystem.DiceRoll = dice_system_instance.roll_dice(pattern, context)
	dice_roll_completed.emit(result)

## Handle UI lock requests
func _handle_ui_lock_request(locked: bool, reason: String) -> void:
	# Send lock request to all registered components
	for component_name: String in registered_components:
		var component: Control = registered_components[component_name]
		if not is_instance_valid(component):
			continue
		if component.has_method("set_ui_locked"):
			component.set_ui_locked(locked, reason)

## Handle UI refresh requests
func _handle_ui_refresh_request(components: Array) -> void:
	for component_name: String in components:
		if component_name in registered_components:
			var component: Control = registered_components[component_name]
			if not is_instance_valid(component):
				continue
			if component.has_method("refresh_ui"):
				component.refresh_ui()

## =====================================================
## SIGNAL HANDLERS
## =====================================================

func _on_component_phase_completed(component_name: String) -> void:
	"""Handle phase completion from UI components"""
	if active_battle_manager:
		active_battle_manager.advance_phase()
	debug_message.emit("INFO", "Phase completed by component: %s" % component_name, {})

func _on_component_dice_request(component_name: String, pattern: FPCM_DiceSystem.DicePattern, context: String) -> void:
	"""Handle dice roll requests from components"""
	dice_roll_requested.emit(pattern, context)

func _on_component_error(component_name: String, error: String, context: Dictionary) -> void:
	"""Handle errors from UI components"""
	var error_context: Dictionary = context.duplicate()
	error_context["source_component"] = component_name
	battle_error.emit("UI_COMPONENT_ERROR", error_context)

func _on_battle_phase_changed(old_phase: FPCM_BattleManager.BattleManagerPhase, new_phase: FPCM_BattleManager.BattleManagerPhase) -> void:
	"""Forward battle phase changes"""
	battle_phase_changed.emit(old_phase, new_phase)

func _on_battle_state_updated(state: FPCM_BattleState) -> void:
	"""Forward battle state updates"""
	battle_state_updated.emit(state)

func _on_battle_completed(result: FPCM_BattleManager.BattleResult) -> void:
	"""Forward battle completion"""
	battle_completed.emit(result)

func _on_battle_error(error_code: String, context: Dictionary) -> void:
	"""Forward battle errors"""
	battle_error.emit(error_code, context)

func _on_ui_transition_requested(target_ui: String, data: Dictionary) -> void:
	"""Forward UI transition requests"""
	ui_transition_requested.emit(target_ui, data)

func _on_dice_roll_completed(result: FPCM_DiceSystem.DiceRoll) -> void:
	"""Forward dice roll completion"""
	dice_roll_completed.emit(result)

## Performance monitoring
func _check_performance() -> void:
	"""Monitor event bus performance"""
	var connected_signals: int = _count_connected_signals()
	
	if connected_signals > 100:
		performance_warning.emit("EventBus", "High signal count", {"count": connected_signals})
	
	# Check for memory leaks
	if registered_components.size() > 20:
		performance_warning.emit("EventBus", "Many registered components", {"count": registered_components.size()})

func _count_connected_signals() -> int:
	"""Count all connected signals for performance monitoring"""
	# This is a simplified count - in a real implementation, 
	# you would iterate through all signals and count connections
	return registered_components.size() * 5 # Rough estimate

## Get event bus status for debugging
func get_event_bus_status() -> Dictionary:
	return {
		"registered_components": registered_components.keys(),
		"active_battle_manager": active_battle_manager != null,
		"dice_system_active": dice_system_instance != null,
		"signal_count": signal_count,
		"performance_healthy": registered_components.size() < 20
	}

func _exit_tree() -> void:
	"""Cleanup when event bus is removed from scene tree"""
	if _performance_timer:
		_performance_timer.stop()
		_performance_timer.queue_free()
		_performance_timer = null
	cleanup_for_scene_change()

## Emergency cleanup for scene transitions
func cleanup_for_scene_change() -> void:
	"""Clean up all connections for scene transitions"""
	# Unregister all components - iterate over a COPY to avoid modification during iteration
	var component_names: Array = registered_components.keys().duplicate()
	for component_name: String in component_names:
		unregister_ui_component(component_name)
	
	# Disconnect battle manager
	if active_battle_manager:
		_disconnect_battle_manager_signals(active_battle_manager)
		active_battle_manager = null
	
	# Cleanup dice system
	if dice_system_instance:
		if dice_system_instance.dice_rolled.is_connected(_on_dice_roll_completed):
			dice_system_instance.dice_rolled.disconnect(_on_dice_roll_completed)
		dice_system_instance = null
	
	print("Battle Event Bus cleaned up for scene change")
