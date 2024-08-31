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

func _init():
	pass

func initialize(new_type: StrangeCharacterType) -> void:
	type = new_type
	_generate_special_abilities()

func _generate_special_abilities() -> void:
	special_abilities.clear()
	match type:
		StrangeCharacterType.DE_CONVERTED:
			special_abilities = ["6+ Armor Save", "Up to 3 implants", "Savvy score can never be improved"]
		StrangeCharacterType.UNITY_AGENT:
			special_abilities = ["Call in a Favor"]
		StrangeCharacterType.MYSTERIOUS_PAST:
			special_abilities = ["Double Background roll", "No bonus story points from rolls"]
		StrangeCharacterType.HAKSHAN:
			special_abilities = ["Truth motivation"]
		StrangeCharacterType.STALKER:
			special_abilities = ["Teleportation"]
		StrangeCharacterType.HULKER:
			special_abilities = ["Ignore Clumsy and Heavy traits", "Shooting always at +0 Combat Skill"]
		StrangeCharacterType.HOPEFUL_ROOKIE:
			special_abilities = ["Bonus XP", "Lose Luck permanently on first casualty"]
		StrangeCharacterType.GENETIC_UPLIFT:
			special_abilities = ["Enhanced base stats", "Additional Rival"]
		StrangeCharacterType.MUTANT:
			special_abilities = ["Cannot be sent for Recruit or Find a Patron tasks"]
		StrangeCharacterType.ASSAULT_BOT:
			special_abilities = ["5+ Armor Save", "Ignore Clumsy and Heavy traits"]
		StrangeCharacterType.MANIPULATOR:
			special_abilities = ["Dual Pistol use", "Bonus story point chance"]
		StrangeCharacterType.PRIMITIVE:
			special_abilities = ["Limited gun use", "All Melee weapons count as Elegant"]
		StrangeCharacterType.FEELER:
			special_abilities = ["Double Motivation roll", "Risk of mental breakdown"]
		StrangeCharacterType.EMO_SUPPRESSED:
			special_abilities = ["Never leaves crew voluntarily", "Can ignore certain events", "No Luck points"]
		StrangeCharacterType.MINOR_ALIEN:
			special_abilities = ["Reduced bonus gains", "Discounted ability score increase"]
		StrangeCharacterType.TRAVELER:
			special_abilities = ["Initial bonuses", "Chance to disappear", "Faster retreat"]
		StrangeCharacterType.EMPATH:
			special_abilities = ["Bonus to Recruit and Find a Patron tasks"]
		StrangeCharacterType.BIO_UPGRADE:
			special_abilities = ["Can have up to 4 implants", "Reduced bonus credits"]
		StrangeCharacterType.ALIEN:
			special_abilities = ["Telepathy"]
		StrangeCharacterType.ROBOT:
			special_abilities = ["Integrated Weaponry"]
		StrangeCharacterType.GHOST:
			special_abilities = ["Intangibility"]
		StrangeCharacterType.SHAPESHIFTER:
			special_abilities = ["Shapechange"]
		StrangeCharacterType.BOT:
			special_abilities = ["Internet Connection"]

func apply_special_abilities(character: Character) -> void:
	for ability in special_abilities:
		character.add_ability(ability)
	
	match type:
		StrangeCharacterType.DE_CONVERTED:
			character.savvy = min(character.savvy, 5)  # Ensure Savvy can't be improved beyond 5
		StrangeCharacterType.GENETIC_UPLIFT:
			character.speed += 1
			character.combat_skill += 1
		StrangeCharacterType.HULKER:
			character.toughness += 1
		StrangeCharacterType.HOPEFUL_ROOKIE:
			character.xp += 2  # Start with bonus XP
		# Add more specific stat modifications for other types as needed

func get_description() -> String:
	var description = "Strange Character Type: " + StrangeCharacterType.keys()[type] + "\n"
	description += "Special Abilities:\n"
	for ability in special_abilities:
		description += "- " + ability + "\n"
	return description

func to_dict() -> Dictionary:
	return {
		"type": StrangeCharacterType.keys()[type],
		"special_abilities": special_abilities
	}

func from_dict(data: Dictionary) -> void:
	type = StrangeCharacterType[data["type"]]
	special_abilities = data["special_abilities"]
