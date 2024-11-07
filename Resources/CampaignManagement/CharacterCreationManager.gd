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
	# Load available options from data files
	available_species = GlobalEnums.Species.values()
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
		GlobalEnums.Species.HUMAN:
			current_character.stats.luck += 1
		GlobalEnums.Species.ENGINEER:
			current_character.stats.technical += 1
		# Add other species bonuses...

func _apply_background_effects() -> void:
	match current_character.background:
		GlobalEnums.Background.MILITARY_BRAT:
			current_character.stats.combat += 1
		GlobalEnums.Background.MINING_COLONY:
			current_character.stats.technical += 1
		# Add other background effects...

func _apply_class_equipment() -> void:
	match current_character.character_class:
		GlobalEnums.Class.SOLDIER:
			current_character.add_starting_equipment("Military Rifle")
			current_character.add_starting_equipment("Combat Armor")
		GlobalEnums.Class.TECHNICIAN:
			current_character.add_starting_equipment("Repair Kit")
			current_character.add_starting_equipment("Tech Scanner")
		# Add other class equipment...

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
