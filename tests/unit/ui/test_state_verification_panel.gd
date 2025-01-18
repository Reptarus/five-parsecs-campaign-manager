@tool
extends "res://tests/test_base.gd"

const StateVerificationPanel := preload("res://src/ui/components/combat/state/state_verification_panel.tscn")
const TestHelper := preload("res://tests/fixtures/test_helper.gd")

var panel: Node

func before_each() -> void:
    super.before_each()
    panel = StateVerificationPanel.instantiate()
    add_child(panel)

func after_each() -> void:
    super.after_each()
    panel = null

func test_initialization() -> void:
    assert_not_null(panel, "State verification panel should be initialized")
    assert_true(panel.has_method("show_verification_result"), "Should have show_verification_result method")
    assert_true(panel.has_method("clear_results"), "Should have clear_results method")

func test_show_verification_result() -> void:
    var test_result = {
        "status": GameEnums.VerificationResult.SUCCESS,
        "message": "Test message",
        "details": ["Detail 1", "Detail 2"]
    }
    panel.show_verification_result(test_result)
    assert_true(panel.visible, "Panel should be visible after showing result")
    assert_eq(panel.result_label.text, "Test message", "Should display result message")

func test_show_error_result() -> void:
    var test_result = {
        "status": GameEnums.VerificationResult.ERROR,
        "message": "Error message",
        "details": ["Error 1", "Error 2"]
    }
    panel.show_verification_result(test_result)
    assert_true(panel.visible, "Panel should be visible after showing error")
    assert_eq(panel.result_label.text, "Error message", "Should display error message")
    assert_eq(panel.details_list.get_child_count(), 2, "Should display error details")

func test_show_warning_result() -> void:
    var test_result = {
        "status": GameEnums.VerificationResult.WARNING,
        "message": "Warning message",
        "details": ["Warning 1"]
    }
    panel.show_verification_result(test_result)
    assert_true(panel.visible, "Panel should be visible after showing warning")
    assert_eq(panel.result_label.text, "Warning message", "Should display warning message")
    assert_eq(panel.details_list.get_child_count(), 1, "Should display warning details")

func test_clear_results() -> void:
    var test_result = {
        "status": GameEnums.VerificationResult.SUCCESS,
        "message": "Test message",
        "details": ["Detail 1"]
    }
    panel.show_verification_result(test_result)
    panel.clear_results()
    assert_false(panel.visible, "Panel should be hidden after clearing results")
    assert_eq(panel.details_list.get_child_count(), 0, "Should clear result details")

func test_auto_hide() -> void:
    var test_result = {
        "status": GameEnums.VerificationResult.SUCCESS,
        "message": "Test message",
        "details": []
    }
    panel.auto_hide = true
    panel.show_verification_result(test_result)
    await get_tree().create_timer(panel.auto_hide_delay + 0.1).timeout
    assert_false(panel.visible, "Panel should auto-hide after delay")

func test_disable_auto_hide() -> void:
    var test_result = {
        "status": GameEnums.VerificationResult.SUCCESS,
        "message": "Test message",
        "details": []
    }
    panel.auto_hide = false
    panel.show_verification_result(test_result)
    await get_tree().create_timer(panel.auto_hide_delay + 0.1).timeout
    assert_true(panel.visible, "Panel should not auto-hide when disabled")

func test_close_button() -> void:
    var test_result = {
        "status": GameEnums.VerificationResult.SUCCESS,
        "message": "Test message",
        "details": []
    }
    panel.show_verification_result(test_result)
    panel._on_close_button_pressed()
    assert_false(panel.visible, "Panel should hide when close button is pressed")

func test_result_history() -> void:
    var test_results = [
        {
            "status": GameEnums.VerificationResult.SUCCESS,
            "message": "Success message",
            "details": []
        },
        {
            "status": GameEnums.VerificationResult.WARNING,
            "message": "Warning message",
            "details": ["Warning"]
        },
        {
            "status": GameEnums.VerificationResult.ERROR,
            "message": "Error message",
            "details": ["Error"]
        }
    ]
    
    for result in test_results:
        panel.show_verification_result(result)
    
    assert_eq(panel.result_history.size(), 3, "Should store result history")
    assert_eq(panel.result_history[0].status, GameEnums.VerificationResult.SUCCESS, "Should store result status")
    assert_eq(panel.result_history[1].status, GameEnums.VerificationResult.WARNING, "Should store result status")
    assert_eq(panel.result_history[2].status, GameEnums.VerificationResult.ERROR, "Should store result status")

func test_clear_history() -> void:
    var test_result = {
        "status": GameEnums.VerificationResult.SUCCESS,
        "message": "Test message",
        "details": []
    }
    panel.show_verification_result(test_result)
    panel.clear_history()
    assert_eq(panel.result_history.size(), 0, "Should clear result history")