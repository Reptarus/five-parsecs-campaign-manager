class_name CompendiumDeploymentVariables
extends RefCounted
## Enemy Deployment Variables — Compendium pp.44-45.
##
## "Set up both sides normally and roll to Seize the Initiative. If you fail,
##  roll D100 on the table below, using the AI type to calculate which deployment
##  type the enemy will use. If you successfully Seize the Initiative, the enemy
##  will always use the Line (i.e. standard) deployment option."
##
## data/compendium/deployment_variables.json has held the nine deployment types
## and all six AI-type D100 columns, byte-correct against the book, since it was
## written — and had ZERO loaders. This file is that loader.
##
## Output is TEXT INSTRUCTIONS: the app tells the player how to place the enemy
## on the physical table. It does not move figures.

const FLAG := "DEPLOYMENT_VARIABLES"

## AI types the p.44 table has a column for. Guardian is deliberately absent —
## the book prints six columns and Guardian is not one of them, so a Guardian
## force gets no variable deployment rather than a fabricated one.
const TABLE_AI_TYPES: Array = [
	"aggressive", "cautious", "defensive", "rampage", "tactical", "beast",
]


## ============================================================================
## DATA LOADING
## ============================================================================

static var _data: Dictionary = {}
static var _loaded: bool = false

static func _ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	var file := FileAccess.open(
		"res://data/compendium/deployment_variables.json", FileAccess.READ)
	if not file:
		push_warning("CompendiumDeploymentVariables: could not load deployment_variables.json")
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
## DLC GATING
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
## THE RULE
## ============================================================================

## Normalize whatever the enemy force calls its AI to a p.44 column name.
static func normalize_ai_type(ai_type: String) -> String:
	var key: String = ai_type.strip_edges().to_lower()
	# Single-letter codes are how enemy_types.json stores AI (A/C/D/R/T/B).
	match key:
		"a": key = "aggressive"
		"c": key = "cautious"
		"d": key = "defensive"
		"r": key = "rampage"
		"t": key = "tactical"
		"b": key = "beast"
	if key in TABLE_AI_TYPES:
		return key
	return ""


static func get_deployment_type(type_id: String) -> Dictionary:
	for entry in DEPLOYMENT_TYPES:
		if entry is Dictionary and str(entry.get("id", "")) == type_id:
			return entry.duplicate(true)
	return {}


## Resolve the enemy's deployment for this battle.
##
## `seized` true short-circuits to Line per p.44 — that is the rule, not an
## optimisation, so it applies before the flag check has any dice to roll.
## Returns {} when the option is off or the AI type has no column (Guardian).
static func roll_deployment(ai_type: String, seized: bool) -> Dictionary:
	if not _is_flag_enabled(FLAG):
		return {}
	var column: String = normalize_ai_type(ai_type)
	if column.is_empty():
		return {}
	if seized:
		var line: Dictionary = get_deployment_type("line")
		if line.is_empty():
			return {}
		line["roll"] = 0
		line["ai_type"] = column
		line["reason"] = "Initiative seized — the enemy always uses Line deployment (p.44)."
		return line

	var rows: Array = DEPLOYMENT_TABLES.get(column, [])
	if rows.is_empty():
		return {}
	var roll: int = randi_range(1, 100)
	var types: Array = DEPLOYMENT_TYPES
	for row in rows:
		# Rows are [type_index, roll_min, roll_max] against DEPLOYMENT_TYPES.
		if not (row is Array) or row.size() != 3:
			continue
		if roll < int(row[1]) or roll > int(row[2]):
			continue
		var index: int = int(row[0])
		if index < 0 or index >= types.size():
			return {}
		var out: Dictionary = (types[index] as Dictionary).duplicate(true)
		out["roll"] = roll
		out["ai_type"] = column
		out["reason"] = "Initiative not seized — D100 %d on the %s column (p.44)." % [
			roll, column.capitalize()]
		return out
	return {}


## The placement clarification p.44 prints beneath the table. Shown alongside
## Infiltration and Concealed because those are the two that arrive mid-battle.
static func get_arrival_placement_note() -> String:
	return ("Figures arriving from concealment or infiltration are placed anywhere"
		+ " within or directly behind the feature that lets them fire on at least"
		+ " one crew member. Arriving enemies with no ranged attack are placed as"
		+ " close to a crew member as the feature allows (Compendium p.44).")
