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

func apply_special_abilities(character: Character):
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
			character.add_ability("Telepathy")
		StrangeCharacterType.ROBOT:
			character.add_ability("Integrated Weaponry")
		StrangeCharacterType.GHOST:
			character.add_ability("Intangibility")
		StrangeCharacterType.SHAPESHIFTER:
			character.add_ability("Shapechange")
		StrangeCharacterType.BOT:
			character.add_ability("Internet Connection")


func get_description() -> String:
	var description = "Strange Character Type: " + StrangeCharacterType.keys()[type] + "\n"
	description += "Special Abilities:\n"
	for ability in special_abilities:
		description += "- " + ability + "\n"
	return description
