extends Node

const Character = preload("res://Resources/CrewAndCharacters/Character.gd")
const CharacterNameGenerator = preload("res://Resources/CrewAndCharacters/CharacterNameGenerator.gd")

signal character_created(character: Character)
signal creation_cancelled

var game_state: GameState
var name_generator: CharacterNameGenerator
var current_character: Character

# Character creation data
var available_species := []
var available_backgrounds := []
var available_classes := []
var available_motivations := []

func _init() -> void:
	game_state = get_node("/root/GameStateManager").game_state
	name_generator = CharacterNameGenerator.new()
	_load_creation_data()

func _load_creation_data() -> void:
	# Updated to use correct enums
	available_species = GlobalEnums.Origin.values()
	available_backgrounds = GlobalEnums.Background.values()
	available_classes = GlobalEnums.Class.values()
	available_motivations = GlobalEnums.Motivation.values()

func start_character_creation(is_captain: bool = false) -> void:
	current_character = Character.new()
	current_character.is_captain = is_captain
	
	# Set default values
	randomize_character()

func randomize_character() -> void:
	if not current_character:
		return
		
	current_character.name = name_generator.generate_name()
	current_character.species = available_species[randi() % available_species.size()]
	current_character.background = available_backgrounds[randi() % available_backgrounds.size()]
	current_character.character_class = available_classes[randi() % available_classes.size()]
	current_character.motivation = available_motivations[randi() % available_motivations.size()]
	
	_apply_species_bonuses()
	_apply_background_effects()
	_apply_class_equipment()

func _apply_species_bonuses() -> void:
	match current_character.species:
		GlobalEnums.Origin.MILITARY:
			current_character.stats[GlobalEnums.CharacterStats.LUCK] += 1
		GlobalEnums.Origin.CORPORATE:
			current_character.stats[GlobalEnums.CharacterStats.TECHNICAL] += 1
		GlobalEnums.Origin.HYBRID:
			current_character.stats[GlobalEnums.CharacterStats.AGILITY] += 1
		GlobalEnums.Origin.MUTANT:
			current_character.stats[GlobalEnums.CharacterStats.STRENGTH] += 1
		GlobalEnums.Origin.ACADEMIC:
			current_character.stats[GlobalEnums.CharacterStats.INTELLIGENCE] += 1

func _apply_background_effects() -> void:
	match current_character.background:
		GlobalEnums.Background.SOLDIER:
			current_character.stats[GlobalEnums.CharacterStats.COMBAT_SKILL] += 1
		GlobalEnums.Background.MERCHANT:
			current_character.stats[GlobalEnums.CharacterStats.TECHNICAL] += 1
		GlobalEnums.Background.SCIENTIST:
			current_character.stats[GlobalEnums.CharacterStats.INTELLIGENCE] += 1
		GlobalEnums.Background.EXPLORER:
			current_character.stats[GlobalEnums.CharacterStats.SURVIVAL] += 1
		GlobalEnums.Background.OUTLAW:
			current_character.stats[GlobalEnums.CharacterStats.STEALTH] += 1
		GlobalEnums.Background.DIPLOMAT:
			current_character.stats[GlobalEnums.CharacterStats.SAVVY] += 1

func _apply_class_equipment() -> void:
	match current_character.character_class:
		GlobalEnums.Class.WARRIOR:
			_add_starting_equipment(GlobalEnums.WeaponType.SHELL_GUN, GlobalEnums.ArmorType.MEDIUM)
		GlobalEnums.Class.SCOUT:
			_add_starting_equipment(GlobalEnums.WeaponType.HUNTING_RIFLE, GlobalEnums.ArmorType.LIGHT)
		GlobalEnums.Class.TECH:
			_add_starting_equipment(GlobalEnums.WeaponType.HAND_GUN, GlobalEnums.ArmorType.LIGHT)
		GlobalEnums.Class.LEADER:
			_add_starting_equipment(GlobalEnums.WeaponType.HAND_GUN, GlobalEnums.ArmorType.LIGHT)
		GlobalEnums.Class.SPECIALIST:
			_add_starting_equipment(GlobalEnums.WeaponType.HAND_GUN, GlobalEnums.ArmorType.STEALTH)
		GlobalEnums.Class.SUPPORT:
			_add_starting_equipment(GlobalEnums.WeaponType.PLASMA_RIFLE, GlobalEnums.ArmorType.LIGHT)

func _add_starting_equipment(weapon_type: GlobalEnums.WeaponType, armor_type: GlobalEnums.ArmorType) -> void:
	if not game_state or not game_state.equipment_manager:
		push_error("Equipment manager not initialized")
		return
		
	var weapon = game_state.equipment_manager.create_weapon(weapon_type)
	var armor = game_state.equipment_manager.create_armor(armor_type)
	
	if weapon and armor and current_character:
		current_character.add_equipment(weapon)
		current_character.add_equipment(armor)
	else:
		push_error("Failed to add starting equipment")

func validate_character() -> bool:
	# Add validation logic
	return true

func finalize_character() -> void:
	if validate_character():
		character_created.emit(current_character)
		current_character = null
	else:
		push_error("Character validation failed")

func cancel_creation() -> void:
	current_character = null
	creation_cancelled.emit()
