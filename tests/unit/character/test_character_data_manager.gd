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
extends FiveParsecsEnemyTest

const Character := preload("res://src/core/character/Base/Character.gd")
const FiveParsecsGameState := preload("res://src/core/state/GameState.gd")
const CharacterDataManager := preload("res://src/core/character/Management/CharacterDataManager.gd")
const GameStateManager := preload("res://src/core/managers/GameStateManager.gd")

# Test constants
const TEST_BATCH_SIZE: int = 100
const MAX_CHARACTERS: int = 1000

var game_state: GameStateManager
var data_manager: CharacterDataManager
var test_character: Character

# Helper methods
func create_test_character() -> Node:
	var character = Character.new()
	character.character_name = "Test Character"
	character.character_class = GameEnums.CharacterClass.SOLDIER
	track_test_resource(character)
	return character

func create_batch_characters(count: int) -> Array[Character]:
	var characters: Array[Character] = []
	for i in range(count):
		characters.append(create_test_character())
	return characters

# Setup and teardown
func before_each() -> void:
	await super.before_each()
	game_state = GameStateManager.new()
	data_manager = CharacterDataManager.new(game_state)
	test_character = Character.new()
	test_character.initialize_managers(game_state)
	add_child(game_state)
	add_child(data_manager)
	track_test_node(game_state)
	track_test_node(data_manager)
	watch_signals(game_state)
	watch_signals(data_manager)

func after_each() -> void:
	await super.after_each()
	if is_instance_valid(game_state):
		game_state.queue_free()
		game_state = null
	if is_instance_valid(data_manager):
		data_manager.queue_free()
		data_manager = null
	if is_instance_valid(test_character):
		test_character.queue_free()
		test_character = null

# Basic functionality tests
func test_initial_state() -> void:
	assert_not_null(data_manager, "Data manager should be initialized")
	assert_eq(data_manager.get_character_count(), 0, "Should start with no characters")

func test_save_and_load_character() -> void:
	# Setup test character
	test_character.character_name = "Test Character"
	test_character.character_class = GameEnums.CharacterClass.SOLDIER
	test_character.origin = GameEnums.Origin.HUMAN
	test_character.background = GameEnums.Background.MILITARY
	test_character.motivation = GameEnums.Motivation.DUTY
	
	# Save character
	var file_name = "test_character"
	data_manager.save_character(test_character, file_name)
	
	# Load character
	var loaded_character = data_manager.load_character(file_name)
	assert_not_null(loaded_character, "Should load character successfully")
	
	# Verify character data
	assert_eq(loaded_character.character_name, test_character.character_name,
		"Character name should match")
	assert_eq(loaded_character.character_class, test_character.character_class,
		"Character class should match")
	assert_eq(loaded_character.origin, test_character.origin,
		"Character origin should match")
	assert_eq(loaded_character.background, test_character.background,
		"Character background should match")
	assert_eq(loaded_character.motivation, test_character.motivation,
		"Character motivation should match")

# Performance tests
func test_batch_character_operations() -> void:
	var start_time := Time.get_ticks_msec()
	var characters := create_batch_characters(TEST_BATCH_SIZE)
	
	for character in characters:
		data_manager.save_character_data(character)
	
	var end_time := Time.get_ticks_msec()
	var duration := end_time - start_time
	
	assert_eq(data_manager.get_character_count(), TEST_BATCH_SIZE, "Should save all characters")
	assert_true(duration < 1000, "Batch operation should complete within 1 second")

# Boundary tests
func test_character_limit() -> void:
	for i in range(MAX_CHARACTERS + 1):
		var result = data_manager.save_character_data(create_test_character())
		if i >= MAX_CHARACTERS:
			assert_null(result, "Should not save beyond maximum character limit")

# Signal verification tests
func test_signal_emission_order() -> void:
	watch_signals(data_manager)
	var character := create_test_character()
	
	data_manager.save_character_data(character)
	assert_eq(_signal_watcher.get_emit_count(data_manager, "character_data_saved"), 1)
	
	data_manager.set_active_character(0)
	assert_eq(_signal_watcher.get_emit_count(data_manager, "active_character_changed"), 1)
	
	data_manager.delete_character_data(0)
	assert_eq(_signal_watcher.get_emit_count(data_manager, "character_data_deleted"), 1)

# Error boundary tests
func test_invalid_character_operations() -> void:
	assert_null(data_manager.get_character_data(-1), "Should handle invalid index")
	assert_null(data_manager.get_character_data(9999), "Should handle out of bounds index")
	
	var invalid_character = null
	assert_null(data_manager.save_character_data(invalid_character), "Should handle null character")