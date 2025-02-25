@tool
extends Node

const FiveParsecsGameState = preload("res://src/core/state/GameState.gd")

signal faction_relation_changed(faction_id: String, new_standing: float)
signal faction_event_occurred(event: Dictionary)

var game_state: FiveParsecsGameState
var faction_standings: Dictionary = {}

func _init() -> void:
    pass

func setup(state: FiveParsecsGameState) -> void:
    game_state = state

func process_faction_events() -> void:
    # Process faction events and relationships
    pass

func update_faction_standings() -> void:
    # Update faction standings based on recent actions
    pass

func get_faction_standing(faction_id: String) -> float:
    return faction_standings.get(faction_id, 0.0)

func modify_faction_standing(faction_id: String, amount: float) -> void:
    var current = get_faction_standing(faction_id)
    faction_standings[faction_id] = clamp(current + amount, -100.0, 100.0)
    faction_relation_changed.emit(faction_id, faction_standings[faction_id])