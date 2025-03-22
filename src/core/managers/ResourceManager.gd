@tool
extends Resource
class_name ResourceManager

# Use absolute paths to ensure correct resolution
const GameEnums = preload("res://src/core/systems/GlobalEnums.gd")
const ResourceManagerTransactionClass = preload("res://src/core/managers/ResourceTransaction.gd")

signal resource_changed(resource_type: int, old_value: int, new_value: int, source: String)
signal resource_threshold_reached(resource_type: int, threshold: int, current_value: int)
signal resource_depleted(resource_type: int)
signal resource_history_updated(resource_type: int, history_entry: Dictionary)

var resources: Dictionary = {}
var resource_history: Dictionary = {}
var resource_thresholds: Dictionary = {}

const MAX_HISTORY_ENTRIES = 100
const HISTORY_PRUNE_THRESHOLD = 120

func _init() -> void:
	_initialize_resources()
	_initialize_history()

func _initialize_resources() -> void:
	for resource_type in GameEnums.ResourceType.values():
		resources[resource_type] = 0
		resource_thresholds[resource_type] = {}

func _initialize_history() -> void:
	for resource_type in GameEnums.ResourceType.values():
		resource_history[resource_type] = []

func set_resource(resource_type: int, value: int, source: String = "system") -> void:
	if not resource_type in resources:
		push_error("Invalid resource type: %d" % resource_type)
		return
	
	var old_value = resources[resource_type]
	resources[resource_type] = value
	
	_add_history_entry(resource_type, old_value, value, source)
	_check_thresholds(resource_type, value)
	
	resource_changed.emit(resource_type, old_value, value, source)
	
	if value <= 0:
		resource_depleted.emit(resource_type)

func modify_resource(resource_type: int, amount: int, source: String = "system") -> void:
	if not resource_type in resources:
		push_error("Invalid resource type: %d" % resource_type)
		return
	
	var old_value = resources[resource_type]
	var new_value = old_value + amount
	
	set_resource(resource_type, new_value, source)

func get_resource(resource_type: int) -> int:
	return resources.get(resource_type, 0)

func has_resource(resource_type: int) -> bool:
	return resource_type in resources

func set_resource_threshold(resource_type: int, threshold: int, value: int) -> void:
	if not resource_type in resource_thresholds:
		resource_thresholds[resource_type] = {}
	
	resource_thresholds[resource_type][threshold] = value

func get_resource_threshold(resource_type: int, threshold: int) -> int:
	return resource_thresholds.get(resource_type, {}).get(threshold, 0)

func _check_thresholds(resource_type: int, value: int) -> void:
	if not resource_type in resource_thresholds:
		return
	
	for threshold in resource_thresholds[resource_type]:
		if value <= threshold:
			resource_threshold_reached.emit(resource_type, threshold, value)

func _add_history_entry(resource_type: int, old_value: int, new_value: int, source: String) -> void:
	var entry = ResourceManagerTransactionClass.new(
		resource_type,
		old_value,
		new_value,
		source,
		get_current_turn()
	)
	
	resource_history[resource_type].append(entry)
	resource_history_updated.emit(resource_type, _create_history_entry_dict(entry))
	
	_prune_history_if_needed(resource_type)

func _prune_history_if_needed(resource_type: int) -> void:
	var history = resource_history[resource_type]
	if history.size() > HISTORY_PRUNE_THRESHOLD:
		history = history.slice(- MAX_HISTORY_ENTRIES)
		resource_history[resource_type] = history

func get_resource_history(resource_type: int, limit: int = -1) -> Array:
	if not resource_type in resource_history:
		return []
	
	var history = resource_history[resource_type]
	if limit > 0:
		history = history.slice(- limit)
	
	return history.map(_create_history_entry_dict)

func get_resource_changes_by_turn(resource_type: int, turn_number: int) -> Array:
	if not resource_type in resource_history:
		return []
	
	return resource_history[resource_type].filter(
		func(entry): return entry.turn_number == turn_number
	).map(_create_history_entry_dict)

func get_resource_analytics(resource_type: int) -> Dictionary:
	if not resource_type in resource_history:
		return {}
	
	var history = resource_history[resource_type]
	if history.is_empty():
		return {}
	
	var total_changes := 0
	var positive_changes := 0
	var negative_changes := 0
	var largest_gain := 0
	var largest_loss := 0
	
	for entry in history:
		var change = entry.change_amount
		total_changes += change
		
		if change > 0:
			positive_changes += change
			largest_gain = maxi(largest_gain, change)
		elif change < 0:
			negative_changes += change
			largest_loss = mini(largest_loss, change)
	
	return {
		"total_changes": total_changes,
		"positive_changes": positive_changes,
		"negative_changes": negative_changes,
		"largest_gain": largest_gain,
		"largest_loss": largest_loss,
		"average_change": float(total_changes) / history.size()
	}

func _create_history_entry_dict(entry) -> Dictionary:
	return {
		"resource_type": entry.resource_type,
		"old_value": entry.old_value,
		"new_value": entry.new_value,
		"change_amount": entry.change_amount,
		"source": entry.source,
		"timestamp": entry.timestamp,
		"turn_number": entry.turn_number
	}

func get_current_turn() -> int:
	# This should be implemented to return the current game turn
	return 0 # Placeholder