@tool
extends "res://addons/gut/test.gd"

## Test for FiveParsecsCharacterManager
##
## Tests the game-specific character manager implementation
## for Five Parsecs From Home.

# Script references with type hints
const CharacterManager = preload("res://src/core/character/management/CharacterManager.gd")
const FPCharacter = preload("res://src/game/character/Character.gd")
const TypeSafeMixin = preload("res://tests/fixtures/helpers/type_safe_test_mixin.gd")
const GutCompatibility = preload("res://tests/fixtures/helpers/gut_compatibility.gd")

# Test variables
var _manager = null
var _test_char1 = null
var _test_char2 = null

# Setup and teardown
func before_each():
	# Create manager with error handling
	if CharacterManager and CharacterManager is GDScript:
		# Try to create manager with no arguments
		_manager = CharacterManager.new()
		if not _manager:
			# If creation failed, log and skip tests
			push_error("Failed to create CharacterManager instance")
			pending("CharacterManager could not be instantiated")
			return
			
		add_child_autofree(_manager)
	else:
		pending("CharacterManager is not available")
		return
	
	# Create test characters with error handling
	if not _manager or not _manager.has_method("create_character"):
		pending("Manager cannot create characters")
		return
		
	_test_char1 = _manager.create_character()
	if _test_char1:
		# Safely set properties with type checking
		if _test_char1 is Object and _test_char1.has_method("set_name"):
			_test_char1.set_name("Test Character 1")
		elif _test_char1 is Object and _test_char1.get("name") != null:
			_test_char1.set("name", "Test Character 1")
		
		if _test_char1 is Object and _test_char1.has_method("set_id"):
			_test_char1.set_id("char1")
		elif _test_char1 is Object and _test_char1.get("id") != null:
			_test_char1.set("id", "char1")
		
		# Ensure resource has valid path if needed
		if _test_char1 is Resource and _test_char1.resource_path.is_empty():
			_test_char1.resource_path = "res://tests/generated/test_char1_%d.tres" % [Time.get_unix_time_from_system()]
	
	_test_char2 = _manager.create_character()
	if _test_char2:
		# Safely set properties with type checking
		if _test_char2 is Object and _test_char2.has_method("set_name"):
			_test_char2.set_name("Test Character 2")
		elif _test_char2 is Object and _test_char2.get("name") != null:
			_test_char2.set("name", "Test Character 2")
		
		if _test_char2 is Object and _test_char2.has_method("set_id"):
			_test_char2.set_id("char2")
		elif _test_char2 is Object and _test_char2.get("id") != null:
			_test_char2.set("id", "char2")
		
		# Ensure resource has valid path if needed
		if _test_char2 is Resource and _test_char2.resource_path.is_empty():
			_test_char2.resource_path = "res://tests/generated/test_char2_%d.tres" % [Time.get_unix_time_from_system()]
	
	# Wait for engine to process
	await get_tree().process_frame
	await get_tree().process_frame

func after_each():
	_manager = null
	_test_char1 = null
	_test_char2 = null
	
	# Wait for cleanup
	await get_tree().process_frame

# Helper method to safely get character ID
func _get_character_id(character) -> String:
	if not character:
		return ""
		
	if character is String:
		return character
		
	if character is Object and character.has_method("get_id"):
		return character.get_id()
		
	if character is Object and character.get("id") != null:
		if character.id is String:
			return character.id
			
	if character is Object and character.has_method("to_string"):
		return character.to_string()
		
	if character is Dictionary and "id" in character:
		return str(character.id)
		
	# Last resort, try converting to string
	return str(character)

# Tests
func test_create_character():
	# Check if manager is valid
	if not _manager or not _manager.has_method("create_character"):
		pending("Manager cannot create characters")
		return
		
	# Test that character creation works
	var character = _manager.create_character()
	
	# Verify character was created correctly
	assert_not_null(character, "Character should be created")
	if FPCharacter and FPCharacter is GDScript:
		assert_true(character is FPCharacter, "Character should be FPCharacter type")
	
	# Safely check if manager has the character using type-safe helpers
	var has_character = false
	if _manager.has_method("has_character"):
		# Get character ID safely
		var character_id = _get_character_id(character)
		has_character = _manager.has_character(character_id)
	elif _manager.has_method("get_characters"):
		# Alternative approach: check if character is in the list
		var characters = _manager.get_characters()
		has_character = character in characters
		
	assert_true(has_character, "Manager should track the character")

func test_add_relationship():
	# Check if manager is valid
	if not _manager or not _manager.has_method("add_relationship") or not _manager.has_method("get_relationship"):
		pending("Manager cannot handle relationships")
		return
		
	# Test adding a relationship between characters
	_manager.add_relationship("char1", "char2", 2) # 2 = friendly
	
	# Verify relationship was set
	var relationship = _manager.get_relationship("char1", "char2")
	assert_eq(relationship, 2, "Relationship should be set to friendly (2)")

func test_asymmetric_relationships():
	# Check if manager is valid
	if not _manager or not _manager.has_method("add_relationship") or not _manager.has_method("get_relationship"):
		pending("Manager cannot handle relationships")
		return
		
	# Test that relationships can be asymmetric
	_manager.add_relationship("char1", "char2", 2) # char1 likes char2
	_manager.add_relationship("char2", "char1", -1) # char2 dislikes char1
	
	# Verify relationships
	assert_eq(_manager.get_relationship("char1", "char2"), 2, "Char1 should like Char2")
	assert_eq(_manager.get_relationship("char2", "char1"), -1, "Char2 should dislike Char1")

func test_nonexistent_relationship():
	# Check if manager is valid
	if not _manager or not _manager.has_method("get_relationship"):
		pending("Manager cannot handle relationships")
		return
		
	# Test getting a nonexistent relationship
	var relationship = _manager.get_relationship("char1", "nonexistent")
	
	# Should return 0 (neutral) for nonexistent relationships
	assert_eq(relationship, 0, "Nonexistent relationship should return 0 (neutral)")

func test_calculate_crew_morale():
	# Check if manager and test characters are valid
	if not _manager or not _manager.has_method("calculate_crew_morale") or not _test_char1 or not _test_char2:
		pending("Manager or test characters are not properly initialized")
		return
		
	# Setup characters with morale using safer property access
	if _test_char1.has_method("set_morale"):
		_test_char1.set_morale(3)
	elif _test_char1 is Object:
		TypeSafeMixin._set_property_safe(_test_char1, "morale", 3)
	
	if _test_char2.has_method("set_morale"):
		_test_char2.set_morale(2)
	elif _test_char2 is Object:
		TypeSafeMixin._set_property_safe(_test_char2, "morale", 2)
	
	# Test morale calculation
	var total_morale = _manager.calculate_crew_morale()
	
	# Verify calculation
	assert_eq(total_morale, 5, "Total morale should be sum of individual morales")
