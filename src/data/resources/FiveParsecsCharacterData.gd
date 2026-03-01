extends Resource
class_name FiveParsecsCharacterData

## Five Parsecs Character Data Resource
## Consolidated character creation and background data using Godot Resources
## Framework Bible compliant: Simple, type-safe, with built-in validation
## Replaces complex JSON loading with native Godot resource system

## Schema version for save file migration (CRITICAL for data integrity)
@export var schema_version: int = 1

# Character backgrounds data
@export var backgrounds: Array[CharacterBackground] = []
@export var motivations: Array[CharacterMotivation] = []
@export var species: Array[CharacterSpecies] = []
@export var traits: Array[CharacterTrait] = []

# Character creation tables
@export var stat_generation_rules: StatGenerationRules
@export var starting_equipment_tables: Array[EquipmentTable] = []
@export var name_generation_tables: NameGenerationTables

# Character progression data
@export var advancement_options: Array[AdvancementOption] = []
@export var skill_trees: Array[SkillTree] = []
@export var training_options: Array[TrainingOption] = []

## Character Background Resource
class CharacterBackground extends Resource:
	@export var id: int = 0
	@export var name: String = ""
	@export var description: String = ""
	@export var stat_modifiers: Dictionary = {}  # stat_name: modifier
	@export var starting_equipment: Array[String] = []
	@export var special_rules: Array[String] = []
	@export var connections_bonus: int = 0
	@export var credits_bonus: int = 0

## Character Motivation Resource  
class CharacterMotivation extends Resource:
	@export var id: int = 0
	@export var name: String = ""
	@export var description: String = ""
	@export var mechanical_benefit: String = ""
	@export var story_hooks: Array[String] = []

## Character Species Resource
class CharacterSpecies extends Resource:
	@export var id: int = 0
	@export var name: String = ""
	@export var description: String = ""
	@export var base_stats: Dictionary = {}  # stat_name: base_value
	@export var special_abilities: Array[String] = []
	@export var movement_speed: int = 6
	@export var armor_restrictions: Array[String] = []
	@export var equipment_restrictions: Array[String] = []
	@export var dlc_required: String = ""  # Empty = core rulebook, e.g. "trailblazers_toolkit"

## Character Trait Resource
class CharacterTrait extends Resource:
	@export var id: int = 0
	@export var name: String = ""
	@export var description: String = ""
	@export var effect: String = ""
	@export var prerequisite: String = ""
	@export var cost: int = 0

## Stat Generation Rules
class StatGenerationRules extends Resource:
	@export var method: String = "2d6_div_3"  # Five Parsecs standard
	@export var minimum_value: int = 1
	@export var maximum_value: int = 6
	@export var reroll_conditions: Array[String] = []
	@export var stat_names: Array[String] = ["Combat", "Toughness", "Savvy", "Speed", "Luck"]

## Equipment Table Resource
class EquipmentTable extends Resource:
	@export var table_name: String = ""
	@export var table_type: String = ""  # "starting", "background", "species"
	@export var equipment_entries: Array[EquipmentEntry] = []

class EquipmentEntry extends Resource:
	@export var roll_range: Vector2i = Vector2i(1, 6)
	@export var equipment_name: String = ""
	@export var quantity: int = 1
	@export var condition: String = ""  # Optional condition

## Name Generation Tables
class NameGenerationTables extends Resource:
	@export var human_first_names: Array[String] = []
	@export var human_last_names: Array[String] = []
	@export var alien_names: Array[String] = []
	@export var nickname_prefixes: Array[String] = []
	@export var nickname_suffixes: Array[String] = []

## Character Advancement Resources
class AdvancementOption extends Resource:
	@export var id: int = 0
	@export var name: String = ""
	@export var description: String = ""
	@export var cost: int = 1
	@export var effect: String = ""
	@export var prerequisites: Array[String] = []

class SkillTree extends Resource:
	@export var tree_name: String = ""
	@export var skills: Array[Skill] = []

class Skill extends Resource:
	@export var name: String = ""
	@export var description: String = ""
	@export var tier: int = 1
	@export var cost: int = 2
	@export var prerequisites: Array[String] = []

class TrainingOption extends Resource:
	@export var name: String = ""
	@export var description: String = ""
	@export var cost: int = 1
	@export var duration: int = 1  # Campaign turns
	@export var effect: String = ""

## Data Access Methods - Simple and direct

func get_background_by_id(background_id: int) -> CharacterBackground:
	## Get character background by ID
	for background in backgrounds:
		if background.id == background_id:
			return background
	return null

func get_background_by_name(background_name: String) -> CharacterBackground:
	## Get character background by name
	for background in backgrounds:
		if background.name == background_name:
			return background
	return null

func get_motivation_by_id(motivation_id: int) -> CharacterMotivation:
	## Get character motivation by ID
	for motivation in motivations:
		if motivation.id == motivation_id:
			return motivation
	return null

func get_species_by_id(species_id: int) -> CharacterSpecies:
	## Get character species by ID
	for species_entry in species:
		if species_entry.id == species_id:
			return species_entry
	return null

func roll_random_background() -> CharacterBackground:
	## Roll random character background
	if backgrounds.is_empty():
		return null
	return backgrounds[randi() % backgrounds.size()]

func roll_random_motivation() -> CharacterMotivation:
	## Roll random character motivation
	if motivations.is_empty():
		return null
	return motivations[randi() % motivations.size()]

func roll_random_species() -> CharacterSpecies:
	## Roll random character species
	if species.is_empty():
		return null
	return species[randi() % species.size()]

func generate_random_name(species_name: String = "Human") -> String:
	## Generate random character name
	if not name_generation_tables:
		return "Generated Character"
	
	match species_name.to_lower():
		"human":
			var first = name_generation_tables.human_first_names
			var last = name_generation_tables.human_last_names
			if first.is_empty() or last.is_empty():
				return "Human Character"
			return first[randi() % first.size()] + " " + last[randi() % last.size()]
		_:
			var alien = name_generation_tables.alien_names
			if alien.is_empty():
				return "Alien Character"
			return alien[randi() % alien.size()]

func get_starting_equipment(background_id: int) -> Array[String]:
	## Get starting equipment for background
	var background = get_background_by_id(background_id)
	if background:
		return background.starting_equipment
	return []

func get_equipment_table(table_name: String) -> EquipmentTable:
	## Get equipment table by name
	for table in starting_equipment_tables:
		if table.table_name == table_name:
			return table
	return null

func roll_on_equipment_table(table_name: String) -> String:
	## Roll on equipment table and return result
	var table = get_equipment_table(table_name)
	if not table:
		return ""
	
	var roll = randi() % 6 + 1
	for entry in table.equipment_entries:
		if roll >= entry.roll_range.x and roll <= entry.roll_range.y:
			return entry.equipment_name
	
	return ""

## Validation Methods

func validate_data() -> Array[String]:
	## Validate character data integrity
	var errors: Array[String] = []
	
	# Check backgrounds
	if backgrounds.is_empty():
		errors.append("No character backgrounds defined")
	else:
		for background in backgrounds:
			if background.name.is_empty():
				errors.append("Background %d has no name" % background.id)
	
	# Check motivations
	if motivations.is_empty():
		errors.append("No character motivations defined")
	else:
		for motivation in motivations:
			if motivation.name.is_empty():
				errors.append("Motivation %d has no name" % motivation.id)
	
	# Check species
	if species.is_empty():
		errors.append("No character species defined")
	else:
		for species_entry in species:
			if species_entry.name.is_empty():
				errors.append("Species %d has no name" % species_entry.id)
	
	# Check stat generation rules
	if not stat_generation_rules:
		errors.append("No stat generation rules defined")
	elif stat_generation_rules.stat_names.is_empty():
		errors.append("No stat names defined in generation rules")
	
	return errors

func is_valid() -> bool:
	## Check if character data is valid
	return validate_data().is_empty()

## Factory Methods for Default Data

static func create_default_character_data() -> FiveParsecsCharacterData:
	## Create character data with Five Parsecs defaults
	var data = FiveParsecsCharacterData.new()
	
	# Create default backgrounds
	data.backgrounds = _create_default_backgrounds()
	data.motivations = _create_default_motivations()
	data.species = _create_default_species()
	data.stat_generation_rules = _create_default_stat_rules()
	data.name_generation_tables = _create_default_name_tables()
	
	return data

static func _create_default_backgrounds() -> Array[CharacterBackground]:
	## Create Five Parsecs default backgrounds
	var backgrounds: Array[CharacterBackground] = []
	
	var military = CharacterBackground.new()
	military.id = 0
	military.name = "Military"
	military.description = "Former military service"
	military.stat_modifiers = {"Combat": 1}
	military.starting_equipment = ["Military Rifle", "Flak Screen"]
	backgrounds.append(military)
	
	var trader = CharacterBackground.new()
	trader.id = 1
	trader.name = "Trader"
	trader.description = "Commercial background"
	trader.credits_bonus = 2
	trader.starting_equipment = ["Trade Goods"]
	backgrounds.append(trader)
	
	var colonist = CharacterBackground.new()
	colonist.id = 2
	colonist.name = "Colonist"
	colonist.description = "Frontier colony background"
	colonist.stat_modifiers = {"Savvy": 1}
	colonist.starting_equipment = ["Colony Rifle", "Tool Kit"]
	backgrounds.append(colonist)
	
	return backgrounds

static func _create_default_motivations() -> Array[CharacterMotivation]:
	## Create Five Parsecs default motivations
	var motivations: Array[CharacterMotivation] = []
	
	var fortune = CharacterMotivation.new()
	fortune.id = 0
	fortune.name = "Fortune"
	fortune.description = "Seeking wealth and prosperity"
	fortune.mechanical_benefit = "+1 Credit from trade"
	motivations.append(fortune)
	
	var adventure = CharacterMotivation.new()
	adventure.id = 1
	adventure.name = "Adventure"
	adventure.description = "Thrill-seeking and exploration"
	adventure.mechanical_benefit = "+1 XP from missions"
	motivations.append(adventure)
	
	return motivations

static func _create_default_species() -> Array[CharacterSpecies]:
	## Create Five Parsecs default species
	var species_list: Array[CharacterSpecies] = []
	
	var human = CharacterSpecies.new()
	human.id = 0
	human.name = "Human"
	human.description = "Standard human"
	human.base_stats = {"Combat": 1, "Toughness": 1, "Savvy": 1, "Speed": 6, "Luck": 1}
	human.movement_speed = 6
	species_list.append(human)

	# Compendium DLC species (gated by DLCManager)
	var dlc_mgr = Engine.get_main_loop().root.get_node_or_null("/root/DLCManager") if Engine.get_main_loop() else null

	if dlc_mgr and dlc_mgr.is_feature_enabled(dlc_mgr.ContentFlag.SPECIES_KRAG):
		var krag = CharacterSpecies.new()
		krag.id = 1
		krag.name = "Krag"
		krag.description = "Tough, belligerent species. Cannot Dash. Reroll natural 1 vs Rivals."
		krag.base_stats = {"Reactions": 1, "Toughness": 4, "Speed": 4}
		krag.movement_speed = 4
		krag.special_abilities = ["no_dash", "reroll_vs_rivals", "always_fights"]
		krag.armor_restrictions = ["requires_krag_modification"]
		krag.dlc_required = "trailblazers_toolkit"
		species_list.append(krag)

	if dlc_mgr and dlc_mgr.is_feature_enabled(dlc_mgr.ContentFlag.SPECIES_SKULKER):
		var skulker = CharacterSpecies.new()
		skulker.id = 2
		skulker.name = "Skulker"
		skulker.description = "Fast, agile species. Ignores difficult ground and low obstacles. Resists poison."
		skulker.base_stats = {"Reactions": 1, "Toughness": 3, "Speed": 6}
		skulker.movement_speed = 6
		skulker.special_abilities = ["ignore_difficult_ground", "ignore_low_obstacles", "climb_discount", "biological_resistance", "universal_armor"]
		skulker.dlc_required = "trailblazers_toolkit"
		species_list.append(skulker)

	return species_list

static func _create_default_stat_rules() -> StatGenerationRules:
	## Create Five Parsecs stat generation rules
	var rules = StatGenerationRules.new()
	rules.method = "2d6_div_3"
	rules.minimum_value = 1
	rules.maximum_value = 6
	rules.stat_names = ["Combat", "Toughness", "Savvy", "Speed", "Luck"]
	return rules

static func _create_default_name_tables() -> NameGenerationTables:
	## Create default name generation tables
	var tables = NameGenerationTables.new()
	tables.human_first_names = ["Alex", "Blake", "Casey", "Devon", "Ellis"]
	tables.human_last_names = ["Steel", "Nova", "Cross", "Drake", "Stone"]
	tables.alien_names = ["Zyx", "Qeth", "Vrin", "Lok", "Tesh"]
	return tables
