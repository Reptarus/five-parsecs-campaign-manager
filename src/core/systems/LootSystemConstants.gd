class_name LootSystemConstants
## Loot System Constants for Five Parsecs Campaign Manager
## Transferred from test helpers to production code
## Based on Five Parsecs Core Rulebook p.66-72 (Loot and Battlefield Finds Tables)
##
## Usage: Reference these constants in post-battle loot generation
## Architecture: Pure constants class - no state, no dependencies

## Loot categories for main tables
enum LootCategory {
	WEAPON,
	DAMAGED_WEAPONS,
	DAMAGED_GEAR,
	GEAR,
	ODDS_AND_ENDS,
	REWARDS,
	# Battlefield-specific
	CONSUMABLE,
	QUEST_RUMOR,
	SHIP_PART,
	TRINKET,
	DEBRIS,
	VITAL_INFO,
	NOTHING
}

## ==========================================
## BATTLEFIELD FINDS TABLE (Five Parsecs p.66)
## ==========================================

const BATTLEFIELD_FINDS_RANGES: Dictionary = {
	LootCategory.WEAPON: {"min": 1, "max": 15, "description": "Random weapon from slain enemy"},
	LootCategory.CONSUMABLE: {"min": 16, "max": 25, "description": "Usable goods (consumable item)"},
	LootCategory.QUEST_RUMOR: {"min": 26, "max": 35, "description": "Curious data stick", "quest_rumor": true},
	LootCategory.SHIP_PART: {"min": 36, "max": 45, "description": "Starship part", "credits": 2},
	LootCategory.TRINKET: {"min": 46, "max": 60, "description": "Personal trinket (possible future loot roll)"},
	LootCategory.DEBRIS: {"min": 61, "max": 75, "description": "Debris (1D3 credits)", "dice": "1d3"},
	LootCategory.VITAL_INFO: {"min": 76, "max": 90, "description": "Vital info (Corporate Patron opportunity)"},
	LootCategory.NOTHING: {"min": 91, "max": 100, "description": "Nothing of value"}
}

## ==========================================
## MAIN LOOT TABLE (Five Parsecs p.70-72)
## ==========================================

const MAIN_LOOT_RANGES: Dictionary = {
	LootCategory.WEAPON: {"min": 1, "max": 25, "description": "Single weapon (roll weapon subtable)"},
	LootCategory.DAMAGED_WEAPONS: {"min": 26, "max": 35, "description": "2 damaged weapons (need repair)", "requires_repair": true, "count": 2},
	LootCategory.DAMAGED_GEAR: {"min": 36, "max": 45, "description": "2 damaged gear items (need repair)", "requires_repair": true, "count": 2},
	LootCategory.GEAR: {"min": 46, "max": 65, "description": "Single gear item (roll gear subtable)"},
	LootCategory.ODDS_AND_ENDS: {"min": 66, "max": 80, "description": "Odds and ends item (roll subtable)"},
	LootCategory.REWARDS: {"min": 81, "max": 100, "description": "Rewards (roll rewards subtable)"}
}

## ==========================================
## WEAPON SUBTABLE (D100)
## ==========================================

const WEAPON_SUBTABLE_RANGES: Dictionary = {
	"basic_weapons": {"min": 1, "max": 35, "items": ["Hand Gun", "Military Rifle", "Shotgun", "Auto Rifle"]},
	"energy_weapons": {"min": 36, "max": 50, "items": ["Hand Laser", "Infantry Laser", "Blast Rifle"]},
	"plasma_weapons": {"min": 51, "max": 65, "items": ["Plasma Rifle", "Fury Rifle", "Needle Rifle"]},
	"melee_weapons": {"min": 66, "max": 85, "items": ["Blade", "Ripper Sword", "Boarding Saber"]},
	"grenades": {"min": 86, "max": 100, "items": ["3 Frakk Grenades", "2 Dazzle Grenades", "2 Shock Grenades"]}
}

## ==========================================
## GEAR SUBTABLE (D100)
## ==========================================

const GEAR_SUBTABLE_RANGES: Dictionary = {
	"gun_mods": {"min": 1, "max": 20, "items": ["Assault Blade", "Bipod", "Stabilizer", "Laser Sight", "Heavy Duty Magazine"]},
	"gun_sights": {"min": 21, "max": 40, "items": ["Laser Sight", "Quality Sight", "Seeker Sight", "Night Sight"]},
	"protective_items": {"min": 41, "max": 75, "items": ["Combat Armor", "Frag Vest", "Flak Screen", "Deflector Field", "Shield Generator"]},
	"utility_items": {"min": 76, "max": 100, "items": ["Motion Tracker", "Jump Belt", "Battle Visor", "Scanner Bot", "Communicator", "Grapple Launcher"]}
}

## ==========================================
## ODDS AND ENDS SUBTABLE (D100)
## ==========================================

const ODDS_AND_ENDS_RANGES: Dictionary = {
	"consumables": {"min": 1, "max": 55, "items": ["Booster Pills", "Combat Serum", "Stim-pack", "Rage Out", "Still"], "uses": 2},
	"implants": {"min": 56, "max": 70, "items": ["Boosted Arm", "Boosted Leg", "Health Boost", "Night Sight", "Pain Suppressor", "Neural Optimization"]},
	"ship_items": {"min": 71, "max": 100, "items": ["Med-patch", "Spare Parts", "Repair Bot", "Nano-doc", "Colonist Ration Packs", "Fuel Cell"]}
}

## ==========================================
## REWARDS SUBTABLE (D100)
## ==========================================

const REWARDS_SUBTABLE_RANGES: Dictionary = {
	"documents": {"min": 1, "max": 10, "item": "Documents", "rumors": 1, "credits": 0},
	"data_files": {"min": 11, "max": 20, "item": "Data Files", "rumors": 2, "credits": 0},
	"scrap": {"min": 21, "max": 25, "item": "Scrap", "credits": 3, "rumors": 0},
	"cargo_crate": {"min": 26, "max": 40, "item": "Cargo Crate", "credits_dice": "1d6", "rumors": 0},
	"valuable_materials": {"min": 41, "max": 55, "item": "Valuable Materials", "credits_dice": "1d6+2", "rumors": 0},
	"rare_substance": {"min": 56, "max": 70, "item": "Rare Substance", "credits_dice": "2d6_pick_highest", "rumors": 0},
	"ship_parts": {"min": 71, "max": 85, "item": "Ship Parts", "discount_dice": "1d6", "rumors": 0},
	"military_ship_part": {"min": 86, "max": 90, "item": "Military Ship Part", "discount_dice": "1d6+2", "rumors": 0},
	"mysterious_items": {"min": 91, "max": 95, "item": "Mysterious Items", "story_points": 2, "rumors": 0},
	"personal_item": {"min": 96, "max": 100, "item": "Personal Item", "story_points": 3, "rumors": 0}
}

## ==========================================
## HELPER FUNCTIONS
## ==========================================

## Get battlefield finds category from D100 roll
static func get_battlefield_finds_category(roll: int) -> LootCategory:
	"""Determine loot category from battlefield finds table

	Args:
		roll: D100 result (1-100)

	Returns:
		LootCategory enum value
	"""
	for category in BATTLEFIELD_FINDS_RANGES.keys():
		var range_data: Dictionary = BATTLEFIELD_FINDS_RANGES[category]
		if roll >= range_data.min and roll <= range_data.max:
			return category

	return LootCategory.NOTHING

## Get main loot category from D100 roll
static func get_main_loot_category(roll: int) -> LootCategory:
	"""Determine loot category from main loot table

	Args:
		roll: D100 result (1-100)

	Returns:
		LootCategory enum value
	"""
	for category in MAIN_LOOT_RANGES.keys():
		var range_data: Dictionary = MAIN_LOOT_RANGES[category]
		if roll >= range_data.min and roll <= range_data.max:
			return category

	return LootCategory.NOTHING

## Get weapon from weapon subtable
static func get_weapon_from_subtable(roll: int) -> String:
	"""Get random weapon from weapon subtable

	Args:
		roll: D100 result (1-100)

	Returns:
		Weapon name string
	"""
	for category in WEAPON_SUBTABLE_RANGES.keys():
		var range_data: Dictionary = WEAPON_SUBTABLE_RANGES[category]
		if roll >= range_data.min and roll <= range_data.max:
			var items: Array = range_data.items
			return items[randi() % items.size()] if items.size() > 0 else "Unknown Weapon"

	return "Unknown Weapon"

## Get gear from gear subtable
static func get_gear_from_subtable(roll: int) -> String:
	"""Get random gear item from gear subtable

	Args:
		roll: D100 result (1-100)

	Returns:
		Gear item name string
	"""
	for category in GEAR_SUBTABLE_RANGES.keys():
		var range_data: Dictionary = GEAR_SUBTABLE_RANGES[category]
		if roll >= range_data.min and roll <= range_data.max:
			var items: Array = range_data.items
			return items[randi() % items.size()] if items.size() > 0 else "Unknown Gear"

	return "Unknown Gear"

## Get odds and ends item from subtable
static func get_odds_and_ends_from_subtable(roll: int) -> Dictionary:
	"""Get random odds and ends item from subtable

	Args:
		roll: D100 result (1-100)

	Returns:
		Dictionary with item name and uses (if consumable)
	"""
	for category in ODDS_AND_ENDS_RANGES.keys():
		var range_data: Dictionary = ODDS_AND_ENDS_RANGES[category]
		if roll >= range_data.min and roll <= range_data.max:
			var items: Array = range_data.items
			var item_name: String = items[randi() % items.size()] if items.size() > 0 else "Unknown Item"
			var uses: int = range_data.get("uses", 0)

			return {
				"item": item_name,
				"uses": uses,
				"category": category
			}

	return {"item": "Unknown Item", "uses": 0, "category": "unknown"}

## Get reward from rewards subtable
static func get_reward_from_subtable(roll: int) -> Dictionary:
	"""Get reward details from rewards subtable

	Args:
		roll: D100 result (1-100)

	Returns:
		Dictionary with item, credits_dice, rumors, story_points
	"""
	for category in REWARDS_SUBTABLE_RANGES.keys():
		var range_data: Dictionary = REWARDS_SUBTABLE_RANGES[category]
		if roll >= range_data.min and roll <= range_data.max:
			return {
				"item": range_data.get("item", "Unknown Reward"),
				"credits": range_data.get("credits", 0),
				"credits_dice": range_data.get("credits_dice", ""),
				"discount_dice": range_data.get("discount_dice", ""),
				"rumors": range_data.get("rumors", 0),
				"story_points": range_data.get("story_points", 0),
				"category": category
			}

	return {
		"item": "Unknown Reward",
		"credits": 0,
		"credits_dice": "",
		"discount_dice": "",
		"rumors": 0,
		"story_points": 0,
		"category": "unknown"
	}
