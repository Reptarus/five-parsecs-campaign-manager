# StrangeCharacters.gd

class_name StrangeCharacters
extends Resource

const GameEnums = preload("res://src/core/systems/GlobalEnums.gd")
const Character = preload("res://src/core/character/Base/Character.gd")

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

## Safe Property Access Methods
func _get_character_property(character: Character, property: String, default_value = null) -> Variant:
	if not character:
		push_error("Trying to access property '%s' on null character" % property)
		return default_value
	if not property in character:
		return default_value
	return character.get(property)

func _set_character_property(character: Character, property: String, value: Variant) -> void:
	if not character:
		push_error("Trying to set property '%s' on null character" % property)
		return
	if not property in character:
		push_error("Character missing property: %s" % property)
		return
	character.set(property, value)

func apply_special_abilities(character: Character) -> void:
	if not character:
		push_error("Cannot apply special abilities to null character")
		return
		
	for ability in special_abilities:
		if not "traits" in character:
			push_error("Character missing traits array")
			return
		character.traits.append(ability)

	match type:
		GameEnums.StrangeCharacterType.BOT, GameEnums.StrangeCharacterType.ASSAULT_BOT, GameEnums.StrangeCharacterType.DE_CONVERTED:
			_set_character_property(character, "toughness", saving_throw)
		GameEnums.StrangeCharacterType.PRECURSOR:
			_set_character_property(character, "has_extra_character_event_roll", true)
		GameEnums.StrangeCharacterType.FERAL:
			_set_character_property(character, "combat_skill", 1)
			_set_character_property(character, "toughness", 3)

func apply_feral_characteristics(character: Character) -> void:
	if type == GameEnums.StrangeCharacterType.FERAL:
		_set_character_property(character, "reactions", 1)
		_set_character_property(character, "speed", 4)
		_set_character_property(character, "combat_skill", 1)
		_set_character_property(character, "toughness", 3)
		_set_character_property(character, "savvy", 1)
