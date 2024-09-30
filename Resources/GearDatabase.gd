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
		gears[gear_name] = Gear.new(
			gear_data["name"],
			gear_data["description"],
			gear_data["gear_type"],
			gear_data["level"]
		)
		gears[gear_name].value = gear_data["value"]
		gears[gear_name].is_damaged = gear_data.get("is_damaged", false)

	file.close()

func get_gear(gear_name: String) -> Gear:
	return gears.get(gear_name)

func get_all_gears() -> Array[Gear]:
	return gears.values()

func get_gears_by_type(gear_type: String) -> Array[Gear]:
	return gears.values().filter(func(gear): return gear.gear_type == gear_type)

func get_gear_types() -> Array[String]:
	var types = []
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

# Add a method to save the gear data
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
			"gear_type": gear.gear_type,
			"level": gear.level,
			"value": gear.value,
			"is_damaged": gear.is_damaged
		}

	var json_string = JSON.stringify(data, "\t")
	file.store_string(json_string)
	file.close()

# Add a method to add new gear
func add_gear(gear: Gear) -> void:
	gears[gear.name] = gear
	save_gear_data()

# Add a method to remove gear
func remove_gear(gear_name: String) -> void:
	if gears.has(gear_name):
		gears.erase(gear_name)
		save_gear_data()

# Add a method to update existing gear
func update_gear(gear: Gear) -> void:
	if gears.has(gear.name):
		gears[gear.name] = gear
		save_gear_data()
