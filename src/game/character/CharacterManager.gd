@tool
extends "res://src/core/character/Management/CharacterManager.gd"
class_name FPCM_GameCharacterManager

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
func create_character(character_data: Dictionary = {}) -> Character:
	var character := FPCM_Character.new()
	
	# Apply provided data or use defaults
	character.character_name = character_data.get("name", "New Character")
	character.character_class = character_data.get("class", 0)
	
	add_character_to_roster(character)
	character_created.emit(character)
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
	var total_morale: int = 0
	
	for character in active_crew:
		var char_morale: int = 0
		if character.has_method("get_morale"):
			char_morale = character.get_morale()
		elif character.has("morale"):
			char_morale = character.morale
		total_morale += char_morale
	
	return total_morale