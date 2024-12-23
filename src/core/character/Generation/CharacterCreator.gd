@tool
extends Control

signal character_created(character: Character)
signal character_edited(character: Character)
signal creation_cancelled

const Character = preload("res://src/core/character/Base/Character.gd")
const CharacterStats = preload("res://src/core/character/Base/CharacterStats.gd")
const CharacterTableRoller = preload("res://src/core/character/Generation/CharacterTableRoller.gd")
const GameEnums = preload("res://src/core/systems/GlobalEnums.gd")

enum CreatorMode {
	CHARACTER,
	CAPTAIN,
	INITIAL_CREW
}

var current_character: Character
var creator_mode: CreatorMode = CreatorMode.CHARACTER
var current_bonuses: Dictionary = {
	"background": {},
	"class": {},
	"motivation": {}
}

func _init() -> void:
	current_character = Character.new()

func start_creation(is_captain: bool = false) -> void:
	creator_mode = CreatorMode.CAPTAIN if is_captain else CreatorMode.CHARACTER
	clear()
	show()

func edit_character(character: Character) -> void:
	current_character = character
	_load_character_data(character)
	show()

func clear() -> void:
	current_character = Character.new()
	if creator_mode == CreatorMode.CAPTAIN:
		_setup_captain_bonuses()
	elif creator_mode == CreatorMode.INITIAL_CREW:
		_setup_initial_crew_bonuses()
	
	current_bonuses.clear()
	current_bonuses = {
		"background": {},
		"class": {},
		"motivation": {}
	}
	
	_validate_character()

func _load_character_data(character: Character) -> void:
	if not character:
		push_error("Invalid character provided for editing")
		return
	
	current_character.character_name = character.character_name
	current_character.origin = character.origin
	current_character.character_class = character.character_class
	current_character.background = character.background
	current_character.motivation = character.motivation
	current_character.portrait_path = character.portrait_path
	
	if character.stats:
		current_character.stats = character.stats.duplicate()
	
	_validate_character()

func _setup_captain_bonuses() -> void:
	if not current_character or not current_character.stats:
		return
	
	# Apply captain-specific bonuses
	current_character.stats.combat_skill += 1
	current_character.stats.luck += 1

func _setup_initial_crew_bonuses() -> void:
	if not current_character or not current_character.stats:
		return
	
	# Initial crew members get standard starting stats
	current_character.stats.reset_to_base_stats()

func _apply_background_bonuses(background_id: int) -> void:
	if not current_character or not current_character.stats:
		return
	
	# Remove previous background bonuses
	for stat in current_bonuses.background:
		current_character.stats.apply_stat_bonus(stat, -current_bonuses.background[stat])
	
	current_bonuses.background.clear()
	
	# Apply new background bonuses based on selection
	match background_id:
		GameEnums.CharacterBackground.MILITARY:
			current_bonuses.background[str(GameEnums.CharacterStats.COMBAT_SKILL)] = 1
		GameEnums.CharacterBackground.ACADEMIC:
			current_bonuses.background[str(GameEnums.CharacterStats.SAVVY)] = 1
		GameEnums.CharacterBackground.CRIMINAL:
			current_bonuses.background[str(GameEnums.CharacterStats.REACTIONS)] = 1
	
	# Apply new bonuses
	for stat in current_bonuses.background:
		current_character.stats.apply_stat_bonus(stat, current_bonuses.background[stat])

func _apply_class_bonuses(class_id: int) -> void:
	if not current_character or not current_character.stats:
		return
	
	# Remove previous class bonuses
	for stat in current_bonuses.class:
		current_character.stats.apply_stat_bonus(stat, -current_bonuses.class[stat])
	
	current_bonuses.class.clear()
	
	# Apply new class bonuses based on selection
	match class_id:
		GameEnums.CharacterClass.SOLDIER:
			current_bonuses.class[str(GameEnums.CharacterStats.COMBAT_SKILL)] = 1
			current_bonuses.class[str(GameEnums.CharacterStats.TOUGHNESS)] = 1
		GameEnums.CharacterClass.MEDIC:
			current_bonuses.class[str(GameEnums.CharacterStats.SAVVY)] = 1
			current_bonuses.class[str(GameEnums.CharacterStats.LUCK)] = 1
		GameEnums.CharacterClass.TECH:
			current_bonuses.class[str(GameEnums.CharacterStats.SAVVY)] = 1
			current_bonuses.class[str(GameEnums.CharacterStats.SPEED)] = 1
		GameEnums.CharacterClass.SCOUT:
			current_bonuses.class[str(GameEnums.CharacterStats.REACTIONS)] = 1
			current_bonuses.class[str(GameEnums.CharacterStats.SPEED)] = 1
		GameEnums.CharacterClass.LEADER:
			current_bonuses.class[str(GameEnums.CharacterStats.COMBAT_SKILL)] = 1
			current_bonuses.class[str(GameEnums.CharacterStats.LUCK)] = 1
		GameEnums.CharacterClass.SPECIALIST:
			current_bonuses.class[str(GameEnums.CharacterStats.SAVVY)] = 1
			current_bonuses.class[str(GameEnums.CharacterStats.COMBAT_SKILL)] = 1
	
	# Apply new bonuses
	for stat in current_bonuses.class:
		current_character.stats.apply_stat_bonus(stat, current_bonuses.class[stat])

func _apply_motivation_bonuses(motivation_id: int) -> void:
	if not current_character or not current_character.stats:
		return
	
	# Remove previous motivation bonuses
	for stat in current_bonuses.motivation:
		current_character.stats.apply_stat_bonus(stat, -current_bonuses.motivation[stat])
	
	current_bonuses.motivation.clear()
	
	# Apply new motivation bonuses based on selection
	match motivation_id:
		GameEnums.CharacterMotivation.GLORY:
			current_bonuses.motivation[str(GameEnums.CharacterStats.COMBAT_SKILL)] = 1
		GameEnums.CharacterMotivation.WEALTH:
			current_bonuses.motivation[str(GameEnums.CharacterStats.SAVVY)] = 1
		GameEnums.CharacterMotivation.SURVIVAL:
			current_bonuses.motivation[str(GameEnums.CharacterStats.REACTIONS)] = 1
	
	# Apply new bonuses
	for stat in current_bonuses.motivation:
		current_character.stats.apply_stat_bonus(stat, current_bonuses.motivation[stat])

func _validate_character() -> bool:
	var is_valid = current_character != null and \
				   current_character.character_name.length() > 0
	
	return is_valid

func _on_confirm_pressed() -> void:
	if _validate_character():
		if creator_mode == CreatorMode.CAPTAIN:
			character_created.emit(current_character)
		else:
			character_edited.emit(current_character)
		hide()

func _on_cancel_pressed() -> void:
	creation_cancelled.emit()
	hide()

func _on_randomize_pressed() -> void:
	if not current_character:
		return
	
	# Generate random character data
	current_character.character_name = CharacterTableRoller.generate_random_name()
	current_character.origin = randi() % GameEnums.Origin.size()
	current_character.character_class = randi() % GameEnums.CharacterClass.size()
	
	# Generate background and motivation indices
	var background_index = randi() % GameEnums.CharacterBackground.size()
	current_character.background = background_index
	
	var motivation_index = randi() % GameEnums.CharacterMotivation.size()
	current_character.motivation = motivation_index
	
	# Apply bonuses
	_apply_background_bonuses(background_index)
	_apply_class_bonuses(current_character.character_class)
	_apply_motivation_bonuses(motivation_index)
	
	_validate_character()
