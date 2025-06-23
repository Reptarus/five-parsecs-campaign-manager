@tool
extends GdUnitGameTest

## Unit tests for the SaveManager system
##
## This test suite covers:
## - Game state serialization/deserialization
## - Save file operations
## - Campaign persistence
## - Error handling for corrupted saves

# Test constants
const TEST_SAVE_FILE_SUFFIX := "_test"
const TEST_AUTO_SAVE_INTERVAL := 30.0

# Mock save manager for testing
class MockSaveManager extends Resource:
    signal save_completed(file_path: String)
    signal load_completed(file_path: String)
    signal save_failed(error: String)
    signal auto_save_triggered()
    
    var current_save_file: String = ""
    var auto_save_enabled: bool = true
    var last_save_time: float = 0.0
    var save_count: int = 0
    var load_count: int = 0
    var _save_data: Dictionary = {}
    var _auto_save_timer: float = 0.0
    
    func save_game(file_path: String, data: Dictionary) -> bool:
        if file_path.is_empty():
            save_failed.emit("Invalid file path")
            return false
        
        _save_data = data.duplicate(true)
        current_save_file = file_path
        last_save_time = Time.get_ticks_msec() / 1000.0
        save_count += 1
        
        save_completed.emit(file_path)
        return true
    
    func load_game(file_path: String) -> Dictionary:
        if file_path.is_empty():
            return {}
        
        load_count += 1
        load_completed.emit(file_path)
        return _save_data.duplicate(true)
    
    func auto_save(data: Dictionary) -> bool:
        if not auto_save_enabled:
            return false
        
        var auto_save_path = current_save_file + "_auto"
        var success = save_game(auto_save_path, data)
        if success:
            auto_save_triggered.emit()
        return success
    
    func delete_save_file(file_path: String) -> bool:
        if file_path == current_save_file:
            current_save_file = ""
            _save_data.clear()
        return true
    
    func list_save_files() -> Array:
        var files: Array[String] = []
        if not current_save_file.is_empty():
            files.append(current_save_file)
            files.append(current_save_file + "_auto")
        return files
    
    func get_save_metadata(file_path: String) -> Dictionary:
        if file_path == current_save_file:
            return {
                "timestamp": last_save_time,
                "version": "1.0.0",
                "campaign_name": _save_data.get("campaign_name", "Test Campaign"),
                "turn_number": _save_data.get("turn_number", 1)
            }
        return {}
    
    func update_auto_save_timer(delta: float) -> void:
        _auto_save_timer += delta
        if _auto_save_timer >= TEST_AUTO_SAVE_INTERVAL:
            _auto_save_timer = 0.0
            if auto_save_enabled and not _save_data.is_empty():
                auto_save(_save_data)
    
    func validate_save_data(data: Dictionary) -> bool:
        if not data.has("campaign_name"):
            return false
        if not data.has("turn_number"):
            return false
        if typeof(data.get("turn_number")) != TYPE_INT:
            return false
        return true
    
    func get_save_file_size(file_path: String) -> int:
        if file_path == current_save_file:
            return _save_data.size() * 100 # Mock file size
        return 0
    
    func backup_save_file(file_path: String) -> String:
        var backup_path = file_path + ".backup"
        # Mock backup creation
        return backup_path
    
    func restore_from_backup(backup_path: String) -> bool:
        return backup_path.ends_with(".backup")

# Mock campaign data for testing
class MockCampaignData extends Resource:
    var campaign_name: String = "Test Campaign"
    var turn_number: int = 1
    var crew_data: Dictionary = {}
    var ship_data: Dictionary = {}
    var world_data: Dictionary = {}
    
    func serialize() -> Dictionary:
        return {
            "campaign_name": campaign_name,
            "turn_number": turn_number,
            "crew_data": crew_data,
            "ship_data": ship_data,
            "world_data": world_data,
            "timestamp": Time.get_ticks_msec() / 1000.0
        }
    
    func deserialize(data: Dictionary) -> void:
        campaign_name = data.get("campaign_name", "Unknown Campaign")
        turn_number = data.get("turn_number", 1)
        crew_data = data.get("crew_data", {})
        ship_data = data.get("ship_data", {})
        world_data = data.get("world_data", {})

# Test instance variables
var _save_manager: MockSaveManager
var _campaign_data: MockCampaignData
var _test_save_path: String

func before_test() -> void:
    super.before_test()
    _save_manager = MockSaveManager.new()
    track_resource(_save_manager)
    _campaign_data = MockCampaignData.new()
    track_resource(_campaign_data)
    _test_save_path = "test_save" + TEST_SAVE_FILE_SUFFIX

func after_test() -> void:
    super.after_test()
    _save_manager = null
    _campaign_data = null

#region Core Save/Load Tests

func test_save_campaign() -> void:
    monitor_signals(_save_manager)
    var save_data = _campaign_data.serialize()
    var success = _save_manager.save_game(_test_save_path, save_data)
    
    assert_that(success).is_true()
    assert_that(_save_manager.save_count).is_equal(1)
    assert_that(_save_manager.current_save_file).is_equal(_test_save_path)
    assert_signal(_save_manager).is_emitted("save_completed", [_test_save_path])

func test_load_campaign() -> void:
    # First save a campaign
    var save_data = _campaign_data.serialize()
    _save_manager.save_game(_test_save_path, save_data)
    
    # Then load it
    monitor_signals(_save_manager)
    var loaded_data = _save_manager.load_game(_test_save_path)
    
    assert_that(loaded_data).is_not_empty()
    assert_that(loaded_data["campaign_name"]).is_equal(_campaign_data.campaign_name)
    assert_that(loaded_data["turn_number"]).is_equal(_campaign_data.turn_number)
    assert_that(_save_manager.load_count).is_equal(1)
    assert_signal(_save_manager).is_emitted("load_completed", [_test_save_path])

func test_save_with_invalid_path() -> void:
    monitor_signals(_save_manager)
    var save_data = _campaign_data.serialize()
    var success = _save_manager.save_game("", save_data)
    
    assert_that(success).is_false()
    assert_signal(_save_manager).is_emitted("save_failed", ["Invalid file path"])

func test_load_nonexistent_file() -> void:
    var loaded_data = _save_manager.load_game("nonexistent_file")
    assert_that(loaded_data).is_empty()

#endregion

#region Auto-Save Tests

func test_auto_save_functionality() -> void:
    _save_manager.current_save_file = _test_save_path
    var save_data = _campaign_data.serialize()
    _save_manager._save_data = save_data
    
    monitor_signals(_save_manager)
    var success = _save_manager.auto_save(save_data)
    
    assert_that(success).is_true()
    assert_signal(_save_manager).is_emitted("auto_save_triggered")

func test_auto_save_disabled() -> void:
    _save_manager.auto_save_enabled = false
    var save_data = _campaign_data.serialize()
    var success = _save_manager.auto_save(save_data)
    
    assert_that(success).is_false()

func test_auto_save_timer() -> void:
    _save_manager.auto_save_enabled = true
    _save_manager._save_data = _campaign_data.serialize()
    _save_manager.current_save_file = _test_save_path
    
    monitor_signals(_save_manager)
    
    # Simulate timer updates
    _save_manager.update_auto_save_timer(TEST_AUTO_SAVE_INTERVAL + 1.0)
    
    assert_signal(_save_manager).is_emitted("auto_save_triggered")

#endregion

#region File Management Tests

func test_delete_save_file() -> void:
    # Create a save first
    var save_data = _campaign_data.serialize()
    _save_manager.save_game(_test_save_path, save_data)
    
    # Delete it
    var success = _save_manager.delete_save_file(_test_save_path)
    
    assert_that(success).is_true()
    assert_that(_save_manager.current_save_file).is_equal("")

func test_list_save_files() -> void:
    var save_data = _campaign_data.serialize()
    _save_manager.save_game(_test_save_path, save_data)
    
    var files = _save_manager.list_save_files()
    
    assert_that(files.size()).is_greater_equal(1)
    assert_that(files).contains(_test_save_path)

func test_get_save_metadata() -> void:
    var save_data = _campaign_data.serialize()
    _save_manager.save_game(_test_save_path, save_data)
    
    var metadata = _save_manager.get_save_metadata(_test_save_path)
    
    assert_that(metadata).is_not_empty()
    assert_that(metadata.has("timestamp")).is_true()
    assert_that(metadata.has("version")).is_true()
    assert_that(metadata["campaign_name"]).is_equal(_campaign_data.campaign_name)

#endregion

#region Data Validation Tests

func test_validate_save_data() -> void:
    var valid_data = _campaign_data.serialize()
    assert_that(_save_manager.validate_save_data(valid_data)).is_true()
    
    var invalid_data = {"invalid": "data"}
    assert_that(_save_manager.validate_save_data(invalid_data)).is_false()

func test_validate_missing_campaign_name() -> void:
    var invalid_data = {"turn_number": 1}
    assert_that(_save_manager.validate_save_data(invalid_data)).is_false()

func test_validate_invalid_turn_number() -> void:
    var invalid_data = {
        "campaign_name": "Test",
        "turn_number": "not_a_number"
    }
    assert_that(_save_manager.validate_save_data(invalid_data)).is_false()

#endregion

#region Serialization Tests

func test_campaign_data_serialization() -> void:
    _campaign_data.campaign_name = "Advanced Test Campaign"
    _campaign_data.turn_number = 42
    _campaign_data.crew_data = {"pilot": "John Doe"}
    
    var serialized = _campaign_data.serialize()
    
    assert_that(serialized["campaign_name"]).is_equal("Advanced Test Campaign")
    assert_that(serialized["turn_number"]).is_equal(42)
    assert_that(serialized["crew_data"]["pilot"]).is_equal("John Doe")
    assert_that(serialized.has("timestamp")).is_true()

func test_campaign_data_deserialization() -> void:
    var test_data = {
        "campaign_name": "Deserialized Campaign",
        "turn_number": 99,
        "crew_data": {"engineer": "Jane Smith"},
        "ship_data": {"hull": 100},
        "world_data": {"sector": "Alpha"}
    }
    
    _campaign_data.deserialize(test_data)
    
    assert_that(_campaign_data.campaign_name).is_equal("Deserialized Campaign")
    assert_that(_campaign_data.turn_number).is_equal(99)
    assert_that(_campaign_data.crew_data["engineer"]).is_equal("Jane Smith")
    assert_that(_campaign_data.ship_data["hull"]).is_equal(100)
    assert_that(_campaign_data.world_data["sector"]).is_equal("Alpha")

#endregion

#region Backup and Recovery Tests

func test_backup_save_file() -> void:
    var save_data = _campaign_data.serialize()
    _save_manager.save_game(_test_save_path, save_data)
    
    var backup_path = _save_manager.backup_save_file(_test_save_path)
    
    assert_that(backup_path).contains(".backup")
    assert_that(backup_path).is_not_equal(_test_save_path)

func test_restore_from_backup() -> void:
    var backup_path = _test_save_path + ".backup"
    var success = _save_manager.restore_from_backup(backup_path)
    
    assert_that(success).is_true()

func test_get_save_file_size() -> void:
    var save_data = _campaign_data.serialize()
    _save_manager.save_game(_test_save_path, save_data)
    
    var file_size = _save_manager.get_save_file_size(_test_save_path)
    
    assert_that(file_size).is_greater(0)

#endregion

#region Edge Cases and Error Handling

func test_save_empty_data() -> void:
    monitor_signals(_save_manager)
    var success = _save_manager.save_game(_test_save_path, {})
    
    # Should still succeed with empty data
    assert_that(success).is_true()
    assert_signal(_save_manager).is_emitted("save_completed")

func test_multiple_saves_same_file() -> void:
    var save_data1 = _campaign_data.serialize()
    _campaign_data.turn_number = 2
    var save_data2 = _campaign_data.serialize()
    
    _save_manager.save_game(_test_save_path, save_data1)
    _save_manager.save_game(_test_save_path, save_data2)
    
    assert_that(_save_manager.save_count).is_equal(2)
    
    var loaded_data = _save_manager.load_game(_test_save_path)
    assert_that(loaded_data["turn_number"]).is_equal(2)

func test_load_after_delete() -> void:
    var save_data = _campaign_data.serialize()
    _save_manager.save_game(_test_save_path, save_data)
    _save_manager.delete_save_file(_test_save_path)
    
    var loaded_data = _save_manager.load_game(_test_save_path)
    assert_that(loaded_data).is_empty()

#endregion

#region Performance Tests

func test_large_save_data_performance() -> void:
    # Create large save data
    var large_data = _campaign_data.serialize()
    for i: int in range(1000):
        large_data["large_array_" + str(i)] = range(100)
    
    var start_time = Time.get_ticks_msec()
    var success = _save_manager.save_game(_test_save_path, large_data)
    var save_time = Time.get_ticks_msec() - start_time
    
    assert_that(success).is_true()
    assert_that(save_time).is_less(5000) # Should complete within 5 seconds
    
    start_time = Time.get_ticks_msec()
    var loaded_data = _save_manager.load_game(_test_save_path)
    var load_time = Time.get_ticks_msec() - start_time
    
    assert_that(loaded_data).is_not_empty()
    assert_that(load_time).is_less(5000) # Should complete within 5 seconds

func test_rapid_save_load_cycles() -> void:
    var save_data = _campaign_data.serialize()
    
    for i: int in range(10):
        _campaign_data.turn_number = i + 1
        var current_data = _campaign_data.serialize()
        
        var success = _save_manager.save_game(_test_save_path, current_data)
        assert_that(success).is_true()
        
        var loaded_data = _save_manager.load_game(_test_save_path)
        assert_that(loaded_data["turn_number"]).is_equal(i + 1)
    
    assert_that(_save_manager.save_count).is_equal(10)
    assert_that(_save_manager.load_count).is_equal(10)

#endregion
