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
## JSON DATA LOADING (RulesReference canonical, const fallback)
## ============================================================================

static var _ref_data: Dictionary = {}
static var _ref_loaded: bool = false

static func _ensure_ref_loaded() -> void:
	if _ref_loaded:
		return
	_ref_loaded = true
	var path := "res://data/RulesReference/DifficultyOptions.json"
	if not FileAccess.file_exists(path):
		return
	var file := FileAccess.open(path, FileAccess.READ)
	if not file:
		return
	var json := JSON.new()
	if json.parse(file.get_as_text()) == OK and json.data is Dictionary:
		_ref_data = json.data
	file.close()

static func get_ref_data() -> Dictionary:
	_ensure_ref_loaded()
	return _ref_data


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
## DIFFICULTY TOGGLES (Compendium pp.34-36)
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
		"description": "Increased XP costs and unchanged max levels: Reactions 8 XP (max 4), Combat Skill 8 XP (max +3), Speed 5 XP (max 8\"), Savvy 5 XP (max +5), Toughness 8 XP (max 5), Luck 10 XP (max 3).",
		"instruction": "PROGRESSION: XP costs — Reactions 8 (max 4), Combat 8 (max +3), Speed 5 (max 8\"), Savvy 5 (max +5), Toughness 8 (max 5), Luck 10 (max 3).",
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
		"description": "Unique Individuals appear on 7+ (not 9+). For enemy types that cannot have a Unique Individual, a random enemy gets +2 Combat Skill and +2 Toughness (max +4 / T6).",
		"instruction": "COMBAT: Unique Individuals on 7+ (not 9+). If enemy type has no UI, a random enemy gets +2 Combat/Toughness (max +4/T6).",
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
		"description": "Each round including the first: Roll D6. If result <= round number, +1 enemy arrives.",
		"instruction": "TIME: Each round (including Round 1), roll D6. If D6 <= round number, +1 enemy spawns.",
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
		"description": "Three sub-options (use 1-3): (1) Start with only 3 Low-Tech Weapons rolls + 1 Gear or Gadget roll, no free Military/Hi-Tech rolls, no 1cr/crew. (2) Begin with only 3 crew instead of 6. (3) Begin without a ship — must purchase one (Core Rules p.60).",
		"instruction": "START: (1) Only 3 Low-Tech + 1 Gear/Gadget roll, no Military/Hi-Tech, no 1cr/crew. (2) Only 3 crew. (3) No starting ship.",
	},
	{
		"id": "reduced_lethality",
		"name": "Reduced Lethality",
		"category": "combat_difficulty",
		"dlc_flag": "DIFFICULTY_TOGGLES",
		"description": "Before rolling post-battle injuries, if 2+ characters are injured, select one to be exempt — they recover fully with no Sick Bay time (works for biological, Soulless, or Bot). If only 1 character is injured, roll normally.",
		"instruction": "COMBAT: If 2+ injured post-battle, exempt 1 from injury roll (full recovery, no Sick Bay). If only 1 injured, roll normally.",
	},
]


## ============================================================================
## D6 AI TYPE SELECTOR (simplified from AI Variations, Compendium pp.42-43)
## Roll D6 per enemy group to determine their AI type.
## Full AI Variations have per-type D6 action tables — see pp.42-43 for details.
## AI Variations (Compendium pp.42-43): Per-type D6 action tables for known AI types.
## Beast, Rampage, and Guardian AI function unchanged (no D6 roll needed).
## Figures within 2" of each other share the same D6 roll (group actions).
## ============================================================================

const AI_VARIATION_TABLES: Dictionary = {
	"cautious": {
		"base_condition": "If in Cover and visible opponents within 12\", move away to most distant position that remains in Cover and in range with Line of Sight, then fire.",
		"actions": [
			{"roll": 1, "action": "Retreat a full move, remaining in Cover. Maintain Line of Sight if possible."},
			{"roll": 2, "action": "Remain in place or maneuver within current Cover to fire."},
			{"roll": 3, "action": "Remain in place or maneuver within current Cover to fire."},
			{"roll": 4, "action": "Advance to within 12\" of the nearest enemy and fire. Remain in Cover."},
			{"roll": 5, "action": "Advance to within 12\" of the nearest enemy and fire. Remain in Cover."},
			{"roll": 6, "action": "Advance on the nearest enemy and fire, ending in Cover if possible."},
		],
	},
	"aggressive": {
		"base_condition": "If able to engage an opponent in brawling combat this round, advance to do so.",
		"actions": [
			{"roll": 1, "action": "Maneuver within current Cover to fire."},
			{"roll": 2, "action": "Maneuver within current Cover to fire."},
			{"roll": 3, "action": "Advance to the next forward position in Cover. Fire if eligible."},
			{"roll": 4, "action": "Advance and fire on the nearest enemy. Use Cover."},
			{"roll": 5, "action": "Advance and fire on the nearest enemy. Fastest route."},
			{"roll": 6, "action": "Dash towards the nearest enemy. Fastest route."},
		],
	},
	"tactical": {
		"base_condition": "If in Cover and within 12\" of visible opponents, remain in position and fire.",
		"actions": [
			{"roll": 1, "action": "Remain in place to fire."},
			{"roll": 2, "action": "Maneuver within current Cover to fire."},
			{"roll": 3, "action": "Advance to the next forward position in Cover or move to flank."},
			{"roll": 4, "action": "Advance to the next forward position in Cover or move to flank."},
			{"roll": 5, "action": "Advance and fire on the nearest enemy. Use Cover."},
			{"roll": 6, "action": "Advance and fire on the nearest enemy. Use Cover."},
		],
	},
	"defensive": {
		"base_condition": "If in Cover and opponents in the open are visible, remain in position and fire.",
		"actions": [
			{"roll": 1, "action": "Remain in place to fire."},
			{"roll": 2, "action": "Maneuver within current Cover to fire."},
			{"roll": 3, "action": "Maneuver within current Cover to fire."},
			{"roll": 4, "action": "Maneuver within current Cover to fire."},
			{"roll": 5, "action": "Advance to the next forward position in Cover."},
			{"roll": 6, "action": "Advance and fire on the nearest enemy. Use Cover."},
		],
	},
}

## Legacy alias — code may reference AI_BEHAVIOR_TABLE. Returns empty since structure changed.
const AI_BEHAVIOR_TABLE: Array[Dictionary] = []


## ============================================================================
## CASUALTY TABLES (Compendium pp.99-100) — 3 tables by creature type.
## Roll D6 when a figure would become a casualty. Regular column for crew/normal enemies,
## Boss column for captains/leaders/unique. Multiple hits: roll all, apply highest single result.
## If event causes auto-casualty (no Toughness roll), casualty tables are NOT used.
## Critical Hit optional rule: natural 6 to Hit = roll one extra on Casualty table, use highest.
## ============================================================================

const CASUALTY_TABLES: Dictionary = {
	"humanoid": {
		"name": "Table 1: Humanoid Combatants",
		"entries": [
			{"regular": [1, 2], "boss": [1, 2], "outcome": "Dazed", "effect": "On their next activation, they do not remove a Stun marker automatically. Ignore this result if already Dazed."},
			{"regular": [3, 4], "boss": [3, 5], "outcome": "Wounded", "effect": "Move at half speed. Reduce Combat Skill by 1 (can go to -1). If Wounded again, they are a Goner."},
			{"regular": [5, 6], "boss": [6, 6], "outcome": "Goner", "effect": "The character is removed from play."},
		],
	},
	"cybernetic": {
		"name": "Table 2: Cybernetic Combatants (Soulless, Converted, Bots)",
		"entries": [
			{"regular": [1, 2], "boss": [1, 2], "outcome": "Temporary Shutdown", "effect": "On their next activation, do not remove a Stun marker automatically. Ignore if already shut down."},
			{"regular": [3, 4], "boss": [3, 5], "outcome": "Damaged", "effect": "Mark with token. Every activation, roll D6: on 6, falls apart and removed. Multiple instances no effect. +1 to future casualty rolls."},
			{"regular": [5, 6], "boss": [6, 6], "outcome": "Goner", "effect": "The character is removed from play."},
		],
	},
	"beast": {
		"name": "Table 3: Beasts and Monsters",
		"entries": [
			{"regular": [1, 2], "boss": [1, 2], "outcome": "Knock down / Drive off", "effect": "Move 2\" directly away from the firer per hit inflicted by the attack."},
			{"regular": [3, 4], "boss": [3, 5], "outcome": "Bleeding", "effect": "Roll D6 at end of next activation: On 1, Bleeding ends. On 6, they are a Goner. +1 to future injury rolls. Multiple instances no effect."},
			{"regular": [5, 6], "boss": [6, 6], "outcome": "Goner", "effect": "The character is removed from play."},
		],
	},
	"_cleanup": "All Bleeding/Damaged/Wounded conditions removed at end of battle, no long-term effects.",
}

## Legacy alias — old code may reference CASUALTY_TABLE
const CASUALTY_TABLE: Array[Dictionary] = []


## ============================================================================
## DETAILED INJURY TABLE (Compendium pp.88-90)
## DETAILED POST-BATTLE INJURIES (Compendium pp.101-102) — D100 table, replaces Core Rules injury table.
## Synthetic characters (Bots/Soulless) still use the Core Rules Bot Injury table.
## Medical facilities: Roll 1D6 — 1-2 = crew member Savvy test 6+ to find off-world medic (+1cr fee), 3-6 = available.
## ============================================================================

const DETAILED_INJURY_TABLE: Array[Dictionary] = [
	{"roll_min": 0, "roll_max": 10, "id": "death", "name": "Death",
	 "effect": "The character is slain. A random item they carried is damaged.",
	 "sick_bay": -1},
	{"roll_min": 11, "roll_max": 15, "id": "critical_strike", "name": "Critical Strike",
	 "effect": "Is the character wearing Armor? If so, they survive but the armor is damaged. Otherwise, they are slain.",
	 "sick_bay_roll": "1D6+3"},
	{"roll_min": 16, "roll_max": 20, "id": "extensive_injury", "name": "Extensive Injury",
	 "effect": "Requires specialized treatment. Roll 1D6+1 for cost in Credits. Cannot take crew tasks or fight until paid. Sick Bay begins after treatment.",
	 "sick_bay": -2, "treatment_cost_roll": "1D6+1"},
	{"roll_min": 21, "roll_max": 30, "id": "item_hit", "name": "Item Hit",
	 "effect": "Randomly select a carried item and roll 1D6. On 1-4 it is damaged. On 5-6 it is destroyed.",
	 "sick_bay": 0},
	{"roll_min": 31, "roll_max": 40, "id": "lingering_injury", "name": "Lingering Injury",
	 "effect": "After recovery, before every mission roll 1D6: On 1, cannot participate. On 2-5, fine. On 6, fully recovered (remove condition). Multiple lingering injuries roll separately.",
	 "sick_bay_roll": "1D6+1"},
	{"roll_min": 41, "roll_max": 50, "id": "injured_arm", "name": "Injured Arm",
	 "effect": "Combat Skill counts as 1 lower (min -1) when firing non-Pistol weapons or Brawling. 3 Credits medical treatment to remove.",
	 "sick_bay_roll": "1D3", "treatment_cost": 3},
	{"roll_min": 51, "roll_max": 60, "id": "injured_leg", "name": "Injured Leg",
	 "effect": "Reduce Speed by 1\". 3 Credits medical treatment to remove.",
	 "sick_bay_roll": "1D3", "treatment_cost": 3},
	{"roll_min": 61, "roll_max": 70, "id": "injured_torso", "name": "Injured Torso",
	 "effect": "Knocked out after two Stun markers instead of three. 3 Credits medical treatment to remove.",
	 "sick_bay_roll": "1D3", "treatment_cost": 3},
	{"roll_min": 71, "roll_max": 75, "id": "serious_injury", "name": "Serious Injury",
	 "effect": "No side effects.",
	 "sick_bay_roll": "1D3+1"},
	{"roll_min": 76, "roll_max": 80, "id": "minor_injury", "name": "Minor Injury",
	 "effect": "No side effects.",
	 "sick_bay": 1},
	{"roll_min": 81, "roll_max": 95, "id": "knocked_out", "name": "Knocked Out",
	 "effect": "No side effects.",
	 "sick_bay": 0},
	{"roll_min": 96, "roll_max": 100, "id": "school_of_hard_knocks", "name": "School of Hard Knocks",
	 "effect": "+1 XP.",
	 "sick_bay": 0},
]


## ============================================================================
## DRAMATIC COMBAT (Compendium pp.87-89) — Lunging mechanic + Dramatic Weapons.
## Dramatic Weapons table changes many weapon stats from Core Rules — see Compendium pp.88-89.
## ============================================================================

const DRAMATIC_COMBAT_RULES: Dictionary = {
	"lunging": {
		"description": "A Lunging character is immediately moved a full move towards the shooter, attempting to enter Brawling combat.",
		"movement_reduction_ignore": 2,
		"per_round_limit": 1,
		"is_bonus_action": true,
		"instruction": "DRAMATIC COMBAT: Lunging — character moves full move toward shooter to Brawl. Ignores up to 2\" movement reduction. Once per round. Does not affect normal activation.",
	},
	"dramatic_weapons_note": "If using Dramatic Weapons (Compendium pp.88-89), many weapon stats change (e.g., Blade +1 Damage, Blast Pistol 6\" range, Boarding Saber +2 Damage, etc.). Use with Adjusted Shooting hit numbers from p.87.",
}

## Legacy alias — old code may reference DRAMATIC_EFFECTS
const DRAMATIC_EFFECTS: Array[Dictionary] = []


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
