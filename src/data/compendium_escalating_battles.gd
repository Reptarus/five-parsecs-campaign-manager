class_name CompendiumEscalatingBattles
extends RefCounted
## Escalating Battles — Compendium pp.46-47
##
## At end of each round, if any enemy removed, objective reached, or
## outnumbered by 3+ at end of Round 1, perform an Escalation check.
## Max 3 escalation rolls per battle. D100 by AI type.
##
## All output is TEXT INSTRUCTIONS for the tabletop companion model.
## Gated behind DLCManager.ContentFlag.ESCALATING_BATTLES.


## ============================================================================
## JSON DATA LOADING
## ============================================================================

static var _data: Dictionary = {}
static var _loaded: bool = false

static func _ensure_loaded() -> void:
	if _loaded: return
	_loaded = true
	var file := FileAccess.open("res://data/compendium/escalating_battles.json", FileAccess.READ)
	if not file:
		push_warning("CompendiumEscalatingBattles: Could not load escalating_battles.json")
		return
	var json := JSON.new()
	if json.parse(file.get_as_text()) == OK and json.data is Dictionary:
		_data = json.data
	file.close()


## ============================================================================
## DLC GATING
## ============================================================================

static func _is_enabled() -> bool:
	var dlc_mgr = Engine.get_main_loop().root.get_node_or_null("/root/DLCManager") if Engine.get_main_loop() else null
	if not dlc_mgr:
		return false
	return dlc_mgr.is_feature_enabled(dlc_mgr.ContentFlag.ESCALATING_BATTLES)


## ============================================================================
## ESCALATION TRIGGER RULES
## ============================================================================

static var TRIGGER_RULES: String:
	get:
		_ensure_loaded()
		return _data.get("trigger_rules", "")


## ============================================================================
## ESCALATION EFFECTS (Compendium p.47)
## ============================================================================

static var ESCALATION_EFFECTS: Array:
	get:
		_ensure_loaded()
		return _data.get("escalation_effects", [])

## D100 ranges by AI type. Values = [effect_index, roll_min, roll_max]
## Effect indices match ESCALATION_EFFECTS array order
static var ESCALATION_TABLES: Dictionary:
	get:
		_ensure_loaded()
		return _data.get("escalation_tables", {})


## ============================================================================
## QUERY METHODS
## ============================================================================

## Check if escalation should trigger this round.
static func should_escalate(enemies_removed: bool, objective_reached: bool,
		round_number: int, enemy_count: int, crew_count: int,
		escalations_so_far: int) -> bool:
	if not _is_enabled():
		return false
	if escalations_so_far >= 3:
		return false
	if enemies_removed or objective_reached:
		return true
	if round_number == 1 and crew_count >= enemy_count + 3:
		return true
	return false


## Roll escalation effect for a given AI type. Returns effect dict.
static func roll_escalation(ai_type: String) -> Dictionary:
	if not _is_enabled():
		return {}

	var ai_key := ai_type.to_lower()
	if not ESCALATION_TABLES.has(ai_key):
		return ESCALATION_EFFECTS[0]

	var roll := randi_range(1, 100)
	var table: Array = ESCALATION_TABLES[ai_key]
	for entry in table:
		var effect_idx: int = entry[0]
		var r_min: int = entry[1]
		var r_max: int = entry[2]
		if roll >= r_min and roll <= r_max:
			var result: Dictionary = ESCALATION_EFFECTS[effect_idx].duplicate()
			result["roll"] = roll
			result["ai_type"] = ai_key
			return result

	return ESCALATION_EFFECTS[0]


## Get escalation effect by ID.
static func get_escalation_effect(effect_id: String) -> Dictionary:
	for effect in ESCALATION_EFFECTS:
		if effect.id == effect_id:
			return effect
	return {}


## Optional variation rule: if same result rolled twice, ignore it
## (doesn't count toward the 3-roll limit).
static func check_variation_duplicate(effect_id: String, prior_effects: Array) -> bool:
	return effect_id in prior_effects
