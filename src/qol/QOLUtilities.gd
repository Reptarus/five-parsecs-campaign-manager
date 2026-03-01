extends Node
class_name QOLUtilities

## QOL Utilities - Collection of small utility features
## Singleton autoload: QOLUtils

signal undo_state_changed(can_undo: bool, can_redo: bool)

## Undo/Redo system
var undo_stack: Array[Dictionary] = []
var redo_stack: Array[Dictionary] = []
const MAX_UNDO_STACK: int = 10

## Dice statistics
var dice_rolls: Array[Dictionary] = []
var dice_stats: Dictionary = {}

## === UNDO/REDO SYSTEM ===

func push_undo_state(action_type: String, state_data: Dictionary) -> void:
	## Save state for undo
	undo_stack.append({
		"action_type": action_type,
		"timestamp": Time.get_unix_time_from_system(),
		"state": state_data
	})
	
	if undo_stack.size() > MAX_UNDO_STACK:
		undo_stack.pop_front()
	
	redo_stack.clear()  # Clear redo on new action
	undo_state_changed.emit(can_undo(), can_redo())

func undo_last_action() -> bool:
	## Undo the last action
	if undo_stack.is_empty():
		return false
	
	var state = undo_stack.pop_back()
	redo_stack.append(state)
	
	# TODO: Actually restore state (needs GameState integration)
	undo_state_changed.emit(can_undo(), can_redo())
	return true

func redo_action() -> bool:
	## Redo an undone action
	if redo_stack.is_empty():
		return false
	
	var state = redo_stack.pop_back()
	undo_stack.append(state)
	
	undo_state_changed.emit(can_undo(), can_redo())
	return true

func can_undo() -> bool:
	return not undo_stack.is_empty()

func can_redo() -> bool:
	return not redo_stack.is_empty()

func clear_undo_stack() -> void:
	undo_stack.clear()
	redo_stack.clear()
	undo_state_changed.emit(false, false)

## === DICE STATISTICS ===

func record_dice_roll(result: int, context: String = "") -> void:
	## Track a dice roll
	dice_rolls.append({
		"result": result,
		"context": context,
		"timestamp": Time.get_unix_time_from_system()
	})
	
	_update_dice_stats()

func get_dice_statistics() -> Dictionary:
	## Get dice roll statistics
	return dice_stats.duplicate()

func is_on_hot_streak() -> bool:
	## Check if currently on hot streak (3+ high rolls)
	if dice_rolls.size() < 3:
		return false
	
	var recent = dice_rolls.slice(-3)
	return recent.all(func(r): return r.result >= 5)

func is_on_cold_streak() -> bool:
	## Check if currently on cold streak (3+ low rolls)
	if dice_rolls.size() < 3:
		return false
	
	var recent = dice_rolls.slice(-3)
	return recent.all(func(r): return r.result <= 2)

func _update_dice_stats() -> void:
	## Recalculate dice statistics
	if dice_rolls.is_empty():
		return
	
	var total = 0
	var distribution = {}
	
	for roll in dice_rolls:
		total += roll.result
		if not distribution.has(roll.result):
			distribution[roll.result] = 0
		distribution[roll.result] += 1
	
	dice_stats = {
		"total_rolls": dice_rolls.size(),
		"average": float(total) / dice_rolls.size(),
		"distribution": distribution,
		"hot_streak": is_on_hot_streak(),
		"cold_streak": is_on_cold_streak()
	}

## === BULK ACTIONS ===

func bulk_sell_items(items: Array) -> int:
	## Sell multiple items at once - returns total credits
	var total_credits = 0
	for item in items:
		if item.has("value"):
			total_credits += item.value
	return total_credits

func apply_healing_to_crew(crew: Array, healing_amount: int) -> void:
	## Apply healing to all crew members
	for character in crew:
		if character.has("current_health") and character.has("max_health"):
			character.current_health = min(character.current_health + healing_amount, character.max_health)

## === SAVE/LOAD ===

func load_from_save(save_data: Dictionary) -> void:
	if save_data.has("qol_data") and save_data.qol_data.has("utilities"):
		var utils_data = save_data.qol_data.utilities
		dice_rolls = utils_data.get("dice_rolls", [])
		_update_dice_stats()

func save_to_dict() -> Dictionary:
	return {
		"dice_rolls": dice_rolls.slice(-100)  # Keep last 100 rolls
	}
