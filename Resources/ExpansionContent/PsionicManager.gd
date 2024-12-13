class_name PsionicManager
extends Node

@export var game_state: GameState
var psionic_characters: Dictionary = {}  # Character: Dictionary(ability, power_level)

const GameEnums = preload("res://Resources/Core/Systems/GlobalEnums.gd")
const POWER_THRESHOLD := 10
const POWER_INCREASE_CHANCE := 0.2
const POWER_DECREASE_CHANCE := 0.1

signal psionic_ability_used(character: Character, ability: int)  # GameEnums.PsionicAbility
signal psionic_power_changed(character: Character, new_power: int)

func _init(_game_state: GameState) -> void:
    if not _game_state:
        push_error("GameState is required for PsionicManager")
        return
    game_state = _game_state

func update_psionic_ability(character: Character, new_ability: int) -> void:  # GameEnums.PsionicAbility
    if not character:
        push_error("Character is required for psionic ability update")
        return
        
    if not psionic_characters.has(character):
        psionic_characters[character] = {"ability": new_ability, "power_level": 0}
    else:
        psionic_characters[character].ability = new_ability
        
    psionic_ability_used.emit(character, new_ability)