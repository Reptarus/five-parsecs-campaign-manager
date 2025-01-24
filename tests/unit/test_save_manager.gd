extends "res://addons/gut/test.gd"

const SaveManager = preload("res://src/core/state/SaveManager.gd")

var save_manager: SaveManager

func before_each() -> void:
    save_manager = SaveManager.new()
    add_child(save_manager) # Required since it extends Node
    
    # Connect to signals
    save_manager.save_completed.connect(_on_save_completed)
    save_manager.load_completed.connect(_on_load_completed)
    
    # Clean up any existing test saves
    var dir = DirAccess.open(SaveManager.SAVE_DIR)
    if dir:
        dir.list_dir_begin()
        var file_name = dir.get_next()
        while file_name != "":
            if not dir.current_is_dir() and file_name.ends_with(SaveManager.SAVE_FILE_EXTENSION):
                DirAccess.remove_absolute(SaveManager.SAVE_DIR + file_name)
            file_name = dir.get_next()

func after_each() -> void:
    save_manager.save_completed.disconnect(_on_save_completed)
    save_manager.load_completed.disconnect(_on_load_completed)
    remove_child(save_manager)
    save_manager = null

var _last_save_result := false
var _last_save_message := ""
var _last_load_result := false
var _last_load_data := {}

func _on_save_completed(success: bool, message: String) -> void:
    _last_save_result = success
    _last_save_message = message

func _on_load_completed(success: bool, data: Dictionary) -> void:
    _last_load_result = success
    _last_load_data = data

func test_initialization() -> void:
    assert_true(DirAccess.dir_exists_absolute(SaveManager.SAVE_DIR),
                "Should create save directory")

func test_save_game() -> void:
    var test_data := {
        "test_value": 42,
        "test_string": "test"
    }
    
    # Test saving to slot 0
    save_manager.save_game(test_data)
    await get_tree().create_timer(0.1).timeout # Wait for save to complete
    assert_true(_last_save_result, "Should successfully save game")
    assert_true(FileAccess.file_exists(SaveManager.SAVE_DIR + "save_0.save"),
                "Should create save file")
    
    # Test saving to different slot
    save_manager.save_game(test_data, 1)
    await get_tree().create_timer(0.1).timeout
    assert_true(_last_save_result, "Should save to different slot")
    assert_true(FileAccess.file_exists(SaveManager.SAVE_DIR + "save_1.save"),
                "Should create save file in specified slot")
    
    # Test save metadata
    save_manager.load_game(0)
    await get_tree().create_timer(0.1).timeout
    assert_true("save_version" in _last_load_data, "Should include save version")
    assert_true("save_date" in _last_load_data, "Should include save date")
    assert_true("game_version" in _last_load_data, "Should include game version")

func test_load_game() -> void:
    var test_data := {
        "test_value": 42,
        "test_string": "test"
    }
    
    # Setup test save
    save_manager.save_game(test_data)
    await get_tree().create_timer(0.1).timeout
    
    # Test loading save
    save_manager.load_game()
    await get_tree().create_timer(0.1).timeout
    assert_true(_last_load_result, "Should successfully load save")
    assert_eq(_last_load_data.test_value, test_data.test_value, "Should preserve data")
    assert_eq(_last_load_data.test_string, test_data.test_string, "Should preserve data")
    
    # Test loading non-existent save
    save_manager.load_game(99)
    await get_tree().create_timer(0.1).timeout
    assert_false(_last_load_result, "Should fail to load non-existent save")
    assert_eq(_last_load_data.size(), 0, "Should return empty data on failed load")

func test_save_slots() -> void:
    var test_data := {"test": "data"}
    
    # Create saves in multiple slots
    save_manager.save_game(test_data, 0)
    save_manager.save_game(test_data, 1)
    save_manager.save_game(test_data, 2)
    await get_tree().create_timer(0.1).timeout
    
    # Test slot listing
    var slots = save_manager.get_save_slots()
    assert_eq(slots.size(), 3, "Should list all save slots")
    assert_true("save_0" in slots, "Should include slot 0")
    assert_true("save_1" in slots, "Should include slot 1")
    assert_true("save_2" in slots, "Should include slot 2")

func test_backup_system() -> void:
    var test_data := {"version": 1}
    var updated_data := {"version": 2}
    
    # Create initial save
    save_manager.save_game(test_data)
    await get_tree().create_timer(0.1).timeout
    
    # Update save to trigger backup
    save_manager.save_game(updated_data)
    await get_tree().create_timer(0.1).timeout
    
    assert_true(FileAccess.file_exists(SaveManager.SAVE_DIR + "save_0.save.backup"),
                "Should create backup file")
    
    # Verify backup contains original data
    var backup_file = FileAccess.open(SaveManager.SAVE_DIR + "save_0.save.backup", FileAccess.READ)
    var json = JSON.new()
    json.parse(backup_file.get_as_text())
    var backup_data = json.get_data()
    assert_eq(backup_data.version, 1, "Should preserve original data in backup")

func test_error_handling() -> void:
    # Test saving invalid data
    var invalid_data := {"invalid": test_error_handling} # Methods can't be serialized
    save_manager.save_game(invalid_data)
    await get_tree().create_timer(0.1).timeout
    assert_false(_last_save_result, "Should fail to save invalid data")
    
    # Test loading corrupted save
    var file = FileAccess.open(SaveManager.SAVE_DIR + "save_0.save", FileAccess.WRITE)
    file.store_string("corrupted data")
    file.close()
    
    save_manager.load_game()
    await get_tree().create_timer(0.1).timeout
    assert_false(_last_load_result, "Should fail to load corrupted save")
    assert_eq(_last_load_data.size(), 0, "Should return empty data for corrupted save")

func test_invalid_slots() -> void:
    var test_data := {"test": "data"}
    
    # Test saving to invalid slots
    save_manager.save_game(test_data, -1)
    await get_tree().create_timer(0.1).timeout
    assert_false(_last_save_result, "Should fail to save to negative slot")
    
    save_manager.save_game(test_data, SaveManager.MAX_SAVE_SLOTS)
    await get_tree().create_timer(0.1).timeout
    assert_false(_last_save_result, "Should fail to save to slot beyond max")
    
    # Test loading from invalid slots
    save_manager.load_game(-1)
    await get_tree().create_timer(0.1).timeout
    assert_false(_last_load_result, "Should fail to load from negative slot")
    
    save_manager.load_game(SaveManager.MAX_SAVE_SLOTS)
    await get_tree().create_timer(0.1).timeout
    assert_false(_last_load_result, "Should fail to load from slot beyond max")

func test_save_info() -> void:
    var test_data := {"test": "data"}
    
    # Create test save
    save_manager.save_game(test_data)
    await get_tree().create_timer(0.1).timeout
    
    # Test getting save info
    var info = save_manager.get_save_info(0)
    assert_eq(info.version, SaveManager.SAVE_VERSION, "Should return correct save version")
    assert_true("date" in info, "Should include save date")
    assert_true("game_version" in info, "Should include game version")
    
    # Test getting info for non-existent save
    var empty_info = save_manager.get_save_info(99)
    assert_eq(empty_info.size(), 0, "Should return empty info for non-existent save")