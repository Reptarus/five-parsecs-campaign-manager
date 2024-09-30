class_name EquipmentManager
extends Node

signal equipment_updated

var equipment_database: Dictionary = {}
var game_state: GameState

func _ready() -> void:
	_load_equipment_database()

func _load_equipment_database() -> void:
	var file = FileAccess.open("res://data/equipment_database.json", FileAccess.READ)
	if file:
		var json = JSON.new()
		var parse_result = json.parse(file.get_as_text())
		if parse_result == OK:
			var data = json.get_data()
			for category in data.keys():
				for item in data[category]:
					var equipment: Equipment
					match category:
						"weapons":
							equipment = Weapon.from_json(item)
						"armor":
							equipment = Armor.from_json(item)
						"gear":
							equipment = Gear.from_json(item)
						_:
							equipment = Equipment.from_json(item)
					equipment_database[equipment.name] = equipment
		file.close()
	else:
		push_error("Failed to open equipment_database.json")

func generate_equipment_from_background(background: GlobalEnums.Background) -> Array[Equipment]:
	var equipment: Array[Equipment] = []
	var background_data = GameState.background_data[background]
	if "starting_gear" in background_data:
		for item_name in background_data.starting_gear:
			var item = get_equipment(item_name)
			if item:
				equipment.append(item)
	return equipment

func generate_equipment_from_motivation(motivation: GlobalEnums.Motivation) -> Array[Equipment]:
	var equipment: Array[Equipment] = []
	var motivation_data = GameState.motivation_data[motivation]
	if "starting_gear" in motivation_data:
		for item_name in motivation_data.starting_gear:
			var item = get_equipment(item_name)
			if item:
				equipment.append(item)
	return equipment

func generate_equipment_from_class(class_type: GlobalEnums.Class) -> Array[Equipment]:
	var equipment: Array[Equipment] = []
	var class_data = GameState.class_data[class_type]
	if "starting_gear" in class_data:
		for item_name in class_data.starting_gear:
			var item = get_equipment(item_name)
			if item:
				equipment.append(item)
	return equipment

func get_equipment(equipment_id: String) -> Equipment:
	if equipment_id in equipment_database:
		return equipment_database[equipment_id].create_copy()
	push_error("Equipment not found: " + equipment_id)
	return null

func create_equipment(equipment_id: String) -> Equipment:
	return get_equipment(equipment_id)

func initialize(game_state_ref: GameState) -> void:
	game_state = game_state_ref

func repair_equipment(equipment: Equipment) -> void:
	equipment.repair()
	equipment_updated.emit()

func damage_equipment(equipment: Equipment) -> void:
	equipment.damage()
	equipment_updated.emit()

func get_equipment_by_type(type: GlobalEnums.ItemType) -> Array[Equipment]:
	var filtered_equipment: Array[Equipment] = []
	for equipment in equipment_database.values():
		if equipment.type == type:
			filtered_equipment.append(equipment)
	return filtered_equipment

func get_equipment_value(equipment: Equipment) -> int:
	return equipment.get_effectiveness()
