## Test class for rule editor functionality
##
## Tests the UI components and logic for editing house rules
## including rule validation, modification, and state management
@tool
extends "res://tests/fixtures/base_test.gd"

const RuleEditor := preload("res://src/ui/components/combat/rules/rule_editor.gd")
const GameEnums := preload("res://src/core/systems/GlobalEnums.gd")

# Test variables
var editor: RuleEditor

# Lifecycle Methods
func before_each() -> void:
	await super.before_each()
	editor = RuleEditor.new()
	add_child(editor)
	track_test_node(editor)
	watch_signals(editor)
	await get_tree().process_frame

func after_each() -> void:
	await super.after_each()
	editor = null

# Basic Editor Tests
func test_initial_state() -> void:
	assert_false(editor.visible, "Editor should start hidden")
	assert_eq(editor.current_rule, null, "Should start with no rule")
	assert_eq(editor.get_edit_mode(), GameEnums.EditMode.NONE, "Should start in NONE edit mode")

# Rule Editing Tests
func test_edit_combat_rule() -> void:
	var combat_rule = {
		"id": "cover_bonus",
		"name": "Enhanced Cover",
		"description": "Units receive additional defense in cover",
		"enabled": true,
		"category": GameEnums.CombatModifier.COVER_HEAVY,
		"type": GameEnums.VerificationType.COMBAT,
		"edit_mode": GameEnums.EditMode.EDIT
	}
	
	editor.edit_rule(combat_rule)
	assert_eq(editor.current_rule.id, "cover_bonus", "Should set current rule")
	assert_eq(editor.get_edit_mode(), GameEnums.EditMode.EDIT, "Should be in EDIT mode")
	assert_true(editor.visible, "Editor should be visible")
	assert_signal_emitted(editor, "rule_edit_started")

func test_edit_terrain_rule() -> void:
	var terrain_rule = {
		"id": "elevation_bonus",
		"name": "High Ground",
		"description": "Bonus for elevated positions",
		"enabled": true,
		"category": GameEnums.TerrainModifier.ELEVATION_BONUS,
		"type": GameEnums.VerificationType.COMBAT,
		"edit_mode": GameEnums.EditMode.EDIT
	}
	
	editor.edit_rule(terrain_rule)
	assert_eq(editor.current_rule.category, GameEnums.TerrainModifier.ELEVATION_BONUS, "Should set terrain modifier")
	assert_signal_emitted(editor, "rule_edit_started")

# Rule Modification Tests
func test_modify_rule_properties() -> void:
	var test_rule = {
		"id": "test_rule",
		"name": "Original Name",
		"description": "Original description",
		"enabled": true,
		"type": GameEnums.VerificationType.COMBAT,
		"edit_mode": GameEnums.EditMode.EDIT
	}
	
	editor.edit_rule(test_rule)
	
	# Modify properties
	editor.set_rule_property("name", "Updated Name")
	editor.set_rule_property("description", "Updated description")
	editor.set_rule_property("type", GameEnums.VerificationType.MOVEMENT)
	
	assert_eq(editor.current_rule.name, "Updated Name", "Should update rule name")
	assert_eq(editor.current_rule.description, "Updated description", "Should update rule description")
	assert_eq(editor.current_rule.type, GameEnums.VerificationType.MOVEMENT, "Should update rule type")

func test_rule_validation() -> void:
	var invalid_rules = [
		{
			"id": "",
			"name": "",
			"description": "",
			"enabled": true,
			"type": GameEnums.VerificationType.NONE
		},
		{
			"id": "test",
			"name": "Test",
			"description": "Description",
			"enabled": true,
			"type": - 1
		}
	]
	
	for rule in invalid_rules:
		editor.edit_rule(rule)
		assert_false(editor.validate_rule(), "Should fail validation for invalid rule")
		assert_signal_not_emitted(editor, "rule_saved")

# Save and Cancel Tests
func test_save_valid_rule() -> void:
	var test_rule = {
		"id": "test_rule",
		"name": "Test Rule",
		"description": "A valid test rule",
		"enabled": true,
		"type": GameEnums.VerificationType.COMBAT,
		"edit_mode": GameEnums.EditMode.EDIT
	}
	
	editor.edit_rule(test_rule)
	assert_true(editor.validate_rule(), "Should validate correct rule")
	
	editor.save_rule()
	assert_eq(editor.current_rule, null, "Should clear current rule")
	assert_false(editor.visible, "Editor should be hidden")
	assert_eq(editor.get_edit_mode(), GameEnums.EditMode.NONE, "Should return to NONE mode")
	assert_signal_emitted(editor, "rule_saved")

func test_cancel_edit() -> void:
	var original_rule = {
		"id": "test_rule",
		"name": "Original Name",
		"description": "Original description",
		"enabled": true,
		"type": GameEnums.VerificationType.COMBAT,
		"edit_mode": GameEnums.EditMode.EDIT
	}
	
	editor.edit_rule(original_rule)
	editor.set_rule_property("name", "Modified Name")
	editor.cancel_edit()
	
	assert_eq(editor.current_rule, null, "Should clear current rule")
	assert_false(editor.visible, "Editor should be hidden")
	assert_eq(editor.get_edit_mode(), GameEnums.EditMode.NONE, "Should return to NONE mode")
	assert_signal_emitted(editor, "edit_cancelled")

# Error Condition Tests
func test_invalid_operations() -> void:
	# Test saving without active rule
	editor.save_rule()
	assert_signal_not_emitted(editor, "rule_saved")
	
	# Test modifying without active rule
	editor.set_rule_property("name", "New Name")
	assert_signal_not_emitted(editor, "rule_modified")
	
	# Test canceling without active rule
	editor.cancel_edit()
	assert_signal_not_emitted(editor, "edit_cancelled")

# Boundary Tests
func test_edit_mode_transitions() -> void:
	var test_rule = {
		"id": "test_rule",
		"name": "Test Rule",
		"description": "Test description",
		"enabled": true,
		"type": GameEnums.VerificationType.COMBAT
	}
	
	# Test all edit modes
	var modes = [
		GameEnums.EditMode.CREATE,
		GameEnums.EditMode.EDIT,
		GameEnums.EditMode.VIEW
	]
	
	for mode in modes:
		test_rule["edit_mode"] = mode
		editor.edit_rule(test_rule)
		assert_eq(editor.get_edit_mode(), mode, "Should set correct edit mode")
		editor.cancel_edit()

func test_rapid_operations() -> void:
	var test_rule = {
		"id": "test_rule",
		"name": "Test Rule",
		"description": "Test description",
		"enabled": true,
		"type": GameEnums.VerificationType.COMBAT,
		"edit_mode": GameEnums.EditMode.EDIT
	}
	
	# Test rapid edit/save/cancel operations
	for i in range(100):
		editor.edit_rule(test_rule)
		if i % 2 == 0:
			editor.save_rule()
		else:
			editor.cancel_edit()
		assert_eq(editor.current_rule, null, "Should maintain consistent state")