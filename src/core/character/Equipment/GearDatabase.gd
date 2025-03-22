@tool
extends Resource

const FiveParsecsGear = preload("res://src/core/character/Equipment/implementations/five_parsecs_gear.gd")
const GameEnums = preload("res://src/core/systems/GlobalEnums.gd")

var gears: Dictionary = {}

func roll_weapon_table(table: String = "basic") -> Dictionary:
	var roll = randi() % 6 + 1
	var weapon_data = {}
	
	match table:
		"basic":
			match roll:
				1: weapon_data = {"name": "Scrap pistol", "type": "PISTOL", "range": 12, "shots": 1, "damage": 0}
				2: weapon_data = {"name": "Hand gun", "type": "PISTOL", "range": 14, "shots": 1, "damage": 0}
				3: weapon_data = {"name": "Colony rifle", "type": "RIFLE", "range": 18, "shots": 1, "damage": 0}
				4: weapon_data = {"name": "Military rifle", "type": "RIFLE", "range": 26, "shots": 1, "damage": 0}
				5: weapon_data = {"name": "Scrap pistol", "type": "PISTOL", "range": 12, "shots": 1, "damage": 0, "traits": ["Blade"]}
				6: weapon_data = {"name": "Shotgun", "type": "SHOTGUN", "range": 12, "shots": 2, "damage": 1}
		"specialist_a":
			match roll:
				1: weapon_data = {"name": "Power claw", "type": "MELEE", "range": 1, "shots": 1, "damage": 2}
				2: weapon_data = {"name": "Shotgun", "type": "SHOTGUN", "range": 12, "shots": 2, "damage": 1}
				3: weapon_data = {"name": "Auto rifle", "type": "RIFLE", "range": 24, "shots": 2, "damage": 1}
				4: weapon_data = {"name": "Clingfire pistol", "type": "PISTOL", "range": 8, "shots": 1, "damage": 1, "traits": ["Area"]}
				5: weapon_data = {"name": "Hunting rifle", "type": "RIFLE", "range": 30, "shots": 1, "damage": 2}
				6: weapon_data = {"name": "Hand gun", "type": "PISTOL", "range": 14, "shots": 1, "damage": 0, "traits": ["Ripper sword"]}
		"specialist_b":
			match roll:
				1: weapon_data = {"name": "Marksman's rifle", "type": "RIFLE", "range": 36, "shots": 1, "damage": 2, "traits": ["Aimed"]}
				2: weapon_data = {"name": "Auto rifle", "type": "RIFLE", "range": 24, "shots": 2, "damage": 1}
				3: weapon_data = {"name": "Shell gun", "type": "HEAVY", "range": 18, "shots": 1, "damage": 2, "traits": ["Area"]}
				4: weapon_data = {"name": "Hand flamer", "type": "HEAVY", "range": 8, "shots": 2, "damage": 1, "traits": ["Area"]}
				5: weapon_data = {"name": "Rattle gun", "type": "HEAVY", "range": 24, "shots": 3, "damage": 1}
				6: weapon_data = {"name": "Rattle gun", "type": "HEAVY", "range": 24, "shots": 3, "damage": 1}
		"specialist_c":
			match roll:
				1: weapon_data = {"name": "Marksman's rifle", "type": "RIFLE", "range": 36, "shots": 1, "damage": 2, "traits": ["Aimed"]}
				2: weapon_data = {"name": "Shell gun", "type": "HEAVY", "range": 18, "shots": 1, "damage": 2, "traits": ["Area"]}
				3: weapon_data = {"name": "Fury rifle", "type": "RIFLE", "range": 30, "shots": 1, "damage": 3, "traits": ["Heavy"]}
				4: weapon_data = {"name": "Plasma rifle", "type": "RIFLE", "range": 20, "shots": 2, "damage": 2, "traits": ["Energy"]}
				5: weapon_data = {"name": "Plasma rifle", "type": "RIFLE", "range": 20, "shots": 2, "damage": 2, "traits": ["Energy"]}
				6: weapon_data = {"name": "Hyper blaster", "type": "RIFLE", "range": 24, "shots": 3, "damage": 1, "traits": ["Overheat"]}
		"military":
			match roll:
				1: weapon_data = {"name": "Military rifle", "type": "RIFLE", "range": 26, "shots": 1, "damage": 0}
				2: weapon_data = {"name": "Auto rifle", "type": "RIFLE", "range": 24, "shots": 2, "damage": 1}
				3: weapon_data = {"name": "Marksman's rifle", "type": "RIFLE", "range": 36, "shots": 1, "damage": 2, "traits": ["Aimed"]}
				4: weapon_data = {"name": "Plasma rifle", "type": "RIFLE", "range": 20, "shots": 2, "damage": 2, "traits": ["Energy"]}
				5: weapon_data = {"name": "Rattle gun", "type": "HEAVY", "range": 24, "shots": 3, "damage": 1}
				6: weapon_data = {"name": "Shell gun", "type": "HEAVY", "range": 18, "shots": 1, "damage": 2, "traits": ["Area"]}
	
	weapon_data["roll_result"] = roll
	return weapon_data

func get_weapon_table_description(table: String) -> String:
	match table:
		"basic": return "Basic weapons table (1d6)"
		"specialist_a": return "Specialist A weapons table (1d6)"
		"specialist_b": return "Specialist B weapons table (1d6)"
		"specialist_c": return "Specialist C weapons table (1d6)"
		"military": return "Military weapons table (1d6)"
		_: return "Unknown weapon table"

func get_weapon_trait_description(trait_name: String) -> String:
	match trait_name:
		"Aimed": return "Improved accuracy at long range"
		"Area": return "Affects an area around the target"
		"Blade": return "Includes a melee weapon"
		"Energy": return "Uses energy ammunition"
		"Heavy": return "Requires setup time"
		"Overheat": return "Can overheat with sustained fire"
		"Ripper sword": return "Includes a deadly melee weapon"
		_: return "No description available"

func _init() -> void:
	load_gear_data()

func load_gear_data() -> bool:
	var file_path = "res://data/equipment_database.json"
	var file = FileAccess.open(file_path, FileAccess.READ)
	if file == null:
		push_error("Failed to open equipment database file: " + file_path + ". Error code: " + str(FileAccess.get_open_error()))
		return false

	var json = JSON.new()
	var error = json.parse(file.get_as_text())
	file.close()
	
	if error != OK:
		push_error("Failed to parse equipment database JSON: " + file_path + "\nError: " + json.get_error_message() + " at line " + str(json.get_error_line()))
		return false

	var data = json.data
	if not data is Dictionary:
		push_error("Invalid equipment database format: Expected Dictionary, got " + str(typeof(data)))
		return false

	gears.clear()
	
	# Process weapons section
	if data.has("weapons"):
		for weapon in data["weapons"]:
			if not weapon is Dictionary:
				push_error("Invalid weapon data format: Expected Dictionary")
				continue
				
			var gear_data = {
				"name": weapon.get("name", "Unknown Weapon"),
				"description": _generate_weapon_description(weapon),
				"gear_type": "WEAPON",
				"level": weapon.get("level", 1),
				"value": weapon.get("value", 100),
				"weight": weapon.get("weight", 1.0),
				"rarity": weapon.get("rarity", "COMMON"),
				"damage": weapon.get("damage", 1),
				"range": weapon.get("range", 12),
				"shots": weapon.get("shots", 1),
				"traits": weapon.get("traits", [])
			}
			
			if not _validate_gear_data(gear_data):
				push_error("Invalid weapon data for: " + gear_data["name"])
				continue
				
			var gear_type = GameEnums.ItemType[gear_data["gear_type"]]
			var level = gear_data["level"] as int
			var weight = _safe_float_conversion(gear_data["weight"])
			
			var new_gear = _create_gear(gear_data["name"], gear_data, gear_type, level, weight)
			if new_gear != null:
				gears[gear_data["name"]] = new_gear
	
	return true

func _generate_weapon_description(weapon: Dictionary) -> String:
	var desc = "A %s weapon. " % weapon.get("type", "standard")
	
	# Add roll result if available
	if weapon.has("roll_result"):
		desc = "[Roll: %d] " % weapon.roll_result + desc
	
	desc += "Damage: %d, Range: %d, Shots: %d" % [
		weapon.get("damage", 1),
		weapon.get("range", 12),
		weapon.get("shots", 1)
	]
	
	var traits = weapon.get("traits", [])
	if not traits.is_empty():
		desc += ". Traits: " + ", ".join(traits)
	
	return desc

func _safe_float_conversion(value: Variant) -> float:
	if value is float:
		return value
	if value is int:
		return float(value)
	if value is String:
		if value.is_valid_float():
			return value.to_float()
	return 1.0 # Default weight if conversion fails

func _create_gear(gear_name: String, gear_data: Dictionary, gear_type: int, level: int, weight: float) -> Resource:
	if not gear_data.has("name") or not gear_data.has("description"):
		push_error("Missing required fields for gear: " + gear_name)
		return null
		
	# Create new gear instance
	var new_gear = FiveParsecsGear.new()
	new_gear.item_name = gear_data["name"]
	new_gear.description = gear_data["description"]
	new_gear.item_type = gear_type
	new_gear.cost = gear_data.get("value", 0)
	new_gear.weight = weight
	
	if not is_instance_valid(new_gear):
		push_error("Failed to create gear instance for: " + gear_name)
		return null
	
	# Handle rarity with error checking
	var rarity_str = gear_data.get("rarity", "COMMON")
	if not rarity_str in GameEnums.ItemRarity.keys():
		push_warning("Invalid rarity for gear '%s': %s, defaulting to COMMON" % [gear_name, rarity_str])
		new_gear.rarity = GameEnums.ItemRarity.COMMON
	else:
		new_gear.rarity = GameEnums.ItemRarity[rarity_str]
	
	return new_gear

func _safe_int_conversion(value: Variant) -> int:
	if value is int:
		return value
	if value is float:
		return int(value)
	if value is String:
		if value.is_valid_int():
			return value.to_int()
	return 0 # Default value if conversion fails

func _validate_gear_data(data: Dictionary) -> bool:
	# Required fields
	var required_fields = ["name", "description", "gear_type", "level", "value"]
	for field in required_fields:
		if not data.has(field):
			push_error("Missing required field: " + field)
			return false
	
	# Type validation
	if not data["name"] is String:
		push_error("Invalid name type: Expected String")
		return false
		
	if not data["description"] is String:
		push_error("Invalid description type: Expected String")
		return false
	
	# Validate gear type
	if not data["gear_type"] in GameEnums.ItemType.keys():
		push_error("Invalid gear_type: " + str(data["gear_type"]))
		return false
	
	# Validate numeric fields
	if not (data["level"] is int or data["level"] is float) or data["level"] < 1:
		push_error("Invalid level: Must be positive integer")
		return false
		
	if not (data["value"] is int or data["value"] is float) or data["value"] < 0:
		push_error("Invalid value: Must be non-negative integer")
		return false
	
	# Optional fields validation
	if data.has("weight"):
		var weight = data["weight"]
		if not (weight is float or weight is int or (weight is String and weight.is_valid_float())):
			push_error("Invalid weight: Must be numeric")
			return false
		
	if data.has("rarity"):
		if not data["rarity"] in GameEnums.ItemRarity.keys():
			push_error("Invalid rarity: " + str(data["rarity"]))
			return false
	
	return true

func get_gear(gear_name: String) -> Resource:
	if not gears.has(gear_name):
		push_warning("Gear not found: " + gear_name)
	return gears.get(gear_name)

func get_all_gears() -> Array[Resource]:
	return gears.values()

func get_gears_by_type(gear_type: GameEnums.ItemType) -> Array[Resource]:
	return gears.values().filter(func(gear): return gear.gear_type == gear_type)

func get_gear_types() -> Array[GameEnums.ItemType]:
	var types: Array[GameEnums.ItemType] = []
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

func save_gear_data() -> bool:
	var file_path = "res://data/gear_database.json"
	var file = FileAccess.open(file_path, FileAccess.WRITE)
	if file == null:
		push_error("Failed to open gear database file for writing: " + file_path)
		return false

	var data = {}
	for gear_name in gears:
		var gear = gears[gear_name]
		if not is_instance_valid(gear):
			push_error("Invalid gear instance found: " + gear_name)
			continue
			
		data[gear_name] = {
			"name": gear.name,
			"description": gear.description,
			"gear_type": GameEnums.ItemType.keys()[gear.gear_type],
			"level": gear.level,
			"value": gear.value,
			"weight": gear.weight,
			"is_damaged": gear.is_damaged,
			"rarity": GameEnums.ItemRarity.keys()[gear.rarity]
		}

	var json_string = JSON.stringify(data, "\t")
	file.store_string(json_string)
	file.close()
	return true

func add_gear(gear: Resource) -> bool:
	if not is_instance_valid(gear):
		push_error("Cannot add invalid gear instance")
		return false
		
	if gears.has(gear.name):
		push_warning("Overwriting existing gear: " + gear.name)
		
	gears[gear.name] = gear
	return save_gear_data()

func remove_gear(gear_name: String) -> bool:
	if not gears.has(gear_name):
		push_warning("Cannot remove non-existent gear: " + gear_name)
		return false
		
	gears.erase(gear_name)
	return save_gear_data()

func update_gear(gear: Resource) -> bool:
	if not is_instance_valid(gear):
		push_error("Cannot update invalid gear instance")
		return false
		
	if not gears.has(gear.name):
		push_warning("Cannot update non-existent gear: " + gear.name)
		return false
		
	gears[gear.name] = gear
	return save_gear_data()

func get_gears_by_rarity(rarity: GameEnums.ItemRarity) -> Array[Resource]:
	return gears.values().filter(func(gear): return gear.rarity == rarity)

func repair_gear(gear_name: String) -> bool:
	if not gears.has(gear_name):
		push_warning("Cannot repair non-existent gear: " + gear_name)
		return false
		
	gears[gear_name].is_damaged = false
	return save_gear_data()

func damage_gear(gear_name: String) -> bool:
	if not gears.has(gear_name):
		push_warning("Cannot damage non-existent gear: " + gear_name)
		return false
		
	gears[gear_name].is_damaged = true
	return save_gear_data()

func roll_random_gear() -> Resource:
	var roll = randi() % 100 + 1
	var gear_names = get_gear_names()
	if gear_names.is_empty():
		push_error("No gear available to roll")
		return null
	
	var selected_gear = gear_names[randi() % gear_names.size()]
	var gear = get_gear(selected_gear)
	if gear:
		gear.roll_result = roll
	return gear

func roll_random_gadget() -> Resource:
	var roll = randi() % 100 + 1
	var gadget_gears = get_gears_by_type(GameEnums.ItemType.MISC)
	if gadget_gears.is_empty():
		push_error("No gadgets available to roll")
		return null
	
	var selected_gear = gadget_gears[randi() % gadget_gears.size()]
	if selected_gear:
		selected_gear.roll_result = roll
	return selected_gear

func roll_gear_table() -> Dictionary:
	var roll = randi() % 6 + 1
	var gear_data = {}
	
	match roll:
		1: gear_data = {"name": "Survival Kit", "type": "GEAR", "description": "Basic survival equipment", "quantity": 1}
		2: gear_data = {"name": "Medkit", "type": "GEAR", "description": "Basic medical supplies", "quantity": 1}
		3: gear_data = {"name": "Toolkit", "type": "GEAR", "description": "Basic repair tools", "quantity": 1}
		4: gear_data = {"name": "Climbing Gear", "type": "GEAR", "description": "Basic climbing equipment", "quantity": 1}
		5: gear_data = {"name": "Camping Gear", "type": "GEAR", "description": "Basic camping equipment", "quantity": 1}
		6: gear_data = {"name": "Navigation Kit", "type": "GEAR", "description": "Basic navigation tools", "quantity": 1}
	
	gear_data["roll_result"] = roll
	return gear_data

func roll_gadget_table() -> Dictionary:
	var roll = randi() % 6 + 1
	var gadget_data = {}
	
	match roll:
		1: gadget_data = {"name": "Scanner", "type": "SPECIAL", "description": "Advanced scanning device", "quantity": 1}
		2: gadget_data = {"name": "Shield Generator", "type": "SPECIAL", "description": "Personal shield device", "quantity": 1}
		3: gadget_data = {"name": "Stealth Field", "type": "SPECIAL", "description": "Personal cloaking device", "quantity": 1}
		4: gadget_data = {"name": "Jet Pack", "type": "SPECIAL", "description": "Personal flight device", "quantity": 1}
		5: gadget_data = {"name": "Holo Projector", "type": "SPECIAL", "description": "Holographic projection device", "quantity": 1}
		6: gadget_data = {"name": "Grav Boots", "type": "SPECIAL", "description": "Gravity manipulation boots", "quantity": 1}
	
	gadget_data["roll_result"] = roll
	return gadget_data

func get_gear_type_description(gear_type: String) -> String:
	match gear_type:
		"GEAR": return "Standard equipment"
		"SPECIAL": return "Advanced technological device"
		"WEAPON": return "Combat equipment"
		"ARMOR": return "Protective equipment"
		"TOOL": return "Utility item"
		_: return "Unknown equipment type"
