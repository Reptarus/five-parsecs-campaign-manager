class_name GameStateManagerNode
extends Node

var game_state: GameStateManager

func _ready() -> void:
    game_state = GameStateManager.new()

func get_game_state() -> GameStateManager:
    return game_state
