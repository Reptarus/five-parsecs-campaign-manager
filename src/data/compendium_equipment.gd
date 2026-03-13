class_name CompendiumEquipment
extends RefCounted
## Compendium Equipment Data - Training, Bot Upgrades, Ship Parts, Psionic Gear
##
## Data-driven equipment definitions from the Compendium expansion.
## All items gated behind DLCManager ContentFlags.
## All output is TEXT INSTRUCTIONS for the tabletop companion model.
##
## Usage:
##   CompendiumEquipment.get_advanced_training()   # NEW_TRAINING flag
##   CompendiumEquipment.get_bot_upgrades()         # BOT_UPGRADES flag
##   CompendiumEquipment.get_ship_parts()           # NEW_SHIP_PARTS flag
##   CompendiumEquipment.get_psionic_equipment()    # PSIONIC_EQUIPMENT flag


## ============================================================================
## DLC GATING HELPER
## ============================================================================

static func _get_dlc_manager() -> Node:
	if not Engine.get_main_loop():
		return null
	return Engine.get_main_loop().root.get_node_or_null("/root/DLCManager")


static func _is_flag_enabled(flag_name: String) -> bool:
	var dlc_mgr := _get_dlc_manager()
	if not dlc_mgr:
		return false
	var flag_value: int = dlc_mgr.ContentFlag.get(flag_name, -1)
	if flag_value < 0:
		return false
	return dlc_mgr.is_feature_enabled(flag_value)


## ============================================================================
## ADVANCED TRAINING (Compendium pp.26-28)
## Purchased during Advancement Phase with credits (NOT XP).
## Character spends a crew action to attend training.
## ============================================================================

const ADVANCED_TRAINING: Array[Dictionary] = [
	{
		"id": "freelancer_cert",
		"name": "Freelancer Certification",
		"cost": 15,
		"currency": "credits",
		"effect": "permanent_patron_license",
		"description": "Permanent patron license. When seeking Patrons, always succeed on the availability roll.",
		"instruction": "TRAINING: Freelancer Certification (15 cr) - Always succeed on Patron availability rolls.",
		"one_per_crew": true,
	},
	{
		"id": "instructor",
		"name": "Instructor",
		"cost": 10,
		"currency": "credits",
		"effect": "no_training_fee_no_availability_roll",
		"description": "Crew member becomes an instructor. Other crew can train without paying fees or rolling availability.",
		"instruction": "TRAINING: Instructor (10 cr) - Other crew train for free without availability roll.",
		"one_per_crew": true,
	},
	{
		"id": "survival_course",
		"name": "Survival Course",
		"cost": 10,
		"currency": "credits",
		"effect": "d6_4plus_evade_trap_hazard",
		"description": "When encountering a trap or environmental hazard, roll D6: 4+ to evade it entirely.",
		"instruction": "TRAINING: Survival Course (10 cr) - D6 4+ to evade traps/hazards.",
		"one_per_crew": false,
	},
	{
		"id": "fixer",
		"name": "Fixer",
		"cost": 15,
		"currency": "credits",
		"effect": "plus1_find_patron_recruit_track",
		"description": "+1 to Find Patron, Recruit, and Track rolls.",
		"instruction": "TRAINING: Fixer (15 cr) - +1 to Find Patron, Recruit, and Track rolls.",
		"one_per_crew": true,
	},
	{
		"id": "tactical_course",
		"name": "Tactical Course",
		"cost": 15,
		"currency": "credits",
		"effect": "act_before_move_on_activation",
		"description": "On activation, this character may take their action before moving.",
		"instruction": "TRAINING: Tactical Course (15 cr) - May act before moving on activation.",
		"one_per_crew": false,
	},
]


## ============================================================================
## COMPENDIUM BOT UPGRADES (Compendium pp.30-32)
## Purchased during Advancement Phase with credits.
## These are ADDITIONAL to the 6 core bot upgrades.
## Max 1 upgrade installed per campaign turn.
## ============================================================================

const COMPENDIUM_BOT_UPGRADES: Array[Dictionary] = [
	{
		"id": "builtin_weapon",
		"name": "Built-in Weapon",
		"cost_formula": "3 x Shots + 1 x Damage",
		"cost": 0,  # Variable, computed at purchase
		"effect": "negate_heavy_clumsy",
		"description": "Convert any weapon to built-in. Negates Heavy and Clumsy traits. Cost: 3 per Shots + 1 per Damage. Revert for 1 cr.",
		"instruction": "BOT UPGRADE: Built-in Weapon (3xShots + 1xDamage cr) - Negates Heavy/Clumsy. Max 1 per turn. Revert: 1 cr.",
		"max_per_turn": 1,
		"revert_cost": 1,
	},
	{
		"id": "improved_armor",
		"name": "Improved Armor Casing",
		"cost": 5,
		"effect": "builtin_save_5plus",
		"description": "Built-in armor saving throw of 5+. Does not stack with worn armor.",
		"instruction": "BOT UPGRADE: Improved Armor Casing (5 cr) - Built-in 5+ Armor Save (no stacking).",
	},
	{
		"id": "deflection_module",
		"name": "Deflection Module",
		"cost": 8,
		"effect": "save_counts_screen_and_armor",
		"description": "Saving throw counts as both Screen and Armor save.",
		"instruction": "BOT UPGRADE: Deflection Module (8 cr) - Save counts as Screen AND Armor.",
	},
	{
		"id": "jump_module",
		"name": "Jump Module",
		"cost": 6,
		"effect": "replace_move_with_jump",
		"description": "Replace normal movement with Jump: move in straight line, ignoring terrain. Cannot Dash.",
		"instruction": "BOT UPGRADE: Jump Module (6 cr) - Jump movement (ignore terrain, no Dashing).",
	},
	{
		"id": "multi_scanner",
		"name": "Multi-wave Scanner",
		"cost": 10,
		"effect": "plus1_seize_initiative",
		"description": "+1 to Seize the Initiative rolls.",
		"instruction": "BOT UPGRADE: Multi-wave Scanner (10 cr) - +1 Seize the Initiative.",
	},
	{
		"id": "broad_spectrum",
		"name": "Broad Spectrum Vision",
		"cost": 6,
		"effect": "see_through_darkness_smoke_fog",
		"description": "See through darkness, smoke, and fog. Ignore visibility penalties.",
		"instruction": "BOT UPGRADE: Broad Spectrum Vision (6 cr) - Ignore darkness/smoke/fog penalties.",
	},
]


## ============================================================================
## NEW SHIP PARTS (Compendium pp.34-36)
## Purchased during Trade Phase with credits.
## Installed on ship (one slot per part type).
## ============================================================================

const NEW_SHIP_PARTS: Array[Dictionary] = [
	{
		"id": "emergency_drives",
		"name": "Emergency Drives",
		"cost": 20,
		"slot": "engine",
		"effect": "reroll_flee_travel_event",
		"description": "May re-roll one failed flee attempt per travel event.",
		"instruction": "SHIP PART: Emergency Drives (20 cr) - Re-roll one failed flee attempt per travel event.",
	},
	{
		"id": "cargo_hold_expansion",
		"name": "Expanded Cargo Hold",
		"cost": 10,
		"slot": "cargo",
		"effect": "plus3_cargo_capacity",
		"description": "+3 cargo capacity for stash and trade goods.",
		"instruction": "SHIP PART: Expanded Cargo Hold (10 cr) - +3 cargo capacity.",
	},
	{
		"id": "fuel_converter",
		"name": "Fuel Converter",
		"cost": 15,
		"slot": "fuel",
		"effect": "reduce_fuel_cost_by_1",
		"description": "Reduce fuel cost per jump by 1 (minimum 1).",
		"instruction": "SHIP PART: Fuel Converter (15 cr) - -1 fuel per jump (min 1).",
	},
	{
		"id": "medical_bay",
		"name": "Medical Bay",
		"cost": 25,
		"slot": "medical",
		"effect": "reduce_recovery_by_1_turn",
		"description": "Reduce crew recovery time by 1 campaign turn (minimum 1).",
		"instruction": "SHIP PART: Medical Bay (25 cr) - -1 turn recovery time (min 1).",
	},
	{
		"id": "weapon_hardpoint",
		"name": "Weapon Hardpoint",
		"cost": 15,
		"slot": "weapon",
		"effect": "plus1_weapon_mount",
		"description": "+1 weapon mount for ship combat.",
		"instruction": "SHIP PART: Weapon Hardpoint (15 cr) - +1 weapon mount.",
	},
	{
		"id": "reinforced_hull",
		"name": "Reinforced Hull Plating",
		"cost": 20,
		"slot": "hull",
		"effect": "plus2_max_hull",
		"description": "+2 maximum hull points.",
		"instruction": "SHIP PART: Reinforced Hull Plating (20 cr) - +2 max hull points.",
	},
	{
		"id": "sensor_suite",
		"name": "Advanced Sensor Suite",
		"cost": 12,
		"slot": "sensor",
		"effect": "plus1_exploration_rolls",
		"description": "+1 to all exploration and scanning rolls.",
		"instruction": "SHIP PART: Advanced Sensor Suite (12 cr) - +1 exploration/scan rolls.",
	},
]


## ============================================================================
## PSIONIC EQUIPMENT (Compendium pp.40-42)
## Purchased during Trade Phase with credits.
## Requires PSIONIC_EQUIPMENT DLC flag.
## ============================================================================

const PSIONIC_EQUIPMENT: Array[Dictionary] = [
	{
		"id": "psionic_amplifier",
		"name": "Psionic Amplifier",
		"cost": 15,
		"slot": "gear",
		"effect": "plus1_psionic_projection",
		"description": "+1 to all psionic projection rolls. Gear slot.",
		"instruction": "PSIONIC GEAR: Psionic Amplifier (15 cr) - +1 to psionic projection rolls. (Gear slot)",
	},
	{
		"id": "mind_shield",
		"name": "Mind Shield",
		"cost": 12,
		"slot": "gear",
		"effect": "plus2_resist_enemy_psionic",
		"description": "+2 to resist enemy psionic attacks. Gear slot.",
		"instruction": "PSIONIC GEAR: Mind Shield (12 cr) - +2 resist enemy psionics. (Gear slot)",
	},
	{
		"id": "psi_dampener",
		"name": "Psi-Dampener",
		"cost": 8,
		"slot": "consumable",
		"uses": 1,
		"effect": "suppress_psionics_6in_1round",
		"description": "Single-use. Suppress all psionic powers within 6\" for 1 round.",
		"instruction": "PSIONIC GEAR: Psi-Dampener (8 cr) - Suppress psionics within 6\" for 1 round. Single use.",
	},
	{
		"id": "focus_crystal",
		"name": "Focus Crystal",
		"cost": 10,
		"slot": "gear",
		"effect": "reroll_one_strain_die",
		"description": "May re-roll one strain die per battle. Gear slot.",
		"instruction": "PSIONIC GEAR: Focus Crystal (10 cr) - Re-roll one strain die per battle. (Gear slot)",
	},
	{
		"id": "psionic_blade",
		"name": "Psionic Blade",
		"cost": 18,
		"slot": "weapon",
		"effect": "melee_plus1_damage_psionic_only",
		"description": "Melee weapon. +1 Damage. Only usable by psionic characters.",
		"instruction": "PSIONIC GEAR: Psionic Blade (18 cr) - Melee, +1 Damage. Psionic-only.",
	},
]


## ============================================================================
## QUERY METHODS (DLC-gated)
## ============================================================================

## Returns advanced training options. Empty array if DLC not enabled.
static func get_advanced_training() -> Array[Dictionary]:
	if not _is_flag_enabled("NEW_TRAINING"):
		return []
	var result: Array[Dictionary] = []
	result.assign(ADVANCED_TRAINING)
	return result


## Returns compendium bot upgrades. Empty array if DLC not enabled.
static func get_bot_upgrades() -> Array[Dictionary]:
	if not _is_flag_enabled("BOT_UPGRADES"):
		return []
	var result: Array[Dictionary] = []
	result.assign(COMPENDIUM_BOT_UPGRADES)
	return result


## Returns new ship parts. Empty array if DLC not enabled.
static func get_ship_parts() -> Array[Dictionary]:
	if not _is_flag_enabled("NEW_SHIP_PARTS"):
		return []
	var result: Array[Dictionary] = []
	result.assign(NEW_SHIP_PARTS)
	return result


## Returns psionic equipment. Empty array if DLC not enabled.
static func get_psionic_equipment() -> Array[Dictionary]:
	if not _is_flag_enabled("PSIONIC_EQUIPMENT"):
		return []
	var result: Array[Dictionary] = []
	result.assign(PSIONIC_EQUIPMENT)
	return result


## Returns ALL purchasable compendium items for the Trade Phase shop.
## Combines ship parts + psionic gear (training and bot upgrades are Advancement Phase).
static func get_trade_phase_items() -> Array[Dictionary]:
	var items: Array[Dictionary] = []
	items.append_array(get_ship_parts())
	items.append_array(get_psionic_equipment())
	return items


## Returns trade phase items with DLC lock status for UI display.
## Each item gets "_dlc_locked": bool. Locked items should be shown but not purchasable.
static func get_trade_phase_items_with_lock_status() -> Array[Dictionary]:
	var items: Array[Dictionary] = []
	var ship_unlocked: bool = _is_flag_enabled("NEW_SHIP_PARTS")
	for part in NEW_SHIP_PARTS:
		var entry: Dictionary = part.duplicate()
		entry["_dlc_locked"] = not ship_unlocked
		items.append(entry)
	var psi_unlocked: bool = _is_flag_enabled("PSIONIC_EQUIPMENT")
	for psi in PSIONIC_EQUIPMENT:
		var entry: Dictionary = psi.duplicate()
		entry["_dlc_locked"] = not psi_unlocked
		items.append(entry)
	return items


## Returns ALL advancement phase compendium options.
## Combines advanced training + compendium bot upgrades.
static func get_advancement_phase_items() -> Array[Dictionary]:
	var items: Array[Dictionary] = []
	items.append_array(get_advanced_training())
	items.append_array(get_bot_upgrades())
	return items


## Get a specific item by ID from any category.
static func get_item_by_id(item_id: String) -> Dictionary:
	for list in [ADVANCED_TRAINING, COMPENDIUM_BOT_UPGRADES, NEW_SHIP_PARTS, PSIONIC_EQUIPMENT]:
		for item in list:
			if item.get("id", "") == item_id:
				return item
	return {}


## Get instruction text for a specific item (for cheat sheet / battle log).
static func get_instruction_text(item_id: String) -> String:
	var item := get_item_by_id(item_id)
	return item.get("instruction", "")
