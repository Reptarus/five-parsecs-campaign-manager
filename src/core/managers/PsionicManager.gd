extends Resource

# GlobalEnums available as autoload singleton
const GameState = preload("res://src/core/state/GameState.gd")
const Character = preload("res://src/core/character/Management/CharacterDataManager.gd")
const SaveManager = preload("res://src/core/state/SaveManager.gd")

var game_state: GameState

signal psionic_power_used(character: Resource, power: String)
signal psionic_power_learned(character: Resource, power: String)
signal psionic_power_failed(character: Resource, power: String, reason: String)

func _init(_game_state: GameState) -> void:
	game_state = _game_state