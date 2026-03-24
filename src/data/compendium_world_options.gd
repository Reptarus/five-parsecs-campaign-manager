class_name CompendiumWorldOptions
extends RefCounted
## Compendium World Options — Fringe World Strife, Expanded Loans, Name Tables
##
## Book-accurate data from Compendium pp.148-162.
## All output is TEXT INSTRUCTIONS for the tabletop companion model.
##
## Features:
##   FRINGE_WORLD_STRIFE - Instability tracking + D100 strife events (pp.148-153)
##   EXPANDED_LOANS      - Multi-step loan system: origin, interest, enforcement (pp.152-158)
##   NAME_GENERATION     - D100 tables for worlds, colonies, ships, corporate patrons (pp.157-162)
##   EXPANDED_FACTIONS   - DLC gate for existing FactionSystem
##   TERRAIN_GENERATION  - DLC gate for compendium terrain themes


## ============================================================================
## JSON DATA LOADING (RulesReference canonical, const fallback)
## ============================================================================

static var _ref_data: Dictionary = {}
static var _ref_loaded: bool = false

static func _ensure_ref_loaded() -> void:
	if _ref_loaded:
		return
	_ref_loaded = true
	# Load terrain tables and fringe world strife data
	for path in ["res://data/RulesReference/TerrainTables.json", "res://data/RulesReference/FringeWorldStrife"]:
		var file := FileAccess.open(path, FileAccess.READ)
		if file:
			var json := JSON.new()
			if json.parse(file.get_as_text()) == OK and json.data is Dictionary:
				_ref_data.merge(json.data)
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
## FRINGE WORLD STRIFE (Compendium pp.148-153)
##
## Mechanism: On arrival at new world, D6 4+ = Unstable (or 5+ for less chaos).
## Unstable worlds start at Instability +1. Each campaign turn (Invasion step):
##   +1D6 to instability
##   +1 per active Rival on this world
##   -1 if completed a Patron job this turn
##   -1 if Held the Field against a Roving Threat this turn
## If instability >= 10: roll D100 on STRIFE_EVENTS, reduce by listed amount.
## ============================================================================

const STRIFE_MECHANISM: String = (
	"FRINGE WORLD STRIFE: On arrival, roll D6. 4+ = Unstable (5+ for calmer setting).\n" +
	"Unstable worlds start at Instability +1.\n" +
	"Each campaign turn (Invasion step):\n" +
	"  +1D6 to Instability\n" +
	"  +1 per active Rival on this world\n" +
	"  -1 if you completed a Patron job this turn\n" +
	"  -1 if you Held the Field vs a Roving Threat this turn\n" +
	"If Instability >= 10: Roll D100 on Strife table, reduce by listed amount."
)

const STRIFE_EVENTS: Array[Dictionary] = [
	{
		"roll_min": 1, "roll_max": 10,
		"id": "hooligans",
		"name": "Hooligans",
		"instability_reduction": 5,
		"instruction": "STRIFE: Hooligans. -5 Instability. A bunch of roided-up hooligans cause a riot. You cannot perform any Explore or Trade crew actions during the next campaign turn.",
	},
	{
		"roll_min": 11, "roll_max": 24,
		"id": "criminal_gang",
		"name": "Criminal Gang",
		"instability_reduction": 5,
		"instruction": "STRIFE: Criminal Gang. -5 Instability. Roll on Criminal Elements table (core rules p.94). This gang threatens local businesses. All post-battle payouts on this world are reduced by 1 credit until cleared. To clear: set up a Fight Off mission. Add 1 Specialist and an Enemy Boss Unique Individual. +1 Story Point if you kill the boss in Brawling combat.",
	},
	{
		"roll_min": 25, "roll_max": 36,
		"id": "enemy_infiltration",
		"name": "Enemy Infiltration",
		"instability_reduction": 5,
		"instruction": "STRIFE: Enemy Infiltration. -5 Instability. A Converted Infiltrator squad (core rules p.101) has arrived. Use the Track crew action (like tracking a Rival) to find them. Fight Off mission: enemy has +1 Combat Skill and 1 additional Specialist. Must check for Invasion every campaign turn until squad is destroyed.",
	},
	{
		"roll_min": 37, "roll_max": 46,
		"id": "heating_up",
		"name": "Heating Up",
		"instability_reduction": 3,
		"instruction": "STRIFE: Heating Up. -3 Instability. Tensions getting out of hand. Add a Rival randomly selected from the Criminal Elements subtable (core rules p.94).",
	},
	{
		"roll_min": 47, "roll_max": 54,
		"id": "sabotage",
		"name": "Sabotage",
		"instability_reduction": 7,
		"instruction": "STRIFE: Sabotage. -7 Instability. During a running gun battle, your ship was caught in crossfire. Ship takes 1D6+1 points of hull damage.",
	},
	{
		"roll_min": 55, "roll_max": 66,
		"id": "raiders",
		"name": "Raiders",
		"instability_reduction": 7,
		"instruction": "STRIFE: Raiders. -7 Instability. Next campaign turn, attacked by scavengers. Resolve as Rival attack Raid scenario. Roll D6 for attackers: 1-2 Raiders, 3 Psychos, 4-5 Pirates, 6 Planetary Nomads. Add +2 to enemy numbers.",
	},
	{
		"roll_min": 67, "roll_max": 72,
		"id": "crackdown",
		"name": "Crackdown",
		"instability_reduction": 10,
		"instruction": "STRIFE: Crackdown. -10 Instability. Authorities making examples. Unless you leave next campaign turn, roll 3D6 in Upkeep step — discard every die showing 5 or 6, add remaining dice together and pay that many credits in fines, or have your ship confiscated.",
	},
	{
		"roll_min": 73, "roll_max": 86,
		"id": "economic_collapse",
		"name": "Economic Collapse",
		"instability_reduction": 10,
		"instruction": "STRIFE: Economic Collapse. -10 Instability. Cannot take Trade actions. All mission payouts -1 credit. Recovery: after each mission, roll D6 (+1 if Patron job, +4 if Quest). On 6+, economic malaise is over.",
	},
	{
		"roll_min": 87, "roll_max": 94,
		"id": "invasion_imminent",
		"name": "Invasion Imminent",
		"instability_reduction": 0,
		"instruction": "STRIFE: Invasion Imminent! Instability no longer tracked. After the next campaign turn, the world is automatically invaded. Roll D6 for invaders: 1-2 Converted Acquisition, 3 Abductor Raiders, 4-5 Swarm Brood, 6 K'Erin Colonists.",
	},
	{
		"roll_min": 95, "roll_max": 100,
		"id": "civil_war",
		"name": "Civil War",
		"instability_reduction": 0,
		"instruction": "STRIFE: Civil War! Instability no longer tracked. World erupts in shooting war next turn. If you stay: roll twice on Interested Parties table (core rules p.99) — choose a side. Each mission is Opportunity vs opposing force, +2 regular +1 Specialist enemies, +1 credit per mission. Use Galactic War Progress (core rules p.126). Unity Victorious = 1D6 credits bonus + remove 1 Rival. Lost to Unity = ship + credits confiscated, booted off-world.",
	},
]


## ============================================================================
## EXPANDED LOANS (Compendium pp.152-158)
##
## Step 1: Loan Origin (D100)
## Step 2: Loan Amount (ship cost + fees)
## Step 3: Interest Rate (D100) — low/high columns
## Step 4: Enforcement Thresholds (D100) — two threshold values
## Enforcement: Different D100 ranges per origin type
## ============================================================================

const LOAN_ORIGINS: Array[Dictionary] = [
	{"roll_min": 1, "roll_max": 15, "id": "unity_program",
	 "name": "Unity Program",
	 "fee_adjustment": "+5 credits (fees and paperwork)",
	 "instruction": "LOAN ORIGIN: Unity Program. Unity-funded org sponsors starship loans for economic development. Add +5 credits to loan amount for fees."},
	{"roll_min": 16, "roll_max": 25, "id": "sector_government",
	 "name": "Sector Government Program",
	 "fee_adjustment": "none",
	 "instruction": "LOAN ORIGIN: Sector Government. Multi-system governments view private traders as valuable. Standard loan terms."},
	{"roll_min": 26, "roll_max": 60, "id": "corporate",
	 "name": "Corporate",
	 "fee_adjustment": "none",
	 "instruction": "LOAN ORIGIN: Corporate. Funding freelancers as investment (or tax write-off). Standard loan terms."},
	{"roll_min": 61, "roll_max": 85, "id": "free_trader",
	 "name": "Free Trader",
	 "fee_adjustment": "+1D6 credits (personal whims)",
	 "instruction": "LOAN ORIGIN: Free Trader. Private loan from a trader who made it big. Add +1D6 credits to loan amount."},
	{"roll_min": 86, "roll_max": 100, "id": "suspicious_character",
	 "name": "Suspicious Character",
	 "fee_adjustment": "+1D6 credits (personal whims)",
	 "instruction": "LOAN ORIGIN: Suspicious Character. Shady deal with questionable terms. Add +1D6 credits to loan amount."},
]

const INTEREST_RATES: Array[Dictionary] = [
	{"roll_min": 1, "roll_max": 10, "id": "very_cheap",
	 "name": "Very Cheap", "low": 1, "high": 1,
	 "note": "Free Trader treats this as Cheap instead.",
	 "instruction": "INTEREST: Very Cheap. Low debt (<=30cr): +1/turn. High debt (>30cr): +1/turn. Note: Free Trader → Cheap."},
	{"roll_min": 11, "roll_max": 40, "id": "cheap",
	 "name": "Cheap", "low": 1, "high": 2,
	 "note": "",
	 "instruction": "INTEREST: Cheap. Low debt (<=30cr): +1/turn. High debt (>30cr): +2/turn."},
	{"roll_min": 41, "roll_max": 70, "id": "average",
	 "name": "Average", "low": 1, "high": 3,
	 "note": "",
	 "instruction": "INTEREST: Average. Low debt (<=30cr): +1/turn. High debt (>30cr): +3/turn."},
	{"roll_min": 71, "roll_max": 85, "id": "expensive",
	 "name": "Expensive", "low": 2, "high": 3,
	 "note": "Suspicious Character treats this as Very Expensive instead.",
	 "instruction": "INTEREST: Expensive. Low debt (<=30cr): +2/turn. High debt (>30cr): +3/turn. Note: Suspicious Character → Very Expensive."},
	{"roll_min": 86, "roll_max": 100, "id": "very_expensive",
	 "name": "Very Expensive", "low": 2, "high": -1,
	 "note": "High interest = 1D6 rolled each turn. Unity Program treats this as Expensive instead.",
	 "instruction": "INTEREST: Very Expensive. Low debt (<=30cr): +2/turn. High debt (>30cr): +1D6/turn. Note: Unity Program → Expensive."},
]

const ENFORCEMENT_THRESHOLDS: Array[Dictionary] = [
	{"roll_min": 1, "roll_max": 10, "id": "very_casual",
	 "name": "Very Casual", "threshold_1": 75, "threshold_2": 90,
	 "instruction": "ENFORCEMENT: Very Casual. Threshold 1: 75 credits. Threshold 2: 90 credits."},
	{"roll_min": 11, "roll_max": 20, "id": "casual",
	 "name": "Casual", "threshold_1": 65, "threshold_2": 80,
	 "instruction": "ENFORCEMENT: Casual. Threshold 1: 65 credits. Threshold 2: 80 credits."},
	{"roll_min": 21, "roll_max": 45, "id": "moderate",
	 "name": "Moderate", "threshold_1": 60, "threshold_2": 75,
	 "instruction": "ENFORCEMENT: Moderate. Threshold 1: 60 credits. Threshold 2: 75 credits."},
	{"roll_min": 46, "roll_max": 75, "id": "aggressive",
	 "name": "Aggressive", "threshold_1": 55, "threshold_2": 70,
	 "instruction": "ENFORCEMENT: Aggressive. Threshold 1: 55 credits. Threshold 2: 70 credits."},
	{"roll_min": 76, "roll_max": 100, "id": "very_aggressive",
	 "name": "Very Aggressive", "threshold_1": 50, "threshold_2": 65,
	 "instruction": "ENFORCEMENT: Very Aggressive. Threshold 1: 50 credits. Threshold 2: 65 credits."},
]

## Enforcement methods — D100 ranges differ by loan origin type
## Columns: unity_program, sector_government, corporate, free_trader, suspicious_character
const ENFORCEMENT_METHODS: Array[Dictionary] = [
	{"id": "fees", "name": "Fees and Penalties",
	 "ranges": {"unity_program": [1, 20], "sector_government": [1, 20], "corporate": [1, 30], "free_trader": [1, 15], "suspicious_character": [1, 25]},
	 "amounts": {"unity_program": "+5 credits", "sector_government": "+5 credits", "corporate": "+6 credits", "free_trader": "+1D6+2 credits", "suspicious_character": "+2D6 credits"},
	 "instruction": "ENFORCEMENT: Fees. A loan fee is added to the loan. May trigger further enforcement."},
	{"id": "collectors", "name": "Collectors",
	 "ranges": {"unity_program": [21, 35], "sector_government": [21, 35], "corporate": [31, 55], "free_trader": [16, 40], "suspicious_character": [26, 40]},
	 "instruction": "ENFORCEMENT: Collectors. Each Upkeep step, roll 1D6+1. If <= turns on current world, they catch you: fine of 3D6 credits. Can't pay = added to loan + Bounty Hunter Rival. Then remove Collectors. Can have multiple Collectors at once."},
	{"id": "collectors_fringe", "name": "Collectors, Fringe-style",
	 "ranges": {"unity_program": [36, 45], "sector_government": [36, 50], "corporate": [56, 70], "free_trader": [41, 65], "suspicious_character": [41, 75]},
	 "instruction": "ENFORCEMENT: Collectors, Fringe-style. Armed collectors added as Rival. Treated as normal Rival — won't stop even if you pay up. Must be dealt with. Can pay 10 credits to remove them from roster."},
	{"id": "temporary_seizure", "name": "Temporary Seizure",
	 "ranges": {"unity_program": [46, 75], "sector_government": [51, 75], "corporate": [71, 85], "free_trader": [66, 80], "suspicious_character": [76, 85]},
	 "instruction": "ENFORCEMENT: Temporary Seizure. Warrant for ship. Each turn roll 2D6: on 2-5, ship seized until debt reduced to 10 credits below seizure amount. Interest accrues unless Unity/Sector Government. Multiple rolls increase seizure range by 1 each time."},
	{"id": "permanent_seizure", "name": "Permanent Seizure",
	 "ranges": {"unity_program": [76, 100], "sector_government": [76, 100], "corporate": [86, 100], "free_trader": [81, 100], "suspicious_character": [86, 100]},
	 "instruction": "ENFORCEMENT: Permanent Seizure. Warrant for ship. Each turn roll 2D6: on 2-6, ship permanently lost. Cancel by reducing debt to 10 credits below seizure amount. Multiple rolls increase range by 1."},
]

## Collection squad types by loan origin
const COLLECTION_SQUAD_TYPES: Dictionary = {
	"unity_program": "Unity grunts",
	"sector_government": "Enforcers",
	"corporate": "Corporate security",
	"free_trader": "Bounty hunters",
	"suspicious_character": "Bounty hunters",
}

const FIGHT_SEIZURE_INSTRUCTION: String = (
	"FIGHT SEIZURE: Set up battle vs Enforcers (core rules p.96), +2 basic enemies. " +
	"Deploy center, 12\"+ from edges. Enemy from 2 random edges, split evenly. " +
	"Randomly determine your escape edge. If at least 1 crew escapes, you leave off-world. " +
	"Warrant remains, Enforcer Rival added."
)


## ============================================================================
## NAME GENERATION TABLES (Compendium pp.157-162)
## All D100 tables with 25 entries each (4-number ranges).
## ============================================================================

## World Names: D100 for system name + D6 for planet number (e.g., "Gough III")
const WORLD_NAMES: Array[String] = [
	"Samsonov", "Foch", "Pershing", "Cadorna", "Monash",
	"Mackensen", "Falkenhayn", "Byng", "Lanrezac", "Allenby",
	"Gough", "Currie", "Danilov", "Joffre", "Petain",
	"Brusilov", "Potiorek", "Putnik", "Fuller", "Birdwood",
	"Moltke", "Sarrail", "Goltz", "Maude", "Nivelle",
]

## Colony Names Part 1 (D100, possessive names)
const COLONY_PART1: Array[String] = [
	"Ingram's", "Larsen's", "Greenway's", "Mustaine's", "Kevill's",
	"Duplantier's", "Sattler's", "Hetfield's", "Friden's", "Ryan's",
	"Gossow's", "Parkes'", "Hegg's", "Dickinson's", "Shelton's",
	"Scalzi's", "Lindberg's", "Willet's", "Halford's", "Baker's",
	"Lee's", "Cavaleras'", "Plant's", "Nasic's", "Bryntse's",
]

## Colony Names Part 2 (D100, geographic suffixes)
const COLONY_PART2: Array[String] = [
	"Ridge", "Peace", "Sanctuary", "Mile", "Road",
	"Hope", "Preserve", "Point", "Landing", "Creek",
	"Valley", "Gorge", "Redemption", "Rise", "Drift",
	"Field", "Place", "Port", "Hills", "Salvation",
	"Prayer", "Isolation", "Reach", "Entry", "Rest",
]

## Ship Names Part 1 (D100, adjectives — "The [Adj] [Noun]")
const SHIP_PART1: Array[String] = [
	"Exuberant", "Chivalrous", "Dependable", "Adventurous", "Fierce",
	"Invincible", "Plucky", "Determined", "Majestic", "Brave",
	"Independent", "Reliable", "Proud", "Loyal", "Furious",
	"Courageous", "Ambitious", "Regal", "Stalwart", "Fearsome",
	"Magnificent", "Unsurpassable", "Inexhaustible", "Indispensable", "Curious",
]

## Ship Names Part 2 (D100, nouns)
const SHIP_PART2: Array[String] = [
	"Otter", "Traveler", "Badger", "Hedgehog", "Weasel",
	"Dingo", "Explorer", "Rabbit", "Way", "Ferret",
	"Cougar", "Pathfinder", "Beaver", "Mongoose", "Raccoon",
	"Squirrel", "Scout", "Tidings", "Possum", "Hamster",
	"Intruder", "Outrider", "Hawk", "Falcon", "Wasp",
]

## Corporate Patron Names Part 1 (D100, adjectives)
const CORP_PART1: Array[String] = [
	"Interstellar", "Agile", "Calibrated", "Synergistic", "Customized",
	"Unified", "Galactic", "Optimized", "Accelerated", "Xenomorphic",
	"Diversified", "Conglomerated", "United", "Responsive", "Integrated",
	"Universal", "Associated", "Incorporated", "Dynamic", "Reactive",
	"Advanced", "Optimized", "Sector", "Extra-solar", "Orbital",
]

## Corporate Patron Names Part 2 (D100, business nouns)
const CORP_PART2: Array[String] = [
	"Implementations", "Solutions", "Sequences", "Aggregates", "Enterprises",
	"Deliveries", "Composites", "Amalgamations", "Connections", "Executives",
	"Holdings", "Acquisitions", "Logistics", "Resolutions", "Defenses",
	"Securities", "Procurements", "Proficiencies", "Resources", "Operations",
	"Accounts", "Assets", "Interactions", "Equities", "Investments",
]


## ============================================================================
## QUERY METHODS
## ============================================================================

## Check if world is unstable on arrival. D6 4+ (or 5+ if less chaotic).
static func check_world_unstable(use_calmer_setting: bool = false) -> bool:
	var threshold := 5 if use_calmer_setting else 4
	return randi_range(1, 6) >= threshold


## Roll instability change for this campaign turn.
## Returns the new instability delta (always positive before modifiers).
static func roll_instability_delta(active_rivals: int, patron_job: bool, held_field_roving: bool) -> int:
	var delta := randi_range(1, 6)
	delta += active_rivals
	if patron_job:
		delta -= 1
	if held_field_roving:
		delta -= 1
	return maxi(delta, 0)


## Roll a Fringe World Strife event (D100). Returns empty if DLC disabled.
static func roll_strife_event() -> Dictionary:
	if not _is_flag_enabled("FRINGE_WORLD_STRIFE"):
		return {}
	var roll := randi_range(1, 100)
	for event in STRIFE_EVENTS:
		if roll >= event.roll_min and roll <= event.roll_max:
			var result: Dictionary = event.duplicate()
			result["roll"] = roll
			return result
	return STRIFE_EVENTS[0]


## Check if strife should be checked (legacy compat — prefer check_world_unstable).
static func should_check_strife(is_fringe_world: bool) -> bool:
	if not _is_flag_enabled("FRINGE_WORLD_STRIFE"):
		return false
	if not is_fringe_world:
		return false
	return check_world_unstable()


## Roll loan origin (D100). Returns empty if DLC disabled.
static func roll_loan_origin() -> Dictionary:
	if not _is_flag_enabled("EXPANDED_LOANS"):
		return {}
	var roll := randi_range(1, 100)
	for origin in LOAN_ORIGINS:
		if roll >= origin.roll_min and roll <= origin.roll_max:
			var result: Dictionary = origin.duplicate()
			result["roll"] = roll
			return result
	return LOAN_ORIGINS[0]


## Roll interest rate (D100). Returns empty if DLC disabled.
static func roll_interest_rate() -> Dictionary:
	if not _is_flag_enabled("EXPANDED_LOANS"):
		return {}
	var roll := randi_range(1, 100)
	for rate in INTEREST_RATES:
		if roll >= rate.roll_min and roll <= rate.roll_max:
			var result: Dictionary = rate.duplicate()
			result["roll"] = roll
			return result
	return INTEREST_RATES[0]


## Roll enforcement threshold (D100). Returns empty if DLC disabled.
static func roll_enforcement_threshold() -> Dictionary:
	if not _is_flag_enabled("EXPANDED_LOANS"):
		return {}
	var roll := randi_range(1, 100)
	for threshold in ENFORCEMENT_THRESHOLDS:
		if roll >= threshold.roll_min and roll <= threshold.roll_max:
			var result: Dictionary = threshold.duplicate()
			result["roll"] = roll
			return result
	return ENFORCEMENT_THRESHOLDS[0]


## Determine enforcement method for a given origin type. D100 roll.
static func roll_enforcement_method(origin_id: String) -> Dictionary:
	if not _is_flag_enabled("EXPANDED_LOANS"):
		return {}
	var roll := randi_range(1, 100)
	for method in ENFORCEMENT_METHODS:
		var ranges: Dictionary = method.get("ranges", {})
		if ranges.has(origin_id):
			var r: Array = ranges[origin_id]
			if roll >= r[0] and roll <= r[1]:
				var result: Dictionary = method.duplicate()
				result["roll"] = roll
				result["origin"] = origin_id
				if method.has("amounts") and method.amounts.has(origin_id):
					result["amount"] = method.amounts[origin_id]
				return result
	return ENFORCEMENT_METHODS[0]


## Calculate interest for a turn given current debt and rate tier.
static func calculate_interest(current_debt: int, rate: Dictionary) -> int:
	if current_debt <= 30:
		return rate.get("low", 1)
	var high_val: int = rate.get("high", 1)
	if high_val < 0:
		# Very Expensive: roll 1D6 each turn for high debt
		return randi_range(1, 6)
	return high_val


## Pick from a 25-entry D100 name array (each entry covers 4 numbers).
static func _pick_from_d100_array(arr: Array) -> String:
	if arr.is_empty():
		return ""
	var roll := randi_range(1, 100)
	var index := clampi((roll - 1) / 4, 0, arr.size() - 1)
	return arr[index]


## Generate a world name: "[System] [Roman numeral]" (D100 + D6).
static func generate_world_name() -> String:
	if not _is_flag_enabled("NAME_GENERATION"):
		return ""
	var system := _pick_from_d100_array(WORLD_NAMES)
	var planet_num := randi_range(1, 6)
	var roman := ["I", "II", "III", "IV", "V", "VI"]
	return system + " " + roman[planet_num - 1]


## Generate a colony name: "[Possessive] [Suffix]" (D100 × 2).
static func generate_colony_name() -> String:
	if not _is_flag_enabled("NAME_GENERATION"):
		return ""
	return _pick_from_d100_array(COLONY_PART1) + " " + _pick_from_d100_array(COLONY_PART2)


## Generate a ship name: "The [Adj] [Noun]" (D100 × 2).
## For naval feel, use Part 1 only with "The" prefix.
static func generate_ship_name(naval_style: bool = false) -> String:
	if not _is_flag_enabled("NAME_GENERATION"):
		return ""
	var adj := _pick_from_d100_array(SHIP_PART1)
	if naval_style:
		return "The " + adj
	return "The " + adj + " " + _pick_from_d100_array(SHIP_PART2)


## Generate a corporate patron name: "[Adj] [Business Noun]" (D100 × 2).
static func generate_corporate_name() -> String:
	if not _is_flag_enabled("NAME_GENERATION"):
		return ""
	return _pick_from_d100_array(CORP_PART1) + " " + _pick_from_d100_array(CORP_PART2)


## Generate a random name for a species (character names — not in Compendium,
## kept for UI compatibility). Falls back to world name generator for unknown.
static func generate_name(species: String) -> String:
	if not _is_flag_enabled("NAME_GENERATION"):
		return ""
	# Character species names are not in the Compendium name tables.
	# Use the ship adjective list + world name list as creative fallback.
	var first := _pick_from_d100_array(SHIP_PART1)
	var last := _pick_from_d100_array(WORLD_NAMES)
	return first + " " + last


## Check if expanded factions should be active.
static func is_expanded_factions_enabled() -> bool:
	return _is_flag_enabled("EXPANDED_FACTIONS")


## Check if compendium terrain generation should be active.
static func is_terrain_generation_enabled() -> bool:
	return _is_flag_enabled("TERRAIN_GENERATION")
