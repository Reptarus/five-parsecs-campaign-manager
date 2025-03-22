@tool
# Use explicit file paths instead of class names
extends "res://tests/fixtures/base/game_test.gd"

# Test suite for BaseBattleData class
# Tests initialization, serialization and core functionality

# Use explicit preloads instead of global class names
const BattleDataScript = preload("res://src/base/combat/BaseBattleData.gd")
const GameEnumsScript = preload("res://src/core/systems/GlobalEnums.gd")

# Test variables
var _battle_data = null # BaseBattleData instance

func before_each():
	await super.before_each()
	
	# Create instance of battle data
	_battle_data = BattleDataScript.new()
	add_child_autofree(_battle_data)
	
	await stabilize_engine()

func after_each():
	_battle_data = null
	await super.after_each()

func test_battle_data_initialization():
	# Then
	assert_not_null(_battle_data, "Battle data should be initialized")
	assert_eq(_battle_data.turn, 1, "Default turn should be 1")
	assert_eq(_battle_data.phase, GameEnumsScript.BattlePhase.SETUP, "Default phase should be SETUP")
	assert_true(_battle_data.characters.is_empty(), "Characters list should start empty")

func test_battle_data_serialization():
	# Given
	_battle_data.turn = 3
	# Use an actual enum value that exists in GameEnumsScript.BattlePhase
	_battle_data.phase = GameEnumsScript.BattlePhase.SETUP
	
	# When
	var serialized = _battle_data.serialize()
	
	# Then
	assert_not_null(serialized, "Serialized data should not be null")
	assert_eq(serialized.turn, 3, "Serialized turn should be 3")
	assert_eq(serialized.phase, GameEnumsScript.BattlePhase.SETUP, "Serialized phase should be SETUP")
	
	# When deserializing
	var new_battle_data = BattleDataScript.new()
	new_battle_data.deserialize(serialized)
	
	# Then
	assert_eq(new_battle_data.turn, 3, "Deserialized turn should be 3")
	assert_eq(new_battle_data.phase, GameEnumsScript.BattlePhase.SETUP, "Deserialized phase should be SETUP")

func test_battle_character_management():
	# Given
	var character_data: Dictionary = {
		"id": "test_char_1",
		"name": "Test Character",
		"health": 100,
		"status": []
	}
	
	# When
	_battle_data.add_character(character_data)
	
	# Then
	assert_eq(_battle_data.characters.size(), 1, "Should have one character")
	
	# Get character with type safety - explicitly cast to Dictionary
	var retrieved_char: Dictionary = _battle_data.get_character("test_char_1") as Dictionary
	assert_not_null(retrieved_char, "Should retrieve the added character")
	assert_eq(retrieved_char.name, "Test Character", "Character name should match")
	
	# Test character status management
	var status_update: Dictionary = {"wounded": true}
	_battle_data.set_character_status("test_char_1", status_update)
	
	# Get updated character with proper type casting
	retrieved_char = _battle_data.get_character("test_char_1") as Dictionary
	assert_true(retrieved_char.status.has("wounded"), "Character should have wounded status")