class_name CompendiumStealthMissions
extends RefCounted
## Stealth Missions — Compendium pp.117-124
##
## Infiltration missions with stealth rounds, detection mechanics, and
## alarm-triggered transition to conventional combat. Crew tries to achieve
## an objective undetected; if spotted, reinforcements arrive each round.
##
## All output is TEXT INSTRUCTIONS for the tabletop companion model.
## Gated behind DLCManager.ContentFlag.STEALTH_MISSIONS.
##
## Integration notes (p.117):
##   - Enemy Deployment Variables (p.44) are NOT used
##   - Escalating Battles (p.46) do NOT apply during Stealth rounds or Round 1
##   - NOT compatible with Grid-based Movement or No-minis Combat Resolution
##   - Requires conventional miniatures rules on 3x3 ft table (halve distances for 2x2)


## ============================================================================
## DLC GATING
## ============================================================================

static func _is_enabled() -> bool:
	var dlc_mgr = Engine.get_main_loop().root.get_node_or_null("/root/DLCManager") if Engine.get_main_loop() else null
	if not dlc_mgr:
		return false
	return dlc_mgr.is_feature_enabled(dlc_mgr.ContentFlag.STEALTH_MISSIONS)



## ============================================================================
## COMPENDIUM DATA LOADING (from JSON)
## ============================================================================

static var _data: Dictionary = {}
static var _loaded: bool = false

static func _ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	var file := FileAccess.open("res://data/compendium/stealth_missions.json", FileAccess.READ)
	if not file:
		push_warning("CompendiumStealthMissions: Could not load stealth_missions.json")
		return
	var json := JSON.new()
	if json.parse(file.get_as_text()) == OK and json.data is Dictionary:
		_data = json.data
	file.close()

static var STEALTH_OBJECTIVES: Array:
	get:
		_ensure_loaded()
		return _data.get("stealth_objectives", [])

static var INDIVIDUAL_PROFILE: Dictionary:
	get:
		_ensure_loaded()
		return _data.get("individual_profile", {})

static var INDIVIDUAL_TYPES: Array:
	get:
		_ensure_loaded()
		return _data.get("individual_types", [])

static var INDIVIDUAL_RULES: String:
	get:
		_ensure_loaded()
		return _data.get("individual_rules", "")

static var FINDING_TARGET_RULES: String:
	get:
		_ensure_loaded()
		return _data.get("finding_target_rules", "")

static var ITEM_RULES: String:
	get:
		_ensure_loaded()
		return _data.get("item_rules", "")

static var DEPLOYMENT_RULES: String:
	get:
		_ensure_loaded()
		return _data.get("deployment_rules", "")

static var STEALTH_ROUND_RULES: String:
	get:
		_ensure_loaded()
		return _data.get("stealth_round_rules", "")

static var DETECTION_RULES: String:
	get:
		_ensure_loaded()
		return _data.get("detection_rules", "")

static var STEALTH_TOOLS: Array:
	get:
		_ensure_loaded()
		return _data.get("stealth_tools", [])

static var STEALTH_ATTACK_RULES: String:
	get:
		_ensure_loaded()
		return _data.get("stealth_attack_rules", "")

static var ALARM_RULES: String:
	get:
		_ensure_loaded()
		return _data.get("alarm_rules", "")

static var PSIONIC_RULES: String:
	get:
		_ensure_loaded()
		return _data.get("psionic_rules", "")

static var EXFILTRATION_RULES: String:
	get:
		_ensure_loaded()
		return _data.get("exfiltration_rules", "")

static var MISSION_TYPE_SELECTION: Dictionary:
	get:
		_ensure_loaded()
		return _data.get("mission_type_selection", {})

## ============================================================================
## QUERY METHODS
## ============================================================================

## Roll a stealth mission objective. Returns objective dict.
static func roll_objective() -> Dictionary:
	if not _is_enabled():
		return {}

	var roll := randi_range(1, 100)
	for obj in STEALTH_OBJECTIVES:
		if roll >= obj.roll_min and roll <= obj.roll_max:
			var result: Dictionary = obj.duplicate()
			result["roll"] = roll
			return result

	return STEALTH_OBJECTIVES[0]


## Roll the type of individual for objective. Returns {id, name}.
static func roll_individual_type() -> Dictionary:
	var roll := randi_range(1, 100)
	for ind in INDIVIDUAL_TYPES:
		if roll >= ind.roll_min and roll <= ind.roll_max:
			var result: Dictionary = ind.duplicate()
			result["roll"] = roll
			result["profile"] = INDIVIDUAL_PROFILE
			return result

	return INDIVIDUAL_TYPES[0]


## Determine battle type for a given mission source. Returns battle type string.
## mission_source: "rival", "invasion", "opportunity", "patron", "faction", "quest"
## Returns: "conventional", "stealth", "street_fight", or "salvage"
static func roll_battle_type(mission_source: String) -> String:
	var source_key := mission_source.to_lower()
	if not MISSION_TYPE_SELECTION.has(source_key):
		return "conventional"

	var table: Dictionary = MISSION_TYPE_SELECTION[source_key]
	var roll := randi_range(1, 6)

	if table.stealth.size() == 2 and roll >= table.stealth[0] and roll <= table.stealth[1]:
		return "stealth"
	if table.street_fight.size() == 2 and roll >= table.street_fight[0] and roll <= table.street_fight[1]:
		return "street_fight"
	if table.salvage.size() == 2 and roll >= table.salvage[0] and roll <= table.salvage[1]:
		# Salvage requires Freelancer's Handbook
		var dlc_mgr = Engine.get_main_loop().root.get_node_or_null("/root/DLCManager") if Engine.get_main_loop() else null
		if dlc_mgr and dlc_mgr.is_feature_enabled(dlc_mgr.ContentFlag.SALVAGE_JOBS):
			return "salvage"
		return "stealth" # Fallback per book rule
	return "conventional"


## Get full stealth mission setup as a single instruction block.
static func generate_mission_setup() -> Dictionary:
	if not _is_enabled():
		return {}

	var objective := roll_objective()
	var setup: Dictionary = {
		"objective": objective,
		"deployment": DEPLOYMENT_RULES,
		"stealth_rounds": STEALTH_ROUND_RULES,
		"detection": DETECTION_RULES,
		"tools": STEALTH_TOOLS,
		"attack_rules": STEALTH_ATTACK_RULES,
		"alarm": ALARM_RULES,
		"exfiltration": EXFILTRATION_RULES,
		"item_rules": ITEM_RULES,
		"psionic_rules": PSIONIC_RULES,
	}

	if objective.get("has_individual", false):
		setup["individual"] = roll_individual_type()
		setup["individual_rules"] = INDIVIDUAL_RULES

	if objective.get("requires_finding", false):
		setup["finding_target"] = FINDING_TARGET_RULES

	return setup


## Get mission type selection instruction for a given source.
static func get_mission_type_instruction(mission_source: String) -> String:
	var source_key := mission_source.to_lower()
	if MISSION_TYPE_SELECTION.has(source_key):
		return MISSION_TYPE_SELECTION[source_key].instruction
	return "MISSION TYPE: Conventional battle (default)."
