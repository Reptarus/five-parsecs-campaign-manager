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
## Sprint 19.2: EXPANDED WEAPON CATEGORIES (Core Rules p.131)
## ==========================================

## Individual weapon definitions with stats
const WEAPON_DEFINITIONS: Dictionary = {
	# Basic Weapons (Range 1-35)
	"Hand Gun": {"range": 12, "shots": 1, "damage": 0, "special": "", "category": "pistol"},
	"Military Rifle": {"range": 24, "shots": 1, "damage": 0, "special": "", "category": "rifle"},
	"Shotgun": {"range": 12, "shots": 2, "damage": 1, "special": "FOCUSED", "category": "shotgun"},
	"Auto Rifle": {"range": 24, "shots": 2, "damage": 0, "special": "", "category": "rifle"},
	"Hunting Rifle": {"range": 30, "shots": 1, "damage": 0, "special": "", "category": "rifle"},
	"Scrap Pistol": {"range": 8, "shots": 1, "damage": 0, "special": "UNRELIABLE", "category": "pistol"},
	"Machine Pistol": {"range": 8, "shots": 2, "damage": 0, "special": "", "category": "pistol"},
	"Carbine": {"range": 18, "shots": 1, "damage": 0, "special": "", "category": "rifle"},

	# Energy Weapons (Range 36-50)
	"Hand Laser": {"range": 12, "shots": 1, "damage": 0, "special": "SNAP_FIRE", "category": "laser"},
	"Infantry Laser": {"range": 18, "shots": 1, "damage": 1, "special": "", "category": "laser"},
	"Blast Rifle": {"range": 24, "shots": 2, "damage": 0, "special": "AREA", "category": "laser"},
	"Beam Pistol": {"range": 10, "shots": 1, "damage": 1, "special": "", "category": "laser"},
	"Laser Rifle": {"range": 30, "shots": 1, "damage": 1, "special": "", "category": "laser"},

	# Plasma Weapons (Range 51-65)
	"Plasma Rifle": {"range": 20, "shots": 1, "damage": 2, "special": "CRITICAL", "category": "plasma"},
	"Fury Rifle": {"range": 24, "shots": 2, "damage": 1, "special": "CRITICAL", "category": "plasma"},
	"Needle Rifle": {"range": 18, "shots": 3, "damage": 0, "special": "PIERCE", "category": "plasma"},
	"Plasma Pistol": {"range": 10, "shots": 1, "damage": 2, "special": "", "category": "plasma"},
	"Hyper Blaster": {"range": 18, "shots": 3, "damage": 1, "special": "", "category": "plasma"},

	# Melee Weapons (Range 66-85)
	"Blade": {"range": 0, "shots": 0, "damage": 0, "special": "MELEE", "category": "melee"},
	"Ripper Sword": {"range": 0, "shots": 0, "damage": 1, "special": "MELEE", "category": "melee"},
	"Boarding Saber": {"range": 0, "shots": 0, "damage": 1, "special": "MELEE ELEGANT", "category": "melee"},
	"Power Claw": {"range": 0, "shots": 0, "damage": 2, "special": "MELEE CLUMSY", "category": "melee"},
	"Shatter Axe": {"range": 0, "shots": 0, "damage": 2, "special": "MELEE", "category": "melee"},
	"Glare Sword": {"range": 0, "shots": 0, "damage": 2, "special": "MELEE ELEGANT", "category": "melee"},

	# Heavy Weapons
	"Auto Cannon": {"range": 24, "shots": 3, "damage": 1, "special": "HEAVY", "category": "heavy"},
	"Flak Gun": {"range": 18, "shots": 4, "damage": 0, "special": "HEAVY", "category": "heavy"},
	"Missile Launcher": {"range": 30, "shots": 1, "damage": 3, "special": "HEAVY AREA", "category": "heavy"},

	# Grenades (Range 86-100)
	"Frakk Grenade": {"range": 6, "shots": 0, "damage": 1, "special": "AREA SINGLE_USE", "category": "grenade"},
	"Dazzle Grenade": {"range": 6, "shots": 0, "damage": 0, "special": "STUN AREA SINGLE_USE", "category": "grenade"},
	"Shock Grenade": {"range": 6, "shots": 0, "damage": 0, "special": "STUN_BOTS AREA SINGLE_USE", "category": "grenade"}
}

## ==========================================
## EXPANDED GEAR DEFINITIONS (Core Rules p.131)
## ==========================================

const GEAR_DEFINITIONS: Dictionary = {
	# Gun Mods
	"Assault Blade": {"effect": "melee_attachment", "description": "Add melee attack to weapon"},
	"Bipod": {"effect": "stability_bonus", "description": "+1 to hit when stationary"},
	"Stabilizer": {"effect": "recoil_reduction", "description": "Reduce multi-shot penalty"},
	"Laser Sight": {"effect": "accuracy_bonus", "description": "+1 to hit within 12\""},
	"Heavy Duty Magazine": {"effect": "extra_shots", "description": "+1 Shots stat"},
	"Hot Shot Pack": {"effect": "damage_boost", "description": "+1 Damage (energy weapons only)"},
	"Suppressor": {"effect": "stealth", "description": "Reduces detection range"},

	# Gun Sights
	"Quality Sight": {"effect": "range_bonus", "description": "+4\" Range"},
	"Seeker Sight": {"effect": "ignore_cover_light", "description": "Ignore light cover"},
	"Night Sight": {"effect": "dark_vision", "description": "No penalty in darkness"},
	"Holo Sight": {"effect": "quick_aim", "description": "May fire at full rate after moving"},

	# Protective Items
	"Combat Armor": {"effect": "armor_bonus", "value": 5, "description": "5+ Armor save"},
	"Frag Vest": {"effect": "armor_bonus", "value": 5, "description": "5+ Armor save (torso only)"},
	"Flak Screen": {"effect": "field_armor", "value": 4, "description": "4+ Field save vs ranged"},
	"Deflector Field": {"effect": "field_deflect", "description": "5+ save, deflects attack on 6"},
	"Shield Generator": {"effect": "regenerating_shield", "description": "4+ save, regenerates each turn"},
	"Hazard Suit": {"effect": "environment_protection", "description": "Ignore environmental hazards"},

	# Utility Items
	"Motion Tracker": {"effect": "detect_hidden", "description": "Reveals hidden enemies within 12\""},
	"Jump Belt": {"effect": "jump_move", "description": "May jump 6\" (ignoring terrain)"},
	"Battle Visor": {"effect": "target_lock", "description": "+1 to hit one target per battle"},
	"Scanner Bot": {"effect": "scan_area", "description": "Reveals all enemies within 18\""},
	"Communicator": {"effect": "coordinate", "description": "Allies within 6\" +1 initiative"},
	"Grapple Launcher": {"effect": "vertical_move", "description": "Move vertically up to 12\""},
	"Med-kit": {"effect": "heal_wounds", "uses": 3, "description": "Heal 1 wound (3 uses)"},
	"Repair Kit": {"effect": "repair_gear", "uses": 2, "description": "Repair damaged equipment"}
}

## ==========================================
## CONSUMABLE ITEMS TABLE (Core Rules)
## ==========================================

const CONSUMABLE_ITEMS: Dictionary = {
	"Booster Pills": {"uses": 2, "effect": "+1 to all rolls for one battle", "duration": "battle"},
	"Combat Serum": {"uses": 1, "effect": "+2 Combat Skill for one battle", "duration": "battle"},
	"Stim-pack": {"uses": 3, "effect": "Remove Stun or recover 1 wound", "duration": "instant"},
	"Rage Out": {"uses": 1, "effect": "+1 Damage in melee, -1 to hit ranged", "duration": "battle"},
	"Still": {"uses": 2, "effect": "Ignore Fear/Morale checks", "duration": "battle"},
	"Focus": {"uses": 1, "effect": "+2 to hit one attack", "duration": "instant"},
	"Analyzer": {"uses": 1, "effect": "Reveal enemy stats", "duration": "instant"},
	"Smoke Grenade": {"uses": 1, "effect": "Create smoke cloud (3\" radius)", "duration": "2_rounds"},
	"Flash Bomb": {"uses": 1, "effect": "Stun all enemies within 3\"", "duration": "instant"}
}

## ==========================================
## ITEM QUALITY/RARITY MODIFIERS (Sprint 19.2)
## ==========================================

enum ItemQuality {
	DAMAGED,     # -1 to stats, needs repair
	WORN,        # No modifier, fragile (breaks on 1)
	STANDARD,    # Normal stats
	QUALITY,     # +1 to one stat
	MILITARY,    # +1 to all stats
	ARTIFACT     # Special properties
}

const QUALITY_MODIFIERS: Dictionary = {
	ItemQuality.DAMAGED: {"stat_mod": -1, "description": "Damaged (needs repair)", "sell_value_mod": 0.25},
	ItemQuality.WORN: {"stat_mod": 0, "description": "Worn (breaks on 1)", "sell_value_mod": 0.5},
	ItemQuality.STANDARD: {"stat_mod": 0, "description": "Standard issue", "sell_value_mod": 1.0},
	ItemQuality.QUALITY: {"stat_mod": 1, "description": "Quality (+1 to one stat)", "sell_value_mod": 1.5},
	ItemQuality.MILITARY: {"stat_mod": 1, "description": "Military grade (+1 all)", "sell_value_mod": 2.0},
	ItemQuality.ARTIFACT: {"stat_mod": 2, "description": "Alien artifact", "sell_value_mod": 3.0}
}

## Quality roll: D6
## 1 = Damaged, 2 = Worn, 3-4 = Standard, 5 = Quality, 6 = Roll again (Military on 5+, Artifact on 6)
static func roll_item_quality() -> ItemQuality:
	var roll: int = randi_range(1, 6)
	match roll:
		1: return ItemQuality.DAMAGED
		2: return ItemQuality.WORN
		3, 4: return ItemQuality.STANDARD
		5: return ItemQuality.QUALITY
		6:
			var bonus_roll: int = randi_range(1, 6)
			if bonus_roll == 6:
				return ItemQuality.ARTIFACT
			elif bonus_roll >= 5:
				return ItemQuality.MILITARY
			else:
				return ItemQuality.QUALITY
	return ItemQuality.STANDARD

## ==========================================
## TRADE GOODS TABLE (for selling/buying)
## ==========================================

const TRADE_GOODS: Dictionary = {
	"Common Supplies": {"base_value": 1, "weight": 1, "legal": true},
	"Medical Supplies": {"base_value": 3, "weight": 1, "legal": true},
	"Weapons Cache": {"base_value": 5, "weight": 3, "legal": false},
	"Tech Components": {"base_value": 4, "weight": 1, "legal": true},
	"Luxury Goods": {"base_value": 6, "weight": 2, "legal": true},
	"Military Hardware": {"base_value": 8, "weight": 4, "legal": false},
	"Alien Artifacts": {"base_value": 10, "weight": 1, "legal": false},
	"Fuel Cells": {"base_value": 2, "weight": 2, "legal": true},
	"Data Cores": {"base_value": 4, "weight": 0, "legal": true},
	"Contraband": {"base_value": 7, "weight": 1, "legal": false}
}

## ==========================================
## HELPER FUNCTIONS
## ==========================================

## Get battlefield finds category from D100 roll
static func get_battlefield_finds_category(roll: int) -> LootCategory:
	## Determine loot category from battlefield finds table
	##
	## Args:
	## roll: D100 result (1-100)
	##
	## Returns:
	## LootCategory enum value
	for category in BATTLEFIELD_FINDS_RANGES.keys():
		var range_data: Dictionary = BATTLEFIELD_FINDS_RANGES[category]
		if roll >= range_data.min and roll <= range_data.max:
			return category

	return LootCategory.NOTHING

## Get main loot category from D100 roll
static func get_main_loot_category(roll: int) -> LootCategory:

	## Args:
	## 	roll: D100 result (1-100)
	##
	## Returns:
	## 	LootCategory enum value
	##
	for category in MAIN_LOOT_RANGES.keys():
		var range_data: Dictionary = MAIN_LOOT_RANGES[category]
		if roll >= range_data.min and roll <= range_data.max:
			return category

	return LootCategory.NOTHING

## Get weapon from weapon subtable
static func get_weapon_from_subtable(roll: int) -> String:
	## Get random weapon from weapon subtable
	##
	## Args:
	## roll: D100 result (1-100)
	##
	## Returns:
	## Weapon name string
	for category in WEAPON_SUBTABLE_RANGES.keys():
		var range_data: Dictionary = WEAPON_SUBTABLE_RANGES[category]
		if roll >= range_data.min and roll <= range_data.max:
			var items: Array = range_data.items
			return items[randi() % items.size()] if items.size() > 0 else "Unknown Weapon"

	return "Unknown Weapon"

## Get gear from gear subtable
static func get_gear_from_subtable(roll: int) -> String:

	## Args:
	## 	roll: D100 result (1-100)
	##
	## Returns:
	## 	Gear item name string
	##
	for category in GEAR_SUBTABLE_RANGES.keys():
		var range_data: Dictionary = GEAR_SUBTABLE_RANGES[category]
		if roll >= range_data.min and roll <= range_data.max:
			var items: Array = range_data.items
			return items[randi() % items.size()] if items.size() > 0 else "Unknown Gear"

	return "Unknown Gear"

## Get odds and ends item from subtable
static func get_odds_and_ends_from_subtable(roll: int) -> Dictionary:
	## Get random odds and ends item from subtable
	##
	## Args:
	## roll: D100 result (1-100)
	##
	## Returns:
	## Dictionary with item name and uses (if consumable)
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

	## Args:
	## 	roll: D100 result (1-100)
	##
	## Returns:
	## 	Dictionary with item, credits_dice, rumors, story_points
	##
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
