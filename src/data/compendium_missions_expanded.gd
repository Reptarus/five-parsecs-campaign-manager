class_name CompendiumMissionsExpanded
extends RefCounted
## Expanded Missions, Quests, Connections + PvP/Co-op
##
## Book-accurate data from Compendium pp.74-88 (missions/quests/connections),
## pp.35-41 (PvP/Co-op). All output is TEXT INSTRUCTIONS for the tabletop
## companion model.
##
## Features:
##   EXPANDED_MISSIONS    - Objective overview, specific objectives, time/extraction, patron conditions
##   EXPANDED_QUESTS      - D100 quest progression + conclusion rules
##   EXPANDED_CONNECTIONS - D6 main table + 5 subtables (30 narrative scenarios)
##   PVP_BATTLES          - Two-player opposed battles
##   COOP_BATTLES         - Two-player cooperative battles


## ============================================================================
## JSON DATA LOADING (RulesReference canonical, const fallback)
## ============================================================================

static var _ref_data: Dictionary = {}
static var _ref_loaded: bool = false

static func _ensure_ref_loaded() -> void:
	if _ref_loaded:
		return
	_ref_loaded = true
	var path := "res://data/RulesReference/ExpandedMissions.json"
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
	var file := FileAccess.open("res://data/compendium/missions_expanded.json", FileAccess.READ)
	if not file:
		push_warning("CompendiumMissionsExpanded: Could not load missions_expanded.json")
		return
	var json := JSON.new()
	if json.parse(file.get_as_text()) == OK and json.data is Dictionary:
		_data = json.data
	file.close()

static var OBJECTIVE_OVERVIEW: Array:
	get:
		_ensure_loaded()
		return _data.get("objective_overview", [])

static var SPECIFIC_OBJECTIVES: Array:
	get:
		_ensure_loaded()
		return _data.get("specific_objectives", [])

static var TIME_CONSTRAINTS: Array:
	get:
		_ensure_loaded()
		return _data.get("time_constraints", [])

static var EXTRACTION: Array:
	get:
		_ensure_loaded()
		return _data.get("extraction", [])

static var PATRON_CONDITIONS: Array:
	get:
		_ensure_loaded()
		return _data.get("patron_conditions", [])

static var QUEST_PROGRESSION: Array:
	get:
		_ensure_loaded()
		return _data.get("quest_progression", [])

static var QUEST_CONCLUSION: Dictionary:
	get:
		_ensure_loaded()
		return _data.get("quest_conclusion", {})

static var CONNECTION_MAIN_TABLE: Array:
	get:
		_ensure_loaded()
		return _data.get("connection_main_table", [])

static var CONNECTION_SUBTABLE_1: Array:
	get:
		_ensure_loaded()
		return _data.get("connection_subtable_1", [])

static var CONNECTION_SUBTABLE_2: Array:
	get:
		_ensure_loaded()
		return _data.get("connection_subtable_2", [])

static var CONNECTION_SUBTABLE_3: Array:
	get:
		_ensure_loaded()
		return _data.get("connection_subtable_3", [])

static var CONNECTION_SUBTABLE_4: Array:
	get:
		_ensure_loaded()
		return _data.get("connection_subtable_4", [])

static var CONNECTION_SUBTABLE_5: Array:
	get:
		_ensure_loaded()
		return _data.get("connection_subtable_5", [])

static var SETUP_RULES: String:
	get:
		_ensure_loaded()
		return _data.get("setup_rules", "")

static var PVP_BATTLE_REASON: Array:
	get:
		_ensure_loaded()
		return _data.get("pvp_battle_reason", [])

static var PVP_INITIATIVE_USES: Array:
	get:
		_ensure_loaded()
		return _data.get("pvp_initiative_uses", [])

static var PVP_POWER_RATING: String:
	get:
		_ensure_loaded()
		return _data.get("pvp_power_rating", "")

static var PVP_THIRD_PARTY_DEPLOYMENT: Array:
	get:
		_ensure_loaded()
		return _data.get("pvp_third_party_deployment", [])

static var PVP_RULES: Dictionary:
	get:
		_ensure_loaded()
		return _data.get("pvp_rules", {})

static var COOP_RULES: Dictionary:
	get:
		_ensure_loaded()
		return _data.get("coop_rules", {})

static var INTRODUCTORY_CAMPAIGN: Array:
	get:
		_ensure_loaded()
		return _data.get("introductory_campaign", [])

## ============================================================================
## QUERY METHODS
## ============================================================================

## Roll objective overview (D100). Returns empty if DLC disabled.
static func roll_objective_overview() -> Dictionary:
	if not _is_flag_enabled("EXPANDED_MISSIONS"):
		return {}
	var roll := randi_range(1, 100)
	for entry in OBJECTIVE_OVERVIEW:
		if roll >= entry.roll_min and roll <= entry.roll_max:
			var result: Dictionary = entry.duplicate()
			result["roll"] = roll
			return result
	return OBJECTIVE_OVERVIEW[0]


## Roll a specific objective (D100). Returns empty if DLC disabled.
static func roll_specific_objective() -> Dictionary:
	if not _is_flag_enabled("EXPANDED_MISSIONS"):
		return {}
	var roll := randi_range(1, 100)
	for obj in SPECIFIC_OBJECTIVES:
		if roll >= obj.roll_min and roll <= obj.roll_max:
			var result: Dictionary = obj.duplicate()
			result["roll"] = roll
			return result
	return SPECIFIC_OBJECTIVES[0]


## Roll time constraint (D100). Returns empty if DLC disabled.
static func roll_time_constraint() -> Dictionary:
	if not _is_flag_enabled("EXPANDED_MISSIONS"):
		return {}
	var roll := randi_range(1, 100)
	for tc in TIME_CONSTRAINTS:
		if roll >= tc.roll_min and roll <= tc.roll_max:
			var result: Dictionary = tc.duplicate()
			result["roll"] = roll
			return result
	return TIME_CONSTRAINTS[0]


## Roll extraction method (D100). Returns empty if DLC disabled.
static func roll_extraction() -> Dictionary:
	if not _is_flag_enabled("EXPANDED_MISSIONS"):
		return {}
	var roll := randi_range(1, 100)
	for ext in EXTRACTION:
		if roll >= ext.roll_min and roll <= ext.roll_max:
			var result: Dictionary = ext.duplicate()
			result["roll"] = roll
			return result
	return EXTRACTION[0]


## Roll patron special condition (D100). Returns empty if DLC disabled.
static func roll_patron_condition() -> Dictionary:
	if not _is_flag_enabled("EXPANDED_MISSIONS"):
		return {}
	var roll := randi_range(1, 100)
	for cond in PATRON_CONDITIONS:
		if roll >= cond.roll_min and roll <= cond.roll_max:
			var result: Dictionary = cond.duplicate()
			result["roll"] = roll
			return result
	return PATRON_CONDITIONS[0]


## Roll quest progression (D100). Returns empty if DLC disabled.
static func roll_quest_progression() -> Dictionary:
	if not _is_flag_enabled("EXPANDED_QUESTS"):
		return {}
	var roll := randi_range(1, 100)
	for step in QUEST_PROGRESSION:
		if roll >= step.roll_min and roll <= step.roll_max:
			var result: Dictionary = step.duplicate()
			result["roll"] = roll
			return result
	return QUEST_PROGRESSION[0]


## Get quest conclusion text.
static func get_quest_conclusion() -> String:
	if not _is_flag_enabled("EXPANDED_QUESTS"):
		return ""
	return QUEST_CONCLUSION.instruction


## Check for connection during Opportunity mission (D6: 5-6).
static func check_for_connection() -> bool:
	if not _is_flag_enabled("EXPANDED_CONNECTIONS"):
		return false
	return randi_range(1, 6) >= 5


## Roll connection type (D6). Returns main table entry.
static func roll_connection_type() -> Dictionary:
	if not _is_flag_enabled("EXPANDED_CONNECTIONS"):
		return {}
	var roll := randi_range(1, 6)
	for entry in CONNECTION_MAIN_TABLE:
		if roll >= entry.roll_min and roll <= entry.roll_max:
			var result: Dictionary = entry.duplicate()
			result["roll"] = roll
			return result
	return CONNECTION_MAIN_TABLE[0]


## Roll on a specific connection subtable (1-5). Returns entry.
static func roll_connection_subtable(subtable_num: int) -> Dictionary:
	if not _is_flag_enabled("EXPANDED_CONNECTIONS"):
		return {}
	var table: Array[Dictionary] = []
	match subtable_num:
		1: table.assign(CONNECTION_SUBTABLE_1)
		2: table.assign(CONNECTION_SUBTABLE_2)
		3: table.assign(CONNECTION_SUBTABLE_3)
		4: table.assign(CONNECTION_SUBTABLE_4)
		5: table.assign(CONNECTION_SUBTABLE_5)
		_: return {}
	var roll := randi_range(1, 6)
	for entry in table:
		if entry.roll == roll:
			var result: Dictionary = entry.duplicate()
			result["subtable"] = subtable_num
			return result
	return table[0] if not table.is_empty() else {}


## Get PvP setup text. Returns empty if DLC disabled.
static func get_pvp_setup() -> String:
	if not _is_flag_enabled("PVP_BATTLES"):
		return ""
	return PVP_RULES.setup


## Get PvP rules text for a specific aspect.
static func get_pvp_rules(aspect: String) -> String:
	if not _is_flag_enabled("PVP_BATTLES"):
		return ""
	return PVP_RULES.get(aspect, PVP_RULES.get("instruction", ""))


## Roll PvP battle reason (D100).
static func roll_pvp_battle_reason() -> Dictionary:
	if not _is_flag_enabled("PVP_BATTLES"):
		return {}
	var roll := randi_range(1, 100)
	for entry in PVP_BATTLE_REASON:
		if roll >= entry.roll_min and roll <= entry.roll_max:
			var result: Dictionary = entry.duplicate()
			result["roll"] = roll
			return result
	return PVP_BATTLE_REASON[0]


## Roll PvP third party deployment (D100).
static func roll_pvp_third_party() -> Dictionary:
	if not _is_flag_enabled("PVP_BATTLES"):
		return {}
	var roll := randi_range(1, 100)
	for entry in PVP_THIRD_PARTY_DEPLOYMENT:
		if roll >= entry.roll_min and roll <= entry.roll_max:
			var result: Dictionary = entry.duplicate()
			result["roll"] = roll
			return result
	return PVP_THIRD_PARTY_DEPLOYMENT[0]


## Get co-op setup text. Returns empty if DLC disabled.
static func get_coop_setup() -> String:
	if not _is_flag_enabled("COOP_BATTLES"):
		return ""
	return COOP_RULES.setup


## Get co-op rules text for a specific aspect.
static func get_coop_rules(aspect: String) -> String:
	if not _is_flag_enabled("COOP_BATTLES"):
		return ""
	return COOP_RULES.get(aspect, COOP_RULES.get("instruction", ""))


## Get introductory campaign mission. Returns empty if DLC disabled.
static func get_introductory_mission(turn_number: int) -> Dictionary:
	if not _is_flag_enabled("INTRODUCTORY_CAMPAIGN"):
		return {}
	for mission in INTRODUCTORY_CAMPAIGN:
		if mission.turn == turn_number:
			return mission
	return {}


## Get all introductory missions. Returns empty if DLC disabled.
static func get_all_introductory_missions() -> Array[Dictionary]:
	if not _is_flag_enabled("INTRODUCTORY_CAMPAIGN"):
		return []
	var result: Array[Dictionary] = []
	result.assign(INTRODUCTORY_CAMPAIGN)
	return result
