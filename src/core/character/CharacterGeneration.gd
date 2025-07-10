@tool
extends RefCounted
class_name FiveParsecsCharacterGeneration

## Five Parsecs Character Generation System
##
## Implements character creation following Five Parsecs From Home Core Rules
## - Attribute generation using 2D6 / 3.0 rounded up formula
## - Character class and background system
## - Five Parsecs specific traits and equipment

const GlobalEnums = preload("res://src/core/systems/GlobalEnums.gd")
const Character = preload("res://src/core/character/Character.gd")
const UniversalResourceLoader = preload("res://src/utils/UniversalResourceLoader.gd")

# Data-driven character creation tables
static var _character_data: Dictionary = {}
static var _backgrounds_data: Dictionary = {}
static var _skills_data: Dictionary = {}
static var _is_data_loaded: bool = false

## Load all necessary JSON data for character creation
static func _load_character_data() -> void:
	if _is_data_loaded:
		return

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
	var character := Character.new()

	# Basic identity from config or defaults
	character.character_name = config.get("name", "New Character")
	var p_class_name: String = config.get("class", "SOLDIER")
	var p_background_name: String = config.get("background", "MILITARY")
	
	if p_class_name in GlobalEnums.CharacterClass:
		character.character_class = GlobalEnums.CharacterClass[p_class_name]
	else:
		character.character_class = GlobalEnums.CharacterClass.SOLDIER

	if p_background_name in GlobalEnums.Background:
		character.background = GlobalEnums.Background[p_background_name]
	else:
		character.background = GlobalEnums.Background.MILITARY
		
	character.motivation = config.get("motivation", GlobalEnums.Motivation.SURVIVAL)
	character.origin = config.get("origin", GlobalEnums.Origin.HUMAN)

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
	character.reaction = generate_attribute() # Base 1, Max 6
	character.speed = generate_attribute() + 2 # Base 4", Max 8"
	character.combat = generate_attribute() - 1 # Base +0, Max +3
	character.toughness = generate_attribute() # Base 3, Max 6
	character.savvy = generate_attribute() - 1 # Base +0, Max +3

	# Clamp values to Five Parsecs ranges
	character.reaction = clampi(character.reaction, 1, 6)
	character.speed = clampi(character.speed, 4, 8)
	character.combat = clampi(character.combat, 0, 3)
	character.toughness = clampi(character.toughness, 3, 6)
	character.savvy = clampi(character.savvy, 0, 3)

	# Luck starts at 0 (humans can have up to 3)
	character.luck = 0

## Apply background-specific bonuses from loaded data
static func apply_background_bonuses(character: Character) -> void:
	var background_name: String = GlobalEnums.Background.keys()[character.background]
	if _backgrounds_data.has(background_name):
		var bg_data: Dictionary = _backgrounds_data[background_name]
		var stat_bonuses: Dictionary = bg_data.get("stat_bonuses", {})
		for key: String in stat_bonuses:
			character.set(key, character.get(key) + stat_bonuses[key])
		var features: Array = bg_data.get("traits", [])
		for feature: String in features:
			if character.has_method("add_trait"):
				character.add_trait(feature)

## Apply character class bonuses from loaded data
static func apply_class_bonuses(character: Character) -> void:
	var p_class_name: String = GlobalEnums.CharacterClass.keys()[character.character_class]
	if _character_data.has("classes") and _character_data.get("classes").has(p_class_name):
		var class_data: Dictionary = _character_data["classes"][p_class_name]
		var stat_bonuses: Dictionary = class_data.get("stat_bonuses", {})
		for key: String in stat_bonuses:
			character.set(key, character.get(key) + stat_bonuses[key])
		var features: Array = class_data.get("traits", [])
		for feature: String in features:
			if character.has_method("add_trait"):
				character.add_trait(feature)

## Set character flags based on origin
static func set_character_flags(character: Character) -> void:
	match character.origin:
		GlobalEnums.Origin.HUMAN:
			character.is_human = true
			character.luck = 1 # Humans start with 1 luck
		GlobalEnums.Origin.BOT:
			character.is_bot = true
			if character and character.has_method("add_trait"): character.add_trait("Mechanical")
		GlobalEnums.Origin.SOULLESS:
			character.is_soulless = true
			if character and character.has_method("add_trait"): character.add_trait("Emotionless")
		GlobalEnums.Origin.SWIFT:
			character.speed += 1
			if character and character.has_method("add_trait"): character.add_trait("Quick")
		GlobalEnums.Origin.KERIN:
			character.reaction += 1
			if character and character.has_method("add_trait"): character.add_trait("Sharp Senses")
		GlobalEnums.Origin.PRECURSOR:
			character.savvy += 1
			if character and character.has_method("add_trait"): character.add_trait("Ancient Knowledge")

## Generate starting equipment following Five Parsecs rules
static func generate_starting_equipment(character: Character) -> void:
	# Basic starting equipment
	var starting_gear: Dictionary = {
		"weapon": "Colony Rifle",
		"armor": "Flak Screen",
		"credits": 1000 + (roll_d10() * 100),
		"supplies": 3
	}

	# Class-specific equipment bonuses
	match character.character_class:
		GlobalEnums.CharacterClass.SOLDIER:
			starting_gear["weapon"] = "Military Rifle"
			starting_gear["armor"] = "Combat Armor"
		GlobalEnums.CharacterClass.SCOUT:
			starting_gear["weapon"] = "Scrap Pistol"
			starting_gear["equipment"] = "Scanner"
		GlobalEnums.CharacterClass.MEDIC:
			starting_gear["equipment"] = "Med-kit"
			starting_gear["supplies"] += 2
		GlobalEnums.CharacterClass.ENGINEER:
			starting_gear["equipment"] = "Repair Kit"
			starting_gear["weapon"] = "Ripper Sword"
		GlobalEnums.CharacterClass.PILOT:
			starting_gear["equipment"] = "Navigation Computer"
		GlobalEnums.CharacterClass.MERCHANT:
			starting_gear["credits"] += 500
		GlobalEnums.CharacterClass.SECURITY:
			starting_gear["weapon"] = "Hand Cannon"
			starting_gear["armor"] = "Deflector Field"
		GlobalEnums.CharacterClass.BROKER:
			starting_gear["credits"] += 300
			starting_gear["equipment"] = "Data Pad"

	# Store equipment data (would integrate with equipment system)
	character.credits_earned = starting_gear.get("credits", 1000)

## Validate character meets Five Parsecs constraints
static func validate_character(character: Character) -> Dictionary:
	var result: Dictionary = {
		"valid": true,
		"errors": []
	}

	# Check attribute ranges
	if character.reaction < 1 or character.reaction > 6:
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

	# Check health calculation
	var expected_health = character.toughness + 2
	if character.max_health != expected_health:
		result.errors.append("Max health should be toughness + 2")
		result.valid = false

	return result

## Generate a complete character with full Five Parsecs relationships and equipment
static func generate_complete_character(config: Dictionary = {}) -> Character:
	var character = create_character(config)
	
	# Generate relationships
	character.patrons = _generate_patrons(character)
	character.rivals = _generate_rivals(character)
	
	# Generate starting equipment
	character.personal_equipment = _generate_starting_equipment_enhanced(character)
	
	# Apply background bonuses and effects
	_apply_background_effects(character)
	
	# Apply motivation effects
	_apply_motivation_effects(character)
	
	return character

## Generate a random character using data
static func generate_random_character() -> Character:
	_load_character_data()
	var config: Dictionary = {
		"name": _generate_random_name()
	}
	
	# Select random class and background from loaded data
	var class_keys: Array = _character_data.get("classes", {}).keys()
	if not class_keys.is_empty():
		config["class"] = class_keys[randi() % class_keys.size()]
		
	var bg_keys: Array = _backgrounds_data.keys()
	if not bg_keys.is_empty():
		config["background"] = bg_keys[randi() % bg_keys.size()]
	
	# Add random motivation and origin
	var motivation_keys = GlobalEnums.Motivation.keys()
	if "NONE" in motivation_keys: motivation_keys.erase("NONE")
	if "UNKNOWN" in motivation_keys: motivation_keys.erase("UNKNOWN")
	if not motivation_keys.is_empty():
		config["motivation"] = GlobalEnums.Motivation[motivation_keys[randi() % motivation_keys.size()]]
	
	var origin_keys = GlobalEnums.Origin.keys()
	if "NONE" in origin_keys: origin_keys.erase("NONE")
	if "UNKNOWN" in origin_keys: origin_keys.erase("UNKNOWN")
	if not origin_keys.is_empty():
		config["origin"] = GlobalEnums.Origin[origin_keys[randi() % origin_keys.size()]]
	
	return generate_complete_character(config)

## Helper methods for random generation
static func _generate_random_name() -> String:
	var names = ["Alex", "Morgan", "Casey", "Taylor", "Jordan", "Riley", "Avery", "Quinn"]
	return names[randi() % names.size()]

static func _roll_random_class() -> int:
	var classes = [
		GlobalEnums.CharacterClass.SOLDIER,
		GlobalEnums.CharacterClass.SCOUT,
		GlobalEnums.CharacterClass.MEDIC,
		GlobalEnums.CharacterClass.ENGINEER,
		GlobalEnums.CharacterClass.PILOT,
		GlobalEnums.CharacterClass.MERCHANT,
		GlobalEnums.CharacterClass.SECURITY,
		GlobalEnums.CharacterClass.BROKER
	]
	return classes[randi() % classes.size()]

static func _roll_random_background() -> String:
	var backgrounds = GlobalEnums.Background.keys()
	if "UNKNOWN" in backgrounds:
		backgrounds.erase("UNKNOWN")
	return backgrounds[randi() % backgrounds.size()]

static func _roll_random_motivation() -> String:
	var motivations = GlobalEnums.Motivation.keys()
	if "UNKNOWN" in motivations:
		motivations.erase("UNKNOWN")
	return motivations[randi() % motivations.size()]

static func _roll_random_origin() -> String:
	var origins = GlobalEnums.Origin.keys()
	if "UNKNOWN" in origins:
		origins.erase("UNKNOWN")
	return origins[randi() % origins.size()]

## Generate patrons for a character based on background and motivation
static func _generate_patrons(character: Character) -> Array:
	var patrons = []
	
	# Determine patron count based on background
	var patron_count = _get_patron_count_for_background(character.background)
	
	for i in range(patron_count):
		var patron = _create_patron_for_character(character)
		patrons.append(patron)
	
	return patrons

## Generate rivals for a character based on background and motivation
static func _generate_rivals(character: Character) -> Array:
	var rivals = []
	
	# Determine rival count based on motivation and background
	var rival_count = _get_rival_count_for_character(character)
	
	for i in range(rival_count):
		var rival = _create_rival_for_character(character)
		rivals.append(rival)
	
	return rivals

## Get patron count based on character background
static func _get_patron_count_for_background(background: int) -> int:
	match background:
		GlobalEnums.Background.MILITARY:
			return randi_range(1, 2) # Military contacts
		GlobalEnums.Background.MERCHANT:
			return randi_range(1, 3) # Trade networks
		GlobalEnums.Background.CRIMINAL:
			return randi_range(0, 2) # Underworld contacts
		GlobalEnums.Background.TRADER:
			return randi_range(1, 2) # Trade contacts (using TRADER instead of CORPORATE)
		GlobalEnums.Background.COLONIST:
			return randi_range(0, 1) # Local contacts
		GlobalEnums.Background.ACADEMIC:
			return randi_range(1, 2) # Research contacts
		_:
			return randi_range(0, 1) # General contacts

## Get rival count based on character profile
static func _get_rival_count_for_character(character: Character) -> int:
	var base_count = 0
	
	# Background influence on rivals
	match character.background:
		GlobalEnums.Background.CRIMINAL:
			base_count += randi_range(1, 2) # Criminal past creates enemies
		GlobalEnums.Background.MILITARY:
			base_count += randi_range(0, 1) # Military conflicts
		GlobalEnums.Background.TRADER:
			base_count += randi_range(0, 1) # Trade rivals
		_:
			base_count += randi_range(0, 1) # General chance
	
	# Motivation influence on rivals
	match character.motivation:
		GlobalEnums.Motivation.REVENGE:
			base_count += 1 # Revenge creates more enemies
		GlobalEnums.Motivation.WEALTH:
			base_count += randi_range(0, 1) # Competition
		GlobalEnums.Motivation.POWER:
			base_count += randi_range(0, 1) # Political enemies
	
	return clampi(base_count, 0, 3) # Max 3 rivals

## Create a patron for the character
static func _create_patron_for_character(character: Character) -> Dictionary:
	var patron = {
		"name": _generate_patron_name(),
		"type": _get_patron_type_for_background(character.background),
		"relationship_level": randi_range(1, 3),
		"influence": _roll_patron_influence(),
		"sector": _roll_patron_sector(),
		"available_jobs": randi_range(1, 3),
		"payment_reliability": _roll_patron_reliability(character.background),
		"description": ""
	}
	
	patron.description = _generate_patron_description(patron)
	return patron

## Create a rival for the character
static func _create_rival_for_character(character: Character) -> Dictionary:
	var rival = {
		"name": _generate_rival_name(),
		"type": _get_rival_type_for_character(character),
		"threat_level": randi_range(1, 3),
		"influence": _roll_rival_influence(),
		"motivation": _roll_rival_motivation(),
		"resources": _roll_rival_resources(),
		"active": true,
		"last_encounter": "",
		"description": ""
	}
	
	rival.description = _generate_rival_description(rival)
	return rival

## Get patron type based on background
static func _get_patron_type_for_background(background: int) -> String:
	match background:
		GlobalEnums.Background.MILITARY:
			return ["Military Officer", "Veteran Commander", "Defense Contractor"][randi() % 3]
		GlobalEnums.Background.MERCHANT:
			return ["Trade Baron", "Shipping Magnate", "Market Coordinator"][randi() % 3]
		GlobalEnums.Background.CRIMINAL:
			return ["Crime Boss", "Smuggler King", "Underground Broker"][randi() % 3]
		GlobalEnums.Background.TRADER:
			return ["Trade Executive", "Commerce Director", "Market Leader"][randi() % 3]
		GlobalEnums.Background.COLONIST:
			return ["Colony Administrator", "Settlement Leader", "Resource Manager"][randi() % 3]
		GlobalEnums.Background.ACADEMIC:
			return ["Research Director", "University Chancellor", "Think Tank Leader"][randi() % 3]
		_:
			return ["Independent Operator", "Freelance Coordinator", "Local Contact"][randi() % 3]

## Roll patron influence level
static func _roll_patron_influence() -> String:
	var roll = randi_range(1, 6)
	match roll:
		1, 2:
			return "Local"
		3, 4:
			return "Regional"
		5:
			return "Sector"
		6:
			return "Galactic"
		_:
			return "Local"

## Roll patron sector of operation
static func _roll_patron_sector() -> String:
	var sectors = [
		"Trade & Commerce", "Military & Security", "Research & Development",
		"Mining & Resources", "Transportation", "Entertainment", "Agriculture",
		"Technology", "Healthcare", "Construction", "Information"
	]
	return sectors[randi() % sectors.size()]

## Roll patron payment reliability
static func _roll_patron_reliability(background: int) -> String:
	var base_roll = randi_range(1, 6)
	
	# Background modifier
	match background:
		GlobalEnums.Background.MILITARY:
			base_roll += 1 # Military tends to be reliable
		GlobalEnums.Background.TRADER:
			base_roll += 1 # Trade structure ensures payment
		GlobalEnums.Background.CRIMINAL:
			base_roll -= 1 # Criminal contacts less reliable
	
	match base_roll:
		1, 2:
			return "Unreliable"
		3, 4:
			return "Average"
		5, 6:
			return "Good"
		_:
			return "Excellent"

## Generate patron names
static func _generate_patron_name() -> String:
	var first_names = ["Marcus", "Elena", "Viktor", "Zara", "Chen", "Aria", "Dmitri", "Nova"]
	var last_names = ["Blackwood", "Sterling", "Voss", "Kane", "Cross", "Steele", "Vega", "Storm"]
	return first_names[randi() % first_names.size()] + " " + last_names[randi() % last_names.size()]

## Generate rival names
static func _generate_rival_name() -> String:
	var names = ["Scarface Jake", "Iron Vixen", "The Broker", "Crimson Wade", "Ghost Walker",
				 "Steel Hand Murphy", "Void Queen", "Mad Dog Martinez", "Shadow Weaver", "Blood Eagle"]
	return names[randi() % names.size()]

## Get rival type for character
static func _get_rival_type_for_character(character: Character) -> String:
	match character.background:
		GlobalEnums.Background.CRIMINAL:
			return ["Former Gang Member", "Betrayed Partner", "Rival Crime Boss"][randi() % 3]
		GlobalEnums.Background.MILITARY:
			return ["Disgraced Officer", "War Enemy", "Court Martial Prosecutor"][randi() % 3]
		GlobalEnums.Background.TRADER:
			return ["Competing Trader", "Trade Whistleblower", "Market Rival"][randi() % 3]
		_:
			return ["Personal Enemy", "Business Rival", "Vengeful Contact"][randi() % 3]

## Roll rival influence
static func _roll_rival_influence() -> String:
	var roll = randi_range(1, 6)
	match roll:
		1, 2:
			return "Limited"
		3, 4:
			return "Moderate"
		5:
			return "Significant"
		6:
			return "Extensive"
		_:
			return "Limited"

## Roll rival motivation
static func _roll_rival_motivation() -> String:
	var motivations = ["Revenge", "Competition", "Ideology", "Greed", "Power", "Survival"]
	return motivations[randi() % motivations.size()]

## Roll rival resources
static func _roll_rival_resources() -> String:
	var roll = randi_range(1, 6)
	match roll:
		1, 2:
			return "Minimal"
		3, 4:
			return "Moderate"
		5:
			return "Well-funded"
		6:
			return "Extensive"
		_:
			return "Minimal"

## Generate patron description
static func _generate_patron_description(patron: Dictionary) -> String:
	var influence = patron.get("influence", "Local")
	var sector = patron.get("sector", "Unknown")
	var reliability = patron.get("payment_reliability", "Average")
	var type = patron.get("type", "Contact")
	
	return "A %s %s with %s influence in %s. Known for %s payment reliability." % [
		influence.to_lower(), type.to_lower(), influence.to_lower(), sector, reliability.to_lower()
	]

## Generate rival description
static func _generate_rival_description(rival: Dictionary) -> String:
	var type = rival.get("type", "Enemy")
	var threat = rival.get("threat_level", 1)
	var motivation = rival.get("motivation", "Unknown")
	var resources = rival.get("resources", "Minimal")
	
	var threat_text = ""
	match threat:
		1: threat_text = "minor"
		2: threat_text = "moderate"
		3: threat_text = "significant"
		_: threat_text = "unknown"
	
	return "A %s representing a %s threat. Motivated by %s with %s resources at their disposal." % [
		type.to_lower(), threat_text, motivation.to_lower(), resources.to_lower()
	]

## Enhanced starting equipment generation
static func _generate_starting_equipment_enhanced(character: Character) -> Dictionary:
	var equipment = {
		"weapons": [],
		"armor": [],
		"items": [],
		"credits": 1000 + (randi_range(1, 10) * 100),
		"value": 0
	}
	
	# Generate weapons based on class and background
	var primary_weapon = _generate_primary_weapon(character)
	equipment.weapons.append(primary_weapon)
	
	# Generate armor
	var armor = _generate_armor(character)
	equipment.armor.append(armor)
	
	# Generate items based on background
	var items = _generate_background_items(character)
	equipment.items.append_array(items)
	
	# Calculate total value
	equipment.value = _calculate_equipment_value(equipment)
	
	return equipment

## Generate primary weapon for character
static func _generate_primary_weapon(character: Character) -> Dictionary:
	var weapon_name = ""
	var weapon_stats = {}
	
	match character.character_class:
		GlobalEnums.CharacterClass.SOLDIER:
			weapon_name = ["Military Rifle", "Combat Shotgun", "Auto Rifle"][randi() % 3]
		GlobalEnums.CharacterClass.SCOUT:
			weapon_name = ["Scrap Pistol", "Hunting Rifle", "Needle Rifle"][randi() % 3]
		GlobalEnums.CharacterClass.SECURITY:
			weapon_name = ["Hand Cannon", "Plasma Rifle", "Blast Rifle"][randi() % 3]
		_:
			weapon_name = ["Colony Rifle", "Shell Gun", "Scrap Pistol"][randi() % 3]
	
	return {
		"name": weapon_name,
		"type": "Primary",
		"condition": _roll_equipment_condition(),
		"value": randi_range(200, 800)
	}

## Generate armor for character
static func _generate_armor(character: Character) -> Dictionary:
	var armor_name = ""
	
	match character.character_class:
		GlobalEnums.CharacterClass.SOLDIER:
			armor_name = ["Combat Armor", "Flak Screen", "Deflector Field"][randi() % 3]
		GlobalEnums.CharacterClass.SECURITY:
			armor_name = ["Deflector Field", "Combat Armor", "Power Armor"][randi() % 3]
		_:
			armor_name = ["Flak Screen", "Mesh Armor", "Basic Armor"][randi() % 3]
	
	return {
		"name": armor_name,
		"type": "Armor",
		"condition": _roll_equipment_condition(),
		"value": randi_range(150, 600)
	}

## Generate background-specific items
static func _generate_background_items(character: Character) -> Array:
	var items = []
	
	# Generate items based on character class (not background)
	match character.character_class:
		GlobalEnums.CharacterClass.MEDIC:
			items.append({"name": "Med-kit", "type": "Medical", "condition": "Good", "value": 300})
		GlobalEnums.CharacterClass.ENGINEER:
			items.append({"name": "Repair Kit", "type": "Tool", "condition": "Good", "value": 250})
		GlobalEnums.CharacterClass.MERCHANT:
			items.append({"name": "Trade Goods", "type": "Commodity", "condition": "Standard", "value": 400})
		GlobalEnums.CharacterClass.ACADEMIC:
			items.append({"name": "Data Pad", "type": "Information", "condition": "Good", "value": 200})
		_:
			items.append({"name": "Personal Effects", "type": "Misc", "condition": "Standard", "value": 100})
	
	# Add background-specific items
	match character.background:
		GlobalEnums.Background.MERCHANT:
			items.append({"name": "Trade Contacts", "type": "Information", "condition": "Good", "value": 150})
		GlobalEnums.Background.MILITARY:
			items.append({"name": "Military ID", "type": "Documentation", "condition": "Good", "value": 100})
		GlobalEnums.Background.ACADEMIC:
			items.append({"name": "Research Notes", "type": "Information", "condition": "Good", "value": 100})
	
	# Add universal starting items
	items.append({"name": "Communicator", "type": "Tech", "condition": "Good", "value": 150})
	items.append({"name": "Field Rations", "type": "Supply", "condition": "Standard", "value": 50})
	
	return items

## Roll equipment condition
static func _roll_equipment_condition() -> String:
	var roll = randi_range(1, 6)
	match roll:
		1:
			return "Poor"
		2, 3:
			return "Standard"
		4, 5:
			return "Good"
		6:
			return "Excellent"
		_:
			return "Standard"

## Calculate total equipment value
static func _calculate_equipment_value(equipment: Dictionary) -> int:
	var total = 0
	
	for weapon in equipment.get("weapons", []):
		total += weapon.get("value", 0)
	
	for armor in equipment.get("armor", []):
		total += armor.get("value", 0)
	
	for item in equipment.get("items", []):
		total += item.get("value", 0)
	
	return total

## Apply background effects to character
static func _apply_background_effects(character: Character) -> void:
	match character.background:
		GlobalEnums.Background.MILITARY:
			character.add_trait("Military Training")
			character.combat = mini(character.combat + 1, 3)
		GlobalEnums.Background.MERCHANT:
			character.add_trait("Trade Networks")
			character.credits_earned += 500
		GlobalEnums.Background.CRIMINAL:
			character.add_trait("Underworld Contacts")
			character.savvy = mini(character.savvy + 1, 3)
		GlobalEnums.Background.ACADEMIC:
			character.add_trait("Research Skills")
			character.savvy = mini(character.savvy + 1, 3)
		GlobalEnums.Background.COLONIST:
			character.add_trait("Frontier Survival")
			character.toughness = mini(character.toughness + 1, 6)

## Apply motivation effects to character
static func _apply_motivation_effects(character: Character) -> void:
	match character.motivation:
		GlobalEnums.Motivation.REVENGE:
			character.add_trait("Driven by Revenge")
		GlobalEnums.Motivation.WEALTH:
			character.add_trait("Wealth Seeker")
			character.credits_earned += 300
		GlobalEnums.Motivation.POWER:
			character.add_trait("Power Hungry")
		GlobalEnums.Motivation.SURVIVAL:
			character.add_trait("Survivalist")
			character.toughness = mini(character.toughness + 1, 6)
		GlobalEnums.Motivation.KNOWLEDGE:
			character.add_trait("Knowledge Seeker")
			character.savvy = mini(character.savvy + 1, 3)

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

## Apply background event from tables (with dependency injection)
static func _apply_background_event(character: Character, tables_manager: Object) -> void:
	if not tables_manager:
		push_warning("CharacterGeneration: tables_manager not provided to _apply_background_event.")
		return

	if not tables_manager.has_method("roll_background_event"):
		push_error("CharacterGeneration: tables_manager is missing 'roll_background_event' method.")
		return

	var event: Dictionary = tables_manager.roll_background_event(character.background)

	if character and character.has_method("add_trait"):
		var feature_name = "Background Event: " + event.get("event", "Unknown Event")
		character.add_trait(feature_name)

	# Apply event effects
	if event.has("effect"):
		_apply_feature_effect(character, event.effect)

## Apply character motivation from tables (with dependency injection)
static func _apply_motivation(character: Character, tables_manager: Object) -> void:
	if not tables_manager:
		push_warning("CharacterGeneration: tables_manager not provided to _apply_motivation.")
		return

	if not tables_manager.has_method("roll_motivation"):
		push_error("CharacterGeneration: tables_manager is missing 'roll_motivation' method.")
		return

	var motivation: Dictionary = tables_manager.roll_motivation()

	if character and character.has_method("add_trait"):
		var feature_name = "Motivation: " + motivation.get("name", "Unknown")
		var feature_desc = motivation.get("description", "")
		character.add_trait(str(feature_name) + " - " + feature_desc)

## Apply character quirk from tables (with dependency injection)
static func _apply_character_quirk(character: Character, tables_manager: Object) -> void:
	if not tables_manager:
		push_warning("CharacterGeneration: tables_manager not provided to _apply_character_quirk.")
		return

	if not tables_manager.has_method("roll_character_quirk"):
		push_error("CharacterGeneration: tables_manager is missing 'roll_character_quirk' method.")
		return

	var quirk: Dictionary = tables_manager.roll_character_quirk()

	if character and character.has_method("add_trait"):
		var feature_name = "Quirk: " + quirk.get("name", "Unknown")
		var feature_effect = quirk.get("effect", "")
		character.add_trait(str(feature_name) + " - " + feature_effect)

## Generate enhanced equipment using new equipment system (with dependency injection)
static func _generate_enhanced_equipment(character: Character, dice_manager: Node, equipment_generator: Object) -> void:
	if not equipment_generator:
		push_warning("CharacterGeneration: equipment_generator not provided.")
		return

	if not equipment_generator.has_method("generate_starting_equipment"):
		push_error("CharacterGeneration: equipment_generator is missing 'generate_starting_equipment' method.")
		return

	var equipment: Dictionary = equipment_generator.generate_starting_equipment(character, dice_manager)
	if equipment_generator.has_method("apply_equipment_condition"):
		equipment_generator.apply_equipment_condition(equipment, dice_manager)

	# Update character credits
	character.credits_earned = equipment.get("credits", 1000)

	# Store equipment as traits for now (could be enhanced to use actual equipment system)
	var weapons: Array = equipment.get("weapons", [])
	for weapon: Variant in weapons:
		if weapon is Dictionary:
			var feature_name = "Equipment: " + weapon.get("name", "Unknown Weapon")
			var condition = weapon.get("condition", "standard")
			if character.has_method("add_trait"): character.add_trait(str(feature_name) + " (" + condition + ")")
		elif weapon is String:
			if character.has_method("add_trait"): character.add_trait("Equipment: " + weapon)

	var armor_items: Array = equipment.get("armor", [])
	for armor: Variant in armor_items:
		if armor is Dictionary:
			var feature_name = "Armor: " + armor.get("name", "Unknown Armor")
			var condition = armor.get("condition", "standard")
			if character.has_method("add_trait"): character.add_trait(str(feature_name) + " (" + condition + ")")
		elif armor is String:
			if character.has_method("add_trait"): character.add_trait("Armor: " + armor)

## Generate character connections and relationships (with dependency injection)
static func _generate_connections(character: Character, connections_manager: Object) -> void:
	if not connections_manager:
		push_warning("CharacterGeneration: connections_manager not provided.")
		return

	if not connections_manager.has_method("generate_starting_connections"):
		push_error("CharacterGeneration: connections_manager is missing 'generate_starting_connections' method.")
		return

	var connections: Array[Dictionary] = connections_manager.generate_starting_connections(character)
	var rivals: Array[Dictionary] = []
	var patrons: Array[Dictionary] = []

	if connections_manager.has_method("generate_starting_rivals"):
		rivals = connections_manager.generate_starting_rivals(character)

	if connections_manager.has_method("generate_patron_connections"):
		patrons = connections_manager.generate_patron_connections(character)

	# Apply connections as traits
	if connections_manager.has_method("apply_connections_to_character"):
		connections_manager.apply_connections_to_character(character, connections)

	# Apply rivals as traits
	for rival: Dictionary in rivals:
		var rival_feature = "Rival: " + rival.get("name", "Unknown") + " (" + rival.get("relationship", "hostile") + ")"
		if character.has_method("add_trait"): character.add_trait(rival_feature)

	# Apply patrons as traits
	for patron: Dictionary in patrons:
		var patron_feature = "Patron: " + patron.get("name", "Unknown") + " (" + patron.get("influence", "minor") + ")"
		if character.has_method("add_trait"): character.add_trait(patron_feature)

## Apply trait effect to character (parse effect strings)
static func _apply_feature_effect(character: Character, effect: String) -> void:
	# Parse common effect patterns
	if "+1 to Combat" in effect or "Combat Skill" in effect:
		character.combat = mini(character.combat + 1, 5)
	elif "+1 to Leadership" in effect:
		if character and character.has_method("add_trait"): character.add_trait("Leadership Bonus")
	elif "+1 to Survival" in effect:
		if character and character.has_method("add_trait"): character.add_trait("Survival Bonus")
	elif "+1 to Morale" in effect:
		if character and character.has_method("add_trait"): character.add_trait("Morale Bonus")
	elif "+1 to Trade" in effect:
		if character and character.has_method("add_trait"): character.add_trait("Trade Bonus")
	elif "+1 to Toughness" in effect:
		character.toughness = mini(character.toughness + 1, 6)
	elif "Rival:" in effect:
		if character and character.has_method("add_trait"): character.add_trait("Rival: " + effect.split("Rival:")[1].strip_edges())
	elif "Enemy:" in effect:
		if character and character.has_method("add_trait"): character.add_trait("Enemy: " + effect.split("Enemy:")[1].strip_edges())
	elif "Contact:" in effect:
		if character and character.has_method("add_trait"): character.add_trait("Contact: " + effect.split("Contact:")[1].strip_edges())

	# Log effect application
	print("CharacterGeneration: Applied trait effect: %s" % effect)

## Generate character with full Core Rulebook compliance
static func generate_rulebook_compliant_character(dice_manager: Node) -> Character:
	var config = {
		"name": _generate_random_name(),
		"class": _roll_random_class(),
		"background": _roll_random_background(),
		"motivation": _roll_random_motivation(),
		"origin": _roll_random_origin()
	}
	
	# Load dependent scripts for full generation
	var tables_manager = load("res://src/core/character/tables/CharacterCreationTables.gd")
	var equipment_generator = load("res://src/core/character/Equipment/StartingEquipmentGenerator.gd")
	var connections_manager = load("res://src/core/character/connections/CharacterConnections.gd")

	return create_enhanced_character(config, dice_manager, tables_manager, equipment_generator, connections_manager)

## Create basic character without external dependencies (safe fallback)
static func create_basic_character(config: Dictionary = {}) -> Character:
	return create_character(config)
## Safe property access helper - eliminates UNSAFE_METHOD_ACCESS warnings
## Based on Godot 4.4 best practices for safe property access
func safe_get_property(obj: Variant, property: String, default_value: Variant = null) -> Variant:
	if obj == null:
		return default_value
	if obj is Object and obj.has_method("get"):
		var value: Variant = obj.get(property)
		return value if value != null else default_value
	elif obj is Dictionary:
		return obj.get(property, default_value)
	return default_value
## Safe method call helper - eliminates UNSAFE_METHOD_ACCESS warnings
func safe_call_method(obj: Variant, method_name: String, args: Array = []) -> Variant:
	if obj == null:
		return null
	if obj is Object and obj.has_method(method_name):
		return obj.callv(method_name, args)
	return null