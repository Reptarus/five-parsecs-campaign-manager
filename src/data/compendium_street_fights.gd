class_name CompendiumStreetFights
extends RefCounted
## Street Fights — Compendium pp.125-138
##
## Urban combat with Suspect markers, City markers, pistol Shootout mechanics,
## Evasion, unique enemy tables, and street combatants. Confused, chaotic
## environments where enemies start as unidentified Suspects.
##
## All output is TEXT INSTRUCTIONS for the tabletop companion model.
## Gated behind DLCManager.ContentFlag.STREET_FIGHTS.
##
## Integration notes (p.125):
##   - Notable Sights and Deployment Conditions are NOT used
##   - Enemy Deployment Variables (p.44) are NOT used
##   - Escalating Battles (p.46) are NOT used
##   - Morale is NOT checked (situation too confusing)
##   - Visibility limited to 9" (cannot be increased by abilities/equipment)


## ============================================================================
## DLC GATING
## ============================================================================

static func _is_enabled() -> bool:
	var dlc_mgr = Engine.get_main_loop().root.get_node_or_null("/root/DLCManager") if Engine.get_main_loop() else null
	if not dlc_mgr:
		return false
	return dlc_mgr.is_feature_enabled(dlc_mgr.ContentFlag.STREET_FIGHTS)



## ============================================================================
## COMPENDIUM DATA LOADING (from JSON)
## ============================================================================

static var _data: Dictionary = {}
static var _loaded: bool = false

static func _ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	var file := FileAccess.open("res://data/compendium/street_fights.json", FileAccess.READ)
	if not file:
		push_warning("CompendiumStreetFights: Could not load street_fights.json")
		return
	var json := JSON.new()
	if json.parse(file.get_as_text()) == OK and json.data is Dictionary:
		_data = json.data
	file.close()

static var TABLE_SETUP_RULES: String:
	get:
		_ensure_loaded()
		return _data.get("table_setup_rules", "")

static var BUILDING_TYPES: Array:
	get:
		_ensure_loaded()
		return _data.get("building_types", [])

static var DEPLOYMENT_RULES: String:
	get:
		_ensure_loaded()
		return _data.get("deployment_rules", "")

static var SUSPECT_ACTIONS: Array:
	get:
		_ensure_loaded()
		return _data.get("suspect_actions", [])

static var SUSPECT_IDENTIFICATION: Array:
	get:
		_ensure_loaded()
		return _data.get("suspect_identification", [])

static var STREET_FIGHT_OBJECTIVES: Array:
	get:
		_ensure_loaded()
		return _data.get("street_fight_objectives", [])

static var INDIVIDUAL_PROFILE: Dictionary:
	get:
		_ensure_loaded()
		return _data.get("individual_profile", {})

static var INDIVIDUAL_RULES: String:
	get:
		_ensure_loaded()
		return _data.get("individual_rules", "")

static var PACKAGE_RULES: String:
	get:
		_ensure_loaded()
		return _data.get("package_rules", "")

static var EVASION_RULES: String:
	get:
		_ensure_loaded()
		return _data.get("evasion_rules", "")

static var SHOOTOUT_RULES: String:
	get:
		_ensure_loaded()
		return _data.get("shootout_rules", "")

static var STARTING_TROUBLE_RULES: String:
	get:
		_ensure_loaded()
		return _data.get("starting_trouble_rules", "")

static var STREET_FIGHT_ENEMIES: Array:
	get:
		_ensure_loaded()
		return _data.get("street_fight_enemies", [])

static var STREET_COMBATANTS: Array:
	get:
		_ensure_loaded()
		return _data.get("street_combatants", [])

static var CITY_MARKER_ACTIONS: Array:
	get:
		_ensure_loaded()
		return _data.get("city_marker_actions", [])

static var CITY_MARKER_REVEALS: Array:
	get:
		_ensure_loaded()
		return _data.get("city_marker_reveals", [])

static var LAW_RULES: String:
	get:
		_ensure_loaded()
		return _data.get("law_rules", "")

static var END_GAME_RULES: String:
	get:
		_ensure_loaded()
		return _data.get("end_game_rules", "")

## ============================================================================
## QUERY METHODS
## ============================================================================

## Roll a street fight objective. Returns objective dict.
static func roll_objective() -> Dictionary:
	if not _is_enabled():
		return {}

	var roll := randi_range(1, 100)
	for obj in STREET_FIGHT_OBJECTIVES:
		if roll >= obj.roll_min and roll <= obj.roll_max:
			var result: Dictionary = obj.duplicate()
			result["roll"] = roll
			return result
	return STREET_FIGHT_OBJECTIVES[0]


## Roll street fight enemy type (first reveal). Returns enemy dict.
static func roll_enemy_type() -> Dictionary:
	if not _is_enabled():
		return {}

	var roll := randi_range(1, 100)
	for enemy in STREET_FIGHT_ENEMIES:
		if roll >= enemy.roll_min and roll <= enemy.roll_max:
			var result: Dictionary = enemy.duplicate()
			result["roll"] = roll
			return result
	return STREET_FIGHT_ENEMIES[0]


## Roll street combatant (from City marker reveal). Returns combatant dict.
static func roll_street_combatant() -> Dictionary:
	var roll := randi_range(1, 100)
	for combatant in STREET_COMBATANTS:
		if roll >= combatant.roll_min and roll <= combatant.roll_max:
			var result: Dictionary = combatant.duplicate()
			result["roll"] = roll
			return result
	return STREET_COMBATANTS[0]


## Roll suspect action. Returns action dict.
static func roll_suspect_action() -> Dictionary:
	var roll := randi_range(1, 6)
	for action in SUSPECT_ACTIONS:
		if roll >= action.roll_min and roll <= action.roll_max:
			var result: Dictionary = action.duplicate()
			result["roll"] = roll
			return result
	return SUSPECT_ACTIONS[0]


## Roll suspect identification. Returns identification dict.
static func roll_suspect_identification() -> Dictionary:
	var roll := randi_range(1, 6)
	for ident in SUSPECT_IDENTIFICATION:
		if roll >= ident.roll_min and roll <= ident.roll_max:
			var result: Dictionary = ident.duplicate()
			result["roll"] = roll
			return result
	return SUSPECT_IDENTIFICATION[0]


## Roll city marker behavior (once per turn). Returns action dict.
static func roll_city_marker_action() -> Dictionary:
	var roll := randi_range(1, 6)
	for action in CITY_MARKER_ACTIONS:
		if roll >= action.roll_min and roll <= action.roll_max:
			var result: Dictionary = action.duplicate()
			result["roll"] = roll
			return result
	return CITY_MARKER_ACTIONS[0]


## Roll city marker reveal (when crew within 4"). Returns reveal dict.
static func roll_city_marker_reveal() -> Dictionary:
	var roll := randi_range(1, 100)
	for reveal in CITY_MARKER_REVEALS:
		if roll >= reveal.roll_min and roll <= reveal.roll_max:
			var result: Dictionary = reveal.duplicate()
			result["roll"] = roll
			return result
	return CITY_MARKER_REVEALS[0]


## Roll building type (D6). Returns building dict.
static func roll_building_type() -> Dictionary:
	var roll := randi_range(1, 6)
	for bldg in BUILDING_TYPES:
		if roll >= bldg.roll_min and roll <= bldg.roll_max:
			var result: Dictionary = bldg.duplicate()
			result["roll"] = roll
			return result
	return BUILDING_TYPES[0]


## Get full street fight setup as instruction block.
static func generate_mission_setup() -> Dictionary:
	if not _is_enabled():
		return {}

	var objective := roll_objective()
	return {
		"objective": objective,
		"table_setup": TABLE_SETUP_RULES,
		"deployment": DEPLOYMENT_RULES,
		"suspect_actions": SUSPECT_ACTIONS,
		"suspect_identification": SUSPECT_IDENTIFICATION,
		"evasion": EVASION_RULES,
		"shootout": SHOOTOUT_RULES,
		"starting_trouble": STARTING_TROUBLE_RULES,
		"city_marker_actions": CITY_MARKER_ACTIONS,
		"city_marker_reveals": CITY_MARKER_REVEALS,
		"law_rules": LAW_RULES,
		"end_game": END_GAME_RULES,
		"individual_rules": INDIVIDUAL_RULES if objective.get("has_individual", false) else "",
		"package_rules": PACKAGE_RULES if objective.get("has_package", false) else "",
	}
