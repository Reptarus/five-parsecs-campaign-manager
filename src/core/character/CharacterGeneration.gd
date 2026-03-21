@tool
extends RefCounted
class_name FiveParsecsCharacterGeneration

## Five Parsecs Character Generation System
##
## Implements character creation following Five Parsecs From Home Core Rules
## - Attribute generation using 2D6 / 3.0 rounded up formula
## - Character class and background system
## - Five Parsecs specific traits and equipment
## - Hybrid approach: Type-safe enums + Rich JSON data

# GlobalEnums available as autoload singleton
const GlobalEnums = preload("res://src/core/systems/GlobalEnums.gd")
const UniversalResourceLoader = preload("res://src/core/systems/UniversalResourceLoader.gd")
# DataManager accessed via autoload singleton (not preload)
const SafeDataAccess = preload("res://src/utils/SafeDataAccess.gd")
const HouseRulesHelper = preload("res://src/core/systems/HouseRulesHelper.gd")

# Data-driven character creation tables
static var _character_data: Dictionary = {}
static var _backgrounds_data: Dictionary = {}
static var _skills_data: Dictionary = {}
static var _is_data_loaded: bool = false

## D100 Background Table (Core Rules p.24)
## Each entry: {name, effect, stat_bonus, credits_dice, story_points, patron, rumors, starting_rolls}
static var BACKGROUND_TABLE: Array = [
	# 1-4: Peaceful, High-Tech Colony
	{"roll_min": 1, "roll_max": 4, "name": "Peaceful, High-Tech Colony", "stat_bonus": {"savvy": 1}, "credits_dice": 1},
	# 5-9: Giant, Overcrowded, Dystopian City
	{"roll_min": 5, "roll_max": 9, "name": "Giant, Overcrowded, Dystopian City", "stat_bonus": {"speed": 1}},
	# 10-13: Low-Tech Colony
	{"roll_min": 10, "roll_max": 13, "name": "Low-Tech Colony", "starting_rolls": ["low_tech_weapon"]},
	# 14-17: Mining Colony
	{"roll_min": 14, "roll_max": 17, "name": "Mining Colony", "stat_bonus": {"toughness": 1}},
	# 18-21: Military Brat
	{"roll_min": 18, "roll_max": 21, "name": "Military Brat", "stat_bonus": {"combat": 1}},
	# 22-25: Space Station
	{"roll_min": 22, "roll_max": 25, "name": "Space Station", "starting_rolls": ["gear"]},
	# 26-29: Military Outpost
	{"roll_min": 26, "roll_max": 29, "name": "Military Outpost", "stat_bonus": {"reactions": 1}},
	# 30-34: Drifter
	{"roll_min": 30, "roll_max": 34, "name": "Drifter", "starting_rolls": ["gear"]},
	# 35-39: Lower Megacity Class
	{"roll_min": 35, "roll_max": 39, "name": "Lower Megacity Class", "starting_rolls": ["low_tech_weapon"]},
	# 40-42: Wealthy Merchant Family
	{"roll_min": 40, "roll_max": 42, "name": "Wealthy Merchant Family", "credits_dice": 2},
	# 43-46: Frontier Gang
	{"roll_min": 43, "roll_max": 46, "name": "Frontier Gang", "stat_bonus": {"combat": 1}},
	# 47-49: Religious Cult - PATRON + STORY POINT
	{"roll_min": 47, "roll_max": 49, "name": "Religious Cult", "patron": 1, "story_points": 1},
	# 50-52: War-Torn Hell-Hole
	{"roll_min": 50, "roll_max": 52, "name": "War-Torn Hell-Hole", "stat_bonus": {"reactions": 1}, "starting_rolls": ["military_weapon"]},
	# 53-55: Tech Guild
	{"roll_min": 53, "roll_max": 55, "name": "Tech Guild", "stat_bonus": {"savvy": 1}, "credits_dice": 1, "starting_rolls": ["high_tech_weapon"]},
	# 56-59: Subjugated Colony on Alien World
	{"roll_min": 56, "roll_max": 59, "name": "Subjugated Colony on Alien World", "starting_rolls": ["gadget"]},
	# 60-64: Long-Term Space Mission
	{"roll_min": 60, "roll_max": 64, "name": "Long-Term Space Mission", "stat_bonus": {"savvy": 1}},
	# 65-68: Research Outpost
	{"roll_min": 65, "roll_max": 68, "name": "Research Outpost", "stat_bonus": {"savvy": 1}, "starting_rolls": ["gadget"]},
	# 69-72: Primitive or Regressed World
	{"roll_min": 69, "roll_max": 72, "name": "Primitive or Regressed World", "stat_bonus": {"toughness": 1}, "starting_rolls": ["low_tech_weapon"]},
	# 73-76: Orphan Utility Program - PATRON + STORY POINT
	{"roll_min": 73, "roll_max": 76, "name": "Orphan Utility Program", "patron": 1, "story_points": 1},
	# 77-80: Isolationist Enclave - 2 QUEST RUMORS
	{"roll_min": 77, "roll_max": 80, "name": "Isolationist Enclave", "rumors": 2},
	# 81-84: Comfortable Megacity Class
	{"roll_min": 81, "roll_max": 84, "name": "Comfortable Megacity Class", "credits_dice": 1},
	# 85-89: Industrial World
	{"roll_min": 85, "roll_max": 89, "name": "Industrial World", "starting_rolls": ["gear"]},
	# 90-93: Bureaucrat
	{"roll_min": 90, "roll_max": 93, "name": "Bureaucrat", "credits_dice": 1},
	# 94-97: Wasteland Nomads
	{"roll_min": 94, "roll_max": 97, "name": "Wasteland Nomads", "stat_bonus": {"reactions": 1}, "starting_rolls": ["low_tech_weapon"]},
	# 98-100: Alien Culture
	{"roll_min": 98, "roll_max": 100, "name": "Alien Culture", "starting_rolls": ["high_tech_weapon"]}
]

## D100 Motivation Table (Core Rules p.25)
static var MOTIVATION_TABLE: Array = [
	# 1-8: Wealth
	{"roll_min": 1, "roll_max": 8, "name": "Wealth", "credits_dice": 1},
	# 9-14: Fame
	{"roll_min": 9, "roll_max": 14, "name": "Fame", "story_points": 1},
	# 15-19: Glory
	{"roll_min": 15, "roll_max": 19, "name": "Glory", "stat_bonus": {"combat": 1}, "starting_rolls": ["military_weapon"]},
	# 20-26: Survival
	{"roll_min": 20, "roll_max": 26, "name": "Survival", "stat_bonus": {"toughness": 1}},
	# 27-32: Escape
	{"roll_min": 27, "roll_max": 32, "name": "Escape", "stat_bonus": {"speed": 1}},
	# 33-39: Adventure
	{"roll_min": 33, "roll_max": 39, "name": "Adventure", "credits_dice": 1, "starting_rolls": ["low_tech_weapon"]},
	# 40-44: Truth - RUMOR + STORY POINT
	{"roll_min": 40, "roll_max": 44, "name": "Truth", "rumors": 1, "story_points": 1},
	# 45-49: Technology
	{"roll_min": 45, "roll_max": 49, "name": "Technology", "stat_bonus": {"savvy": 1}, "starting_rolls": ["gadget"]},
	# 50-56: Discovery
	{"roll_min": 50, "roll_max": 56, "name": "Discovery", "stat_bonus": {"savvy": 1}, "starting_rolls": ["gear"]},
	# 57-63: Loyalty - PATRON + STORY POINT
	{"roll_min": 57, "roll_max": 63, "name": "Loyalty", "patron": 1, "story_points": 1},
	# 64-69: Revenge - RIVAL + XP
	{"roll_min": 64, "roll_max": 69, "name": "Revenge", "rival": 1, "xp": 2},
	# 70-74: Romance - RUMOR + STORY POINT
	{"roll_min": 70, "roll_max": 74, "name": "Romance", "rumors": 1, "story_points": 1},
	# 75-79: Faith - RUMOR + STORY POINT
	{"roll_min": 75, "roll_max": 79, "name": "Faith", "rumors": 1, "story_points": 1},
	# 80-84: Political - PATRON + STORY POINT
	{"roll_min": 80, "roll_max": 84, "name": "Political", "patron": 1, "story_points": 1},
	# 85-90: Power - RIVAL + XP
	{"roll_min": 85, "roll_max": 90, "name": "Power", "rival": 1, "xp": 2},
	# 91-95: Order - PATRON + STORY POINT
	{"roll_min": 91, "roll_max": 95, "name": "Order", "patron": 1, "story_points": 1},
	# 96-100: Freedom
	{"roll_min": 96, "roll_max": 100, "name": "Freedom", "xp": 2}
]

## D100 Class Table (Core Rules p.26)
static var CLASS_TABLE: Array = [
	# 1-5: Working Class
	{"roll_min": 1, "roll_max": 5, "name": "Working Class", "stat_bonus": {"savvy": 1, "luck": 1}},
	# 6-9: Technician
	{"roll_min": 6, "roll_max": 9, "name": "Technician", "stat_bonus": {"savvy": 1}, "starting_rolls": ["gear"]},
	# 10-13: Scientist
	{"roll_min": 10, "roll_max": 13, "name": "Scientist", "stat_bonus": {"savvy": 1}, "starting_rolls": ["gadget"]},
	# 14-17: Hacker - RIVAL
	{"roll_min": 14, "roll_max": 17, "name": "Hacker", "stat_bonus": {"savvy": 1}, "rival": 1},
	# 18-22: Soldier
	{"roll_min": 18, "roll_max": 22, "name": "Soldier", "stat_bonus": {"combat": 1}, "credits_dice": 1},
	# 23-27: Mercenary
	{"roll_min": 23, "roll_max": 27, "name": "Mercenary", "stat_bonus": {"combat": 1}, "starting_rolls": ["military_weapon"]},
	# 28-32: Agitator - RIVAL
	{"roll_min": 28, "roll_max": 32, "name": "Agitator", "rival": 1},
	# 33-36: Primitive
	{"roll_min": 33, "roll_max": 36, "name": "Primitive", "stat_bonus": {"speed": 1}, "starting_rolls": ["low_tech_weapon"]},
	# 37-40: Artist
	{"roll_min": 37, "roll_max": 40, "name": "Artist", "credits_dice": 1},
	# 41-44: Negotiator - PATRON + STORY POINT
	{"roll_min": 41, "roll_max": 44, "name": "Negotiator", "patron": 1, "story_points": 1},
	# 45-49: Trader
	{"roll_min": 45, "roll_max": 49, "name": "Trader", "credits_dice": 2},
	# 50-54: Starship Crew
	{"roll_min": 50, "roll_max": 54, "name": "Starship Crew", "stat_bonus": {"savvy": 1}},
	# 55-58: Petty Criminal
	{"roll_min": 55, "roll_max": 58, "name": "Petty Criminal", "stat_bonus": {"speed": 1}},
	# 59-63: Ganger
	{"roll_min": 59, "roll_max": 63, "name": "Ganger", "stat_bonus": {"reactions": 1}, "starting_rolls": ["low_tech_weapon"]},
	# 64-67: Scoundrel
	{"roll_min": 64, "roll_max": 67, "name": "Scoundrel", "stat_bonus": {"speed": 1}},
	# 68-71: Enforcer - PATRON
	{"roll_min": 68, "roll_max": 71, "name": "Enforcer", "stat_bonus": {"combat": 1}, "patron": 1},
	# 72-75: Special Agent - PATRON + GADGET
	{"roll_min": 72, "roll_max": 75, "name": "Special Agent", "stat_bonus": {"reactions": 1}, "patron": 1, "starting_rolls": ["gadget"]},
	# 76-79: Troubleshooter
	{"roll_min": 76, "roll_max": 79, "name": "Troubleshooter", "stat_bonus": {"reactions": 1}, "starting_rolls": ["low_tech_weapon"]},
	# 80-83: Bounty Hunter - RUMOR + LOW-TECH WEAPON
	{"roll_min": 80, "roll_max": 83, "name": "Bounty Hunter", "stat_bonus": {"speed": 1}, "rumors": 1, "starting_rolls": ["low_tech_weapon"]},
	# 84-88: Nomad
	{"roll_min": 84, "roll_max": 88, "name": "Nomad", "starting_rolls": ["gear"]},
	# 89-92: Explorer
	{"roll_min": 89, "roll_max": 92, "name": "Explorer", "xp": 2, "starting_rolls": ["gear"]},
	# 93-96: Punk - RIVAL + XP
	{"roll_min": 93, "roll_max": 96, "name": "Punk", "rival": 1, "xp": 2},
	# 97-100: Scavenger - RUMOR + HIGH-TECH WEAPON
	{"roll_min": 97, "roll_max": 100, "name": "Scavenger", "rumors": 1, "starting_rolls": ["high_tech_weapon"]}
]

## Roll on a D100 table and return the matching entry
static func _roll_on_table(table: Array) -> Dictionary:
	var roll = randi_range(1, 100)
	for entry in table:
		if roll >= entry.roll_min and roll <= entry.roll_max:
			var result = entry.duplicate(true)
			result["roll"] = roll
			return result
	# Fallback to first entry if no match (shouldn't happen)
	var fallback = table[0].duplicate(true)
	fallback["roll"] = roll
	return fallback

## Roll on all three character creation tables and aggregate resources
## Returns: {background_result, motivation_result, class_result, resources}
static func roll_character_tables() -> Dictionary:
	var bg_result = _roll_on_table(BACKGROUND_TABLE)
	var mot_result = _roll_on_table(MOTIVATION_TABLE)
	var class_result = _roll_on_table(CLASS_TABLE)

	# Aggregate resources from all three tables
	var resources = {
		"patrons": 0,
		"rivals": 0,
		"rumors": 0,
		"story_points": 0,
		"credits_dice": 0, # Number of D6 to roll for credits
		"xp": 0,
		"starting_rolls": [] # Equipment rolls to make
	}

	# Sum up all resources
	for result in [bg_result, mot_result, class_result]:
		resources.patrons += result.get("patron", 0)
		resources.rivals += result.get("rival", 0)
		resources.rumors += result.get("rumors", 0)
		resources.story_points += result.get("story_points", 0)
		resources.credits_dice += result.get("credits_dice", 0)
		resources.xp += result.get("xp", 0)
		resources.starting_rolls.append_array(result.get("starting_rolls", []))

	# Roll for bonus credits
	var bonus_credits = 0
	for i in resources.credits_dice:
		bonus_credits += randi_range(1, 6)
	resources["bonus_credits"] = bonus_credits

	return {
		"background_result": bg_result,
		"motivation_result": mot_result,
		"class_result": class_result,
		"resources": resources
	}

## Apply table results to a character (stat bonuses and traits)
static func apply_table_results_to_character(character: Character, table_results: Dictionary) -> void:
	# Apply stat bonuses from all three tables
	for result_key in ["background_result", "motivation_result", "class_result"]:
		var result = table_results.get(result_key, {})
		var stat_bonuses = result.get("stat_bonus", {})

		for stat_name in stat_bonuses:
			var bonus = stat_bonuses[stat_name]
			match stat_name:
				"combat":
					character.combat = clampi(character.combat + bonus, 0, 5)
				"reactions":
					character.reactions = clampi(character.reactions + bonus, 1, 6)
				"toughness":
					character.toughness = clampi(character.toughness + bonus, 1, 6)
				"speed":
					character.speed = clampi(character.speed + bonus, 4, 8)
				"savvy":
					character.savvy = clampi(character.savvy + bonus, 0, 5)
				"luck":
					character.luck = clampi(character.luck + bonus, 0, 3)

		# Add trait for the table result
		var result_name = result.get("name", "")
		if result_name != "":
			match result_key:
				"background_result":
					character.add_trait("Background: " + result_name)
				"motivation_result":
					character.add_trait("Motivation: " + result_name)
				"class_result":
					character.add_trait("Class: " + result_name)

	# Apply XP bonus (unless rookie_crew house rule is enabled)
	var resources = table_results.get("resources", {})
	var xp_bonus = resources.get("xp", 0)

	# HOUSE RULE: rookie_crew - Starting crew begins with 0 XP
	if HouseRulesHelper.is_enabled("rookie_crew"):
		character.experience_points = 0
	elif xp_bonus > 0:
		character.experience_points += xp_bonus

	# Apply bonus credits
	var bonus_credits = resources.get("bonus_credits", 0)
	if bonus_credits > 0:
		character.credits_earned += bonus_credits

	# Store table results on character for later reference
	character.set_meta("creation_table_results", table_results)
	character.set_meta("creation_resources", resources)

	pass # Table results and resources applied

## Aggregate resources from all crew members and apply to campaign
static func finalize_crew_resources(characters: Array, campaign) -> Dictionary:
	var total_resources = {
		"patrons": 0,
		"rivals": 0,
		"rumors": 0,
		"story_points": 0,
		"xp": 0,
		"credits": 0
	}

	# Sum resources from all characters
	for character in characters:
		var char_resources = character.get_meta("creation_resources", {})
		total_resources.patrons += char_resources.get("patrons", 0)
		total_resources.rivals += char_resources.get("rivals", 0)
		total_resources.rumors += char_resources.get("rumors", 0)
		total_resources.story_points += char_resources.get("story_points", 0)
		total_resources.xp += char_resources.get("xp", 0)
		total_resources.credits += char_resources.get("bonus_credits", 0)

	if not campaign:
		return total_resources

	# Apply to campaign
	# Generate patron entities
	for i in total_resources.patrons:
		var patron = _create_starting_patron(i)
		if campaign is Resource and "patrons" in campaign:
			campaign.patrons.append(patron)
		elif campaign is Dictionary:
			if not campaign.has("patrons"):
				campaign["patrons"] = []
			campaign["patrons"].append(patron)
		pass # Starting patron created

	# Generate rival entities
	for i in total_resources.rivals:
		var rival = _create_starting_rival(i)
		if campaign is Resource and "rivals" in campaign:
			campaign.rivals.append(rival)
		elif campaign is Dictionary:
			if not campaign.has("rivals"):
				campaign["rivals"] = []
			campaign["rivals"].append(rival)
		pass # Starting rival created

	# Add quest rumors
	if campaign is Resource and "quest_rumors" in campaign:
		campaign.quest_rumors += total_resources.rumors
	elif campaign is Dictionary:
		campaign["quest_rumors"] = campaign.get("quest_rumors", 0) + total_resources.rumors

	# Add story points and credits via GameStateManager (SSOT pattern)
	var gsm = Engine.get_main_loop().root.get_node_or_null("/root/GameStateManager") if Engine.get_main_loop() else null
	if gsm:
		# Use GameStateManager for credits (single source of truth)
		if gsm.has_method("add_credits") and total_resources.credits > 0:
			gsm.add_credits(total_resources.credits)
		elif gsm.has_method("set_credits") and total_resources.credits > 0:
			gsm.set_credits(gsm.get_credits() + total_resources.credits)

		# Use GameStateManager for story points if available
		if gsm.has_method("add_story_points") and total_resources.story_points > 0:
			gsm.add_story_points(total_resources.story_points)
		elif gsm.has_method("set_story_progress") and total_resources.story_points > 0:
			var current = gsm.get_story_progress() if gsm.has_method("get_story_progress") else 0
			gsm.set_story_progress(current + total_resources.story_points)
	else:
		# Fallback: Direct campaign modification (legacy support)
		if campaign is Resource and "story_points" in campaign:
			campaign.story_points += total_resources.story_points
		elif campaign is Dictionary:
			campaign["story_points"] = campaign.get("story_points", 0) + total_resources.story_points

		if campaign is Resource and "credits" in campaign:
			campaign.credits += total_resources.credits
		elif campaign is Dictionary:
			campaign["credits"] = campaign.get("credits", 0) + total_resources.credits

	pass # Crew resources finalized

	return total_resources

## Create a starting patron from character creation
static func _create_starting_patron(index: int) -> Dictionary:
	var patron_types = ["Corporate", "Government", "Criminal", "Military", "Trade Guild", "Religious Order"]
	var patron_names = ["Director Chen", "Commissioner Vale", "Boss Krynn", "Colonel Drake", "Merchant Lord Vex", "High Priest Zara"]

	return {
		"id": "starting_patron_%d_%d" % [Time.get_unix_time_from_system(), index],
		"name": patron_names[index % patron_names.size()],
		"type": patron_types[index % patron_types.size()],
		"reputation": 0,
		"jobs_completed": 0,
		"jobs_failed": 0,
		"is_starting_patron": true
	}

## Create a starting rival from character creation
static func _create_starting_rival(index: int) -> Dictionary:
	var rival_types = ["Gang", "Corporate", "Criminal", "Personal Enemy", "Mercenary Band"]
	var rival_names = ["The Red Fang", "Nexus Corp Enforcers", "Shadow Syndicate", "Vendetta Hunter", "Steel Dogs"]

	return {
		"id": "starting_rival_%d_%d" % [Time.get_unix_time_from_system(), index],
		"name": rival_names[index % rival_names.size()],
		"type": rival_types[index % rival_types.size()],
		"strength": 1,
		"hostility": 5,
		"is_starting_rival": true
	}

## Load all necessary JSON data for character creation
static func _load_character_data() -> void:
	if _is_data_loaded:
		return

	# Use DataManager for consistent data loading
	if DataManager.is_system_ready():
		_character_data = DataManager.export_character_data()
		_is_data_loaded = true
		return

	# Fallback to direct loading if DataManager not available
	_character_data = UniversalResourceLoader.load_json_safe("res://data/character_creation_data.json", "Character Creation Data")
	_backgrounds_data = UniversalResourceLoader.load_json_safe("res://data/character_backgrounds.json", "Character Backgrounds")
	_skills_data = UniversalResourceLoader.load_json_safe("res://data/character_skills.json", "Character Skills")
	
	_is_data_loaded = true

## Generate Five Parsecs attribute using official 2D6 / 3.0 formula
static func generate_attribute() -> int:
	var roll := randi_range(2, 12) # 2D6
	return ceili(float(roll) / 3.0) # Divide by 3, round up

## Generate d66 for tables (two d6 read as tens and ones)
static func roll_d66() -> int:
	var tens := randi_range(1, 6)
	var ones := randi_range(1, 6)
	return tens * 10 + ones

## Generate d10 for combat resolution
static func roll_d10() -> int:
	return randi_range(1, 10)

## Create a complete Five Parsecs character following official rules
static func create_character(config: Dictionary = {}) -> Character:
	_load_character_data()
	
	# Validate config parameter type
	if not config is Dictionary:
		push_error("CharacterGeneration: config parameter must be a Dictionary, got %s. Using empty config." % typeof(config))
		config = {}
	
	# Debug: Check if Character class is available
	if not Character:
		push_error("CharacterGeneration: Character class not available")
		return null
	
	# Try to create the character with better error handling
	var character: Character
	character = Character.new()
	if not character:
		push_error("CharacterGeneration: Character.new() returned null")
		return null
	

	# Basic identity from config or defaults
	var config_dict = SafeDataAccess.safe_dict_access(config, "character name configuration")
	character.character_name = SafeDataAccess.safe_get(config_dict, "name", "New Character", "character name lookup")
	
	# Handle class assignment - accept both String and int values
	var class_value = SafeDataAccess.safe_get(config_dict, "class", "SOLDIER", "character class lookup")
	if class_value is String:
		var p_class_name: String = class_value
		if p_class_name in GlobalEnums.CharacterClass:
			character.character_class = p_class_name
		else:
			character.character_class = "SOLDIER"
	elif class_value is int:
		character.character_class = GlobalEnums.to_string_value("character_class", class_value)
	else:
		character.character_class = "SOLDIER"
	
	# Handle background assignment - accept both String and int values
	var background_value = SafeDataAccess.safe_get(config_dict, "background", "MILITARY", "character background lookup")
	if background_value is String:
		var p_background_name: String = background_value
		if p_background_name in GlobalEnums.Background:
			character.background = p_background_name
		else:
			character.background = "MILITARY"
	elif background_value is int:
		character.background = background_value
	else:
		character.background = "MILITARY"
	
	# Handle motivation assignment - accept both String and int values  
	var motivation_value = SafeDataAccess.safe_get(config_dict, "motivation", "SURVIVAL", "character motivation lookup")
	if motivation_value is String:
		if motivation_value in GlobalEnums.Motivation:
			character.motivation = motivation_value
		else:
			character.motivation = "SURVIVAL"
	elif motivation_value is int:
		character.motivation = motivation_value
	else:
		character.motivation = "SURVIVAL"
	
	# Handle origin assignment - accept both String and int values
	var origin_value = SafeDataAccess.safe_get(config_dict, "origin", "HUMAN", "character origin lookup")
	if origin_value is String:
		if origin_value in GlobalEnums.Origin:
			character.origin = origin_value
		else:
			character.origin = "HUMAN"
	elif origin_value is int:
		var global_enums = Engine.get_singleton("GlobalEnums")
		character.origin = global_enums.to_string_value("origin", origin_value) if global_enums else "HUMAN"
	else:
		character.origin = "HUMAN"

	# Generate attributes
	generate_character_attributes(character)

	# Set health
	character.max_health = character.toughness + 2
	character.health = character.max_health

	# Apply bonuses from data
	apply_background_bonuses(character)
	apply_class_bonuses(character)

	# Generate starting equipment
	generate_starting_equipment(character)

	# Set character flags based on origin
	set_character_flags(character)

	return character

## Generate all character attributes using Five Parsecs rules
static func generate_character_attributes(character: Character) -> void:
	# Core Five Parsecs attributes (2D6 / 3.0 rounded up)
	character.reactions = generate_attribute() # Base 1, Max 6
	character.speed = generate_attribute() + 2 # Base 4", Max 8"
	character.combat = generate_attribute() - 1 # Base +0, Max +3
	character.toughness = generate_attribute() # Base 3, Max 6
	character.savvy = generate_attribute() - 1 # Base +0, Max +3

	# Clamp values to Five Parsecs ranges
	character.reactions = clampi(character.reactions, 1, 6)
	character.speed = clampi(character.speed, 4, 8)
	character.combat = clampi(character.combat, 0, 3)
	character.toughness = clampi(character.toughness, 3, 6)
	character.savvy = clampi(character.savvy, 0, 3)

	# Luck starts at 0 (humans can have up to 3)
	character.luck = 0
	
	# Set health according to Five Parsecs rules (toughness + 2)
	character.max_health = character.toughness + 2
	character.health = character.max_health

	pass # Character attributes generated

## Apply background-specific bonuses from loaded data with safe enum access
static func apply_background_bonuses(character: Character) -> void:
	# Validate background string value before using it
	if not character.background in GlobalEnums.Background:
		push_error("CharacterGeneration: Invalid background string value: %s. Using MILITARY as fallback." % character.background)
		character.background = "MILITARY"
	
	# Try to get background data from DataManager first
	var background_data = _get_background_data_for_character(character)
	if not background_data.is_empty():
		_apply_background_data_bonuses(character, background_data)
	else:
		# Fallback to enum-based bonuses
		_apply_enum_background_bonuses(character)

## Enhanced background data application using rich JSON
static func _apply_background_data_bonuses(character: Character, background_data: Dictionary) -> void:
	# Apply stat bonuses from JSON
	var background_dict = SafeDataAccess.safe_dict_access(background_data, "background data validation")
	var stat_bonuses = SafeDataAccess.safe_get(background_dict, "stat_bonuses", {}, "background stat bonuses lookup")
	if stat_bonuses is Dictionary:
		for stat_name in stat_bonuses.keys():
			var bonus = stat_bonuses[stat_name]
			_apply_stat_bonus(character, stat_name, bonus)
	
	# Apply stat penalties
	var stat_penalties = SafeDataAccess.safe_get(background_dict, "stat_penalties", {}, "background stat penalties lookup")
	if stat_penalties is Dictionary:
		for stat_name in stat_penalties.keys():
			var penalty = stat_penalties[stat_name]
			_apply_stat_bonus(character, stat_name, penalty) # Penalty is negative bonus
	
	# Add starting skills as traits
	var starting_skills = SafeDataAccess.safe_get(background_dict, "starting_skills", [], "background starting skills lookup")
	if starting_skills is Array:
		for skill in starting_skills:
			character.add_trait("Skill: " + skill)
	
	# Add special abilities as traits
	var special_abilities = SafeDataAccess.safe_get(background_dict, "special_abilities", [], "background special abilities lookup")
	if special_abilities is Array:
		for ability in special_abilities:
			if ability is Dictionary:
				var ability_dict = SafeDataAccess.safe_dict_access(ability, "special ability validation")
				var ability_name = SafeDataAccess.safe_get(ability_dict, "name", "Unknown Ability", "ability name lookup")
				var ability_desc = ability.get("description", "")
				character.add_trait("Ability: %s - %s" % [ability_name, ability_desc])
	
	pass # Background bonuses applied

## Safe stat bonus application
static func _apply_stat_bonus(character: Character, stat_name: String, bonus: int) -> void:
	match stat_name.to_lower():
		"combat", "combat_skill":
			character.combat = clampi(character.combat + bonus, 0, 5)
		"reactions", "reaction":
			character.reactions = clampi(character.reactions + bonus, 1, 6)
		"toughness":
			character.toughness = clampi(character.toughness + bonus, 1, 6)
		"speed":
			character.speed = clampi(character.speed + bonus, 4, 8)
		"savvy":
			character.savvy = clampi(character.savvy + bonus, 0, 5)
		_:
			push_warning("CharacterGeneration: Unknown stat '%s' for bonus application" % stat_name)

## Get background data for character using hybrid approach
static func _get_background_data_for_character(character: Character) -> Dictionary:
	# Try DataManager first
	if DataManager.is_system_ready():
		var background_id = _get_background_id_from_string(character.background)
		return DataManager.get_background_data(background_id)
	
	# Fallback to local data
	var background_name = character.background
	if _backgrounds_data.has(background_name):
		return _backgrounds_data[background_name]
	
	return {}

## Convert background string to JSON background ID
static func _get_background_id_from_string(background_string: String) -> String:
	match background_string:
		"MILITARY": return "military"
		"CRIMINAL": return "criminal"
		"ACADEMIC": return "scientist"
		"MERCENARY": return "mercenary"
		"COLONIST": return "colonist"
		"EXPLORER": return "pilot"
		"TRADER": return "corporate"
		"OUTCAST": return "drifter"
		_: return "drifter" # Safe default

## Fallback enum-based background bonuses
static func _apply_enum_background_bonuses(character: Character) -> void:
	var background_name = character.background
	if _backgrounds_data.has(background_name):
		var bg_data = _backgrounds_data[background_name]
		
		# Ensure bg_data is a Dictionary before calling .get()
		if not bg_data is Dictionary:
			push_warning("CharacterGeneration: Expected Dictionary for background data, got %s" % typeof(bg_data))
			return
		
		var stat_bonuses = bg_data.get("stat_bonuses", {})
		if stat_bonuses is Dictionary:
			for key in stat_bonuses:
				character.set(key, character.get(key) + stat_bonuses[key])
		
		var features = bg_data.get("traits", [])
		if features is Array:
			for feature in features:
				character.add_trait(feature)

## Apply class-specific bonuses
static func apply_class_bonuses(character: Character) -> void:
	match character.character_class:
		"SOLDIER":
			character.combat = clampi(character.combat + 1, 0, 5)
			character.add_trait("Military Training")
		"SCOUT":
			character.speed = clampi(character.speed + 1, 4, 8)
			character.add_trait("Scout Training")
		"MEDIC":
			character.savvy = clampi(character.savvy + 1, 0, 5)
			character.add_trait("Medical Training")
		"ENGINEER":
			# Engineers can't exceed T4 in Savvy (Five Parsecs p.18)
			var engineer_max_savvy = 4 if character.character_class.to_lower() == "engineer" else 5
			character.savvy = clampi(character.savvy + 1, 0, engineer_max_savvy)
			character.add_trait("Engineering Training")
		"PILOT":
			character.reactions = clampi(character.reactions + 1, 1, 6)
			character.add_trait("Pilot Training")
		"MERCHANT":
			character.savvy = clampi(character.savvy + 1, 0, 5)
			character.add_trait("Merchant Training")
		"SECURITY":
			character.combat = clampi(character.combat + 1, 0, 5)
			character.add_trait("Security Training")
		"BROKER":
			character.savvy = clampi(character.savvy + 1, 0, 5)
			character.add_trait("Broker Training")

## Generate starting equipment using hybrid approach
static func generate_starting_equipment(character: Character) -> void:
	# Get equipment from both origin and background
	var origin_equipment = _get_starting_equipment_data(character)
	var background_equipment = _get_background_equipment_data(character)
	
	# Merge equipment from both sources
	var combined_equipment = _merge_equipment_data(origin_equipment, background_equipment)
	
	if not combined_equipment.is_empty():
		_apply_equipment_data(character, combined_equipment)
	else:
		# Fallback to basic equipment
		_apply_basic_equipment(character)

## Get starting equipment data using hybrid approach
static func _get_starting_equipment_data(character: Character) -> Dictionary:
	# Try DataManager first
	if DataManager.is_system_ready():
		# Origin is now a string, use directly
		var origin_name = character.origin
		var origin_data = DataManager.get_origin_data(origin_name)
		
		# Validate origin_data is a Dictionary before calling .get()
		if not origin_data is Dictionary:
			push_warning("CharacterGeneration: Expected Dictionary for origin data, got %s" % typeof(origin_data))
			return {}
		
		var starting_gear_array = origin_data.get("starting_gear", [])
		return _convert_gear_array_to_dict(starting_gear_array)
	
	# Fallback to local data
	# Origin is now a string, use directly
	var origin_name = character.origin
	if _character_data.has("origins") and _character_data["origins"].has(origin_name):
		var origin_local_data = _character_data["origins"][origin_name]
		
		# Validate origin_local_data is a Dictionary before calling .get()
		if not origin_local_data is Dictionary:
			push_warning("CharacterGeneration: Expected Dictionary for local origin data, got %s" % typeof(origin_local_data))
			return {}
		
		var starting_gear_array = origin_local_data.get("starting_gear", [])
		return _convert_gear_array_to_dict(starting_gear_array)
	
	return {}

## Get background equipment data using hybrid approach
static func _get_background_equipment_data(character: Character) -> Dictionary:
	# Try DataManager first
	if DataManager.is_system_ready():
		var background_id = _get_background_id_from_string(character.background)
		var background_data = DataManager.get_background_data(background_id)
		
		# Validate background_data is a Dictionary before calling .get()
		if not background_data is Dictionary:
			push_warning("CharacterGeneration: Expected Dictionary for background data, got %s" % typeof(background_data))
			return {}
		
		var starting_gear_array = background_data.get("starting_gear", [])
		return _convert_gear_array_to_dict(starting_gear_array)
	
	# Fallback to local data
	var background_name = character.background
	if _backgrounds_data.has(background_name):
		var background_local_data = _backgrounds_data[background_name]
		
		# Validate background_local_data is a Dictionary before calling .get()
		if not background_local_data is Dictionary:
			push_warning("CharacterGeneration: Expected Dictionary for local background data, got %s" % typeof(background_local_data))
			return {}
		
		var starting_gear_array = background_local_data.get("starting_gear", [])
		return _convert_gear_array_to_dict(starting_gear_array)
	
	return {}

## Merge equipment data from multiple sources
static func _merge_equipment_data(equipment1: Dictionary, equipment2: Dictionary) -> Dictionary:
	var merged = {
		"weapons": [],
		"armor": [],
		"gear": [],
		"credits": 0
	}
	
	# Merge weapons
	merged.weapons.append_array(equipment1.get("weapons", []))
	merged.weapons.append_array(equipment2.get("weapons", []))
	
	# Merge armor
	merged.armor.append_array(equipment1.get("armor", []))
	merged.armor.append_array(equipment2.get("armor", []))
	
	# Merge gear
	merged.gear.append_array(equipment1.get("gear", []))
	merged.gear.append_array(equipment2.get("gear", []))
	
	# Add credits (take the higher value)
	merged.credits = max(equipment1.get("credits", 0), equipment2.get("credits", 0))
	
	return merged

## Convert gear array to equipment dictionary structure
static func _convert_gear_array_to_dict(gear_array: Array) -> Dictionary:
	var equipment_dict = {
		"weapons": [],
		"armor": [],
		"gear": [],
		"credits": 1000
	}
	
	# Handle both simple string arrays and complex object arrays
	for item in gear_array:
		if item is String:
			# Simple string format (from origin data)
			var item_str = str(item).to_lower()
			if "pistol" in item_str or "rifle" in item_str or "knife" in item_str or "weapon" in item_str or "cannon" in item_str or "shot" in item_str:
				equipment_dict.weapons.append(item)
			elif "armor" in item_str or "suit" in item_str or "chassis" in item_str:
				equipment_dict.armor.append(item)
			else:
				equipment_dict.gear.append(item)
		elif item is Dictionary:
			# Complex object format (from background data)
			var item_type = item.get("type", "").to_lower()
			var options = item.get("options", [])
			
			# Validate options is an Array before iterating
			if not options is Array:
				push_warning("CharacterGeneration: Expected Array for options, got %s" % typeof(options))
				continue
			
			# Add all options to the appropriate category
			for option in options:
				match item_type:
					"weapon":
						equipment_dict.weapons.append(option)
					"armor":
						equipment_dict.armor.append(option)
					"gear":
						equipment_dict.gear.append(option)
					_:
						# Default to gear if type is unknown
						equipment_dict.gear.append(option)
	
	return equipment_dict

## Apply equipment data to character
static func _apply_equipment_data(character: Character, equipment_data: Dictionary) -> void:
	# Store equipment data (would integrate with equipment system)
	character.personal_equipment = equipment_data
	character.credits_earned = equipment_data.get("credits", 1000)

## Apply basic equipment fallback
static func _apply_basic_equipment(character: Character) -> void:
	character.personal_equipment = {
		"weapons": ["Basic Pistol"],
		"armor": ["Light Armor"],
		"gear": ["Comm Unit"],
		"credits": 1000
	}
	character.credits_earned = 1000

## Set character flags based on origin (Five Parsecs p.18-20)
## Note: Origin-based properties like is_bot(), is_human() are derived from origin string
## so we only need to apply the stat modifiers and traits here
static func set_character_flags(character: Character) -> void:
	match character.origin:
		"HUMAN":
			# Human: +1 luck (Five Parsecs p.18)
			character.luck = clampi(character.luck + 1, 0, 3)
		"BOT":
			# Bot: 6+ Armor save (Five Parsecs p.18) - origin already set
			character.add_trait("Bot: 6+ Armor Save")
		"SOULLESS":
			# Soulless: 6+ Armor save (Five Parsecs p.19) - origin already set
			character.add_trait("Soulless: 6+ Armor Save")
		"ENGINEER":
			# Engineer: +1 Savvy, -1 Reaction, can't exceed T4 in Savvy (Five Parsecs p.18)
			character.savvy = clampi(character.savvy + 1, 0, 4) # T4 cap
			character.reactions = clampi(character.reactions - 1, 1, 6)
			character.add_trait("Engineer: +1 to repair rolls, T4 Savvy cap")
		"KERIN":
			# K'Erin: Toughness 4, +1 melee damage (Five Parsecs p.19)
			character.toughness = 4 # Force T4
			character.add_trait("K'Erin: +1 damage with melee weapons")
		"PRECURSOR":
			# Precursor: +2 Savvy, roll twice on events (Five Parsecs p.19)
			character.savvy = clampi(character.savvy + 2, 0, 5)
			character.add_trait("Precursor: Roll twice on events, keep preferred")
		"FERAL":
			# Feral: Ignore enemy penalties (Five Parsecs p.20)
			character.add_trait("Feral: Ignore suppression and enemy penalties")
		"SWIFT":
			# Swift: +2 Speed, limited to 1 Reaction per round (Five Parsecs p.20)
			character.speed = clampi(character.speed + 2, 4, 8)
			character.max_reactions_per_round = 1 # Hard cap for Swift
			character.add_trait("Swift: Glide abilities, 1 Reaction per round")

## Validate character meets Five Parsecs constraints
static func validate_character(character: Character) -> Dictionary:
	var result: Dictionary = {
		"valid": true,
		"errors": []
	}

	# Check attribute ranges according to Five Parsecs rules
	if character.reactions < 1 or character.reactions > 6:
		result.errors.append("Reaction must be 1-6")
		result.valid = false

	if character.speed < 4 or character.speed > 8:
		result.errors.append("Speed must be 4-8")
		result.valid = false

	if character.combat < 0 or character.combat > 3:
		result.errors.append("Combat skill must be 0-3")
		result.valid = false

	if character.toughness < 3 or character.toughness > 6:
		result.errors.append("Toughness must be 3-6")
		result.valid = false

	if character.savvy < 0 or character.savvy > 3:
		result.errors.append("Savvy must be 0-3")
		result.valid = false

	# Check character name
	if character.character_name.is_empty():
		result.errors.append("Character must have a name")
		result.valid = false

	# Check health calculation (Five Parsecs rule: toughness + 2)
	var expected_health = character.toughness + 2
	if character.max_health != expected_health:
		result.errors.append("Max health should be toughness + 2")
		result.valid = false

	return result

## Generate a complete character with full Five Parsecs relationships and equipment
## Now uses D100 table rolling for Background/Motivation/Class per Core Rules
static func generate_complete_character(config: Dictionary = {}) -> Character:
	var character = create_character(config)

	if not character:
		push_error("CharacterGeneration: Failed to create character in generate_complete_character")
		return null


	# Roll on D100 tables for Background, Motivation, and Class
	var table_results = roll_character_tables()

	# Apply table results (stat bonuses, traits, resources)
	apply_table_results_to_character(character, table_results)

	# Generate starting equipment (includes table-based equipment rolls)
	character.personal_equipment = _generate_starting_equipment_enhanced(character)

	# Legacy relationship generation (now supplemented by table resources)
	# These are kept for backward compatibility but resource counting comes from tables
	character.patrons = _generate_patrons(character)
	character.rivals = _generate_rivals(character)

	# Apply any additional background/motivation effects not covered by tables
	_apply_background_effects(character)
	_apply_motivation_effects(character)

	return character

## Generate a random character using ALL available enum values
static func generate_random_character() -> Character:
	_load_character_data()
	var config: Dictionary = {
		"name": _generate_random_full_name()
	}
	
	# Select random class from ALL available classes (core rules D100 table)
	var all_classes = [
		GlobalEnums.CharacterClass.WORKING_CLASS,
		GlobalEnums.CharacterClass.TECHNICIAN,
		GlobalEnums.CharacterClass.SCIENTIST,
		GlobalEnums.CharacterClass.HACKER,
		GlobalEnums.CharacterClass.SOLDIER,
		GlobalEnums.CharacterClass.MERCENARY,
		GlobalEnums.CharacterClass.AGITATOR,
		GlobalEnums.CharacterClass.PRIMITIVE,
		GlobalEnums.CharacterClass.ARTIST,
		GlobalEnums.CharacterClass.NEGOTIATOR,
		GlobalEnums.CharacterClass.TRADER,
		GlobalEnums.CharacterClass.STARSHIP_CREW,
		GlobalEnums.CharacterClass.PETTY_CRIMINAL,
		GlobalEnums.CharacterClass.GANGER,
		GlobalEnums.CharacterClass.SCOUNDREL,
		GlobalEnums.CharacterClass.ENFORCER,
		GlobalEnums.CharacterClass.SPECIAL_AGENT,
		GlobalEnums.CharacterClass.TROUBLESHOOTER,
		GlobalEnums.CharacterClass.BOUNTY_HUNTER,
		GlobalEnums.CharacterClass.NOMAD,
		GlobalEnums.CharacterClass.EXPLORER,
		GlobalEnums.CharacterClass.PUNK,
		GlobalEnums.CharacterClass.SCAVENGER
	]
	config["class"] = all_classes[randi() % all_classes.size()]
	
	# Select random background from ALL available backgrounds (core rules D100 table)
	var all_backgrounds = [
		GlobalEnums.Background.PEACEFUL_HIGH_TECH_COLONY,
		GlobalEnums.Background.GIANT_OVERCROWDED_CITY,
		GlobalEnums.Background.LOW_TECH_COLONY,
		GlobalEnums.Background.MINING_COLONY,
		GlobalEnums.Background.MILITARY_BRAT,
		GlobalEnums.Background.SPACE_STATION,
		GlobalEnums.Background.MILITARY_OUTPOST,
		GlobalEnums.Background.DRIFTER,
		GlobalEnums.Background.LOWER_MEGACITY_CLASS,
		GlobalEnums.Background.WEALTHY_MERCHANT_FAMILY,
		GlobalEnums.Background.FRONTIER_GANG,
		GlobalEnums.Background.RELIGIOUS_CULT,
		GlobalEnums.Background.WAR_TORN_HELLHOLE,
		GlobalEnums.Background.TECH_GUILD,
		GlobalEnums.Background.SUBJUGATED_COLONY,
		GlobalEnums.Background.LONG_TERM_SPACE_MISSION,
		GlobalEnums.Background.RESEARCH_OUTPOST,
		GlobalEnums.Background.PRIMITIVE_WORLD,
		GlobalEnums.Background.ORPHAN_UTILITY_PROGRAM,
		GlobalEnums.Background.ISOLATIONIST_ENCLAVE,
		GlobalEnums.Background.COMFORTABLE_MEGACITY,
		GlobalEnums.Background.INDUSTRIAL_WORLD,
		GlobalEnums.Background.BUREAUCRAT,
		GlobalEnums.Background.WASTELAND_NOMADS,
		GlobalEnums.Background.ALIEN_CULTURE
	]
	config["background"] = all_backgrounds[randi() % all_backgrounds.size()]
	
	# Select random motivation from ALL available motivations (core rules D100 table)
	var all_motivations = [
		GlobalEnums.Motivation.WEALTH,
		GlobalEnums.Motivation.FAME,
		GlobalEnums.Motivation.GLORY,
		GlobalEnums.Motivation.SURVIVAL,
		GlobalEnums.Motivation.ESCAPE,
		GlobalEnums.Motivation.ADVENTURE,
		GlobalEnums.Motivation.TRUTH,
		GlobalEnums.Motivation.TECHNOLOGY,
		GlobalEnums.Motivation.DISCOVERY,
		GlobalEnums.Motivation.LOYALTY,
		GlobalEnums.Motivation.REVENGE,
		GlobalEnums.Motivation.ROMANCE,
		GlobalEnums.Motivation.FAITH,
		GlobalEnums.Motivation.POLITICAL,
		GlobalEnums.Motivation.POWER,
		GlobalEnums.Motivation.ORDER,
		GlobalEnums.Motivation.FREEDOM
	]
	config["motivation"] = all_motivations[randi() % all_motivations.size()]
	
	# Select random origin from ALL available origins
	var all_origins = [
		GlobalEnums.Origin.HUMAN,
		GlobalEnums.Origin.ENGINEER,
		GlobalEnums.Origin.KERIN,
		GlobalEnums.Origin.SOULLESS,
		GlobalEnums.Origin.PRECURSOR,
		GlobalEnums.Origin.FERAL,
		GlobalEnums.Origin.SWIFT,
		GlobalEnums.Origin.BOT,
		GlobalEnums.Origin.CORE_WORLDS,
		GlobalEnums.Origin.FRONTIER,
		GlobalEnums.Origin.DEEP_SPACE,
		GlobalEnums.Origin.COLONY,
		GlobalEnums.Origin.HIVE_WORLD,
		GlobalEnums.Origin.FORGE_WORLD
	]
	config["origin"] = all_origins[randi() % all_origins.size()]
	
	var character = generate_complete_character(config)
	if not character:
		push_error("CharacterGeneration: generate_complete_character returned null, using fallback")
		return _create_simple_character()
	
	# Ensure character has proper equipment and relationships
	_ensure_character_equipment_static(character)
	_ensure_character_relationships_static(character)
	
	pass # Character generated
	
	return character

## Create a simple character without complex dependencies
static func _create_simple_character() -> Character:
	## Create a basic character with minimal dependencies for fallback
	if not Character:
		push_error("CharacterGeneration: Character class not available for simple creation")
		return null
	
	var character = Character.new()
	if not character:
		push_error("CharacterGeneration: Failed to create simple character")
		return null
	
	# Set basic properties
	character.character_name = "Fallback Character"
	character.character_class = "SOLDIER"
	character.background = "MILITARY"
	character.motivation = "SURVIVAL"
	character.origin = "HUMAN"
	
	# Set basic stats (Five Parsecs defaults)
	character.reactions = 3
	character.combat = 1
	character.toughness = 4
	character.savvy = 1
	character.speed = 6
	character.luck = 0
	
	# Set health (Five Parsecs rule: Toughness + 2)
	character.max_health = character.toughness + 2
	character.health = character.max_health
	
	return character

## Helper methods for random generation
static func _generate_random_full_name() -> String:
	## Generate a full name with first and last name
	var first_names = ["Alex", "Morgan", "Casey", "Taylor", "Jordan", "Riley", "Avery", "Quinn", "Blake", "Cameron", "Jamie", "Sage", "Rowan", "Kai", "Drew", "Sam", "Parker", "Reese", "Dakota", "Skyler"]
	var last_names = ["Vega", "Cruz", "Stone", "Hunter", "Fox", "Storm", "Reeves", "Cross", "Vale", "Kane", "Steele", "Raven", "Wolf", "Shaw", "Grey", "Black", "White", "Brown", "Green", "Blue"]
	
	var first = first_names[randi() % first_names.size()]
	var last = last_names[randi() % last_names.size()]
	return first + " " + last

static func _roll_random_class() -> int:
	var classes = [
		GlobalEnums.CharacterClass.WORKING_CLASS,
		GlobalEnums.CharacterClass.TECHNICIAN,
		GlobalEnums.CharacterClass.SCIENTIST,
		GlobalEnums.CharacterClass.HACKER,
		GlobalEnums.CharacterClass.SOLDIER,
		GlobalEnums.CharacterClass.MERCENARY,
		GlobalEnums.CharacterClass.AGITATOR,
		GlobalEnums.CharacterClass.PRIMITIVE,
		GlobalEnums.CharacterClass.ARTIST,
		GlobalEnums.CharacterClass.NEGOTIATOR,
		GlobalEnums.CharacterClass.TRADER,
		GlobalEnums.CharacterClass.STARSHIP_CREW,
		GlobalEnums.CharacterClass.PETTY_CRIMINAL,
		GlobalEnums.CharacterClass.GANGER,
		GlobalEnums.CharacterClass.SCOUNDREL,
		GlobalEnums.CharacterClass.ENFORCER,
		GlobalEnums.CharacterClass.SPECIAL_AGENT,
		GlobalEnums.CharacterClass.TROUBLESHOOTER,
		GlobalEnums.CharacterClass.BOUNTY_HUNTER,
		GlobalEnums.CharacterClass.NOMAD,
		GlobalEnums.CharacterClass.EXPLORER,
		GlobalEnums.CharacterClass.PUNK,
		GlobalEnums.CharacterClass.SCAVENGER
	]
	return classes[randi() % classes.size()]

static func _roll_random_background() -> String:
	var backgrounds = GlobalEnums.Background.keys()
	if "NONE" in backgrounds: backgrounds.erase("NONE")
	if "UNKNOWN" in backgrounds: backgrounds.erase("UNKNOWN")
	return backgrounds[randi() % backgrounds.size()]

static func _roll_random_motivation() -> int:
	var motivations = GlobalEnums.Motivation.keys()
	if "NONE" in motivations: motivations.erase("NONE")
	if "UNKNOWN" in motivations: motivations.erase("UNKNOWN")
	return GlobalEnums.Motivation[motivations[randi() % motivations.size()]]

static func _roll_random_origin() -> int:
	var origins = GlobalEnums.Origin.keys()
	if "NONE" in origins: origins.erase("NONE")
	if "UNKNOWN" in origins: origins.erase("UNKNOWN")
	# Filter DLC species if not enabled
	var _dlc_gen = Engine.get_main_loop().root.get_node_or_null("/root/DLCManager") if Engine.get_main_loop() else null
	if _dlc_gen:
		if not _dlc_gen.is_feature_enabled(_dlc_gen.ContentFlag.SPECIES_KRAG):
			origins.erase("KRAG")
		if not _dlc_gen.is_feature_enabled(_dlc_gen.ContentFlag.SPECIES_SKULKER):
			origins.erase("SKULKER")
	return GlobalEnums.Origin[origins[randi() % origins.size()]]

## Enhanced equipment generation with DiceManager integration
static func _generate_starting_equipment_enhanced(character: Character) -> Dictionary:
	
	# Get DiceManager through AutoloadManager for safe access
	var dice_manager = AutoloadManager.get_autoload_safe("DiceManager")
	if not dice_manager:
		push_error("CharacterGeneration: DiceManager not available for equipment generation")
		return _generate_fallback_equipment(character)
	
	# Use StartingEquipmentGenerator for proper Five Parsecs equipment generation
	if not ResourceLoader.exists("res://src/core/character/Equipment/StartingEquipmentGenerator.gd"):
		push_error("CharacterGeneration: StartingEquipmentGenerator not found")
		return _generate_fallback_equipment(character)
	
	var equipment_generator = preload("res://src/core/character/Equipment/StartingEquipmentGenerator.gd")
	var equipment = equipment_generator.generate_starting_equipment(character, dice_manager)
	
	if equipment.is_empty():
		push_warning("CharacterGeneration: StartingEquipmentGenerator failed, using fallback")
		return _generate_fallback_equipment(character)
	
	# Apply equipment conditions using dice
	equipment_generator.apply_equipment_condition(equipment, dice_manager)
	
	pass # Equipment generated
	
	return equipment

## Fallback equipment generation when DiceManager/StartingEquipmentGenerator unavailable
static func _generate_fallback_equipment(character: Character) -> Dictionary:
	
	var equipment = {
		"weapons": [],
		"armor": [],
		"gear": [],
		"credits": 1000,
		"condition_modifiers": {}
	}
	
	# Add class-specific equipment (original basic implementation) - now using string comparison
	match character.character_class:
		"SOLDIER":
			equipment.weapons.append("Combat Rifle")
			equipment.armor.append("Trooper Armor")
		"SCOUT":
			equipment.weapons.append("Carbine")
			equipment.armor.append("Light Armor")
		"MEDIC":
			equipment.weapons.append("Service Pistol")
			equipment.gear.append("Medkit")
		"ENGINEER":
			equipment.weapons.append("Service Pistol")
			equipment.gear.append("Repair Kit")
		"PILOT":
			equipment.weapons.append("Service Pistol")
			equipment.gear.append("Flight Computer")
		"MERCHANT":
			equipment.weapons.append("Service Pistol")
			equipment.gear.append("Trade Computer")
		"SECURITY":
			equipment.weapons.append("Combat Rifle")
			equipment.armor.append("Security Armor")
		"BROKER":
			equipment.weapons.append("Service Pistol")
			equipment.gear.append("Negotiation Tools")
	
	# Add random bonus equipment (simulated without dice)
	var bonus_weapons = ["Blade", "Pistol", "Hand Weapon"]
	equipment.weapons.append(bonus_weapons[randi() % bonus_weapons.size()])
	
	# Add random credits bonus (500-1500 range)
	equipment.credits += randi_range(0, 500)
	
	return equipment

## Public API for UI access
## These methods wrap the private implementations for external use

static func generate_patrons(character: Character) -> Array:
	return _generate_patrons(character)

static func generate_rivals(character: Character) -> Array:
	return _generate_rivals(character)

static func apply_background_effects(character: Character) -> void:
	_apply_background_effects(character)

static func apply_motivation_effects(character: Character) -> void:
	_apply_motivation_effects(character)

static func generate_starting_equipment_enhanced(character: Character) -> Dictionary:
	return _generate_starting_equipment_enhanced(character)

## Generate patron relationships using GameStateManager systems
static func _generate_patrons(character: Character) -> Array:
	
	var patrons = []
	
	# Get GameStateManager through AutoloadManager
	var game_state_manager = AutoloadManager.get_autoload_safe("GameStateManager")
	if not game_state_manager or not game_state_manager.has_method("get_manager"):
		push_warning("CharacterGeneration: GameStateManager not available, using fallback patron generation")
		return _generate_fallback_patrons(character)
	
	# Get PatronManager from GameStateManager
	var patron_manager = game_state_manager.get_manager("PatronManager")
	if not patron_manager:
		# Try direct PatronSystem access
		if ResourceLoader.exists("res://src/core/systems/PatronSystem.gd"):
			var patron_system = preload("res://src/core/systems/PatronSystem.gd").new()
			patron_manager = patron_system
		else:
			push_warning("CharacterGeneration: PatronManager/PatronSystem not available")
			return _generate_fallback_patrons(character)
	
	# Generate 1-3 patrons based on character background
	var patron_count = randi_range(1, 3)
	for i in patron_count:
		var patron = null
		if patron_manager.has_method("generate_patron"):
			patron = patron_manager.generate_patron()
		elif patron_manager.has_method("create_patron"):
			patron = patron_manager.create_patron()
		
		if patron:
			# Link patron to character background if possible
			_link_patron_to_character(patron, character)
			patrons.append(patron)
	
	pass # Patrons generated
	return patrons

## Generate rival relationships using GameStateManager systems
static func _generate_rivals(character: Character) -> Array:
	
	var rivals = []
	
	# Get GameStateManager through AutoloadManager
	var game_state_manager = AutoloadManager.get_autoload_safe("GameStateManager")
	if not game_state_manager or not game_state_manager.has_method("get_manager"):
		push_warning("CharacterGeneration: GameStateManager not available, using fallback rival generation")
		return _generate_fallback_rivals(character)
	
	# Get RivalManager from GameStateManager
	var rival_manager = game_state_manager.get_manager("RivalManager")
	if not rival_manager:
		# Try direct RivalSystem access
		if ResourceLoader.exists("res://src/core/rivals/RivalSystem.gd"):
			var rival_system = preload("res://src/core/rivals/RivalSystem.gd").new()
			rival_manager = rival_system
		else:
			push_warning("CharacterGeneration: RivalManager/RivalSystem not available")
			return _generate_fallback_rivals(character)
	
	# Generate 0-2 rivals based on character background/class
	var rival_count = randi_range(0, 2)
	for i in rival_count:
		var rival = null
		if rival_manager.has_method("create_rival"):
			# Create rival with character-appropriate parameters
			var rival_params = _get_rival_params_for_character(character)
			rival = rival_manager.create_rival(rival_params)
		
		if rival:
			rivals.append(rival)
	
	pass # Rivals generated
	return rivals

## Fallback patron generation when systems unavailable
static func _generate_fallback_patrons(character: Character) -> Array:
	var patrons = []
	var patron_count = randi_range(1, 2) # Reduced count for fallback
	
	for i in patron_count:
		var patron = {
			"id": "patron_%d_%d" % [character.get_instance_id(), i],
			"name": "Patron %d" % (i + 1),
			"type": "Corporate",
			"reputation": 0,
			"job_rate": 50,
			"linked_character_id": character.get_instance_id()
		}
		patrons.append(patron)
	
	return patrons

## Fallback rival generation when systems unavailable  
static func _generate_fallback_rivals(character: Character) -> Array:
	var rivals = []
	var rival_count = randi_range(0, 1) # Reduced count for fallback
	
	for i in rival_count:
		var rival = {
			"id": "rival_%d_%d" % [character.get_instance_id(), i],
			"name": "Rival %d" % (i + 1),
			"type": 0, # Default enemy type
			"level": 1,
			"reputation": 0,
			"active": true
		}
		rivals.append(rival)
	
	return rivals

## Link patron to character background/motivation
static func _link_patron_to_character(patron: Dictionary, character: Character) -> void:
	if patron.has("linked_character_id"):
		patron.linked_character_id = character.get_instance_id()
	
	# Adjust patron type based on character background - now using string comparison
	if patron.has("type"):
		match character.background:
			"CORPORATE":
				patron.type = "Corporate"
			"MILITARY":
				patron.type = "Military"
			"CRIMINAL":
				patron.type = "Criminal"
			_:
				patron.type = "Independent"

## Get rival parameters appropriate for character
static func _get_rival_params_for_character(character: Character) -> Dictionary:
	var params = {}
	
	# Base rival on character background/class for thematic consistency - now using string comparison
	match character.background:
		"MILITARY":
			params.type = GlobalEnums.EnemyType.get("PIRATES", 0)
			params.name = "Military Deserter"
		"CRIMINAL":
			params.type = GlobalEnums.EnemyType.get("GANGERS", 1)
			params.name = "Gang Rival"
		"CORPORATE":
			params.type = GlobalEnums.EnemyType.get("CORPORATE", 2)
			params.name = "Corporate Enforcer"
		_:
			params.type = GlobalEnums.EnemyType.get("RAIDERS", 3)
			params.name = "Personal Enemy"
	
	params.level = 1
	params.reputation = 0
	
	return params

## Apply background effects
static func _apply_background_effects(character: Character) -> void:
	match character.background:
		"MILITARY":
			character.add_trait("Military Discipline")
		"CRIMINAL":
			character.add_trait("Street Smarts")
		"ACADEMIC":
			character.add_trait("Academic Training")
		"MERCENARY":
			character.add_trait("Mercenary Experience")
		"COLONIST":
			character.add_trait("Colony Experience")
		"EXPLORER":
			character.add_trait("Exploration Experience")
		"TRADER":
			character.add_trait("Trade Experience")
		"OUTCAST":
			character.add_trait("Outcast Experience")

## Apply motivation effects to character (Core Rules p.25 — 17 motivations)
## Note: Primary stat/resource bonuses come from D100 MOTIVATION_TABLE.
## This method adds thematic traits for flavor.
static func _apply_motivation_effects(character: Character) -> void:
	match character.motivation:
		"WEALTH":
			character.add_trait("Wealth Seeker")
		"FAME":
			character.add_trait("Fame Seeker")
		"GLORY":
			character.add_trait("Glory Seeker")
		"SURVIVAL":
			character.add_trait("Survivalist")
		"ESCAPE":
			character.add_trait("Driven to Escape")
		"ADVENTURE":
			character.add_trait("Adventurer")
		"TRUTH":
			character.add_trait("Truth Seeker")
		"TECHNOLOGY":
			character.add_trait("Technology Enthusiast")
		"DISCOVERY":
			character.add_trait("Explorer at Heart")
		"LOYALTY":
			character.add_trait("Loyal to the Cause")
		"REVENGE":
			character.add_trait("Driven by Revenge")
		"ROMANCE":
			character.add_trait("Romantic Idealist")
		"FAITH":
			character.add_trait("Person of Faith")
		"POLITICAL":
			character.add_trait("Political Idealist")
		"POWER":
			character.add_trait("Power Hungry")
		"ORDER":
			character.add_trait("Seeker of Order")
		"FREEDOM":
			character.add_trait("Freedom Fighter")

## Enhanced character creation with full table integration
static func create_enhanced_character(
	config: Dictionary,
	dice_manager: Node,
	tables_manager: Object,
	equipment_generator: Object,
	connections_manager: Object
) -> Character:
	var character: Character = create_character(config)

	# Apply background event, motivation, and quirk from tables
	_apply_background_event(character, tables_manager)
	_apply_motivation(character, tables_manager)
	_apply_character_quirk(character, tables_manager)

	# Generate enhanced equipment using new system
	_generate_enhanced_equipment(character, dice_manager, equipment_generator)

	# Generate connections and relationships
	_generate_connections(character, connections_manager)

	return character

## Apply background event from tables
static func _apply_background_event(character: Character, tables_manager: Object) -> void:
	if not tables_manager or not tables_manager.has_method("roll_background_event"):
		return

	var event = tables_manager.roll_background_event(character.background)
	if not event.is_empty():
		character.add_trait("Background: " + event.get("description", "Unknown Event"))

## Apply motivation from tables
static func _apply_motivation(character: Character, tables_manager: Object) -> void:
	if not tables_manager or not tables_manager.has_method("roll_motivation"):
		return

	var motivation = tables_manager.roll_motivation(character.motivation)
	if not motivation.is_empty():
		character.add_trait("Motivation: " + motivation.get("description", "Unknown Motivation"))

## Apply character quirk from tables
static func _apply_character_quirk(character: Character, tables_manager: Object) -> void:
	if not tables_manager or not tables_manager.has_method("roll_character_quirk"):
		return

	var quirk = tables_manager.roll_character_quirk()
	if not quirk.is_empty():
		character.add_trait("Quirk: " + quirk.get("description", "Unknown Quirk"))

## Generate enhanced equipment
static func _generate_enhanced_equipment(character: Character, dice_manager: Node, equipment_generator: Object) -> void:
	if not equipment_generator or not equipment_generator.has_method("generate_starting_equipment"):
		return

	var equipment = equipment_generator.generate_starting_equipment(character, dice_manager)
	if not equipment.is_empty():
		character.personal_equipment = equipment

## Generate connections and relationships
static func _generate_connections(character: Character, connections_manager: Object) -> void:
	if not connections_manager or not connections_manager.has_method("generate_connections"):
		return

	var connections = connections_manager.generate_connections(character)
	if not connections.is_empty():
		character.character_relationships = connections

## Create basic character without external dependencies (safe fallback)
static func create_basic_character(config: Dictionary = {}) -> Character:
	return create_character(config)

static func _ensure_character_equipment_static(character: Character) -> void:
	## Ensure character has proper starting equipment
	if not character.has_method("set_personal_equipment"):
		# Set equipment directly on character properties
		var equipment = _generate_starting_equipment_enhanced(character)
		character.set_meta("personal_equipment", equipment)
		character.set_meta("credits_earned", equipment.get("credits", 1000))

static func _ensure_character_relationships_static(character: Character) -> void:
	## Ensure character has proper relationships
	# Generate some random patrons and rivals based on background
	var patrons = []
	var rivals = []
	
	# Add background-appropriate relationships - now using string comparison
	match character.background:
		"MILITARY":
			patrons.append("Military Command")
			rivals.append("Deserters")
		"MERCENARY":
			patrons.append("Mercenary Guild")
			rivals.append("Competing Mercs")
		"CRIMINAL":
			patrons.append("Criminal Syndicate")
			rivals.append("Law Enforcement")
		"ACADEMIC":
			patrons.append("Research Institute")
			rivals.append("Competing Scholars")
		"TRADER":
			patrons.append("Trade Federation")
			rivals.append("Competing Traders")
		_:
			patrons.append("Local Authorities")
			rivals.append("Local Criminals")
	
	character.set_meta("patrons", patrons)
	character.set_meta("rivals", rivals)

func _ensure_character_equipment(character: Character) -> void:
	## Ensure character has proper starting equipment
	if not character.has_method("set_personal_equipment"):
		# Set equipment directly on character properties
		var equipment = _generate_starting_equipment_enhanced(character)
		character.set_meta("personal_equipment", equipment)
		character.set_meta("credits_earned", equipment.get("credits", 1000))

func _ensure_character_relationships(character: Character) -> void:
	## Ensure character has proper relationships
	# Generate some random patrons and rivals based on background
	var patrons = []
	var rivals = []
	
	# Add background-appropriate relationships - now using string comparison
	match character.background:
		"MILITARY":
			patrons.append("Military Command")
			rivals.append("Deserters")
		"MERCENARY":
			patrons.append("Mercenary Guild")
			rivals.append("Competing Mercs")
		"CRIMINAL":
			patrons.append("Criminal Syndicate")
			rivals.append("Law Enforcement")
		"ACADEMIC":
			patrons.append("Research Institute")
			rivals.append("Competing Scholars")
		"TRADER":
			patrons.append("Trade Federation")
			rivals.append("Competing Traders")
		_:
			patrons.append("Local Authorities")
			rivals.append("Local Criminals")
	
	character.set_meta("patrons", patrons)
	character.set_meta("rivals", rivals)
