class_name EquipmentManager
extends Node

var equipment_database: Dictionary = {}

func _ready():
	_load_equipment_database()

func _load_equipment_database():
	var file = FileAccess.open("res://data/equipment_database.json", FileAccess.READ)
	if file:
		var json = JSON.new()
		var parse_result = json.parse(file.get_as_text())
		if parse_result == OK:
			var data = json.get_data()
			for category in data.keys():
				for item in data[category]:
					var equipment = Equipment.from_json(item)
					equipment_database[equipment.name] = equipment
		file.close()
	else:
		print("Failed to open equipment_database.json")

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

func initialize(_game_state: GameState) -> void:
	# This method is added for consistency with other manager classes
	# Currently, EquipmentManager doesn't need the game_state, but we can add it if needed in the future
	pass
