@tool
extends Resource
# Renamed to avoid conflict with a global class
class_name ManagerResourceTransaction

# This class represents a transaction in the ResourceManager (different from ResourceSystem)
# It is specifically used for tracking resource changes in the manager context
# For ResourceSystem transactions, dictionaries are used instead of class instances

var resource_type: int
var old_value: int
var new_value: int
var change_amount: int
var source: String
var timestamp: int
var turn_number: int

func _init(p_type: int, p_old: int, p_new: int, p_source: String, p_turn: int) -> void:
	resource_type = p_type
	old_value = p_old
	new_value = p_new
	change_amount = p_new - p_old
	source = p_source
	timestamp = Time.get_unix_time_from_system()
	turn_number = p_turn
	
# Convert to dictionary representation (for compatibility with ResourceSystem)
func to_dict() -> Dictionary:
	return {
		"resource_type": resource_type,
		"old_value": old_value,
		"new_value": new_value,
		"change_amount": change_amount,
		"source": source,
		"timestamp": timestamp,
		"turn_number": turn_number,
		"transaction_type": "ADD" if change_amount > 0 else "REMOVE"
	}