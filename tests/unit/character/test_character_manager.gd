## Character Manager Test Suite
## Tests the functionality of the CharacterManager class, responsible for managing game characters
##
## This test suite verifies:
## - Character creation and management
## - State management and persistence
## - Performance under load
## - Error boundaries and edge cases
## - Signal emissions and handling
@tool
extends "res://tests/fixtures/base_test.gd"

const Character := preload("res://src/core/character/Base/Character.gd")
const GameState := preload("res://src/core/state/GameState.gd")
const CharacterManager := preload("res://src/core/character/Management/CharacterManager.gd")
const CharacterBox := preload("res://src/core/character/Base/CharacterBox.gd")

# Test Constants
const MAX_CHARACTERS := 100
const PERFORMANCE_TEST_ITERATIONS := 1000

var game_state: GameState
var character_manager: CharacterManager
var test_character: Character

# Lifecycle Methods
func before_each() -> void:
	await super.before_each()
	game_state = GameState.new()
	character_manager = CharacterManager.new()
	test_character = Character.new()
	test_character.initialize_managers(game_state)
	add_child_autofree(game_state)
	add_child_autofree(character_manager)
	track_test_node(game_state)
	track_test_node(character_manager)
	watch_signals(game_state)
	watch_signals(character_manager)
	
	await stabilize_engine()

func after_each() -> void:
	await super.after_each()
	if is_instance_valid(game_state):
		game_state.queue_free()
		game_state = null
	if is_instance_valid(character_manager):
		character_manager.queue_free()
		character_manager = null
	if is_instance_valid(test_character):
		test_character.queue_free()
		test_character = null

# Helper Methods
func create_test_character(name: String = "Test Character", char_class: int = GameEnums.CharacterClass.NONE) -> Character:
	var character: Character = Character.new()
	character.character_name = name
	character.character_class = char_class
	return character

func create_multiple_characters(count: int) -> Array[Character]:
	var characters: Array[Character] = []
	for i in range(count):
		characters.append(create_test_character("Character %d" % i))
	return characters

# Performance Tests
func test_bulk_character_operations() -> void:
	var start_time := Time.get_ticks_msec()
	var characters := create_multiple_characters(100)
	
	for character in characters:
		character_manager.add_character(character)
	
	assert_eq(character_manager.get_character_count(), 100, "Should handle bulk additions")
	assert_true(Time.get_ticks_msec() - start_time < 1000, "Bulk operation should complete within 1 second")

# Boundary Tests
func test_character_limit_boundary() -> void:
	for i in range(MAX_CHARACTERS + 1):
		var character := create_test_character("Character %d" % i)
		if i < MAX_CHARACTERS:
			assert_true(character_manager.add_character(character), "Should add character within limit")
		else:
			assert_false(character_manager.add_character(character), "Should reject character beyond limit")

# Signal Tests
func test_character_signals() -> void:
	var character := create_test_character()
	watch_signals(character_manager)
	
	character_manager.add_character(character)
	assert_signal_emitted(character_manager, "character_added")
	
	character_manager.update_character(character.id, character)
	assert_signal_emitted(character_manager, "character_updated")
	
	character_manager.remove_character(character.id)
	assert_signal_emitted(character_manager, "character_removed")

# Error Tests
func test_invalid_character_operations() -> void:
	assert_false(character_manager.add_character(null), "Should handle null character")
	assert_false(character_manager.update_character("invalid_id", create_test_character()), "Should handle invalid ID")
	assert_false(character_manager.remove_character("nonexistent_id"), "Should handle nonexistent ID")

# Basic State Tests
func test_initial_state() -> void:
	assert_not_null(character_manager, "Character manager should be initialized")
	assert_eq(character_manager.get_character_count(), 0, "Should start with no characters")
	assert_eq(character_manager.get_active_characters().size(), 0, "Should have no active characters")

# Character Management Tests
func test_add_character() -> void:
	var character = create_test_character()
	character_manager.add_character(character)
	
	assert_eq(character_manager.get_character_count(), 1, "Should have one character")
	assert_true(character_manager.has_character(character.id), "Should find character by ID")
	assert_signal_emitted(character_manager, "character_added")
	
	var retrieved = character_manager.get_character(character.id)
	assert_not_null(retrieved, "Should retrieve added character")
	assert_eq(retrieved.character_name, "Test Character", "Character name should match")
	assert_eq(retrieved.character_class, GameEnums.CharacterClass.NONE, "Character class should match")

func test_remove_character() -> void:
	var character = create_test_character()
	character_manager.add_character(character)
	assert_eq(character_manager.get_character_count(), 1, "Should have one character")
	
	character_manager.remove_character(character.id)
	assert_eq(character_manager.get_character_count(), 0, "Should have no characters")
	assert_false(character_manager.has_character(character.id), "Should not find removed character")
	assert_signal_emitted(character_manager, "character_removed")

func test_get_character() -> void:
	var character = create_test_character()
	character_manager.add_character(character)
	
	var retrieved = character_manager.get_character(character.id)
	assert_not_null(retrieved, "Should retrieve character")
	assert_eq(retrieved.id, character.id, "Should retrieve correct character")
	assert_eq(retrieved.character_name, character.character_name, "Should retrieve character with correct name")
	assert_eq(retrieved.character_class, character.character_class, "Should retrieve character with correct class")

func test_update_character() -> void:
	var character = create_test_character("Original Name")
	character_manager.add_character(character)
	
	character.character_name = "Updated Name"
	character.health = 5
	character_manager.update_character(character.id, character)
	
	var updated = character_manager.get_character(character.id)
	assert_eq(updated.character_name, "Updated Name", "Should update character name")
	assert_eq(updated.health, 5, "Should update character properties")
	assert_signal_emitted(character_manager, "character_updated")

# Character Class Tests
func test_character_class_management() -> void:
	var classes = [
		GameEnums.CharacterClass.NONE,
		GameEnums.CharacterClass.NONE,
		GameEnums.CharacterClass.NONE,
		GameEnums.CharacterClass.NONE
	]
	
	for char_class in classes:
		var character = create_test_character("Character %d" % char_class, char_class)
		character_manager.add_character(character)
		
		var retrieved = character_manager.get_character(character.id)
		assert_eq(retrieved.character_class, char_class,
			"Should store correct class for %s" % GameEnums.CharacterClass.keys()[char_class])

# Error Handling Tests
func test_invalid_operations() -> void:
	# Test getting non-existent character
	var retrieved = character_manager.get_character("non_existent_id")
	assert_null(retrieved, "Should return null for non-existent character")
	
	# Test removing non-existent character
	character_manager.remove_character("non_existent_id")
	assert_signal_not_emitted(character_manager, "character_removed")
	
	# Test updating non-existent character
	var invalid_character = create_test_character()
	character_manager.update_character("non_existent_id", invalid_character)
	assert_signal_not_emitted(character_manager, "character_updated")

# Active Character Tests
func test_active_character_management() -> void:
	var character1 = create_test_character("Active Character")
	var character2 = create_test_character("Inactive Character")
	
	character_manager.add_character(character1)
	character_manager.add_character(character2)
	
	character1.is_active = true
	character_manager.update_character(character1.id, character1)
	
	var active_characters = character_manager.get_active_characters()
	assert_eq(active_characters.size(), 1, "Should have one active character")
	assert_eq(active_characters[0].id, character1.id, "Should return correct active character")

func test_character_creation() -> void:
	var character = character_manager.create_character()
	assert_not_null(character, "Should create a valid character")
	assert_eq(character.character_class, GameEnums.CharacterClass.NONE,
		"New character should have no class")

func test_character_class_assignment() -> void:
	var character = character_manager.create_character()
	character_manager.set_character_class(character, GameEnums.CharacterClass.NONE)
	assert_eq(character.character_class, GameEnums.CharacterClass.NONE,
		"Character class should be set to NONE")

func test_character_stats() -> void:
	var character = character_manager.create_character()
	character_manager.set_character_class(character, GameEnums.CharacterClass.NONE)
	
	# Test initial stats
	assert_true(character.get_stat(GameEnums.CharacterStats.COMBAT_SKILL) > 0,
		"NONE should have combat skill")
	assert_true(character.get_stat(GameEnums.CharacterStats.TOUGHNESS) > 0,
		"NONE should have toughness")
	
	# Test stat improvement
	var initial_combat = character.get_stat(GameEnums.CharacterStats.COMBAT_SKILL)
	character_manager.improve_stat(character, GameEnums.CharacterStats.COMBAT_SKILL)
	assert_true(character.get_stat(GameEnums.CharacterStats.COMBAT_SKILL) > initial_combat,
		"Combat skill should improve")

func test_character_experience() -> void:
	var character = character_manager.create_character()
	var initial_xp = character.experience
	
	character_manager.add_experience(character, 100)
	assert_eq(character.experience, initial_xp + 100,
		"Experience should increase by 100")
	
	character_manager.level_up(character)
	assert_true(character.level > 1,
		"Character should level up")
