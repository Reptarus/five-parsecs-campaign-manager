@tool
extends Control

signal character_created(character)
signal character_edited(character)
signal creation_cancelled

const FiveParsecsCharacter = preload("res://src/core/character/Character.gd")
const FiveParsecsCharacterStats = preload("res://src/core/character/Base/CharacterStats.gd")
const FiveParsecsCharacterTableRoller = preload("res://src/core/character/Generation/CharacterTableRoller.gd")
enum CreatorMode {
	CHARACTER,
	CAPTAIN,
	INITIAL_CREW
}

# Maps CharacterStats enum values to flat property names on Character
const STAT_PROPERTY_MAP := {
	"COMBAT_SKILL": "combat",
	"REACTIONS": "reaction",
	"TOUGHNESS": "toughness",
	"SAVVY": "savvy",
	"LUCK": "luck",
	"SPEED": "speed",
}

var current_character
var creator_mode: CreatorMode = CreatorMode.CHARACTER
var _is_editing: bool = false
var current_bonuses: Dictionary = {
	"background": {},
	"class": {},
	"motivation": {}
}

func _init() -> void:
	current_character = FiveParsecsCharacter.new()

func start_creation(mode = CreatorMode.CHARACTER) -> void:
	if mode is bool:
		# Legacy compatibility: convert bool to enum
		creator_mode = CreatorMode.CAPTAIN if mode else CreatorMode.CHARACTER
	else:
		creator_mode = mode as CreatorMode
	_is_editing = false
	clear()
	show()

func edit_character(character: FiveParsecsCharacter) -> void:
	_is_editing = true
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
func _get_character_property(character, property: String, default_value = null) -> Variant:
	if not character:
		push_error("Trying to access property '%s' on null character" % property)
		return default_value
	if not property in character:
		return default_value
	return character.get(property)

func _set_character_property(character, property: String, value: Variant) -> void:
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

	# Copy flat stats directly
	current_character.combat = character.combat
	current_character.reaction = character.reaction
	current_character.toughness = character.toughness
	current_character.speed = character.speed
	current_character.savvy = character.savvy
	current_character.luck = character.luck

	_validate_character()

func _setup_captain_bonuses() -> void:
	if not current_character:
		return
	# Captain gets +1 combat and +1 luck (Five Parsecs core rules)
	current_character.combat = current_character.combat + 1
	current_character.luck = current_character.luck + 1

func _setup_initial_crew_bonuses() -> void:
	if not current_character:
		return
	# Initial crew members get standard starting stats (already default from .new())
	current_character.combat = 0
	current_character.reaction = 0
	current_character.toughness = 0
	current_character.speed = 4
	current_character.savvy = 0
	current_character.luck = 0

func _apply_stat_bonus(stat_key: String, bonus: int) -> void:
	## Apply a stat bonus using the CharacterStats enum key name
	var prop_name: String = STAT_PROPERTY_MAP.get(stat_key, "")
	if prop_name.is_empty() or not current_character:
		return
	var current_val: int = current_character.get(prop_name)
	current_character.set(prop_name, current_val + bonus)

func _remove_bonuses(bonus_dict: Dictionary) -> void:
	## Remove previously applied bonuses
	for stat_key in bonus_dict:
		_apply_stat_bonus(stat_key, -bonus_dict[stat_key])

func _apply_bonuses(bonus_dict: Dictionary) -> void:
	## Apply bonuses from a dictionary
	for stat_key in bonus_dict:
		_apply_stat_bonus(stat_key, bonus_dict[stat_key])

func _apply_background_bonuses(background_id: int) -> void:
	if not current_character:
		return

	# Remove previous background bonuses
	_remove_bonuses(current_bonuses.background)
	current_bonuses.background.clear()

	# Apply new background bonuses based on selection
	match background_id:
		GlobalEnums.Background.MILITARY:
			current_bonuses.background["COMBAT_SKILL"] = 1
		GlobalEnums.Background.ACADEMIC:
			current_bonuses.background["SAVVY"] = 1
		GlobalEnums.Background.CRIMINAL:
			current_bonuses.background["REACTIONS"] = 1

	# Apply new bonuses
	_apply_bonuses(current_bonuses.background)

func _apply_class_bonuses(class_id: int) -> void:
	if not current_character:
		return

	# Remove previous class bonuses
	_remove_bonuses(current_bonuses["class"])
	current_bonuses["class"].clear()

	# Apply new class bonuses based on selection
	match class_id:
		GlobalEnums.CharacterClass.SOLDIER:
			current_bonuses["class"]["COMBAT_SKILL"] = 1
			current_bonuses["class"]["TOUGHNESS"] = 1
		GlobalEnums.CharacterClass.MEDIC:
			current_bonuses["class"]["SAVVY"] = 1
		GlobalEnums.CharacterClass.ENGINEER:
			current_bonuses["class"]["SAVVY"] = 1
		GlobalEnums.CharacterClass.PILOT:
			current_bonuses["class"]["REACTIONS"] = 1
		GlobalEnums.CharacterClass.SECURITY:
			current_bonuses["class"]["COMBAT_SKILL"] = 1
			current_bonuses["class"]["REACTIONS"] = 1
		GlobalEnums.CharacterClass.BOT_TECH:
			current_bonuses["class"]["SAVVY"] = 1

	# Apply new bonuses
	_apply_bonuses(current_bonuses["class"])

func _apply_motivation_bonuses(motivation_id: int) -> void:
	if not current_character:
		return

	# Remove previous motivation bonuses
	_remove_bonuses(current_bonuses.motivation)
	current_bonuses.motivation.clear()

	# Motivations give narrative effects; a few grant direct stat bonuses.
	# Resource-based bonuses (credits, story points) are applied at campaign
	# level in CampaignFinalizationService, not here.
	match motivation_id:
		GlobalEnums.Motivation.GLORY:
			current_bonuses.motivation["COMBAT_SKILL"] = 1
		GlobalEnums.Motivation.SURVIVAL:
			current_bonuses.motivation["TOUGHNESS"] = 1
		GlobalEnums.Motivation.KNOWLEDGE:
			current_bonuses.motivation["SAVVY"] = 1
		# WEALTH: +1D6 credits applied in CampaignFinalizationService
		# FAME: +1 story point applied in CampaignFinalizationService

	# Apply new bonuses
	_apply_bonuses(current_bonuses.motivation)

func _validate_character() -> bool:
	if not current_character:
		return false

	var char_name = _get_character_property(current_character, "character_name", "")
	var is_valid = char_name.length() > 0

	return is_valid

func _on_confirm_pressed() -> void:
	if _validate_character():
		if _is_editing:
			character_edited.emit(current_character)
		else:
			character_created.emit(current_character)
		hide()

func _on_cancel_pressed() -> void:
	creation_cancelled.emit()
	hide()

func _on_randomize_pressed() -> void:
	if not current_character:
		return

	# Generate random character data
	_set_character_property(current_character, "character_name", FiveParsecsCharacterTableRoller.generate_random_name())
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
