@tool
extends Control

signal character_created(character: FiveParsecsCharacter)
signal character_edited(character: FiveParsecsCharacter)
signal creation_cancelled

const FiveParsecsCharacter = preload("res://src/game/character/Character.gd")
const GlobalEnums = preload("res://src/core/systems/GlobalEnums.gd")

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

func _set_character_property(character: FiveParsecsCharacter, property: String, _value: Variant) -> void:

	# Parameter validation - eliminates UNSAFE_CALL_ARGUMENT warnings
	if not is_instance_valid(self):
		return
	if not character:
		push_error("Trying to set property '%s' on null character" % property)
		return
	if not property in character:
		push_error("Character missing required property: %s" % property)
		return
	character.set(property, _value)

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

	_validate_character()

func _setup_captain_bonuses() -> void:
	if not current_character:
		return

	# Apply captain-specific bonuses
	current_character.combat += 1
	current_character.luck += 1

func _setup_initial_crew_bonuses() -> void:
	if not current_character:
		return

	# Initial crew members get standard starting stats
	# Reset to base values if needed

func _apply_background_bonuses(background_id: int) -> void:
	if not current_character:
		return

	# Remove previous background bonuses
	for stat in current_bonuses.background:
		var current_value = _get_character_property(current_character, stat, 0)
		_set_character_property(current_character, stat, current_value - current_bonuses.background[stat])

	current_bonuses.background.clear()

	# Apply new background bonuses based on selection
	match background_id:
		GlobalEnums.Background.MILITARY:
			current_bonuses.background["combat"] = 1
		GlobalEnums.Background.ACADEMIC:
			current_bonuses.background["savvy"] = 1
		GlobalEnums.Background.CRIMINAL:
			current_bonuses.background["reaction"] = 1

	# Apply new bonuses
	for stat in current_bonuses.background:
		var current_value = _get_character_property(current_character, stat, 0)
		_set_character_property(current_character, stat, current_value + current_bonuses.background[stat])

func _apply_class_bonuses(class_id: int) -> void:
	if not current_character:
		return

	# Remove previous class bonuses
	for stat in current_bonuses.class:
		var current_value = _get_character_property(current_character, stat, 0)
		_set_character_property(current_character, stat, current_value - current_bonuses.class [stat])

	current_bonuses.class.clear()

	# Apply new class bonuses based on selection
	match class_id:
		GlobalEnums.CharacterClass.SOLDIER:
			current_bonuses.class ["combat"] = 1
			current_bonuses.class ["toughness"] = 1
		GlobalEnums.CharacterClass.MEDIC:
			current_bonuses.class ["savvy"] = 1
		GlobalEnums.CharacterClass.ENGINEER:
			current_bonuses.class ["savvy"] = 1
		GlobalEnums.CharacterClass.PILOT:
			current_bonuses.class ["reaction"] = 1
		GlobalEnums.CharacterClass.SECURITY:
			current_bonuses.class ["combat"] = 1
			current_bonuses.class ["reaction"] = 1

	# Apply new bonuses
	for stat in current_bonuses.class:
		var current_value = _get_character_property(current_character, stat, 0)
		_set_character_property(current_character, stat, current_value + current_bonuses.class [stat])

func _apply_motivation_bonuses(motivation_id: int) -> void:
	if not current_character:
		return

	# Remove previous motivation bonuses
	for stat in current_bonuses.motivation:
		var current_value = _get_character_property(current_character, stat, 0)
		_set_character_property(current_character, stat, current_value - current_bonuses.motivation[stat])

	current_bonuses.motivation.clear()

	# Apply new motivation bonuses based on selection
	match motivation_id:
		GlobalEnums.Motivation.GLORY:
			current_bonuses.motivation["combat"] = 1
		GlobalEnums.Motivation.WEALTH:
			current_bonuses.motivation["savvy"] = 1
		GlobalEnums.Motivation.SURVIVAL:
			current_bonuses.motivation["reaction"] = 1

	# Apply new bonuses
	for stat in current_bonuses.motivation:
		var current_value = _get_character_property(current_character, stat, 0)
		_set_character_property(current_character, stat, current_value + current_bonuses.motivation[stat])

func _validate_character() -> bool:
	if not current_character:
		return false

	var node_name: String = _get_character_property(current_character, "character_name", "")
	var is_valid: bool = name.length() > 0

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
	_set_character_property(current_character, "character_name", _generate_random_name())
	_set_character_property(current_character, "origin", randi() % GlobalEnums.Origin.size())
	_set_character_property(current_character, "character_class", randi() % GlobalEnums.CharacterClass.size())

	# Generate background and motivation indices
	var background_index = randi() % GlobalEnums.Background.size()
	_set_character_property(current_character, "background", background_index)

	var motivation_index = randi() % GlobalEnums.Motivation.size()
	_set_character_property(current_character, "motivation", motivation_index)

	# Apply bonuses
	_apply_background_bonuses(background_index)
	_apply_class_bonuses(_get_character_property(current_character, "character_class", 0))
	_apply_motivation_bonuses(motivation_index)

	_validate_character()

func _generate_random_name() -> String:
	var names = ["Alex", "Jordan", "Morgan", "Casey", "Riley", "Sam", "Avery", "Quinn"]
	return names[randi() % names.size()]

## Safe method call helper - eliminates UNSAFE_METHOD_ACCESS warnings
func safe_call_method(obj: Variant, method_name: String, args: Array = []) -> Variant:
	if obj == null:
		return null
	if obj is Object and obj.has_method(method_name):
		return obj.callv(method_name, args)
	return null