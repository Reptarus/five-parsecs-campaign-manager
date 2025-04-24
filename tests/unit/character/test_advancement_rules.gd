## Character Advancement Rules Test Suite
## Tests the rules and restrictions for character advancement, including:
## - Experience gain and level progression
## - Training restrictions and progression
## - Class-specific limitations
## - Performance under various conditions
@tool
extends "res://tests/fixtures/base/game_test.gd"
# Use explicit preloads instead of global class names

# Type-safe script references
const Character: GDScript = preload("res://src/core/character/Base/Character.gd")

# Type-safe constants
const MAX_EXPERIENCE: int = 10000

# Type-safe instance variables
var _test_character = null

# Helper Methods
func _setup_character_with_class(char_class: int) -> void:
	if not _test_character:
		push_error("Cannot setup character class: character is null")
		return
	TypeSafeMixin._call_node_method_bool(_test_character, "set_character_class", [char_class])
	TypeSafeMixin._call_node_method_bool(_test_character, "set_is_bot", [false])
	TypeSafeMixin._call_node_method_bool(_test_character, "set_is_soulless", [false])

func _setup_character_with_training(training: int) -> void:
	if not _test_character:
		push_error("Cannot setup character training: character is null")
		return
	TypeSafeMixin._call_node_method_bool(_test_character, "set_training", [training])
	TypeSafeMixin._call_node_method_bool(_test_character, "set_is_bot", [false])
	TypeSafeMixin._call_node_method_bool(_test_character, "set_is_soulless", [false])

# Lifecycle Methods
func before_each() -> void:
	await super.before_each()
	
	# Create character instance safely checking its type
	var character_instance = Character.new()
	if character_instance is Node:
		# If it's a Node, add it to the scene tree
		_test_character = character_instance
		add_child_autofree(_test_character)
		track_test_node(_test_character)
	elif character_instance is Resource:
		# If it's a Resource, handle it appropriately
		_test_character = character_instance
		track_test_resource(_test_character)
	else:
		push_error("Character is neither a Node nor a Resource")
		return
	
	if not _test_character:
		push_error("Failed to create test character")
		return
		
	watch_signals(_test_character)
	await stabilize_engine(STABILIZE_TIME)

func after_each() -> void:
	_test_character = null
	await super.after_each()

# Experience Tests
func test_bot_experience_rules() -> void:
	TypeSafeMixin._call_node_method_bool(_test_character, "set_is_bot", [true])
	var result: bool = TypeSafeMixin._call_node_method_bool(_test_character, "add_experience", [100])
	assert_false(result, "Bots should not gain experience")
	
	var exp: int = TypeSafeMixin._call_node_method_int(_test_character, "get_experience", [])
	assert_eq(exp, 0, "Bot experience should remain at 0")

func test_experience_limits() -> void:
	TypeSafeMixin._call_node_method_bool(_test_character, "add_experience", [MAX_EXPERIENCE + 100])
	var exp: int = TypeSafeMixin._call_node_method_int(_test_character, "get_experience", [])
	assert_eq(exp, MAX_EXPERIENCE, "Experience should not exceed maximum")
	verify_signal_emitted(_test_character, "experience_changed")

# Training Tests
func test_soulless_training_restrictions() -> void:
	TypeSafeMixin._call_node_method_bool(_test_character, "set_is_soulless", [true])
	TypeSafeMixin._call_node_method_bool(_test_character, "set_training", [GameEnums.Training.NONE])
	TypeSafeMixin._call_node_method_bool(_test_character, "set_training", [GameEnums.Training.PILOT])
	
	var training: int = TypeSafeMixin._call_node_method_int(_test_character, "get_training", [])
	assert_eq(training, GameEnums.Training.NONE, "Soulless characters should not be able to receive training")

func test_training_progression() -> void:
	watch_signals(_test_character)
	
	TypeSafeMixin._call_node_method_bool(_test_character, "set_training", [GameEnums.Training.NONE])
	var training: int = TypeSafeMixin._call_node_method_int(_test_character, "get_training", [])
	assert_eq(training, GameEnums.Training.NONE, "Initial training should be NONE")
	
	TypeSafeMixin._call_node_method_bool(_test_character, "set_training", [GameEnums.Training.PILOT])
	training = TypeSafeMixin._call_node_method_int(_test_character, "get_training", [])
	assert_eq(training, GameEnums.Training.PILOT, "Should accept PILOT training")
	verify_signal_emitted(_test_character, "training_changed")
	
	TypeSafeMixin._call_node_method_bool(_test_character, "set_training", [GameEnums.Training.SPECIALIST])
	training = TypeSafeMixin._call_node_method_int(_test_character, "get_training", [])
	assert_eq(training, GameEnums.Training.SPECIALIST, "Should accept SPECIALIST training")
	verify_signal_emitted(_test_character, "training_changed")
	
	TypeSafeMixin._call_node_method_bool(_test_character, "set_training", [GameEnums.Training.ELITE])
	training = TypeSafeMixin._call_node_method_int(_test_character, "get_training", [])
	assert_eq(training, GameEnums.Training.ELITE, "Should accept ELITE training")
	verify_signal_emitted(_test_character, "training_changed")

# Class Limit Tests
func test_engineer_toughness_limit() -> void:
	_setup_character_with_class(GameEnums.CharacterClass.ENGINEER)
	TypeSafeMixin._call_node_method_bool(_test_character, "set_toughness", [4])
	TypeSafeMixin._call_node_method_bool(_test_character, "add_experience", [1000])
	TypeSafeMixin._call_node_method_bool(_test_character, "increase_toughness", [])
	
	var toughness: int = TypeSafeMixin._call_node_method_int(_test_character, "get_toughness", [])
	assert_eq(toughness, 4, "Engineers should not be able to raise Toughness above 4")

# Performance Tests
func test_rapid_experience_gain() -> void:
	watch_signals(_test_character)
	var start_time := Time.get_ticks_msec()
	
	for i in range(1000):
		TypeSafeMixin._call_node_method_bool(_test_character, "add_experience", [10])
	
	var duration := Time.get_ticks_msec() - start_time
	assert_true(duration < 1000, "Should handle rapid experience gains efficiently")
	assert_true(get_signal_emit_count(_test_character, "experience_changed") > 0, "Should emit experience_changed signal")

# Error Boundary Tests
func test_invalid_training_transitions() -> void:
	watch_signals(_test_character)
	
	TypeSafeMixin._call_node_method_bool(_test_character, "set_training", [GameEnums.Training.NONE])
	TypeSafeMixin._call_node_method_bool(_test_character, "set_training", [GameEnums.Training.ELITE])
	
	var training: int = TypeSafeMixin._call_node_method_int(_test_character, "get_training", [])
	assert_eq(training, GameEnums.Training.NONE, "Should not allow skipping training levels")
	verify_signal_not_emitted(_test_character, "training_changed")

func test_invalid_experience_values() -> void:
	watch_signals(_test_character)
	
	var result: bool = TypeSafeMixin._call_node_method_bool(_test_character, "add_experience", [-100])
	assert_false(result, "Should reject negative experience")
	
	var exp: int = TypeSafeMixin._call_node_method_int(_test_character, "get_experience", [])
	assert_eq(exp, 0, "Experience should remain unchanged")
	verify_signal_not_emitted(_test_character, "experience_changed")
