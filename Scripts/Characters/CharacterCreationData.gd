class_name CharacterCreationData
extends Resource

var races: Array[Dictionary] = []
var backgrounds: Array[Dictionary] = []
var motivations: Array[Dictionary] = []
var classes: Array[Dictionary] = []
var skills: Array[Dictionary] = []

var tutorial_races: Array[Dictionary] = []
var tutorial_backgrounds: Array[Dictionary] = []
var tutorial_motivations: Array[Dictionary] = []
var tutorial_classes: Array[Dictionary] = []

func load_data() -> void:
	var json_data: Dictionary = load_json_file("res://data/character_creation_data.json")
	if json_data.has("races"):
		races = json_data.races
	if json_data.has("backgrounds"):
		backgrounds = json_data.backgrounds
	if json_data.has("motivations"):
		motivations = json_data.motivations
	if json_data.has("classes"):
		classes = json_data.classes
	if json_data.has("skills"):
		skills = json_data.skills
	
	var tutorial_data: Dictionary = load_json_file("res://data/RulesReference/tutorial_character_creation_data.json")
	if tutorial_data.has("tutorial_races"):
		tutorial_races = tutorial_data.tutorial_races
	if tutorial_data.has("tutorial_backgrounds"):
		tutorial_backgrounds = tutorial_data.tutorial_backgrounds
	if tutorial_data.has("tutorial_motivations"):
		tutorial_motivations = tutorial_data.tutorial_motivations
	if tutorial_data.has("tutorial_classes"):
		tutorial_classes = tutorial_data.tutorial_classes

func load_json_file(path: String) -> Dictionary:
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	var json: JSON = JSON.new()
	var error: Error = json.parse(file.get_as_text())
	if error == OK:
		return json.data
	else:
		push_error("JSON Parse Error: " + json.get_error_message())
		return {}

func get_race_data(race_id: String) -> Dictionary:
	var filtered_races: Array = races.filter(func(r): return r.id == race_id)
	if filtered_races.is_empty():
		push_warning("No race found for id: " + race_id)
		return {}
	return filtered_races[0]

func get_background_data(background_id: String) -> Dictionary:
	var filtered_backgrounds: Array = backgrounds.filter(func(b): return b.id == background_id)
	if filtered_backgrounds.is_empty():
		push_warning("No background found for id: " + background_id)
		return {}
	return filtered_backgrounds[0]

func get_motivation_data(motivation_id: String) -> Dictionary:
	var filtered_motivations: Array = motivations.filter(func(m): return m.id == motivation_id)
	if filtered_motivations.is_empty():
		push_warning("No motivation found for id: " + motivation_id)
		return {}
	return filtered_motivations[0]

func get_class_data(class_id: String) -> Dictionary:
	var filtered_classes: Array = classes.filter(func(c): return c.id == class_id)
	if filtered_classes.is_empty():
		push_warning("No class found for id: " + class_id)
		return {}
	return filtered_classes[0]

func get_skill_data(skill_id: String) -> Dictionary:
	var filtered_skills: Array = skills.filter(func(s): return s.id == skill_id)
	if filtered_skills.is_empty():
		push_warning("No skill found for id: " + skill_id)
		return {}
	return filtered_skills[0]

func get_tutorial_race_data(race_id: String) -> Dictionary:
	var filtered_races: Array = tutorial_races.filter(func(r): return r.id == race_id)
	if filtered_races.is_empty():
		push_warning("No tutorial race found for id: " + race_id)
		return {}
	return filtered_races[0]

func get_tutorial_background_data(background_id: String) -> Dictionary:
	var filtered_backgrounds: Array = tutorial_backgrounds.filter(func(b): return b.id == background_id)
	if filtered_backgrounds.is_empty():
		push_warning("No tutorial background found for id: " + background_id)
		return {}
	return filtered_backgrounds[0]

func get_tutorial_motivation_data(motivation_id: String) -> Dictionary:
	var filtered_motivations: Array = tutorial_motivations.filter(func(m): return m.id == motivation_id)
	if filtered_motivations.is_empty():
		push_warning("No tutorial motivation found for id: " + motivation_id)
		return {}
	return filtered_motivations[0]

func get_tutorial_class_data(class_id: String) -> Dictionary:
	var filtered_classes: Array = tutorial_classes.filter(func(c): return c.id == class_id)
	if filtered_classes.is_empty():
		push_warning("No tutorial class found for id: " + class_id)
		return {}
	return filtered_classes[0]

# Additional utility functions

func get_all_races() -> Array[Dictionary]:
	return races

func get_all_backgrounds() -> Array[Dictionary]:
	return backgrounds

func get_all_motivations() -> Array[Dictionary]:
	return motivations

func get_all_classes() -> Array[Dictionary]:
	return classes

func get_all_skills() -> Array[Dictionary]:
	return skills

func get_all_tutorial_races() -> Array[Dictionary]:
	return tutorial_races

func get_all_tutorial_backgrounds() -> Array[Dictionary]:
	return tutorial_backgrounds

func get_all_tutorial_motivations() -> Array[Dictionary]:
	return tutorial_motivations

func get_all_tutorial_classes() -> Array[Dictionary]:
	return tutorial_classes
