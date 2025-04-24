@tool
extends "res://tests/fixtures/base/game_test.gd"

# Load scripts safely - handles missing files gracefully
const Compatibility = preload("res://tests/fixtures/helpers/test_compatibility_helper.gd")
var SaveManagerScript = load("res://src/core/save/SaveManager.gd") if ResourceLoader.exists("res://src/core/save/SaveManager.gd") else null

# Test constants
const TEST_SAVE_DIRECTORY = "user://test_saves"
const TEST_SAVE_FILE = "test_save.save"
const TEST_SAVE_PATH = TEST_SAVE_DIRECTORY + "/" + TEST_SAVE_FILE

# Type-safe instance variables
var _save_manager: Resource = null
var _test_game_state: Resource = null

func before_each() -> void:
	await super.before_each()
	if not SaveManagerScript:
		push_error("SaveManagerScript is null")
		return
		
	_save_manager = SaveManagerScript.new()
	if not _save_manager:
		push_error("Failed to create save manager")
		return
		
	# Ensure resource has a valid path for Godot 4.4
	_save_manager = Compatibility.ensure_resource_path(_save_manager, "test_save_manager")
	
	track_test_resource(_save_manager)
	await get_tree().process_frame

func after_each() -> void:
	await super.after_each()
	_save_manager = null

func test_initialization() -> void:
	if not _save_manager:
		pending("Save manager is null, skipping test")
		return
		
	assert_not_null(_save_manager, "Save manager should be initialized")
	
	var save_directory: String = Compatibility.safe_cast_to_string(_save_manager.get_save_directory(), "")
	var auto_save_enabled: bool = Compatibility.call_node_method_bool(_save_manager, "is_auto_save_enabled", [], false)
	var auto_save_interval: int = Compatibility.call_node_method_int(_save_manager, "get_auto_save_interval", [], 0)
	
	assert_ne(save_directory, "", "Should initialize with valid save directory")
	assert_true(auto_save_enabled, "Should initialize with auto-save enabled")
	assert_gt(auto_save_interval, 0, "Should initialize with positive auto-save interval")

func test_save_file_management() -> void:
	if not _save_manager:
		pending("Save manager is null, skipping test")
		return
		
	# Test creating save file
	var test_data := {
		"test_key": "test_value",
		"number": 42,
		"array": [1, 2, 3]
	}
	
	var success: bool = Compatibility.call_node_method_bool(_save_manager, "create_save", ["test_save", test_data], false)
	assert_true(success, "Should create save file")
	
	# Test loading save file
	var loaded_data: Dictionary = Compatibility.call_node_method_dict(_save_manager, "load_save", ["test_save"], {})
	if loaded_data.size() > 0:
		# Use safe dictionary access
		assert_eq(loaded_data.get("test_key", ""), test_data.get("test_key", ""), "Should load correct data")
		assert_eq(loaded_data.get("number", 0), test_data.get("number", 0), "Should preserve number values")
		assert_eq(loaded_data.get("array", []), test_data.get("array", []), "Should preserve array values")
	else:
		assert_true(false, "Failed to load save data")
	
	# Test save file listing
	var save_files: Array = Compatibility.call_node_method_array(_save_manager, "get_save_files", [], [])
	assert_true(save_files.has("test_save"), "Should list created save file")
	
	# Test deleting save file
	success = Compatibility.call_node_method_bool(_save_manager, "delete_save", ["test_save"], false)
	assert_true(success, "Should delete save file")
	
	save_files = Compatibility.call_node_method_array(_save_manager, "get_save_files", [], [])
	assert_false(save_files.has("test_save"), "Should remove deleted save file from list")

func test_auto_save_functionality() -> void:
	if not _save_manager:
		pending("Save manager is null, skipping test")
		return
		
	# Test auto-save configuration
	Compatibility.call_node_method_bool(_save_manager, "set_auto_save_enabled", [false])
	var auto_save_enabled: bool = Compatibility.call_node_method_bool(_save_manager, "is_auto_save_enabled", [], true)
	assert_false(auto_save_enabled, "Should disable auto-save")
	
	Compatibility.call_node_method_bool(_save_manager, "set_auto_save_interval", [30])
	var auto_save_interval: int = Compatibility.call_node_method_int(_save_manager, "get_auto_save_interval", [], 0)
	assert_eq(auto_save_interval, 30, "Should update auto-save interval")
	
	# Test auto-save trigger
	Compatibility.call_node_method_bool(_save_manager, "set_auto_save_enabled", [true])
	var test_data := {"auto_save_test": true}
	Compatibility.call_node_method_bool(_save_manager, "update_auto_save_data", [test_data])
	
	await get_tree().create_timer(auto_save_interval + 1).timeout
	
	var auto_save_files: Array = Compatibility.call_node_method_array(_save_manager, "get_auto_save_files", [], [])
	assert_gt(auto_save_files.size(), 0, "Should create auto-save file")
	
	if auto_save_files.size() > 0:
		var loaded_auto_save: Dictionary = Compatibility.call_node_method_dict(_save_manager, "load_auto_save", [auto_save_files[0]], {})
		# Use safe dictionary access
		assert_eq(loaded_auto_save.get("auto_save_test", false), test_data.get("auto_save_test", false), "Should preserve auto-save data")

func test_save_data_validation() -> void:
	if not _save_manager:
		pending("Save manager is null, skipping test")
		return
		
	# Test invalid save data
	var invalid_data = null
	var success: bool = Compatibility.call_node_method_bool(_save_manager, "create_save", ["invalid_save", invalid_data], false)
	assert_false(success, "Should reject invalid save data")
	
	# Test empty save name
	success = Compatibility.call_node_method_bool(_save_manager, "create_save", ["", {"valid": "data"}], false)
	assert_false(success, "Should reject empty save name")
	
	# Test invalid characters in save name
	success = Compatibility.call_node_method_bool(_save_manager, "create_save", ["invalid/save\\name", {"valid": "data"}], false)
	assert_false(success, "Should reject invalid save name characters")
	
	# Test loading non-existent save
	var loaded_data: Dictionary = Compatibility.call_node_method_dict(_save_manager, "load_save", ["non_existent_save"], {})
	assert_eq(loaded_data.size(), 0, "Should return empty dictionary for non-existent save")

func test_save_backup_management() -> void:
	if not _save_manager:
		pending("Save manager is null, skipping test")
		return
		
	# Test creating backup
	var test_data := {"backup_test": true}
	var success: bool = Compatibility.call_node_method_bool(_save_manager, "create_backup", ["test_save", test_data], false)
	assert_true(success, "Should create backup")
	
	# Test listing backups
	var backups: Array = Compatibility.call_node_method_array(_save_manager, "get_backups", ["test_save"], [])
	assert_gt(backups.size(), 0, "Should list created backup")
	
	if backups.size() > 0:
		# Test loading backup
		var loaded_backup: Dictionary = Compatibility.call_node_method_dict(_save_manager, "load_backup", ["test_save", backups[0]], {})
		# Use safe dictionary access
		assert_eq(loaded_backup.get("backup_test", false), test_data.get("backup_test", false), "Should load correct backup data")
	
	# Test backup rotation
	for i in range(10):
		Compatibility.call_node_method_bool(_save_manager, "create_backup", ["test_save", {"backup_number": i}])
	
	backups = Compatibility.call_node_method_array(_save_manager, "get_backups", ["test_save"], [])
	var max_backups: int = Compatibility.call_node_method_int(_save_manager, "get_max_backups", [], 0)
	assert_le(backups.size(), max_backups, "Should maintain maximum number of backups")
	
	# Test deleting backups
	success = Compatibility.call_node_method_bool(_save_manager, "delete_backups", ["test_save"], false)
	assert_true(success, "Should delete all backups")
	
	backups = Compatibility.call_node_method_array(_save_manager, "get_backups", ["test_save"], [])
	assert_eq(backups.size(), 0, "Should have no backups after deletion")

func test_save_metadata() -> void:
	if not _save_manager:
		pending("Save manager is null, skipping test")
		return
		
	# Test save metadata creation
	var test_data := {"game_data": "test"}
	var metadata := {
		"timestamp": Time.get_unix_time_from_system(),
		"version": "1.0.0",
		"description": "Test save"
	}
	
	var success: bool = Compatibility.call_node_method_bool(_save_manager, "create_save_with_metadata",
		["test_save", test_data, metadata], false)
	assert_true(success, "Should create save with metadata")
	
	# Test metadata retrieval
	var save_metadata: Dictionary = Compatibility.call_node_method_dict(_save_manager, "get_save_metadata", ["test_save"], {})
	
	# Use safe dictionary access
	assert_eq(save_metadata.get("version", ""), metadata.get("version", ""), "Should preserve version metadata")
	assert_eq(save_metadata.get("description", ""), metadata.get("description", ""), "Should preserve description metadata")
	
	# Test metadata update
	var updated_metadata := metadata.duplicate()
	updated_metadata["description"] = "Updated test save"
	success = Compatibility.call_node_method_bool(_save_manager, "update_save_metadata",
		["test_save", updated_metadata], false)
	assert_true(success, "Should update save metadata")
	
	save_metadata = Compatibility.call_node_method_dict(_save_manager, "get_save_metadata", ["test_save"], {})
	assert_eq(save_metadata.get("description", ""), updated_metadata.get("description", ""), "Should reflect updated metadata")

func test_save_compression() -> void:
	if not _save_manager:
		pending("Save manager is null, skipping test")
		return
		
	# Test compressed save creation
	var large_data := {"array": []}
	for i in range(1000):
		large_data.array.append("test_data_" + str(i))
	
	var success: bool = Compatibility.call_node_method_bool(_save_manager, "create_compressed_save",
		["compressed_save", large_data], false)
	assert_true(success, "Should create compressed save")
	
	# Test compressed save loading
	var loaded_data: Dictionary = Compatibility.call_node_method_dict(_save_manager, "load_compressed_save",
		["compressed_save"], {})
		
	# Use safe dictionary access
	var loaded_array = loaded_data.get("array", [])
	var large_data_array = large_data.get("array", [])
	assert_eq(loaded_array.size(), large_data_array.size(), "Should preserve all data in compressed save")
	
	# Test compression ratio
	var uncompressed_size: int = Compatibility.call_node_method_int(_save_manager, "get_uncompressed_size",
		["compressed_save"], 0)
	var compressed_size: int = Compatibility.call_node_method_int(_save_manager, "get_compressed_size",
		["compressed_save"], 0)
	assert_lt(compressed_size, uncompressed_size, "Should achieve compression")

# Add missing assertion functions directly in this file
func assert_le(a, b, text: String = "") -> void:
	if text.length() > 0:
		assert_true(a <= b, text)
	else:
		assert_true(a <= b, "Expected %s <= %s" % [a, b])

func assert_ge(a, b, text: String = "") -> void:
	if text.length() > 0:
		assert_true(a >= b, text)
	else:
		assert_true(a >= b, "Expected %s >= %s" % [a, b])
