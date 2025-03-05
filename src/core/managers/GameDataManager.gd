@tool
extends Node

signal data_loaded(data_type)
signal data_load_failed(data_type, error)

# Singleton reference
static var _instance: Node = null

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
var enemy_types: Dictionary = {}
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
	if _instance == null and not Engine.is_editor_hint():
		_instance = self
		
# Static accessor for singleton
static func get_instance() -> Node:
	if _instance == null:
		push_warning("GameDataManager singleton not initialized. Creating new instance.")
		_instance = load("res://src/core/managers/GameDataManager.gd").new()
	return _instance

# Static method to ensure data is loaded
static func ensure_data_loaded() -> bool:
	var instance = get_instance()
	if not instance._is_initialized:
		return instance.load_all_data()
	return true

func _ready() -> void:
	# If this is the autoloaded instance, load data automatically
	if _instance == self and not Engine.is_editor_hint():
		load_all_data()

func load_all_data() -> bool:
	var all_loaded = true
	
	# Track files that loaded successfully
	var loaded_successfully = {}
	
	# Try to load each data file, but continue even if some fail
	loaded_successfully["injury_tables"] = load_injury_tables()
	loaded_successfully["enemy_types"] = load_enemy_types()
	loaded_successfully["world_traits"] = load_world_traits()
	loaded_successfully["planet_types"] = load_planet_types()
	loaded_successfully["location_types"] = load_location_types()
	loaded_successfully["gear_database"] = load_gear_database()
	loaded_successfully["equipment_database"] = load_equipment_database()
	loaded_successfully["loot_tables"] = load_loot_tables()
	loaded_successfully["mission_templates"] = load_mission_templates()
	loaded_successfully["character_creation_data"] = load_character_creation_data()
	loaded_successfully["weapons_database"] = load_weapons_database()
	loaded_successfully["armor_database"] = load_armor_database()
	loaded_successfully["status_effects"] = load_status_effects()
	
	# Log any files that failed to load
	for data_type in loaded_successfully:
		if not loaded_successfully[data_type]:
			push_warning("Failed to load %s data" % data_type)
			all_loaded = false
	
	# Set initialization flag to true if at least the critical data was loaded
	var critical_data_loaded = loaded_successfully["enemy_types"] and loaded_successfully["weapons_database"] and loaded_successfully["armor_database"]
	_is_initialized = critical_data_loaded
	
	# Log the initialization status
	if _is_initialized:
		if not all_loaded:
			push_warning("Some non-critical data files failed to load, but GameDataManager is initialized with critical data.")
	else:
		push_error("Failed to load critical data files. GameDataManager is not properly initialized.")
	
	return _is_initialized

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
	
	var data = json.get_data()
	if typeof(data) == TYPE_DICTIONARY:
		injury_tables = data
	else:
		push_error("Invalid injury tables format: expected a dictionary")
		emit_signal("data_load_failed", "injury_tables", ERR_INVALID_DATA)
		return false
		
	emit_signal("data_loaded", "injury_tables")
	return true

func load_enemy_types() -> bool:
	var file = FileAccess.open(ENEMY_TYPES_PATH, FileAccess.READ)
	if file == null:
		var error = FileAccess.get_open_error()
		push_error("Failed to open enemy types file: " + str(error))
		emit_signal("data_load_failed", "enemy_types", error)
		# Use fallback data structure
		_initialize_default_enemy_types()
		return true
	
	var json_text = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	var error = json.parse(json_text)
	if error != OK:
		push_error("Failed to parse enemy types JSON: " + json.get_error_message() + " at line " + str(json.get_error_line()))
		emit_signal("data_load_failed", "enemy_types", error)
		# Use fallback data structure
		_initialize_default_enemy_types()
		return true
	
	var data = json.get_data()
	if typeof(data) == TYPE_DICTIONARY:
		enemy_types = data
	else:
		push_error("Invalid enemy types data structure: expected a dictionary")
		emit_signal("data_load_failed", "enemy_types", ERR_INVALID_DATA)
		# Use fallback data structure
		_initialize_default_enemy_types()
		return true
	
	emit_signal("data_loaded", "enemy_types")
	return true

# Initialize a default enemy types structure for fallback
func _initialize_default_enemy_types() -> void:
	enemy_types = {
		"name": "enemy_types",
		"enemy_categories": [
			{
				"id": "raiders",
				"name": "Raiders",
				"description": "Opportunistic bandits and pirates who prey on the weak.",
				"enemies": [
					{
						"id": "raider_grunt",
						"name": "Raider Grunt",
						"description": "Common bandit armed with basic weapons.",
						"tags": ["common", "grunt"]
					}
				]
			}
		],
		"enemy_loot_tables": {},
		"enemy_spawn_rules": {}
	}

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
	
	var data = json.get_data()
	if typeof(data) == TYPE_DICTIONARY:
		world_traits = data
	else:
		push_error("Invalid world traits format: expected a dictionary")
		emit_signal("data_load_failed", "world_traits", ERR_INVALID_DATA)
		return false
		
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
	
	var data = json.get_data()
	if typeof(data) == TYPE_DICTIONARY:
		planet_types = data
	else:
		push_error("Invalid planet types format: expected a dictionary")
		emit_signal("data_load_failed", "planet_types", ERR_INVALID_DATA)
		return false
		
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
	
	var data = json.get_data()
	if typeof(data) == TYPE_DICTIONARY:
		location_types = data
	else:
		push_error("Invalid location types format: expected a dictionary")
		emit_signal("data_load_failed", "location_types", ERR_INVALID_DATA)
		return false
		
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
	
	var data = json.get_data()
	if typeof(data) == TYPE_DICTIONARY:
		gear_database = data
	else:
		push_error("Invalid gear database format: expected a dictionary")
		emit_signal("data_load_failed", "gear_database", ERR_INVALID_DATA)
		return false
		
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
	
	var data = json.get_data()
	if typeof(data) == TYPE_DICTIONARY:
		equipment_database = data
	else:
		push_error("Invalid equipment database format: expected a dictionary")
		emit_signal("data_load_failed", "equipment_database", ERR_INVALID_DATA)
		return false
		
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
	
	var data = json.get_data()
	if typeof(data) == TYPE_DICTIONARY:
		loot_tables = data
	else:
		push_error("Invalid loot tables format: expected a dictionary")
		emit_signal("data_load_failed", "loot_tables", ERR_INVALID_DATA)
		return false
		
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
	
	var data = json.get_data()
	if typeof(data) == TYPE_DICTIONARY and data.has("mission_templates"):
		mission_templates = data["mission_templates"]
	else:
		push_error("Invalid mission templates format: expected a dictionary with 'mission_templates' array")
		emit_signal("data_load_failed", "mission_templates", ERR_INVALID_DATA)
		return false
		
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
	
	var data = json.get_data()
	if typeof(data) == TYPE_DICTIONARY:
		character_creation_data = data
	else:
		push_error("Invalid character creation data format: expected a dictionary")
		emit_signal("data_load_failed", "character_creation_data", ERR_INVALID_DATA)
		return false
		
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
	
	var data = json.get_data()
	if typeof(data) == TYPE_DICTIONARY:
		weapons_database = data
	else:
		push_error("Invalid weapons database format: expected a dictionary")
		emit_signal("data_load_failed", "weapons_database", ERR_INVALID_DATA)
		return false
		
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
	
	var data = json.get_data()
	if typeof(data) == TYPE_DICTIONARY:
		armor_database = data
	else:
		push_error("Invalid armor database format: expected a dictionary")
		emit_signal("data_load_failed", "armor_database", ERR_INVALID_DATA)
		return false
		
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
	
	var data = json.get_data()
	if typeof(data) == TYPE_DICTIONARY:
		status_effects = data
	else:
		push_error("Invalid status effects format: expected a dictionary")
		emit_signal("data_load_failed", "status_effects", ERR_INVALID_DATA)
		return false
		
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
	
	if not enemy_types.has("enemy_categories"):
		push_error("Enemy types data is missing 'enemy_categories' key")
		return {}
		
	for category in enemy_types.get("enemy_categories", []):
		if not category.has("enemies"):
			continue
			
		for enemy in category.get("enemies", []):
			if enemy.has("id") and enemy.get("id") == enemy_id:
				return enemy
	
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
			if enemy_types.is_empty():
				return false
			if enemy_types.has("enemy_categories") or enemy_types.has("enemy_loot_tables") or enemy_types.has("enemy_spawn_rules"):
				return true
			return enemy_types.size() > 0
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

# Static accessor for data loading check
static func is_data_type_loaded(data_type: String) -> bool:
	return get_instance().is_data_loaded(data_type)

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
