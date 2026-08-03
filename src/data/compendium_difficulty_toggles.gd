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
## COMPENDIUM DATA LOADING (from JSON)
## ============================================================================

static var _data: Dictionary = {}
static var _loaded: bool = false

static func _ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	var file := FileAccess.open("res://data/compendium/difficulty_toggles.json", FileAccess.READ)
	if not file:
		push_warning("CompendiumDifficultyToggles: Could not load difficulty_toggles.json")
		return
	var json := JSON.new()
	if json.parse(file.get_as_text()) == OK and json.data is Dictionary:
		_data = json.data
	file.close()

static var DIFFICULTY_TOGGLES: Array:
	get:
		_ensure_loaded()
		return _data.get("difficulty_toggles", [])

static var AI_VARIATION_TABLES: Dictionary:
	get:
		_ensure_loaded()
		return _data.get("ai_variation_tables", {})

static var AI_BEHAVIOR_TABLE: Array:
	get:
		_ensure_loaded()
		return _data.get("ai_behavior_table", [])

static var CASUALTY_TABLES: Dictionary:
	get:
		_ensure_loaded()
		return _data.get("casualty_tables", {})

## CASUALTY_TABLE was DELETED (Aug 3 2026). It read `casualty_table`, a key whose
## value in difficulty_toggles.json is the empty array `[]` — the real p.99-100
## data has always been in `casualty_tables` (three tables keyed
## humanoid/cybernetic/beast, each with regular/boss COLUMNS, not a flat `roll`).
## roll_casualty() iterated the empty one looking for `entry.roll`, so it returned
## {} on every call and the Compendium casualty rules never once fired.

static var DETAILED_INJURY_TABLE: Array:
	get:
		_ensure_loaded()
		return _data.get("detailed_injury_table", [])

static var DRAMATIC_COMBAT_RULES: Dictionary:
	get:
		_ensure_loaded()
		return _data.get("dramatic_combat_rules", {})

static var DRAMATIC_EFFECTS: Array:
	get:
		_ensure_loaded()
		return _data.get("dramatic_effects", [])

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


## Roll D6 on a Casualty Table (Compendium pp.99-100). Returns the row plus the
## roll and the column used, or {} when the option is off or the category is
## unknown.
##
## p.99: "roll D6 on the appropriate table below. Use the most suitable category
## for the type of creature. The Regular column is used for your crew figures and
## normal enemies (including specialists). The Boss column is used for your crew
## captain, any enemy leader and unique personalities."
##
## `bonus` carries the +1 the Damaged (cybernetic) and Bleeding (beast) rows add
## to FUTURE casualty rolls, and the Critical Hit option's extra roll is made by
## the caller rolling twice and keeping the highest (p.100).
static func roll_casualty(category: String = "humanoid", is_boss: bool = false,
		bonus: int = 0) -> Dictionary:
	if not _is_flag_enabled("CASUALTY_TABLES"):
		return {}
	var table: Dictionary = CASUALTY_TABLES.get(category, {})
	var entries: Array = table.get("entries", []) if table is Dictionary else []
	if entries.is_empty():
		return {}
	var roll: int = clampi(randi_range(1, 6) + bonus, 1, 6)
	var column := "boss" if is_boss else "regular"
	for entry in entries:
		var span: Array = entry.get(column, [])
		if span.size() == 2 and roll >= int(span[0]) and roll <= int(span[1]):
			var out: Dictionary = entry.duplicate(true)
			out["roll"] = roll
			out["column"] = column
			out["table"] = category
			return out
	return {}


## Which Casualty Table a figure uses (p.99 "the most suitable category").
static func casualty_category_for(is_mechanical: bool, is_beast: bool) -> String:
	if is_mechanical:
		return "cybernetic"
	if is_beast:
		return "beast"
	return "humanoid"


## Roll D100 on the Detailed Post-Battle Injury table (Compendium p.102).
## Returns the row, with the roll attached, or {} when the option is off.
##
## Was `randi_range(1, 6) + randi_range(1, 6)` — 2D6 against a D100 table — and
## then matched `entry.roll`, a key these rows do not have (they carry `roll_min`
## / `roll_max`). Both faults independently guaranteed {}, so the table never
## resolved once. Note roll_min 0 on the Death row is the book's tens-digit
## notation for "01-10"; matching an inclusive 1-100 roll against the span is
## correct for it and for the 96-00 row alike.
static func roll_detailed_injury() -> Dictionary:
	if not _is_flag_enabled("DETAILED_INJURIES"):
		return {}
	var roll := randi_range(1, 100)
	for entry in DETAILED_INJURY_TABLE:
		if roll >= int(entry.get("roll_min", -1)) and roll <= int(entry.get("roll_max", -1)):
			var out: Dictionary = entry.duplicate(true)
			out["roll"] = roll
			return out
	return {}


## Get dramatic effect text for a weapon type. Returns empty if disabled.
static func get_dramatic_effect(weapon_type: String) -> String:
	if not _is_flag_enabled("DRAMATIC_COMBAT"):
		return ""
	for entry in DRAMATIC_EFFECTS:
		if entry.weapon_type == weapon_type:
			return entry.instruction
	return ""


## Get Adjusted Shooting hit thresholds (Compendium p.87) when Dramatic Combat
## is on. Returns {"open": int, "cover": int} or empty dict when disabled.
static func get_adjusted_shooting_thresholds() -> Dictionary:
	if not _is_flag_enabled("DRAMATIC_COMBAT"):
		return {}
	var rules: Dictionary = DRAMATIC_COMBAT_RULES.get("adjusted_shooting", {})
	if rules.is_empty():
		return {}
	return {
		"open": int(rules.get("in_open_threshold", 5)),
		"cover": int(rules.get("in_cover_threshold", 6)),
	}


## Get the dramatic weapons stat override for a given weapon id (Compendium
## pp.88-89). Returns empty dict when disabled or the weapon has no override
## (callers fall back to the equipment_database baseline).
static func get_dramatic_weapon_stats(weapon_id: String) -> Dictionary:
	if not _is_flag_enabled("DRAMATIC_COMBAT"):
		return {}
	_ensure_loaded()
	var table: Dictionary = _data.get("dramatic_weapons_stats", {})
	var key := weapon_id.to_lower().strip_edges().replace(" ", "_").replace("-", "_")
	var stats = table.get(key, {})
	return stats if stats is Dictionary else {}


## Aggregated rule-text instructions for the BattlePhase setup screen.
## Returns the Adjusted Shooting / Duck Back / Lunge bullet strings so the
## tabletop player has the actual rules in front of them, not just per-weapon
## flavor strings. Returns [] when DRAMATIC_COMBAT is disabled.
static func get_dramatic_combat_rule_instructions() -> Array[String]:
	var out: Array[String] = []
	if not _is_flag_enabled("DRAMATIC_COMBAT"):
		return out
	var rules: Dictionary = DRAMATIC_COMBAT_RULES
	for key in ["adjusted_shooting", "duck_back", "lunging"]:
		var block = rules.get(key, {})
		if block is Dictionary:
			var instr: String = str(block.get("instruction", ""))
			if not instr.is_empty():
				out.append(instr)
	return out


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
