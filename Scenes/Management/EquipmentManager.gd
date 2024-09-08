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

func generate_equipment_from_background(background: Dictionary) -> Array:
	var equipment = []
	if "starting_gear" in background:
		for item_name in background.starting_gear:
			equipment.append(get_equipment(item_name))
	return equipment

func generate_equipment_from_motivation(motivation: Dictionary) -> Array:
	var equipment = []
	if "starting_gear" in motivation:
		for item_name in motivation.starting_gear:
			equipment.append(get_equipment(item_name))
	return equipment

func generate_equipment_from_class(class_type: Dictionary) -> Array:
	var equipment = []
	if "starting_gear" in class_type:
		for item_name in class_type.starting_gear:
			equipment.append(get_equipment(item_name))
	return equipment

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
