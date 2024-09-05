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
	BOT
}

var type: StrangeCharacterType
var special_abilities: Array[String] = []

func _init(_type: StrangeCharacterType = StrangeCharacterType.ALIEN):
	type = _type
	_set_special_abilities()

func _set_special_abilities() -> void:
	match type:
		StrangeCharacterType.DE_CONVERTED:
			special_abilities = ["6+ Armor Save", "Up to 3 implants", "Savvy score can never be improved"]
		StrangeCharacterType.UNITY_AGENT:
			special_abilities = ["Call in a Favor"]
		# ... (rest of the match statement)
		StrangeCharacterType.BOT:
			special_abilities = ["Internet Connection"]

func apply_special_abilities(character: Character) -> void:
	for ability in special_abilities:
		character.add_ability(ability)

	# Additional specific actions for certain types
	match type:
		StrangeCharacterType.ALIEN:
			character.add_ability("Telepathy")
		StrangeCharacterType.ROBOT:
			character.add_ability("Integrated Weaponry")
		StrangeCharacterType.GHOST:
			character.add_ability("Intangibility")
		StrangeCharacterType.SHAPESHIFTER:
			character.add_ability("Shapechange")

func get_description() -> String:
	var description = "Strange Character Type: " + StrangeCharacterType.keys()[type] + "\n"
	description += "Special Abilities:\n"
	for ability in special_abilities:
		description += "- " + ability + "\n"
	return description

func serialize() -> Dictionary:
	return {
		"type": StrangeCharacterType.keys()[type],
		"special_abilities": special_abilities
	}

static func deserialize(data: Dictionary) -> StrangeCharacters:
	var strange_character = StrangeCharacters.new(StrangeCharacterType[data["type"]])
	strange_character.special_abilities = data["special_abilities"]
	return strange_character
