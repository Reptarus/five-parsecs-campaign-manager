@tool
extends "res://tests/test_base.gd"

# ==============================================================================
# Variables
# ==============================================================================
var _test_character: Character

# ==============================================================================
# Lifecycle Methods
# ==============================================================================
func before_each() -> void:
	await get_tree().process_frame
	super.before_each()
	_test_character = setup_test_character()
	track_test_resource(_test_character)
	_setup_test_character()

func after_each() -> void:
	await get_tree().process_frame
	super.after_each()

# ==============================================================================
# Helper Methods
# ==============================================================================
func _setup_test_character() -> void:
	_test_character.character_name = "Test Character"
	_test_character.character_class = GameEnums.CharacterClass.SOLDIER
	_test_character.origin = GameEnums.Origin.HUMAN
	_test_character.is_human = true
	
	_test_character.reaction = 3
	_test_character.combat = 2
	_test_character.speed = 4
	_test_character.savvy = 2
	_test_character.toughness = 3
	_test_character.luck = 0

# ==============================================================================
# Test Methods
# ==============================================================================
func test_character_initialization() -> void:
	assert_not_null(_test_character, "Character should be initialized")
	assert_str_eq(_test_character.character_name, "Test Character", "Character name should match")
	assert_enum_eq(_test_character.character_class, GameEnums.CharacterClass.SOLDIER, "Character class should match")

func test_character_stats() -> void:
	assert_true(_test_character.reaction >= 0 and _test_character.reaction <= Character.MAX_STATS.reaction)
	assert_true(_test_character.combat >= 0 and _test_character.combat <= Character.MAX_STATS.combat)
	assert_true(_test_character.speed >= 0 and _test_character.speed <= Character.MAX_STATS.speed)