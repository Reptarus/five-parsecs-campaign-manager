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

static var CASUALTY_TABLE: Array:
	get:
		_ensure_loaded()
		return _data.get("casualty_table", [])

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
