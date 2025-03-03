@tool
class_name GameDataManager
extends Node

signal data_loaded(data_type)
signal data_load_failed(data_type, error)

# Paths to data files
const INJURY_TABLE_PATH = "res://data/injury_table.json"
const ENEMY_TYPES_PATH = "res://data/enemy_types.json"
const WORLD_TRAITS_PATH = "res://data/world_traits.json"
const PLANET_TYPES_PATH = "res://data/planet_types.json"
const LOCATION_TYPES_PATH = "res://data/location_types.json"
const GEAR_DATABASE_PATH = "res://data/gear_database.json"
const EQUIPMENT_DATABASE_PATH = "res://data/equipment_database.json"
const LOOT_TABLES_PATH = "res://data/loot_tables.json"
const MISSION_TEMPLATES_PATH = "res://data/mission_templates.json"
const CHARACTER_CREATION_PATH = "res://data/character_creation_data.json"
const WEAPONS_DATABASE_PATH = "res://data/weapons.json"
const ARMOR_DATABASE_PATH = "res://data/armor.json"
const STATUS_EFFECTS_PATH = "res://data/status_effects.json"

# Data containers
var injury_tables: Dictionary = {}
var enemy_types: Array = []
var world_traits: Dictionary = {}
var planet_types: Dictionary = {}
var location_types: Dictionary = {}
var gear_database: Dictionary = {}
var equipment_database: Dictionary = {}
var loot_tables: Dictionary = {}
var mission_templates: Array = []
var character_creation_data: Dictionary = {}
var weapons_database: Dictionary = {}
var armor_database: Dictionary = {}
var status_effects: Dictionary = {}

# Initialization flag
var _is_initialized: bool = false

func _init() -> void:
	# We don't automatically load data on initialization
	# to allow for more control over when data is loaded
	pass

func load_all_data() -> bool:
	var success = true
	
	# Load all data files
	success = success and load_injury_tables()
	success = success and load_enemy_types()
	success = success and load_world_traits()
	success = success and load_planet_types()
	success = success and load_location_types()
	success = success and load_gear_database()
	success = success and load_equipment_database()
	success = success and load_loot_tables()
	success = success and load_mission_templates()
	success = success and load_character_creation_data()
	success = success and load_weapons_database()
	success = success and load_armor_database()
	success = success and load_status_effects()
	
	_is_initialized = success
	return success

func load_injury_tables() -> bool:
	var file = FileAccess.open(INJURY_TABLE_PATH, FileAccess.READ)
	if file == null:
		var error = FileAccess.get_open_error()
		push_error("Failed to open injury table file: " + str(error))
		emit_signal("data_load_failed", "injury_tables", error)
		return false
	
	var json_text = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	var error = json.parse(json_text)
	if error != OK:
		push_error("Failed to parse injury table JSON: " + json.get_error_message() + " at line " + str(json.get_error_line()))
		emit_signal("data_load_failed", "injury_tables", error)
		return false
	
	injury_tables = json.get_data()
	emit_signal("data_loaded", "injury_tables")
	return true

func load_enemy_types() -> bool:
	var file = FileAccess.open(ENEMY_TYPES_PATH, FileAccess.READ)
	if file == null:
		var error = FileAccess.get_open_error()
		push_error("Failed to open enemy types file: " + str(error))
		emit_signal("data_load_failed", "enemy_types", error)
		return false
	
	var json_text = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	var error = json.parse(json_text)
	if error != OK:
		push_error("Failed to parse enemy types JSON: " + json.get_error_message() + " at line " + str(json.get_error_line()))
		emit_signal("data_load_failed", "enemy_types", error)
		return false
	
	enemy_types = json.get_data()
	emit_signal("data_loaded", "enemy_types")
	return true

func load_world_traits() -> bool:
	var file = FileAccess.open(WORLD_TRAITS_PATH, FileAccess.READ)
	if file == null:
		var error = FileAccess.get_open_error()
		push_error("Failed to open world traits file: " + str(error))
		emit_signal("data_load_failed", "world_traits", error)
		return false
	
	var json_text = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	var error = json.parse(json_text)
	if error != OK:
		push_error("Failed to parse world traits JSON: " + json.get_error_message() + " at line " + str(json.get_error_line()))
		emit_signal("data_load_failed", "world_traits", error)
		return false
	
	world_traits = json.get_data()
	emit_signal("data_loaded", "world_traits")
	return true

func load_planet_types() -> bool:
	var file = FileAccess.open(PLANET_TYPES_PATH, FileAccess.READ)
	if file == null:
		var error = FileAccess.get_open_error()
		push_error("Failed to open planet types file: " + str(error))
		emit_signal("data_load_failed", "planet_types", error)
		return false
	
	var json_text = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	var error = json.parse(json_text)
	if error != OK:
		push_error("Failed to parse planet types JSON: " + json.get_error_message() + " at line " + str(json.get_error_line()))
		emit_signal("data_load_failed", "planet_types", error)
		return false
	
	planet_types = json.get_data()
	emit_signal("data_loaded", "planet_types")
	return true

func load_location_types() -> bool:
	var file = FileAccess.open(LOCATION_TYPES_PATH, FileAccess.READ)
	if file == null:
		var error = FileAccess.get_open_error()
		push_error("Failed to open location types file: " + str(error))
		emit_signal("data_load_failed", "location_types", error)
		return false
	
	var json_text = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	var error = json.parse(json_text)
	if error != OK:
		push_error("Failed to parse location types JSON: " + json.get_error_message() + " at line " + str(json.get_error_line()))
		emit_signal("data_load_failed", "location_types", error)
		return false
	
	location_types = json.get_data()
	emit_signal("data_loaded", "location_types")
	return true

func load_gear_database() -> bool:
	var file = FileAccess.open(GEAR_DATABASE_PATH, FileAccess.READ)
	if file == null:
		var error = FileAccess.get_open_error()
		push_error("Failed to open gear database file: " + str(error))
		emit_signal("data_load_failed", "gear_database", error)
		return false
	
	var json_text = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	var error = json.parse(json_text)
	if error != OK:
		push_error("Failed to parse gear database JSON: " + json.get_error_message() + " at line " + str(json.get_error_line()))
		emit_signal("data_load_failed", "gear_database", error)
		return false
	
	gear_database = json.get_data()
	emit_signal("data_loaded", "gear_database")
	return true

func load_equipment_database() -> bool:
	var file = FileAccess.open(EQUIPMENT_DATABASE_PATH, FileAccess.READ)
	if file == null:
		var error = FileAccess.get_open_error()
		push_error("Failed to open equipment database file: " + str(error))
		emit_signal("data_load_failed", "equipment_database", error)
		return false
	
	var json_text = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	var error = json.parse(json_text)
	if error != OK:
		push_error("Failed to parse equipment database JSON: " + json.get_error_message() + " at line " + str(json.get_error_line()))
		emit_signal("data_load_failed", "equipment_database", error)
		return false
	
	equipment_database = json.get_data()
	emit_signal("data_loaded", "equipment_database")
	return true

func load_loot_tables() -> bool:
	var file = FileAccess.open(LOOT_TABLES_PATH, FileAccess.READ)
	if file == null:
		var error = FileAccess.get_open_error()
		push_error("Failed to open loot tables file: " + str(error))
		emit_signal("data_load_failed", "loot_tables", error)
		return false
	
	var json_text = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	var error = json.parse(json_text)
	if error != OK:
		push_error("Failed to parse loot tables JSON: " + json.get_error_message() + " at line " + str(json.get_error_line()))
		emit_signal("data_load_failed", "loot_tables", error)
		return false
	
	loot_tables = json.get_data()
	emit_signal("data_loaded", "loot_tables")
	return true

func load_mission_templates() -> bool:
	var file = FileAccess.open(MISSION_TEMPLATES_PATH, FileAccess.READ)
	if file == null:
		var error = FileAccess.get_open_error()
		push_error("Failed to open mission templates file: " + str(error))
		emit_signal("data_load_failed", "mission_templates", error)
		return false
	
	var json_text = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	var error = json.parse(json_text)
	if error != OK:
		push_error("Failed to parse mission templates JSON: " + json.get_error_message() + " at line " + str(json.get_error_line()))
		emit_signal("data_load_failed", "mission_templates", error)
		return false
	
	mission_templates = json.get_data()
	emit_signal("data_loaded", "mission_templates")
	return true

func load_character_creation_data() -> bool:
	var file = FileAccess.open(CHARACTER_CREATION_PATH, FileAccess.READ)
	if file == null:
		var error = FileAccess.get_open_error()
		push_error("Failed to open character creation data file: " + str(error))
		emit_signal("data_load_failed", "character_creation_data", error)
		return false
	
	var json_text = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	var error = json.parse(json_text)
	if error != OK:
		push_error("Failed to parse character creation data JSON: " + json.get_error_message() + " at line " + str(json.get_error_line()))
		emit_signal("data_load_failed", "character_creation_data", error)
		return false
	
	character_creation_data = json.get_data()
	emit_signal("data_loaded", "character_creation_data")
	return true

func load_weapons_database() -> bool:
	var file = FileAccess.open(WEAPONS_DATABASE_PATH, FileAccess.READ)
	if file == null:
		var error = FileAccess.get_open_error()
		push_error("Failed to open weapons database file: " + str(error))
		emit_signal("data_load_failed", "weapons_database", error)
		return false
	
	var json_text = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	var error = json.parse(json_text)
	if error != OK:
		push_error("Failed to parse weapons database JSON: " + json.get_error_message() + " at line " + str(json.get_error_line()))
		emit_signal("data_load_failed", "weapons_database", error)
		return false
	
	weapons_database = json.get_data()
	emit_signal("data_loaded", "weapons_database")
	return true

func load_armor_database() -> bool:
	var file = FileAccess.open(ARMOR_DATABASE_PATH, FileAccess.READ)
	if file == null:
		var error = FileAccess.get_open_error()
		push_error("Failed to open armor database file: " + str(error))
		emit_signal("data_load_failed", "armor_database", error)
		return false
	
	var json_text = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	var error = json.parse(json_text)
	if error != OK:
		push_error("Failed to parse armor database JSON: " + json.get_error_message() + " at line " + str(json.get_error_line()))
		emit_signal("data_load_failed", "armor_database", error)
		return false
	
	armor_database = json.get_data()
	emit_signal("data_loaded", "armor_database")
	return true

func load_status_effects() -> bool:
	var file = FileAccess.open(STATUS_EFFECTS_PATH, FileAccess.READ)
	if file == null:
		var error = FileAccess.get_open_error()
		push_error("Failed to open status effects file: " + str(error))
		emit_signal("data_load_failed", "status_effects", error)
		return false
	
	var json_text = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	var error = json.parse(json_text)
	if error != OK:
		push_error("Failed to parse status effects JSON: " + json.get_error_message() + " at line " + str(json.get_error_line()))
		emit_signal("data_load_failed", "status_effects", error)
		return false
	
	status_effects = json.get_data()
	emit_signal("data_loaded", "status_effects")
	return true

# Generic JSON file loader
func load_json_file(file_path: String) -> Variant:
	var file = FileAccess.open(file_path, FileAccess.READ)
	if file == null:
		var error = FileAccess.get_open_error()
		push_error("Failed to open JSON file: " + file_path + " Error: " + str(error))
		return null
	
	var json_text = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	var error = json.parse(json_text)
	if error != OK:
		push_error("Failed to parse JSON file: " + file_path + " Error: " + json.get_error_message() + " at line " + str(json.get_error_line()))
		return null
	
	return json.get_data()

# Helper methods to access data

func get_injury_result(table_name: String, roll: int) -> Dictionary:
	if not _is_initialized:
		push_error("GameDataManager not initialized. Call load_all_data() first.")
		return {}
	
	if not injury_tables.has(table_name):
		push_error("Invalid injury table name: " + table_name)
		return {}
	
	var table = injury_tables[table_name]
	
	# Find the entry that matches the roll
	for entry in table:
		if "roll_range" in entry:
			var range_values = entry.roll_range
			if range_values.size() >= 2:
				var min_roll = range_values[0]
				var max_roll = range_values[1]
				
				if roll >= min_roll and roll <= max_roll:
					return entry
	
	# If no match found
	push_error("No injury result found for roll " + str(roll) + " in table " + table_name)
	return {}

func get_enemy_type(enemy_id: String) -> Dictionary:
	if not _is_initialized:
		push_error("GameDataManager not initialized. Call load_all_data() first.")
		return {}
	
	for enemy_type in enemy_types:
		if enemy_type.id == enemy_id:
			return enemy_type
	
	push_error("Enemy type not found: " + enemy_id)
	return {}

func get_world_trait(trait_id: String) -> Dictionary:
	if not _is_initialized:
		push_error("GameDataManager not initialized. Call load_all_data() first.")
		return {}
	
	if world_traits.has(trait_id):
		return world_traits[trait_id]
	
	push_error("World trait not found: " + trait_id)
	return {}

func get_planet_type(planet_id: String) -> Dictionary:
	if not _is_initialized:
		push_error("GameDataManager not initialized. Call load_all_data() first.")
		return {}
	
	if planet_types.has(planet_id):
		return planet_types[planet_id]
	
	push_error("Planet type not found: " + planet_id)
	return {}

func get_location_type(location_id: String) -> Dictionary:
	if not _is_initialized:
		push_error("GameDataManager not initialized. Call load_all_data() first.")
		return {}
	
	if location_types.has(location_id):
		return location_types[location_id]
	
	push_error("Location type not found: " + location_id)
	return {}

func get_gear_item(item_id: String) -> Dictionary:
	if not _is_initialized:
		push_error("GameDataManager not initialized. Call load_all_data() first.")
		return {}
	
	if gear_database.has(item_id):
		return gear_database[item_id]
	
	push_error("Gear item not found: " + item_id)
	return {}

func get_equipment_item(item_id: String) -> Dictionary:
	if not _is_initialized:
		push_error("GameDataManager not initialized. Call load_all_data() first.")
		return {}
	
	if equipment_database.has(item_id):
		return equipment_database[item_id]
	
	push_error("Equipment item not found: " + item_id)
	return {}

func get_loot_table(table_name: String) -> Array:
	if not _is_initialized:
		push_error("GameDataManager not initialized. Call load_all_data() first.")
		return []
	
	if loot_tables.has(table_name):
		return loot_tables[table_name]
	
	push_error("Loot table not found: " + table_name)
	return []

func get_random_loot_item(table_name: String) -> Dictionary:
	var table = get_loot_table(table_name)
	if table.empty():
		return {}
	
	return table[randi() % table.size()]

func get_mission_template(template_id: String) -> Dictionary:
	if not _is_initialized:
		push_error("GameDataManager not initialized. Call load_all_data() first.")
		return {}
	
	for mission_template in mission_templates:
		if mission_template.id == template_id:
			return mission_template
	
	push_error("Mission template not found: " + template_id)
	return {}

func get_character_creation_option(option_type: String, option_id: String) -> Dictionary:
	if not _is_initialized:
		push_error("GameDataManager not initialized. Call load_all_data() first.")
		return {}
	
	if not character_creation_data.has(option_type):
		push_error("Invalid character creation option type: " + option_type)
		return {}
	
	var options = character_creation_data[option_type]
	
	for creation_option in options:
		if creation_option.id == option_id:
			return creation_option
	
	push_error("Character creation option not found: " + option_id + " in type " + option_type)
	return {}

func is_data_loaded(data_type: String) -> bool:
	match data_type:
		"injury_tables":
			return not injury_tables.is_empty()
		"enemy_types":
			return not enemy_types.is_empty()
		"world_traits":
			return not world_traits.is_empty()
		"planet_types":
			return not planet_types.is_empty()
		"location_types":
			return not location_types.is_empty()
		"gear_database":
			return not gear_database.is_empty()
		"equipment_database":
			return not equipment_database.is_empty()
		"loot_tables":
			return not loot_tables.is_empty()
		"mission_templates":
			return not mission_templates.is_empty()
		"character_creation_data":
			return not character_creation_data.is_empty()
		"weapons_database":
			return not weapons_database.is_empty()
		"armor_database":
			return not armor_database.is_empty()
		"status_effects":
			return not status_effects.is_empty()
		_:
			push_error("Invalid data type: " + data_type)
			return false

func get_weapon_by_id(weapon_id: String) -> Dictionary:
	if not weapons_database.has("weapons"):
		return {}
	
	for weapon in weapons_database.weapons:
		if weapon.id == weapon_id:
			return weapon
	
	return {}

func get_armor_by_id(armor_id: String) -> Dictionary:
	if not armor_database.has("armor"):
		return {}
	
	for armor in armor_database.armor:
		if armor.id == armor_id:
			return armor
	
	return {}

func get_status_effect_by_id(effect_id: String) -> Dictionary:
	if not status_effects.has("effects"):
		return {}
	
	for effect in status_effects.effects:
		if effect.id == effect_id:
			return effect
	
	return {}