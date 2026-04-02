class_name CompendiumSalvageJobs
extends RefCounted
## Salvage Jobs — Compendium pp.137-147
##
## Exploration-driven missions with Tension track, Contact markers, Points of
## Interest, and salvage collection. Crew explores a derelict ship, abandoned
## colony, or ruined facility looking for valuables while encountering hazards.
##
## All output is TEXT INSTRUCTIONS for the tabletop companion model.
## Gated behind DLCManager.ContentFlag.SALVAGE_JOBS.
##
## Integration notes (p.139):
##   - Enemy Deployment Variables (p.44) and Escalating Battles (p.46) CANNOT be used
##   - AI Variations (p.42) and Elite-level Enemies (p.48) CAN be used normally
##   - Normal Deployment Conditions and Notable Sights are NOT used
##   - Do NOT roll for a mission objective
##   - No roll to Seize the Initiative
##   - 3x3 ft recommended. On 2x2, reduce all movement by 1"


## ============================================================================
## DLC GATING
## ============================================================================

static func _is_enabled() -> bool:
	var dlc_mgr = Engine.get_main_loop().root.get_node_or_null("/root/DLCManager") if Engine.get_main_loop() else null
	if not dlc_mgr:
		return false
	return dlc_mgr.is_feature_enabled(dlc_mgr.ContentFlag.SALVAGE_JOBS)



## ============================================================================
## COMPENDIUM DATA LOADING (from JSON)
## ============================================================================

static var _data: Dictionary = {}
static var _loaded: bool = false

static func _ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	var file := FileAccess.open("res://data/compendium/salvage_jobs.json", FileAccess.READ)
	if not file:
		push_warning("CompendiumSalvageJobs: Could not load salvage_jobs.json")
		return
	var json := JSON.new()
	if json.parse(file.get_as_text()) == OK and json.data is Dictionary:
		_data = json.data
	file.close()

static var SALVAGE_AVAILABILITY: Array:
	get:
		_ensure_loaded()
		return _data.get("salvage_availability", [])

static var TABLE_SETUP_RULES: String:
	get:
		_ensure_loaded()
		return _data.get("table_setup_rules", "")

static var TENSION_RULES: String:
	get:
		_ensure_loaded()
		return _data.get("tension_rules", "")

static var CONTACT_PLACEMENT_RULES: String:
	get:
		_ensure_loaded()
		return _data.get("contact_placement_rules", "")

static var CONTACT_RESULTS: Array:
	get:
		_ensure_loaded()
		return _data.get("contact_results", [])

static var HOSTILES_TABLE: Array:
	get:
		_ensure_loaded()
		return _data.get("hostiles_table", [])

static var ENEMY_FORCES_BY_ENCOUNTER: Array:
	get:
		_ensure_loaded()
		return _data.get("enemy_forces_by_encounter", [])

static var ENEMY_PLACEMENT_RULES: String:
	get:
		_ensure_loaded()
		return _data.get("enemy_placement_rules", "")

static var CONTACT_MOVEMENT_RULES: String:
	get:
		_ensure_loaded()
		return _data.get("contact_movement_rules", "")

static var POI_REVEALS: Array:
	get:
		_ensure_loaded()
		return _data.get("poi_reveals", [])

static var SALVAGE_VALUE_RULES: String:
	get:
		_ensure_loaded()
		return _data.get("salvage_value_rules", "")

static var DISCOVERY_TABLE: Array:
	get:
		_ensure_loaded()
		return _data.get("discovery_table", [])

static var POI_REWARD_TABLE: Array:
	get:
		_ensure_loaded()
		return _data.get("poi_reward_table", [])

## ============================================================================
## QUERY METHODS
## ============================================================================

## Roll salvage job availability. Returns availability dict.
static func roll_salvage_availability() -> Dictionary:
	if not _is_enabled():
		return {}

	var roll := randi_range(1, 6)
	for avail in SALVAGE_AVAILABILITY:
		if roll >= avail.roll_min and roll <= avail.roll_max:
			var result: Dictionary = avail.duplicate()
			result["roll"] = roll
			return result
	return SALVAGE_AVAILABILITY[0]


## Roll contact result (D6 when contact revealed). Returns contact dict.
static func roll_contact_result() -> Dictionary:
	var roll := randi_range(1, 6)
	for contact in CONTACT_RESULTS:
		if roll >= contact.roll_min and roll <= contact.roll_max:
			var result: Dictionary = contact.duplicate()
			result["roll"] = roll
			return result
	return CONTACT_RESULTS[0]


## Roll hostiles type (D100, first encounter only). Returns hostiles dict.
static func roll_hostiles_type() -> Dictionary:
	var roll := randi_range(1, 100)
	for hostile in HOSTILES_TABLE:
		if roll >= hostile.roll_min and roll <= hostile.roll_max:
			var result: Dictionary = hostile.duplicate()
			result["roll"] = roll
			return result
	return HOSTILES_TABLE[0]


## Get enemy force composition for a given encounter number.
static func get_enemy_forces(encounter_number: int) -> Dictionary:
	if encounter_number <= 0:
		encounter_number = 1
	if encounter_number > ENEMY_FORCES_BY_ENCOUNTER.size():
		return ENEMY_FORCES_BY_ENCOUNTER[3] # 4th+ encounter
	return ENEMY_FORCES_BY_ENCOUNTER[encounter_number - 1]


## Roll Point of Interest reveal (D100). Returns POI dict.
static func roll_poi_reveal() -> Dictionary:
	var roll := randi_range(1, 100)
	for poi in POI_REVEALS:
		if roll >= poi.roll_min and roll <= poi.roll_max:
			var result: Dictionary = poi.duplicate()
			result["roll"] = roll
			return result
	return POI_REVEALS[0]


## Calculate initial Tension value for crew size.
static func get_initial_tension(crew_size: int) -> int:
	return ceili(crew_size / 2.0)


## Perform Tension roll. Returns {new_tension, contact_spawned, roll}.
static func roll_tension(current_tension: int) -> Dictionary:
	var roll := randi_range(1, 6)
	if roll > current_tension:
		return {"new_tension": current_tension + 1, "contact_spawned": false, "roll": roll,
			"instruction": "TENSION: Roll %d > Tension %d. Tension rises to %d." % [roll, current_tension, current_tension + 1]}
	else:
		var new_tension: int = maxi(current_tension - roll, 0)
		return {"new_tension": new_tension, "contact_spawned": true, "roll": roll,
			"instruction": "TENSION: Roll %d <= Tension %d. Contact spawned! Tension drops to %d." % [roll, current_tension, new_tension]}


## Get full salvage mission setup as instruction block.
static func generate_mission_setup() -> Dictionary:
	if not _is_enabled():
		return {}

	return {
		"table_setup": TABLE_SETUP_RULES,
		"tension_rules": TENSION_RULES,
		"contact_placement": CONTACT_PLACEMENT_RULES,
		"contact_movement": CONTACT_MOVEMENT_RULES,
		"enemy_placement": ENEMY_PLACEMENT_RULES,
		"salvage_value": SALVAGE_VALUE_RULES,
	}
