class_name CompendiumDeploymentVariables
extends RefCounted
## Enemy Deployment Variables — Compendium pp.44-45
##
## When failing to Seize the Initiative, roll D100 by AI type to determine
## how enemies deploy. If initiative IS seized, enemies use Line (standard).
##
## All output is TEXT INSTRUCTIONS for the tabletop companion model.
## Gated behind DLCManager.ContentFlag.DEPLOYMENT_VARIABLES.


## ============================================================================
## JSON DATA LOADING (RulesReference canonical, const fallback)
## ============================================================================

static var _ref_data: Dictionary = {}
static var _ref_loaded: bool = false

static func _ensure_ref_loaded() -> void:
	if _ref_loaded:
		return
	_ref_loaded = true
	var path := "res://data/RulesReference/AlternateEnemyDeployment.json"
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
## DLC GATING
## ============================================================================

static func _is_enabled() -> bool:
	var dlc_mgr = Engine.get_main_loop().root.get_node_or_null("/root/DLCManager") if Engine.get_main_loop() else null
	if not dlc_mgr:
		return false
	return dlc_mgr.is_feature_enabled(dlc_mgr.ContentFlag.DEPLOYMENT_VARIABLES)



## ============================================================================
## COMPENDIUM DATA LOADING (from JSON)
## ============================================================================

static var _data: Dictionary = {}
static var _loaded: bool = false

static func _ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	var file := FileAccess.open("res://data/compendium/deployment_variables.json", FileAccess.READ)
	if not file:
		push_warning("CompendiumDeploymentVariables: Could not load deployment_variables.json")
		return
	var json := JSON.new()
	if json.parse(file.get_as_text()) == OK and json.data is Dictionary:
		_data = json.data
	file.close()

static var DEPLOYMENT_TYPES: Array:
	get:
		_ensure_loaded()
		return _data.get("deployment_types", [])

static var DEPLOYMENT_TABLES: Dictionary:
	get:
		_ensure_loaded()
		return _data.get("deployment_tables", {})

## ============================================================================
## QUERY METHODS
## ============================================================================

## Roll deployment type for a given AI type. Returns deployment dict.
## If initiative was seized, always returns Line.
static func roll_deployment(ai_type: String, seized_initiative: bool = false) -> Dictionary:
	if not _is_enabled():
		return {}
	if seized_initiative:
		return DEPLOYMENT_TYPES[0] # Line

	var ai_key := ai_type.to_lower()
	if not DEPLOYMENT_TABLES.has(ai_key):
		return DEPLOYMENT_TYPES[0] # Default to Line

	var roll := randi_range(1, 100)
	var table: Array = DEPLOYMENT_TABLES[ai_key]
	for entry in table:
		var deploy_idx: int = entry[0]
		var r_min: int = entry[1]
		var r_max: int = entry[2]
		if roll >= r_min and roll <= r_max:
			var result: Dictionary = DEPLOYMENT_TYPES[deploy_idx].duplicate()
			result["roll"] = roll
			result["ai_type"] = ai_key
			return result

	return DEPLOYMENT_TYPES[0]


## Get deployment type by ID.
static func get_deployment_type(deploy_id: String) -> Dictionary:
	for dt in DEPLOYMENT_TYPES:
		if dt.id == deploy_id:
			return dt
	return {}
