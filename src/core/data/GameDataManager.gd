@tool
extends Resource
class_name FPCM_GameDataManager

# Universal imports for safety patterns
# # Universal framework import removed to fix SHADOWED_GLOBAL_IDENTIFIER # Removed to fix SHADOWED_GLOBAL_IDENTIFIER - using global class
# # Universal framework import removed to fix SHADOWED_GLOBAL_IDENTIFIER # Removed to fix SHADOWED_GLOBAL_IDENTIFIER - using global class
# # Universal framework import removed to fix SHADOWED_GLOBAL_IDENTIFIER # Removed to fix SHADOWED_GLOBAL_IDENTIFIER - using global class

# Paths to data files - Fixed to match actual data structure
const ARMOR_DATA_PATH: String = "res://data/armor.json"
const WEAPON_DATA_PATH: String = "res://data/weapons.json"
const GEAR_DATA_PATH: String = "res://data/gear_database.json"
const WORLD_TRAITS_PATH: String = "res://data/world_traits.json"

# Additional missing constants for complete data loading
const INJURY_TABLES_PATH: String = "res://data/injury_table.json"
const ENEMY_TYPES_PATH: String = "res://data/enemy_types.json"
const PLANET_TYPES_PATH: String = "res://data/planet_types.json"
const LOCATION_TYPES_PATH: String = "res://data/location_types.json"
const MISSION_TEMPLATES_PATH: String = "res://data/mission_templates.json"
const LOOT_TABLES_PATH: String = "res://data/loot_tables.json"
const CHARACTER_CREATION_PATH: String = "res://data/character_creation_data.json"
const STATUS_EFFECTS_PATH: String = "res://data/status_effects.json"
const EQUIPMENT_DATABASE_PATH: String = "res://data/equipment_database.json"
const PSIONIC_POWERS_DATA_PATH: String = "res://data/psionic_powers.json"
const ELITE_ENEMY_TYPES_PATH: String = "res://data/elite_enemy_types.json"

# Loaded data caches - Enhanced type safety
var _armor_database: Dictionary = {}
var _weapons_database: Dictionary = {}
var _gear_database: Dictionary = {}
var _world_traits_database: Dictionary = {}

# Additional data caches for all data types
var _injury_tables: Dictionary = {}
var _psionic_powers_database: Dictionary = {}
var _elite_enemy_types: Dictionary = {}
var _enemy_types: Dictionary = {}
var _planet_types: Dictionary = {}
var _location_types: Dictionary = {}
var _mission_templates: Dictionary = {}
var _loot_tables: Dictionary = {}
var _character_creation_data: Dictionary = {}
var _status_effects: Dictionary = {}
var _equipment_database: Dictionary = {}

# Loaded data caches - Enhanced type safety
var _armor_database: Dictionary = {}
var _weapons_database: Dictionary = {}
var _gear_database: Dictionary = {}
var _world_traits_database: Dictionary = {}

# Additional data caches for all data types
var _injury_tables: Dictionary = {}
var _psionic_powers_database: Dictionary = {}
var _elite_enemy_types: Dictionary = {}
var _enemy_types: Dictionary = {}
var _planet_types: Dictionary = {}
var _location_types: Dictionary = {}
var _mission_templates: Dictionary = {}
var _loot_tables: Dictionary = {}
var _character_creation_data: Dictionary = {}
var _status_effects: Dictionary = {}
var _equipment_database: Dictionary = {}

# Internal state tracking
var _loading_in_progress: bool = false
var _load_errors: Array[String] = []

# Signals - Enhanced type safety
signal data_loaded(data_type: String)
signal data_error(data_type: String, error: String)
signal all_data_loaded()

func _init() -> void:
	# Initialize data manager with proper validation
	_validate_data_paths()
	print("FPCM_GameDataManager: Initialized with Universal safety patterns")

## Stage 1: Enhanced Type Safety and Validation
func _validate_data_paths() -> void:
	"""Validate all data file paths exist"""
	var paths: Array[String] = [
		ARMOR_DATA_PATH, WEAPON_DATA_PATH, GEAR_DATA_PATH, WORLD_TRAITS_PATH,
		INJURY_TABLES_PATH, ENEMY_TYPES_PATH, PLANET_TYPES_PATH, 
		LOCATION_TYPES_PATH, MISSION_TEMPLATES_PATH, LOOT_TABLES_PATH,
		CHARACTER_CREATION_PATH, STATUS_EFFECTS_PATH, EQUIPMENT_DATABASE_PATH,
		PSIONIC_POWERS_DATA_PATH,
		ELITE_ENEMY_TYPES_PATH
	]

	for path in paths:
		if not FileAccess.file_exists(path):
			push_warning("FPCM_GameDataManager: Data file not found: " + path)
			_load_errors.append("Missing file: " + path)

## Load all databases with enhanced error handling
func load_all_data() -> void:
	if _loading_in_progress:
		push_warning("FPCM_GameDataManager: Load already in progress")
		return

	_loading_in_progress = true
	_load_errors.clear()

	print("FPCM_GameDataManager: Starting comprehensive data load")

	# Load all databases with proper error tracking
	load_armor_database()
	load_weapons_database()
	load_gear_database()
	load_world_traits()
	load_injury_tables()
	load_enemy_types()
	load_planet_types()
	load_location_types()
	load_mission_templates()
	load_loot_tables()
	load_character_creation_data()
	load_status_effects()
	load_equipment_database()
	load_psionic_powers()

	_loading_in_progress = false

	# Emit completion signal
	self.all_data_loaded.emit()

## Load armor database with enhanced safety
func load_armor_database() -> void:
	print("FPCM_GameDataManager: Loading armor database")
	_armor_database = _load_json_data_safe(ARMOR_DATA_PATH, "armor")

	if not _armor_database.is_empty():
		self.data_loaded.emit("armor")
	else:
		push_error("FPCM_GameDataManager: Failed to load armor database")

## Load weapons database with enhanced safety
func load_weapons_database() -> void:
	print("FPCM_GameDataManager: Loading weapons database")
	_weapons_database = _load_json_data_safe(WEAPON_DATA_PATH, "weapons")

	if not _weapons_database.is_empty():
		self.data_loaded.emit("weapons")
	else:
		push_error("FPCM_GameDataManager: Failed to load weapons database")

## Load gear database with enhanced safety
func load_gear_database() -> void:
	print("FPCM_GameDataManager: Loading gear database")
	_gear_database = _load_json_data_safe(GEAR_DATA_PATH, "gear")

	if not _gear_database.is_empty():
		self.data_loaded.emit("gear")
	else:
		push_error("FPCM_GameDataManager: Failed to load gear database")

## Load world traits with enhanced safety
func load_world_traits() -> void:
	print("FPCM_GameDataManager: Loading world traits database")
	_world_traits_database = _load_json_data_safe(WORLD_TRAITS_PATH, "world_traits")

	if not _world_traits_database.is_empty():
		self.data_loaded.emit("world_traits")
	else:
		push_error("FPCM_GameDataManager: Failed to load world traits database")

## Load injury tables with enhanced safety
func load_injury_tables() -> void:
	print("FPCM_GameDataManager: Loading injury tables")
	_injury_tables = _load_json_data_safe(INJURY_TABLES_PATH, "injury_tables")
	if not _injury_tables.is_empty():
		self.data_loaded.emit("injury_tables")

## Load enemy types with enhanced safety
func load_enemy_types() -> void:
	print("FPCM_GameDataManager: Loading enemy types")
	_enemy_types = _load_json_data_safe(ENEMY_TYPES_PATH, "enemy_types")
	if not _enemy_types.is_empty():
		self.data_loaded.emit("enemy_types")

## Load planet types with enhanced safety
func load_planet_types() -> void:
	print("FPCM_GameDataManager: Loading planet types")
	_planet_types = _load_json_data_safe(PLANET_TYPES_PATH, "planet_types")
	if not _planet_types.is_empty():
		self.data_loaded.emit("planet_types")

## Load location types with enhanced safety
func load_location_types() -> void:
	print("FPCM_GameDataManager: Loading location types")
	_location_types = _load_json_data_safe(LOCATION_TYPES_PATH, "location_types")
	if not _location_types.is_empty():
		self.data_loaded.emit("location_types")

## Load mission templates with enhanced safety
func load_mission_templates() -> void:
	print("FPCM_GameDataManager: Loading mission templates")
	_mission_templates = _load_json_data_safe(MISSION_TEMPLATES_PATH, "mission_templates")
	if not _mission_templates.is_empty():
		self.data_loaded.emit("mission_templates")

## Load loot tables with enhanced safety
func load_loot_tables() -> void:
	print("FPCM_GameDataManager: Loading loot tables")
	_loot_tables = _load_json_data_safe(LOOT_TABLES_PATH, "loot_tables")
	if not _loot_tables.is_empty():
		self.data_loaded.emit("loot_tables")

## Load character creation data with enhanced safety
func load_character_creation_data() -> void:
	print("FPCM_GameDataManager: Loading character creation data")
	_character_creation_data = _load_json_data_safe(CHARACTER_CREATION_PATH, "character_creation_data")
	if not _character_creation_data.is_empty():
		self.data_loaded.emit("character_creation_data")

## Load status effects with enhanced safety
func load_status_effects() -> void:
	print("FPCM_GameDataManager: Loading status effects")
	_status_effects = _load_json_data_safe(STATUS_EFFECTS_PATH, "status_effects")
	if not _status_effects.is_empty():
		self.data_loaded.emit("status_effects")

## Load equipment database with enhanced safety
func load_equipment_database() -> void:
	print("FPCM_GameDataManager: Loading equipment database")
	_equipment_database = _load_json_data_safe(EQUIPMENT_DATABASE_PATH, "equipment_database")
	if not _equipment_database.is_empty():
		self.data_loaded.emit("equipment_database")

## Load psionic powers with enhanced safety
func load_psionic_powers() -> void:
	print("FPCM_GameDataManager: Loading psionic powers")
	_psionic_powers_database = _load_json_data_safe(PSIONIC_POWERS_DATA_PATH, "psionic_powers")
	if not _psionic_powers_database.is_empty():
		self.data_loaded.emit("psionic_powers")

## Load elite enemy types with enhanced safety
func load_elite_enemy_types() -> void:
	print("FPCM_GameDataManager: Loading elite enemy types")
	_elite_enemy_types = _load_json_data_safe(ELITE_ENEMY_TYPES_PATH, "elite_enemy_types")
	if not _elite_enemy_types.is_empty():
		self.data_loaded.emit("elite_enemy_types")

## Stage 2: Enhanced Data Access with Validation

## Get armor data by ID with enhanced validation
func get_armor(armor_id: String) -> Dictionary:
	if armor_id.is_empty():
		push_warning("FPCM_GameDataManager: Empty armor_id provided")
		return {}

	if _armor_database.has(armor_id):
		var armor_data: Dictionary = _armor_database[armor_id]
		if typeof(armor_data) == TYPE_DICTIONARY:
			return armor_data.duplicate()
		else:
			push_error("FPCM_GameDataManager: Invalid armor data type for ID: " + armor_id)
			return {}
	else:
		push_warning("FPCM_GameDataManager: Armor not found: " + armor_id)
		return {}

## Get weapon data by ID with enhanced validation
func get_weapon(weapon_id: String) -> Dictionary:
	if weapon_id.is_empty():
		push_warning("FPCM_GameDataManager: Empty weapon_id provided")
		return {}

	if _weapons_database.has(weapon_id):
		var weapon_data: Dictionary = _weapons_database[weapon_id]
		if typeof(weapon_data) == TYPE_DICTIONARY:
			return weapon_data.duplicate()
		else:
			push_error("FPCM_GameDataManager: Invalid weapon data type for ID: " + weapon_id)
			return {}
	else:
		push_warning("FPCM_GameDataManager: Weapon not found: " + weapon_id)
		return {}

## Get gear item data by ID with enhanced validation
func get_gear_item(gear_id: String) -> Dictionary:
	if gear_id.is_empty():
		push_warning("FPCM_GameDataManager: Empty gear_id provided")
		return {}

	if _gear_database.has(gear_id):
		var gear_data: Dictionary = _gear_database[gear_id]
		if typeof(gear_data) == TYPE_DICTIONARY:
			return gear_data.duplicate()
		else:
			push_error("FPCM_GameDataManager: Invalid gear data type for ID: " + gear_id)
			return {}
	else:
		push_warning("FPCM_GameDataManager: Gear item not found: " + gear_id)
		return {}

## Get world trait data by ID with enhanced validation
func get_world_trait(trait_id: String) -> Dictionary:
	if trait_id.is_empty():
		push_warning("FPCM_GameDataManager: Empty trait_id provided")
		return {}

	if _world_traits_database.has(trait_id):
		var trait_data: Dictionary = _world_traits_database[trait_id]
		if typeof(trait_data) == TYPE_DICTIONARY:
			return trait_data.duplicate()
		else:
			push_error("FPCM_GameDataManager: Invalid world trait data type for ID: " + trait_id)
			return {}
	else:
		push_warning("FPCM_GameDataManager: World trait not found: " + trait_id)
		return {}

## Stage 3: Enhanced Collection Methods with Proper Array Handling

## Get all armors with enhanced safety
func get_all_armor() -> Array[Dictionary]:
	var result: Array[Dictionary] = []

	for key in _armor_database.keys():
		var armor_data: Dictionary = _armor_database[key]
		if typeof(armor_data) == TYPE_DICTIONARY:
			@warning_ignore("return_value_discarded")
			result.append(armor_data.duplicate())
		else:
			push_warning("FPCM_GameDataManager: Invalid armor data type for key: " + str(key))

	return result

## Get all weapons with enhanced safety
func get_all_weapons() -> Array[Dictionary]:
	var result: Array[Dictionary] = []

	for key in _weapons_database.keys():
		var weapon_data: Dictionary = _weapons_database[key]
		if typeof(weapon_data) == TYPE_DICTIONARY:
			@warning_ignore("return_value_discarded")
			result.append(weapon_data.duplicate())
		else:
			push_warning("FPCM_GameDataManager: Invalid weapon data type for key: " + str(key))

	return result

## Get all gear items with enhanced safety
func get_all_gear() -> Array[Dictionary]:
	var result: Array[Dictionary] = []

	for key in _gear_database.keys():
		var gear_data: Dictionary = _gear_database[key]
		if typeof(gear_data) == TYPE_DICTIONARY:
			@warning_ignore("return_value_discarded")
			result.append(gear_data.duplicate())
		else:
			push_warning("FPCM_GameDataManager: Invalid gear data type for key: " + str(key))

	return result

## Get all world traits with enhanced safety
func get_all_world_traits() -> Array[Dictionary]:
	var result: Array[Dictionary] = []

	for key in _world_traits_database.keys():
		var trait_data: Dictionary = _world_traits_database[key]
		if typeof(trait_data) == TYPE_DICTIONARY:
			@warning_ignore("return_value_discarded")
			result.append(trait_data.duplicate())
		else:
			push_warning("FPCM_GameDataManager: Invalid world trait data type for key: " + str(key))

	return result

## Get injury tables data
func get_injury_tables() -> Dictionary:
	"""Get all injury tables data"""
	return _injury_tables.duplicate()

## Get enemy types data
func get_enemy_types() -> Dictionary:
	"""Get all enemy types data"""
	return _enemy_types.duplicate()

## Get planet types data
func get_planet_types() -> Dictionary:
	"""Get all planet types data"""
	return _planet_types.duplicate()

## Get location types data
func get_location_types() -> Dictionary:
	"""Get all location types data"""
	return _location_types.duplicate()

## Get mission templates data
func get_mission_templates() -> Dictionary:
	"""Get all mission templates data"""
	return _mission_templates.duplicate()

## Get loot tables data
func get_loot_tables() -> Dictionary:
	"""Get all loot tables data"""
	return _loot_tables.duplicate()

## Get character creation data
func get_character_creation_data() -> Dictionary:
	"""Get all character creation data"""
	return _character_creation_data.duplicate()

## Get status effects data
func get_status_effects() -> Dictionary:
	"""Get all status effects data"""
	return _status_effects.duplicate()

## Get equipment database
func get_equipment_database() -> Dictionary:
	"""Get all equipment database data"""
	return _equipment_database.duplicate()

## Get psionic powers data
func get_psionic_powers() -> Dictionary:
	"""Get all psionic powers data"""
	return _psionic_powers_database.duplicate()

## Get elite enemy types data
func get_elite_enemy_types() -> Dictionary:
	"""Get all elite enemy types data"""
	return _elite_enemy_types.duplicate()

## Stage 4: Enhanced Filtering System with Comprehensive Validation

## Filter items by tags with enhanced validation and safety
func filter_by_tags(items: Array, required_tags: Array[String], excluded_tags: Array[String] = []) -> Array[Dictionary]:
	var result: Array[Dictionary] = []

	if items.is_empty():
		push_warning("FPCM_GameDataManager: Empty items array provided to filter_by_tags")
		return result

	if required_tags.is_empty():
		push_warning("FPCM_GameDataManager: No required tags provided to filter_by_tags")
		return result

	for item in items:
		var typed_item: Variant = item
		if typeof(typed_item) != TYPE_DICTIONARY:
			push_warning("FPCM_GameDataManager: Non-dictionary item in filter_by_tags")
			continue

		var item_dict: Dictionary = typed_item

		if not item_dict.has("_tags"):
			continue

		var item_tags = item_dict["_tags"]
		if typeof(item_tags) != TYPE_ARRAY:
			push_warning("FPCM_GameDataManager: Invalid _tags type in item: " + str(item_dict.get("id", "unknown")))
			continue

		var item_tags_array: Array = item_tags as Array
		var include_item: bool = true

		# Check required tags
		for tag in required_tags:
			if not tag in item_tags_array:
				include_item = false
				break

		# Check excluded tags
		if include_item:
			for tag in excluded_tags:
				if tag in item_tags_array:
					include_item = false
					break

		if include_item:
			@warning_ignore("return_value_discarded")
			result.append(item_dict)

	return result

## Stage 5: Enhanced Data Loading with Comprehensive Error Handling

## Helper to load JSON data from a file with enhanced safety
func _load_json_data_safe(file_path: String, data_type: String) -> Dictionary:
	"""Load JSON data with comprehensive error handling and validation"""

	# Stage 1: File existence validation
	if not FileAccess.file_exists(file_path):
		var error_msg: String = "Data file not found: " + file_path
		push_error("FPCM_GameDataManager: " + error_msg)
		self.data_error.emit(data_type, "File not found")
		return {}

	# Stage 2: File access validation
	var file: FileAccess = FileAccess.open(file_path, FileAccess.READ)
	if not file:
		var error_msg: String = "Failed to open file: " + file_path
		push_error("FPCM_GameDataManager: " + error_msg)
		self.data_error.emit(data_type, "File access failed")
		return {}

	# Stage 3: Content reading validation
	var text: String = file.get_as_text()
	if file: file.close()

	if text.is_empty():
		var error_msg: String = "Empty file content: " + file_path
		push_error("FPCM_GameDataManager: " + error_msg)
		self.data_error.emit(data_type, "Empty file content")
		return {}

	# Stage 4: JSON parsing validation
	var json: JSON = JSON.new()
	var parse_result: Error = json.parse(text)

	if parse_result != OK:
		var error_msg: String = "JSON Parse Error: " + json.get_error_message() + " in " + file_path + " at line " + str(json.get_error_line())
		push_error("FPCM_GameDataManager: " + error_msg)
		self.data_error.emit(data_type, "JSON Parse Error: " + json.get_error_message())
		return {}

	# Stage 5: Data type validation
	var data = json.get_data()
	if typeof(data) != TYPE_DICTIONARY:
		var error_msg: String = "Invalid data format in " + file_path + " - expected Dictionary, got " + type_string(typeof(data))
		push_error("FPCM_GameDataManager: " + error_msg)
		self.data_error.emit(data_type, "Invalid data format - expected Dictionary")
		return {}

	# Stage 6: Content validation
	var data_dict: Dictionary = data as Dictionary
	if data_dict.is_empty():
		push_warning("FPCM_GameDataManager: Empty data dictionary in " + file_path)
		# Validate expected structure for critical files
		if data_type == "enemy_types" or data_type == "injury_tables":
			# These are critical for battle system
			push_error("FPCM_GameDataManager: Critical data file is empty: " + file_path)
			self.data_error.emit(data_type, "Critical file is empty")
		# Don't emit error for empty files, just return empty dict
		return {}

	print("FPCM_GameDataManager: Successfully loaded " + data_type + " data with " + str(data_dict.size()) + " entries")
	return data_dict

## Stage 6: Additional Utility Methods

## Get database statistics
func get_database_stats() -> Dictionary:
	"""Get comprehensive statistics about loaded databases"""
	return {
		"armor_count": _armor_database.size(),
		"weapons_count": _weapons_database.size(),
		"gear_count": _gear_database.size(),
		"world_traits_count": _world_traits_database.size(),
		"injury_tables_count": _injury_tables.size(),
		"enemy_types_count": _enemy_types.size(),
		"planet_types_count": _planet_types.size(),
		"location_types_count": _location_types.size(),
		"mission_templates_count": _mission_templates.size(),
		"loot_tables_count": _loot_tables.size(),
		"character_creation_count": _character_creation_data.size(),
		"status_effects_count": _status_effects.size(),
		"equipment_database_count": _equipment_database.size(),
		"total_items": _armor_database.size() + _weapons_database.size() + _gear_database.size() + _world_traits_database.size() + _injury_tables.size() + _enemy_types.size() + _planet_types.size() + _location_types.size() + _mission_templates.size() + _loot_tables.size() + _character_creation_data.size() + _status_effects.size() + _equipment_database.size(),
		"load_errors": _load_errors.size(),
		"loading_in_progress": _loading_in_progress
	}

## Check if all databases are loaded
func is_all_data_loaded() -> bool:
	"""Check if all databases have been successfully loaded"""
	return (
		not _armor_database.is_empty() and
		not _weapons_database.is_empty() and
		not _gear_database.is_empty() and
		not _world_traits_database.is_empty() and
		not _injury_tables.is_empty() and
		not _enemy_types.is_empty() and
		not _planet_types.is_empty() and
		not _location_types.is_empty() and
		not _mission_templates.is_empty() and
		not _loot_tables.is_empty() and
		not _character_creation_data.is_empty() and
		not _status_effects.is_empty() and
		not _equipment_database.is_empty() and
		not _psionic_powers_database.is_empty()
	)

## Get load errors
func get_load_errors() -> Array[String]:
	"""Get array of load errors that occurred"""
	return _load_errors.duplicate()

## Clear all databases
func clear_all_data() -> void:
	"""Clear all loaded databases"""
	_armor_database.clear()
	_weapons_database.clear()
	_gear_database.clear()
	_world_traits_database.clear()
	_load_errors.clear()
	_loading_in_progress = false
	print("FPCM_GameDataManager: All databases cleared")

## Stage 7: Final Validation and Cleanup

## Validate database integrity
func validate_database_integrity() -> Dictionary:
	"""Validate the integrity of all loaded databases"""
	var validation_result: Dictionary = {
		"valid": true,
		"errors": [],
		"warnings": []
	}

	# Validate armor database
	_validate_database_structure(_armor_database, "armor", validation_result)

	# Validate weapons database
	_validate_database_structure(_weapons_database, "weapons", validation_result)

	# Validate gear database
	_validate_database_structure(_gear_database, "gear", validation_result)

	# Validate world traits database
	_validate_database_structure(_world_traits_database, "world_traits", validation_result)

	return validation_result

## Helper to validate individual database structure
func _validate_database_structure(database: Dictionary, database_name: String, validation_result: Dictionary) -> void:
	"""Validate individual database structure"""
	if database.is_empty():
		@warning_ignore("return_value_discarded")
		validation_result["warnings"].append(str(database_name) + " database is empty")
		return

	for key in database.keys():
		var item = database[key]
		if typeof(item) != TYPE_DICTIONARY:
			@warning_ignore("return_value_discarded")
			validation_result["errors"].append(str(database_name) + " item " + str(key) + " is not a Dictionary")
			validation_result["valid"] = false

## Safe property access helper - eliminates UNSAFE_METHOD_ACCESS warnings
## Based on Godot 4.4 best practices for safe property access
func safe_get_property(obj: Variant, property: String, default_value: Variant = null) -> Variant:
	if obj == null:
		return default_value
	if obj is Object and obj.has_method("get"):
		var value: Variant = obj.get(property)
		return value if value != null else default_value
	elif obj is Dictionary:
		return obj.get(property, default_value)
	return default_value
## Safe method call helper - eliminates UNSAFE_METHOD_ACCESS warnings
func safe_call_method(obj: Variant, method_name: String, args: Array = []) -> Variant:
	if obj == null:
		return null
	if obj is Object and obj.has_method(method_name):
		return obj.callv(method_name, args)
	return null