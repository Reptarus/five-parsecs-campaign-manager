## Character Advancement Rules Test Suite
## Tests the rules and restrictions for character advancement, including:
## - Experience gain and level progression
## - Training restrictions and progression
## - Class-specific limitations
## - Performance under various conditions
@tool
extends BaseTest

const Character = preload("res://src/core/character/Base/Character.gd")
const MAX_EXPERIENCE := 10000

# Training levels
enum Training {
	NONE,
	PILOT,
	MECHANIC,
	MEDICAL,
	MERCHANT,
	SECURITY,
	BROKER,
	BOT_TECH,
	SPECIALIST,
	ELITE
}

# Character classes
enum CharacterClass {
	NONE,
	SOLDIER,
	MEDIC,
	ENGINEER,
	PILOT,
	MERCHANT,
	SECURITY,
	BROKER,
	BOT_TECH
}

var MAX_TRAINING_LEVEL: int = Training.ELITE

# Test variables
var _test_character: Character

# Helper Methods
func setup_character_with_class(char_class: int) -> void:
	_test_character.character_class = char_class
	_test_character.is_bot = false
	_test_character.is_soulless = false

func setup_character_with_training(training: int) -> void:
	_test_character.training = training
	_test_character.is_bot = false
	_test_character.is_soulless = false

# Lifecycle Methods
func before_each() -> void:
	super.before_each()
	_test_character = Character.new()
	track_test_resource(_test_character)

func after_each() -> void:
	super.after_each()
	_test_character = null

# Experience Tests
func test_bot_experience_rules() -> void:
	_test_character.is_bot = true
	assert_false(_test_character.add_experience(100), "Bots should not gain experience")
	assert_eq(_test_character.experience, 0, "Bot experience should remain at 0")

func test_experience_limits() -> void:
	_test_character.add_experience(MAX_EXPERIENCE + 100)
	assert_eq(_test_character.experience, MAX_EXPERIENCE, "Experience should not exceed maximum")

# Training Tests
func test_soulless_training_restrictions() -> void:
	_test_character.is_soulless = true
	_test_character.training = Training.NONE
	_test_character.training = Training.PILOT
	assert_eq(_test_character.training, Training.NONE,
		"Soulless characters should not be able to receive training")

func test_training_progression() -> void:
	_test_character.training = Training.NONE
	assert_eq(_test_character.training, Training.NONE, "Initial training should be NONE")
	
	_test_character.training = Training.PILOT
	assert_eq(_test_character.training, Training.PILOT, "Should accept PILOT training")
	
	_test_character.training = Training.SPECIALIST
	assert_eq(_test_character.training, Training.SPECIALIST, "Should accept SPECIALIST training")
	
	_test_character.training = Training.ELITE
	assert_eq(_test_character.training, Training.ELITE, "Should accept ELITE training")

# Class Limit Tests
func test_engineer_toughness_limit() -> void:
	setup_character_with_class(CharacterClass.ENGINEER)
	_test_character.toughness = 4
	_test_character.add_experience(1000)
	_test_character.toughness += 1
	assert_eq(_test_character.toughness, 4,
		"Engineers should not be able to raise Toughness above 4")

# Performance Tests
func test_rapid_experience_gain() -> void:
	var start_time := Time.get_ticks_msec()
	
	for i in range(1000):
		_test_character.add_experience(10)
	
	var duration := Time.get_ticks_msec() - start_time
	assert_true(duration < 1000, "Should handle rapid experience gains efficiently")

# Error Boundary Tests
func test_invalid_training_transitions() -> void:
	_test_character.training = Training.NONE
	_test_character.training = Training.ELITE
	assert_eq(_test_character.training, Training.NONE,
		"Should not allow skipping training levels")

func test_invalid_experience_values() -> void:
	assert_false(_test_character.add_experience(-100), "Should reject negative experience")
	assert_eq(_test_character.experience, 0, "Experience should remain unchanged")

# ... existing code ...
