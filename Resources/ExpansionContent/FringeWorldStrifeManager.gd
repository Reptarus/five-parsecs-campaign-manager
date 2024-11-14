extends Node

signal strife_level_changed(location: Location, new_level: GlobalEnums.FringeWorldInstability)
signal unity_progress_changed(location: Location, new_progress: int)

const UNITY_THRESHOLD := 10
const STRIFE_INCREASE_CHANCE := 0.2
const STRIFE_DECREASE_CHANCE := 0.1

var game_state: GameState
var affected_locations: Dictionary = {}  # Location: Dictionary(strife_level, unity_progress)

func _init(_game_state: GameState) -> void:
    if not _game_state:
        push_error("GameState is required for FringeWorldStrifeManager")
        return
    game_state = _game_state

func update_strife_level(location: Location, new_level: GlobalEnums.FringeWorldInstability) -> void:
    if not location:
        push_error("Location is required for strife level update")
        return
        
    if not affected_locations.has(location):
        affected_locations[location] = {
            "strife_level": new_level, 
            "unity_progress": 0
        }
    else:
        affected_locations[location].strife_level = new_level
        
    strife_level_changed.emit(location, new_level)