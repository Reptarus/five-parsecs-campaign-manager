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
		# Add other types as needed

func apply_special_abilities(character) -> void:
	for ability in special_abilities:
		character.add_ability(ability)

	match type:
		StrangeCharacterType.BOT, StrangeCharacterType.ASSAULT_BOT, StrangeCharacterType.DE_CONVERTED:
			character.set_armor_save(saving_throw)
		StrangeCharacterType.PRECURSOR:
			character.set_extra_character_event_roll(true)
		StrangeCharacterType.FERAL:
			character.set_combat_skill(1)
			character.set_toughness(3)

func get_description() -> String:
	var description = "Strange Character Type: " + StrangeCharacterType.keys()[type] + "\n"
	description += "Special Abilities:\n"
	for ability in special_abilities:
		description += "- " + ability + "\n"
	if saving_throw > 0:
		description += "Armor Save: " + str(saving_throw) + "+\n"
	return description

func serialize() -> Dictionary:
	return {
		"type": StrangeCharacterType.keys()[type],
		"special_abilities": special_abilities,
		"saving_throw": saving_throw
	}

static func deserialize(data: Dictionary) -> StrangeCharacters:
	var strange_character = StrangeCharacters.new(StrangeCharacterType[data["type"]])
	strange_character.special_abilities = data["special_abilities"]
	strange_character.saving_throw = data["saving_throw"]
	return strange_character

func roll_dice(num_dice: int, sides: int) -> int:
	var total := 0
	for i in range(num_dice):
		total += randi() % sides + 1
	return total

func handle_precursor_character_event(character) -> void:
	if type == StrangeCharacterType.PRECURSOR:
		var event1 = roll_dice(1, 100)
		var event2 = roll_dice(1, 100)
		# Logic to handle character event choice
		# This is a placeholder and should be implemented based on your game's character event system
		print("Precursor can choose between event " + str(event1) + " and event " + str(event2))

func apply_feral_characteristics(character) -> void:
	if type == StrangeCharacterType.FERAL:
		character.set_reactions(1)
		character.set_speed(4)
		character.set_combat_skill(1)
		character.set_toughness(3)
		character.set_savvy(1)
