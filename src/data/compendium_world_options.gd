class_name CompendiumWorldOptions
extends RefCounted
## Compendium World Options - Fringe World Strife, Expanded Loans, Name Tables
##
## Data-driven world system additions from the Compendium.
## All output is TEXT INSTRUCTIONS for the tabletop companion model.
##
## Features:
##   FRINGE_WORLD_STRIFE - Instability events per world (Fixer's Guidebook)
##   EXPANDED_LOANS      - Loan origin types with interest/enforcement (Fixer's Guidebook)
##   NAME_GENERATION     - Species-specific name tables (Fixer's Guidebook)
##   EXPANDED_FACTIONS   - DLC gate for existing FactionSystem (Fixer's Guidebook)
##   TERRAIN_GENERATION  - DLC gate for compendium terrain themes (Freelancer's Handbook)


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
## FRINGE WORLD STRIFE (Compendium pp.110-114)
## Check at world arrival and post-battle. Instability 0-10 scale.
## ============================================================================

const STRIFE_EVENTS: Array[Dictionary] = [
	{
		"roll_min": 1, "roll_max": 10,
		"id": "civil_unrest",
		"name": "Civil Unrest",
		"instability_mod": 1,
		"instruction": "STRIFE: Civil Unrest. +1 Instability. Patrols increased - D6: 1-2 = encounter Enforcers before mission.",
	},
	{
		"roll_min": 11, "roll_max": 20,
		"id": "supply_shortage",
		"name": "Supply Shortage",
		"instability_mod": 0,
		"instruction": "STRIFE: Supply Shortage. All shop prices +50% this turn. Medical supplies unavailable.",
	},
	{
		"roll_min": 21, "roll_max": 30,
		"id": "gang_war",
		"name": "Gang War",
		"instability_mod": 2,
		"instruction": "STRIFE: Gang War. +2 Instability. +1 enemy per encounter. D6: 5-6 = caught in crossfire (D6 damage to random crew).",
	},
	{
		"roll_min": 31, "roll_max": 40,
		"id": "martial_law",
		"name": "Martial Law",
		"instability_mod": -1,
		"instruction": "STRIFE: Martial Law declared. -1 Instability. Weapons restricted - carrying visible weapons = Enforcer encounter.",
	},
	{
		"roll_min": 41, "roll_max": 50,
		"id": "refugee_crisis",
		"name": "Refugee Crisis",
		"instability_mod": 1,
		"instruction": "STRIFE: Refugee Crisis. +1 Instability. Recruitment costs halved. +1 potential recruit available.",
	},
	{
		"roll_min": 51, "roll_max": 60,
		"id": "economic_boom",
		"name": "Economic Boom",
		"instability_mod": -1,
		"instruction": "STRIFE: Economic Boom! -1 Instability. All mission rewards +2 credits. Trade items -20% price.",
	},
	{
		"roll_min": 61, "roll_max": 70,
		"id": "pirate_raids",
		"name": "Pirate Raids",
		"instability_mod": 2,
		"instruction": "STRIFE: Pirate Raids. +2 Instability. Travel events: +1 to hostile encounter rolls. Bounty missions available (+3 cr bonus).",
	},
	{
		"roll_min": 71, "roll_max": 80,
		"id": "plague_outbreak",
		"name": "Plague Outbreak",
		"instability_mod": 1,
		"instruction": "STRIFE: Plague Outbreak. +1 Instability. Each crew member: D6 1 = sick (miss 1 turn). Medical missions pay double.",
	},
	{
		"roll_min": 81, "roll_max": 90,
		"id": "election",
		"name": "Contested Election",
		"instability_mod": 1,
		"instruction": "STRIFE: Contested Election. +1 Instability. Faction standings shift: +1 or -1 to a random faction.",
	},
	{
		"roll_min": 91, "roll_max": 100,
		"id": "natural_disaster",
		"name": "Natural Disaster",
		"instability_mod": 3,
		"instruction": "STRIFE: Natural Disaster! +3 Instability. D3 buildings destroyed on battlefield. Rescue missions available (+5 cr).",
	},
]


## ============================================================================
## EXPANDED LOANS (Compendium pp.116-118)
## ============================================================================

const LOAN_ORIGINS: Array[Dictionary] = [
	{
		"roll": 1,
		"id": "bank",
		"name": "Colonial Bank",
		"amount_range": [10, 20],
		"interest_pct": 5,
		"grace_turns": 5,
		"enforcement": "Legal proceedings. -2 Reputation per late turn. After 3 late: assets seized.",
		"instruction": "LOAN: Colonial Bank. 5% interest/turn. Grace: 5 turns. Late = legal action, -2 Rep/turn.",
	},
	{
		"roll": 2,
		"id": "megacorp",
		"name": "Mega-Corporation",
		"amount_range": [15, 30],
		"interest_pct": 8,
		"grace_turns": 3,
		"enforcement": "Corporate bounty hunters. After 3 late: +1 Rival (Corporate Agents).",
		"instruction": "LOAN: Mega-Corp. 8% interest/turn. Grace: 3 turns. Late = corporate bounty hunters.",
	},
	{
		"roll": 3,
		"id": "loan_shark",
		"name": "Loan Shark",
		"amount_range": [5, 15],
		"interest_pct": 15,
		"grace_turns": 2,
		"enforcement": "Immediate violence. After 2 late: D6 damage to random crew. +1 Rival (Criminal).",
		"instruction": "LOAN: Loan Shark. 15% interest/turn. Grace: 2 turns. Late = violence + Criminal Rival.",
	},
	{
		"roll": 4,
		"id": "syndicate",
		"name": "Crime Syndicate",
		"amount_range": [10, 25],
		"interest_pct": 10,
		"grace_turns": 3,
		"enforcement": "Forced job. Must complete a syndicate mission (no pay). Refuse = +2 Rivals.",
		"instruction": "LOAN: Crime Syndicate. 10% interest/turn. Grace: 3 turns. Late = forced job (no pay).",
	},
	{
		"roll": 5,
		"id": "government",
		"name": "Government Grant",
		"amount_range": [8, 15],
		"interest_pct": 3,
		"grace_turns": 8,
		"enforcement": "Travel restricted. Cannot leave world until paid. -1 Rep/turn.",
		"instruction": "LOAN: Government Grant. 3% interest/turn. Grace: 8 turns. Late = travel restricted.",
	},
	{
		"roll": 6,
		"id": "benefactor",
		"name": "Mysterious Benefactor",
		"amount_range": [20, 40],
		"interest_pct": 0,
		"grace_turns": 10,
		"enforcement": "Favor owed. D6: 1-3 = dangerous mission, 4-5 = item retrieval, 6 = information only.",
		"instruction": "LOAN: Mysterious Benefactor. 0% interest! Grace: 10 turns. Late = favor owed (possibly dangerous).",
	},
]


## ============================================================================
## NAME GENERATION TABLES (Compendium pp.120-124)
## ============================================================================

const HUMAN_FIRST_NAMES: Array[String] = [
	"Anya", "Bash", "Corra", "Dex", "Elara", "Finn", "Greta", "Holt",
	"Iris", "Jace", "Kira", "Lev", "Mira", "Nash", "Orin", "Petra",
	"Quinn", "Reva", "Sable", "Tarn", "Uma", "Vale", "Wren", "Xan",
]

const HUMAN_SURNAMES: Array[String] = [
	"Ashford", "Blackwell", "Caine", "Draven", "Erikson", "Frost",
	"Graves", "Hale", "Irwin", "Jax", "Kade", "Locke", "Mercer",
	"North", "Oakes", "Pierce", "Raines", "Shaw", "Thorne", "Voss",
]

const KERIN_NAMES: Array[String] = [
	"Ak'thar", "Bel'kara", "Cor'vash", "Dha'keel", "El'miri",
	"Fal'gorn", "Gor'thak", "Hel'vira", "Ish'kaan", "Jor'vek",
	"Kal'dris", "Lor'mash", "Mor'thane", "Nor'vail", "Por'kesh",
]

const SWIFT_NAMES: Array[String] = [
	"Zephira", "Quicksilk", "Windchaser", "Starglide", "Moonwhistle",
	"Sunspark", "Duskfeather", "Dawnleap", "Mistwalker", "Shimmerfoot",
	"Lightweave", "Galeborn", "Cloudskip", "Breezethorn", "Flashwing",
]

const KRAG_NAMES: Array[String] = [
	"Grul", "Thokk", "Bragga", "Korgul", "Drukk", "Vargash",
	"Mogrul", "Skarn", "Brekka", "Zulgat", "Hargol", "Dursk",
]

const SKULKER_NAMES: Array[String] = [
	"Slink", "Twitch", "Nibble", "Scurry", "Whisker", "Dart",
	"Fidget", "Prowl", "Sneak", "Glint", "Skitter", "Shadow",
]

const SHIP_NAMES: Array[String] = [
	"Vagrant Star", "Iron Resolve", "Dusty Horizon", "Silver Wake",
	"Lucky Break", "Dark Passage", "Red Horizon", "Cold Fortune",
	"Star Drifter", "Rusty Nail", "Swift Justice", "Lone Wolf",
	"Crimson Dawn", "Ghost Runner", "Steel Tempest", "Nova's Edge",
]

const WORLD_NAMES: Array[String] = [
	"Cygnus Prime", "Ashfall", "Nexus Station", "Verdant Hope",
	"Dust Bowl", "Iron Gate", "Fringe's End", "Shadowmere",
	"Titan's Reach", "Ember's Fall", "New Carthage", "Void's Edge",
	"Crystal Bay", "Desolation Point", "Starfall Colony", "Haven's Rest",
]


## ============================================================================
## QUERY METHODS
## ============================================================================

## Roll a Fringe World Strife event. Returns empty if DLC disabled.
static func roll_strife_event() -> Dictionary:
	if not _is_flag_enabled("FRINGE_WORLD_STRIFE"):
		return {}
	var roll := randi_range(1, 100)
	for event in STRIFE_EVENTS:
		if roll >= event.roll_min and roll <= event.roll_max:
			return event
	return STRIFE_EVENTS[0]


## Check if strife should occur (D6: 1-2 on fringe worlds, 1 on core worlds).
static func should_check_strife(is_fringe_world: bool) -> bool:
	if not _is_flag_enabled("FRINGE_WORLD_STRIFE"):
		return false
	var roll := randi_range(1, 6)
	if is_fringe_world:
		return roll <= 2
	return roll <= 1


## Roll for a loan origin. Returns empty if DLC disabled.
static func roll_loan_origin() -> Dictionary:
	if not _is_flag_enabled("EXPANDED_LOANS"):
		return {}
	var roll := randi_range(1, 6)
	for loan in LOAN_ORIGINS:
		if loan.roll == roll:
			return loan
	return LOAN_ORIGINS[0]


## Calculate loan amount for a given origin.
static func calculate_loan_amount(origin: Dictionary) -> int:
	var range_arr: Array = origin.get("amount_range", [10, 20])
	return randi_range(range_arr[0], range_arr[1])


## Calculate interest for a loan this turn.
static func calculate_interest(principal: int, origin: Dictionary) -> int:
	var pct: int = origin.get("interest_pct", 5)
	return ceili(principal * pct / 100.0)


## Generate a random name for a species. Returns empty if DLC disabled.
static func generate_name(species: String) -> String:
	if not _is_flag_enabled("NAME_GENERATION"):
		return ""
	match species.to_lower():
		"human":
			return HUMAN_FIRST_NAMES[randi() % HUMAN_FIRST_NAMES.size()] + " " + HUMAN_SURNAMES[randi() % HUMAN_SURNAMES.size()]
		"kerin", "k'erin":
			return KERIN_NAMES[randi() % KERIN_NAMES.size()]
		"swift":
			return SWIFT_NAMES[randi() % SWIFT_NAMES.size()]
		"krag":
			return KRAG_NAMES[randi() % KRAG_NAMES.size()]
		"skulker":
			return SKULKER_NAMES[randi() % SKULKER_NAMES.size()]
	# Default to human names for unknown species
	return HUMAN_FIRST_NAMES[randi() % HUMAN_FIRST_NAMES.size()] + " " + HUMAN_SURNAMES[randi() % HUMAN_SURNAMES.size()]


## Generate a random ship name.
static func generate_ship_name() -> String:
	if not _is_flag_enabled("NAME_GENERATION"):
		return ""
	return SHIP_NAMES[randi() % SHIP_NAMES.size()]


## Generate a random world name.
static func generate_world_name() -> String:
	if not _is_flag_enabled("NAME_GENERATION"):
		return ""
	return WORLD_NAMES[randi() % WORLD_NAMES.size()]


## Check if expanded factions should be active.
static func is_expanded_factions_enabled() -> bool:
	return _is_flag_enabled("EXPANDED_FACTIONS")


## Check if compendium terrain generation should be active.
static func is_terrain_generation_enabled() -> bool:
	return _is_flag_enabled("TERRAIN_GENERATION")
