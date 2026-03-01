class_name InjurySystemConstants
## Injury System Constants for Five Parsecs Campaign Manager
## Transferred from test helpers to production code
## Based on Five Parsecs Core Rulebook p.94-95 (Injury Determination Table)
##
## Usage: Reference these constants in post-battle injury processing
## Architecture: Pure constants class - no state, no dependencies

## Injury type enumeration (matches Five Parsecs rulebook categories)
enum InjuryType {
	FATAL,              # 1-15: Character dies
	MIRACULOUS_ESCAPE,  # 16: No injury
	EQUIPMENT_LOSS,     # 17-30: Equipment damaged/lost
	CRIPPLING_WOUND,    # 31-45: Requires surgery or long recovery
	SERIOUS_INJURY,     # 46-54: Extended recovery time
	MINOR_INJURY,       # 55-80: Short recovery
	KNOCKED_OUT,        # 81-95: Shaken but recovers
	HARD_KNOCKS         # 96-100: Learns from experience (+1 XP)
}

## D100 roll ranges for each injury type (Five Parsecs rulebook p.94)
const INJURY_ROLL_RANGES: Dictionary = {
	InjuryType.FATAL: {"min": 1, "max": 15},
	InjuryType.MIRACULOUS_ESCAPE: {"min": 16, "max": 16},
	InjuryType.EQUIPMENT_LOSS: {"min": 17, "max": 30},
	InjuryType.CRIPPLING_WOUND: {"min": 31, "max": 45},
	InjuryType.SERIOUS_INJURY: {"min": 46, "max": 54},
	InjuryType.MINOR_INJURY: {"min": 55, "max": 80},
	InjuryType.KNOCKED_OUT: {"min": 81, "max": 95},
	InjuryType.HARD_KNOCKS: {"min": 96, "max": 100}
}

## Recovery time ranges for each injury type
## For dice rolls, use min/max to determine D6 or D3+1 rolls
const RECOVERY_TIMES: Dictionary = {
	InjuryType.FATAL: {
		"min": 0, "max": 0,
		"description": "Character is dead - no recovery"
	},
	InjuryType.MIRACULOUS_ESCAPE: {
		"min": 0, "max": 0,
		"description": "No injury sustained"
	},
	InjuryType.EQUIPMENT_LOSS: {
		"min": 0, "max": 0,
		"description": "Equipment damaged/lost, no medical recovery needed"
	},
	InjuryType.CRIPPLING_WOUND: {
		"min": 1, "max": 6,
		"dice": "1d6",
		"description": "1D6 turns OR surgery to instantly recover"
	},
	InjuryType.SERIOUS_INJURY: {
		"min": 2, "max": 4,
		"dice": "1d3+1",
		"description": "1D3+1 turns recovery time"
	},
	InjuryType.MINOR_INJURY: {
		"min": 1, "max": 1,
		"dice": "1",
		"description": "1 turn recovery time"
	},
	InjuryType.KNOCKED_OUT: {
		"min": 0, "max": 0,
		"description": "Shaken but recovers immediately, no sick bay time"
	},
	InjuryType.HARD_KNOCKS: {
		"min": 0, "max": 0,
		"description": "Learns from experience, gains +1 XP, no recovery needed"
	}
}

## Injury type names (short form for service layer)
const INJURY_TYPE_NAMES: Dictionary = {
	InjuryType.FATAL: "FATAL",
	InjuryType.MIRACULOUS_ESCAPE: "MIRACULOUS_ESCAPE",
	InjuryType.EQUIPMENT_LOSS: "EQUIPMENT_LOSS",
	InjuryType.CRIPPLING_WOUND: "CRIPPLING_WOUND",
	InjuryType.SERIOUS_INJURY: "SERIOUS_INJURY",
	InjuryType.MINOR_INJURY: "MINOR_INJURY",
	InjuryType.KNOCKED_OUT: "KNOCKED_OUT",
	InjuryType.HARD_KNOCKS: "HARD_KNOCKS"
}

## Injury descriptions for UI display
const INJURY_DESCRIPTIONS: Dictionary = {
	InjuryType.FATAL: "DEAD - Fatal injury",
	InjuryType.MIRACULOUS_ESCAPE: "Miraculous escape - No injury",
	InjuryType.EQUIPMENT_LOSS: "Equipment damaged/lost",
	InjuryType.CRIPPLING_WOUND: "CRIPPLING WOUND - Requires surgery or long recovery",
	InjuryType.SERIOUS_INJURY: "SERIOUS INJURY - Extended recovery",
	InjuryType.MINOR_INJURY: "MINOR INJURY - Short recovery",
	InjuryType.KNOCKED_OUT: "KNOCKED OUT - Shaken but recovers quickly",
	InjuryType.HARD_KNOCKS: "School of Hard Knocks - Learns from experience"
}

## Special injury properties (surgery, equipment loss, XP bonus)
const INJURY_PROPERTIES: Dictionary = {
	InjuryType.FATAL: {
		"is_fatal": true,
		"requires_surgery": false,
		"equipment_lost": false,
		"bonus_xp": 0
	},
	InjuryType.MIRACULOUS_ESCAPE: {
		"is_fatal": false,
		"requires_surgery": false,
		"equipment_lost": false,
		"bonus_xp": 0
	},
	InjuryType.EQUIPMENT_LOSS: {
		"is_fatal": false,
		"requires_surgery": false,
		"equipment_lost": true,
		"bonus_xp": 0
	},
	InjuryType.CRIPPLING_WOUND: {
		"is_fatal": false,
		"requires_surgery": true,  # Surgery can instantly heal
		"equipment_lost": false,
		"bonus_xp": 0
	},
	InjuryType.SERIOUS_INJURY: {
		"is_fatal": false,
		"requires_surgery": false,
		"equipment_lost": false,
		"bonus_xp": 0
	},
	InjuryType.MINOR_INJURY: {
		"is_fatal": false,
		"requires_surgery": false,
		"equipment_lost": false,
		"bonus_xp": 0
	},
	InjuryType.KNOCKED_OUT: {
		"is_fatal": false,
		"requires_surgery": false,
		"equipment_lost": false,
		"bonus_xp": 0
	},
	InjuryType.HARD_KNOCKS: {
		"is_fatal": false,
		"requires_surgery": false,
		"equipment_lost": false,
		"bonus_xp": 1  # Character gains +1 XP
	}
}

## Helper function: Determine injury type from D100 roll
static func get_injury_type_from_roll(roll: int) -> InjuryType:
	## Determine injury type from D100 roll result
	##
	## Args:
	## 	roll: D100 result (1-100)
	##
	## Returns:
	## 	InjuryType enum value
	for injury_type in INJURY_ROLL_RANGES.keys():
		var range_data: Dictionary = INJURY_ROLL_RANGES[injury_type]
		if roll >= range_data.min and roll <= range_data.max:
			return injury_type
	# Fallback to minor injury if roll is invalid
	return InjuryType.MINOR_INJURY

## Helper function: Get injury description
static func get_injury_description(injury_type: InjuryType) -> String:
	## Get human-readable injury description
	##
	## Args:
	## 	injury_type: InjuryType enum value
	##
	## Returns:
	## 	Human-readable injury description
	return INJURY_DESCRIPTIONS.get(injury_type, "Unknown injury")

## Helper function: Get recovery time for injury
static func get_recovery_time(injury_type: InjuryType) -> Dictionary:
	## Get recovery time information for injury type
	##
	## Args:
	## 	injury_type: InjuryType enum value
	##
	## Returns:
	## 	Dictionary with min, max, dice notation, and description
	return RECOVERY_TIMES.get(injury_type, {
		"min": 0,
		"max": 0,
		"description": "Unknown injury type"
	})

## Helper function: Check if injury is fatal
static func is_fatal_injury(injury_type: InjuryType) -> bool:
	## Check if injury type is fatal
	##
	## Args:
	## 	injury_type: InjuryType enum value
	##
	## Returns:
	## 	True if injury is fatal
	var properties: Dictionary = INJURY_PROPERTIES.get(injury_type, {})
	return properties.get("is_fatal", false)

## Helper function: Check if injury requires surgery
static func requires_surgery(injury_type: InjuryType) -> bool:
	## Check if injury can be instantly healed with surgery
	##
	## Args:
	## 	injury_type: InjuryType enum value
	##
	## Returns:
	## 	True if surgery can instantly heal this injury
	var properties: Dictionary = INJURY_PROPERTIES.get(injury_type, {})
	return properties.get("requires_surgery", false)

## Helper function: Check if injury causes equipment loss
static func causes_equipment_loss(injury_type: InjuryType) -> bool:
	## Check if injury causes equipment to be lost
	##
	## Args:
	## 	injury_type: InjuryType enum value
	##
	## Returns:
	## 	True if equipment is lost
	var properties: Dictionary = INJURY_PROPERTIES.get(injury_type, {})
	return properties.get("equipment_lost", false)

## Helper function: Get bonus XP from injury
static func get_bonus_xp(injury_type: InjuryType) -> int:
	## Get experience points gained from injury (Hard Knocks only)
	##
	## Args:
	## 	injury_type: InjuryType enum value
	##
	## Returns:
	## 	Bonus XP amount (0 for most injuries, 1 for Hard Knocks)
	var properties: Dictionary = INJURY_PROPERTIES.get(injury_type, {})
	return properties.get("bonus_xp", 0)

## Helper function: Alias for is_fatal_injury (service layer compatibility)
static func is_fatal(injury_type: InjuryType) -> bool:
	## Alias for is_fatal_injury for service layer compatibility
	##
	## Args:
	## 	injury_type: InjuryType enum value
	##
	## Returns:
	## 	True if injury is fatal
	return is_fatal_injury(injury_type)

## Helper function: Get base recovery time as int
static func get_base_recovery_turns(injury_type: InjuryType) -> int:
	## Get base recovery time in turns (uses max value from range)
	##
	## Args:
	## 	injury_type: InjuryType enum value
	##
	## Returns:
	## 	Number of turns for recovery (max value from range)
	var recovery_info: Dictionary = get_recovery_time(injury_type)
	return recovery_info.get("max", 0)

## Helper function: Get special effect description
static func get_injury_special_effect(injury_type: InjuryType) -> String:
	## Get special effect description for an injury type
	##
	## Args:
	## 	injury_type: InjuryType enum value
	##
	## Returns:
	## 	Special effect description (empty string if none)
	match injury_type:
		InjuryType.HARD_KNOCKS:
			return "Character gains +1 XP from learning experience"
		InjuryType.CRIPPLING_WOUND:
			return "Can be instantly healed with surgery"
		InjuryType.EQUIPMENT_LOSS:
			return "Random equipment item damaged or destroyed"
		InjuryType.MIRACULOUS_ESCAPE:
			return "No injury sustained despite being knocked out"
		_:
			return ""

# =============================================================================
# BOT / SOULLESS INJURY TABLE (Core Rules p.94-95)
# Robotic characters use a separate, simpler injury table
# =============================================================================

enum BotInjuryType {
	OBLITERATED,       # 1-5: Destroyed + all equipment damaged, no repair possible
	DESTROYED,         # 6-15: Destroyed permanently
	EQUIPMENT_LOSS,    # 16-30: Random carried item damaged
	SEVERE_DAMAGE,     # 31-45: 1D6 repair turns required
	MINOR_DAMAGE,      # 46-65: 1 repair turn required
	JUST_A_FEW_DENTS   # 66-100: Cosmetic only, no repair needed
}

const BOT_INJURY_ROLL_RANGES: Dictionary = {
	BotInjuryType.OBLITERATED: {"min": 1, "max": 5},
	BotInjuryType.DESTROYED: {"min": 6, "max": 15},
	BotInjuryType.EQUIPMENT_LOSS: {"min": 16, "max": 30},
	BotInjuryType.SEVERE_DAMAGE: {"min": 31, "max": 45},
	BotInjuryType.MINOR_DAMAGE: {"min": 46, "max": 65},
	BotInjuryType.JUST_A_FEW_DENTS: {"min": 66, "max": 100}
}

const BOT_RECOVERY_TIMES: Dictionary = {
	BotInjuryType.OBLITERATED: {
		"min": 0, "max": 0,
		"description": "Bot obliterated - all equipment damaged, no repair possible"
	},
	BotInjuryType.DESTROYED: {
		"min": 0, "max": 0,
		"description": "Bot destroyed permanently"
	},
	BotInjuryType.EQUIPMENT_LOSS: {
		"min": 0, "max": 0,
		"description": "Random carried item damaged"
	},
	BotInjuryType.SEVERE_DAMAGE: {
		"min": 1, "max": 6,
		"dice": "1d6",
		"description": "Severe damage, 1D6 repair turns required"
	},
	BotInjuryType.MINOR_DAMAGE: {
		"min": 1, "max": 1,
		"dice": "1",
		"description": "Minor damage, 1 repair turn required"
	},
	BotInjuryType.JUST_A_FEW_DENTS: {
		"min": 0, "max": 0,
		"description": "Just a few dents, no repair needed"
	}
}

const BOT_INJURY_TYPE_NAMES: Dictionary = {
	BotInjuryType.OBLITERATED: "OBLITERATED",
	BotInjuryType.DESTROYED: "DESTROYED",
	BotInjuryType.EQUIPMENT_LOSS: "EQUIPMENT_LOSS",
	BotInjuryType.SEVERE_DAMAGE: "SEVERE_DAMAGE",
	BotInjuryType.MINOR_DAMAGE: "MINOR_DAMAGE",
	BotInjuryType.JUST_A_FEW_DENTS: "JUST_A_FEW_DENTS"
}

const BOT_INJURY_DESCRIPTIONS: Dictionary = {
	BotInjuryType.OBLITERATED: "OBLITERATED - Bot destroyed beyond repair, all equipment damaged",
	BotInjuryType.DESTROYED: "DESTROYED - Bot permanently destroyed",
	BotInjuryType.EQUIPMENT_LOSS: "EQUIPMENT LOSS - Random carried item damaged",
	BotInjuryType.SEVERE_DAMAGE: "SEVERE DAMAGE - Requires 1D6 repair turns",
	BotInjuryType.MINOR_DAMAGE: "MINOR DAMAGE - Requires 1 repair turn",
	BotInjuryType.JUST_A_FEW_DENTS: "JUST A FEW DENTS - No repair needed"
}

const BOT_INJURY_PROPERTIES: Dictionary = {
	BotInjuryType.OBLITERATED: {
		"is_fatal": true,
		"equipment_damaged": true,
		"all_equipment": true
	},
	BotInjuryType.DESTROYED: {
		"is_fatal": true,
		"equipment_damaged": false,
		"all_equipment": false
	},
	BotInjuryType.EQUIPMENT_LOSS: {
		"is_fatal": false,
		"equipment_damaged": true,
		"all_equipment": false
	},
	BotInjuryType.SEVERE_DAMAGE: {
		"is_fatal": false,
		"equipment_damaged": false,
		"all_equipment": false
	},
	BotInjuryType.MINOR_DAMAGE: {
		"is_fatal": false,
		"equipment_damaged": false,
		"all_equipment": false
	},
	BotInjuryType.JUST_A_FEW_DENTS: {
		"is_fatal": false,
		"equipment_damaged": false,
		"all_equipment": false
	}
}

static func get_bot_injury_type_from_roll(roll: int) -> BotInjuryType:
	for injury_type in BOT_INJURY_ROLL_RANGES.keys():
		var range_data: Dictionary = BOT_INJURY_ROLL_RANGES[injury_type]
		if roll >= range_data.min and roll <= range_data.max:
			return injury_type
	return BotInjuryType.JUST_A_FEW_DENTS

static func get_bot_injury_description(injury_type: BotInjuryType) -> String:
	return BOT_INJURY_DESCRIPTIONS.get(injury_type, "Unknown bot injury")

static func get_bot_recovery_time(injury_type: BotInjuryType) -> Dictionary:
	return BOT_RECOVERY_TIMES.get(injury_type, {"min": 0, "max": 0, "description": "Unknown"})

static func is_bot_fatal_injury(injury_type: BotInjuryType) -> bool:
	var properties: Dictionary = BOT_INJURY_PROPERTIES.get(injury_type, {})
	return properties.get("is_fatal", false)

static func bot_causes_equipment_loss(injury_type: BotInjuryType) -> bool:
	var properties: Dictionary = BOT_INJURY_PROPERTIES.get(injury_type, {})
	return properties.get("equipment_damaged", false)
