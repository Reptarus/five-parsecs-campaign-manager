class_name PhaseController
extends Node

const StepManagerClass = preload("res://Resources/Core/StepManager.gd")

signal phase_started(phase_data: Dictionary)
signal phase_completed(phase_data: Dictionary)
signal phase_changed(old_phase: int, new_phase: int)

var game_state: GameState
var current_phase: int = 0
var phase_managers: Dictionary = {}

func _init(_game_state: GameState) -> void:
    game_state = _game_state
    _initialize_phase_managers()

func _initialize_phase_managers() -> void:
    # Virtual method to be implemented by child classes
    pass

func start_phase(phase: int) -> void:
    if not phase_managers.has(phase):
        push_error("No manager registered for phase %d" % phase)
        return
        
    var old_phase = current_phase
    current_phase = phase
    
    var phase_data = {
        "phase": phase,
        "manager": phase_managers[phase]
    }
    
    phase_started.emit(phase_data)
    phase_changed.emit(old_phase, current_phase)
    
    await phase_managers[phase].start_sequence()
    phase_completed.emit(phase_data)

func register_phase_manager(phase: int, manager: StepManagerClass) -> void:
    phase_managers[phase] = manager
    manager.sequence_completed.connect(_on_phase_manager_completed.bind(phase))

func get_current_phase() -> int:
    return current_phase

func get_phase_manager(phase: int) -> StepManagerClass:
    return phase_managers.get(phase)

func _on_phase_manager_completed(phase: int) -> void:
    # Virtual method to be implemented by child classes
    pass 