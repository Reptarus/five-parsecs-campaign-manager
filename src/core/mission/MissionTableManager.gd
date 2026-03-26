extends RefCounted
class_name MissionTableManager

## MissionTableManager — Loads and rolls on Core Rules mission tables.
##
## Provides methods for all canonical dice rolls from:
## - Mission Objectives (D10 by mission type, Core Rules pp.89-91)
## - Mission Pay + Danger Pay (1D6 + D10, Core Rules pp.83, 120)
## - Battlefield Finds (D100, Core Rules pp.120-121)
## - Rival Involvement (1D6, Core Rules pp.85-86)
## - Rival Attack Types (D10, Core Rules p.91)
## - Loot Table (D100, Core Rules pp.131-134)
## - Notable Sights (D100 by mission type, Core Rules p.88)

# Loaded table data
var _objectives_data: Dictionary = {}
var _rewards_data: Dictionary = {}
var _rival_data: Dictionary = {}
var _loot_data: Dictionary = {}
var _types_data: Dictionary = {}

# Paths
const TABLES_PATH := "res://data/mission_tables/"

func _init() -> void:
	_load_all_tables()

func _load_all_tables() -> void:
	_objectives_data = _load_json(TABLES_PATH + "mission_objectives.json")
	_rewards_data = _load_json(TABLES_PATH + "mission_rewards.json")
	_rival_data = _load_json(TABLES_PATH + "rival_involvement.json")
	_loot_data = _load_json(TABLES_PATH + "reward_items.json")
	_types_data = _load_json(TABLES_PATH + "mission_types.json")

func _load_json(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if not file:
		push_warning("MissionTableManager: Failed to load %s" % path)
		return {}
	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK:
		push_warning("MissionTableManager: Failed to parse %s" % path)
		return {}
	if json.data is Dictionary:
		return json.data
	return {}


# ── Mission Objectives (Core Rules pp.89-91) ──

## Roll D10 on the objective table for the given mission type.
## mission_type: "opportunity", "quest", or "patron"
## Returns: Dictionary with "type" (e.g. "FIGHT_OFF") and objective definition.
func roll_mission_objective(mission_type: String) -> Dictionary:
	var tables: Dictionary = _objectives_data.get("tables", {})
	var table: Dictionary = tables.get(mission_type, tables.get("opportunity", {}))
	var entries: Array = table.get("entries", [])
	if entries.is_empty():
		return _get_default_objective()

	var roll: int = randi_range(1, 10)
	for entry in entries:
		var r: Array = entry.get("roll_range", [0, 0])
		if roll >= r[0] and roll <= r[1]:
			var obj_type: String = entry.get("type", "FIGHT_OFF")
			var definitions: Dictionary = _objectives_data.get(
				"objective_definitions", {})
			var definition: Dictionary = definitions.get(
				obj_type, {})
			return {
				"type": obj_type,
				"name": definition.get("name", obj_type),
				"description": definition.get("description", ""),
				"placement_rules": definition.get(
					"placement_rules", ""),
				"victory_condition": definition.get(
					"victory_condition", ""),
				"roll": roll,
			}

	return _get_default_objective()

func _get_default_objective() -> Dictionary:
	var default_def: Dictionary = _objectives_data.get(
		"objective_definitions", {}).get("FIGHT_OFF", {})
	return {
		"type": "FIGHT_OFF",
		"name": default_def.get("name", "Fight Off"),
		"description": default_def.get("description",
			"Drive off or eliminate all enemies."),
		"placement_rules": default_def.get("placement_rules", ""),
		"victory_condition": default_def.get("victory_condition",
			"Hold the Field."),
		"roll": 0,
	}

## Get objective definition by type key (e.g. "MOVE_THROUGH").
func get_objective_definition(obj_type: String) -> Dictionary:
	return _objectives_data.get(
		"objective_definitions", {}).get(obj_type, {})


# ── Mission Pay (Core Rules p.120) ──

## Calculate base mission pay: 1D6 credits with modifiers.
## conditions: Array of strings (e.g. ["quest_finale", "won_by_objective"])
## Returns: Dictionary with "credits", "roll", "modifiers_applied".
func roll_mission_pay(conditions: Array = []) -> Dictionary:
	var roll: int = randi_range(1, 6)
	var second_roll: int = 0
	var modifiers_applied: Array = []

	# Invasion = no pay
	if "invasion_battle" in conditions:
		return {"credits": 0, "roll": 0,
			"modifiers_applied": ["invasion_battle"]}

	# Quest finale: roll twice, pick higher, +1
	if "quest_finale" in conditions:
		second_roll = randi_range(1, 6)
		roll = maxi(roll, second_roll) + 1
		modifiers_applied.append("quest_finale")

	# Won by objective: treat 1-2 as 3 (not for rival missions)
	if "won_by_objective" in conditions \
			and "rival_mission" not in conditions:
		if roll < 3:
			roll = 3
		modifiers_applied.append("won_by_objective")

	# Easy mode: +1
	if "easy_mode" in conditions:
		roll += 1
		modifiers_applied.append("easy_mode")

	return {
		"credits": roll,
		"roll": roll,
		"modifiers_applied": modifiers_applied,
	}


# ── Danger Pay (Core Rules p.83) ──

## Roll D10 for Danger Pay (patron jobs only).
## is_corporation: true if patron is Corporation type (+1 to roll).
## Returns: Dictionary with "danger_pay", "roll", "bonus_pay_rule".
func roll_danger_pay(is_corporation: bool = false) -> Dictionary:
	var roll: int = randi_range(1, 10)
	if is_corporation:
		roll += 1

	var entries: Array = _rewards_data.get(
		"danger_pay", {}).get("entries", [])
	for entry in entries:
		var r: Array = entry.get("roll_range", [0, 0])
		if roll >= r[0] and roll <= r[1]:
			return {
				"danger_pay": entry.get("danger_pay", 1),
				"roll": roll,
				"bonus_pay_rule": entry.get(
					"bonus_pay_rule", ""),
			}

	return {"danger_pay": 1, "roll": roll, "bonus_pay_rule": ""}


# ── Battlefield Finds (Core Rules pp.120-121) ──

## Roll D100 on the Battlefield Finds table.
## Only if Held the Field. Not after Invasion battles.
## Returns: Dictionary with "type", "description", "roll".
func roll_battlefield_find() -> Dictionary:
	var roll: int = randi_range(1, 100)
	var entries: Array = _rewards_data.get(
		"battlefield_finds", {}).get("entries", [])
	for entry in entries:
		var r: Array = entry.get("roll_range", [0, 0])
		if roll >= r[0] and roll <= r[1]:
			return {
				"type": entry.get("type", "NOTHING"),
				"description": entry.get("description", ""),
				"roll": roll,
			}
	return {"type": "NOTHING", "description": "Nothing of value.",
		"roll": roll}


# ── Rival Check (Core Rules pp.85-86) ──

## Check if a rival tracks you down.
## rival_count: number of active rivals.
## decoy_count: number of crew sent as decoy.
## Returns: Dictionary with "tracked_down" (bool), "roll".
func check_rival_tracking(rival_count: int,
		decoy_count: int = 0) -> Dictionary:
	if rival_count <= 0:
		return {"tracked_down": false, "roll": 0}

	var roll: int = randi_range(1, 6)
	roll += decoy_count  # Decoys add to roll (harder for rivals)
	var tracked: bool = roll <= rival_count
	return {"tracked_down": tracked, "roll": roll}


## Roll D10 on the Rival Attack Type table (Core Rules p.91).
## tracked_down: if rival was tracked via crew task, always Showdown.
## Returns: Dictionary with "type", "description", "roll".
func roll_rival_attack_type(
		tracked_down: bool = false) -> Dictionary:
	if tracked_down:
		return {
			"type": "SHOWDOWN",
			"description": "Straight-up fight. No modifications.",
			"roll": 0,
		}

	var roll: int = randi_range(1, 10)
	var entries: Array = _rival_data.get(
		"rival_attack_types", {}).get("entries", [])
	for entry in entries:
		var r: Array = entry.get("roll_range", [0, 0])
		if roll >= r[0] and roll <= r[1]:
			return {
				"type": entry.get("type", "SHOWDOWN"),
				"description": entry.get("description", ""),
				"roll": roll,
			}
	return {"type": "SHOWDOWN",
		"description": "Straight-up fight.", "roll": roll}


# ── Loot Table (Core Rules pp.131-134) ──

## Roll D100 on the main Loot Table to determine loot category.
## Returns: Dictionary with "category", "action", "roll".
func roll_loot_category() -> Dictionary:
	var roll: int = randi_range(1, 100)
	var entries: Array = _loot_data.get(
		"loot_categories", {}).get("entries", [])
	for entry in entries:
		var r: Array = entry.get("roll_range", [0, 0])
		if roll >= r[0] and roll <= r[1]:
			return {
				"category": entry.get("category", "REWARDS"),
				"action": entry.get("action", ""),
				"roll": roll,
			}
	return {"category": "REWARDS",
		"action": "Roll once on Rewards Subtable.", "roll": roll}

## Roll D100 on the Rewards Subtable.
## Returns: Dictionary with "type", "effect", "roll".
func roll_rewards_subtable() -> Dictionary:
	var roll: int = randi_range(1, 100)
	var entries: Array = _loot_data.get(
		"rewards_subtable", {}).get("entries", [])
	for entry in entries:
		var r: Array = entry.get("roll_range", [0, 0])
		if roll >= r[0] and roll <= r[1]:
			return {
				"type": entry.get("type", "SCRAP"),
				"effect": entry.get("effect", "3 credits."),
				"roll": roll,
			}
	return {"type": "SCRAP", "effect": "3 credits.", "roll": roll}


# ── Notable Sights (Core Rules p.88) ──

## Roll D100 on the Notable Sights table.
## mission_type: "opportunity_patron", "rival", or "quest".
## Returns: Dictionary with "type", "effect", "roll".
func roll_notable_sight(
		mission_type: String = "opportunity_patron") -> Dictionary:
	var roll: int = randi_range(1, 100)
	var columns: Dictionary = _loot_data.get(
		"notable_sights", {}).get("columns", {})
	var entries: Array = columns.get(
		mission_type, columns.get("opportunity_patron", []))
	for entry in entries:
		var r: Array = entry.get("roll_range", [0, 0])
		if roll >= r[0] and roll <= r[1]:
			return {
				"type": entry.get("type", "NOTHING"),
				"effect": entry.get("effect", "Nothing special."),
				"roll": roll,
			}
	return {"type": "NOTHING", "effect": "Nothing special.",
		"roll": roll}


# ── Mission Type Info ──

## Get the available mission types for the current campaign state.
## Returns: Array of type info Dictionaries.
func get_available_mission_types(
		has_patron: bool, has_quest: bool,
		tracked_rival: bool) -> Array:
	var options: Array = []
	var selection = _types_data.get("selection_options", {})
	for opt in selection.get("options", []):
		var cond: String = opt.get("condition", "always")
		var available := false
		match cond:
			"always":
				available = true
			"active_patron":
				available = has_patron
			"active_quest":
				available = has_quest
			"tracked_rival":
				available = tracked_rival
		if available:
			options.append({
				"type": opt.get("type", "OPPORTUNITY"),
				"description": opt.get("description", ""),
			})
	return options

## Get the objective table key for a mission type.
func get_objective_table_for_type(
		mission_type: String) -> String:
	var types: Dictionary = _types_data.get("types", {})
	var type_info: Dictionary = types.get(
		mission_type.to_upper(), {})
	var table: Variant = type_info.get("objective_table", null)
	if table is String:
		return table
	return "opportunity"

## Get the deployment column for a mission type.
func get_deployment_column_for_type(
		mission_type: String) -> String:
	var types: Dictionary = _types_data.get("types", {})
	var type_info: Dictionary = types.get(
		mission_type.to_upper(), {})
	var col: Variant = type_info.get("deployment_column", null)
	if col is String:
		return col
	return "opportunity_patron"
