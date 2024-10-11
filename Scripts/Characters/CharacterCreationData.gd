@tool
class_name CharacterCreationData
extends Resource

@export var species: Array[Dictionary] = []
@export var backgrounds: Array[Dictionary] = []
@export var motivations: Array[Dictionary] = []
@export var classes: Array[Dictionary] = []
@export var skills: Array[Dictionary] = []
@export var strange_characters: Array[Dictionary] = []
@export var weapons: Array[Dictionary] = []
@export var crew_sizes: Array[int] = []
@export var victory_conditions: Array[Dictionary] = []
@export var gear: Array[Dictionary] = []
@export var ship_upgrades: Array[Dictionary] = []
@export var story_hooks: Array[Dictionary] = []

var _data_cache: Dictionary = {}

func _init():
	load_data()

func load_data() -> void:
	if not _data_cache.is_empty():
		return  # Data already loaded
	
	print("Loading character creation data from JSON")
	var json_data: Dictionary = load_json_file("res://data/character_creation_data.json")
	print("JSON data loaded. Contents: ", json_data)
	
	species = _convert_to_array_dictionary(json_data.get("species", []))
	backgrounds = _convert_to_array_dictionary(json_data.get("backgrounds", []))
	motivations = _convert_to_array_dictionary(json_data.get("motivations", []))
	classes = _convert_to_array_dictionary(json_data.get("classes", []))
	skills = _convert_to_array_dictionary(json_data.get("skills", []))
	strange_characters = _convert_to_array_dictionary(json_data.get("strange_characters", []))
	weapons = _convert_to_array_dictionary(json_data.get("weapons", []))
	crew_sizes = _convert_to_array_int(json_data.get("crew_sizes", []))
	victory_conditions = _convert_to_array_dictionary(json_data.get("victory_conditions", []))
	gear = _convert_to_array_dictionary(json_data.get("gear", []))
	ship_upgrades = _convert_to_array_dictionary(json_data.get("ship_upgrades", []))
	story_hooks = _convert_to_array_dictionary(json_data.get("story_hooks", []))
	
	_data_cache = json_data  # Cache the loaded data

func load_json_file(path: String) -> Dictionary:
	if FileAccess.file_exists(path):
		var file = FileAccess.open(path, FileAccess.READ)
		var json = JSON.new()
		var error = json.parse(file.get_as_text())
		if error == OK:
			return json.data
		else:
			push_error("JSON Parse Error: " + json.get_error_message())
	else:
		push_error("File not found: " + path)
	return {}

func _convert_to_array_dictionary(data: Array) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for item in data:
		if item is Dictionary:
			result.append(item)
	return result

func _convert_to_array_int(data: Array) -> Array[int]:
	var result: Array[int] = []
	for item in data:
		if item is int:
			result.append(item)
	return result

# Generic get_all functions
func get_all_species() -> Array[Dictionary]:
	return species

func get_all_backgrounds() -> Array[Dictionary]:
	return backgrounds

func get_all_motivations() -> Array[Dictionary]:
	return motivations

func get_all_classes() -> Array[Dictionary]:
	return classes

func get_all_skills() -> Array[Dictionary]:
	return skills

func get_all_strange_characters() -> Array[Dictionary]:
	return strange_characters

func get_all_weapons() -> Array[Dictionary]:
	return weapons

func get_all_crew_sizes() -> Array[int]:
	return crew_sizes

func get_all_victory_conditions() -> Array[Dictionary]:
	return victory_conditions

func get_all_gear() -> Array[Dictionary]:
	return gear

func get_all_ship_upgrades() -> Array[Dictionary]:
	return ship_upgrades

func get_all_story_hooks() -> Array[Dictionary]:
	return story_hooks

# Generic get_data functions
func get_data_by_id(data_array: Array[Dictionary], id: String) -> Dictionary:
	var filtered_data: Array = data_array.filter(func(item): return item.id == id)
	if filtered_data.is_empty():
		push_warning("No item found for id: " + str(id))
		return {}
	return filtered_data[0]

func get_background_data(background_id: String) -> Dictionary:
	return get_data_by_id(backgrounds, background_id)

func get_motivation_data(motivation_id: String) -> Dictionary:
	return get_data_by_id(motivations, motivation_id)

func get_class_data(class_id: String) -> Dictionary:
	return get_data_by_id(classes, class_id)

func get_skill_data(skill_id: String) -> Dictionary:
	return get_data_by_id(skills, skill_id)

# Generic get_description functions
func get_description_by_id(data_array: Array[Dictionary], id: String) -> String:
	var item = get_data_by_id(data_array, id)
	return item.get("description", "Description not found")

func get_background_description(background_id: String) -> String:
	return get_description_by_id(backgrounds, background_id)

func get_motivation_description(motivation_id: String) -> String:
	return get_description_by_id(motivations, motivation_id)

func get_class_description(class_id: String) -> String:
	return get_description_by_id(classes, class_id)

# New functions for roll effects
func get_background_roll_effect(background_id: String, roll: int) -> String:
	var background = get_background_data(background_id)
	var roll_effects = background.get("roll_effects", {})
	return roll_effects.get(str(roll), "No effect")

func get_motivation_roll_effect(motivation_id: String, roll: int) -> String:
	var motivation = get_motivation_data(motivation_id)
	var roll_effects = motivation.get("roll_effects", {})
	return roll_effects.get(str(roll), "No effect")

func get_class_roll_effect(class_id: String, roll: int) -> String:
	var character_class = get_class_data(class_id)
	var roll_effects = character_class.get("roll_effects", {})
	return roll_effects.get(str(roll), "No effect")

# Random outcome generation
func generate_random_outcome(outcomes: Array) -> Dictionary:
	if outcomes.is_empty():
		return {}
	return outcomes[randi() % outcomes.size()]

# Tutorial data (if needed)
@export var tutorial_data: Dictionary = {}

func get_tutorial_data(category: String) -> Dictionary:
	return tutorial_data.get(category, {})
