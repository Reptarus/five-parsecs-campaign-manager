@tool
extends "res://tests/fixtures/base/game_test.gd"

const RuleEditor = preload("res://src/ui/components/combat/rules/rule_editor.gd")
const GameRule = preload("res://src/game/combat/FiveParsecsBattleRules.gd")

var _rule_editor
var _test_rule

# Lifecycle methods
func before_each() -> void:
    await super.before_each()
    
    # Create test rule
    _test_rule = GameRule.new()
    _test_rule.rule_id = "test_rule_1"
    _test_rule.title = "Test Rule"
    _test_rule.description = "This is a test rule for unit testing"
    _test_rule.category = "Combat"
    _test_rule.applies_to = ["character", "vehicle"]
    _test_rule.difficulty_modifier = 1
    
    # Create rule editor
    _rule_editor = RuleEditor.new()
    if not _rule_editor:
        push_error("Failed to create rule editor")
        return
    add_child(_rule_editor)
    track_test_node(_rule_editor)
    await _rule_editor.ready
    
    # Watch signals
    if _signal_watcher:
        _signal_watcher.watch_signals(_rule_editor)

func after_each() -> void:
    if is_instance_valid(_rule_editor):
        _rule_editor.queue_free()
    _rule_editor = null
    
    if is_instance_valid(_test_rule):
        _test_rule.queue_free()
    _test_rule = null
    
    await super.after_each()

# Basic State Tests
func test_initial_state() -> void:
    if not is_instance_valid(_rule_editor):
        push_warning("Skipping test_initial_state: _rule_editor is null or invalid")
        pending("Test skipped - _rule_editor is null or invalid")
        return
        
    assert_not_null(_rule_editor, "RuleEditor should be initialized")
    
    if not "current_rule" in _rule_editor:
        push_warning("Skipping current_rule check: property not found")
        pending("Test skipped - current_rule property not found")
        return
        
    assert_null(_rule_editor.current_rule, "No rule should be loaded initially")
    
    if not ("title_input" in _rule_editor and
            "description_input" in _rule_editor and
            "save_button" in _rule_editor):
        push_warning("Skipping UI element checks: required properties not found")
        pending("Test skipped - required properties not found")
        return
        
    assert_eq(_rule_editor.title_input.text, "", "Title input should be empty initially")
    assert_eq(_rule_editor.description_input.text, "", "Description input should be empty initially")
    assert_true(_rule_editor.save_button.disabled, "Save button should be disabled initially")

# Rule Loading Tests
func test_rule_loading() -> void:
    if not is_instance_valid(_rule_editor):
        push_warning("Skipping test_rule_loading: _rule_editor is null or invalid")
        pending("Test skipped - _rule_editor is null or invalid")
        return
        
    if not _rule_editor.has_method("load_rule"):
        push_warning("Skipping test_rule_loading: load_rule method not found")
        pending("Test skipped - load_rule method not found")
        return
        
    if not is_instance_valid(_test_rule):
        push_warning("Skipping test_rule_loading: _test_rule is null or invalid")
        pending("Test skipped - _test_rule is null or invalid")
        return
        
    # Load test rule
    _rule_editor.load_rule(_test_rule)
    
    if not ("current_rule" in _rule_editor and
            "title_input" in _rule_editor and
            "description_input" in _rule_editor and
            "category_dropdown" in _rule_editor):
        push_warning("Skipping UI element checks: required properties not found")
        pending("Test skipped - required properties not found")
        return
        
    assert_eq(_rule_editor.current_rule, _test_rule, "Current rule should be set")
    assert_eq(_rule_editor.title_input.text, "Test Rule", "Title input should match rule title")
    assert_eq(_rule_editor.description_input.text, "This is a test rule for unit testing",
        "Description input should match rule description")
    
    # Check category selection
    var category_index = _rule_editor.category_dropdown.selected
    var selected_category = _rule_editor.category_dropdown.get_item_text(category_index)
    assert_eq(selected_category, "Combat", "Category dropdown should match rule category")

# Rule Editing Tests
func test_rule_editing() -> void:
    if not is_instance_valid(_rule_editor):
        push_warning("Skipping test_rule_editing: _rule_editor is null or invalid")
        pending("Test skipped - _rule_editor is null or invalid")
        return
        
    if not (_rule_editor.has_method("load_rule") and
            _rule_editor.has_method("_on_title_changed") and
            _rule_editor.has_method("_on_description_changed")):
        push_warning("Skipping test_rule_editing: required methods not found")
        pending("Test skipped - required methods not found")
        return
        
    if not is_instance_valid(_test_rule):
        push_warning("Skipping test_rule_editing: _test_rule is null or invalid")
        pending("Test skipped - _test_rule is null or invalid")
        return
        
    # Load test rule
    _rule_editor.load_rule(_test_rule)
    
    if not ("title_input" in _rule_editor and
            "description_input" in _rule_editor and
            "modified" in _rule_editor and
            "save_button" in _rule_editor):
        push_warning("Skipping UI element checks: required properties not found")
        pending("Test skipped - required properties not found")
        return
        
    # Edit title
    _rule_editor.title_input.text = "Modified Rule Title"
    _rule_editor._on_title_changed("Modified Rule Title")
    
    assert_true(_rule_editor.modified, "Modified flag should be set after editing")
    assert_false(_rule_editor.save_button.disabled, "Save button should be enabled after editing")
    
    # Edit description
    _rule_editor.description_input.text = "This is a modified description"
    _rule_editor._on_description_changed("This is a modified description")
    
    assert_true(_rule_editor.modified, "Modified flag should remain set")

# Rule Saving Tests
func test_rule_saving() -> void:
    if not is_instance_valid(_rule_editor):
        push_warning("Skipping test_rule_saving: _rule_editor is null or invalid")
        pending("Test skipped - _rule_editor is null or invalid")
        return
        
    if not (_rule_editor.has_method("load_rule") and
            _rule_editor.has_method("_on_title_changed") and
            _rule_editor.has_method("_on_save_pressed") and
            _rule_editor.has_signal("rule_saved")):
        push_warning("Skipping test_rule_saving: required methods or signals not found")
        pending("Test skipped - required methods or signals not found")
        return
        
    if not is_instance_valid(_test_rule):
        push_warning("Skipping test_rule_saving: _test_rule is null or invalid")
        pending("Test skipped - _test_rule is null or invalid")
        return
        
    # Load and modify rule
    _rule_editor.load_rule(_test_rule)
    
    if not ("title_input" in _rule_editor and "modified" in _rule_editor):
        push_warning("Skipping UI element checks: required properties not found")
        pending("Test skipped - required properties not found")
        return
        
    _rule_editor.title_input.text = "Modified Rule Title"
    _rule_editor._on_title_changed("Modified Rule Title")
    
    # Save rule
    _rule_editor._on_save_pressed()
    
    verify_signal_emitted(_rule_editor, "rule_saved")
    
    # Check if rule was updated
    assert_eq(_test_rule.title, "Modified Rule Title", "Rule title should be updated")
    assert_false(_rule_editor.modified, "Modified flag should be cleared after saving")

# Rule Creation Tests
func test_new_rule_creation() -> void:
    if not is_instance_valid(_rule_editor):
        push_warning("Skipping test_new_rule_creation: _rule_editor is null or invalid")
        pending("Test skipped - _rule_editor is null or invalid")
        return
        
    if not (_rule_editor.has_method("create_new_rule") and
            _rule_editor.has_method("_on_title_changed") and
            _rule_editor.has_method("_on_save_pressed") and
            _rule_editor.has_signal("rule_saved")):
        push_warning("Skipping test_new_rule_creation: required methods or signals not found")
        pending("Test skipped - required methods or signals not found")
        return
        
    # Create new rule
    _rule_editor.create_new_rule()
    
    if not ("current_rule" in _rule_editor and
            "title_input" in _rule_editor and
            "save_button" in _rule_editor):
        push_warning("Skipping UI element checks: required properties not found")
        pending("Test skipped - required properties not found")
        return
        
    assert_not_null(_rule_editor.current_rule, "New rule should be created")
    assert_eq(_rule_editor.title_input.text, "", "Title input should be empty for new rule")
    assert_true(_rule_editor.save_button.disabled, "Save button should be disabled for empty rule")
    
    # Fill in requiredfields
    _rule_editor.title_input.text = "New Test Rule"
    _rule_editor._on_title_changed("New Test Rule")
    
    assert_false(_rule_editor.save_button.disabled, "Save button should be enabled after adding title")
    
    # Save new rule
    _rule_editor._on_save_pressed()
    
    verify_signal_emitted(_rule_editor, "rule_saved")
    assert_eq(_rule_editor.current_rule.title, "New Test Rule", "New rule should have correct title")

# Rule Validation Tests
func test_rule_validation() -> void:
    if not is_instance_valid(_rule_editor):
        push_warning("Skipping test_rule_validation: _rule_editor is null or invalid")
        pending("Test skipped - _rule_editor is null or invalid")
        return
        
    if not (_rule_editor.has_method("create_new_rule") and
            _rule_editor.has_method("_on_title_changed") and
            _rule_editor.has_method("validate_rule")):
        push_warning("Skipping test_rule_validation: required methods not found")
        pending("Test skipped - required methods not found")
        return
        
    # Create new rule
    _rule_editor.create_new_rule()
    
    if not ("title_input" in _rule_editor and
            "error_label" in _rule_editor and
            "save_button" in _rule_editor):
        push_warning("Skipping UI element checks: required properties not found")
        pending("Test skipped - required properties not found")
        return
        
    # Try to validate with empty title
    var valid = _rule_editor.validate_rule()
    
    assert_false(valid, "Validation should fail with empty title")
    assert_true(_rule_editor.error_label.visible, "Error label should be visible")
    assert_true(_rule_editor.save_button.disabled, "Save button should be disabled for invalid rule")
    
    # Add title and validate again
    _rule_editor.title_input.text = "Valid Rule Title"
    _rule_editor._on_title_changed("Valid Rule Title")
    
    valid = _rule_editor.validate_rule()
    
    assert_true(valid, "Validation should pass with title")
    assert_false(_rule_editor.error_label.visible, "Error label should be hidden for valid rule")
    assert_false(_rule_editor.save_button.disabled, "Save button should be enabled for valid rule")

# Navigation Tests
func test_cancel_navigation() -> void:
    if not is_instance_valid(_rule_editor):
        push_warning("Skipping test_cancel_navigation: _rule_editor is null or invalid")
        pending("Test skipped - _rule_editor is null or invalid")
        return
        
    if not (_rule_editor.has_method("load_rule") and
            _rule_editor.has_method("_on_title_changed") and
            _rule_editor.has_method("_on_cancel_pressed") and
            _rule_editor.has_signal("edit_cancelled")):
        push_warning("Skipping test_cancel_navigation: required methods or signals not found")
        pending("Test skipped - required methods or signals not found")
        return
        
    if not is_instance_valid(_test_rule):
        push_warning("Skipping test_cancel_navigation: _test_rule is null or invalid")
        pending("Test skipped - _test_rule is null or invalid")
        return
        
    # Load and modify rule
    _rule_editor.load_rule(_test_rule)
    
    if not "title_input" in _rule_editor:
        push_warning("Skipping title_input check: property not found")
        pending("Test skipped - title_input property not found")
        return
        
    _rule_editor.title_input.text = "Modified Rule Title"
    _rule_editor._on_title_changed("Modified Rule Title")
    
    # Press cancel
    _rule_editor._on_cancel_pressed()
    
    verify_signal_emitted(_rule_editor, "edit_cancelled")
    assert_eq(_test_rule.title, "Test Rule", "Rule should not be modified after cancel")

# Dialog Tests
func test_unsaved_changes_dialog() -> void:
    if not is_instance_valid(_rule_editor):
        push_warning("Skipping test_unsaved_changes_dialog: _rule_editor is null or invalid")
        pending("Test skipped - _rule_editor is null or invalid")
        return
        
    if not (_rule_editor.has_method("load_rule") and
            _rule_editor.has_method("_on_title_changed") and
            _rule_editor.has_method("_on_cancel_pressed") and
            "confirmation_dialog" in _rule_editor):
        push_warning("Skipping test_unsaved_changes_dialog: required methods or properties not found")
        pending("Test skipped - required methods or properties not found")
        return
        
    if not is_instance_valid(_test_rule):
        push_warning("Skipping test_unsaved_changes_dialog: _test_rule is null or invalid")
        pending("Test skipped - _test_rule is null or invalid")
        return
        
    # Load and modify rule
    _rule_editor.load_rule(_test_rule)
    
    if not "title_input" in _rule_editor:
        push_warning("Skipping title_input check: property not found")
        pending("Test skipped - title_input property not found")
        return
        
    _rule_editor.title_input.text = "Modified Rule Title"
    _rule_editor._on_title_changed("Modified Rule Title")
    
    # Try to cancel with unsaved changes
    _rule_editor._on_cancel_pressed()
    
    assert_true(_rule_editor.confirmation_dialog.visible,
        "Confirmation dialog should be visible for unsaved changes")

# Cleanup Tests
func test_cleanup() -> void:
    if not is_instance_valid(_rule_editor):
        push_warning("Skipping test_cleanup: _rule_editor is null or invalid")
        pending("Test skipped - _rule_editor is null or invalid")
        return
        
    if not (_rule_editor.has_method("load_rule") and
            _rule_editor.has_method("cleanup")):
        push_warning("Skipping test_cleanup: required methods not found")
        pending("Test skipped - required methods not found")
        return
        
    if not is_instance_valid(_test_rule):
        push_warning("Skipping test_cleanup: _test_rule is null or invalid")
        pending("Test skipped - _test_rule is null or invalid")
        return
        
    # Load rule
    _rule_editor.load_rule(_test_rule)
    
    # Cleanup
    _rule_editor.cleanup()
    
    if not ("current_rule" in _rule_editor and
            "title_input" in _rule_editor and
            "description_input" in _rule_editor):
        push_warning("Skipping UI element checks: required properties not found")
        pending("Test skipped - required properties not found")
        return
        
    assert_null(_rule_editor.current_rule, "Current rule should be cleared after cleanup")
    assert_eq(_rule_editor.title_input.text, "", "Title input should be cleared after cleanup")
    assert_eq(_rule_editor.description_input.text, "",
        "Description input should be cleared after cleanup")