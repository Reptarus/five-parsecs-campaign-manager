@tool
extends Resource
class_name BaseEquipment

# Base equipment properties
var item_id: String = ""
var item_name: String = "Unknown Equipment"
var item_description: String = ""
var item_type: int = 0
var item_value: int = 0
var item_weight: float = 1.0

func _init() -> void:
	# Default initialization
	pass

## Get the display name of the equipment
func get_display_name() -> String:
	return item_name

## Get the description of the equipment
func get_description() -> String:
	return item_description

## Get the value of the equipment
func get_value() -> int:
	return item_value

## Get the weight of the equipment
func get_weight() -> float:
	return item_weight

## Get equipment data as dictionary
func to_dictionary() -> Dictionary:
	return {
		"id": item_id,
		"name": item_name,
		"description": item_description,
		"type": item_type,
		"value": item_value,
		"weight": item_weight
	}

## Initialize the equipment from data
func initialize_from_data(data: Dictionary) -> bool:
	if data.is_empty():
		return false
		
	item_id = data.get("id", "")
	item_name = data.get("name", "Unknown Equipment")
	item_description = data.get("description", "")
	item_type = data.get("type", 0)
	item_value = data.get("value", 0)
	item_weight = data.get("weight", 1.0)
	
	return true
