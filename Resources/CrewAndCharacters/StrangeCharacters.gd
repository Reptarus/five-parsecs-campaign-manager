# StrangeCharacters.gd

class_name StrangeCharacters
extends Resource

enum StrangeCharacterType {
	DE_CONVERTED,
	UNITY_AGENT,
	MYSTERIOUS_PAST,
	HAKSHAN,
	STALKER,
	HULKER,
	HOPEFUL_ROOKIE,
	GENETIC_UPLIFT,
	MUTANT,
	ASSAULT_BOT,
	MANIPULATOR,
	PRIMITIVE,
	FEELER,
	EMO_SUPPRESSED,
	MINOR_ALIEN,
	TRAVELER,
	EMPATH,
	BIO_UPGRADE,
	ALIEN,
	ROBOT,
	GHOST,
	SHAPESHIFTER,
	BOT,
	PRECURSOR,
	FERAL
}

var type: StrangeCharacterType
var special_abilities: Array[String] = []
var saving_throw: int = 0

var game_state_manager: GameStateManager

func _init(_type: StrangeCharacterType = StrangeCharacterType.ALIEN):
	type = _type
	_set_special_abilities()

func _set_special_abilities() -> void:
	match type:
		StrangeCharacterType.DE_CONVERTED:
			special_abilities = ["6+ Armor Save", "Up to 3 implants", "Savvy score can never be improved"]
			saving_throw = 6
		StrangeCharacterType.UNITY_AGENT:
				special_abilities = ["Call in a Favor"]
		StrangeCharacterType.BOT:
			special_abilities = ["Internet Connection", "Data Processing"]
			saving_throw = 6
		StrangeCharacterType.ASSAULT_BOT:
			special_abilities = ["Heavy Armor", "Integrated Weapons"]
			saving_throw = 5
		StrangeCharacterType.PRECURSOR:
			special_abilities = ["Ancient Knowledge", "Extended Lifespan"]
		StrangeCharacterType.FERAL:
			special_abilities = ["Enhanced Senses", "Natural Weapons"]

func apply_special_abilities(character: Character) -> void:
	for ability in special_abilities:
		character.traits.append(ability)

	match type:
		StrangeCharacterType.BOT, StrangeCharacterType.ASSAULT_BOT, StrangeCharacterType.DE_CONVERTED:
			character.toughness = saving_throw
		StrangeCharacterType.PRECURSOR:
			character.has_extra_character_event_roll = true
		StrangeCharacterType.FERAL:
			character.combat_skill = 1
			character.toughness = 3

func apply_feral_characteristics(character: Character) -> void:
	if type == StrangeCharacterType.FERAL:
			character.reactions = 1
			character.speed = 4
			character.combat_skill = 1
			character.toughness = 3
			character.savvy = 1
