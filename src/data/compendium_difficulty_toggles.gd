class_name CompendiumDifficultyToggles
extends RefCounted
## Compendium Difficulty Toggles & Combat Options Data
##
## Data-driven difficulty/combat option definitions from the Compendium.
## Extends house_rules_definitions.gd pattern with sub-toggles and categories.
## All output is TEXT INSTRUCTIONS for the tabletop companion model.
##
## Categories:
##   encounter_scaling  - Enemy count/composition (DIFFICULTY_TOGGLES)
##   economy            - Credits/upkeep/progression (DIFFICULTY_TOGGLES)
##   combat_difficulty  - Enemy stat boosts (DIFFICULTY_TOGGLES)
##   time_pressure      - Round limits/spawns (DIFFICULTY_TOGGLES)
##   ai_behavior        - D6 enemy AI type (AI_VARIATIONS)
##   casualty           - Casualty tables (CASUALTY_TABLES)
##   injury_detail      - Detailed injuries (DETAILED_INJURIES)
##   dramatic           - Dramatic combat effects (DRAMATIC_COMBAT)


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
## DIFFICULTY TOGGLES (Compendium pp.56-80)
## ============================================================================

const DIFFICULTY_TOGGLES: Array[Dictionary] = [
	{
		"id": "strength_adjusted",
		"name": "Strength-Adjusted Enemies",
		"category": "encounter_scaling",
		"dlc_flag": "DIFFICULTY_TOGGLES",
		"description": "Enemy count = crew size + enemy modifiers. Scales encounters to crew strength.",
		"instruction": "ENCOUNTER: Enemy count equals your crew size, plus any enemy-specific modifiers.",
	},
	{
		"id": "slaves_to_stargrind_money",
		"name": "Money is Tight",
		"category": "economy",
		"dlc_flag": "DIFFICULTY_TOGGLES",
		"description": "Upkeep: 0 for 1 crew, 1 for 2-4, +1 per crew past 4. Find Patron/Repair Kit cost 1 cr. No free hull repair. Credit rewards D6-1 (min 1).",
		"instruction": "ECONOMY: Upkeep 0/1/+1 per crew past 4. Find Patron & Repair Kit cost 1 cr each. No free hull repair. Credit rewards: D6-1 (min 1).",
	},
	{
		"id": "slaves_to_stargrind_progression",
		"name": "Slower Progression",
		"category": "economy",
		"dlc_flag": "DIFFICULTY_TOGGLES",
		"description": "Increased XP costs: Reactions 8, Combat 8, Speed 5, Savvy 5, Toughness 8, Luck 10.",
		"instruction": "PROGRESSION: XP costs increased - Reactions/Combat/Toughness: 8 XP, Speed/Savvy: 5 XP, Luck: 10 XP.",
	},
	{
		"id": "veteran",
		"name": "Veteran Enemy",
		"category": "combat_difficulty",
		"dlc_flag": "DIFFICULTY_TOGGLES",
		"description": "1 basic enemy gets +1 Combat Skill.",
		"instruction": "COMBAT: One basic enemy has +1 Combat Skill (Veteran).",
	},
	{
		"id": "actually_specialized",
		"name": "Actually Specialized",
		"category": "combat_difficulty",
		"dlc_flag": "DIFFICULTY_TOGGLES",
		"description": "Specialist enemies have minimum Combat Skill +1 and Toughness 4.",
		"instruction": "COMBAT: Specialists get minimum Combat +1, Toughness 4.",
	},
	{
		"id": "armored_leaders",
		"name": "Armored Leaders",
		"category": "combat_difficulty",
		"dlc_flag": "DIFFICULTY_TOGGLES",
		"description": "Lieutenants get a 5+ Armor saving throw.",
		"instruction": "COMBAT: Lieutenants gain 5+ Armor Save.",
	},
	{
		"id": "better_leadership",
		"name": "Better Leadership",
		"category": "combat_difficulty",
		"dlc_flag": "DIFFICULTY_TOGGLES",
		"description": "Unique Individuals appear on a roll of 7+ instead of 9+.",
		"instruction": "COMBAT: Unique Individuals appear on 7+ (not 9+).",
	},
	{
		"id": "paying_by_hour",
		"name": "Paying by the Hour",
		"category": "time_pressure",
		"dlc_flag": "DIFFICULTY_TOGGLES",
		"description": "Battle has a round limit: 2D6 (pick highest) + 4. Must complete objective before time runs out.",
		"instruction": "TIME: Round limit = 2D6 pick highest + 4. Complete objective before time expires.",
	},
	{
		"id": "movement_all_over",
		"name": "Movement All Over",
		"category": "time_pressure",
		"dlc_flag": "DIFFICULTY_TOGGLES",
		"description": "Each round after Round 1: Roll D6. If result <= round number, +1 enemy arrives.",
		"instruction": "TIME: Each round, roll D6. If D6 <= round number, +1 enemy spawns.",
	},
	{
		"id": "fickle_scans",
		"name": "Fickle Scans",
		"category": "time_pressure",
		"dlc_flag": "DIFFICULTY_TOGGLES",
		"description": "Notable Sights markers are removed after Round 3.",
		"instruction": "TIME: Notable Sights markers removed after Round 3. Grab them early!",
	},
	{
		"id": "starting_gutter",
		"name": "Starting in the Gutter",
		"category": "economy",
		"dlc_flag": "DIFFICULTY_TOGGLES",
		"description": "Start campaign with 0 credits and only basic weapons. A harder beginning.",
		"instruction": "START: Begin with 0 credits and basic weapons only.",
	},
	{
		"id": "reduced_lethality",
		"name": "Reduced Lethality",
		"category": "combat_difficulty",
		"dlc_flag": "DIFFICULTY_TOGGLES",
		"description": "Characters knocked out of action are only killed on a natural 1 on the injury roll. Easier survival.",
		"instruction": "COMBAT: Characters only killed on natural 1 on injury roll (easier survival).",
	},
]


## ============================================================================
## D6 AI BEHAVIOR TABLE (Compendium pp.82-84)
## Roll D6 per enemy group to determine their behavior pattern.
## ============================================================================

const AI_BEHAVIOR_TABLE: Array[Dictionary] = [
	{
		"roll": 1,
		"id": "aggressive",
		"name": "Aggressive",
		"description": "Always advance toward nearest crew. Prioritize brawling over shooting.",
		"instruction": "AI: AGGRESSIVE - Enemies always advance and prefer brawling.",
	},
	{
		"roll": 2,
		"id": "defensive",
		"name": "Defensive",
		"description": "Maximize cover usage. Retreat when wounded. Hold objectives.",
		"instruction": "AI: DEFENSIVE - Enemies seek cover, retreat when wounded.",
	},
	{
		"roll": 3,
		"id": "tactical",
		"name": "Tactical",
		"description": "Attempt flanking maneuvers. Focus fire on weakest/wounded targets.",
		"instruction": "AI: TACTICAL - Enemies flank and focus fire on weak targets.",
	},
	{
		"roll": 4,
		"id": "cautious",
		"name": "Cautious",
		"description": "Hold position until engaged. Fire at targets of opportunity.",
		"instruction": "AI: CAUTIOUS - Enemies hold position, fire at opportunity.",
	},
	{
		"roll": 5,
		"id": "beast",
		"name": "Beast",
		"description": "Move toward nearest target. Always brawl if possible.",
		"instruction": "AI: BEAST - Move to nearest, always brawl.",
	},
	{
		"roll": 6,
		"id": "rampage",
		"name": "Rampage",
		"description": "Move toward nearest target. Fire or brawl, whichever is available.",
		"instruction": "AI: RAMPAGE - Move to nearest, fire or brawl.",
	},
]


## ============================================================================
## CASUALTY TABLE (Compendium p.86)
## When a character reaches 0 HP, roll D6.
## ============================================================================

const CASUALTY_TABLE: Array[Dictionary] = [
	{
		"roll": 1,
		"id": "instant_kill",
		"name": "Instantly Killed",
		"instruction": "CASUALTY: Character is KILLED instantly. Remove from campaign.",
	},
	{
		"roll": 2,
		"id": "severe_wound_low",
		"name": "Severely Wounded",
		"instruction": "CASUALTY: Severely Wounded. Cannot act for rest of battle. Roll on injury table post-battle.",
	},
	{
		"roll": 3,
		"id": "severe_wound_high",
		"name": "Severely Wounded",
		"instruction": "CASUALTY: Severely Wounded. Cannot act for rest of battle. Roll on injury table post-battle.",
	},
	{
		"roll": 4,
		"id": "stunned_low",
		"name": "Stunned",
		"instruction": "CASUALTY: Stunned. Lose next activation, return at 1 HP.",
	},
	{
		"roll": 5,
		"id": "stunned_high",
		"name": "Stunned",
		"instruction": "CASUALTY: Stunned. Lose next activation, return at 1 HP.",
	},
	{
		"roll": 6,
		"id": "shrugged_off",
		"name": "Shrugged It Off",
		"instruction": "CASUALTY: Shrugged it off! Stay at 1 HP, continue acting normally.",
	},
]


## ============================================================================
## DETAILED INJURY TABLE (Compendium pp.88-90)
## 2D6 expanded injury table (replaces standard 6-result table).
## ============================================================================

const DETAILED_INJURY_TABLE: Array[Dictionary] = [
	{
		"roll": 2,
		"id": "critical_injury",
		"name": "Critical Injury",
		"instruction": "INJURY (2): CRITICAL. Roll D6: 1-3 = death, 4-6 = permanent -1 to a random stat.",
	},
	{
		"roll": 3,
		"id": "severe_head",
		"name": "Severe Head Wound",
		"instruction": "INJURY (3): Severe Head Wound. 6 turns recovery, -1 Savvy during recovery. Surgery: 15 cr to halve recovery.",
	},
	{
		"roll": 4,
		"id": "severe_torso",
		"name": "Severe Torso Wound",
		"instruction": "INJURY (4): Severe Torso Wound. 5 turns recovery, -1 Toughness during recovery. Surgery: 12 cr to halve recovery.",
	},
	{
		"roll": 5,
		"id": "broken_limb",
		"name": "Broken Limb",
		"instruction": "INJURY (5): Broken Limb. 4 turns recovery, -1 Speed during recovery.",
	},
	{
		"roll": 6,
		"id": "moderate_wound",
		"name": "Moderate Wound",
		"instruction": "INJURY (6): Moderate Wound. 3 turns recovery, -1 Combat Skill during recovery.",
	},
	{
		"roll": 7,
		"id": "flesh_wound",
		"name": "Flesh Wound",
		"instruction": "INJURY (7): Flesh Wound. 2 turns recovery. No stat penalty.",
	},
	{
		"roll": 8,
		"id": "light_wound",
		"name": "Light Wound",
		"instruction": "INJURY (8): Light Wound. 2 turns recovery. No stat penalty.",
	},
	{
		"roll": 9,
		"id": "bruised",
		"name": "Bruised and Battered",
		"instruction": "INJURY (9): Bruised. 1 turn recovery. No stat penalty.",
	},
	{
		"roll": 10,
		"id": "knocked_out",
		"name": "Knocked Out",
		"instruction": "INJURY (10): Knocked out. 1 turn recovery. No stat penalty.",
	},
	{
		"roll": 11,
		"id": "minor_scratch",
		"name": "Minor Scratch",
		"instruction": "INJURY (11): Minor scratch. Cosmetic only, no recovery needed.",
	},
	{
		"roll": 12,
		"id": "miraculous",
		"name": "Miraculous Recovery",
		"instruction": "INJURY (12): MIRACULOUS! No injury. Gain +1 XP. D6 6 = gain Lucky trait.",
	},
]


## ============================================================================
## DRAMATIC COMBAT EFFECTS (Compendium p.92)
## Optional weapon-specific dramatic effects text.
## ============================================================================

const DRAMATIC_EFFECTS: Array[Dictionary] = [
	{
		"weapon_type": "blade",
		"instruction": "DRAMATIC: Blade strikes spark off armor. Describe the parry and riposte.",
	},
	{
		"weapon_type": "pistol",
		"instruction": "DRAMATIC: Pistol shot echoes through corridors. Describe the impact.",
	},
	{
		"weapon_type": "rifle",
		"instruction": "DRAMATIC: Rifle round pierces cover. Describe debris and suppression.",
	},
	{
		"weapon_type": "heavy",
		"instruction": "DRAMATIC: Heavy weapon devastates the area. Describe the destruction.",
	},
	{
		"weapon_type": "grenade",
		"instruction": "DRAMATIC: Explosion sends shrapnel flying. Describe the blast radius.",
	},
	{
		"weapon_type": "melee",
		"instruction": "DRAMATIC: Close quarters clash. Describe the grapple and struggle.",
	},
]


## ============================================================================
## QUERY METHODS (DLC-gated)
## ============================================================================

## Get all difficulty toggles. Empty if DLC not enabled.
static func get_difficulty_toggles() -> Array[Dictionary]:
	if not _is_flag_enabled("DIFFICULTY_TOGGLES"):
		return []
	var result: Array[Dictionary] = []
	result.assign(DIFFICULTY_TOGGLES)
	return result


## Get toggles filtered by category.
static func get_toggles_by_category(category: String) -> Array[Dictionary]:
	var toggles := get_difficulty_toggles()
	var filtered: Array[Dictionary] = []
	for t in toggles:
		if t.get("category", "") == category:
			filtered.append(t)
	return filtered


## Roll D6 for enemy AI behavior. Returns behavior dict or empty if disabled.
static func roll_ai_behavior() -> Dictionary:
	if not _is_flag_enabled("AI_VARIATIONS"):
		return {}
	var roll := randi_range(1, 6)
	for entry in AI_BEHAVIOR_TABLE:
		if entry.roll == roll:
			return entry
	return {}


## Get AI behavior by roll value.
static func get_ai_behavior(roll: int) -> Dictionary:
	if not _is_flag_enabled("AI_VARIATIONS"):
		return {}
	for entry in AI_BEHAVIOR_TABLE:
		if entry.roll == roll:
			return entry
	return {}


## Roll D6 for casualty result. Returns casualty dict or empty if disabled.
static func roll_casualty() -> Dictionary:
	if not _is_flag_enabled("CASUALTY_TABLES"):
		return {}
	var roll := randi_range(1, 6)
	for entry in CASUALTY_TABLE:
		if entry.roll == roll:
			return entry
	return {}


## Roll 2D6 for detailed injury. Returns injury dict or empty if disabled.
static func roll_detailed_injury() -> Dictionary:
	if not _is_flag_enabled("DETAILED_INJURIES"):
		return {}
	var roll := randi_range(1, 6) + randi_range(1, 6)
	for entry in DETAILED_INJURY_TABLE:
		if entry.roll == roll:
			return entry
	return {}


## Get dramatic effect text for a weapon type. Returns empty if disabled.
static func get_dramatic_effect(weapon_type: String) -> String:
	if not _is_flag_enabled("DRAMATIC_COMBAT"):
		return ""
	for entry in DRAMATIC_EFFECTS:
		if entry.weapon_type == weapon_type:
			return entry.instruction
	return ""


## Get all toggle categories.
static func get_categories() -> Array[String]:
	return [
		"encounter_scaling",
		"economy",
		"combat_difficulty",
		"time_pressure",
	]


## Get category display name.
static func get_category_name(category: String) -> String:
	match category:
		"encounter_scaling":
			return "Encounter Scaling"
		"economy":
			return "Economy & Progression"
		"combat_difficulty":
			return "Combat Difficulty"
		"time_pressure":
			return "Time Pressure"
	return category.capitalize()
