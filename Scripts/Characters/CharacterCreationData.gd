class_name CharacterCreationData
extends Resource

var races: Array
var backgrounds: Array
var motivations: Array
var classes: Array
var skills: Array
var psionic_data: Dictionary

func load_data():
	var json_data = load_json_file("res://data/character_creation_data.json")
	races = json_data.races
	backgrounds = json_data.backgrounds
	motivations = json_data.motivations
	classes = json_data.classes
	skills = json_data.skills
	load_psionic_data()

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
	return backgrounds.filter(func(b): return b.id == background_id)[0]

func get_motivation_data(motivation_id: String) -> Dictionary:
	return motivations.filter(func(m): return m.id == motivation_id)[0]

func get_class_data(class_id: String) -> Dictionary:
	return classes.filter(func(c): return c.id == class_id)[0]

func get_skill_data(skill_id: String) -> Dictionary:
	return skills.filter(func(s): return s.id == skill_id)[0]

func load_psionic_data():
	var file = FileAccess.open("res://data/RulesReference/Psionics.json", FileAccess.READ)
	if file:
		var json = JSON.new()
		var error = json.parse(file.get_as_text())
		file.close()
		if error == OK:
			psionic_data = json.data
		else:
			print("Error parsing Psionics.json")
