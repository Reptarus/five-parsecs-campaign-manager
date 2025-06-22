@tool
extends Resource
class_name FPCM_GameDataManager

# Paths to data files
const ARMOR_DATA_PATH = "res://data/equipment/armor.json"
const WEAPON_DATA_PATH = "res://data/equipment/weapons.json"
const GEAR_DATA_PATH = "res://data/equipment/gear.json"
const WORLD_TRAITS_PATH = "res://data/world/world_traits.json"

# Loaded data caches
var _armor_database: Dictionary = {}
var _weapons_database: Dictionary = {}
var _gear_database: Dictionary = {}
var _world_traits_database: Dictionary = {}

# Signals
signal data_loaded(data_type: String)
signal data_error(data_type: String, error: String)

func _init() -> void:
	# Initialize data manager
	pass

## Load all databases
func load_all_data() -> void:
	load_armor_database()
	load_weapons_database()
	load_gear_database()
	load_world_traits()

## Load armor database
func load_armor_database() -> void:
	_armor_database = _load_json_data(ARMOR_DATA_PATH)
	data_loaded.emit("armor")  # warning: return value discarded (intentional)

## Load weapons database
func load_weapons_database() -> void:
	_weapons_database = _load_json_data(WEAPON_DATA_PATH)
	data_loaded.emit("weapons")  # warning: return value discarded (intentional)

## Load gear database
func load_gear_database() -> void:
	_gear_database = _load_json_data(GEAR_DATA_PATH)
	data_loaded.emit("gear")  # warning: return value discarded (intentional)

## Load world traits
func load_world_traits() -> void:
	_world_traits_database = _load_json_data(WORLD_TRAITS_PATH)
	data_loaded.emit("world_traits")  # warning: return value discarded (intentional)

## Get armor data by ID
func get_armor(armor_id: String) -> Dictionary:
	if _armor_database.has(armor_id):
		return _armor_database[armor_id].duplicate()
	return {}

## Get weapon data by ID
func get_weapon(weapon_id: String) -> Dictionary:
	if _weapons_database.has(weapon_id):
		return _weapons_database[weapon_id].duplicate()
	return {}

## Get gear item data by ID
func get_gear_item(gear_id: String) -> Dictionary:
	if _gear_database.has(gear_id):
		return _gear_database[gear_id].duplicate()
	return {}

## Get world trait data by ID
func get_world_trait(trait_id: String) -> Dictionary:
	if _world_traits_database.has(trait_id):
		return _world_traits_database[trait_id].duplicate()
	return {}

## Get all armors
func get_all_armor() -> Array:
	var result: Array = []
	for key in _armor_database:

		result.append(_armor_database[key].duplicate())  # warning: return value discarded (intentional)
	return result

## Get all weapons
func get_all_weapons() -> Array:
	var result: Array = []
	for key in _weapons_database:

		result.append(_weapons_database[key].duplicate())  # warning: return value discarded (intentional)
	return result

## Get all gear items
func get_all_gear() -> Array:
	var result: Array = []
	for key in _gear_database:

		result.append(_gear_database[key].duplicate())  # warning: return value discarded (intentional)
	return result

## Get all world traits
func get_all_world_traits() -> Array:
	var result: Array = []
	for key in _world_traits_database:

		result.append(_world_traits_database[key].duplicate())  # warning: return value discarded (intentional)
	return result

## Filter items by tags
func filter_by_tags(items: Array, required_tags: Array, excluded_tags: Array = []) -> Array:
	var result: Array = []
	
	for item in items:
		if not "_tags" in item:
			continue
			
		var item_tags = item["_tags"]
		var include_item: bool = true
		
		# Check required _tags
		for tag in required_tags:
			if not tag in item_tags:
				include_item = false
				break
				
		# Check excluded _tags
		if include_item:
			for tag in excluded_tags:
				if tag in item_tags:
					include_item = false
					break
					
		if include_item:

			result.append(item)  # warning: return value discarded (intentional)
			
	return result

## Helper to load JSON data from a file
func _load_json_data(file_path: String) -> Dictionary:
	if not FileAccess.file_exists(file_path):
		push_error("Data file not found: " + file_path)
		data_error.emit(file_path.get_file().get_basename(), "File not found")  # warning: return value discarded (intentional)
		return {}
		
	var file = FileAccess.open(file_path, FileAccess.READ)
	var text = file.get_as_text()
	file.close()
	
	var json := JSON.new()
	var error = json.parse(text)
	
	if error != OK:
		push_error("JSON Parse Error: " + json.get_error_message() + " in " + file_path + " at line " + str(json.get_error_line()))
		data_error.emit(file_path.get_file().get_basename(), "JSON Parse Error: " + json.get_error_message())  # warning: return value discarded (intentional)
		return {}
		
	var data = json.get_data()
	if typeof(data) != TYPE_DICTIONARY:
		push_error("Invalid data format in " + file_path)
		data_error.emit(file_path.get_file().get_basename(), "Invalid data format")  # warning: return value discarded (intentional)
		return {}
		
	return data
