extends Node

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
		GlobalEnums.Origin.HUMAN:
			current_character.stats.luck += 1
		GlobalEnums.Origin.SYNTHETIC:
			current_character.stats.technical += 1
		GlobalEnums.Origin.HYBRID:
			current_character.stats.agility += 1
		GlobalEnums.Origin.MUTANT:
			current_character.stats.strength += 1
		GlobalEnums.Origin.UPLIFTED:
			current_character.stats.intelligence += 1

func _apply_background_effects() -> void:
	match current_character.background:
		GlobalEnums.Background.MILITARY:
			current_character.stats.combat += 1
		GlobalEnums.Background.CORPORATE:
			current_character.stats.technical += 1
		GlobalEnums.Background.ACADEMIC:
			current_character.stats.intelligence += 1
		GlobalEnums.Background.FRONTIER:
			current_character.stats.survival += 1
		GlobalEnums.Background.CRIMINAL:
			current_character.stats.stealth += 1
		GlobalEnums.Background.NOMAD:
			current_character.stats.piloting += 1

func _apply_class_equipment() -> void:
	match current_character.character_class:
		GlobalEnums.Class.SOLDIER:
			_add_starting_equipment(GlobalEnums.WeaponType.MILITARY, GlobalEnums.ArmorType.MEDIUM)
		GlobalEnums.Class.SCOUT:
			_add_starting_equipment(GlobalEnums.WeaponType.RIFLE, GlobalEnums.ArmorType.LIGHT)
		GlobalEnums.Class.TECHNICIAN:
			_add_starting_equipment(GlobalEnums.WeaponType.PISTOL, GlobalEnums.ArmorType.LIGHT)
		GlobalEnums.Class.MEDIC:
			_add_starting_equipment(GlobalEnums.WeaponType.PISTOL, GlobalEnums.ArmorType.LIGHT)
		GlobalEnums.Class.DIPLOMAT:
			_add_starting_equipment(GlobalEnums.WeaponType.PISTOL, GlobalEnums.ArmorType.SCREEN)
		GlobalEnums.Class.PSION:
			_add_starting_equipment(GlobalEnums.WeaponType.SPECIAL, GlobalEnums.ArmorType.LIGHT)

func _add_starting_equipment(weapon_type: GlobalEnums.WeaponType, armor_type: GlobalEnums.ArmorType) -> void:
	var weapon = game_state.equipment_manager.create_weapon(weapon_type)
	var armor = game_state.equipment_manager.create_armor(armor_type)
	current_character.add_equipment(weapon)
	current_character.add_equipment(armor)

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
