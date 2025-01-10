# StrangeCharacters.gd

class_name StrangeCharacters
extends Resource

const GameEnums = preload("res://src/core/systems/GlobalEnums.gd")

var type: GameEnums.StrangeCharacterType
var special_abilities: Array[String] = []
var saving_throw: int = 0

var game_state_manager: GameStateManager

func _init(_type: GameEnums.StrangeCharacterType = GameEnums.StrangeCharacterType.ALIEN):
	type = _type
	_set_special_abilities()

func _set_special_abilities() -> void:
	match type:
		GameEnums.StrangeCharacterType.DE_CONVERTED:
			special_abilities = ["6+ Armor Save", "Up to 3 implants", "Savvy score can never be improved"]
			saving_throw = 6
		GameEnums.StrangeCharacterType.UNITY_AGENT:
				special_abilities = ["Call in a Favor"]
		GameEnums.StrangeCharacterType.BOT:
			special_abilities = ["Internet Connection", "Data Processing"]
			saving_throw = 6
		GameEnums.StrangeCharacterType.ASSAULT_BOT:
			special_abilities = ["Heavy Armor", "Integrated Weapons"]
			saving_throw = 5
		GameEnums.StrangeCharacterType.PRECURSOR:
			special_abilities = ["Ancient Knowledge", "Extended Lifespan"]
		GameEnums.StrangeCharacterType.FERAL:
			special_abilities = ["Enhanced Senses", "Natural Weapons"]

func apply_special_abilities(character: Character) -> void:
	for ability in special_abilities:
		character.traits.append(ability)

	match type:
		GameEnums.StrangeCharacterType.BOT, GameEnums.StrangeCharacterType.ASSAULT_BOT, GameEnums.StrangeCharacterType.DE_CONVERTED:
			character.toughness = saving_throw
		GameEnums.StrangeCharacterType.PRECURSOR:
			character.has_extra_character_event_roll = true
		GameEnums.StrangeCharacterType.FERAL:
			character.combat_skill = 1
			character.toughness = 3

func apply_feral_characteristics(character: Character) -> void:
	if type == GameEnums.StrangeCharacterType.FERAL:
			character.reactions = 1
			character.speed = 4
			character.combat_skill = 1
			character.toughness = 3
			character.savvy = 1
