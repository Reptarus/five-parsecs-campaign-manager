class_name TestCharacterManager
extends "res://addons/gut/test.gd"

const GameEnums = preload("res://src/core/systems/GlobalEnums.gd")
const Character = preload("res://src/core/character/Base/Character.gd")
const CharacterManager = preload("res://src/core/character/Management/CharacterManager.gd")

var character_manager: CharacterManager
var test_character: Character

func before_each():
	character_manager = CharacterManager.new()
	add_child_autoqfree(character_manager)
	test_character = Character.new()
	test_character.character_name = "Test Character"
	test_character.level = 1
	test_character.status = GameEnums.CharacterStatus.HEALTHY

func after_each():
	character_manager = null
	test_character = null

func test_add_character():
	var signal_emitted = false
	character_manager.character_created.connect(
		func(character): signal_emitted = true
	)
	
	var success = character_manager.add_character(test_character)
	assert_true(success,
		"Character should be added successfully")
	assert_true(signal_emitted,
		"Character created signal should be emitted")
	assert_eq(character_manager.get_active_character_count(), 1,
		"Active character count should be 1")

func test_character_limit():
	# Add maximum number of characters
	for i in range(CharacterManager.MAX_CHARACTERS):
		var char = Character.new()
		char.character_name = "Test Character %d" % i
		character_manager.add_character(char)
	
	# Try to add one more
	var extra_char = Character.new()
	extra_char.character_name = "Extra Character"
	var success = character_manager.add_character(extra_char)
	
	assert_false(success,
		"Should not be able to add more than MAX_CHARACTERS")
	assert_eq(character_manager.get_active_character_count(), CharacterManager.MAX_CHARACTERS,
		"Active character count should be at maximum")

func test_remove_character():
	character_manager.add_character(test_character)
	var character_id = character_manager._generate_character_id(test_character)
	
	var signal_emitted = false
	character_manager.character_deleted.connect(
		func(id): signal_emitted = true
	)
	
	character_manager.remove_character(character_id)
	assert_true(signal_emitted,
		"Character deleted signal should be emitted")
	assert_eq(character_manager.get_active_character_count(), 0,
		"Active character count should be 0")
	assert_null(character_manager.get_character(character_id),
		"Character should not be retrievable after removal")

func test_update_character():
	character_manager.add_character(test_character)
	
	var signal_emitted = false
	character_manager.character_updated.connect(
		func(character): signal_emitted = true
	)
	
	test_character.level = 2
	character_manager.update_character(test_character)
	
	var character_id = character_manager._generate_character_id(test_character)
	var updated_char = character_manager.get_character(character_id)
	
	assert_true(signal_emitted,
		"Character updated signal should be emitted")
	assert_eq(updated_char.level, 2,
		"Character level should be updated")

func test_character_status():
	character_manager.add_character(test_character)
	
	var signal_emitted = false
	character_manager.character_updated.connect(
		func(character): signal_emitted = true
	)
	
	character_manager.update_character_status(test_character, GameEnums.CharacterStatus.INJURED)
	
	assert_true(signal_emitted,
		"Character updated signal should be emitted")
	assert_eq(test_character.status, GameEnums.CharacterStatus.INJURED,
		"Character status should be updated")

func test_character_health():
	character_manager.add_character(test_character)
	
	# Test healing
	character_manager.heal_character(test_character, 10)
	assert_eq(test_character.stats.current_health, test_character.stats.max_health,
		"Health should not exceed max health")
	
	# Test damage
	character_manager.apply_damage(test_character, 20)
	assert_eq(test_character.status, GameEnums.CharacterStatus.INJURED,
		"Character should be injured when taking significant damage")

func test_experience_system():
	character_manager.add_character(test_character)
	
	var initial_xp = test_character.xp
	character_manager.add_experience(test_character, 100)
	
	assert_eq(test_character.xp, initial_xp + 100,
		"Character should gain correct amount of experience")