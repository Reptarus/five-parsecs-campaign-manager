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
## COMPENDIUM BOT UPGRADES (Compendium p.28)
## Purchased during Post-Battle Step 11 (Purchase Items) with credits.
## Max 1 upgrade installed per campaign turn.
## One of each upgrade per Bot. Lost if Bot is permanently destroyed.
## Soulless cannot use these (different tech base).
## ============================================================================

const COMPENDIUM_BOT_UPGRADES: Array[Dictionary] = [
	{
		"id": "builtin_weapon",
		"name": "Built-in Weapon",
		"cost_formula": "3 x Shots + 1 x Damage",
		"cost": 0,  # Variable, computed at purchase
		"effect": "negate_heavy_clumsy",
		"description": "Any weapon built into chassis. Negates Heavy and Clumsy traits. Cost: 3 Credits per Shot on weapon profile + 1 Credit per point of weapon Damage. 1 Credit to revert.",
		"instruction": "BOT UPGRADE: Built-in Weapon (3 cr x Shots + 1 cr x Damage) - Negates Heavy/Clumsy. 1 cr to revert.",
		"revert_cost": 1,
	},
	{
		"id": "improved_armor",
		"name": "Improved Armor Casing",
		"cost": 5,
		"effect": "builtin_save_5plus",
		"description": "Improve the Bot's built-in Armor Saving Throw to 5+.",
		"instruction": "BOT UPGRADE: Improved Armor Casing (5 cr) - Built-in 5+ Armor Save.",
	},
	{
		"id": "deflection_module",
		"name": "Deflection Module",
		"cost": 8,
		"effect": "save_counts_screen_and_armor",
		"description": "The Bot's built-in saving throw becomes both a Screen and Armor, allowing a save as long as the attack does not negate both forms of defense.",
		"instruction": "BOT UPGRADE: Deflection Module (8 cr) - Save counts as both Screen AND Armor.",
	},
	{
		"id": "jump_module",
		"name": "Jump Module",
		"cost": 6,
		"effect": "replace_move_with_jump",
		"description": "May replace any portion of movement (including Dash movement) by a Jump of equal distance. Jumping does not affect or restrict other actions.",
		"instruction": "BOT UPGRADE: Jump Module (6 cr) - Replace any movement (incl. Dash) with Jump of equal distance.",
	},
	{
		"id": "multi_scanner",
		"name": "Multi-wave Scanner",
		"cost": 10,
		"effect": "plus1_seize_initiative",
		"description": "+1 to all rolls to Seize the Initiative. Cumulative with a party-carried Motion Tracker.",
		"instruction": "BOT UPGRADE: Multi-wave Scanner (10 cr) - +1 Seize the Initiative (stacks with Motion Tracker).",
	},
	{
		"id": "broad_spectrum",
		"name": "Broad Spectrum Vision",
		"cost": 6,
		"effect": "see_through_darkness_smoke_fog",
		"description": "See through darkness, smoke, fog, gas and other impediments normally, without penalty.",
		"instruction": "BOT UPGRADE: Broad Spectrum Vision (6 cr) - Ignore all visibility penalties.",
	},
]


## ============================================================================
## NEW SHIP PARTS (Compendium p.29)
## Installed using normal ship component rules (Core Rules p.60).
## ============================================================================

const NEW_SHIP_PARTS: Array[Dictionary] = [
	{
		"id": "expanded_database",
		"name": "Expanded Database",
		"cost": 10,
		"type": "component",
		"effect": "plus1_quest_progress",
		"description": "Constantly updated database with AI assistance. When rolling to progress an active Quest (Post-Battle Step 3) add +1 to the roll.",
		"instruction": "SHIP COMPONENT: Expanded Database (10 cr) - +1 to Quest progress rolls.",
	},
	{
		"id": "scientific_research",
		"name": "Scientific Research System",
		"cost": 10,
		"type": "component",
		"effect": "travel_research_roll",
		"description": "Gathers and analyzes space debris samples. When traveling to another world, roll 1D6: 1-2 Nothing, 3-4 Research data (2 Credits), 5-6 +1 Quest Rumor.",
		"instruction": "SHIP COMPONENT: Scientific Research System (10 cr) - Travel roll: 1D6: 1-2 nothing, 3-4 earn 2 cr, 5-6 +1 Quest Rumor.",
	},
	{
		"id": "miniaturized_components",
		"name": "Miniaturized Components",
		"cost": 5,
		"type": "component_mod",
		"effect": "negate_fuel_cost_for_component",
		"description": "State-of-the-art lightweight components. The modified component is not counted towards increased fuel costs (Core Rules p.61). Cannot be removed once applied. Can retrofit existing component for 8 Credits.",
		"instruction": "COMPONENT MOD: Miniaturized Components (+5 cr / 8 cr retrofit) - Component doesn't count toward fuel costs.",
		"retrofit_cost": 8,
		"permanent": true,
	},
]


## ============================================================================
## PSIONIC EQUIPMENT (Compendium p.29)
## Purchased during Post-Battle Step 11 (Purchase Items) with credits.
## Requires PSIONIC_EQUIPMENT DLC flag.
## ============================================================================

const PSIONIC_EQUIPMENT: Array[Dictionary] = [
	{
		"id": "warding_shrel",
		"name": "Warding Shrel",
		"cost": 10,
		"slot": "utility",
		"effect": "avoid_psionic_strain",
		"description": "Odd Precursor device. If the wearer would suffer the effects of psionic Strain, the effect is avoided and the device shuts down for the rest of the battle. Carrying two Shrels cancels the effects of both.",
		"instruction": "PSIONIC GEAR: Warding Shrel (10 cr, Utility) - Avoid one Strain effect per battle. Carrying two cancels both.",
		"max_carried": -1,
		"carry_two_cancels": true,
	},
	{
		"id": "psionic_focus",
		"name": "Psionic Focus",
		"cost": 10,
		"slot": "utility",
		"effect": "plus1_power_range",
		"description": "Wrist-mounted device that helps channel psionic waves. Add +1\" to the range of all powers.",
		"instruction": "PSIONIC GEAR: Psionic Focus (10 cr, Utility) - +1\" range to all psionic powers.",
	},
	{
		"id": "nullification_surgery",
		"name": "Nullification Surgery",
		"cost": 3,
		"slot": "implant",
		"effect": "permanently_lose_psionics",
		"description": "The character permanently loses all psionic abilities. This is non-reversible.",
		"instruction": "PSIONIC GEAR: Nullification Surgery (3 cr, Implant) - Permanently remove all psionic abilities. Irreversible.",
		"permanent": true,
		"irreversible": true,
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
