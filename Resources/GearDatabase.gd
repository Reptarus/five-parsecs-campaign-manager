class_name GearDatabase
extends Resource

var gears: Dictionary = {}

func _init():
	load_gear_data()

func load_gear_data() -> void:
	var file_path = "res://data/gear_database.json"
	var file = FileAccess.open(file_path, FileAccess.READ)
	if file == null:
		push_error("Failed to open gear database file: " + file_path)
		return

	var json = JSON.new()
	var error = json.parse(file.get_as_text())
	if error != OK:
		push_error("Failed to parse gear database JSON: " + file_path)
		return

	var data = json.data
	for gear_name in data:
		var gear_data = data[gear_name]
		var new_gear = Gear.new(
			gear_data["name"],
			gear_data["description"],
			GlobalEnums.ItemType[gear_data["gear_type"]],
			gear_data["level"]
		)
		new_gear.value = gear_data["value"]
		new_gear.is_damaged = gear_data.get("is_damaged", false)
		new_gear.rarity = GlobalEnums.ItemRarity[gear_data.get("rarity", "COMMON")]
		gears[gear_name] = new_gear

	file.close()

func get_gear(gear_name: String) -> Gear:
	return gears.get(gear_name)

func get_all_gears() -> Array[Gear]:
	return gears.values()

func get_gears_by_type(gear_type: GlobalEnums.ItemType) -> Array[Gear]:
	return gears.values().filter(func(gear): return gear.gear_type == gear_type)

func get_gear_types() -> Array[GlobalEnums.ItemType]:
	var types: Array[GlobalEnums.ItemType] = []
	for gear in gears.values():
		if not gear.gear_type in types:
			types.append(gear.gear_type)
	return types

func get_gear_names() -> Array[String]:
	return gears.keys()

func get_gear_count() -> int:
	return gears.size()

func has_gear(gear_name: String) -> bool:
	return gears.has(gear_name)

func save_gear_data() -> void:
	var file_path = "res://data/gear_database.json"
	var file = FileAccess.open(file_path, FileAccess.WRITE)
	if file == null:
		push_error("Failed to open gear database file for writing: " + file_path)
		return

	var data = {}
	for gear_name in gears:
		var gear = gears[gear_name]
		data[gear_name] = {
			"name": gear.name,
			"description": gear.description,
			"gear_type": GlobalEnums.ItemType.keys()[gear.gear_type],
			"level": gear.level,
			"value": gear.value,
			"is_damaged": gear.is_damaged,
			"rarity": GlobalEnums.ItemRarity.keys()[gear.rarity]
		}

	var json_string = JSON.stringify(data, "\t")
	file.store_string(json_string)
	file.close()

func add_gear(gear: Gear) -> void:
	gears[gear.name] = gear
	save_gear_data()

func remove_gear(gear_name: String) -> void:
	if gears.has(gear_name):
		gears.erase(gear_name)
		save_gear_data()

func update_gear(gear: Gear) -> void:
	if gears.has(gear.name):
		gears[gear.name] = gear
		save_gear_data()

func get_gears_by_rarity(rarity: GlobalEnums.ItemRarity) -> Array[Gear]:
	return gears.values().filter(func(gear): return gear.rarity == rarity)

func repair_gear(gear_name: String) -> void:
	if gears.has(gear_name):
		gears[gear_name].is_damaged = false
		save_gear_data()

func damage_gear(gear_name: String) -> void:
	if gears.has(gear_name):
		gears[gear_name].is_damaged = true
		save_gear_data()
