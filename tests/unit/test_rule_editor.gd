@tool
extends "res://tests/fixtures/game_test.gd"

const RuleEditor := preload("res://src/ui/components/combat/rules/rule_editor.gd")

# Test variables
var editor: Node # Using Node type to avoid casting issues

# Lifecycle Methods
func before_each() -> void:
	await super.before_each()
	editor = RuleEditor.new()
	add_child(editor)
	track_test_node(editor)
	await get_tree().process_frame

func after_each() -> void:
	await super.after_each()
	editor = null

# Test Methods
func test_initial_state() -> void:
	assert_false(editor.visible, "Editor should start hidden")
	assert_eq(editor.current_rule, null, "Should start with no rule")

func test_edit_rule() -> void:
	watch_signals(editor)
	
	var test_rule = {
		"id": "test_rule",
		"name": "Test Rule",
		"description": "A test rule",
		"enabled": true
	}
	
	editor.edit_rule(test_rule)
	assert_eq(editor.current_rule.id, "test_rule", "Should set current rule")
	assert_true(editor.visible, "Editor should be visible")
	assert_signal_emitted(editor, "rule_edit_started")

func test_save_rule() -> void:
	watch_signals(editor)
	
	var test_rule = {
		"id": "test_rule",
		"enabled": true
	}
	editor.edit_rule(test_rule)
	
	editor.save_rule()
	assert_eq(editor.current_rule, null, "Should clear current rule")
	assert_false(editor.visible, "Editor should be hidden")
	assert_signal_emitted(editor, "rule_saved")

func test_cancel_edit() -> void:
	watch_signals(editor)
	
	var test_rule = {
		"id": "test_rule",
		"enabled": true
	}
	editor.edit_rule(test_rule)
	
	editor.cancel_edit()
	assert_eq(editor.current_rule, null, "Should clear current rule")
	assert_false(editor.visible, "Editor should be hidden")
	assert_signal_emitted(editor, "edit_cancelled")