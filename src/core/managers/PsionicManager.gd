class_name PsionicManager
extends Resource

const GameEnums = preload("res://src/core/systems/GlobalEnums.gd")
const FiveParsecsGameState = preload("res://src/core/state/GameState.gd")
const Character = preload("res://src/core/character/Management/CharacterDataManager.gd")
const SaveManager = preload("res://src/core/state/SaveManager.gd")

@export var game_state: FiveParsecsGameState

signal psionic_power_used(character: Resource, power: String)
signal psionic_power_learned(character: Resource, power: String)
signal psionic_power_failed(character: Resource, power: String, reason: String)

func _init(_game_state: FiveParsecsGameState) -> void:
    game_state = _game_state