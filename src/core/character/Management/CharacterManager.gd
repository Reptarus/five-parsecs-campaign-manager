@tool
extends Node

signal character_added(character)
signal character_updated(character)
signal character_removed(character_id: String)

const Character = preload("res://src/core/character/Base/Character.gd")
const CharacterBox = preload("res://src/core/character/Base/CharacterBox.gd")
const GameEnums = preload("res://src/core/systems/GlobalEnums.gd")
const MAX_CHARACTERS = 100

var _characters: Dictionary = {}
var _active_characters: Array = []

func _ready() -> void:
	pass

func create_character() -> Character:
	var character = Character.new()
	add_character(character)
	return character

func add_character(character) -> bool:
	if not character:
		return false
		
	if _characters.size() >= MAX_CHARACTERS:
		return false
		
	var char_id = _get_character_property(character, "id", "")
	if char_id.is_empty():
		push_error("Character missing required id property")
		return false
		
	_characters[char_id] = character
	if _get_character_property(character, "is_active", false):
		_active_characters.append(character)
	
	character_added.emit(character)
	return true

func update_character(character_id: String, character) -> bool:
	if not character_id in _characters:
		return false
		
	var char_id = _get_character_property(character, "id", "")
	if char_id.is_empty() or char_id != character_id:
		push_error("Character id mismatch or missing")
		return false
		
	_characters[character_id] = character
	_update_active_characters()
	
	character_updated.emit(character)
	return true

func remove_character(character_id: String) -> bool:
	if not character_id in _characters:
		return false
		
	var character = _characters[character_id]
	_characters.erase(character_id)
	_active_characters.erase(character)
	
	character_removed.emit(character_id)
	return true

func get_character(character_id: String):
	return _characters.get(character_id)

func has_character(character_id: String) -> bool:
	return character_id in _characters

func get_character_count() -> int:
	return _characters.size()

func get_active_characters() -> Array:
	return _active_characters.duplicate()

func set_character_class(character, char_class: int) -> void:
	if not character:
		return
		
	_set_character_property(character, "character_class", char_class)
	_initialize_class_stats(character)
	var char_id = _get_character_property(character, "id", "")
	if not char_id.is_empty():
		update_character(char_id, character)

func improve_stat(character, stat: int) -> void:
	if not character:
		return
		
	character.improve_stat(stat)
	var char_id = _get_character_property(character, "id", "")
	if not char_id.is_empty():
		update_character(char_id, character)

func add_experience(character, amount: int) -> void:
	if not character:
		return
		
	character.add_experience(amount)
	var char_id = _get_character_property(character, "id", "")
	if not char_id.is_empty():
		update_character(char_id, character)

func level_up(character) -> void:
	if not character:
		return
		
	character.level_up()
	var char_id = _get_character_property(character, "id", "")
	if not char_id.is_empty():
		update_character(char_id, character)

func _update_active_characters() -> void:
	_active_characters.clear()
	for character in _characters.values():
		if _get_character_property(character, "is_active", false):
			_active_characters.append(character)

func _initialize_class_stats(character) -> void:
	match _get_character_property(character, "character_class", GameEnums.CharacterClass.NONE):
		GameEnums.CharacterClass.NONE:
			_set_character_property(character, "base_stats", {
				GameEnums.CharacterStats.COMBAT_SKILL: 2,
				GameEnums.CharacterStats.TOUGHNESS: 3,
				GameEnums.CharacterStats.REACTIONS: 3,
				GameEnums.CharacterStats.TECH: 3
			})

## Safe Property Access Methods
func _get_character_property(character, property: String, default_value = null):
	if not character:
		push_error("Trying to access property '%s' on null character" % property)
		return default_value
	if not property in character:
		push_error("Character missing required property: %s" % property)
		return default_value
	return character.get(property)

func _set_character_property(character, property: String, value) -> void:
	if not character:
		push_error("Trying to set property '%s' on null character" % property)
		return
	if not property in character:
		push_error("Character missing required property: %s" % property)
		return
	character.set(property, value)
