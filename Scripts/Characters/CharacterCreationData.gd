class_name CharacterCreationData
extends Resource

var species: Array = [
	{"name": "Human", "id": GlobalEnums.Species.HUMAN, "effects": {"reactions": 1, "speed": 1}},
	{"name": "Engineer", "id": GlobalEnums.Species.ENGINEER, "effects": {"toughness": 1, "savvy": 1}},
	{"name": "Kerin", "id": GlobalEnums.Species.KERIN, "effects": {"speed": 1, "savvy": 1}},
	{"name": "Soulless", "id": GlobalEnums.Species.SOULLESS, "effects": {"toughness": 2}},
	{"name": "Precursor", "id": GlobalEnums.Species.PRECURSOR, "effects": {"savvy": 2}},
	{"name": "Feral", "id": GlobalEnums.Species.FERAL, "effects": {"reactions": 2}},
	{"name": "Swift", "id": GlobalEnums.Species.SWIFT, "effects": {"speed": 2}},
	{"name": "Bot", "id": GlobalEnums.Species.BOT, "effects": {"toughness": 1, "savvy": 1}},
	{"name": "Skulker", "id": GlobalEnums.Species.SKULKER, "effects": {"reactions": 1, "savvy": 1}},
	{"name": "Krag", "id": GlobalEnums.Species.KRAG, "effects": {"toughness": 2}}
]

var backgrounds: Array = [
	{"name": "High Tech Colony", "id": GlobalEnums.Background.HIGH_TECH_COLONY, "effects": {"combat_skill": 1}},
	{"name": "Overcrowded City", "id": GlobalEnums.Background.OVERCROWDED_CITY, "effects": {"savvy": 1}},
	{"name": "Low Tech Colony", "id": GlobalEnums.Background.LOW_TECH_COLONY, "effects": {"toughness": 1}},
	{"name": "Mining Colony", "id": GlobalEnums.Background.MINING_COLONY, "effects": {"combat_skill": 1}},
	{"name": "Military Brat", "id": GlobalEnums.Background.MILITARY_BRAT, "effects": {"combat_skill": 1, "reactions": 1}},
	{"name": "Space Station", "id": GlobalEnums.Background.SPACE_STATION, "effects": {"savvy": 1, "speed": 1}}
]

var motivations: Array = [
	{"name": "Wealth", "id": GlobalEnums.Motivation.WEALTH, "effects": {}},
	{"name": "Fame", "id": GlobalEnums.Motivation.FAME, "effects": {}},
	{"name": "Glory", "id": GlobalEnums.Motivation.GLORY, "effects": {}},
	{"name": "Survival", "id": GlobalEnums.Motivation.SURVIVAL, "effects": {}},
	{"name": "Escape", "id": GlobalEnums.Motivation.ESCAPE, "effects": {}},
	{"name": "Adventure", "id": GlobalEnums.Motivation.ADVENTURE, "effects": {}}
]

var classes: Array = [
	{"name": "Working Class", "id": GlobalEnums.Class.WORKING_CLASS, "abilities": ["Combat Mastery", "Tough as Nails"]},
	{"name": "Technician", "id": GlobalEnums.Class.TECHNICIAN, "abilities": ["Tech Savvy", "Jury Rig"]},
	{"name": "Scientist", "id": GlobalEnums.Class.SCIENTIST, "abilities": ["Quick Learner", "Analytical Mind"]},
	{"name": "Hacker", "id": GlobalEnums.Class.HACKER, "abilities": ["Cyber Infiltration", "Data Analysis"]},
	{"name": "Soldier", "id": GlobalEnums.Class.SOLDIER, "abilities": ["Tactical Training", "Weapon Specialist"]},
	{"name": "Mercenary", "id": GlobalEnums.Class.MERCENARY, "abilities": ["Adaptable", "Combat Veteran"]}
]

var skills: Array
var psionic_data: Dictionary

func load_data():
	var json_data = load_json_file("res://data/character_creation_data.json")
	if json_data.has("species"):
		species = json_data.species
	if json_data.has("backgrounds"):
		backgrounds = json_data.backgrounds
	if json_data.has("motivations"):
		motivations = json_data.motivations
	if json_data.has("classes"):
		classes = json_data.classes
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

func get_species_data(species_id: GlobalEnums.Species) -> Dictionary:
	return species.filter(func(s): return s.id == species_id)[0]

func get_background_data(background_id: int) -> Dictionary:
	var filtered_backgrounds = backgrounds.filter(func(b): return int(b.id) == background_id)
	if filtered_backgrounds.is_empty():
		print("No background found for id: ", background_id)
		return {}
	return filtered_backgrounds[0]

func get_motivation_data(motivation_id: int) -> Dictionary:
	var filtered_motivations = motivations.filter(func(m): return int(m.id) == motivation_id)
	if filtered_motivations.is_empty():
		print("No motivation found for id: ", motivation_id)
		return {}
	return filtered_motivations[0]

func get_class_data(class_id: int) -> Dictionary:
	var filtered_classes = classes.filter(func(c): return int(c.id) == class_id)
	if filtered_classes.is_empty():
		print("No class found for id: ", class_id)
		return {}
	return filtered_classes[0]

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

func get_psionic_power_data(power_id: String) -> Dictionary:
	return psionic_data.powers.filter(func(p): return p.id == power_id)[0]

func get_psionic_legality() -> GlobalEnums.PsionicLegality:
	return GlobalEnums.PsionicLegality[psionic_data.legality]
