class_name StateTracker
extends Node

signal state_changed(old_state: Dictionary, new_state: Dictionary)
signal state_updated(state: Dictionary)
signal state_reset

var game_state: GameState
var current_state: Dictionary = {}
var state_history: Array[Dictionary] = []
var max_history_size: int = 100

func _init(_game_state: GameState) -> void:
    game_state = _game_state
    _initialize_state()

func _initialize_state() -> void:
    # Virtual method to be implemented by child classes
    pass

func update_state(new_values: Dictionary) -> void:
    var old_state = current_state.duplicate()
    
    for key in new_values:
        if current_state.has(key) and current_state[key] != new_values[key]:
            current_state[key] = new_values[key]
            
    _add_to_history(old_state)
    state_changed.emit(old_state, current_state)
    state_updated.emit(current_state)

func get_state() -> Dictionary:
    return current_state.duplicate()

func get_state_value(key: String, default_value = null):
    return current_state.get(key, default_value)

func reset_state() -> void:
    var old_state = current_state.duplicate()
    current_state.clear()
    _initialize_state()
    state_changed.emit(old_state, current_state)
    state_reset.emit()

func _add_to_history(state: Dictionary) -> void:
    state_history.push_back(state)
    if state_history.size() > max_history_size:
        state_history.pop_front()

func get_history() -> Array[Dictionary]:
    return state_history.duplicate()

func clear_history() -> void:
    state_history.clear()

func can_undo() -> bool:
    return state_history.size() > 0

func undo() -> bool:
    if not can_undo():
        return false
        
    var previous_state = state_history.pop_back()
    var old_state = current_state.duplicate()
    current_state = previous_state
    state_changed.emit(old_state, current_state)
    state_updated.emit(current_state)
    return true 