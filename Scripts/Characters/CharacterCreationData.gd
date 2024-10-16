class_name CharacterCreationData
extends Resource

<<<<<<< HEAD
enum Race { HUMAN, ENGINEER, KERIN, SOULLESS, PRECURSOR, FERAL, SWIFT, BOT }
enum Background { HIGH_TECH_COLONY, OVERCROWDED_CITY, LOW_TECH_COLONY, MINING_COLONY, MILITARY_BRAT, SPACE_STATION }
enum Motivation { WEALTH, FAME, GLORY, SURVIVAL, ESCAPE, ADVENTURE }
enum Class { WORKING_CLASS, TECHNICIAN, SCIENTIST, HACKER, SOLDIER, MERCENARY }

const RACE_TRAITS = {
	Race.HUMAN: {},
	Race.ENGINEER: {
		"base_stats": {"toughness": -1, "savvy": 1},
		"repair_bonus": 1,
		"max_toughness": 4
	},
	Race.KERIN: {
		"base_stats": {"toughness": 1},
		"brawling_advantage": true,
		"must_engage_brawl": true
	},
	Race.SOULLESS: {
		"base_stats": {"toughness": 1, "savvy": 1},
		"armor_save": 6,
		"bot_injury_table": true,
		"no_consumables": true,
		"no_implants": true
	},
	Race.PRECURSOR: {
		"base_stats": {"speed": 1},
		"extra_character_event": true
	},
	Race.FERAL: {
		"base_stats": {},
		"ignore_initiative_penalties": true,
		"priority_reaction": true
	},
	Race.SWIFT: {
		"base_stats": {"speed": 1},
		"gliding": true,
		"free_jumping": true,
		"multi_shot_restriction": true
	},
	Race.BOT: {
		"base_stats": {"reactions": 1, "combat_skill": 1, "toughness": 1, "savvy": 2},
		"armor_save": 6,
		"bot_injury_table": true,
		"no_experience": true,
		"no_consumables": true,
		"no_implants": true,
		"no_character_events": true
	}
}

const STRANGE_CHARACTER_CHANCE: float = 0.1

const BACKGROUND_STATS = {
	Background.HIGH_TECH_COLONY: {"savvy": 1, "credits": 6},
	Background.OVERCROWDED_CITY: {"speed": 1},
	Background.LOW_TECH_COLONY: {"low_tech_weapon": 1},
	Background.MINING_COLONY: {"toughness": 1},
	Background.MILITARY_BRAT: {"combat_skill": 1},
	Background.SPACE_STATION: {"gear": 1}
}

const MOTIVATION_STATS = {
	Motivation.WEALTH: {"credits": 6},
	Motivation.FAME: {"story_point": 1},
	Motivation.GLORY: {"combat_skill": 1, "military_weapon": 1},
	Motivation.SURVIVAL: {"toughness": 1},
	Motivation.ESCAPE: {"speed": 1},
	Motivation.ADVENTURE: {"credits": 6, "low_tech_weapon": 1}
}

const CLASS_STATS = {
	Class.WORKING_CLASS: {"savvy": 1, "luck": 1},
	Class.TECHNICIAN: {"savvy": 1, "gear": 1},
	Class.SCIENTIST: {"savvy": 1, "gadget": 1},
	Class.HACKER: {"savvy": 1, "rival": 1},
	Class.SOLDIER: {"combat_skill": 1, "credits": 6},
	Class.MERCENARY: {"combat_skill": 1, "military_weapon": 1}
}

const NAMES = [
	"Alice", "Bob", "Charlie", "Diana", "Ethan", "Fiona", "George", "Hannah",
	"Isaac", "Julia", "Kevin", "Laura", "Michael", "Natalie", "Oliver", "Penny"
]

static func get_race_traits(race: Race) -> Dictionary:
	return RACE_TRAITS.get(race, {})

static func get_background_stats(background: Background) -> Dictionary:
	return BACKGROUND_STATS.get(background, {})

static func get_motivation_stats(motivation: Motivation) -> Dictionary:
	return MOTIVATION_STATS.get(motivation, {})

static func get_class_stats(character_class: Class) -> Dictionary:
	return CLASS_STATS.get(character_class, {})

static func get_random_name() -> String:
	return NAMES[randi() % NAMES.size()]

static func get_random_background() -> Background:
	return Background.values()[randi() % Background.size()]

static func get_random_race() -> Race:
	return Race.values()[randi() % Race.size()]

static func get_random_motivation() -> Motivation:
	return Motivation.values()[randi() % Motivation.size()]

static func get_random_class() -> Class:
	return Class.values()[randi() % Class.size()]

static func get_random_skills(count: int) -> Dictionary:
	var all_skills = ["Melee", "Ranged", "Magic", "Stealth", "Persuasion", "Survival"]
	var selected_skills = {}
	
	for i in range(count):
		if all_skills.size() > 0:
			var skill = all_skills.pop_at(randi() % all_skills.size())
			var new_skill = Skill.new()
			new_skill.initialize(skill, Skill.SkillType.COMBAT if i < 2 else Skill.SkillType.GENERAL)
			selected_skills[skill] = new_skill
=======
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
>>>>>>> parent of 1efa334 (worldphase functionality)
	
	return selected_skills

static func generate_random_character() -> Character:
	var character = Character.new()
	character.name = get_random_name()
	character.race = get_random_race()
	character.background = get_random_background()
	character.motivation = get_random_motivation()
	character.character_class = get_random_class()
	character.skills = get_random_skills(3)
	character.portrait = get_random_portrait()

	apply_race_traits(character)

	if randf() < STRANGE_CHARACTER_CHANCE:
		apply_strange_abilities(character)

	return character

static func apply_race_traits(character: Character) -> void:
	var race_traits = RACE_TRAITS[character.race]
	if "base_stats" in race_traits:
		for stat in race_traits["base_stats"]:
			var value = race_traits["base_stats"][stat]
			character.set(stat, character.get(stat) + value)
	
	match character.race:
		Race.ENGINEER:
			var repair_skill = Skill.new()
			repair_skill.initialize("Repair", Skill.SkillType.GENERAL)
			character.skills["Repair"] = repair_skill
		Race.KERIN:
			character.add_ability("Brawling Advantage")
		Race.SOULLESS:
			character.add_ability("Armor Save 6+")
		Race.PRECURSOR:
			character.add_ability("Extra Character Event")
		Race.FERAL:
			character.add_ability("Ignore Initiative Penalties")
			character.add_ability("Priority Reaction")
		Race.SWIFT:
			character.add_ability("Gliding")
			character.add_ability("Free Jumping")
		Race.BOT:
			character.add_ability("Armor Save 6+")
			character.add_ability("No Experience Gain")

<<<<<<< HEAD
static func apply_strange_abilities(character: Character) -> void:
	var strange_type = StrangeCharacters.StrangeCharacterType.values()[randi() % StrangeCharacters.StrangeCharacterType.size()]
	character.strange_character = StrangeCharacters.new()
	character.strange_character.initialize(strange_type)
	character.strange_character.apply_special_abilities(character)

static func get_random_portrait() -> String:
	return "res://assets/portraits/portrait_01.png"
=======
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
>>>>>>> parent of 1efa334 (worldphase functionality)
