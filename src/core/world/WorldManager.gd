class_name WorldManager
extends Node

const FiveParsecsGameState = preload("res://src/core/state/GameState.gd")

var game_state: FiveParsecsGameState

func setup(state: FiveParsecsGameState) -> void:
    game_state = state