@tool
extends "res://tests/test_base.gd"

const CharacterManager := preload("res://src/core/character/Management/CharacterManager.gd")
const GameWeapon := preload("res://src/core/systems/items/Weapon.gd")
const TestHelper := preload("res://tests/fixtures/test_helper.gd")

var manager: CharacterManager
var test_character: Character
var error_messages: Array[String] = []

func before_each() -> void:
	super.before_each()
	manager = CharacterManager.new()
	manager.character_error.connect(_on_character_error)
	
	test_character = Character.new()
	test_character.character_name = "Test Character"
	test_character.origin = GameEnums.Origin.HUMAN
	test_character.character_class = GameEnums.CharacterClass.SOLDIER
	
	add_child(manager)
	track_test_node(manager)
	track_test_resource(test_character)
	error_messages.clear()

func after_each() -> void:
	super.after_each()
	error_messages.clear()

func _on_character_error(message: String) -> void:
	error_messages.append(message)

func test_add_character() -> void:
	assert_true(manager.add_character(test_character))
	assert_eq(manager.get_active_character_count(), 1)
	
	var loaded_character: Character = manager.get_character("test_character")
	assert_not_null(loaded_character)
	assert_eq(loaded_character.character_name, "Test Character")
	assert_eq(error_messages.size(), 0)

func test_add_duplicate_character() -> void:
	assert_true(manager.add_character(test_character))
	assert_false(manager.add_character(test_character))
	assert_eq(manager.get_active_character_count(), 1)
	assert_eq(error_messages.size(), 1)
	assert_true(error_messages[0].contains("already exists"))

func test_remove_character() -> void:
	manager.add_character(test_character)
	manager.remove_character("test_character")
	assert_eq(manager.get_active_character_count(), 0)
	assert_null(manager.get_character("test_character"))

func test_character_status_update() -> void:
	manager.add_character(test_character)
	manager.update_character_status(test_character.character_id, GameEnums.CharacterStatus.INJURED)
	
	assert_true(test_character.status == GameEnums.CharacterStatus.INJURED, "Character status should be updated to INJURED")

func test_character_health_management() -> void:
	manager.add_character(test_character)
	var initial_health: int = test_character.stats.current_health
	
	# Test damage
	manager.apply_damage(test_character, 5)
	assert_eq(test_character.stats.current_health, initial_health - 5)
	
	# Test healing
	manager.heal_character(test_character, 3)
	assert_eq(test_character.stats.current_health, initial_health - 2)

func test_character_experience() -> void:
	manager.add_character(test_character)
	var initial_level: int = test_character.stats.level
	
	# Add enough experience for a level up
	manager.add_experience(test_character, 100)
	assert_gt(test_character.stats.level, initial_level)

func test_character_equipment() -> void:
	manager.add_character(test_character)
	
	# Test weapon equipping
	var weapon := GameWeapon.new()
	track_test_resource(weapon)
	assert_true(manager.equip_item(test_character, weapon))
	assert_not_null(test_character.equipped_weapon)
	
	# Test weapon unequipping
	assert_true(manager.unequip_item(test_character, weapon))
	assert_null(test_character.equipped_weapon)

func test_load_all_characters() -> void:
	# Add multiple characters
	var characters: Array[Character] = []
	for i in range(3):
		var char := Character.new()
		char.character_name = "Test Character %d" % i
		characters.append(char)
		track_test_resource(char)
		manager.add_character(char)
	
	# Clear active characters and reload
	manager.active_characters.clear()
	manager.load_all_characters()
	
	assert_eq(manager.get_active_character_count(), 3)
	for i in range(3):
		var char_id := "test_character_%d" % i
		assert_not_null(manager.get_character(char_id))

func test_character_save_load() -> void:
	manager.add_character(test_character)
	
	# Modify character
	test_character.stats.combat_skill = 2
	test_character.stats.toughness = 4
	manager.save_character(test_character)
	
	# Clear and reload
	manager.active_characters.clear()
	var loaded_character: Character = manager.load_character("test_character")
	
	assert_not_null(loaded_character)
	assert_eq(loaded_character.stats.combat_skill, 2)
	assert_eq(loaded_character.stats.toughness, 4)

func test_max_characters() -> void:
	for i in range(manager.MAX_CHARACTERS + 1):
		var char := Character.new()
		char.character_name = "Test Character %d" % i
		track_test_resource(char)
		if i < manager.MAX_CHARACTERS:
			assert_true(manager.add_character(char))
		else:
			assert_false(manager.add_character(char))
	
	assert_eq(manager.get_active_character_count(), manager.MAX_CHARACTERS)
	assert_eq(error_messages.size(), 1)
	assert_true(error_messages[0].contains("Maximum number of characters reached"))