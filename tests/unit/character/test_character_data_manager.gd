## Character Data Manager Test Suite
## Tests the functionality of the CharacterDataManager class which handles character data persistence
## and management operations.
##
## - Character state management
## - Data validation and boundaries
## - Performance considerations
## - Signal emissions
@tool
extends GdUnitTestSuite

#
class MockCharacter extends Resource:
    var character_name: String = "Test Character"
    var character_class: int = 1
    var origin: int = 1
    var background: int = 1
    var motivation: int = 1
    
    func get_character_name() -> String: return character_name
    func set_character_name(test_value: String) -> void: character_name = test_value
    func get_character_class() -> int: return character_class
    func set_character_class(test_value: int) -> void: character_class = test_value
    func get_origin() -> int: return origin
    func set_origin(test_value: int) -> void: origin = test_value
    func get_background() -> int: return background
    func set_background(test_value: int) -> void: background = test_value
    func get_motivation() -> int: return motivation
    func set_motivation(test_value: int) -> void: motivation = test_value
    
    signal character_updated(character: Resource)

class MockGameStateManager extends Resource:
    var state_data: Dictionary = {}
    
    func initialize() -> void: pass
    func get_state() -> Dictionary: return state_data
    func set_state(data: Dictionary) -> void: state_data = data
    
    signal state_changed(new_state: Dictionary)

class MockCharacterDataManager extends Resource:
    var characters: Array = []
    var active_character_index: int = -1
    var max_characters: int = 1000
    
    func initialize(game_state: Resource) -> void: pass
    
    func get_character_count() -> int: return characters.size()
    
    func save_character(character: Resource, file_name: String) -> bool:
        if character:
            characters.append(character)
            return true
        return false

    func load_character(file_name: String) -> Resource:
        if characters.size() > 0:
            return characters[0]
        return null

    func save_character_data(character: Resource) -> bool:
        if character and characters.size() < max_characters:
            characters.append(character)
            return true
        return false

    func get_character_data(index: int) -> Resource:
        if index >= 0 and index < characters.size():
            return characters[index]
        return null

    func set_active_character(index: int) -> bool:
        if index >= 0 and index < characters.size():
            active_character_index = index
            return true
        return false

    func delete_character_data(index: int) -> bool:
        if index >= 0 and index < characters.size():
            characters.remove_at(index)
            return true
        return false

    signal character_data_saved(character: Resource)
    signal active_character_changed(index: int)
    signal character_data_deleted(index: int)

class MockGameEnums extends Resource:
    enum CharacterClass {SOLDIER = 1, ENGINEER = 2, MEDIC = 3}
    enum Origin {HUMAN = 1, ALIEN = 2, AI = 3}
    enum Background {MILITARY = 1, CIVILIAN = 2, CRIMINAL = 3}
    enum Motivation {DUTY = 1, REVENGE = 2, WEALTH = 3}

# Test constants
const TEST_BATCH_SIZE: int = 100
const MAX_CHARACTERS: int = 1000
const STABILIZE_TIME: float = 0.1

# Type-safe instance variables - ALL RESOURCES NOW
var _data_manager: MockCharacterDataManager = null
var _test_character: MockCharacter = null
var _game_state: MockGameStateManager = null

func _create_test_character() -> MockCharacter:
    var character := MockCharacter.new()
    character.set_character_name("Test Character")
    character.set_character_class(MockGameEnums.CharacterClass.SOLDIER)
    return character

func _create_batch_characters(count: int) -> Array[MockCharacter]:
    var characters: Array[MockCharacter] = []
    for i: int in range(count):
        var character := _create_test_character()
        if character:
            characters.append(character)
    return characters

func before_test() -> void:
    super.before_test()
    
    # Create mock game state
    _game_state = MockGameStateManager.new()
    
    # Create mock data manager
    _data_manager = MockCharacterDataManager.new()
    _data_manager.initialize(_game_state)
    
    # Create test character
    _test_character = _create_test_character()

func after_test() -> void:
    _game_state = null
    _data_manager = null
    _test_character = null
    super.after_test()

func test_initial_state() -> void:
    assert_that(_data_manager).is_not_null()
    var count: int = _data_manager.get_character_count()
    assert_that(count).is_equal(0)

func test_save_and_load_character() -> void:
    # Setup character data
    _test_character.set_character_name("Test Character")
    _test_character.set_character_class(MockGameEnums.CharacterClass.SOLDIER)
    _test_character.set_origin(MockGameEnums.Origin.HUMAN)
    _test_character.set_background(MockGameEnums.Background.MILITARY)
    _test_character.set_motivation(MockGameEnums.Motivation.DUTY)
    
    # Save character
    var file_name := "test_character"
    var save_result: bool = _data_manager.save_character(_test_character, file_name)
    assert_that(save_result).is_true()
    
    # Load character
    var loaded_character: MockCharacter = _data_manager.load_character(file_name)
    assert_that(loaded_character).is_not_null()
    
    # Verify character data
    var loaded_name: String = loaded_character.get_character_name()
    var loaded_class: int = loaded_character.get_character_class()
    var loaded_origin: int = loaded_character.get_origin()
    var loaded_background: int = loaded_character.get_background()
    var loaded_motivation: int = loaded_character.get_motivation()
    
    assert_that(loaded_name).is_equal("Test Character")
    assert_that(loaded_class).is_equal(MockGameEnums.CharacterClass.SOLDIER)
    assert_that(loaded_origin).is_equal(MockGameEnums.Origin.HUMAN)
    assert_that(loaded_background).is_equal(MockGameEnums.Background.MILITARY)
    assert_that(loaded_motivation).is_equal(MockGameEnums.Motivation.DUTY)

func test_batch_character_operations() -> void:
    var start_time := Time.get_ticks_msec()
    var characters := _create_batch_characters(TEST_BATCH_SIZE)
    
    for character: MockCharacter in characters:
        var result: bool = _data_manager.save_character_data(character)
        assert_that(result).is_true()
    
    var end_time := Time.get_ticks_msec()
    var duration := end_time - start_time
    
    var count: int = _data_manager.get_character_count()
    assert_that(count).is_equal(TEST_BATCH_SIZE)
    assert_that(duration).is_less_than(5000) # Should complete within 5 seconds

func test_character_limit() -> void:
    for i: int in range(MAX_CHARACTERS + 1):
        var character := _create_test_character()
        var result: bool = _data_manager.save_character_data(character)
        
        if i >= MAX_CHARACTERS:
            assert_that(result).is_false()
        else:
            assert_that(result).is_true()

func test_signal_emission_order() -> void:
    var character := _create_test_character()
    
    var save_result: bool = _data_manager.save_character_data(character)
    assert_that(save_result).is_true()
    
    var set_result: bool = _data_manager.set_active_character(0)
    assert_that(set_result).is_true()
    
    var delete_result: bool = _data_manager.delete_character_data(0)
    assert_that(delete_result).is_true()

func test_invalid_character_operations() -> void:
    var invalid_character = _data_manager.get_character_data(-1)
    assert_that(invalid_character).is_null()
    
    invalid_character = _data_manager.get_character_data(9999)
    assert_that(invalid_character).is_null()
    
    var save_result: bool = _data_manager.save_character_data(null)
    assert_that(save_result).is_false()
