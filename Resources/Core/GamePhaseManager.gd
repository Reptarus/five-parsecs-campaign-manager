class_name GamePhaseManager
extends Node

signal phase_started(phase_data: Dictionary)
signal phase_completed(phase_data: Dictionary)
signal phase_changed(old_phase: int, new_phase: int)
signal step_started(step_data: Dictionary)
signal step_completed(step_data: Dictionary)

const GameEnums = preload("res://Resources/Core/Systems/GlobalEnums.gd")

enum GamePhase {
    UPKEEP,
    CREW_MANAGEMENT,
    MISSION_SELECTION,
    EQUIPMENT,
    BATTLE_PREP,
    BATTLE,
    POST_BATTLE
}

enum PhaseStep {
    INITIALIZE,
    PROCESS,
    VALIDATE,
    CLEANUP
}

var game_state: GameState
var current_phase: GamePhase = GamePhase.UPKEEP
var current_step: PhaseStep = PhaseStep.INITIALIZE
var phase_data: Dictionary = {}
var step_data: Dictionary = {}

# Phase handlers
var phase_handlers: Dictionary = {}
var step_handlers: Dictionary = {}

# UI References
var mission_selection_ui: Control
var equipment_ui: Control
var battle_prep_ui: Control

func _init(_game_state: GameState = null) -> void:
    game_state = _game_state
    _register_phase_handlers()
    _register_step_handlers()

func _register_phase_handlers() -> void:
    phase_handlers = {
        GamePhase.UPKEEP: _handle_upkeep_phase,
        GamePhase.CREW_MANAGEMENT: _handle_crew_phase,
        GamePhase.MISSION_SELECTION: _handle_mission_phase,
        GamePhase.EQUIPMENT: _handle_equipment_phase,
        GamePhase.BATTLE_PREP: _handle_battle_prep_phase,
        GamePhase.BATTLE: _handle_battle_phase,
        GamePhase.POST_BATTLE: _handle_post_battle_phase
    }

func _register_step_handlers() -> void:
    step_handlers = {
        PhaseStep.INITIALIZE: _handle_initialize_step,
        PhaseStep.PROCESS: _handle_process_step,
        PhaseStep.VALIDATE: _handle_validate_step,
        PhaseStep.CLEANUP: _handle_cleanup_step
    }

func start_game_loop() -> void:
    current_phase = GamePhase.UPKEEP
    current_step = PhaseStep.INITIALIZE
    process_current_phase()

func process_current_phase() -> void:
    if not game_state:
        push_error("GameState not initialized")
        return
        
    phase_data = {
        "phase": current_phase,
        "handler": phase_handlers[current_phase]
    }
    
    phase_started.emit(phase_data)
    await phase_handlers[current_phase].call()
    process_current_step()

func process_current_step() -> void:
    step_data = {
        "step": current_step,
        "phase": current_phase,
        "handler": step_handlers[current_step]
    }
    
    step_started.emit(step_data)
    await step_handlers[current_step].call()
    
    if current_step == PhaseStep.CLEANUP:
        step_completed.emit(step_data)
        advance_phase()
    else:
        step_completed.emit(step_data)
        advance_step()

func advance_phase() -> void:
    var old_phase = current_phase
    current_phase = (current_phase + 1) % GamePhase.size()
    current_step = PhaseStep.INITIALIZE
    
    phase_changed.emit(old_phase, current_phase)
    process_current_phase()

func advance_step() -> void:
    current_step = (current_step + 1) % PhaseStep.size()
    process_current_step()

# Phase Handlers
func _handle_upkeep_phase() -> void:
    if not game_state:
        return
        
    # Process upkeep costs
    var upkeep_cost = game_state.calculate_upkeep()
    if game_state.can_afford(upkeep_cost):
        game_state.spend_credits(upkeep_cost)
        game_state.perform_maintenance()
    else:
        game_state.handle_insufficient_funds()

func _handle_crew_phase() -> void:
    if not game_state:
        return
        
    # Handle crew management
    game_state.update_crew_status()
    game_state.process_crew_actions()

func _handle_mission_phase() -> void:
    if not game_state:
        return
        
    # Update available missions
    game_state.mission_manager.update_available_missions()
    
    # Show mission selection UI
    if mission_selection_ui:
        mission_selection_ui.show()
        await mission_selection_ui.mission_selected

func _handle_equipment_phase() -> void:
    if not game_state:
        return
        
    # Show equipment management UI
    if equipment_ui:
        equipment_ui.show()
        await equipment_ui.equipment_phase_completed

func _handle_battle_prep_phase() -> void:
    if not game_state or not game_state.current_mission:
        advance_phase()
        return
        
    # Show battle preparation UI
    if battle_prep_ui:
        battle_prep_ui.show()
        await battle_prep_ui.preparation_completed

func _handle_battle_phase() -> void:
    if not game_state or not game_state.current_mission:
        advance_phase()
        return
        
    # Initialize and start battle
    game_state.battle_manager.initialize_battle(game_state.current_mission)
    await game_state.battle_manager.battle_completed

func _handle_post_battle_phase() -> void:
    if not game_state:
        return
        
    # Process battle results
    game_state.process_battle_results()
    game_state.update_campaign_state()

# Step Handlers
func _handle_initialize_step() -> void:
    match current_phase:
        GamePhase.UPKEEP:
            game_state.prepare_upkeep()
        GamePhase.CREW_MANAGEMENT:
            game_state.prepare_crew_management()
        GamePhase.MISSION_SELECTION:
            game_state.prepare_mission_selection()
        GamePhase.EQUIPMENT:
            game_state.prepare_equipment_phase()
        GamePhase.BATTLE_PREP:
            game_state.prepare_battle()
        GamePhase.BATTLE:
            game_state.initialize_battle()
        GamePhase.POST_BATTLE:
            game_state.prepare_post_battle()

func _handle_process_step() -> void:
    match current_phase:
        GamePhase.UPKEEP:
            game_state.process_upkeep()
        GamePhase.CREW_MANAGEMENT:
            game_state.process_crew_management()
        GamePhase.MISSION_SELECTION:
            game_state.process_mission_selection()
        GamePhase.EQUIPMENT:
            game_state.process_equipment_phase()
        GamePhase.BATTLE_PREP:
            game_state.process_battle_prep()
        GamePhase.BATTLE:
            game_state.process_battle()
        GamePhase.POST_BATTLE:
            game_state.process_post_battle()

func _handle_validate_step() -> void:
    match current_phase:
        GamePhase.UPKEEP:
            game_state.validate_upkeep()
        GamePhase.CREW_MANAGEMENT:
            game_state.validate_crew_management()
        GamePhase.MISSION_SELECTION:
            game_state.validate_mission_selection()
        GamePhase.EQUIPMENT:
            game_state.validate_equipment_phase()
        GamePhase.BATTLE_PREP:
            game_state.validate_battle_prep()
        GamePhase.BATTLE:
            game_state.validate_battle()
        GamePhase.POST_BATTLE:
            game_state.validate_post_battle()

func _handle_cleanup_step() -> void:
    match current_phase:
        GamePhase.UPKEEP:
            game_state.cleanup_upkeep()
        GamePhase.CREW_MANAGEMENT:
            game_state.cleanup_crew_management()
        GamePhase.MISSION_SELECTION:
            game_state.cleanup_mission_selection()
        GamePhase.EQUIPMENT:
            game_state.cleanup_equipment_phase()
        GamePhase.BATTLE_PREP:
            game_state.cleanup_battle_prep()
        GamePhase.BATTLE:
            game_state.cleanup_battle()
        GamePhase.POST_BATTLE:
            game_state.cleanup_post_battle()

# UI Management
func register_ui(ui_type: String, ui_node: Control) -> void:
    match ui_type:
        "mission_selection":
            mission_selection_ui = ui_node
        "equipment":
            equipment_ui = ui_node
        "battle_prep":
            battle_prep_ui = ui_node

func get_current_phase() -> int:
    return current_phase

func get_current_step() -> int:
    return current_step

func is_phase_complete() -> bool:
    return current_step == PhaseStep.CLEANUP

func can_advance_phase() -> bool:
    return is_phase_complete() and game_state.can_advance_phase(current_phase) 