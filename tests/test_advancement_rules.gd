@tool
extends "res://tests/test_base.gd"

var _test_character: Character

func before_each() -> void:
	super.before_each()
	_test_character = Character.new()
	track_test_resource(_test_character)

func after_each() -> void:
	super.after_each()

# -----------------
# Experience Tests
# -----------------

func test_bot_experience_rules() -> void:
	_test_character.is_bot = true
	assert_false(_test_character.add_experience(100), "Bots should not gain experience")
	assert_eq(_test_character.experience, 0, "Bot experience should remain at 0")

# -----------------
# Training Tests
# -----------------

func test_soulless_training_restrictions() -> void:
	_test_character.is_soulless = true
	_test_character.training = GameEnums.Training.NONE
	_test_character.training = GameEnums.Training.PILOT
	assert_eq(_test_character.training, GameEnums.Training.NONE,
		"Soulless characters should not be able to receive training")

# -----------------
# Class Limit Tests
# -----------------

func test_engineer_toughness_limit() -> void:
	_test_character.character_class = GameEnums.CharacterClass.ENGINEER
	_test_character.toughness = 4
	_test_character.add_experience(1000)
	var initial_toughness = _test_character.toughness
	_test_character.toughness += 1
	assert_eq(_test_character.toughness, 4,
		"Engineers should not be able to raise Toughness above 4")

# ... existing code ...