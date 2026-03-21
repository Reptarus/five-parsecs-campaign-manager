@tool
extends Node

# This file should be referenced via preload
# Use explicit preloads instead of global class names
## Five Parsecs Character Classes
## Legacy values (0-14) preserved for save compatibility
## Book classes (Core Rules p.27) appended starting at 15
enum CharacterClass {
	NONE, # 0
	SOLDIER, # 1
	MEDIC, # 2 (legacy)
	ROGUE, # 3 (legacy)
	PSIONICIST, # 4 (legacy)
	TECH, # 5 (legacy)
	BRUTE, # 6 (legacy)
	GUNSLINGER, # 7 (legacy)
	ACADEMIC, # 8 (legacy)
	PILOT, # 9 (legacy)
	ENGINEER, # 10 (legacy)
	MERCHANT, # 11 (legacy)
	SECURITY, # 12 (legacy)
	BROKER, # 13 (legacy)
	BOT_TECH, # 14 (legacy)
	# Book classes (Core Rules p.27)
	WORKING_CLASS, # 15
	TECHNICIAN, # 16
	SCIENTIST, # 17
	HACKER, # 18
	MERCENARY, # 19
	AGITATOR, # 20
	PRIMITIVE, # 21
	ARTIST, # 22
	NEGOTIATOR, # 23
	TRADER, # 24
	STARSHIP_CREW, # 25
	PETTY_CRIMINAL, # 26
	GANGER, # 27
	SCOUNDREL, # 28
	ENFORCER, # 29
	SPECIAL_AGENT, # 30
	TROUBLESHOOTER, # 31
	BOUNTY_HUNTER, # 32
	NOMAD, # 33
	EXPLORER, # 34
	PUNK, # 35
	SCAVENGER, # 36
}

## Character Status Types for Five Parsecs
enum CharacterStatus {
	NONE,
	HEALTHY,
	INJURED,
	SERIOUSLY_INJURED,
	CRITICALLY_INJURED,
	INCAPACITATED,
	STUNNED,
	SUPPRESSED,
	DEAD,
	CAPTURED,
	MISSING
}

## Ship Types for Five Parsecs
enum ShipType {
	NONE,
	SHUTTLE,
	LIGHT_FREIGHTER,
	MEDIUM_FREIGHTER,
	HEAVY_FREIGHTER,
	CORVETTE,
	PATROL_SHIP,
	EXPLORER,
	LUXURY_YACHT
}

## Campaign Types for Five Parsecs
enum CampaignType {
	NONE,
	STANDARD,
	FREELANCER,
	MERCENARY,
	EXPLORER,
	TRADER,
	BOUNTY_HUNTER,
	CUSTOM,
	TUTORIAL,
	STORY,
	SANDBOX
}

## Convert between Five Parsecs enums and global enums
static func get_character_class_name(class_type: int) -> String:
	return CharacterClass.keys()[class_type]

static func get_character_status_name(status_type: int) -> String:
	return CharacterStatus.keys()[status_type]

static func get_ship_type_name(ship_type: int) -> String:
	return ShipType.keys()[ship_type]

static func get_campaign_type_name(campaign_type: int) -> String:
	return CampaignType.keys()[campaign_type]

## Human-readable names for Character Classes
const CHARACTER_CLASS_NAMES = {
	CharacterClass.NONE: "None",
	CharacterClass.SOLDIER: "Soldier",
	CharacterClass.MEDIC: "Medic",
	CharacterClass.ROGUE: "Rogue",
	CharacterClass.PSIONICIST: "Psionicist",
	CharacterClass.TECH: "Tech",
	CharacterClass.BRUTE: "Brute",
	CharacterClass.GUNSLINGER: "Gunslinger",
	CharacterClass.ACADEMIC: "Academic",
	CharacterClass.PILOT: "Pilot",
	CharacterClass.ENGINEER: "Engineer",
	CharacterClass.MERCHANT: "Merchant",
	CharacterClass.SECURITY: "Security",
	CharacterClass.BROKER: "Broker",
	CharacterClass.BOT_TECH: "Bot Tech",
	# Book classes (Core Rules p.27)
	CharacterClass.WORKING_CLASS: "Working Class",
	CharacterClass.TECHNICIAN: "Technician",
	CharacterClass.SCIENTIST: "Scientist",
	CharacterClass.HACKER: "Hacker",
	CharacterClass.MERCENARY: "Mercenary",
	CharacterClass.AGITATOR: "Agitator",
	CharacterClass.PRIMITIVE: "Primitive",
	CharacterClass.ARTIST: "Artist",
	CharacterClass.NEGOTIATOR: "Negotiator",
	CharacterClass.TRADER: "Trader",
	CharacterClass.STARSHIP_CREW: "Starship Crew",
	CharacterClass.PETTY_CRIMINAL: "Petty Criminal",
	CharacterClass.GANGER: "Ganger",
	CharacterClass.SCOUNDREL: "Scoundrel",
	CharacterClass.ENFORCER: "Enforcer",
	CharacterClass.SPECIAL_AGENT: "Special Agent",
	CharacterClass.TROUBLESHOOTER: "Troubleshooter",
	CharacterClass.BOUNTY_HUNTER: "Bounty Hunter",
	CharacterClass.NOMAD: "Nomad",
	CharacterClass.EXPLORER: "Explorer",
	CharacterClass.PUNK: "Punk",
	CharacterClass.SCAVENGER: "Scavenger",
}

## Human-readable names for Character Status
const CHARACTER_STATUS_NAMES = {
	CharacterStatus.NONE: "None",
	CharacterStatus.HEALTHY: "Healthy",
	CharacterStatus.INJURED: "Injured",
	CharacterStatus.SERIOUSLY_INJURED: "Seriously Injured",
	CharacterStatus.CRITICALLY_INJURED: "Critically Injured",
	CharacterStatus.INCAPACITATED: "Incapacitated",
	CharacterStatus.STUNNED: "Stunned",
	CharacterStatus.SUPPRESSED: "Suppressed",
	CharacterStatus.DEAD: "Dead",
	CharacterStatus.CAPTURED: "Captured",
	CharacterStatus.MISSING: "Missing"
}

## Human-readable names for Ship Types
const SHIP_TYPE_NAMES = {
	ShipType.NONE: "None",
	ShipType.SHUTTLE: "Shuttle",
	ShipType.LIGHT_FREIGHTER: "Light Freighter",
	ShipType.MEDIUM_FREIGHTER: "Medium Freighter",
	ShipType.HEAVY_FREIGHTER: "Heavy Freighter",
	ShipType.CORVETTE: "Corvette",
	ShipType.PATROL_SHIP: "Patrol Ship",
	ShipType.EXPLORER: "Explorer",
	ShipType.LUXURY_YACHT: "Luxury Yacht"
}

## Human-readable names for Campaign Types
const CAMPAIGN_TYPE_NAMES = {
	CampaignType.NONE: "None",
	CampaignType.STANDARD: "Standard",
	CampaignType.FREELANCER: "Freelancer",
	CampaignType.MERCENARY: "Mercenary",
	CampaignType.EXPLORER: "Explorer",
	CampaignType.TRADER: "Trader",
	CampaignType.BOUNTY_HUNTER: "Bounty Hunter",
	CampaignType.CUSTOM: "Custom",
	CampaignType.TUTORIAL: "Tutorial",
	CampaignType.STORY: "Story",
	CampaignType.SANDBOX: "Sandbox"
}