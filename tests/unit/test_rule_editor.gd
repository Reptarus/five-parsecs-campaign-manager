@tool
extends "res://tests/test_base.gd"

const RuleEditor := preload("res://src/ui/components/combat/rules/rule_editor.tscn")
const TestHelper := preload("res://tests/fixtures/test_helper.gd")

var editor: Node

func before_each() -> void:
	super.before_each()
	editor = RuleEditor.instantiate()
	add_child(editor)

func after_each() -> void:
	super.after_each()
	editor = null

func test_initial_state() -> void:
	assert_eq(editor.current_rule_id, "", "Should start with no rule ID")
	assert_eq(editor.current_type, "", "Should start with no type")
	assert_true(editor.save_button.disabled, "Save button should start disabled")
	assert_true(editor.delete_button.disabled, "Delete button should start disabled")
	assert_true(editor.preview_button.disabled, "Preview button should start disabled")

func test_load_rule() -> void:
	var test_rule := {
		"name": "Test Rule",
		"type": "combat_modifier",
		"description": "Test description",
		"fields": [
			{"name": "value", "value": 2},
			{"name": "condition", "value": 0},
			{"name": "target", "value": 0}
		]
	}
	
	editor.load_rule("test_id", test_rule)
	
	assert_eq(editor.current_rule_id, "test_id", "Should set rule ID")
	assert_eq(editor.name_edit.text, "Test Rule", "Should set rule name")
	assert_eq(editor.description_edit.text, "Test description", "Should set description")
	assert_false(editor.save_button.disabled, "Save button should be enabled")
	assert_false(editor.delete_button.disabled, "Delete button should be enabled")
	assert_false(editor.preview_button.disabled, "Preview button should be enabled")

func test_create_field_controls() -> void:
	editor._create_field_controls("combat_modifier")
	
	var fields: Array = editor.fields_container.get_children()
	assert_eq(fields.size(), 3, "Should create all field controls")
	
	var value_control: SpinBox = editor.field_controls.get("value")
	assert_not_null(value_control, "Should create value control")
	assert_true(value_control is SpinBox, "Value control should be SpinBox")
	
	var condition_control: OptionButton = editor.field_controls.get("condition")
	assert_not_null(condition_control, "Should create condition control")
	assert_true(condition_control is OptionButton, "Condition control should be OptionButton")
	
	var target_control: OptionButton = editor.field_controls.get("target")
	assert_not_null(target_control, "Should create target control")
	assert_true(target_control is OptionButton, "Target control should be OptionButton")

func test_get_rule_data() -> void:
	editor.name_edit.text = "Test Rule"
	editor.description_edit.text = "Test description"
	editor.current_type = "combat_modifier"
	
	editor._create_field_controls("combat_modifier")
	var value_control: SpinBox = editor.field_controls["value"]
	value_control.value = 2
	
	var data: Dictionary = editor.get_rule_data()
	
	assert_eq(data.name, "Test Rule", "Should get correct name")
	assert_eq(data.description, "Test description", "Should get correct description")
	assert_eq(data.type, "combat_modifier", "Should get correct type")
	assert_eq(data.fields.size(), 3, "Should get all fields")
	
	var value_field: Dictionary = data.fields.filter(func(f): return f.name == "value")[0]
	assert_eq(value_field.value, 2, "Should get correct field value")

func test_save_rule() -> void:
	watch_signals(editor)
	editor.name_edit.text = "Test Rule"
	editor.description_edit.text = "Test description"
	editor.current_type = "combat_modifier"
	editor._create_field_controls("combat_modifier")
	
	editor._on_save_pressed()
	
	assert_signal_emitted(editor, "rule_saved")
	var signal_args: Array = _signal_watcher.get_signal_parameters(editor, "rule_saved")
	assert_eq(signal_args[0], "", "Should emit empty ID for new rule")
	assert_eq(signal_args[1].name, "Test Rule", "Should emit correct rule data")

func test_delete_rule() -> void:
	watch_signals(editor)
	editor.current_rule_id = "test_id"
	editor._update_button_states()
	
	editor._on_delete_pressed()
	
	assert_signal_emitted(editor, "rule_deleted")
	var signal_args: Array = _signal_watcher.get_signal_parameters(editor, "rule_deleted")
	assert_eq(signal_args[0], "test_id", "Should emit correct rule ID")
	assert_eq(editor.current_rule_id, "", "Should clear current rule ID")
	assert_true(editor.delete_button.disabled, "Delete button should be disabled")

func test_preview_rule() -> void:
	watch_signals(editor)
	editor.name_edit.text = "Test Rule"
	editor.current_type = "combat_modifier"
	editor._create_field_controls("combat_modifier")
	
	editor._on_preview_pressed()
	
	assert_signal_emitted(editor, "preview_requested")
	var signal_args: Array = _signal_watcher.get_signal_parameters(editor, "preview_requested")
	assert_eq(signal_args[0].name, "Test Rule", "Should emit correct rule data")

func test_button_states() -> void:
	editor._update_button_states()
	assert_true(editor.save_button.disabled, "Save button should be disabled without name")
	assert_true(editor.preview_button.disabled, "Preview button should be disabled without name")
	
	editor.name_edit.text = "Test Rule"
	editor._update_button_states()
	assert_true(editor.save_button.disabled, "Save button should be disabled without type")
	assert_true(editor.preview_button.disabled, "Preview button should be disabled without type")
	
	editor.current_type = "combat_modifier"
	editor._update_button_states()
	assert_false(editor.save_button.disabled, "Save button should be enabled with name and type")
	assert_false(editor.preview_button.disabled, "Preview button should be enabled with name and type")

func test_type_selection() -> void:
	watch_signals(editor)
	
	# Select combat modifier type
	var combat_index: int = editor.type_option.get_item_index(1)
	editor._on_type_selected(combat_index)
	
	assert_eq(editor.current_type, "combat_modifier", "Should set correct type")
	assert_eq(editor.fields_container.get_child_count(), 3, "Should create combat modifier fields")
	
	# Select resource modifier type
	var resource_index: int = editor.type_option.get_item_index(2)
	editor._on_type_selected(resource_index)
	
	assert_eq(editor.current_type, "resource_modifier", "Should set correct type")
	assert_eq(editor.fields_container.get_child_count(), 3, "Should create resource modifier fields")
	
	# Select state condition type
	var state_index: int = editor.type_option.get_item_index(3)
	editor._on_type_selected(state_index)
	
	assert_eq(editor.current_type, "state_condition", "Should set correct type")
	assert_eq(editor.fields_container.get_child_count(), 3, "Should create state condition fields")