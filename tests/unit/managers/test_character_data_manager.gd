## Character Data Manager Test Suite
## Tests the functionality of the character data manager including loading,
## saving, and modifying character data.
##
## Covers:
## - Character creation
## - Character property access and modification
## - Character data persistence
## - Character list management
@tool
extends "res://tests/fixtures/base/game_test.gd"

# Load scripts safely - handles missing files gracefully
var CharacterDataManagerScript = load("res://src/core/managers/character/CharacterDataManager.gd") if ResourceLoader.exists("res://src/core/managers/character/CharacterDataManager.gd") else load("res://src/core/managers/CharacterDataManager.gd") if ResourceLoader.exists("res://src/core/managers/CharacterDataManager.gd") else null
var CharacterDataScript = load("res://src/core/character/base/CharacterData.gd") if ResourceLoader.exists("res://src/core/character/base/CharacterData.gd") else load("res://src/core/character/CharacterData.gd") if ResourceLoader.exists("res://src/core/character/CharacterData.gd") else null
const Compatibility = preload("res://tests/fixtures/helpers/test_compatibility_helper.gd")

# Enums for tests
enum CharacterClass {SOLDIER = 0, MEDIC = 1, ENGINEER = 2, SCOUT = 3}
enum CharacterStatus {ACTIVE = 0, INJURED = 1, DEAD = 2}

# Type-safe constants
const TEST_CHARACTER_NAME = "Test Character"
const DEFAULT_CHARACTER_LEVEL = 1
const DEFAULT_CHARACTER_EXP = 0
const DEFAULT_STAT_VALUE = 10
const TEST_SAVE_LOCATION = "user://test_character_save.res"

# Type-safe instance variables
var _manager: Node = null
var _character: Resource = null

# Test setup and teardown
func before_each():
	super.before_each()
	_setup_manager()
	_character = _create_test_character()

func after_each():
	super.after_each()
	if _manager:
		_manager.queue_free()
	_manager = null
	_character = null
	# Clean up test saves
	var dir = DirAccess.open("user://")
	if dir and dir.file_exists("test_character_save.res"):
		dir.remove("test_character_save.res")

# Helper methods
func _setup_manager() -> void:
	if not CharacterDataManagerScript:
		push_error("CharacterDataManager script is null")
		return
		
	_manager = CharacterDataManagerScript.new()
	if not _manager:
		push_error("Failed to create character data manager")
		return
		
	add_child_autofree(_manager)
	track_test_node(_manager)

func _create_test_character(name: String = TEST_CHARACTER_NAME) -> Resource:
	if not CharacterDataScript:
		push_error("CharacterData script is null")
		return null
		
	var character: Resource = CharacterDataScript.new()
	if not character:
		push_error("Failed to create character data")
		return null
	
	# Ensure resource has a valid path for Godot 4.4
	character = Compatibility.ensure_resource_path(character, "test_character")
	
	# Set character properties safely
	Compatibility.safe_call_method(character, "set_name", [name])
	Compatibility.safe_call_method(character, "set_level", [DEFAULT_CHARACTER_LEVEL])
	Compatibility.safe_call_method(character, "set_experience", [DEFAULT_CHARACTER_EXP])
	Compatibility.safe_call_method(character, "set_class", [CharacterClass.SOLDIER])
	Compatibility.safe_call_method(character, "set_status", [CharacterStatus.ACTIVE])
	
	# Set basic stats
	var stats = {
		"strength": DEFAULT_STAT_VALUE,
		"dexterity": DEFAULT_STAT_VALUE,
		"constitution": DEFAULT_STAT_VALUE,
		"intelligence": DEFAULT_STAT_VALUE
	}
	
	for stat_name in stats:
		Compatibility.safe_call_method(character, "set_stat", [stat_name, stats[stat_name]])
	
	return character