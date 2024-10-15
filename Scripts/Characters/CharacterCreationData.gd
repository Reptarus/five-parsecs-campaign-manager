@tool
class_name CharacterCreationData
extends Resource

## Character creation data arrays
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

## Tutorial data (if needed)
@export var tutorial_data: Dictionary = {}

## Cache for loaded data
var _data_cache: Dictionary = {}

func _init() -> void:
	load_data()

## Loads character creation data from JSON file
func load_data() -> void:
	if not _data_cache.is_empty():
		return  # Data already loaded
	
	print("Loading character creation data from JSON")
	var json_data: Dictionary = load_json_file("res://data/character_creation_data.json")
	print("JSON data loaded. Number of categories: ", json_data.size())
	print("Categories loaded: ", json_data.keys())
	
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

## Loads and parses a JSON file
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

## Converts an array to an Array[Dictionary]
func _convert_to_array_dictionary(data: Array) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for item in data:
		if item is Dictionary:
			result.append(item)
	return result

## Converts an array to an Array[int]
func _convert_to_array_int(data: Array) -> Array[int]:
	var result: Array[int] = []
	for item in data:
		if item is int:
			result.append(item)
	return result

## Generic get_all functions
func get_all_species() -> Array[Dictionary]: return species
func get_all_backgrounds() -> Array[Dictionary]: return backgrounds
func get_all_motivations() -> Array[Dictionary]: return motivations
func get_all_classes() -> Array[Dictionary]: return classes
func get_all_skills() -> Array[Dictionary]: return skills
func get_all_strange_characters() -> Array[Dictionary]: return strange_characters
func get_all_weapons() -> Array[Dictionary]: return weapons
func get_all_crew_sizes() -> Array[int]: return crew_sizes
func get_all_victory_conditions() -> Array[Dictionary]: return victory_conditions
func get_all_gear() -> Array[Dictionary]: return gear
func get_all_ship_upgrades() -> Array[Dictionary]: return ship_upgrades
func get_all_story_hooks() -> Array[Dictionary]: return story_hooks

## Generic get_data functions
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

## Generic get_description functions
func get_description_by_id(data_array: Array[Dictionary], id: String) -> String:
	var item = get_data_by_id(data_array, id)
	return item.get("description", "Description not found")

func get_background_description(background_id: String) -> String:
	return get_description_by_id(backgrounds, background_id)

func get_motivation_description(motivation_id: String) -> String:
	return get_description_by_id(motivations, motivation_id)

func get_class_description(class_id: String) -> String:
	return get_description_by_id(classes, class_id)

## Functions for roll effects
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

## Random outcome generation
func generate_random_outcome(outcomes: Array) -> Dictionary:
	if outcomes.is_empty():
		return {}
	return outcomes[randi() % outcomes.size()]

## Get tutorial data for a specific category
func get_tutorial_data(category: String) -> Dictionary:
	return tutorial_data.get(category, {})

## Generate a summary of the test crew
func get_test_crew_summary() -> String:
	var summary = "Test Crew Summary:\n"
	for character in get_all_strange_characters():
		summary += "- %s (%s): %s\n" % [character.get("name", "Unknown"), character.get("class", "Unknown"), character.get("description", "No description")]
	return summary

## Generate a test crew of characters
func generate_test_crew(crew_size: int = 4) -> Array[Character]:
	var test_crew: Array[Character] = []
	for i in range(crew_size):
		var character = Character.new()
		var random_class = classes[randi() % classes.size()]
		var random_species = species[randi() % species.size()]
		var random_background = backgrounds[randi() % backgrounds.size()]
		var random_motivation = motivations[randi() % motivations.size()]
		
		character.name = "Test Crew Member %d" % (i + 1)
		_set_character_class(character, random_class)
		_set_character_species(character, random_species)
		character.background = GlobalEnums.Background[random_background.get("id", "HIGH_TECH_COLONY")]
		character.motivation = GlobalEnums.Motivation[random_motivation.get("id", "ADVENTURE")]
		
		_initialize_character_properties(character)
		
		test_crew.append(character)
	return test_crew

## Set the character's class
func _set_character_class(character: Character, random_class: Dictionary) -> void:
	var class_id = random_class.get("id", "")
	if class_id in GlobalEnums.Class:
		character.character_class = GlobalEnums.Class[class_id]
	else:
		push_warning("Invalid class ID: %s. Using default." % class_id)
		character.character_class = GlobalEnums.Class.WORKING_CLASS

## Set the character's species
func _set_character_species(character: Character, random_species: Dictionary) -> void:
	var species_id = random_species.get("id", "")
	if species_id in GlobalEnums.Species:
		character.species = GlobalEnums.Species[species_id]
	else:
		push_warning("Invalid species ID: %s. Using default." % species_id)
		character.species = GlobalEnums.Species.HUMAN

## Initialize default character properties
func _initialize_character_properties(character: Character) -> void:
	character.is_strange = false
	character.strange_type = ""
	character.reactions = 1
	character.speed = 4
	character.combat_skill = 0
	character.toughness = 3
	character.savvy = 0
	character.xp = 0
	character.level = 1
	character.luck = 0
	character.set_injuries([])
	character.status = GlobalEnums.CharacterStatus.ACTIVE
	character.character_advancement = CharacterAdvancement.new(character)
	
	if randf() < 0.1:  # 10% chance of having a psionic power
		character.psionic_power = GlobalEnums.PsionicPower.values()[randi() % (GlobalEnums.PsionicPower.size() - 1) + 1]
	
	if GameStateManager.has_medical_bay_component():
		character.medbay_turns_left = 0

## Generate random skills for a character
func _generate_random_skills() -> Dictionary:
	var random_skills = {}
	for skill in skills:
		random_skills[skill.get("id")] = randi() % 5  # Random skill level between 0 and 4
	return random_skills
