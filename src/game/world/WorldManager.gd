@tool
extends "res://src/base/world/base_world_system.gd"

const GameEnums = preload("res://src/core/systems/GlobalEnums.gd")
const FiveParsecsPlanet = preload("res://src/game/world/Planet.gd")
const FiveParsecsLocation = preload("res://src/game/world/Location.gd")
const FiveParsecsGameState = preload("res://src/core/state/GameState.gd")

var game_state: FiveParsecsGameState

func setup(state: FiveParsecsGameState) -> void:
    game_state = state