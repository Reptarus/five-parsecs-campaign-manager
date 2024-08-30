class_name CharacterCreationData
extends Resource

# Enums for character properties
enum Race { HUMAN, ENGINEER, KERIN, SOULLESS, PRECURSOR, FERAL, SWIFT, BOT }
enum Background { HIGH_TECH_COLONY, OVERCROWDED_CITY, LOW_TECH_COLONY, MINING_COLONY, MILITARY_BRAT, SPACE_STATION }
enum Motivation { WEALTH, FAME, GLORY, SURVIVAL, ESCAPE, ADVENTURE }
enum Class { WORKING_CLASS, TECHNICIAN, SCIENTIST, HACKER, SOLDIER, MERCENARY }

# Dictionary of race traits
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

# Dictionary of background stats
const BACKGROUND_STATS = {
	Background.HIGH_TECH_COLONY: {"savvy": 1, "credits": 6},
	Background.OVERCROWDED_CITY: {"speed": 1},
	Background.LOW_TECH_COLONY: {"low_tech_weapon": 1},
	Background.MINING_COLONY: {"toughness": 1},
	Background.MILITARY_BRAT: {"combat_skill": 1},
	Background.SPACE_STATION: {"gear": 1}
}

# Dictionary of motivation stats
const MOTIVATION_STATS = {
	Motivation.WEALTH: {"credits": 6},
	Motivation.FAME: {"story_point": 1},
	Motivation.GLORY: {"combat_skill": 1, "military_weapon": 1},
	Motivation.SURVIVAL: {"toughness": 1},
	Motivation.ESCAPE: {"speed": 1},
	Motivation.ADVENTURE: {"credits": 6, "low_tech_weapon": 1}
}

# Dictionary of class stats
const CLASS_STATS = {
	Class.WORKING_CLASS: {"savvy": 1, "luck": 1},
	Class.TECHNICIAN: {"savvy": 1, "gear": 1},
	Class.SCIENTIST: {"savvy": 1, "gadget": 1},
	Class.HACKER: {"savvy": 1, "rival": 1},
	Class.SOLDIER: {"combat_skill": 1, "credits": 6},
	Class.MERCENARY: {"combat_skill": 1, "military_weapon": 1}
}
# Names
const NAMES = [
	"Alice", "Bob", "Charlie", "Diana", "Ethan", "Fiona", "George", "Hannah",
	"Isaac", "Julia", "Kevin", "Laura", "Michael", "Natalie", "Oliver", "Penny"
]

# Returns the traits for a given race
static func get_race_traits(race: Race) -> Dictionary:
	return RACE_TRAITS.get(race, {})

# Returns the stats for a given background
static func get_background_stats(background: Background) -> Dictionary:
	return BACKGROUND_STATS.get(background, {})

# Returns the stats for a given motivation
static func get_motivation_stats(motivation: Motivation) -> Dictionary:
	return MOTIVATION_STATS.get(motivation, {})

# Returns the stats for a given class
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
			selected_skills[skill] = Skill.new(skill, Skill.SkillType.COMBAT if i < 2 else Skill.SkillType.GENERAL)
	
	return selected_skills

static func get_random_portrait() -> String:
	# Implement logic to select a random portrait
	return "res://assets/portraits/portrait_01.png"  # Placeholder
