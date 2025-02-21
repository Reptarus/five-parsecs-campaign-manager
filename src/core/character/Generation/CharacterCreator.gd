@tool
extends Control

signal character_created(character: FiveParsecsCharacter)
signal character_edited(character: FiveParsecsCharacter)
signal creation_cancelled

const FiveParsecsCharacter = preload("res://src/core/character/Base/Character.gd")
const FiveParsecsCharacterStats = preload("res://src/core/character/Base/CharacterStats.gd")
const FiveParsecsCharacterTableRoller = preload("res://src/core/character/Generation/CharacterTableRoller.gd")
const GameEnums = preload("res://src/core/systems/GlobalEnums.gd")

enum CreatorMode {
	CHARACTER,
	CAPTAIN,
	INITIAL_CREW
}

var current_character: FiveParsecsCharacter
var creator_mode: CreatorMode = CreatorMode.CHARACTER
var current_bonuses: Dictionary = {
	"background": {},
	"class": {},
	"motivation": {}
}

func _init() -> void:
	current_character = FiveParsecsCharacter.new()

func start_creation(is_captain: bool = false) -> void:
	creator_mode = CreatorMode.CAPTAIN if is_captain else CreatorMode.CHARACTER
	clear()
	show()

func edit_character(character: FiveParsecsCharacter) -> void:
	current_character = character
	_load_character_data(character)
	show()

func clear() -> void:
	current_character = FiveParsecsCharacter.new()
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

## Safe Property Access Methods
func _get_character_property(character: FiveParsecsCharacter, property: String, default_value = null) -> Variant:
	if not character:
		push_error("Trying to access property '%s' on null character" % property)
		return default_value
	if not property in character:
		push_error("Character missing required property: %s" % property)
		return default_value
	return character.get(property)

func _set_character_property(character: FiveParsecsCharacter, property: String, value: Variant) -> void:
	if not character:
		push_error("Trying to set property '%s' on null character" % property)
		return
	if not property in character:
		push_error("Character missing required property: %s" % property)
		return
	character.set(property, value)

func _load_character_data(character: FiveParsecsCharacter) -> void:
	if not character:
		push_error("Invalid character provided for editing")
		return
	
	_set_character_property(current_character, "character_name", _get_character_property(character, "character_name", ""))
	_set_character_property(current_character, "origin", _get_character_property(character, "origin", 0))
	_set_character_property(current_character, "character_class", _get_character_property(character, "character_class", 0))
	_set_character_property(current_character, "background", _get_character_property(character, "background", 0))
	_set_character_property(current_character, "motivation", _get_character_property(character, "motivation", 0))
	_set_character_property(current_character, "portrait_path", _get_character_property(character, "portrait_path", ""))
	
	var stats = _get_character_property(character, "stats", null)
	if stats:
		_set_character_property(current_character, "stats", stats.duplicate())
	
	_validate_character()

func _setup_captain_bonuses() -> void:
	if not current_character:
		return
		
	var stats = _get_character_property(current_character, "stats", null)
	if not stats:
		push_error("Character missing stats property")
		return
		
	# Apply captain-specific bonuses
	_set_character_property(stats, "combat_skill", _get_character_property(stats, "combat_skill", 0) + 1)
	_set_character_property(stats, "luck", _get_character_property(stats, "luck", 0) + 1)

func _setup_initial_crew_bonuses() -> void:
	if not current_character:
		return
		
	var stats = _get_character_property(current_character, "stats", null)
	if not stats:
		push_error("Character missing stats property")
		return
		
	# Initial crew members get standard starting stats
	if "reset_to_base_stats" in stats:
		stats.reset_to_base_stats()

func _apply_background_bonuses(background_id: int) -> void:
	if not current_character:
		return
		
	var stats = _get_character_property(current_character, "stats", null)
	if not stats:
		push_error("Character missing stats property")
		return
	
	# Remove previous background bonuses
	for stat in current_bonuses.background:
		if "apply_stat_bonus" in stats:
			stats.apply_stat_bonus(stat, -current_bonuses.background[stat])
	
	current_bonuses.background.clear()
	
	# Apply new background bonuses based on selection
	match background_id:
		GameEnums.Background.MILITARY:
			current_bonuses.background[str(GameEnums.CharacterStats.COMBAT_SKILL)] = 1
		GameEnums.Background.ACADEMIC:
			current_bonuses.background[str(GameEnums.CharacterStats.SAVVY)] = 1
		GameEnums.Background.CRIMINAL:
			current_bonuses.background[str(GameEnums.CharacterStats.REACTIONS)] = 1
	
	# Apply new bonuses
	for stat in current_bonuses.background:
		if "apply_stat_bonus" in stats:
			stats.apply_stat_bonus(stat, current_bonuses.background[stat])

func _apply_class_bonuses(class_id: int) -> void:
	if not current_character:
		return
		
	var stats = _get_character_property(current_character, "stats", null)
	if not stats:
		push_error("Character missing stats property")
		return
	
	# Remove previous class bonuses
	for stat in current_bonuses. class:
		if "apply_stat_bonus" in stats:
			stats.apply_stat_bonus(stat, -current_bonuses. class [stat])
	
	current_bonuses. class .clear()
	
	# Apply new class bonuses based on selection
	match class_id:
		GameEnums.CharacterClass.SOLDIER:
			current_bonuses. class [str(GameEnums.CharacterStats.COMBAT_SKILL)] = 1
			current_bonuses. class [str(GameEnums.CharacterStats.TOUGHNESS)] = 1
		GameEnums.CharacterClass.MEDIC:
			current_bonuses. class [str(GameEnums.CharacterStats.SAVVY)] = 1
			current_bonuses. class [str(GameEnums.CharacterStats.SOCIAL)] = 1
		GameEnums.CharacterClass.ENGINEER:
			current_bonuses. class [str(GameEnums.CharacterStats.TECH)] = 1
			current_bonuses. class [str(GameEnums.CharacterStats.SAVVY)] = 1
		GameEnums.CharacterClass.PILOT:
			current_bonuses. class [str(GameEnums.CharacterStats.NAVIGATION)] = 1
			current_bonuses. class [str(GameEnums.CharacterStats.REACTIONS)] = 1
		GameEnums.CharacterClass.SECURITY:
			current_bonuses. class [str(GameEnums.CharacterStats.COMBAT_SKILL)] = 1
			current_bonuses. class [str(GameEnums.CharacterStats.REACTIONS)] = 1
		GameEnums.CharacterClass.BOT_TECH:
			current_bonuses. class [str(GameEnums.CharacterStats.TECH)] = 1
			current_bonuses. class [str(GameEnums.CharacterStats.SAVVY)] = 1
	
	# Apply new bonuses
	for stat in current_bonuses. class:
		if "apply_stat_bonus" in stats:
			stats.apply_stat_bonus(stat, current_bonuses. class [stat])

func _apply_motivation_bonuses(motivation_id: int) -> void:
	if not current_character:
		return
		
	var stats = _get_character_property(current_character, "stats", null)
	if not stats:
		push_error("Character missing stats property")
		return
	
	# Remove previous motivation bonuses
	for stat in current_bonuses.motivation:
		if "apply_stat_bonus" in stats:
			stats.apply_stat_bonus(stat, -current_bonuses.motivation[stat])
	
	current_bonuses.motivation.clear()
	
	# Apply new motivation bonuses based on selection
	match motivation_id:
		GameEnums.Motivation.GLORY:
			current_bonuses.motivation[str(GameEnums.CharacterStats.COMBAT_SKILL)] = 1
		GameEnums.Motivation.WEALTH:
			current_bonuses.motivation[str(GameEnums.CharacterStats.SAVVY)] = 1
		GameEnums.Motivation.SURVIVAL:
			current_bonuses.motivation[str(GameEnums.CharacterStats.REACTIONS)] = 1
	
	# Apply new bonuses
	for stat in current_bonuses.motivation:
		if "apply_stat_bonus" in stats:
			stats.apply_stat_bonus(stat, current_bonuses.motivation[stat])

func _validate_character() -> bool:
	if not current_character:
		return false
		
	var name = _get_character_property(current_character, "character_name", "")
	var is_valid = name.length() > 0
	
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
	_set_character_property(current_character, "character_name", FiveParsecsCharacterTableRoller.generate_random_name())
	_set_character_property(current_character, "origin", randi() % GameEnums.Origin.size())
	_set_character_property(current_character, "character_class", randi() % GameEnums.CharacterClass.size())
	
	# Generate background and motivation indices
	var background_index = randi() % GameEnums.Background.size()
	_set_character_property(current_character, "background", background_index)
	
	var motivation_index = randi() % GameEnums.Motivation.size()
	_set_character_property(current_character, "motivation", motivation_index)
	
	# Apply bonuses
	_apply_background_bonuses(background_index)
	_apply_class_bonuses(_get_character_property(current_character, "character_class", 0))
	_apply_motivation_bonuses(motivation_index)
	
	_validate_character()
