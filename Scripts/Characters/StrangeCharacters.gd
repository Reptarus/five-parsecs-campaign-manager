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
	game_state_manager = GameStateManager

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

func apply_special_abilities(character: Character) -> void:
	for ability in special_abilities:
		character.traits.append(ability)

	match type:
		StrangeCharacterType.BOT, StrangeCharacterType.ASSAULT_BOT, StrangeCharacterType.DE_CONVERTED:
			character.toughness = saving_throw
		StrangeCharacterType.PRECURSOR:
			# Assuming this is a boolean property in the Character class
			character.has_extra_character_event_roll = true
		StrangeCharacterType.FERAL:
			character.combat_skill = 1
			character.toughness = 3

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
	return game_state_manager.combat_manager.roll_dice(num_dice, sides)

func handle_precursor_character_event(character: Character) -> void:
	if type == StrangeCharacterType.PRECURSOR:
		var event1 = roll_dice(1, 100)
		var event2 = roll_dice(1, 100)
		# Logic to handle character event choice
		# This should be implemented using the game's character event system
		game_state_manager.story_track.add_event("Precursor Character Event", 
			"Precursor can choose between event " + str(event1) + " and event " + str(event2))

func apply_feral_characteristics(character: Character) -> void:
	if type == StrangeCharacterType.FERAL:
		character.reactions = 1
		character.speed = 4
		character.combat_skill = 1
		character.toughness = 3
		character.savvy = 1
