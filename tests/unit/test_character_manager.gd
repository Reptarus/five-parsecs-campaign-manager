@tool
extends "res://tests/fixtures/base_test.gd"

const Character = preload("res://src/core/character/Base/Character.gd")
const CharacterManager = preload("res://src/core/character/Management/CharacterManager.gd")

var character_manager: CharacterManager
var test_character: Character

func before_each() -> void:
	character_manager = CharacterManager.new()
	add_child(character_manager)
	track_node(character_manager)
	
	test_character = Character.new()
	test_character.character_name = "Test Character"
	test_character.status = GameEnums.CharacterStatus.HEALTHY

func test_character_status_update() -> void:
	character_manager.add_character(test_character)
	character_manager.update_character_status(test_character.character_id, GameEnums.CharacterStatus.INJURED)
	assert_eq(test_character.status, GameEnums.CharacterStatus.INJURED, "Character status should be updated to INJURED")