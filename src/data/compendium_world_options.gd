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
## COMPENDIUM DATA LOADING (from JSON)
## ============================================================================

static var _data: Dictionary = {}
static var _loaded: bool = false

static func _ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	var file := FileAccess.open("res://data/compendium/world_options.json", FileAccess.READ)
	if not file:
		push_warning("CompendiumWorldOptions: Could not load world_options.json")
		return
	var json := JSON.new()
	if json.parse(file.get_as_text()) == OK and json.data is Dictionary:
		_data = json.data
	file.close()

static var STRIFE_MECHANISM: String:
	get:
		_ensure_loaded()
		return _data.get("strife_mechanism", "")

static var STRIFE_EVENTS: Array:
	get:
		_ensure_loaded()
		return _data.get("strife_events", [])

static var LOAN_ORIGINS: Array:
	get:
		_ensure_loaded()
		return _data.get("loan_origins", [])

static var INTEREST_RATES: Array:
	get:
		_ensure_loaded()
		return _data.get("interest_rates", [])

static var ENFORCEMENT_THRESHOLDS: Array:
	get:
		_ensure_loaded()
		return _data.get("enforcement_thresholds", [])

static var ENFORCEMENT_METHODS: Array:
	get:
		_ensure_loaded()
		return _data.get("enforcement_methods", [])

static var COLLECTION_SQUAD_TYPES: Dictionary:
	get:
		_ensure_loaded()
		return _data.get("collection_squad_types", {})

static var FIGHT_SEIZURE_INSTRUCTION: String:
	get:
		_ensure_loaded()
		return _data.get("fight_seizure_instruction", "")

static var WORLD_NAMES: Array:
	get:
		_ensure_loaded()
		return _data.get("world_names", [])

static var COLONY_PART1: Array:
	get:
		_ensure_loaded()
		return _data.get("colony_part1", [])

static var COLONY_PART2: Array:
	get:
		_ensure_loaded()
		return _data.get("colony_part2", [])

static var SHIP_PART1: Array:
	get:
		_ensure_loaded()
		return _data.get("ship_part1", [])

static var SHIP_PART2: Array:
	get:
		_ensure_loaded()
		return _data.get("ship_part2", [])

static var CORP_PART1: Array:
	get:
		_ensure_loaded()
		return _data.get("corp_part1", [])

static var CORP_PART2: Array:
	get:
		_ensure_loaded()
		return _data.get("corp_part2", [])

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
