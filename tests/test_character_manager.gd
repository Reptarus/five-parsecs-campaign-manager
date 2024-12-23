extends "res://addons/gut/test.gd"

const Character := preload("res://src/core/character/Base/Character.gd")
const GameEnums := preload("res://src/core/systems/GlobalEnums.gd")
const GameWeapon := preload("res://src/core/systems/items/Weapon.gd")
const Equipment := preload("res://src/core/character/Equipment/Equipment.gd")
const CharacterManager := preload("res://src/core/character/Management/CharacterManager.gd")

var character_manager: CharacterManager
var test_character: Character
var error_messages: Array[String] = []

func before_each() -> void:
    super.before_each()
    character_manager = CharacterManager.new()
    character_manager.character_error.connect(_on_character_error)
    
    test_character = Character.new()
    test_character.character_name = "Test Character"
    test_character.character_id = "test_char_1"
    test_character.origin = GameEnums.Origin.HUMAN
    test_character.character_class = GameEnums.CharacterClass.SOLDIER
    
    add_child(character_manager)
    error_messages.clear()

func after_each() -> void:
    super.after_each()
    if is_instance_valid(character_manager):
        character_manager.queue_free()
    test_character = null
    error_messages.clear()

func _on_character_error(message: String) -> void:
    error_messages.append(message)

func test_add_character() -> void:
    assert_true(character_manager.add_character(test_character))
    assert_eq(character_manager.get_active_character_count(), 1)
    
    var loaded_character := character_manager.get_character(test_character.character_id)
    assert_not_null(loaded_character)
    assert_eq(loaded_character.character_name, "Test Character")
    assert_eq(error_messages.size(), 0)

func test_add_duplicate_character() -> void:
    assert_true(character_manager.add_character(test_character))
    assert_false(character_manager.add_character(test_character))
    assert_eq(character_manager.get_active_character_count(), 1)
    assert_eq(error_messages.size(), 1)
    assert_string_contains(error_messages[0], "already exists")

func test_remove_character() -> void:
    character_manager.add_character(test_character)
    character_manager.remove_character(test_character.character_id)
    assert_eq(character_manager.get_active_character_count(), 0)
    assert_null(character_manager.get_character(test_character.character_id))

func test_character_status_update() -> void:
    character_manager.add_character(test_character)
    character_manager.update_character_status(test_character, GameEnums.CharacterStatus.INJURED)
    
    var loaded_character := character_manager.get_character(test_character.character_id)
    assert_eq(loaded_character.status, GameEnums.CharacterStatus.INJURED)

func test_character_health_management() -> void:
    character_manager.add_character(test_character)
    var initial_health: int = test_character.stats.current_health
    
    # Test damage
    character_manager.apply_damage(test_character, 5)
    assert_eq(test_character.stats.current_health, initial_health - 5)
    
    # Test healing
    character_manager.heal_character(test_character, 3)
    assert_eq(test_character.stats.current_health, initial_health - 2)

func test_character_experience() -> void:
    character_manager.add_character(test_character)
    var initial_level: int = test_character.stats.level
    
    # Add enough experience for a level up
    character_manager.add_experience(test_character, 100)
    assert_gt(test_character.stats.level, initial_level)

func test_character_equipment() -> void:
    character_manager.add_character(test_character)
    
    # Test weapon equipping
    var weapon := GameWeapon.new()
    weapon.weapon_name = "Test Weapon"
    assert_true(character_manager.equip_item(test_character, weapon))
    assert_not_null(test_character.equipped_weapon)
    assert_eq(test_character.equipped_weapon.weapon_name, "Test Weapon")
    
    # Test weapon unequipping
    assert_true(character_manager.unequip_item(test_character, weapon))
    assert_null(test_character.equipped_weapon)

func test_character_save_load() -> void:
    character_manager.add_character(test_character)
    
    # Modify character
    test_character.stats.combat_skill = 2
    test_character.stats.toughness = 4
    character_manager.save_character(test_character)
    
    # Clear and reload
    character_manager.active_characters.clear()
    var loaded_character := character_manager.load_character(test_character.character_id)
    
    assert_not_null(loaded_character)
    assert_eq(loaded_character.stats.combat_skill, 2)
    assert_eq(loaded_character.stats.toughness, 4)

func test_max_characters() -> void:
    for i in range(character_manager.MAX_CHARACTERS + 1):
        var char := Character.new()
        char.character_name = "Test Character %d" % i
        char.character_id = "test_char_%d" % i
        if i < character_manager.MAX_CHARACTERS:
            assert_true(character_manager.add_character(char))
        else:
            assert_false(character_manager.add_character(char))
    
    assert_eq(character_manager.get_active_character_count(), character_manager.MAX_CHARACTERS)
    assert_eq(error_messages.size(), 1)
    assert_string_contains(error_messages[0], "Maximum number of characters reached") 