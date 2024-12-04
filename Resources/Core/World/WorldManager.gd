@tool
class_name WorldManager
extends Node

var game_state: GameState

func setup(state: GameState) -> void:
    game_state = state

func process_world_events() -> void:
    # Process world events like strife level changes, resource updates, etc.
    pass

func process_end_of_turn() -> void:
    # Handle end of turn effects for worlds
    pass

func update_world_resources() -> void:
    # Update resource availability and prices
    pass

func handle_world_events() -> void:
    # Handle random world events
    pass 