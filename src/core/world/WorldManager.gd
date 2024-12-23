extends Node

const FiveParsecsGameState = preload("res://src/data/resources/GameState/GameState.gd")

var game_state: FiveParsecsGameState

func setup(state: FiveParsecsGameState) -> void:
    game_state = state 