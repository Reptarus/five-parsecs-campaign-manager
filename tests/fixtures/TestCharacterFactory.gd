class_name TestCharacterFactory
extends RefCounted

## Unified Test Character Factory - Production Schema Compliant
## Creates test data matching Character.gd exactly for comprehensive testing
##
## SCHEMA VERSION: Matches Character.gd v1 (schema_version = 1)
## Last Updated: 2025-11-28

#region Character Creation - Full Schema

## Create a production-compliant character dictionary
## Matches all properties from Character.gd
static func create_character(
	name: String = "Test Character",
	combat: int = 2,
	reactions: int = 1,
	toughness: int = 3,
	savvy: int = 1,
	tech: int = 1,
	move: int = 4,
	speed: int = 4,
	luck: int = 0
) -> Dictionary:
	return {
		# Identity
		"character_id": "char_%d_%d" % [Time.get_ticks_msec(), randi() % 10000],
		"name": name,
		"character_name": name,  # Compatibility alias
		"schema_version": 1,

		# Character Properties (String-based for Godot 4.5 enum compatibility)
		"background": "COLONIST",
		"motivation": "SURVIVAL",
		"origin": "HUMAN",
		"character_class": "BASELINE",

		# Core Stats - CORRECT NAMES matching Character.gd
		"combat": combat,           # NOT combat_skill
		"reactions": reactions,     # NOT reaction (singular)
		"toughness": toughness,
		"savvy": savvy,
		"tech": tech,               # MUST BE INCLUDED
		"move": move,               # MUST BE INCLUDED
		"speed": speed,
		"luck": luck,

		# Health (derived from toughness + 2 in Five Parsecs)
		"health": toughness + 2,
		"max_health": toughness + 2,

		# Character State
		"experience": 0,
		"credits": 0,
		"equipment": [] as Array[String],  # Typed array
		"is_captain": false,
		"status": "ACTIVE",  # ACTIVE, INJURED, RECOVERING, DEAD, MISSING, RETIRED
		"created_at": Time.get_datetime_string_from_system(),

		# Combat state (for battle tests)
		"in_cover": false,
		"elevated": false,
		"is_stunned": false,
		"is_suppressed": false
	}

## Create character with specific background
static func create_character_with_background(
	name: String,
	background: String,
	motivation: String = "SURVIVAL"
) -> Dictionary:
	var char_data := create_character(name)
	char_data["background"] = background.to_upper()
	char_data["motivation"] = motivation.to_upper()

	# Apply background bonuses (matching Character.gd apply_background_bonuses)
	match background.to_upper():
		"MILITARY":
			char_data["combat"] += 1
			char_data["toughness"] += 1
		"TRADER":
			char_data["savvy"] += 1
			char_data["tech"] += 1
		"ENGINEER":
			char_data["tech"] += 2
		"MEDIC":
			char_data["savvy"] += 1
			char_data["toughness"] += 1
		"PILOT":
			char_data["reactions"] += 1
			char_data["move"] += 1
		"SCHOLAR":
			char_data["savvy"] += 2
		"CRIMINAL":
			char_data["reactions"] += 1
			char_data["combat"] += 1
		_:
			char_data["combat"] += 1  # Generic bonus

	return char_data

## Create captain (with captain bonuses)
static func create_captain(name: String = "Test Captain") -> Dictionary:
	var captain := create_character_with_background(name, "MILITARY")
	captain["is_captain"] = true
	captain["combat"] += 1  # Captain bonus
	captain["reactions"] += 1  # Captain bonus
	return captain

## Create character with specific origin
static func create_character_with_origin(
	name: String,
	origin: String
) -> Dictionary:
	var char_data := create_character(name)
	char_data["origin"] = origin.to_upper()

	# Apply origin-specific traits
	match origin.to_upper():
		"HUMAN":
			char_data["luck"] = max(char_data["luck"], 1)  # Humans get luck
		"ALIEN_SWIFT":
			char_data["speed"] += 1
			char_data["reactions"] += 1
		"ALIEN_FERAL":
			char_data["toughness"] += 1
			char_data["combat"] += 1
		"BOT":
			char_data["tech"] += 2
			char_data["luck"] = 0  # Bots don't get luck

	return char_data

#endregion

#region Crew Creation

## Create standard test crew
static func create_test_crew(count: int = 4) -> Array[Dictionary]:
	var crew: Array[Dictionary] = []
	var names := ["Soldier", "Medic", "Engineer", "Scout", "Heavy", "Pilot"]
	var backgrounds := ["MILITARY", "MEDIC", "ENGINEER", "EXPLORER", "MILITARY", "PILOT"]

	for i in range(mini(count, names.size())):
		var char_data := create_character_with_background(
			names[i],
			backgrounds[i]
		)
		char_data["character_id"] = "crew_%d" % i
		crew.append(char_data)

	return crew

## Create minimal crew (for quick tests)
static func create_minimal_crew(count: int = 2) -> Array[Dictionary]:
	var crew: Array[Dictionary] = []
	for i in range(count):
		var char_data := create_character("Crew %d" % i)
		char_data["character_id"] = "crew_%d" % i
		crew.append(char_data)
	return crew

## Create diverse crew (different origins)
static func create_diverse_crew() -> Array[Dictionary]:
	return [
		create_character_with_origin("Human Soldier", "HUMAN"),
		create_character_with_origin("Swift Scout", "ALIEN_SWIFT"),
		create_character_with_origin("Feral Warrior", "ALIEN_FERAL"),
		create_character_with_origin("Bot Medic", "BOT")
	]

#endregion

#region Equipment

## Create equipment array (typed to match Character.gd)
static func create_starting_equipment(background: String = "MILITARY") -> Array[String]:
	var equipment: Array[String] = []
	equipment.append("Basic Kit")
	equipment.append("Clothing")

	match background.to_upper():
		"MILITARY":
			equipment.append("Combat Rifle")
			equipment.append("Body Armor")
		"TRADER":
			equipment.append("Hand Weapon")
			equipment.append("Trade Goods")
		"ENGINEER":
			equipment.append("Tool Kit")
			equipment.append("Repair Kit")
		"MEDIC":
			equipment.append("Medical Kit")
			equipment.append("Stimms")
		"PILOT":
			equipment.append("Hand Weapon")
			equipment.append("Navigation Kit")
		_:
			equipment.append("Hand Weapon")
			equipment.append("Basic Gear")

	return equipment

## Equip character with items
static func equip_character(char_data: Dictionary, items: Array[String]) -> Dictionary:
	char_data["equipment"] = items.duplicate()
	return char_data

#endregion

#region Character States

## Create injured character
static func create_injured_character(
	name: String = "Injured Crew",
	injury_type: String = "LIGHT_INJURY",
	turns_remaining: int = 1
) -> Dictionary:
	var char_data := create_character(name)
	char_data["status"] = "INJURED"
	char_data["injury"] = {
		"type": injury_type,
		"turns_remaining": turns_remaining
	}
	return char_data

## Create recovering character
static func create_recovering_character(name: String = "Recovering Crew") -> Dictionary:
	var char_data := create_character(name)
	char_data["status"] = "RECOVERING"
	return char_data

## Create veteran character (high XP)
static func create_veteran_character(name: String = "Veteran") -> Dictionary:
	var char_data := create_character(name)
	char_data["experience"] = 50
	char_data["combat"] += 2
	char_data["reactions"] += 1
	char_data["toughness"] += 1
	return char_data

#endregion

#region Campaign Data

## Create full campaign data structure (matching GameStateManager format)
static func create_campaign_data(
	campaign_name: String = "Test Campaign",
	crew_count: int = 4
) -> Dictionary:
	var captain := create_captain()
	var crew := create_test_crew(crew_count)

	return {
		"config": {
			"campaign_name": campaign_name,
			"difficulty": "NORMAL",
			"victory_condition": "SURVIVE_10_TURNS",
			"is_complete": true
		},
		"captain": captain,
		"crew": {
			"members": crew,
			"is_complete": true
		},
		"ship": {
			"name": "Test Ship",
			"hull_points": 10,
			"fuel": 6,
			"debt": 0,
			"is_complete": true
		},
		"equipment": {
			"starting_credits": 100,
			"equipment": create_starting_equipment("MILITARY"),
			"is_complete": true
		},
		"world": {
			"current_world": "Test World",
			"world_type": "COLONY",
			"is_complete": true
		},
		"metadata": {
			"created_at": Time.get_datetime_string_from_system(),
			"version": "0.1.0",
			"schema_version": 1
		}
	}

## Create minimal campaign (for quick tests)
static func create_minimal_campaign() -> Dictionary:
	return create_campaign_data("Minimal Campaign", 1)

#endregion

#region Validation Helpers

## Check if character data matches production schema
static func validate_character_schema(char_data: Dictionary) -> Dictionary:
	var result := {
		"valid": true,
		"missing_fields": [] as Array[String],
		"wrong_type_fields": [] as Array[String],
		"errors": [] as Array[String]
	}

	# Required fields from Character.gd
	var required_fields := {
		"name": TYPE_STRING,
		"combat": TYPE_INT,
		"reactions": TYPE_INT,
		"toughness": TYPE_INT,
		"savvy": TYPE_INT,
		"tech": TYPE_INT,
		"move": TYPE_INT,
		"speed": TYPE_INT,
		"luck": TYPE_INT,
		"background": TYPE_STRING,
		"motivation": TYPE_STRING,
		"origin": TYPE_STRING,
		"character_class": TYPE_STRING,
		"status": TYPE_STRING,
		"is_captain": TYPE_BOOL,
		"experience": TYPE_INT
	}

	for field in required_fields:
		if not char_data.has(field):
			result["valid"] = false
			result["missing_fields"].append(field)
			result["errors"].append("Missing required field: %s" % field)
		elif typeof(char_data[field]) != required_fields[field]:
			result["valid"] = false
			result["wrong_type_fields"].append(field)
			result["errors"].append("Field '%s' has wrong type: expected %s" % [field, required_fields[field]])

	# Check for deprecated field names
	var deprecated_fields := ["combat_skill", "reaction", "species"]
	for field in deprecated_fields:
		if char_data.has(field):
			result["errors"].append("WARNING: Using deprecated field '%s'" % field)

	return result

## Validate crew array
static func validate_crew_schema(crew: Array) -> Dictionary:
	var result := {
		"valid": true,
		"member_errors": [] as Array[Dictionary]
	}

	for i in range(crew.size()):
		var member_validation := validate_character_schema(crew[i])
		if not member_validation["valid"]:
			result["valid"] = false
			result["member_errors"].append({
				"index": i,
				"validation": member_validation
			})

	return result

#endregion

#region Compatibility Aliases

## Create character using old naming (with deprecation warning)
## Use this only for testing backward compatibility
static func create_character_legacy(
	character_name: String = "Legacy Character",
	combat_skill: int = 2,
	reaction: int = 1,
	species: String = "HUMAN"
) -> Dictionary:
	push_warning("Using legacy character creation - migrate to create_character()")
	var char_data := create_character(
		character_name,
		combat_skill,  # Maps to combat
		reaction       # Maps to reactions
	)
	char_data["origin"] = species  # Maps species to origin
	return char_data

#endregion
