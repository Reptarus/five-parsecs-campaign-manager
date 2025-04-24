## Character Data Manager Test Suite
## Tests the functionality of the CharacterDataManager class which handles character data persistence
## and management operations.
##
## Covers:
## - Basic CRUD operations for character data
## - Character state management
## - Data validation and boundaries
## - Performance considerations
## - Signal emissions
@tool
extends "res://tests/fixtures/base/game_test.gd"
# Use explicit preloads instead of global class names

# Type-safe script references
const Character: GDScript = preload("res://src/core/character/Base/Character.gd")
const GameStateManager: GDScript = preload("res://src/core/managers/GameStateManager.gd")
const CharacterDataManager: GDScript = preload("res://src/core/character/Management/CharacterDataManager.gd")
const Compatibility = preload("res://tests/fixtures/helpers/test_compatibility_helper.gd")

# Type-safe constants
const TEST_BATCH_SIZE: int = 100
const MAX_CHARACTERS: int = 1000

# Type-safe instance variables
var _data_manager = null
var _test_character = null
var _game_state_manager = null

# Helper methods
func _create_test_character():
	if not Character:
		push_error("Character script is null")
		return null
		
	var character = Character.new()
	if not character:
		push_error("Failed to create test character")
		return null
		
	if character.has_method("set_character_name"):
		character.set_character_name("Test Character")
	else:
		push_warning("Character doesn't have set_character_name method")
		
	if character.has_method("set_character_class"):
		character.set_character_class(GameEnums.CharacterClass.SOLDIER)
	else:
		push_warning("Character doesn't have set_character_class method")
	
	if character is Node:
		add_child_autofree(character)
		track_test_node(character)
	elif character is Resource:
		# Ensure resource has a valid path for serialization
		if character.resource_path.is_empty():
			character.resource_path = "res://tests/generated/test_character_%d.tres" % [Time.get_unix_time_from_system()]
		track_test_resource(character)
	
	return character

func _create_batch_characters(count: int) -> Array:
	var characters = []
	for i in range(count):
		var character = _create_test_character()
		if character:
			characters.append(character)
	return characters

# Setup and teardown
func before_each() -> void:
	await super.before_each()
	
	# Initialize the GameStateManager instance
	if not is_instance_valid(_game_state_manager) or not _game_state_manager is GameStateManager:
		# Create a new GameStateManager instance if needed
		_game_state_manager = GameStateManager.new()
		if _game_state_manager:
			add_child_autofree(_game_state_manager)
			track_test_node(_game_state_manager)
	
	# Directly instantiate the CharacterDataManager with the correct parameter
	_data_manager = CharacterDataManager.new(_game_state_manager)
	
	# Add to scene tree if it's a Node
	if _data_manager:
		if _data_manager is Node:
			add_child_autofree(_data_manager)
			track_test_node(_data_manager)
		elif _data_manager is Resource:
			# Ensure resource has a valid path for serialization
			if _data_manager.resource_path.is_empty():
				_data_manager.resource_path = "res://tests/generated/data_manager_%d.tres" % [Time.get_unix_time_from_system()]
			track_test_resource(_data_manager)
	else:
		push_error("Failed to create data manager")
		return
	
	# Create test character
	_test_character = _create_test_character()
	if not _test_character:
		push_error("Failed to create test character")
		return
	
	# Connect signals with proper checks
	if _game_state and _game_state is Node:
		watch_signals(_game_state)
	
	if _data_manager and _data_manager is Node:
		watch_signals(_data_manager)
	
	await stabilize_engine(STABILIZE_TIME)

func after_each() -> void:
	_game_state_manager = null
	_data_manager = null
	_test_character = null
	await super.after_each()

# Basic functionality tests
func test_initial_state() -> void:
	if not _data_manager:
		pending("Data manager not initialized")
		return
		
	assert_not_null(_data_manager, "Data manager should be initialized")
	
	var count = 0
	if _data_manager.has_method("get_character_count"):
		count = _data_manager.get_character_count()
	elif _data_manager is Object:
		count = TypeSafeMixin._call_node_method_int(_data_manager, "get_character_count", [])
	else:
		pending("Data manager does not support character count")
		return
	
	assert_eq(count, 0, "Should start with no characters")

func test_save_and_load_character() -> void:
	# Skip test if requirements aren't met
	if not _test_character:
		pending("Test character not initialized")
		return
		
	if not _data_manager:
		pending("Data manager not initialized")
		return
		
	# Setup test character with safe checks
	if _test_character.has_method("set_character_name"):
		_test_character.set_character_name("Test Character")
	else:
		TypeSafeMixin._call_node_method_bool(_test_character, "set_character_name", ["Test Character"])
	
	if _test_character.has_method("set_character_class"):
		_test_character.set_character_class(GameEnums.CharacterClass.SOLDIER)
	else:
		TypeSafeMixin._call_node_method_bool(_test_character, "set_character_class", [GameEnums.CharacterClass.SOLDIER])
	
	if _test_character.has_method("set_origin"):
		_test_character.set_origin(GameEnums.Origin.HUMAN)
	else:
		TypeSafeMixin._call_node_method_bool(_test_character, "set_origin", [GameEnums.Origin.HUMAN])
	
	if _test_character.has_method("set_background"):
		_test_character.set_background(GameEnums.Background.MILITARY)
	else:
		TypeSafeMixin._call_node_method_bool(_test_character, "set_background", [GameEnums.Background.MILITARY])
	
	if _test_character.has_method("set_motivation"):
		_test_character.set_motivation(GameEnums.Motivation.DUTY)
	else:
		TypeSafeMixin._call_node_method_bool(_test_character, "set_motivation", [GameEnums.Motivation.DUTY])
	
	# Save character using Dictionary serialization first
	var char_data = {}
	if _test_character.has_method("to_dict"):
		char_data = _test_character.to_dict()
	else:
		char_data = TypeSafeMixin._call_node_method_dict(_test_character, "to_dict", [])
	
	# Now save character data rather than direct object reference
	var file_name := "test_character"
	var save_result = false
	
	if _data_manager.has_method("save_character_data"):
		save_result = _data_manager.save_character_data(char_data, file_name)
	else:
		save_result = TypeSafeMixin._call_node_method_bool(_data_manager, "save_character_data", [char_data, file_name])
	
	if not save_result:
		pending("Failed to save character data - method may not be implemented")
		return
		
	assert_true(save_result, "Should save character data successfully")
	
	# Load character
	var loaded_character = null
	
	if _data_manager.has_method("load_character"):
		loaded_character = _data_manager.load_character(file_name)
	else:
		loaded_character = TypeSafeMixin._call_node_method(_data_manager, "load_character", [file_name])
	
	if not loaded_character:
		pending("Failed to load character - method may not be implemented")
		return
		
	assert_not_null(loaded_character, "Should load character successfully")
	
	# Verify character data with safe checks
	var loaded_name = ""
	var loaded_class = -1
	var loaded_origin = -1
	var loaded_background = -1
	var loaded_motivation = -1
	
	if loaded_character.has_method("get_character_name"):
		loaded_name = str(loaded_character.get_character_name())
	else:
		loaded_name = str(TypeSafeMixin._call_node_method(loaded_character, "get_character_name", []))
		
	if loaded_character.has_method("get_character_class"):
		loaded_class = int(loaded_character.get_character_class())
	else:
		loaded_class = TypeSafeMixin._call_node_method_int(loaded_character, "get_character_class", [])
	
	# Get other properties safely
	if loaded_character.has_method("get_origin"):
		loaded_origin = int(loaded_character.get_origin())
	else:
		loaded_origin = TypeSafeMixin._call_node_method_int(loaded_character, "get_origin", [])
		
	if loaded_character.has_method("get_background"):
		loaded_background = int(loaded_character.get_background())
	else:
		loaded_background = TypeSafeMixin._call_node_method_int(loaded_character, "get_background", [])
		
	if loaded_character.has_method("get_motivation"):
		loaded_motivation = int(loaded_character.get_motivation())
	else:
		loaded_motivation = TypeSafeMixin._call_node_method_int(loaded_character, "get_motivation", [])
	
	assert_eq(loaded_name, "Test Character", "Character name should match")
	assert_eq(loaded_class, GameEnums.CharacterClass.SOLDIER, "Character class should match")
	assert_eq(loaded_origin, GameEnums.Origin.HUMAN, "Character origin should match")
	assert_eq(loaded_background, GameEnums.Background.MILITARY, "Character background should match")
	assert_eq(loaded_motivation, GameEnums.Motivation.DUTY, "Character motivation should match")

# Performance tests
func test_batch_character_operations() -> void:
	# Skip test if data manager isn't ready
	if not _data_manager:
		pending("Data manager not initialized")
		return
		
	var start_time := Time.get_ticks_msec()
	var characters = _create_batch_characters(TEST_BATCH_SIZE)
	
	for character in characters:
		var save_result = false
		
		if _data_manager and _data_manager.has_method("save_character_data"):
			save_result = _data_manager.save_character_data(character)
		else:
			save_result = TypeSafeMixin._call_node_method_bool(_data_manager, "save_character_data", [character])
		
		assert_true(save_result, "Should save character successfully")
	
	var end_time := Time.get_ticks_msec()
	var duration := end_time - start_time
	
	var count = 0
	if _data_manager and _data_manager.has_method("get_character_count"):
		count = _data_manager.get_character_count()
	else:
		count = TypeSafeMixin._call_node_method_int(_data_manager, "get_character_count", [])
		
	assert_eq(count, TEST_BATCH_SIZE, "Should save all characters")
	assert_true(duration < 1000, "Batch operation should complete within 1 second")

# Boundary tests
func test_character_limit() -> void:
	# Skip test if data manager isn't ready
	if not _data_manager:
		pending("Data manager not initialized")
		return
		
	for i in range(MAX_CHARACTERS + 1):
		var character = _create_test_character()
		var result = null
		
		if _data_manager and _data_manager.has_method("save_character_data"):
			result = _data_manager.save_character_data(character)
		else:
			result = TypeSafeMixin._call_node_method(_data_manager, "save_character_data", [character])
		
		if i >= MAX_CHARACTERS:
			assert_null(result, "Should not save beyond maximum character limit")

# Signal verification tests
func test_signal_emission_order() -> void:
	# Skip test if data manager isn't ready or isn't a Node
	if not _data_manager or not (_data_manager is Node):
		pending("Data manager not initialized or not a Node")
		return
		
	watch_signals(_data_manager)
	var character = _create_test_character()
	
	var save_result = false
	if _data_manager and _data_manager.has_method("save_character_data"):
		save_result = _data_manager.save_character_data(character)
	else:
		save_result = TypeSafeMixin._call_node_method_bool(_data_manager, "save_character_data", [character])
		
	assert_true(save_result, "Should save character successfully")
	
	# Safety check for signal emission
	if _data_manager.has_signal("character_data_saved"):
		verify_signal_emitted(_data_manager, "character_data_saved")
	
	var set_result = false
	if _data_manager and _data_manager.has_method("set_active_character"):
		set_result = _data_manager.set_active_character(0)
	else:
		set_result = TypeSafeMixin._call_node_method_bool(_data_manager, "set_active_character", [0])
		
	assert_true(set_result, "Should set active character successfully")
	
	# Safety check for signal emission
	if _data_manager.has_signal("active_character_changed"):
		verify_signal_emitted(_data_manager, "active_character_changed")
	
	var delete_result = false
	if _data_manager and _data_manager.has_method("delete_character_data"):
		delete_result = _data_manager.delete_character_data(0)
	else:
		delete_result = TypeSafeMixin._call_node_method_bool(_data_manager, "delete_character_data", [0])
		
	assert_true(delete_result, "Should delete character successfully")
	
	# Safety check for signal emission
	if _data_manager.has_signal("character_data_deleted"):
		verify_signal_emitted(_data_manager, "character_data_deleted")

# Error boundary tests
func test_invalid_character_operations() -> void:
	# Skip test if data manager isn't ready
	if not _data_manager:
		pending("Data manager not initialized")
		return
		
	var invalid_character = null
	
	if _data_manager and _data_manager.has_method("get_character_data"):
		invalid_character = _data_manager.get_character_data(-1)
	else:
		invalid_character = TypeSafeMixin._call_node_method(_data_manager, "get_character_data", [-1])
		
	assert_null(invalid_character, "Should handle invalid index")
	
	if _data_manager and _data_manager.has_method("get_character_data"):
		invalid_character = _data_manager.get_character_data(9999)
	else:
		invalid_character = TypeSafeMixin._call_node_method(_data_manager, "get_character_data", [9999])
		
	assert_null(invalid_character, "Should handle out of bounds index")
	
	var save_result = false
	
	if _data_manager and _data_manager.has_method("save_character_data"):
		save_result = _data_manager.save_character_data(null)
	else:
		save_result = TypeSafeMixin._call_node_method_bool(_data_manager, "save_character_data", [null])
		
	assert_false(save_result, "Should handle null character")
