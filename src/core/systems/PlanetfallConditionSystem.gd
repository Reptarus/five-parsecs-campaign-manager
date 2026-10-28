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
		var sub_roll_value: int = _d100("Planetfall Condition Detail")
		var sub_result: Dictionary = resolve_sub_roll(condition, sub_roll_value)
		condition["resolved_sub_roll"] = sub_result

	campaign.condition_table[slot_index] = condition
	return condition


## A mission that determines a Condition (p.110): D100 on the Campaign Condition
## table; a blank entry rolls the Master Condition table and is written in, a filled
## entry is "the same Condition again, including any secondary rolls". The Master roll
## happens only for a blank entry, so a forced value is never spent on a filled one.
func roll_mission_condition(campaign: Resource) -> Dictionary:
	if not campaign or not "condition_table" in campaign:
		return {}
	var slot: int = get_slot_for_roll(_d100("Planetfall Condition Slot"))
	if slot < 0:
		return {}
	if slot < campaign.condition_table.size() and campaign.condition_table[slot] is Dictionary \
			and not (campaign.condition_table[slot] as Dictionary).is_empty():
		return campaign.condition_table[slot]
	return fill_condition_slot(campaign, slot, _d100("Planetfall Battlefield Condition"))


## 4th Milestone (p.157): "Erase one campaign battlefield condition from the table on
## your Colony Tracking Sheet and generate a new condition to take its place." The
## player picks the entry; the new one is a fresh Master Condition roll written into
## the same entry, and may repeat the old one (the page does not say to reroll). Spends
## one owed replacement. Returns {slot, erased, condition}, or {} when nothing is owed
## or the entry is blank.
func replace_condition(campaign: Resource, slot_index: int) -> Dictionary:
	if not campaign or not "condition_table" in campaign \
			or not "pending_condition_replacements" in campaign:
		return {}
	if int(campaign.pending_condition_replacements) <= 0:
		return {}
	if slot_index < 0 or slot_index >= campaign.condition_table.size():
		return {}
	var old: Variant = campaign.condition_table[slot_index]
	if not old is Dictionary or (old as Dictionary).is_empty():
		return {}
	campaign.condition_table[slot_index] = {}
	var fresh: Dictionary = fill_condition_slot(campaign, slot_index,
			_d100("Planetfall Battlefield Condition"))
	if fresh.is_empty():
		campaign.condition_table[slot_index] = old
		return {}
	campaign.pending_condition_replacements -= 1
	return {"slot": slot_index, "erased": old, "condition": fresh}


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


## p.64 Changing climate conditions: "Erase a random existing entry from your Campaign
## Conditions table. It is filled again when you roll that entry again." Picked as
## PlanetfallLifeformGenerator.erase_random_entry() picks. Returns the slot, or -1.
func erase_random_entry(campaign: Resource) -> int:
	if not campaign or not "condition_table" in campaign:
		return -1
	var filled: Array = []
	for i in range(campaign.condition_table.size()):
		var entry: Variant = campaign.condition_table[i]
		if entry is Dictionary and not (entry as Dictionary).is_empty():
			filled.append(i)
	if filled.is_empty():
		return -1
	var slot: int = filled[0]
	for _try in range(100):
		var pick: int = _d10("Planetfall Erase Condition") - 1
		if filled.has(pick):
			slot = pick
			break
	campaign.condition_table[slot] = {}
	return slot


static func get_condition_count(campaign: Resource) -> int:
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

static func _dice() -> Node:
	var loop := Engine.get_main_loop()
	return (loop as SceneTree).root.get_node_or_null("/root/DiceManager") \
		if loop is SceneTree else null


func _d100(context: String) -> int:
	var dm := _dice()
	return int(dm.roll_d100(context)) if dm else randi_range(1, 100)


func _d10(context: String) -> int:
	var dm := _dice()
	return int(dm.roll_d10(context)) if dm else randi_range(1, 10)


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
