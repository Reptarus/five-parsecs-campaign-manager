@tool
extends Node

const GameEnums = preload("res://src/core/systems/GlobalEnums.gd")

## Five Parsecs Character Classes
enum CharacterClass {
	NONE,
	SOLDIER,
	MEDIC,
	ROGUE,
	PSIONICIST,
	TECH,
	BRUTE,
	GUNSLINGER,
	ACADEMIC,
	PILOT,
	ENGINEER,
	MERCHANT,
	SECURITY,
	BROKER,
	BOT_TECH
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
	CharacterClass.BOT_TECH: "Bot Tech"
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