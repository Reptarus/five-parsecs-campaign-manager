@tool
extends "res://addons/gut/test.gd"

## Test for FiveParsecsCharacterManager
##
## Tests the game-specific character manager implementation
## for Five Parsecs From Home.

# Script references with type hints
const CharacterManager = preload("res://src/game/character/CharacterManager.gd")
const FPCharacter = preload("res://src/game/character/Character.gd")

# Test variables
var _manager = null
var _test_char1 = null
var _test_char2 = null

# Setup and teardown
func before_each():
	_manager = CharacterManager.new()
	add_child_autofree(_manager)
	
	# Create test characters
	_test_char1 = _manager.create_character()
	_test_char1.name = "Test Character 1"
	_test_char1.id = "char1"
	
	_test_char2 = _manager.create_character()
	_test_char2.name = "Test Character 2"
	_test_char2.id = "char2"
	
	# Wait for engine to process
	await get_tree().process_frame
	await get_tree().process_frame

func after_each():
	_manager = null
	_test_char1 = null
	_test_char2 = null
	
	# Wait for cleanup
	await get_tree().process_frame

# Tests
func test_create_character():
	# Test that character creation works
	var character = _manager.create_character()
	
	# Verify character was created correctly
	assert_not_null(character, "Character should be created")
	assert_true(character is FPCharacter, "Character should be FPCharacter type")
	assert_true(_manager.has_character(character), "Manager should track the character")

func test_add_relationship():
	# Test adding a relationship between characters
	_manager.add_relationship("char1", "char2", 2) # 2 = friendly
	
	# Verify relationship was set
	var relationship = _manager.get_relationship("char1", "char2")
	assert_eq(relationship, 2, "Relationship should be set to friendly (2)")

func test_asymmetric_relationships():
	# Test that relationships can be asymmetric
	_manager.add_relationship("char1", "char2", 2) # char1 likes char2
	_manager.add_relationship("char2", "char1", -1) # char2 dislikes char1
	
	# Verify relationships
	assert_eq(_manager.get_relationship("char1", "char2"), 2, "Char1 should like Char2")
	assert_eq(_manager.get_relationship("char2", "char1"), -1, "Char2 should dislike Char1")

func test_nonexistent_relationship():
	# Test getting a nonexistent relationship
	var relationship = _manager.get_relationship("char1", "nonexistent")
	
	# Should return 0 (neutral) for nonexistent relationships
	assert_eq(relationship, 0, "Nonexistent relationship should return 0 (neutral)")

func test_calculate_crew_morale():
	# Setup characters with morale
	_test_char1.set("morale", 3)
	_test_char2.set("morale", 2)
	
	# Test morale calculation
	var total_morale = _manager.calculate_crew_morale()
	
	# Verify calculation
	assert_eq(total_morale, 5, "Total morale should be sum of individual morales")
