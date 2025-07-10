@tool
extends "res://src/core/character/Management/CharacterManager.gd"
class_name FPCM_GameCharacterManager

## Game-specific character manager implementation
##
## Extends the core character manager with game-specific
## functionality for the Five Parsecs From Home implementation.

# Define game-specific character class reference
const FPCM_CrewMember = preload("res://src/game/campaign/crew/FiveParsecsCrewMember.gd")

# Game-specific properties
var _faction_relations: Dictionary = {}
var _character_relationships: Dictionary = {}

func _ready() -> void:
	super._ready()

## Override create_character to use game-specific character class
func create_character(character_data: Dictionary = {}) -> CoreCharacter:
	var character: CoreCharacter = CoreCharacter.new()

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
		if character and character.has_method("get_morale"):
			char_morale = character.get_morale()
		elif character and character.has("morale"):
			char_morale = character.morale
		total_morale += char_morale

	return total_morale
## Safe property access helper - eliminates UNSAFE_METHOD_ACCESS warnings
## Based on Godot 4.4 best practices for safe property access
func safe_get_property(obj: Variant, property: String, default_value: Variant = null) -> Variant:
	if obj == null:
		return default_value
	if obj is Object and obj.has_method("get"):
		var value: Variant = obj.get(property)
		return value if value != null else default_value
	elif obj is Dictionary:
		return obj.get(property, default_value)
	return default_value
## Safe method call helper - eliminates UNSAFE_METHOD_ACCESS warnings
func safe_call_method(obj: Variant, method_name: String, args: Array = []) -> Variant:
	if obj == null:
		return null
	if obj is Object and obj.has_method(method_name):
		return obj.callv(method_name, args)
	return null