class_name PlanetfallConditionSystem
extends RefCounted

## Manages the 10-slot Campaign Condition Table and generates conditions
## from the Master Condition table. Conditions are persistent per campaign.
## Source: Planetfall pp.110-113

var _master_conditions: Array = []
var _campaign_condition_slots: Array = []
var _loaded: bool = false


func _init() -> void:
	_load_tables()


## ============================================================================
## DATA LOADING
## ============================================================================

func _load_tables() -> void:
	var data: Dictionary = _load_json("res://data/planetfall/master_conditions.json")
	_master_conditions = data.get("entries", [])
	_campaign_condition_slots = data.get("campaign_condition_slots", [])
	_loaded = not _master_conditions.is_empty()


func _load_json(path: String) -> Dictionary:
	if not ResourceLoader.exists(path):
		push_warning("PlanetfallConditionSystem: JSON not found: %s" % path)
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if not file:
		return {}
	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK:
		push_warning("PlanetfallConditionSystem: JSON parse error: %s" % path)
		file.close()
		return {}
	file.close()
	if json.data is Dictionary:
		return json.data
	return {}


## ============================================================================
## CONDITION GENERATION
## ============================================================================

func get_slot_for_roll(d100_roll: int) -> int:
	## Map a D100 roll to a Campaign Condition Table slot (0-9).
	for slot_entry in _campaign_condition_slots:
		if slot_entry is Dictionary:
			if d100_roll >= slot_entry.get("min", 0) and d100_roll <= slot_entry.get("max", 0):
				return slot_entry.get("slot", -1)
	return -1


func generate_condition(roll: int) -> Dictionary:
	## Generate a new condition from the Master Condition table via D100 roll.
	## Returns the condition entry dict (duplicated) or empty dict.
	return _lookup_d100(_master_conditions, roll)


func resolve_sub_roll(condition: Dictionary, sub_roll: int) -> Dictionary:
	## For conditions with sub_rolls, resolve the secondary effect.
	## Returns the matching sub-roll entry or empty dict.
	var sub_roll_data: Dictionary = condition.get("sub_roll", {})
	var entries: Array = sub_roll_data.get("entries", [])
	return _lookup_d100(entries, sub_roll)


func fill_condition_slot(campaign: Resource, slot_index: int, condition_roll: int) -> Dictionary:
	## Generate a condition and write it to campaign.condition_table[slot_index].
	## Returns the generated condition. If slot already filled, returns existing.
	if not campaign or not "condition_table" in campaign:
		return {}

	# Ensure table has 10 slots
	while campaign.condition_table.size() < 10:
		campaign.condition_table.append({})

	# If slot already has data, return it
	var existing: Dictionary = campaign.condition_table[slot_index] if slot_index < campaign.condition_table.size() else {}
	if not existing.is_empty():
		return existing

	# Generate new condition
	var condition: Dictionary = generate_condition(condition_roll)
	if condition.is_empty():
		return {}

	# If condition has sub-rolls, resolve them now so the result is persisted
	if condition.has("sub_roll"):
		var sub_roll_value: int = roll_d100()
		var sub_result: Dictionary = resolve_sub_roll(condition, sub_roll_value)
		condition["resolved_sub_roll"] = sub_result

	campaign.condition_table[slot_index] = condition
	return condition


func get_active_conditions(campaign: Resource) -> Array:
	## Returns non-empty condition slots from campaign.condition_table.
	var result: Array = []
	if not campaign or not "condition_table" in campaign:
		return result
	for i in range(campaign.condition_table.size()):
		var entry: Variant = campaign.condition_table[i]
		if entry is Dictionary and not entry.is_empty():
			var enriched: Dictionary = entry.duplicate()
			enriched["slot_index"] = i
			result.append(enriched)
	return result


func get_condition_count(campaign: Resource) -> int:
	## Returns how many condition slots have been filled.
	var count: int = 0
	if campaign and "condition_table" in campaign:
		for entry in campaign.condition_table:
			if entry is Dictionary and not entry.is_empty():
				count += 1
	return count


## ============================================================================
## DICE HELPERS
## ============================================================================

func roll_d100() -> int:
	return randi_range(1, 100)


## ============================================================================
## PRIVATE
## ============================================================================

func _lookup_d100(table: Array, roll: int) -> Dictionary:
	for entry in table:
		if entry is Dictionary:
			if roll >= entry.get("min", 0) and roll <= entry.get("max", 0):
				return entry.duplicate()
	return {}


func is_loaded() -> bool:
	return _loaded
