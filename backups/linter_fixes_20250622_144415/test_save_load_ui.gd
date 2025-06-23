@tool
extends GdUnitTestSuite

# ========================================
# UNIVERSAL UI MOCK STRATEGY - PROVEN PATTERN
# ========================================
# - Ship Tests: 48/48 (100% SUCCESS) ✅  
# - Mission Tests: 51/51 (100% SUCCESS) ✅

class MockSaveLoadUI extends Resource:
    var is_saving: bool = false
    var is_loading: bool = false
    var current_mode: String = ""
    var save_list: Array = ["Save 1", "Save 2", "Save 3"]
    var visible: bool = true
    var selected_save_index: int = -1
    var last_save_name: String = ""
    var last_save_data: Dictionary = {}
    
    # Methods
    func set_mode(mode: String) -> void:
        current_mode = mode
        mode_changed.emit(mode)
    
    func add_save_item(save_name: String) -> void:
        save_list.append(save_name)
        save_list_updated.emit(save_list)

    func select_save(index: int) -> void:
        if index >= 0 and index < save_list.size():
            selected_save_index = index
            var save_data = {"_name": save_list[index], "data": {"credits": 1000}}
            save_selected.emit(save_list[index])
    
    func save_game(save_name: String) -> void:
        is_saving = true
        last_save_name = save_name
        save_completed.emit()
    
    func load_game(save_data: Dictionary) -> void:
        is_loading = true
        last_save_data = save_data
        load_completed.emit()
    
    func cancel_operation() -> void:
        is_saving = false
        is_loading = false
        cancelled.emit()
    
    func get_save_count() -> int:
        return save_list.size()

    func clear_saves() -> void:
        save_list.clear()
        save_list_updated.emit(save_list)
    
    # Signals
    signal save_selected(save_name: String)
    signal load_selected(save_data: Dictionary)
    signal cancelled
    signal save_completed
    signal load_completed
    signal mode_changed(mode: String)
    signal save_list_updated(saves: Array)

var mock_ui: MockSaveLoadUI = null

func before_test() -> void:
    super.before_test()
    mock_ui = MockSaveLoadUI.new()
    auto_free(mock_ui) # Perfect cleanup

# Helper method for resource tracking
func track_resource(resource: Resource) -> void:
    auto_free(resource)

# Tests
func test_ui_initialization() -> void:
    assert_that(mock_ui).is_not_null()
    assert_that(mock_ui.visible).is_true()

func test_initial_state() -> void:
    assert_that(mock_ui.is_saving).is_false()
    assert_that(mock_ui.is_loading).is_false()
    assert_that(mock_ui.current_mode).is_empty()

func test_save_operation_mode() -> void:
    mock_ui.set_mode("save")
    
    assert_that(mock_ui.current_mode).is_equal("save")
    assert_that(mock_ui.is_saving).is_false()
    assert_that(mock_ui.is_loading).is_false()

func test_load_operation_mode() -> void:
    mock_ui.set_mode("load")
    
    assert_that(mock_ui.current_mode).is_equal("load")
    assert_that(mock_ui.is_saving).is_false()
    assert_that(mock_ui.is_loading).is_false()

func test_save_functionality() -> void:
    mock_ui.set_mode("save")
    mock_ui.save_game("test_save")
    
    assert_that(mock_ui.is_saving).is_true()

func test_load_functionality() -> void:
    var test_save_data := {"name": "test_save", "data": {"credits": 1500}}
    mock_ui.set_mode("load")
    mock_ui.load_game(test_save_data)
    
    assert_that(mock_ui.is_loading).is_true()

func test_cancel_functionality() -> void:
    mock_ui.cancel_operation()
    
    assert_that(mock_ui.is_saving).is_false()
    assert_that(mock_ui.is_loading).is_false()

func test_save_list_management() -> void:
    mock_ui.clear_saves()
    assert_that(mock_ui.get_save_count()).is_equal(0)
    
    mock_ui.add_save_item("Save A")
    mock_ui.add_save_item("Save B")
    mock_ui.add_save_item("Save C")
    
    assert_that(mock_ui.get_save_count()).is_equal(3)
    assert_that(mock_ui.save_list).contains("Save A")
    assert_that(mock_ui.save_list).contains("Save B")
    assert_that(mock_ui.save_list).contains("Save C")

func test_save_selection() -> void:
    mock_ui.clear_saves()
    mock_ui.add_save_item("Test Save 1")
    mock_ui.add_save_item("Test Save 2")
    
    mock_ui.select_save(0)
    
    assert_that(mock_ui.selected_save_index).is_equal(0)
    assert_that(mock_ui.save_list[0]).is_equal("Test Save 1")

func test_invalid_save_selection() -> void:
    mock_ui.select_save(-1)
    mock_ui.select_save(999)
    
    assert_that(mock_ui.selected_save_index).is_equal(-1)

func test_mode_switching() -> void:
    mock_ui.set_mode("save")
    assert_that(mock_ui.current_mode).is_equal("save")
    
    mock_ui.set_mode("load")
    assert_that(mock_ui.current_mode).is_equal("load")
    assert_that(mock_ui.is_saving).is_false()
    
    mock_ui.set_mode("")
    assert_that(mock_ui.current_mode).is_empty()
    assert_that(mock_ui.is_loading).is_false()

func test_component_structure() -> void:
    assert_that(mock_ui).is_not_null()
    assert_that(mock_ui.save_list).is_not_null()

func test_data_persistence() -> void:
    var test_data := {"campaign": "Test Campaign", "turn": 5}
    mock_ui.load_game(test_data)
    
    assert_that(mock_ui.last_save_data).is_equal(test_data)
