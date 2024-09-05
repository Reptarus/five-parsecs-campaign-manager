class_name EquipmentManager
extends Node

var equipment_database: Dictionary = {}

func _init():
	_load_equipment_database()

func _load_equipment_database():
	var file = FileAccess.open("res://data/equipment_database.json", FileAccess.READ)
	if file:
		var json = JSON.new()
		var parse_result = json.parse(file.get_as_text())
		if parse_result == OK:
			var data = json.get_data()
			for key in data:
				equipment_database[key] = Equipment.from_json(data[key])
		file.close()

func get_equipment(equipment_id: String) -> Equipment:
	if equipment_id in equipment_database:
		return equipment_database[equipment_id].duplicate()
	push_error("Equipment not found: " + equipment_id)
	return null

func create_equipment(equipment_id: String) -> Equipment:
	var equipment = get_equipment(equipment_id)
	if equipment:
		return equipment
	return null
