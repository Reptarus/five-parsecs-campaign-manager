@tool
extends RefCounted
class_name FiveParsecsCharacterGeneration

## Five Parsecs Character Generation System
##
## Implements character creation following Five Parsecs From Home Core Rules
## - Attribute generation using 2D6/3 rounded up formula
## - Character class and background system
## - Five Parsecs specific traits and equipment

const GameEnums = preload("res://src/core/systems/GlobalEnums.gd")
const Character = preload("res://src/core/character/Character.gd")
const CharacterCreationTables = preload("res://src/core/character/tables/CharacterCreationTables.gd")
const StartingEquipmentGenerator = preload("res://src/core/character/equipment/StartingEquipmentGenerator.gd")
const CharacterConnections = preload("res://src/core/character/connections/CharacterConnections.gd")

## Generate Five Parsecs attribute using official 2D6/3 formula
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
	var character := Character.new()
	
	# Basic identity
	character.character_name = config.get("name", "New Character")
	character.character_class = config.get("class", GameEnums.CharacterClass.SOLDIER)
	character.background = config.get("background", GameEnums.Background.MILITARY)
	character.motivation = config.get("motivation", GameEnums.Motivation.SURVIVAL)
	character.origin = config.get("origin", GameEnums.Origin.HUMAN)
	
	# Generate Five Parsecs attributes using official 2D6/3 formula
	generate_character_attributes(character)
	
	# Set health based on toughness (Core Rules p.13)
	character.max_health = character.toughness + 2
	character.health = character.max_health
	
	# Apply background and class bonuses
	apply_background_bonuses(character)
	apply_class_bonuses(character)
	
	# Generate starting equipment
	generate_starting_equipment(character)
	
	# Set character flags based on origin
	set_character_flags(character)
	
	return character

## Generate all character attributes using Five Parsecs rules
static func generate_character_attributes(character: Character) -> void:
	# Core Five Parsecs attributes (2D6/3 rounded up)
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

## Apply background-specific bonuses per Five Parsecs rules
static func apply_background_bonuses(character: Character) -> void:
	match character.background:
		GameEnums.Background.MILITARY:
			character.combat += 1
			character.add_trait("Military Training")
		GameEnums.Background.MERCENARY:
			character.combat += 1
			character.reaction += 1
			character.add_trait("Combat Veteran")
		GameEnums.Background.CRIMINAL:
			character.savvy += 1
			character.add_trait("Streetwise")
		GameEnums.Background.COLONIST:
			character.toughness += 1
			character.add_trait("Hardy")
		GameEnums.Background.ACADEMIC:
			character.savvy += 2
			character.add_trait("Educated")
		GameEnums.Background.EXPLORER:
			character.reaction += 1
			character.savvy += 1
			character.add_trait("Well-Traveled")
		GameEnums.Background.TRADER:
			character.savvy += 1
			character.add_trait("Negotiator")
		GameEnums.Background.NOBLE:
			character.savvy += 1
			character.add_trait("Connections")
		GameEnums.Background.OUTCAST:
			character.toughness += 1
			character.add_trait("Self-Reliant")

## Apply character class bonuses per Five Parsecs rules
static func apply_class_bonuses(character: Character) -> void:
	match character.character_class:
		GameEnums.CharacterClass.SOLDIER:
			character.combat += 1
			character.toughness += 1
		GameEnums.CharacterClass.SCOUT:
			character.reaction += 1
			character.speed += 1
		GameEnums.CharacterClass.MEDIC:
			character.savvy += 1
			character.add_trait("Medical Training")
		GameEnums.CharacterClass.ENGINEER:
			character.savvy += 2
			character.add_trait("Technical Expert")
		GameEnums.CharacterClass.PILOT:
			character.reaction += 1
			character.savvy += 1
		GameEnums.CharacterClass.MERCHANT:
			character.savvy += 1
			character.add_trait("Business Sense")
		GameEnums.CharacterClass.SECURITY:
			character.combat += 1
			character.reaction += 1
		GameEnums.CharacterClass.BROKER:
			character.savvy += 2
			character.add_trait("Information Network")

## Set character flags based on origin
static func set_character_flags(character: Character) -> void:
	match character.origin:
		GameEnums.Origin.HUMAN:
			character.is_human = true
			character.luck = 1 # Humans start with 1 luck
		GameEnums.Origin.BOT:
			character.is_bot = true
			character.add_trait("Mechanical")
		GameEnums.Origin.SOULLESS:
			character.is_soulless = true
			character.add_trait("Emotionless")
		GameEnums.Origin.SWIFT:
			character.speed += 1
			character.add_trait("Quick")
		GameEnums.Origin.KERIN:
			character.reaction += 1
			character.add_trait("Sharp Senses")
		GameEnums.Origin.PRECURSOR:
			character.savvy += 1
			character.add_trait("Ancient Knowledge")

## Generate starting equipment following Five Parsecs rules
static func generate_starting_equipment(character: Character) -> void:
	# Basic starting equipment
	var starting_gear = {
		"weapon": "Colony Rifle",
		"armor": "Flak Screen",
		"credits": 1000 + (roll_d10() * 100),
		"supplies": 3
	}
	
	# Class-specific equipment bonuses
	match character.character_class:
		GameEnums.CharacterClass.SOLDIER:
			starting_gear["weapon"] = "Military Rifle"
			starting_gear["armor"] = "Combat Armor"
		GameEnums.CharacterClass.SCOUT:
			starting_gear["weapon"] = "Scrap Pistol"
			starting_gear["equipment"] = "Scanner"
		GameEnums.CharacterClass.MEDIC:
			starting_gear["equipment"] = "Med-kit"
			starting_gear["supplies"] += 2
		GameEnums.CharacterClass.ENGINEER:
			starting_gear["equipment"] = "Repair Kit"
			starting_gear["weapon"] = "Ripper Sword"
		GameEnums.CharacterClass.PILOT:
			starting_gear["equipment"] = "Navigation Computer"
		GameEnums.CharacterClass.MERCHANT:
			starting_gear["credits"] += 500
		GameEnums.CharacterClass.SECURITY:
			starting_gear["weapon"] = "Hand Cannon"
			starting_gear["armor"] = "Deflector Field"
		GameEnums.CharacterClass.BROKER:
			starting_gear["credits"] += 300
			starting_gear["equipment"] = "Data Pad"
	
	# Store equipment data (would integrate with equipment system)
	character.credits_earned = starting_gear.get("credits", 1000)

## Validate character meets Five Parsecs constraints
static func validate_character(character: Character) -> Dictionary:
	var result = {
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

## Generate a random character following Five Parsecs tables
static func generate_random_character() -> Character:
	var config = {
		"name": _generate_random_name(),
		"class": _roll_random_class(),
		"background": _roll_random_background(),
		"motivation": _roll_random_motivation(),
		"origin": _roll_random_origin()
	}
	
	return create_character(config)

## Helper methods for random generation
static func _generate_random_name() -> String:
	var names = ["Alex", "Morgan", "Casey", "Taylor", "Jordan", "Riley", "Avery", "Quinn"]
	return names[randi() % names.size()]

static func _roll_random_class() -> int:
	var classes = [
		GameEnums.CharacterClass.SOLDIER,
		GameEnums.CharacterClass.SCOUT,
		GameEnums.CharacterClass.MEDIC,
		GameEnums.CharacterClass.ENGINEER,
		GameEnums.CharacterClass.PILOT,
		GameEnums.CharacterClass.MERCHANT,
		GameEnums.CharacterClass.SECURITY,
		GameEnums.CharacterClass.BROKER
	]
	return classes[randi() % classes.size()]

static func _roll_random_background() -> int:
	var backgrounds = [
		GameEnums.Background.MILITARY,
		GameEnums.Background.MERCENARY,
		GameEnums.Background.CRIMINAL,
		GameEnums.Background.COLONIST,
		GameEnums.Background.ACADEMIC,
		GameEnums.Background.EXPLORER,
		GameEnums.Background.TRADER,
		GameEnums.Background.NOBLE,
		GameEnums.Background.OUTCAST
	]
	return backgrounds[randi() % backgrounds.size()]

static func _roll_random_motivation() -> int:
	var motivations = [
		GameEnums.Motivation.WEALTH,
		GameEnums.Motivation.REVENGE,
		GameEnums.Motivation.GLORY,
		GameEnums.Motivation.KNOWLEDGE,
		GameEnums.Motivation.POWER,
		GameEnums.Motivation.JUSTICE,
		GameEnums.Motivation.SURVIVAL,
		GameEnums.Motivation.LOYALTY
	]
	return motivations[randi() % motivations.size()]

static func _roll_random_origin() -> int:
	var origins = [
		GameEnums.Origin.HUMAN,
		GameEnums.Origin.BOT,
		GameEnums.Origin.SWIFT,
		GameEnums.Origin.KERIN,
		GameEnums.Origin.PRECURSOR
	]
	return origins[randi() % origins.size()]

## Enhanced character creation with full table integration
static func create_enhanced_character(config: Dictionary = {}) -> Character:
	var character: Character = create_character(config)  # Use existing method
	
	# Apply background event from tables
	_apply_background_event(character)
	
	# Apply motivation from tables
	_apply_motivation(character) 
	
	# Apply character quirk from tables
	_apply_character_quirk(character)
	
	# Generate enhanced equipment using new system
	_generate_enhanced_equipment(character)
	
	# Generate connections and relationships
	_generate_connections(character)
	
	return character

## Apply background event from tables
static func _apply_background_event(character: Character) -> void:
	var event: Dictionary = CharacterCreationTables.roll_background_event(character.background)
	
	if character.has_method("add_trait"):
		var trait_name = "Background Event: " + event.get("event", "Unknown Event")
		character.add_trait(trait_name)
	
	# Apply event effects
	if event.has("effect"):
		_apply_trait_effect(character, event.effect)

## Apply character motivation from tables
static func _apply_motivation(character: Character) -> void:
	var motivation: Dictionary = CharacterCreationTables.roll_motivation()
	
	if character.has_method("add_trait"):
		var trait_name = "Motivation: " + motivation.get("name", "Unknown")
		var trait_desc = motivation.get("description", "")
		character.add_trait(trait_name + " - " + trait_desc)

## Apply character quirk from tables
static func _apply_character_quirk(character: Character) -> void:
	var quirk: Dictionary = CharacterCreationTables.roll_character_quirk()
	
	if character.has_method("add_trait"):
		var trait_name = "Quirk: " + quirk.get("name", "Unknown")
		var trait_effect = quirk.get("effect", "")
		character.add_trait(trait_name + " - " + trait_effect)

## Generate enhanced equipment using new equipment system
static func _generate_enhanced_equipment(character: Character) -> void:
	var equipment: Dictionary = StartingEquipmentGenerator.generate_starting_equipment(character)
	StartingEquipmentGenerator.apply_equipment_condition(equipment)
	
	# Update character credits
	character.credits_earned = equipment.get("credits", 1000)
	
	# Store equipment as traits for now (could be enhanced to use actual equipment system)
	var weapons: Array = equipment.get("weapons", [])
	for weapon in weapons:
		if weapon is Dictionary:
			var trait_name = "Equipment: " + weapon.get("name", "Unknown Weapon")
			var condition = weapon.get("condition", "standard")
			character.add_trait(trait_name + " (" + condition + ")")
		elif weapon is String:
			character.add_trait("Equipment: " + weapon)
	
	var armor_items: Array = equipment.get("armor", [])
	for armor in armor_items:
		if armor is Dictionary:
			var trait_name = "Armor: " + armor.get("name", "Unknown Armor")
			var condition = armor.get("condition", "standard")
			character.add_trait(trait_name + " (" + condition + ")")
		elif armor is String:
			character.add_trait("Armor: " + armor)

## Generate character connections and relationships
static func _generate_connections(character: Character) -> void:
	var connections: Array[Dictionary] = CharacterConnections.generate_starting_connections(character)
	var rivals: Array[Dictionary] = CharacterConnections.generate_starting_rivals(character)
	var patrons: Array[Dictionary] = CharacterConnections.generate_patron_connections(character)
	
	# Apply connections as traits
	CharacterConnections.apply_connections_to_character(character, connections)
	
	# Apply rivals as traits
	for rival in rivals:
		var rival_trait = "Rival: " + rival.get("name", "Unknown") + " (" + rival.get("relationship", "hostile") + ")"
		character.add_trait(rival_trait)
	
	# Apply patrons as traits
	for patron in patrons:
		var patron_trait = "Patron: " + patron.get("name", "Unknown") + " (" + patron.get("influence", "minor") + ")"
		character.add_trait(patron_trait)

## Apply trait effect to character (parse effect strings)
static func _apply_trait_effect(character: Character, effect: String) -> void:
	# Parse common effect patterns
	if "+1 to Combat" in effect or "Combat Skill" in effect:
		character.combat = mini(character.combat + 1, 5)
	elif "+1 to Leadership" in effect:
		character.add_trait("Leadership Bonus")
	elif "+1 to Survival" in effect:
		character.add_trait("Survival Bonus")
	elif "+1 to Morale" in effect:
		character.add_trait("Morale Bonus")
	elif "+1 to Trade" in effect:
		character.add_trait("Trade Bonus")
	elif "+1 to Toughness" in effect:
		character.toughness = mini(character.toughness + 1, 6)
	elif "Rival:" in effect:
		character.add_trait("Rival: " + effect.split("Rival:")[1].strip_edges())
	elif "Enemy:" in effect:
		character.add_trait("Enemy: " + effect.split("Enemy:")[1].strip_edges())
	elif "Contact:" in effect:
		character.add_trait("Contact: " + effect.split("Contact:")[1].strip_edges())
	
	# Log effect application
	print("CharacterGeneration: Applied trait effect: %s" % effect)

## Generate character with full Core Rulebook compliance
static func generate_rulebook_compliant_character() -> Character:
	var config = {
		"name": _generate_random_name(),
		"class": _roll_random_class(),
		"background": _roll_random_background(),
		"motivation": _roll_random_motivation(),
		"origin": _roll_random_origin()
	}
	
	return create_enhanced_character(config)