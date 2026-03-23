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

## Core Rules p.131 — Weapon Category Subtable
const WEAPON_SUBTABLE_RANGES: Dictionary = {
	"slug_weapons": {"min": 1, "max": 35, "items": ["Hold Out Pistol", "Hand Gun", "Scrap Pistol", "Machine Pistol", "Duelling Pistol", "Hand Cannon", "Colony Rifle", "Military Rifle", "Shotgun", "Flak Gun", "Hunting Rifle", "Marksman's Rifle", "Auto Rifle", "Rattle Gun"]},
	"energy_weapons": {"min": 36, "max": 50, "items": ["Hand Laser", "Beam Pistol", "Infantry Laser", "Blast Pistol", "Blast Rifle", "Hyper Blaster"]},
	"special_weapons": {"min": 51, "max": 65, "items": ["Needle Rifle", "Plasma Rifle", "Fury Rifle", "Shell Gun", "Cling Fire Pistol", "Hand Flamer"]},
	"melee_weapons": {"min": 66, "max": 85, "items": ["Blade", "Brutal Melee Weapon", "Boarding Saber", "Ripper Sword", "Shatter Axe", "Power Claw", "Glare Sword", "Suppression Maul"]},
	"grenades": {"min": 86, "max": 100, "items": ["3 Frakk Grenades", "3 Dazzle Grenades"]}
}

## ==========================================
## GEAR SUBTABLE (D100)
## ==========================================

## Core Rules p.132 — Gear Subtable
const GEAR_SUBTABLE_RANGES: Dictionary = {
	"gun_mods": {"min": 1, "max": 20, "items": ["Assault Blade", "Beam Light", "Bipod", "Hot Shot Pack", "Cyber-configurable Nano-Sludge", "Stabilizer", "Shock Attachment", "Upgrade Kit"]},
	"gun_sights": {"min": 21, "max": 40, "items": ["Laser Sight", "Quality Sight", "Seeker Sight", "Tracker Sight", "Unity Battle Sight"]},
	"protective_items": {"min": 41, "max": 75, "items": ["Battle Dress", "Camo Cloak", "Combat Armor", "Deflector Field", "Flak Screen", "Flex-Armor", "Frag Vest", "Screen Generator", "Stealth Gear"]},
	"utility_items": {"min": 76, "max": 100, "items": ["Auto Sensor", "Battle Visor", "Communicator", "Concealed Blade", "Displacer", "Distraction Bot", "Grapple Launcher", "Grav Dampener", "Hazard Suit", "Hover Board", "Insta-Wall", "Jump Belt", "Motion Tracker", "Multi-Cutter", "Robo-Rabbit's Foot", "Scanner Bot", "Snooper Bot", "Sonic Emitter", "Steel Boots", "Time Distorter"]}
}

## ==========================================
## ODDS AND ENDS SUBTABLE (D100)
## ==========================================

## Core Rules p.133 — Odds and Ends Subtable
const ODDS_AND_ENDS_RANGES: Dictionary = {
	"consumables": {"min": 1, "max": 55, "items": ["Booster Pills", "Combat Serum", "Kiranin Crystals", "Rage Out", "Still", "Stim-pack"], "uses": 2},
	"implants": {"min": 56, "max": 70, "items": ["AI Companion", "Body Wire", "Boosted Arm", "Boosted Leg", "Cyber Hand", "Genetic Defenses", "Health Boost", "Nerve Adjuster", "Neural Optimization", "Night Sight", "Pain Suppressor"]},
	"ship_items": {"min": 71, "max": 100, "items": ["Med-patch", "Spare Parts", "Repair Bot", "Nano-doc", "Colonist Ration Packs"]}
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
	"Infantry Laser": {"range": 30, "shots": 1, "damage": 0, "special": "SNAP_FIRE", "category": "laser"},
	"Blast Rifle": {"range": 16, "shots": 1, "damage": 1, "special": "", "category": "laser"},
	"Beam Pistol": {"range": 10, "shots": 1, "damage": 1, "special": "", "category": "laser"},
	"Laser Rifle": {"range": 30, "shots": 1, "damage": 1, "special": "", "category": "laser"},

	# Plasma Weapons (Range 51-65)
	"Plasma Rifle": {"range": 20, "shots": 2, "damage": 1, "special": "FOCUSED_PIERCING", "category": "plasma"},
	"Fury Rifle": {"range": 24, "shots": 1, "damage": 2, "special": "HEAVY_PIERCING", "category": "plasma"},
	"Needle Rifle": {"range": 18, "shots": 2, "damage": 0, "special": "CRITICAL", "category": "plasma"},
	"Plasma Pistol": {"range": 10, "shots": 1, "damage": 2, "special": "", "category": "plasma"},
	"Hyper Blaster": {"range": 24, "shots": 3, "damage": 1, "special": "", "category": "energy"},

	# Melee Weapons (Range 66-85)
	"Blade": {"range": 0, "shots": 0, "damage": 0, "special": "MELEE", "category": "melee"},
	"Ripper Sword": {"range": 0, "shots": 0, "damage": 1, "special": "MELEE", "category": "melee"},
	"Boarding Saber": {"range": 0, "shots": 0, "damage": 1, "special": "MELEE ELEGANT", "category": "melee"},
	"Power Claw": {"range": 0, "shots": 0, "damage": 2, "special": "MELEE CLUMSY", "category": "melee"},
	"Shatter Axe": {"range": 0, "shots": 0, "damage": 2, "special": "MELEE", "category": "melee"},
	"Glare Sword": {"range": 0, "shots": 0, "damage": 2, "special": "MELEE ELEGANT", "category": "melee"},

	# Heavy Weapons
	"Auto Cannon": {"range": 24, "shots": 3, "damage": 1, "special": "HEAVY", "category": "heavy"},
	"Flak Gun": {"range": 8, "shots": 2, "damage": 1, "special": "FOCUSED CRITICAL", "category": "slug"},
	"Missile Launcher": {"range": 30, "shots": 1, "damage": 3, "special": "HEAVY AREA", "category": "heavy"},

	# Grenades (Range 86-100)
	"Frakk Grenade": {"range": 6, "shots": 0, "damage": 1, "special": "AREA SINGLE_USE", "category": "grenade"},
	"Dazzle Grenade": {"range": 6, "shots": 0, "damage": 0, "special": "STUN AREA SINGLE_USE", "category": "grenade"},
	"Shock Grenade": {"range": 6, "shots": 0, "damage": 0, "special": "STUN_BOTS AREA SINGLE_USE", "category": "grenade"}
}

## ==========================================
## EXPANDED GEAR DEFINITIONS (Core Rules p.131)
## ==========================================

## Core Rules pp.53-58, 132-133 — exact book descriptions
const GEAR_DEFINITIONS: Dictionary = {
	# Gun Mods (p.53) — permanent, 1 per weapon, cannot be removed
	"Assault Blade": {"effect": "melee_mod", "description": "Weapon gains Melee trait. Damage +1, wins on Draw. Non-Pistol only."},
	"Beam Light": {"effect": "visibility", "description": "Increase visibility by +3\" in reduced visibility conditions."},
	"Bipod": {"effect": "stability_bonus", "description": "+1 to Hit at ranges over 8\" when Aiming or from Cover. Non-Pistol only."},
	"Hot Shot Pack": {"effect": "damage_boost", "description": "+1 Damage for Blast Pistol/Blast Rifle/Hand Laser/Infantry Laser. Natural 6 = overheat (inoperable rest of fight)."},
	"Cyber-configurable Nano-Sludge": {"effect": "hit_bonus", "description": "Permanent +1 Hit bonus."},
	"Stabilizer": {"effect": "ignore_heavy", "description": "Weapon may ignore Heavy trait."},
	"Shock Attachment": {"effect": "stun_mod", "description": "Weapon receives Stun trait against targets within 8\"."},
	"Upgrade Kit": {"effect": "range_bonus", "description": "+2\" Range increase."},

	# Gun Sights (p.53) — movable, 1 per weapon, damaged with weapon
	"Laser Sight": {"effect": "snap_shot", "description": "Weapon receives Snap Shot trait. Pistol only."},
	"Quality Sight": {"effect": "range_reroll", "description": "+2\" Range. Reroll 1s when firing only 1 shot."},
	"Seeker Sight": {"effect": "stationary_bonus", "description": "+1 to Hit if shooter did not Move this round."},
	"Tracker Sight": {"effect": "tracking_bonus", "description": "+1 to Hit if fired at same target previous round."},
	"Unity Battle Sight": {"effect": "hit_bonus", "description": "+1 to all Hit rolls."},

	# Protective Items (pp.54-55) — armor (max 1) + screen (max 1)
	"Battle Dress": {"effect": "armor_save", "value": 5, "description": "+1 Reactions (max 4) and 5+ Saving Throw."},
	"Camo Cloak": {"effect": "cover_extension", "description": "Within 2\" of Cover counts as in Cover. No effect if shooter within 4\"."},
	"Combat Armor": {"effect": "armor_save", "value": 5, "description": "5+ Saving Throw."},
	"Deflector Field": {"effect": "auto_deflect", "description": "Automatically deflects one ranged Hit per battle. Decide before Toughness/armor rolls."},
	"Flak Screen": {"effect": "area_reduction", "description": "Area weapons have Damage reduced by -1 (cap +0)."},
	"Flex-Armor": {"effect": "conditional_toughness", "description": "If did not move last activation, +1 Toughness (max 6)."},
	"Frag Vest": {"effect": "armor_save", "value": 6, "description": "6+ Saving Throw, improved to 5+ vs Area attacks."},
	"Screen Generator": {"effect": "ranged_save", "value": 5, "description": "5+ Saving Throw vs gunfire. No effect vs Area or Melee."},
	"Stealth Gear": {"effect": "range_penalty", "description": "Enemies firing from over 9\" are -1 to Hit."},

	# Utility Items (pp.56-57) — max 3 per character
	"Auto Sensor": {"effect": "reaction_fire", "description": "Fire one Pistol shot at enemy moving within 4\" LoS. Hits only on natural 6."},
	"Battle Visor": {"effect": "reroll_ones", "description": "Reroll any 1s on firing dice when shooting."},
	"Communicator": {"effect": "reaction_bonus", "description": "Roll one extra die on Reaction roll, discard one."},
	"Concealed Blade": {"effect": "thrown_weapon", "description": "Throw at enemy within 2\" as Free Action. Damage +0. Once per battle, free replacement."},
	"Displacer": {"effect": "teleport", "description": "Teleport to point 1D6\" from aimed spot. Once per mission. Precursor: pick from 2 landing points."},
	"Distraction Bot": {"effect": "disable_enemy", "description": "Target enemy within 12\" cannot act next activation. Once per battle."},
	"Grapple Launcher": {"effect": "vertical_move", "description": "Scale terrain within 1\", ascend up to 12\". Combat Action."},
	"Grav Dampener": {"effect": "fall_immunity", "description": "No falling damage. Drops over 6\" count as Move."},
	"Hazard Suit": {"effect": "hazard_save", "description": "5+ Saving Throw vs environmental hazards."},
	"Hover Board": {"effect": "fast_move", "description": "Move up to 9\" ignoring man-height terrain. No combat while boarding."},
	"Insta-Wall": {"effect": "force_wall", "description": "Place 2\" impenetrable wall within 3\". Dissipates on D6 roll of 6 each round. Once per mission."},
	"Jump Belt": {"effect": "jump_move", "description": "Jump 9\" forward and 3\" up. May take Combat Action after landing."},
	"Motion Tracker": {"effect": "initiative_bonus", "description": "+1 to all Seize the Initiative rolls."},
	"Multi-Cutter": {"effect": "terrain_cut", "description": "Cut man-sized hole through terrain up to 1\" thick. Combat Action. No effect on force fields."},
	"Robo-Rabbit's Foot": {"effect": "luck_boost", "description": "Luck 0 counts as Luck 1. Prevents death once (destroyed)."},
	"Scanner Bot": {"effect": "crew_initiative", "description": "+1 to all crew Seize the Initiative rolls."},
	"Snooper Bot": {"effect": "negate_penalty", "description": "Ignore Seize the Initiative penalties. Damaged on D6 roll of 1."},
	"Sonic Emitter": {"effect": "debuff_enemies", "description": "Enemies within 5\" suffer -1 to all Hit rolls when shooting."},
	"Steel Boots": {"effect": "kick_attack", "description": "On natural 5-6 Brawl win, kick opponent Damage +0, knockback 1D3\"."},
	"Time Distorter": {"effect": "freeze_enemies", "description": "Freeze up to 3 enemies until end of following round. Single-use."}
}

## ==========================================
## CONSUMABLE ITEMS TABLE (Core Rules)
## ==========================================

## Core Rules p.54 — exact book effects. All consumables are single-use.
## Bots and Soulless cannot use consumables.
const CONSUMABLE_ITEMS: Dictionary = {
	"Booster Pills": {"uses": 1, "effect": "Remove all Stun markers. Move at double Speed this round.", "duration": "round"},
	"Combat Serum": {"uses": 1, "effect": "+2\" Speed and +2 Reactions for the rest of the battle.", "duration": "battle"},
	"Kiranin Crystals": {"uses": 1, "effect": "Daze all characters within 4\" (unable to act this round). No effect on already-acted or user. Brawl defense normal.", "duration": "round"},
	"Rage Out": {"uses": 1, "effect": "+2\" Speed and +1 to Brawling rolls for this and next round. K'Erin: rest of battle.", "duration": "2_rounds"},
	"Still": {"uses": 1, "effect": "+1 to Hit, but cannot Move this and next round.", "duration": "2_rounds"},
	"Stim-pack": {"uses": 1, "effect": "If character would become casualty, remain with 1 Stun marker. Reflexive, no action required.", "duration": "instant"}
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
