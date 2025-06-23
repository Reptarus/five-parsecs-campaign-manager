## Test class for rule editor functionality
##
## Tests the UI components and logic for editing house rules
## including rule validation, modification, and state management
@tool
extends GdUnitGameTest

class MockRuleEditor extends Resource:
    pass
    var rule_name: String = "Test Rule"
    var rule_enabled: bool = true
    var visible: bool = true
    var edit_mode: bool = false
    var rule_type: String = "combat"
    var rule_data: Dictionary = {
    "name": "Test Rule",
    "enabled": true,
    "type": "combat",
    "description": "Test description",
    "category": "house_rules",
    "priority": 1,
#
    var has_unsaved_changes: bool = false
    var is_valid: bool = true
    var child_count: int = 4
    var validation_errors: Array[String] = []
    var available_types: Array[String] = ["combat", "terrain", "general", "equipment"]
    
    #
    var is_dirty: bool = false
    var last_saved_data: Dictionary = {}
    var undo_stack: Array[Dictionary] = []
    var redo_stack: Array[Dictionary] = []
    
    #
    signal rule_updated(rule_data: Dictionary)
    signal rule_edit_started(rule_data: Dictionary)
    signal rule_saved(rule_data: Dictionary)
    signal edit_cancelled
    signal visibility_changed(visible: bool)
    signal validation_changed(is_valid: bool)
    signal dirty_state_changed(is_dirty: bool)
    
    #
    func get_rule_name() -> String:
        return rule_name
    
    func set_rule_name(value: String) -> void:
        if rule_name != value:
    rule_name = value
_update_rule_data()
rule_updated.emit(get_rule_data())
    
    func get_rule_enabled() -> bool:
        return rule_enabled
    
    func set_rule_enabled(value: bool) -> void:
        if rule_enabled != value:
    rule_enabled = value
_update_rule_data()
rule_updated.emit(get_rule_data())
    
    func get_rule_type() -> String:
        return rule_type
    
    func set_rule_type(value: String) -> void:
        if rule_type != value and value in available_types:
    rule_type = value
_update_rule_data()
rule_updated.emit(get_rule_data())
    
    func get_rule_data() -> Dictionary:
        return {
    "name": rule_name,
    "enabled": rule_enabled,
    "type": rule_type,
"description": rule_data.get("description", ""),
"category": rule_data.get("category", "house_rules"),
"priority": rule_data.get("priority", 1)

    func set_rule_data(data: Dictionary) -> void:
        pass
    var old_data = get_rule_data()
    rule_name = data.get("name", rule_name)
    rule_enabled = data.get("enabled", rule_enabled)
    rule_type = data.get("type", rule_type)
    rule_data = data.duplicate()
if old_data != get_rule_data():
            rule_updated.emit(get_rule_data())
    
    #
    func start_edit_mode() -> void:
        if not edit_mode:
    edit_mode = true
    last_saved_data = get_rule_data().duplicate()
rule_edit_started.emit(get_rule_data())
    
    func cancel_edit() -> void:
        if edit_mode:
    edit_mode = false
#
            set_rule_data(last_saved_data)
edit_cancelled.emit()
    
    func save_rule() -> bool:
        if validate_rule():
    edit_mode = false
    last_saved_data = get_rule_data().duplicate()
rule_saved.emit(get_rule_data())
    return true
    return false
    
    #
    func validate_rule() -> bool:
        validation_errors.clear()
    var valid = true
        
        if rule_name.is_empty():
            validation_errors.append("Rule name cannot be empty")
    valid = false
if rule_name.length() > 100:
            validation_errors.append("Rule name too long")
    valid = false
if not rule_type in available_types:
            validation_errors.append("            valid = false
        
    is_valid = valid
validation_changed.emit(is_valid)
return valid
    
    func get_validation_errors() -> Array[String]:
        return validation_errors
    
    #
    func can_undo() -> bool:
        return undo_stack.size() > 0
    
    func can_redo() -> bool:
        return redo_stack.size() > 0
    
    func undo() -> bool:
        if can_undo():
            redo_stack.append(get_rule_data())
    var previous_data = undo_stack.pop_back()
set_rule_data(previous_data)
    return true
    return false
    
    func redo() -> bool:
        if can_redo():
            undo_stack.append(get_rule_data())
    var next_data = redo_stack.pop_back()
set_rule_data(next_data)
    return true
    return false
    
    #
    func get_child_count() -> int:
        return child_count
    
    func set_visible(value: bool) -> void:
        if visible != value:
    visible = value
visibility_changed.emit(visible)
    
    func is_visible() -> bool:
        return visible
    
    #
    func _update_rule_data() -> void:
        rule_data["name"] = rule_name
rule_data["enabled"] = rule_enabled
rule_data["type"] = rule_type
    is_dirty = true
dirty_state_changed.emit(is_dirty)
    
    func reset_to_defaults() -> void:
    rule_data = {
    "name": rule_name,
    "enabled": rule_enabled,
    "type": rule_type,
    "description": "",
    "category": "house_rules",
    "priority": 1,
    is_dirty = false
    edit_mode = false

    var mock_rule_editor: MockRuleEditor = null

    func before_test() -> void:
    super.before_test()
    mock_rule_editor = MockRuleEditor.new()
track_resource(mock_rule_editor) # Perfect cleanup

#
    func test_initialization() -> void:
    assert_that(mock_rule_editor).is_not_null()
assert_that(mock_rule_editor.get_rule_name()).is_equal("Test Rule")
assert_that(mock_rule_editor.get_rule_enabled()).is_true()
assert_that(mock_rule_editor.get_rule_type()).is_equal("combat")
assert_that(mock_rule_editor.is_visible()).is_true()

    func test_rule_name_update() -> void:
    mock_rule_editor.set_rule_name("Updated Rule")
    
    assert_that(mock_rule_editor.get_rule_name()).is_equal("Updated Rule")
assert_that(mock_rule_editor.is_dirty).is_true()

    func test_rule_enabled_toggle() -> void:
    mock_rule_editor.set_rule_enabled(false)
    
    assert_that(mock_rule_editor.get_rule_enabled()).is_false()
assert_that(mock_rule_editor.is_dirty).is_true()

    func test_rule_type_change() -> void:
    mock_rule_editor.set_rule_type("terrain")
    
    assert_that(mock_rule_editor.get_rule_type()).is_equal("terrain")
assert_that(mock_rule_editor.is_dirty).is_true()

    func test_rule_data_management() -> void:
        pass
    var test_data = {
    "name": "Custom Rule",
    "enabled": false,
    "type": "equipment",
    "description": "Custom description",
    "priority": 5,
mock_rule_editor.set_rule_data(test_data)
    
    var retrieved_data = mock_rule_editor.get_rule_data()
assert_that(retrieved_data.get("name")).is_equal("Custom Rule")
assert_that(retrieved_data.get("enabled")).is_false()
assert_that(retrieved_data.get("type")).is_equal("equipment")

    func test_edit_mode_lifecycle() -> void:
        pass
#
    mock_rule_editor.start_edit_mode()
assert_that(mock_rule_editor.edit_mode).is_true()
    
    #
    mock_rule_editor.set_rule_name("Edited Rule")
assert_that(mock_rule_editor.get_rule_name()).is_equal("Edited Rule")
    
    #
    var save_result = mock_rule_editor.save_rule()
assert_that(save_result).is_true()
assert_that(mock_rule_editor.edit_mode).is_false()
assert_that(mock_rule_editor.get_rule_name()).is_equal("Edited Rule")

    func test_edit_mode_cancel() -> void:
        pass
#
    mock_rule_editor.start_edit_mode()
    var original_name = mock_rule_editor.get_rule_name()
mock_rule_editor.set_rule_name("Temporary Change")
    
    mock_rule_editor.cancel_edit()
    
    assert_that(mock_rule_editor.edit_mode).is_false()
assert_that(mock_rule_editor.get_rule_name()).is_equal(original_name)
assert_that(mock_rule_editor.get_rule_name()).is_not_equal("Temporary Change")

    func test_validation() -> void:
        pass
#
    assert_that(mock_rule_editor.validate_rule()).is_true()
assert_that(mock_rule_editor.is_valid).is_true()
    
    #
    mock_rule_editor.set_rule_name("")
assert_that(mock_rule_editor.validate_rule()).is_false()
assert_that(mock_rule_editor.is_valid).is_false()
    
    var errors = mock_rule_editor.get_validation_errors()
assert_that(errors.size()).is_greater_than(0)
assert_that(errors[0]).contains("empty")

    func test_validation_long_name() -> void:
        pass
    var long_name = "a".repeat(101)
mock_rule_editor.set_rule_name(long_name)
    
    assert_that(mock_rule_editor.validate_rule()).is_false()
    var errors = mock_rule_editor.get_validation_errors()
assert_that(errors.size()).is_greater_than(0)

    func test_validation_invalid_type() -> void:
    mock_rule_editor.rule_type = "invalid_type" #
    
    assert_that(mock_rule_editor.validate_rule()).is_false()
    var errors = mock_rule_editor.get_validation_errors()
assert_that(errors.size()).is_greater_than(0)

    func test_undo_redo_functionality() -> void:
        pass
#
    assert_that(mock_rule_editor.can_undo()).is_false()
assert_that(mock_rule_editor.can_redo()).is_false()
    
    #
    var original_name = mock_rule_editor.get_rule_name()
mock_rule_editor.undo_stack.append(mock_rule_editor.get_rule_data())
mock_rule_editor.set_rule_name("Changed Name")
    
    #
    assert_that(mock_rule_editor.can_undo()).is_true()
    var undo_result = mock_rule_editor.undo()
assert_that(undo_result).is_true()
assert_that(mock_rule_editor.get_rule_name()).is_equal(original_name)
    
    #
    assert_that(mock_rule_editor.can_redo()).is_true()
    var redo_result = mock_rule_editor.redo()
assert_that(redo_result).is_true()
assert_that(mock_rule_editor.get_rule_name()).is_equal("Changed Name")

    func test_visibility_management() -> void:
    mock_rule_editor.set_visible(false)
assert_that(mock_rule_editor.is_visible()).is_false()
    
    mock_rule_editor.set_visible(true)
assert_that(mock_rule_editor.is_visible()).is_true()

    func test_reset_to_defaults() -> void:
        pass
#
    mock_rule_editor.set_rule_name("Custom Rule")
mock_rule_editor.set_rule_enabled(false)
mock_rule_editor.set_rule_type("combat")
mock_rule_editor.start_edit_mode()
    
    #
    mock_rule_editor.reset_to_defaults()
    
    assert_that(mock_rule_editor.is_dirty).is_false()
assert_that(mock_rule_editor.edit_mode).is_false()
assert_that(mock_rule_editor.rule_data).is_not_empty()
assert_that(mock_rule_editor.rule_data.get("category")).is_equal("house_rules")
assert_that(mock_rule_editor.rule_data.get("priority")).is_equal(1)

    func test_available_types() -> void:
    assert_that(mock_rule_editor.available_types).contains("combat")
assert_that(mock_rule_editor.available_types).contains("terrain")
assert_that(mock_rule_editor.available_types).contains("general")
assert_that(mock_rule_editor.available_types).contains("equipment")
assert_that(mock_rule_editor.available_types.size()).is_equal(4)

    func test_child_count() -> void:
    assert_that(mock_rule_editor.get_child_count()).is_equal(4)

    func test_save_without_validation() -> void:
        pass
#
    mock_rule_editor.set_rule_name("")
mock_rule_editor.start_edit_mode()
    
    var save_result = mock_rule_editor.save_rule()
assert_that(save_result).is_false()
assert_that(mock_rule_editor.edit_mode).is_true() #

    func test_multiple_rule_updates() -> void:
    mock_rule_editor.set_rule_name("Rule 1")
mock_rule_editor.set_rule_enabled(false)
mock_rule_editor.set_rule_type("terrain")
    
    #
    assert_that(mock_rule_editor.is_dirty).is_true()
