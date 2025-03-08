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

# Type-safe constants
const TEST_BATCH_SIZE: int = 100
const MAX_CHARACTERS: int = 1000

# Type-safe instance variables
var _data_manager: Node = null
var _test_character: Node = null

# Helper methods
func _create_test_character() -> Node:
	var character: Node = Character.new()
	if not character:
		push_error("Failed to create test character")
		return null
	TypeSafeMixin._call_node_method_bool(character, "set_character_name", ["Test Character"])
	TypeSafeMixin._call_node_method_bool(character, "set_character_class", [GameEnums.CharacterClass.SOLDIER])
	add_child_autofree(character)
	track_test_node(character)
	return character

func _create_batch_characters(count: int) -> Array[Node]:
	var characters: Array[Node] = []
	for i in range(count):
		var character := _create_test_character()
		if character:
			characters.append(character)
	return characters

# Setup and teardown
func before_each() -> void:
	await super.before_each()
	
	# Initialize data manager
	var data_manager_instance: Node = CharacterDataManager.new()
	_data_manager = data_manager_instance
	if not _data_manager:
		push_error("Failed to create data manager")
		return
	TypeSafeMixin._call_node_method_bool(_data_manager, "initialize", [_game_state])
	add_child_autofree(_data_manager)
	track_test_node(_data_manager)
	
	# Create test character
	_test_character = _create_test_character()
	if not _test_character:
		push_error("Failed to create test character")
		return
	
	watch_signals(_game_state)
	watch_signals(_data_manager)
	await stabilize_engine(STABILIZE_TIME)

func after_each() -> void:
	_game_state = null
	_data_manager = null
	_test_character = null
	await super.after_each()

# Basic functionality tests
func test_initial_state() -> void:
	assert_not_null(_data_manager, "Data manager should be initialized")
	var count: int = TypeSafeMixin._call_node_method_int(_data_manager, "get_character_count", [])
	assert_eq(count, 0, "Should start with no characters")

func test_save_and_load_character() -> void:
	# Setup test character
	TypeSafeMixin._call_node_method_bool(_test_character, "set_character_name", ["Test Character"])
	TypeSafeMixin._call_node_method_bool(_test_character, "set_character_class", [GameEnums.CharacterClass.SOLDIER])
	TypeSafeMixin._call_node_method_bool(_test_character, "set_origin", [GameEnums.Origin.HUMAN])
	TypeSafeMixin._call_node_method_bool(_test_character, "set_background", [GameEnums.Background.MILITARY])
	TypeSafeMixin._call_node_method_bool(_test_character, "set_motivation", [GameEnums.Motivation.DUTY])
	
	# Save character
	var file_name := "test_character"
	var save_result: bool = TypeSafeMixin._call_node_method_bool(_data_manager, "save_character", [_test_character, file_name])
	assert_true(save_result, "Should save character successfully")
	
	# Load character
	var loaded_character: Node = TypeSafeMixin._call_node_method(_data_manager, "load_character", [file_name])
	assert_not_null(loaded_character, "Should load character successfully")
	
	# Verify character data
	var loaded_name: String = TypeSafeMixin._safe_cast_to_string(TypeSafeMixin._call_node_method(loaded_character, "get_character_name", []))
	var loaded_class: int = TypeSafeMixin._call_node_method_int(loaded_character, "get_character_class", [])
	var loaded_origin: int = TypeSafeMixin._call_node_method_int(loaded_character, "get_origin", [])
	var loaded_background: int = TypeSafeMixin._call_node_method_int(loaded_character, "get_background", [])
	var loaded_motivation: int = TypeSafeMixin._call_node_method_int(loaded_character, "get_motivation", [])
	
	assert_eq(loaded_name, "Test Character", "Character name should match")
	assert_eq(loaded_class, GameEnums.CharacterClass.SOLDIER, "Character class should match")
	assert_eq(loaded_origin, GameEnums.Origin.HUMAN, "Character origin should match")
	assert_eq(loaded_background, GameEnums.Background.MILITARY, "Character background should match")
	assert_eq(loaded_motivation, GameEnums.Motivation.DUTY, "Character motivation should match")

# Performance tests
func test_batch_character_operations() -> void:
	var start_time := Time.get_ticks_msec()
	var characters := _create_batch_characters(TEST_BATCH_SIZE)
	
	for character in characters:
		var save_result: bool = TypeSafeMixin._call_node_method_bool(_data_manager, "save_character_data", [character])
		assert_true(save_result, "Should save character successfully")
	
	var end_time := Time.get_ticks_msec()
	var duration := end_time - start_time
	
	var count: int = TypeSafeMixin._call_node_method_int(_data_manager, "get_character_count", [])
	assert_eq(count, TEST_BATCH_SIZE, "Should save all characters")
	assert_true(duration < 1000, "Batch operation should complete within 1 second")

# Boundary tests
func test_character_limit() -> void:
	for i in range(MAX_CHARACTERS + 1):
		var character := _create_test_character()
		var result = TypeSafeMixin._call_node_method(_data_manager, "save_character_data", [character])
		if i >= MAX_CHARACTERS:
			assert_null(result, "Should not save beyond maximum character limit")

# Signal verification tests
func test_signal_emission_order() -> void:
	watch_signals(_data_manager)
	var character := _create_test_character()
	
	var save_result: bool = TypeSafeMixin._call_node_method_bool(_data_manager, "save_character_data", [character])
	assert_true(save_result, "Should save character successfully")
	verify_signal_emitted(_data_manager, "character_data_saved")
	
	var set_result: bool = TypeSafeMixin._call_node_method_bool(_data_manager, "set_active_character", [0])
	assert_true(set_result, "Should set active character successfully")
	verify_signal_emitted(_data_manager, "active_character_changed")
	
	var delete_result: bool = TypeSafeMixin._call_node_method_bool(_data_manager, "delete_character_data", [0])
	assert_true(delete_result, "Should delete character successfully")
	verify_signal_emitted(_data_manager, "character_data_deleted")

# Error boundary tests
func test_invalid_character_operations() -> void:
	var invalid_character = TypeSafeMixin._call_node_method(_data_manager, "get_character_data", [-1])
	assert_null(invalid_character, "Should handle invalid index")
	
	invalid_character = TypeSafeMixin._call_node_method(_data_manager, "get_character_data", [9999])
	assert_null(invalid_character, "Should handle out of bounds index")
	
	var save_result: bool = TypeSafeMixin._call_node_method_bool(_data_manager, "save_character_data", [null])
	assert_false(save_result, "Should handle null character")