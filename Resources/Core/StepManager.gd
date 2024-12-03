class_name StepManager
extends Node

signal step_started(step_data: Dictionary)
signal step_completed(step_data: Dictionary)
signal sequence_completed

var game_state: GameState
var current_step: int = 0
var steps: Array = []
var step_handlers: Dictionary = {}

func _init(_game_state: GameState) -> void:
    game_state = _game_state
    _register_step_handlers()

func _register_step_handlers() -> void:
    # Virtual method to be implemented by child classes
    pass

func start_sequence() -> void:
    current_step = 0
    process_current_step()

func process_current_step() -> void:
    if current_step >= steps.size():
        sequence_completed.emit()
        return
        
    var step_data = {
        "step": current_step,
        "type": steps[current_step]
    }
    
    step_started.emit(step_data)
    
    if step_handlers.has(steps[current_step]):
        await step_handlers[steps[current_step]].call()
    
    step_completed.emit(step_data)
    advance_step()

func advance_step() -> void:
    current_step += 1
    if current_step < steps.size():
        process_current_step()
    else:
        sequence_completed.emit()

func get_current_step() -> int:
    return current_step

func get_step_count() -> int:
    return steps.size()

func get_step_description(step: int) -> String:
    # Virtual method to be implemented by child classes
    return ""

func is_sequence_complete() -> bool:
    return current_step >= steps.size()

func reset() -> void:
    current_step = 0 