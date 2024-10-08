@tool
class_name CharacterCreationData
extends Resource

@export var species: Array[Dictionary] = []
@export var backgrounds: Array[Dictionary] = []
@export var motivations: Array[Dictionary] = []
@export var classes: Array[Dictionary] = []
@export var skills: Array[Dictionary] = []

var tutorial_data: Dictionary = {
	"species": {
		"id": GlobalEnums.Species.HUMAN,
		"name": "Human",
		"effects": {
			"reactions": 0,
			"speed": 0,
			"combat_skill": 0,
			"toughness": 0,
			"savvy": 0
		}
	},
	"background": {
		"id": GlobalEnums.Background.MILITARY_BRAT,
		"name": "Military Brat",
		"effects": {
			"combat_skill": 1,
			"toughness": 1
		}
	},
	"motivation": {
		"id": GlobalEnums.Motivation.ADVENTURE,
		"name": "Adventure",
		"description": "Seeking thrills and excitement across the galaxy"
	},
	"class": {
		"id": GlobalEnums.Class.SOLDIER,
		"name": "Soldier",
		"abilities": ["Combat Training", "Tactical Awareness"]
	}
}

var _data_cache: Dictionary = {}

func load_data() -> void:
	if not _data_cache.is_empty():
		return  # Data already loaded
	
	var json_data: Dictionary = load_json_file("res://data/character_creation_data.json")
	species = _convert_to_array_dictionary(json_data.get("species", []))
	backgrounds = _convert_to_array_dictionary(json_data.get("backgrounds", []))
	motivations = _convert_to_array_dictionary(json_data.get("motivations", []))
	classes = _convert_to_array_dictionary(json_data.get("classes", []))
	skills = _convert_to_array_dictionary(json_data.get("skills", []))
	
	_data_cache = json_data  # Cache the loaded data

func load_json_file(path: String) -> Dictionary:
	if path in _data_cache:
		return _data_cache[path]
	
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("Failed to open file: " + path)
		return {}
	
	var json: JSON = JSON.new()
	var error: Error = json.parse(file.get_as_text())
	if error == OK:
		_data_cache[path] = json.data
		return json.data
	else:
		push_error("JSON Parse Error: " + json.get_error_message())
		return {}

func get_species_data(species_id: GlobalEnums.Species) -> Dictionary:
	var filtered_species: Array = species.filter(func(s): return s.id == species_id)
	if filtered_species.is_empty():
		push_warning("No species found for id: " + str(species_id))
		return {}
	return filtered_species[0]

func get_background_data(background_id: GlobalEnums.Background) -> Dictionary:
	var filtered_backgrounds: Array = backgrounds.filter(func(b): return b.id == background_id)
	if filtered_backgrounds.is_empty():
		push_warning("No background found for id: " + str(background_id))
		return {}
	return filtered_backgrounds[0]

func get_motivation_data(motivation_id: GlobalEnums.Motivation) -> Dictionary:
	var filtered_motivations: Array = motivations.filter(func(m): return m.id == motivation_id)
	if filtered_motivations.is_empty():
		push_warning("No motivation found for id: " + str(motivation_id))
		return {}
	return filtered_motivations[0]

func get_class_data(class_id: GlobalEnums.Class) -> Dictionary:
	var filtered_classes: Array = classes.filter(func(c): return c.id == class_id)
	if filtered_classes.is_empty():
		push_warning("No class found for id: " + str(class_id))
		return {}
	return filtered_classes[0]

func get_skill_data(skill_id: GlobalEnums.SkillType) -> Dictionary:
	var filtered_skills: Array = skills.filter(func(s): return s.id == skill_id)
	if filtered_skills.is_empty():
		push_warning("No skill found for id: " + str(skill_id))
		return {}
	return filtered_skills[0]

func get_tutorial_species_data() -> Dictionary:
	return tutorial_data["species"]

func get_tutorial_background_data() -> Dictionary:
	return tutorial_data["background"]

func get_tutorial_motivation_data() -> Dictionary:
	return tutorial_data["motivation"]

func get_tutorial_class_data() -> Dictionary:
	return tutorial_data["class"]

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

func _convert_to_array_dictionary(data: Array) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for item in data:
		if item is Dictionary:
			result.append(item)
	return result
