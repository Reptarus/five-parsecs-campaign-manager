@tool
extends "res://src/core/character/Management/CharacterManager.gd"
# This file should be referenced via preload
# Use explicit preloads instead of global class names
const Self = preload("res://src/game/character/CharacterManager.gd")

## Game-specific character manager implementation
##
## Extends the core character manager with game-specific
## functionality for the Five Parsecs From Home implementation.

# Define game-specific character class reference
const FPCM_Character = preload("res://src/game/character/Character.gd")

# Game-specific properties
var _faction_relations: Dictionary = {}
var _character_relationships: Dictionary = {}

func _ready() -> void:
	super._ready()

## Override create_character to use game-specific character class
## Returns a character instance with game-specific implementation
func create_character():
	var character = FPCM_Character.new()
	add_character(character)
	return character

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
	
	for character in _active_characters:
		var char_morale = _get_character_property(character, "morale", 0)
		total_morale += char_morale
	
	return total_morale