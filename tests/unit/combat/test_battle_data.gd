@tool
# Use explicit file paths instead of class names
extends "res://tests/fixtures/base/game_test.gd"

# Test suite for BaseBattleData class
# Tests initialization, serialization and core functionality

# Use explicit preloads instead of global class names
const Compatibility = preload("res://tests/fixtures/helpers/test_compatibility_helper.gd")
var BattleDataScript = load("res://src/core/combat/BattleData.gd") if ResourceLoader.exists("res://src/core/combat/BattleData.gd") else null
const GameEnumsScript = preload("res://src/core/systems/GlobalEnums.gd")

# Test variables
var _battle_data: Resource = null # BaseBattleData instance

func before_each() -> void:
	await super.before_each()
	
	if not BattleDataScript:
		push_error("BattleData script is null")
		return
	
	_battle_data = BattleDataScript.new()
	if not _battle_data:
		push_error("Failed to create battle data")
		return
	
	# Ensure resource has a valid path for Godot 4.4
	_battle_data = Compatibility.ensure_resource_path(_battle_data, "test_battle_data")
	
	track_test_resource(_battle_data)
	await stabilize_engine(STABILIZE_TIME)

func after_each() -> void:
	_battle_data = null
	await super.after_each()

func test_battle_data_initialization() -> void:
	assert_not_null(_battle_data, "Battle data should be initialized")
	assert_true(_battle_data is Resource, "Battle data should be a Resource")

func test_battle_setup() -> void:
	# Test setting up with valid parameters
	var result = Compatibility.safe_call_method(
		_battle_data,
		"setup",
		[ {"difficulty": 3, "enemies": 5, "terrain": "urban"}],
		false
	)
	assert_true(result, "Battle data setup should succeed with valid parameters")
	
	# Verify properties through safe accessor methods
	var difficulty = Compatibility.safe_call_method(_battle_data, "get_difficulty", [], 0)
	var enemy_count = Compatibility.safe_call_method(_battle_data, "get_enemy_count", [], 0)
	var terrain_type = Compatibility.safe_call_method(_battle_data, "get_terrain_type", [], "")
	
	assert_eq(difficulty, 3, "Difficulty should be set correctly")
	assert_eq(enemy_count, 5, "Enemy count should be set correctly")
	assert_eq(terrain_type, "urban", "Terrain type should be set correctly")

func test_battle_serialization() -> void:
	# Check if BattleDataScript is available
	if not BattleDataScript:
		pending("BattleDataScript is not available")
		return
	
	# Check if battle data is available
	if not _battle_data:
		pending("Battle data is not available")
		return
		
	# Setup test data
	Compatibility.safe_call_method(
		_battle_data,
		"setup",
		[ {"difficulty": 2, "enemies": 3, "terrain": "desert"}],
		false
	)
	
	# Test serialization
	var serialized = Compatibility.safe_call_method(_battle_data, "to_dict", [], {})
	assert_not_null(serialized, "Serialized data should not be null")
	assert_true(serialized is Dictionary, "Serialized data should be a Dictionary")
	
	# Verify serialized data
	assert_eq(serialized.get("difficulty", 0), 2, "Serialized difficulty should match")
	assert_eq(serialized.get("enemies", 0), 3, "Serialized enemy count should match")
	assert_eq(serialized.get("terrain", ""), "desert", "Serialized terrain should match")
	
	# Test deserialization (use safe creation of new battle data)
	var new_battle_data = null
	if BattleDataScript:
		new_battle_data = BattleDataScript.new()
		if not new_battle_data:
			push_error("Failed to create new battle data instance")
			return
			
		# Ensure resource has a valid path
		new_battle_data = Compatibility.ensure_resource_path(new_battle_data, "test_battle_data_2")
		track_test_resource(new_battle_data)
	else:
		push_error("Cannot create new battle data: BattleDataScript is null")
		return
	
	var deserialized = Compatibility.safe_call_method(
		new_battle_data,
		"from_dict",
		[serialized],
		false
	)
	assert_true(deserialized, "Deserialization should succeed")
	
	# Verify deserialized data
	var new_difficulty = Compatibility.safe_call_method(new_battle_data, "get_difficulty", [], 0)
	var new_enemy_count = Compatibility.safe_call_method(new_battle_data, "get_enemy_count", [], 0)
	var new_terrain_type = Compatibility.safe_call_method(new_battle_data, "get_terrain_type", [], "")
	
	assert_eq(new_difficulty, 2, "Deserialized difficulty should match")
	assert_eq(new_enemy_count, 3, "Deserialized enemy count should match")
	assert_eq(new_terrain_type, "desert", "Deserialized terrain should match")

func test_battle_character_management():
	# Skip test if battle data is not available
	if not _battle_data:
		pending("Battle data is not available")
		return
		
	# Given
	var character_data: Dictionary = {
		"id": "test_char_1",
		"name": "Test Character",
		"health": 100,
		"status": []
	}
	
	# When - use Compatibility helper to safely call methods
	var add_result = Compatibility.safe_call_method(
		_battle_data,
		"add_character",
		[character_data],
		false
	)
	
	# Then - check if call succeeded
	assert_true(add_result, "Should be able to add character")
	
	# Check character count using safe access
	var characters_count = 0
	if _battle_data.get("characters") != null and _battle_data.characters is Array:
		characters_count = _battle_data.characters.size()
	else:
		characters_count = Compatibility.safe_call_method(_battle_data, "get_characters_count", [], 0)
		
	assert_eq(characters_count, 1, "Should have one character")
	
	# Get character with type safety using Compatibility helper
	var retrieved_char = Compatibility.safe_call_method(
		_battle_data,
		"get_character",
		["test_char_1"],
		{}
	)
	
	assert_not_null(retrieved_char, "Should retrieve the added character")
	assert_eq(retrieved_char.get("name", ""), "Test Character", "Character name should match")
	
	# Test character status management with safe method call
	var status_update: Dictionary = {"wounded": true}
	var status_update_result = Compatibility.safe_call_method(
		_battle_data,
		"set_character_status",
		["test_char_1", status_update],
		false
	)
	
	assert_true(status_update_result, "Should update character status")
	
	# Get updated character with proper type safety
	retrieved_char = Compatibility.safe_call_method(
		_battle_data,
		"get_character",
		["test_char_1"],
		{}
	)
	
	assert_true(retrieved_char.get("status", {}).has("wounded"), "Character should have wounded status")