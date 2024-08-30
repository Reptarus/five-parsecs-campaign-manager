class_name EquipmentManager
extends Node

var equipment_database: Dictionary = {}

func _init():
	_load_equipment_database()

func _load_equipment_database():
	# Load equipment data from a file or create it programmatically
	pass

func get_equipment(equipment_id: String) -> Equipment:
	if equipment_id in equipment_database:
		return equipment_database[equipment_id]
	push_error("Equipment not found: " + equipment_id)
	return null

func create_equipment(equipment_id: String) -> Equipment:
	var equipment = get_equipment(equipment_id)
	if equipment:
		return equipment.duplicate()
	return null
