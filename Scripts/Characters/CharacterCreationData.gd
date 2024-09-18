class_name CharacterCreationData
extends Resource

var races: Array = []
var backgrounds: Array = []
var motivations: Array = []
var classes: Array = []
var skills: Array = []

var tutorial_races: Array = []
var tutorial_backgrounds: Array = []
var tutorial_motivations: Array = []
var tutorial_classes: Array = []

func load_data():
	var json_data = load_json_file("res://data/character_creation_data.json")
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
	
	var tutorial_data = load_json_file("res://data/RulesReference/tutorial_character_creation_data.json")
	if tutorial_data.has("tutorial_races"):
		tutorial_races = tutorial_data.tutorial_races
	if tutorial_data.has("tutorial_backgrounds"):
		tutorial_backgrounds = tutorial_data.tutorial_backgrounds
	if tutorial_data.has("tutorial_motivations"):
		tutorial_motivations = tutorial_data.tutorial_motivations
	if tutorial_data.has("tutorial_classes"):
		tutorial_classes = tutorial_data.tutorial_classes

func load_json_file(path: String) -> Dictionary:
	var file = FileAccess.open(path, FileAccess.READ)
	var json = JSON.new()
	var error = json.parse(file.get_as_text())
	if error == OK:
		return json.get_data()
	else:
		print("JSON Parse Error: ", json.get_error_message())
		return {}

func get_race_data(race_id: String) -> Dictionary:
	return races.filter(func(r): return r.id == race_id)[0]

func get_background_data(background_id: String) -> Dictionary:
	var filtered_backgrounds = backgrounds.filter(func(b): return b.id == background_id)
	if filtered_backgrounds.is_empty():
		print("No background found for id: ", background_id)
		return {}
	return filtered_backgrounds[0]

func get_motivation_data(motivation_id: String) -> Dictionary:
	var filtered_motivations = motivations.filter(func(m): return m.id == motivation_id)
	if filtered_motivations.is_empty():
		print("No motivation found for id: ", motivation_id)
		return {}
	return filtered_motivations[0]

func get_class_data(class_id: String) -> Dictionary:
	var filtered_classes = classes.filter(func(c): return c.id == class_id)
	if filtered_classes.is_empty():
		print("No class found for id: ", class_id)
		return {}
	return filtered_classes[0]

func get_skill_data(skill_id: String) -> Dictionary:
	var filtered_skills = skills.filter(func(s): return s.id == skill_id)
	if filtered_skills.is_empty():
		print("No skill found for id: ", skill_id)
		return {}
	return filtered_skills[0]

func get_tutorial_race_data(race_id: String) -> Dictionary:
	return tutorial_races.filter(func(r): return r.id == race_id)[0]

func get_tutorial_background_data(background_id: String) -> Dictionary:
	return tutorial_backgrounds.filter(func(b): return b.id == background_id)[0]

func get_tutorial_motivation_data(motivation_id: String) -> Dictionary:
	return tutorial_motivations.filter(func(m): return m.id == motivation_id)[0]

func get_tutorial_class_data(class_id: String) -> Dictionary:
	return tutorial_classes.filter(func(c): return c.id == class_id)[0]

# Additional utility functions

func get_all_races() -> Array:
	return races

func get_all_backgrounds() -> Array:
	return backgrounds

func get_all_motivations() -> Array:
	return motivations

func get_all_classes() -> Array:
	return classes

func get_all_skills() -> Array:
	return skills

func get_all_tutorial_races() -> Array:
	return tutorial_races

func get_all_tutorial_backgrounds() -> Array:
	return tutorial_backgrounds

func get_all_tutorial_motivations() -> Array:
	return tutorial_motivations

func get_all_tutorial_classes() -> Array:
	return tutorial_classes

# ... (other existing methods remain unchanged)
