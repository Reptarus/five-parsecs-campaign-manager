extends RefCounted
class_name FiveParsecsCharacter

## Five Parsecs Character Factory - Single Source of Truth
## Consolidates all character creation functionality using factory pattern
## Replaces: BaseCharacterCreationSystem, BaseCharacterCreator, SimpleCharacterCreator
## Migration-safe with backward compatibility adapters

# Safe imports - using global autoloads where possible
const Character = preload("res://src/core/character/Character.gd")
const FiveParsecsCharacterGeneration = preload("res://src/core/character/CharacterGeneration.gd")
const CharacterCreationTables = preload("res://src/core/character/tables/CharacterCreationTables.gd")
# DataManager accessed via autoload singleton (not preload)

# Factory creation modes - unified from all three original creators
enum CreationMode {
	INITIAL_CREW,     # Campaign start crew members
	HIRE_CHARACTER,   # During campaign hiring
	GENERATE_NPC,     # For encounters and NPCs
	CAPTAIN,          # Campaign captain creation
	QUICK_GENERATION, # Fast random generation
	CUSTOM           # Full customization mode
}

# Creation context for different scenarios
enum CreationContext {
	CAMPAIGN_START,
	WORLD_PHASE_HIRING,
	BATTLE_NPC_GENERATION,
	TESTING_PURPOSES
}

# Unified signals for all creation scenarios
signal character_created(character: Character)
signal character_updated(character: Character)
signal creation_cancelled()
signal validation_failed(errors: Array[String])
signal generation_completed(character: Character)

# Factory data
var creation_tables: CharacterCreationTables
var data_manager: Node  # DataManager autoload
var character_generation: FiveParsecsCharacterGeneration

func _init() -> void:
	# Initialize core systems
	creation_tables = CharacterCreationTables.new()
	data_manager = Engine.get_main_loop().root.get_node_or_null("/root/DataManager") if Engine.get_main_loop() else null
	character_generation = FiveParsecsCharacterGeneration.new()
	
	print("FiveParsecsCharacter: Initialized consolidated character factory")

## Main Factory Method - Single entry point for all character creation
func create_character(mode: CreationMode, context: CreationContext = CreationContext.CAMPAIGN_START, params: Dictionary = {}) -> Character:
	## Unified character creation factory method
	## Replaces all previous character creator implementations
	print("FiveParsecsCharacter: Creating character with mode=%s, context=%s" % [CreationMode.keys()[mode], CreationContext.keys()[context]])
	
	var character: Character
	
	match mode:
		CreationMode.INITIAL_CREW:
			character = _create_initial_crew_member(params)
		CreationMode.HIRE_CHARACTER:
			character = _create_hired_character(params)
		CreationMode.GENERATE_NPC:
			character = _create_npc(params)
		CreationMode.CAPTAIN:
			character = _create_captain(params)
		CreationMode.QUICK_GENERATION:
			character = _create_quick_character(params)
		CreationMode.CUSTOM:
			character = _create_custom_character(params)
		_:
			push_error("FiveParsecsCharacter: Unknown creation mode: " + str(mode))
			return null
	
	if character:
		# Apply context-specific modifications
		_apply_creation_context(character, context, params)
		
		# Validate character data
		if _validate_character(character):
			character_created.emit(character)
			generation_completed.emit(character)
			return character
		else:
			var errors = ["Character validation failed"]
			validation_failed.emit(errors)
			push_error("FiveParsecsCharacter: Character validation failed")
			return null
	
	return null

## Character Creation Methods - Consolidated from all original creators

func _create_initial_crew_member(params: Dictionary) -> Character:
	## Create crew member for campaign start (from BaseCharacterCreationSystem)
	var character = Character.new()
	
	# Use Five Parsecs standard crew generation
	character.character_name = params.get("name", _generate_random_name())
	character.background = params.get("background", _roll_random_background())
	character.motivation = params.get("motivation", _roll_random_motivation())
	
	# Generate stats using Five Parsecs rules
	_generate_character_stats(character, "standard")
	
	# Assign starting equipment
	_assign_starting_equipment(character, "crew_member")
	
	return character

func _create_hired_character(params: Dictionary) -> Character:
	## Create character for hiring during campaign (from SimpleCharacterCreator logic)
	var character = Character.new()
	
	# Hired characters may have different generation rules
	character.character_name = params.get("name", _generate_random_name())
	character.background = params.get("background", _roll_random_background())
	character.motivation = params.get("motivation", _roll_random_motivation())
	
	# Stats may be slightly different for hired characters
	_generate_character_stats(character, "hired")
	
	# Basic equipment for hired characters
	_assign_starting_equipment(character, "hired")
	
	return character

func _create_npc(params: Dictionary) -> Character:
	## Create NPC for encounters and battles (new functionality)
	var character = Character.new()
	
	# NPCs can be more basic
	character.character_name = params.get("name", _generate_npc_name())
	character.background = params.get("background", _roll_random_background())
	
	# NPC stats may be simplified
	_generate_character_stats(character, "npc")
	
	# Minimal equipment for NPCs
	_assign_starting_equipment(character, "npc")
	
	return character

func _create_captain(params: Dictionary) -> Character:
	## Create campaign captain (from BaseCharacterCreator logic)
	var character = Character.new()
	
	# Captains may have enhanced generation
	character.character_name = params.get("name", _generate_random_name())
	character.background = params.get("background", _roll_random_background())
	character.motivation = params.get("motivation", _roll_random_motivation())
	
	# Captain gets enhanced stats
	_generate_character_stats(character, "captain")
	
	# Captain gets better starting equipment
	_assign_starting_equipment(character, "captain")
	
	return character

func _create_quick_character(params: Dictionary) -> Character:
	## Quick random generation for testing and NPCs
	var character = Character.new()
	
	# Fully randomized character
	character.character_name = _generate_random_name()
	character.background = _roll_random_background()
	character.motivation = _roll_random_motivation()
	
	_generate_character_stats(character, "quick")
	_assign_starting_equipment(character, "basic")
	
	return character

func _create_custom_character(params: Dictionary) -> Character:
	## Full customization mode with all options
	var character = Character.new()
	
	# Use provided parameters or defaults
	character.character_name = params.get("name", "")
	character.background = params.get("background", 0)
	character.motivation = params.get("motivation", 0)
	
	# Allow stat customization
	if params.has("stats"):
		var stats = params.stats
		character.combat = stats.get("combat", 1)
		character.toughness = stats.get("toughness", 1)
		character.savvy = stats.get("savvy", 1)
		character.tech = stats.get("tech", 1)
		character.speed = stats.get("speed", 1)
		character.luck = stats.get("luck", 1)
	else:
		_generate_character_stats(character, "standard")
	
	# Custom equipment if specified
	if params.has("equipment"):
		character.equipment = params.equipment
	else:
		_assign_starting_equipment(character, "standard")
	
	return character

## Support Methods - Consolidated and unified

func _apply_creation_context(character: Character, context: CreationContext, params: Dictionary) -> void:
	## Apply context-specific modifications to character
	match context:
		CreationContext.CAMPAIGN_START:
			# Campaign start characters may get bonus equipment
			pass
		CreationContext.WORLD_PHASE_HIRING:
			# Hired characters may cost credits
			character.hire_cost = params.get("hire_cost", 0)
		CreationContext.BATTLE_NPC_GENERATION:
			# Battle NPCs may have combat bonuses
			character.combat += params.get("combat_bonus", 0)
		CreationContext.TESTING_PURPOSES:
			# Testing characters may have debug flags
			character.is_test_character = true

func _generate_character_stats(character: Character, generation_type: String) -> void:
	## Generate character stats using Five Parsecs rules
	match generation_type:
		"standard", "crew_member":
			# Standard Five Parsecs stat generation (2d6/3 rounded up)
			character.combat = _roll_attribute()
			character.toughness = _roll_attribute()
			character.savvy = _roll_attribute()
			character.tech = _roll_attribute()
			character.speed = _roll_attribute()
			character.luck = _roll_attribute()
		"captain":
			# Captains get +1 to all stats
			character.combat = _roll_attribute() + 1
			character.toughness = _roll_attribute() + 1
			character.savvy = _roll_attribute() + 1
			character.tech = _roll_attribute() + 1
			character.speed = _roll_attribute() + 1
			character.luck = _roll_attribute() + 1
		"hired":
			# Hired characters use standard generation
			character.combat = _roll_attribute()
			character.toughness = _roll_attribute()
			character.savvy = _roll_attribute()
			character.tech = _roll_attribute()
			character.speed = _roll_attribute()
			character.luck = _roll_attribute()
		"npc":
			# NPCs get simplified stats
			var base_stat = 1 + randi() % 3  # 1-3
			character.combat = base_stat
			character.toughness = base_stat
			character.savvy = base_stat
			character.tech = base_stat
			character.speed = base_stat
			character.luck = base_stat
		"quick":
			# Quick generation uses random values
			character.combat = 1 + randi() % 6
			character.toughness = 1 + randi() % 6
			character.savvy = 1 + randi() % 6
			character.tech = 1 + randi() % 6
			character.speed = 1 + randi() % 6
			character.luck = 1 + randi() % 6

func _roll_attribute() -> int:
	## Roll 2d6, divide by 3, round up (Five Parsecs standard)
	var roll = (randi() % 6 + 1) + (randi() % 6 + 1)  # 2d6
	return int(ceil(float(roll) / 3.0))

func _assign_starting_equipment(character: Character, equipment_type: String) -> void:
	## Assign starting equipment based on character type
	# Simplified equipment assignment - can be expanded
	character.equipment = []
	
	match equipment_type:
		"captain":
			character.equipment.append("Military Rifle")
			character.equipment.append("Flak Screen")
			character.equipment.append("Stim Pack")
		"crew_member":
			character.equipment.append("Colony Rifle") 
			character.equipment.append("Scrap Pistol")
		"hired":
			character.equipment.append("Scrap Pistol")
		"npc", "basic":
			character.equipment.append("Scrap Pistol")

func _validate_character(character: Character) -> bool:
	## Validate character data integrity
	if character.character_name.is_empty():
		return false
	
	# Check stat ranges (1-6 typical for Five Parsecs)
	if character.combat < 1 or character.combat > 12:
		return false
	if character.toughness < 1 or character.toughness > 12:
		return false
	
	return true

func _generate_random_name() -> String:
	## Generate random character name
	var first_names = ["Alex", "Blake", "Casey", "Devon", "Ellis", "Finley", "Gray", "Harper"]
	var last_names = ["Steel", "Nova", "Cross", "Drake", "Stone", "Vale", "West", "Fox"]
	
	return first_names[randi() % first_names.size()] + " " + last_names[randi() % last_names.size()]

func _generate_npc_name() -> String:
	## Generate NPC-style names
	var npc_names = ["Guard", "Trader", "Mercenary", "Pilot", "Enforcer", "Scavenger", "Techie", "Gunner"]
	return npc_names[randi() % npc_names.size()] + " " + str(randi() % 100)

func _roll_random_background() -> int:
	## Roll random character background
	return randi() % 10  # Assuming 10 backgrounds

func _roll_random_motivation() -> int:
	## Roll random character motivation
	return randi() % 8   # Assuming 8 motivations

## Legacy Compatibility Methods - For smooth migration

func create_crew_member(params: Dictionary = {}) -> Character:
	## Legacy method for crew member creation
	return create_character(CreationMode.INITIAL_CREW, CreationContext.CAMPAIGN_START, params)

func create_captain(params: Dictionary = {}) -> Character:
	## Legacy method for captain creation
	return create_character(CreationMode.CAPTAIN, CreationContext.CAMPAIGN_START, params)

func generate_quick_character() -> Character:
	## Legacy method for quick generation
	return create_character(CreationMode.QUICK_GENERATION, CreationContext.TESTING_PURPOSES, {})