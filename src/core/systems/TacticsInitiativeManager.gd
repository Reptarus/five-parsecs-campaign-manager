class_name TacticsInitiativeManager
extends RefCounted

## TacticsInitiativeManager - Alternating activation initiative system
## Replaces AoF token bag with Tactics' D6-per-unit initiative rolls.
## Each unit rolls D6 at start of round, high picks activation order.
## Ties broken by Training stat, then player choice.
## Units may delay activation to act later in the round.
## Source: Five Parsecs: Tactics rulebook pp.28-30

## Activation entry: tracks one unit's initiative for a round
## {unit_id, unit_name, side ("player"/"enemy"), initiative_roll, training,
##  has_activated, is_delayed, activation_order}

signal initiative_rolled(results: Array)
signal unit_activated(unit_id: String)
signal unit_delayed(unit_id: String)
signal round_complete()

var _entries: Array = []  # Array of initiative entry dicts
var _current_index: int = -1
var _round_number: int = 0


## Roll initiative for all units at the start of a battle round.
## units: Array of {unit_id, unit_name, side, training, reactions}
func roll_initiative(units: Array) -> Array:
	_round_number += 1
	_entries.clear()
	_current_index = -1

	for unit in units:
		if unit is not Dictionary:
			continue
		var roll: int = _roll_d6()
		_entries.append({
			"unit_id": unit.get("unit_id", ""),
			"unit_name": unit.get("unit_name", ""),
			"side": unit.get("side", "player"),
			"initiative_roll": roll,
			"training": unit.get("training", 0),
			"reactions": unit.get("reactions", 1),
			"has_activated": false,
			"is_delayed": false,
			"activation_order": 0,
		})

	# Sort: highest initiative first, tiebreak by training (higher first)
	_entries.sort_custom(_compare_initiative)

	# Assign activation order
	for i in range(_entries.size()):
		_entries[i]["activation_order"] = i + 1

	initiative_rolled.emit(_entries.duplicate(true))
	return _entries.duplicate(true)


## Get the next unit to activate (skipping already-activated and delayed).
func get_next_activation() -> Dictionary:
	for entry in _entries:
		if entry is Dictionary and not entry["has_activated"] and not entry["is_delayed"]:
			return entry.duplicate()
	# Check delayed units (they activate after all non-delayed)
	for entry in _entries:
		if entry is Dictionary and not entry["has_activated"] and entry["is_delayed"]:
			return entry.duplicate()
	return {}


## Mark a unit as having completed its activation.
func activate_unit(unit_id: String) -> void:
	for entry in _entries:
		if entry is Dictionary and entry["unit_id"] == unit_id:
			entry["has_activated"] = true
			unit_activated.emit(unit_id)
			break

	if _all_activated():
		round_complete.emit()


## Delay a unit's activation (will activate after all non-delayed units).
func delay_unit(unit_id: String) -> void:
	for entry in _entries:
		if entry is Dictionary and entry["unit_id"] == unit_id:
			entry["is_delayed"] = true
			unit_delayed.emit(unit_id)
			break


## Check if all units have activated this round.
func _all_activated() -> bool:
	for entry in _entries:
		if entry is Dictionary and not entry["has_activated"]:
			return false
	return true


## Get all entries for display (sorted by activation order).
func get_activation_order() -> Array:
	return _entries.duplicate(true)


## Get entries for one side.
func get_side_entries(side: String) -> Array:
	var result: Array = []
	for entry in _entries:
		if entry is Dictionary and entry["side"] == side:
			result.append(entry.duplicate())
	return result


## Get count of remaining activations for a side.
func get_remaining_activations(side: String) -> int:
	var count: int = 0
	for entry in _entries:
		if entry is Dictionary and entry["side"] == side and not entry["has_activated"]:
			count += 1
	return count


## Get current round number.
func get_round_number() -> int:
	return _round_number


## Compare two initiative entries for sorting (highest first).
func _compare_initiative(a: Dictionary, b: Dictionary) -> bool:
	# Higher initiative roll first
	if a["initiative_roll"] != b["initiative_roll"]:
		return a["initiative_roll"] > b["initiative_roll"]
	# Tiebreak: higher training first
	if a["training"] != b["training"]:
		return a["training"] > b["training"]
	# Final tiebreak: player before enemy (player advantage)
	if a["side"] != b["side"]:
		return a["side"] == "player"
	return false


func _roll_d6() -> int:
	var dm = Engine.get_main_loop().root.get_node_or_null("/root/DiceManager") \
		if Engine.get_main_loop() else null
	if dm and dm.has_method("roll_dice"):
		var result: Variant = dm.roll_dice(1, 6)
		if result is Array and result.size() > 0:
			return result[0]
		elif result is int:
			return result
	return randi_range(1, 6)
