class_name FiveParsecsWorldManager
extends Node

const GameEnums = preload("res://src/core/systems/GlobalEnums.gd")
const FiveParsecsPlanet = preload("res://src/core/world/Planet.gd")
const FiveParsecsLocation = preload("res://src/core/world/Location.gd")
const FiveParsecsGameState = preload("res://src/core/state/GameState.gd")

var game_state: FiveParsecsGameState

func setup(state: FiveParsecsGameState) -> void:
    game_state = state