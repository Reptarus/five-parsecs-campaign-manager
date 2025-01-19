@tool
extends "res://tests/fixtures/game_test.gd"

const CharacterManager := preload("res://src/core/character/Management/CharacterManager.gd")

var character_manager: Node

func before_each() -> void:
    super.before_each()
    character_manager = CharacterManager.new()
    add_child(character_manager)

func after_each() -> void:
    super.after_each()
    character_manager = null

func test_initial_state() -> void:
    assert_eq(character_manager.get_character_count(), 0, "Should start with no characters")
    assert_eq(character_manager.get_active_characters().size(), 0, "Should have no active characters")

func test_add_character() -> void:
    var character = setup_test_character()
    character_manager.add_character(character)
    
    assert_eq(character_manager.get_character_count(), 1, "Should have one character")
    assert_true(character_manager.has_character(character.id), "Should find character by ID")

func test_remove_character() -> void:
    var character = setup_test_character()
    character_manager.add_character(character)
    character_manager.remove_character(character.id)
    
    assert_eq(character_manager.get_character_count(), 0, "Should have no characters")
    assert_false(character_manager.has_character(character.id), "Should not find removed character")

func test_get_character() -> void:
    var character = setup_test_character()
    character_manager.add_character(character)
    
    var retrieved = character_manager.get_character(character.id)
    assert_not_null(retrieved, "Should retrieve character")
    assert_eq(retrieved.id, character.id, "Should retrieve correct character")

func test_update_character() -> void:
    var character = setup_test_character()
    character_manager.add_character(character)
    
    character.health = 5
    character_manager.update_character(character)
    
    var updated = character_manager.get_character(character.id)
    assert_eq(updated.health, 5, "Should update character properties")