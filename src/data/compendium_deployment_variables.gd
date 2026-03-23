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
## DLC GATING
## ============================================================================

static func _is_enabled() -> bool:
	var dlc_mgr = Engine.get_main_loop().root.get_node_or_null("/root/DLCManager") if Engine.get_main_loop() else null
	if not dlc_mgr:
		return false
	return dlc_mgr.is_feature_enabled(dlc_mgr.ContentFlag.DEPLOYMENT_VARIABLES)


## ============================================================================
## DEPLOYMENT TYPES (Compendium p.45)
## ============================================================================

const DEPLOYMENT_TYPES: Array[Dictionary] = [
	{"id": "line", "name": "Line",
	 "instruction": "DEPLOY: Line. Enemy deployment remains as is (standard)."},
	{"id": "half_flank", "name": "Half Flank",
	 "instruction": "DEPLOY: Half Flank. Random neutral edge. Half of enemy closest to that edge redeploys near center of selected edge. No enemy closer than 12\" to crew."},
	{"id": "improved_positions", "name": "Improved Positions",
	 "instruction": "DEPLOY: Improved Positions. Each enemy moves to nearest terrain feature providing Cover with a firing position."},
	{"id": "forward_positions", "name": "Forward Positions",
	 "instruction": "DEPLOY: Forward Positions. Each enemy moves to closest terrain feature ahead of their current position."},
	{"id": "bolstered_line", "name": "Bolstered Line",
	 "instruction": "DEPLOY: Bolstered Line. Standard deployment. If outnumbered or equal: +1 basic enemy. If crew outnumbers enemy: +1 basic + 1 specialist."},
	{"id": "infiltration", "name": "Infiltration",
	 "instruction": "DEPLOY: Infiltration. Remove half the enemies. End of Round 2, roll D6: 1=tallest terrain, 2=left edge terrain, 3=right edge terrain, 4=nearest to most forward enemy, 5=center terrain, 6=nearest to your edge. Place within/behind feature with LoS to crew."},
	{"id": "reinforced", "name": "Reinforced",
	 "instruction": "DEPLOY: Reinforced. Remove half the enemies. Each round end, D6: if <= round number, removed figures arrive from enemy edge center + 2 additional basic enemies. If table empty after roll, mission ends."},
	{"id": "bolstered_flank", "name": "Bolstered Flank",
	 "instruction": "DEPLOY: Bolstered Flank. Random neutral edge. Half of enemy redeploys near center of that edge + 1 additional specialist for flanking force. No enemy closer than 12\" to crew."},
	{"id": "concealed", "name": "Concealed",
	 "instruction": "DEPLOY: Concealed. Remove all enemies, divide into 3 groups. Mark 6 largest terrain features (1-6). End of Rounds 2, 3, 4: randomly select marked feature, place one group within it."},
]

## D100 ranges by AI type. Keys = AI type, values = array of [deployment_index, roll_min, roll_max]
## Deployment indices: 0=line, 1=half_flank, 2=improved, 3=forward, 4=bolstered_line,
## 5=infiltration, 6=reinforced, 7=bolstered_flank, 8=concealed
const DEPLOYMENT_TABLES: Dictionary = {
	"aggressive": [
		[0, 1, 20], [1, 21, 35], [3, 36, 50], [4, 51, 60],
		[5, 61, 80], [7, 81, 90], [8, 91, 100]],
	"cautious": [
		[0, 1, 30], [1, 31, 40], [2, 41, 50], [4, 51, 70],
		[6, 71, 90], [8, 91, 100]],
	"defensive": [
		[0, 1, 25], [2, 26, 40], [3, 41, 45], [4, 46, 60],
		[5, 61, 70], [6, 71, 85], [7, 86, 90], [8, 91, 100]],
	"rampage": [
		[0, 1, 20], [1, 21, 25], [3, 26, 45], [4, 46, 65],
		[5, 66, 75], [6, 76, 80], [7, 81, 90], [8, 91, 100]],
	"tactical": [
		[0, 1, 20], [1, 21, 30], [2, 31, 40], [3, 41, 50],
		[4, 51, 60], [5, 61, 70], [6, 71, 80], [7, 81, 90], [8, 91, 100]],
	"beast": [
		[1, 1, 15], [2, 16, 20], [3, 21, 35], [4, 36, 45],
		[5, 46, 65], [6, 66, 70], [7, 71, 80], [8, 81, 100]],
}


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
