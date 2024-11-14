class_name RumorManager
extends Node

signal rumor_discovered(rumor: Dictionary)
signal rumor_verified(rumor: Dictionary)

const MAX_ACTIVE_RUMORS := 5
const VERIFICATION_COST := 100

var game_state: GameState
var active_rumors: Array[Dictionary] = []
var verified_rumors: Array[Dictionary] = []

func _init(_game_state: GameState) -> void:
    if not _game_state:
        push_error("GameState is required for RumorManager")
        return
    game_state = _game_state

func add_rumor(rumor_data: Dictionary) -> bool:
    if not validate_rumor_data(rumor_data):
        push_error("Invalid rumor data")
        return false
        
    if active_rumors.size() >= MAX_ACTIVE_RUMORS:
        active_rumors.pop_front()  # Remove oldest rumor
        
    active_rumors.append(rumor_data)
    rumor_discovered.emit(rumor_data)
    return true

func verify_rumor(rumor_index: int) -> bool:
    if rumor_index < 0 or rumor_index >= active_rumors.size():
        push_error("Invalid rumor index")
        return false
        
    if game_state.credits < VERIFICATION_COST:
        push_error("Insufficient credits to verify rumor")
        return false
        
    var rumor := active_rumors[rumor_index]
    game_state.credits -= VERIFICATION_COST
    verified_rumors.append(rumor)
    active_rumors.remove_at(rumor_index)
    rumor_verified.emit(rumor)
    return true

func validate_rumor_data(data: Dictionary) -> bool:
    return data.has_all(["type", "location", "description", "value"]) 