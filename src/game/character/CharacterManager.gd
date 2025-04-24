@tool
extends Node
# Reference the base class via preload to avoid "Could not resolve class" error
const BaseCharacterManager = preload("res://src/core/character/management/CharacterManager.gd")

# This file should be referenced via preload
# Use explicit preloads instead of global class names
const Self = preload("res://src/game/character/CharacterManager.gd")

## Game-specific character manager implementation
##
## Extends the functionality of the core character manager
## for the Five Parsecs From Home implementation.

# Define game-specific character class reference
const FPCM_Character = preload("res://src/game/character/Character.gd")

# Character collections (same as in base CharacterManager)
var _characters = {}
var _active_characters = []
var _inactive_characters = []

# Game-specific properties
var _faction_relations: Dictionary = {}
var _character_relationships: Dictionary = {}
var _base_manager = null

func _init() -> void:
	# Initialize the base manager
	_base_manager = BaseCharacterManager.new()
	
	# Initialize collections
	_characters = {}
	_active_characters = []
	_inactive_characters = []

func _ready() -> void:
	# Initialization code
	pass

## Override create_character to use game-specific character class
## Returns a character instance with game-specific implementation
func create_character():
	var character = FPCM_Character.new()
	add_character(character)
	return character

# Delegate methods to base manager
func add_character(character) -> bool:
	return _base_manager.add_character(character)

func remove_character(character_id: String) -> bool:
	return _base_manager.remove_character(character_id)

func get_character(character_id: String):
	return _base_manager.get_character(character_id)

func has_character(character_id) -> bool:
	return _base_manager.has_character(character_id)

func _get_character_property(character, property: String, default_value = null):
	return _base_manager._get_character_property(character, property, default_value)

## Game-specific methods for managing relationships
func add_relationship(char_id1: String, char_id2: String, relation_type: int) -> void:
	if not _character_relationships.has(char_id1):
		_character_relationships[char_id1] = {}
	
	_character_relationships[char_id1][char_id2] = relation_type

func get_relationship(char_id1: String, char_id2: String) -> int:
	if not _character_relationships.has(char_id1):
		return 0
	
	return _character_relationships[char_id1].get(char_id2, 0)

## Game-specific method for calculating morale bonuses
func calculate_crew_morale() -> int:
	var total_morale = 0
	
	var active_characters = _base_manager.get_active_characters()
	for character in active_characters:
		var char_morale = _base_manager._get_character_property(character, "morale", 0)
		total_morale += char_morale
	
	return total_morale
