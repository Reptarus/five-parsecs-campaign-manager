@tool
extends "res://tests/fixtures/base/game_test.gd"

const SaveManager: GDScript = preload("res://src/core/state/SaveManager.gd")

var save_manager: Resource = null

func before_each() -> void:
    await super.before_each()
    save_manager = SaveManager.new()
    if not save_manager:
        push_error("Failed to create save manager")
        return
    track_test_resource(save_manager)
    await get_tree().process_frame

func after_each() -> void:
    await super.after_each()
    save_manager = null

func test_initialization() -> void:
    assert_not_null(save_manager, "Save manager should be initialized")
    
    var save_directory: String = TypeSafeMixin._safe_cast_to_string(TypeSafeMixin._call_node_method(save_manager, "get_save_directory", []), "")
    var auto_save_enabled: bool = TypeSafeMixin._call_node_method_bool(save_manager, "is_auto_save_enabled", [], false)
    var auto_save_interval: int = TypeSafeMixin._call_node_method_int(save_manager, "get_auto_save_interval", [], 0)
    
    assert_ne(save_directory, "", "Should initialize with valid save directory")
    assert_true(auto_save_enabled, "Should initialize with auto-save enabled")
    assert_gt(auto_save_interval, 0, "Should initialize with positive auto-save interval")

func test_save_file_management() -> void:
    # Test creating save file
    var test_data := {
        "test_key": "test_value",
        "number": 42,
        "array": [1, 2, 3]
    }
    
    var success: bool = TypeSafeMixin._call_node_method_bool(save_manager, "create_save", ["test_save", test_data], false)
    assert_true(success, "Should create save file")
    
    # Test loading save file
    var loaded_data: Dictionary = TypeSafeMixin._call_node_method_dict(save_manager, "load_save", ["test_save"], {})
    assert_eq(loaded_data.test_key, test_data.test_key, "Should load correct data")
    assert_eq(loaded_data.number, test_data.number, "Should preserve number values")
    assert_eq(loaded_data.array, test_data.array, "Should preserve array values")
    
    # Test save file listing
    var save_files: Array = TypeSafeMixin._call_node_method_array(save_manager, "get_save_files", [], [])
    assert_true("test_save" in save_files, "Should list created save file")
    
    # Test deleting save file
    success = TypeSafeMixin._call_node_method_bool(save_manager, "delete_save", ["test_save"], false)
    assert_true(success, "Should delete save file")
    
    save_files = TypeSafeMixin._call_node_method_array(save_manager, "get_save_files", [], [])
    assert_false("test_save" in save_files, "Should remove deleted save file from list")

func test_auto_save_functionality() -> void:
    # Test auto-save configuration
    TypeSafeMixin._call_node_method_bool(save_manager, "set_auto_save_enabled", [false])
    var auto_save_enabled: bool = TypeSafeMixin._call_node_method_bool(save_manager, "is_auto_save_enabled", [], true)
    assert_false(auto_save_enabled, "Should disable auto-save")
    
    TypeSafeMixin._call_node_method_bool(save_manager, "set_auto_save_interval", [30])
    var auto_save_interval: int = TypeSafeMixin._call_node_method_int(save_manager, "get_auto_save_interval", [], 0)
    assert_eq(auto_save_interval, 30, "Should update auto-save interval")
    
    # Test auto-save trigger
    TypeSafeMixin._call_node_method_bool(save_manager, "set_auto_save_enabled", [true])
    var test_data := {"auto_save_test": true}
    TypeSafeMixin._call_node_method_bool(save_manager, "update_auto_save_data", [test_data])
    
    await get_tree().create_timer(auto_save_interval + 1).timeout
    
    var auto_save_files: Array = TypeSafeMixin._call_node_method_array(save_manager, "get_auto_save_files", [], [])
    assert_gt(auto_save_files.size(), 0, "Should create auto-save file")
    
    var loaded_auto_save: Dictionary = TypeSafeMixin._call_node_method_dict(save_manager, "load_auto_save", [auto_save_files[0]], {})
    assert_eq(loaded_auto_save.auto_save_test, test_data.auto_save_test, "Should preserve auto-save data")

func test_save_data_validation() -> void:
    # Test invalid save data
    var invalid_data = null
    var success: bool = TypeSafeMixin._call_node_method_bool(save_manager, "create_save", ["invalid_save", invalid_data], false)
    assert_false(success, "Should reject invalid save data")
    
    # Test empty save name
    success = TypeSafeMixin._call_node_method_bool(save_manager, "create_save", ["", {"valid": "data"}], false)
    assert_false(success, "Should reject empty save name")
    
    # Test invalid characters in save name
    success = TypeSafeMixin._call_node_method_bool(save_manager, "create_save", ["invalid/save\\name", {"valid": "data"}], false)
    assert_false(success, "Should reject invalid save name characters")
    
    # Test loading non-existent save
    var loaded_data: Dictionary = TypeSafeMixin._call_node_method_dict(save_manager, "load_save", ["non_existent_save"], {})
    assert_eq(loaded_data.size(), 0, "Should return empty dictionary for non-existent save")

func test_save_backup_management() -> void:
    # Test creating backup
    var test_data := {"backup_test": true}
    var success: bool = TypeSafeMixin._call_node_method_bool(save_manager, "create_backup", ["test_save", test_data], false)
    assert_true(success, "Should create backup")
    
    # Test listing backups
    var backups: Array = TypeSafeMixin._call_node_method_array(save_manager, "get_backups", ["test_save"], [])
    assert_gt(backups.size(), 0, "Should list created backup")
    
    # Test loading backup
    var loaded_backup: Dictionary = TypeSafeMixin._call_node_method_dict(save_manager, "load_backup", ["test_save", backups[0]], {})
    assert_eq(loaded_backup.backup_test, test_data.backup_test, "Should load correct backup data")
    
    # Test backup rotation
    for i in range(10):
        TypeSafeMixin._call_node_method_bool(save_manager, "create_backup", ["test_save", {"backup_number": i}])
    
    backups = TypeSafeMixin._call_node_method_array(save_manager, "get_backups", ["test_save"], [])
    var max_backups: int = TypeSafeMixin._call_node_method_int(save_manager, "get_max_backups", [], 0)
    assert_le(backups.size(), max_backups, "Should maintain maximum number of backups")
    
    # Test deleting backups
    success = TypeSafeMixin._call_node_method_bool(save_manager, "delete_backups", ["test_save"], false)
    assert_true(success, "Should delete all backups")
    
    backups = TypeSafeMixin._call_node_method_array(save_manager, "get_backups", ["test_save"], [])
    assert_eq(backups.size(), 0, "Should have no backups after deletion")

func test_save_metadata() -> void:
    # Test save metadata creation
    var test_data := {"game_data": "test"}
    var metadata := {
        "timestamp": Time.get_unix_time_from_system(),
        "version": "1.0.0",
        "description": "Test save"
    }
    
    var success: bool = TypeSafeMixin._call_node_method_bool(save_manager, "create_save_with_metadata",
        ["test_save", test_data, metadata], false)
    assert_true(success, "Should create save with metadata")
    
    # Test metadata retrieval
    var save_metadata: Dictionary = TypeSafeMixin._call_node_method_dict(save_manager, "get_save_metadata", ["test_save"], {})
    assert_eq(save_metadata.version, metadata.version, "Should preserve version metadata")
    assert_eq(save_metadata.description, metadata.description, "Should preserve description metadata")
    
    # Test metadata update
    var updated_metadata := metadata.duplicate()
    updated_metadata.description = "Updated test save"
    success = TypeSafeMixin._call_node_method_bool(save_manager, "update_save_metadata",
        ["test_save", updated_metadata], false)
    assert_true(success, "Should update save metadata")
    
    save_metadata = TypeSafeMixin._call_node_method_dict(save_manager, "get_save_metadata", ["test_save"], {})
    assert_eq(save_metadata.description, updated_metadata.description, "Should reflect updated metadata")

func test_save_compression() -> void:
    # Test compressed save creation
    var large_data := {"array": []}
    for i in range(1000):
        large_data.array.append("test_data_" + str(i))
    
    var success: bool = TypeSafeMixin._call_node_method_bool(save_manager, "create_compressed_save",
        ["compressed_save", large_data], false)
    assert_true(success, "Should create compressed save")
    
    # Test compressed save loading
    var loaded_data: Dictionary = TypeSafeMixin._call_node_method_dict(save_manager, "load_compressed_save",
        ["compressed_save"], {})
    assert_eq(loaded_data.array.size(), large_data.array.size(), "Should preserve all data in compressed save")
    
    # Test compression ratio
    var uncompressed_size: int = TypeSafeMixin._call_node_method_int(save_manager, "get_uncompressed_size",
        ["compressed_save"], 0)
    var compressed_size: int = TypeSafeMixin._call_node_method_int(save_manager, "get_compressed_size",
        ["compressed_save"], 0)
    assert_lt(compressed_size, uncompressed_size, "Should achieve compression")