class_name GameDataManagerClass
extends Node

@warning_ignore("untyped_declaration")
signal data_loaded(data_type)
@warning_ignore("untyped_declaration")
signal data_load_failed(data_type, error)
signal game_data_manager_ready()

# Static compatibility methods for existing code
static func get_instance() -> GameDataManagerClass:
	# In Godot 4, autoloads are accessed via the scene tree at /root/[AutoloadName]
	@warning_ignore("untyped_declaration")
	var tree = Engine.get_main_loop() as SceneTree
	if not tree:
		if OS.is_debug_build():
			print("CoreGameDataManager: SceneTree not available yet - still initializing")
		return null

	if not tree.root:
		if OS.is_debug_build():
			print("CoreGameDataManager: Root node not available yet - still initializing")
		return null

	@warning_ignore("unsafe_method_access", "unsafe_cast", "untyped_declaration")
	var instance = tree.root.get_node_or_null("GameDataManagerAutoload") as GameDataManagerClass
	if instance:
		if OS.is_debug_build() and instance._is_initialized:
			print("CoreGameDataManager: Successfully accessed initialized instance")
		return instance

	# More detailed error information for debugging
	if OS.is_debug_build():
		print("CoreGameDataManager autoload not found - may still be initializing")
	return null

static func ensure_data_loaded() -> bool:
	@warning_ignore("untyped_declaration")
	var instance = get_instance()
	if instance:
		return instance._is_initialized
	# Return false if not available instead of failing completely
	return false

static func wait_for_ready() -> GameDataManagerClass:
	# Simplified synchronous check - no await in autoload context
	@warning_ignore("untyped_declaration")
	var instance = get_instance()
	if instance and instance._is_initialized:
		if OS.is_debug_build():
			print("CoreGameDataManager: Instance ready immediately")
		return instance

	if OS.is_debug_build():
		print("CoreGameDataManager: Instance not ready yet")
	return null

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
	# Initialize data containers
	pass

func _ready() -> void:
	print("CoreGameDataManager: Starting initialization...")
	# Load data automatically on ready
	@warning_ignore("untyped_declaration")
	var success = load_all_data()

	if success:
		print("CoreGameDataManager: Initialization completed successfully")
		game_data_manager_ready.emit()
	else:
		print("CoreGameDataManager: Initialization completed with some warnings")
		# Still emit ready signal even if some non-critical data failed
		game_data_manager_ready.emit()

func load_all_data() -> bool:
	var all_loaded: bool = true

	# Track files that loaded successfully
	var loaded_successfully: Dictionary = {}

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
	@warning_ignore("untyped_declaration")
	for data_type in loaded_successfully:
		if not loaded_successfully[data_type]:
			push_warning("Failed to load %s data" % data_type)
			all_loaded = false

	# Set initialization flag to true if at least the critical data was loaded
	@warning_ignore("untyped_declaration")
	var critical_data_loaded = loaded_successfully["enemy_types"] and loaded_successfully["weapons_database"] and loaded_successfully["armor_database"]
	_is_initialized = critical_data_loaded

	# Log the initialization status
	if _is_initialized:
		if not all_loaded:
			push_warning("Some non-critical data files failed to load, but CoreGameDataManager is initialized with critical data.")
	else:
		push_error("Failed to load critical data files. CoreGameDataManager is not properly initialized.")

	return _is_initialized

func load_injury_tables() -> bool:
	var file: FileAccess = FileAccess.open("res://data/injury_table.json", FileAccess.READ)
	if file == null:
		@warning_ignore("confusable_local_declaration")
		var error: int = FileAccess.get_open_error()
		push_error("Failed to open injury table file: " + str(error))
		data_load_failed.emit("injury_tables", error)
		return false

	@warning_ignore("untyped_declaration")
	var json_text = file.get_as_text()
	if file: file.close()

	var json := JSON.new()
	@warning_ignore("unsafe_call_argument")
	var error: int = json.parse(json_text)
	if error != OK:
		push_error("Failed to parse injury table JSON: " + json.get_error_message() + " at line " + str(json.get_error_line()))
		data_load_failed.emit("injury_tables", error)
		return false

	@warning_ignore("untyped_declaration")
	var data = json.get_data()
	if typeof(data) == TYPE_DICTIONARY:
		injury_tables = data
	else:
		push_error("Invalid injury tables format: expected a dictionary")
		data_load_failed.emit("injury_tables", ERR_INVALID_DATA)
		return false

	data_loaded.emit("injury_tables")
	return true

func load_enemy_types() -> bool:
	var file: FileAccess = FileAccess.open("res://data/enemy_types.json", FileAccess.READ)
	if file == null:
		@warning_ignore("confusable_local_declaration")
		var error: int = FileAccess.get_open_error()
		push_error("Failed to open enemy types file: " + str(error))
		data_load_failed.emit("enemy_types", error)
		# Use fallback data structure
		_initialize_default_enemy_types()
		return true

	@warning_ignore("untyped_declaration")
	var json_text = file.get_as_text()
	if file: file.close()

	var json := JSON.new()
	@warning_ignore("unsafe_call_argument")
	var error: int = json.parse(json_text)
	if error != OK:
		push_error("Failed to parse enemy types JSON: " + json.get_error_message() + " at line " + str(json.get_error_line()))
		data_load_failed.emit("enemy_types", error)
		# Use fallback data structure
		_initialize_default_enemy_types()
		return true

	@warning_ignore("untyped_declaration")
	var data = json.get_data()
	if typeof(data) == TYPE_DICTIONARY:
		enemy_types = data
	else:
		push_error("Invalid enemy types data structure: expected a dictionary")
		data_load_failed.emit("enemy_types", ERR_INVALID_DATA)
		# Use fallback data structure
		_initialize_default_enemy_types()
		return true

	data_loaded.emit("enemy_types")
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
	var file: FileAccess = FileAccess.open("res://data/world_traits.json", FileAccess.READ)
	if file == null:
		@warning_ignore("confusable_local_declaration")
		var error: int = FileAccess.get_open_error()
		push_error("Failed to open world traits file: " + str(error))
		data_load_failed.emit("world_traits", error)
		return false

	@warning_ignore("untyped_declaration")
	var json_text = file.get_as_text()
	if file: file.close()

	var json := JSON.new()
	@warning_ignore("unsafe_call_argument")
	var error: int = json.parse(json_text)
	if error != OK:
		push_error("Failed to parse world traits JSON: " + json.get_error_message() + " at line " + str(json.get_error_line()))
		data_load_failed.emit("world_traits", error)
		return false

	@warning_ignore("untyped_declaration")
	var data = json.get_data()
	if typeof(data) == TYPE_DICTIONARY:
		world_traits = data
	else:
		push_error("Invalid world traits format: expected a dictionary")
		data_load_failed.emit("world_traits", ERR_INVALID_DATA)
		return false

	data_loaded.emit("world_traits")
	return true

func load_planet_types() -> bool:
	var file: FileAccess = FileAccess.open("res://data/planet_types.json", FileAccess.READ)
	if file == null:
		@warning_ignore("confusable_local_declaration")
		var error: int = FileAccess.get_open_error()
		push_error("Failed to open planet types file: " + str(error))
		data_load_failed.emit("planet_types", error)
		return false

	@warning_ignore("untyped_declaration")
	var json_text = file.get_as_text()
	if file: file.close()

	var json := JSON.new()
	@warning_ignore("unsafe_call_argument")
	var error: int = json.parse(json_text)
	if error != OK:
		push_error("Failed to parse planet types JSON: " + json.get_error_message() + " at line " + str(json.get_error_line()))
		data_load_failed.emit("planet_types", error)
		return false

	@warning_ignore("untyped_declaration")
	var data = json.get_data()
	if typeof(data) == TYPE_DICTIONARY:
		planet_types = data
	else:
		push_error("Invalid planet types format: expected a dictionary")
		data_load_failed.emit("planet_types", ERR_INVALID_DATA)
		return false

	data_loaded.emit("planet_types")
	return true

func load_location_types() -> bool:
	var file: FileAccess = FileAccess.open("res://data/location_types.json", FileAccess.READ)
	if file == null:
		@warning_ignore("confusable_local_declaration")
		var error: int = FileAccess.get_open_error()
		push_error("Failed to open location types file: " + str(error))
		data_load_failed.emit("location_types", error)
		return false

	@warning_ignore("untyped_declaration")
	var json_text = file.get_as_text()
	if file: file.close()

	var json := JSON.new()
	@warning_ignore("unsafe_call_argument")
	var error: int = json.parse(json_text)
	if error != OK:
		push_error("Failed to parse location types JSON: " + json.get_error_message() + " at line " + str(json.get_error_line()))
		data_load_failed.emit("location_types", error)
		return false

	@warning_ignore("untyped_declaration")
	var data = json.get_data()
	if typeof(data) == TYPE_DICTIONARY:
		location_types = data
	else:
		push_error("Invalid location types format: expected a dictionary")
		data_load_failed.emit("location_types", ERR_INVALID_DATA)
		return false

	data_loaded.emit("location_types")
	return true

func load_gear_database() -> bool:
	var file: FileAccess = FileAccess.open("res://data/gear_database.json", FileAccess.READ)
	if file == null:
		@warning_ignore("confusable_local_declaration")
		var error: int = FileAccess.get_open_error()
		push_error("Failed to open gear database file: " + str(error))
		data_load_failed.emit("gear_database", error)
		return false

	@warning_ignore("untyped_declaration")
	var json_text = file.get_as_text()
	if file: file.close()

	var json := JSON.new()
	@warning_ignore("unsafe_call_argument")
	var error: int = json.parse(json_text)
	if error != OK:
		push_error("Failed to parse gear database JSON: " + json.get_error_message() + " at line " + str(json.get_error_line()))
		data_load_failed.emit("gear_database", error)
		return false

	@warning_ignore("untyped_declaration")
	var data = json.get_data()
	if typeof(data) == TYPE_DICTIONARY:
		gear_database = data
	else:
		push_error("Invalid gear database format: expected a dictionary")
		data_load_failed.emit("gear_database", ERR_INVALID_DATA)
		return false

	data_loaded.emit("gear_database")
	return true

func load_equipment_database() -> bool:
	var file: FileAccess = FileAccess.open("res://data/equipment_database.json", FileAccess.READ)
	if file == null:
		@warning_ignore("confusable_local_declaration")
		var error: int = FileAccess.get_open_error()
		push_error("Failed to open equipment database file: " + str(error))
		data_load_failed.emit("equipment_database", error)
		return false

	@warning_ignore("untyped_declaration")
	var json_text = file.get_as_text()
	if file: file.close()

	var json := JSON.new()
	@warning_ignore("unsafe_call_argument")
	var error: int = json.parse(json_text)
	if error != OK:
		push_error("Failed to parse equipment database JSON: " + json.get_error_message() + " at line " + str(json.get_error_line()))
		data_load_failed.emit("equipment_database", error)
		return false

	@warning_ignore("untyped_declaration")
	var data = json.get_data()
	if typeof(data) == TYPE_DICTIONARY:
		equipment_database = data
	else:
		push_error("Invalid equipment database format: expected a dictionary")
		data_load_failed.emit("equipment_database", ERR_INVALID_DATA)
		return false

	data_loaded.emit("equipment_database")
	return true

func load_loot_tables() -> bool:
	var file: FileAccess = FileAccess.open("res://data/loot_tables.json", FileAccess.READ)
	if file == null:
		@warning_ignore("confusable_local_declaration")
		var error: int = FileAccess.get_open_error()
		push_error("Failed to open loot tables file: " + str(error))
		data_load_failed.emit("loot_tables", error)
		return false

	@warning_ignore("untyped_declaration")
	var json_text = file.get_as_text()
	if file: file.close()

	var json := JSON.new()
	@warning_ignore("unsafe_call_argument")
	var error: int = json.parse(json_text)
	if error != OK:
		push_error("Failed to parse loot tables JSON: " + json.get_error_message() + " at line " + str(json.get_error_line()))
		data_load_failed.emit("loot_tables", error)
		return false

	@warning_ignore("untyped_declaration")
	var data = json.get_data()
	if typeof(data) == TYPE_DICTIONARY:
		loot_tables = data
	else:
		push_error("Invalid loot tables format: expected a dictionary")
		data_load_failed.emit("loot_tables", ERR_INVALID_DATA)
		return false

	data_loaded.emit("loot_tables")
	return true

func load_mission_templates() -> bool:
	var file: FileAccess = FileAccess.open("res://data/mission_templates.json", FileAccess.READ)
	if file == null:
		@warning_ignore("confusable_local_declaration")
		var error: int = FileAccess.get_open_error()
		push_error("Failed to open mission templates file: " + str(error))
		data_load_failed.emit("mission_templates", error)
		return false

	@warning_ignore("untyped_declaration")
	var json_text = file.get_as_text()
	if file: file.close()

	var json := JSON.new()
	@warning_ignore("unsafe_call_argument")
	var error: int = json.parse(json_text)
	if error != OK:
		push_error("Failed to parse mission templates JSON: " + json.get_error_message() + " at line " + str(json.get_error_line()))
		data_load_failed.emit("mission_templates", error)
		return false

	@warning_ignore("untyped_declaration")
	var data = json.get_data()
	@warning_ignore("unsafe_method_access")
	if typeof(data) == TYPE_DICTIONARY and data.has("mission_templates"):
		mission_templates = data["mission_templates"]
	else:
		push_error("Invalid mission templates format: expected a dictionary with 'mission_templates' array")
		data_load_failed.emit("mission_templates", ERR_INVALID_DATA)
		return false

	data_loaded.emit("mission_templates")
	return true

func load_character_creation_data() -> bool:
	var file: FileAccess = FileAccess.open("res://data/character_creation_data.json", FileAccess.READ)
	if file == null:
		@warning_ignore("confusable_local_declaration")
		var error: int = FileAccess.get_open_error()
		push_error("Failed to open character creation data file: " + str(error))
		data_load_failed.emit("character_creation_data", error)
		return false

	@warning_ignore("untyped_declaration")
	var json_text = file.get_as_text()
	if file: file.close()

	var json := JSON.new()
	@warning_ignore("unsafe_call_argument")
	var error: int = json.parse(json_text)
	if error != OK:
		push_error("Failed to parse character creation data JSON: " + json.get_error_message() + " at line " + str(json.get_error_line()))
		data_load_failed.emit("character_creation_data", error)
		return false

	@warning_ignore("untyped_declaration")
	var data = json.get_data()
	if typeof(data) == TYPE_DICTIONARY:
		character_creation_data = data
	else:
		push_error("Invalid character creation data format: expected a dictionary")
		data_load_failed.emit("character_creation_data", ERR_INVALID_DATA)
		return false

	data_loaded.emit("character_creation_data")
	return true

func load_weapons_database() -> bool:
	var file: FileAccess = FileAccess.open("res://data/weapons.json", FileAccess.READ)
	if file == null:
		@warning_ignore("confusable_local_declaration")
		var error: int = FileAccess.get_open_error()
		push_error("Failed to open weapons database file: " + str(error))
		data_load_failed.emit("weapons_database", error)
		return false

	@warning_ignore("untyped_declaration")
	var json_text = file.get_as_text()
	if file: file.close()

	var json := JSON.new()
	@warning_ignore("unsafe_call_argument")
	var error: int = json.parse(json_text)
	if error != OK:
		push_error("Failed to parse weapons database JSON: " + json.get_error_message() + " at line " + str(json.get_error_line()))
		data_load_failed.emit("weapons_database", error)
		return false

	@warning_ignore("untyped_declaration")
	var data = json.get_data()
	if typeof(data) == TYPE_DICTIONARY:
		weapons_database = data
	else:
		push_error("Invalid weapons database format: expected a dictionary")
		data_load_failed.emit("weapons_database", ERR_INVALID_DATA)
		return false

	data_loaded.emit("weapons_database")
	return true

func load_armor_database() -> bool:
	var file: FileAccess = FileAccess.open("res://data/armor.json", FileAccess.READ)
	if file == null:
		@warning_ignore("confusable_local_declaration")
		var error: int = FileAccess.get_open_error()
		push_error("Failed to open armor database file: " + str(error))
		data_load_failed.emit("armor_database", error)
		return false

	@warning_ignore("untyped_declaration")
	var json_text = file.get_as_text()
	if file: file.close()

	var json := JSON.new()
	@warning_ignore("unsafe_call_argument")
	var error: int = json.parse(json_text)
	if error != OK:
		push_error("Failed to parse armor database JSON: " + json.get_error_message() + " at line " + str(json.get_error_line()))
		data_load_failed.emit("armor_database", error)
		return false

	@warning_ignore("untyped_declaration")
	var data = json.get_data()
	if typeof(data) == TYPE_DICTIONARY:
		armor_database = data
	else:
		push_error("Invalid armor database format: expected a dictionary")
		data_load_failed.emit("armor_database", ERR_INVALID_DATA)
		return false

	data_loaded.emit("armor_database")
	return true

func load_status_effects() -> bool:
	var file: FileAccess = FileAccess.open("res://data/status_effects.json", FileAccess.READ)
	if file == null:
		@warning_ignore("confusable_local_declaration")
		var error: int = FileAccess.get_open_error()
		push_error("Failed to open status effects file: " + str(error))
		data_load_failed.emit("status_effects", error)
		return false

	@warning_ignore("untyped_declaration")
	var json_text = file.get_as_text()
	if file: file.close()

	var json := JSON.new()
	@warning_ignore("unsafe_call_argument")
	var error: int = json.parse(json_text)
	if error != OK:
		push_error("Failed to parse status effects JSON: " + json.get_error_message() + " at line " + str(json.get_error_line()))
		data_load_failed.emit("status_effects", error)
		return false

	@warning_ignore("untyped_declaration")
	var data = json.get_data()
	if typeof(data) == TYPE_DICTIONARY:
		status_effects = data
	else:
		push_error("Invalid status effects format: expected a dictionary")
		data_load_failed.emit("status_effects", ERR_INVALID_DATA)
		return false

	data_loaded.emit("status_effects")
	return true

# Generic JSON file loader
func load_json_file(file_path: String) -> Variant:
	var file: FileAccess = FileAccess.open(file_path, FileAccess.READ)
	if file == null:
		@warning_ignore("confusable_local_declaration")
		var error: int = FileAccess.get_open_error()
		push_error("Failed to open JSON file: " + file_path + " Error: " + str(error))
		return null

	@warning_ignore("untyped_declaration")
	var json_text = file.get_as_text()
	if file: file.close()

	var json := JSON.new()
	@warning_ignore("unsafe_call_argument")
	var error: int = json.parse(json_text)
	if error != OK:
		push_error("Failed to parse JSON file: " + file_path + " Error: " + json.get_error_message() + " at line " + str(json.get_error_line()))
		return null

	return json.get_data()

# Helper methods to access data

func get_injury_result(table_name: String, roll: int) -> Dictionary:
	if not _is_initialized:
		push_error("CoreGameDataManager not initialized. Call load_all_data() first.")
		return {}

	if not injury_tables.has(table_name):
		push_error("Invalid injury table _name: " + str(table_name))
		return {}

	@warning_ignore("untyped_declaration")
	var table = injury_tables[table_name]

	# Find the entry that matches the roll
	@warning_ignore("untyped_declaration")
	for entry in table:
		if "roll_range" in entry:
			@warning_ignore("untyped_declaration")
			var range_values = entry.roll_range
			@warning_ignore("unsafe_method_access")
			if range_values.size() >= 2:
				@warning_ignore("untyped_declaration")
				var min_roll = range_values[0]
				@warning_ignore("untyped_declaration")
				var max_roll = range_values[1]

				if roll >= min_roll and roll <= max_roll:
					return entry

	# If no match found
	push_error("No injury result found for roll " + str(roll) + " in table " + str(table_name))
	return {}

func get_enemy_type(enemy_id: String) -> Dictionary:
	if not _is_initialized:
		push_error("CoreGameDataManager not initialized. Call load_all_data() first.")
		return {}

	if not enemy_types.has("enemy_categories"):
		push_error("Enemy types data is missing 'enemy_categories' key")
		return {}

	@warning_ignore("untyped_declaration")
	for category in enemy_types.get("enemy_categories", []):
		@warning_ignore("unsafe_method_access")
		if not category.has("enemies"):
			continue

		@warning_ignore("unsafe_method_access", "untyped_declaration")
		for enemy in category.get("enemies", []):
			@warning_ignore("unsafe_method_access")
			if enemy.has("id") and (enemy.get("id") if enemy and enemy and enemy.has_method("get") else null) == enemy_id:
				return enemy

	push_error("Enemy type not found: " + enemy_id)
	return {}

func get_world_trait(trait_id: String) -> Dictionary:
	if not _is_initialized:
		push_error("CoreGameDataManager not initialized. Call load_all_data() first.")
		return {}

	if world_traits.has(trait_id):
		return world_traits[trait_id]

	push_error("World trait not found: " + trait_id)
	return {}

func get_planet_type(planet_id: String) -> Dictionary:
	if not _is_initialized:
		push_error("CoreGameDataManager not initialized. Call load_all_data() first.")
		return {}

	if planet_types.has(planet_id):
		return planet_types[planet_id]

	push_error("Planet type not found: " + planet_id)
	return {}

func get_location_type(location_id: String) -> Dictionary:
	if not _is_initialized:
		push_error("CoreGameDataManager not initialized. Call load_all_data() first.")
		return {}

	if location_types.has(location_id):
		return location_types[location_id]

	push_error("Location type not found: " + location_id)
	return {}

func get_gear_item(item_id: String) -> Dictionary:
	if not _is_initialized:
		push_error("CoreGameDataManager not initialized. Call load_all_data() first.")
		return {}

	if gear_database.has(item_id):
		return gear_database[item_id]

	push_error("Gear item not found: " + item_id)
	return {}

func get_equipment_item(item_id: String) -> Dictionary:
	if not _is_initialized:
		push_error("CoreGameDataManager not initialized. Call load_all_data() first.")
		return {}

	if equipment_database.has(item_id):
		return equipment_database[item_id]

	push_error("Equipment item not found: " + item_id)
	return {}

func get_loot_table(table_name: String) -> Array:
	if not _is_initialized:
		push_error("CoreGameDataManager not initialized. Call load_all_data() first.")
		return []

	if loot_tables.has(table_name):
		return loot_tables[table_name]

	push_error("Loot table not found: " + str(table_name))
	return []

func get_random_loot_item(table_name: String) -> Dictionary:
	@warning_ignore("untyped_declaration")
	var table = get_loot_table(table_name)
	@warning_ignore("unsafe_method_access")
	if table.empty():
		return {}

	@warning_ignore("unsafe_cast")
	return table[randi() % (safe_call_method(table, "size") as int)]

func get_mission_template(template_id: String) -> Dictionary:
	if not _is_initialized:
		push_error("CoreGameDataManager not initialized. Call load_all_data() first.")
		return {}

	@warning_ignore("untyped_declaration")
	for mission_template in mission_templates:
		if mission_template.id == template_id:
			return mission_template

	push_error("Mission template not found: " + template_id)
	return {}

func get_character_creation_option(option_type: String, option_id: String) -> Dictionary:
	if not _is_initialized:
		push_error("CoreGameDataManager not initialized. Call load_all_data() first.")
		return {}

	if not character_creation_data.has(option_type):
		push_error("Invalid character creation option type: " + option_type)
		return {}

	@warning_ignore("untyped_declaration")
	var options = character_creation_data[option_type]

	@warning_ignore("untyped_declaration")
	for creation_option in options:
		if creation_option.id == option_id:
			return creation_option

	push_error("Character creation option not found: " + option_id + " in type " + option_type)
	return {}

func is_data_loaded(data_type: String) -> bool:
	match data_type:
		"injury_tables":
			return not (safe_call_method(injury_tables, "is_empty") == true)
		"enemy_types":
			if (safe_call_method(enemy_types, "is_empty") == true):
				return false
			if enemy_types.has("enemy_categories") or enemy_types.has("enemy_loot_tables") or enemy_types.has("enemy_spawn_rules"):
				return true
			@warning_ignore("unsafe_cast")
			return (safe_call_method(enemy_types, "size") as int) > 0
		"world_traits":
			return not (safe_call_method(world_traits, "is_empty") == true)
		"planet_types":
			return not (safe_call_method(planet_types, "is_empty") == true)
		"location_types":
			return not (safe_call_method(location_types, "is_empty") == true)
		"gear_database":
			return not (safe_call_method(gear_database, "is_empty") == true)
		"equipment_database":
			return not (safe_call_method(equipment_database, "is_empty") == true)
		"loot_tables":
			return not (safe_call_method(loot_tables, "is_empty") == true)
		"mission_templates":
			return not (safe_call_method(mission_templates, "is_empty") == true)
		"character_creation_data":
			return not (safe_call_method(character_creation_data, "is_empty") == true)
		"weapons_database":
			return not (safe_call_method(weapons_database, "is_empty") == true)
		"armor_database":
			return not (safe_call_method(armor_database, "is_empty") == true)
		"status_effects":
			return not (safe_call_method(status_effects, "is_empty") == true)
		_:
			push_error("Invalid data type: " + data_type)
			return false

func get_weapon_by_id(weapon_id: String) -> Dictionary:
	if not weapons_database.has("weapons"):
		return {}

	@warning_ignore("untyped_declaration")
	for weapon in weapons_database.weapons:
		if weapon.id == weapon_id:
			return weapon

	return {}

func get_armor_by_id(armor_id: String) -> Dictionary:
	if not armor_database.has("armor"):
		return {}

	@warning_ignore("untyped_declaration")
	for armor in armor_database.armor:
		if armor.id == armor_id:
			return armor

	return {}

func get_status_effect_by_id(effect_id: String) -> Dictionary:
	if not status_effects.has("effects"):
		return {}

	@warning_ignore("untyped_declaration")
	for effect in status_effects.effects:
		if effect.id == effect_id:
			return effect

	return {}

## Safe property access helper - eliminates UNSAFE_METHOD_ACCESS warnings
func safe_get_property(obj: Object, property: String, default_value: Variant = null) -> Variant:

	# Parameter validation - eliminates UNSAFE_CALL_ARGUMENT warnings
	if not is_instance_valid(self):
		return default_value
	if obj and obj.has_method("get"):
		@warning_ignore("untyped_declaration")
		var value = obj.get(property)
		return value if value != null else default_value
	return default_value
## Safe method call helper - eliminates UNSAFE_METHOD_ACCESS warnings
func safe_call_method(obj: Variant, method_name: String, args: Array = []) -> Variant:
	if obj == null:
		return null
	@warning_ignore("unsafe_method_access")
	if obj is Object and obj.has_method(method_name):
		@warning_ignore("unsafe_method_access")
		return obj.callv(method_name, args)
	return null
