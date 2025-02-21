## Test class for rule editor functionality
##
## Tests the UI components and logic for editing house rules
## including rule validation, modification, and state management
@tool
extends GameTest

const TestedClass: PackedScene = preload("res://src/ui/components/combat/rules/rule_editor.tscn")

var _instance: Control
var _rule_updated_signal_emitted := false
var _last_rule_data: Dictionary = {}

func before_each() -> void:
	await super.before_each()
	_instance = TestedClass.instantiate()
	add_child_autofree(_instance)
	track_test_node(_instance)
	_connect_signals()
	_reset_signals()

func after_each() -> void:
	_disconnect_signals()
	_reset_signals()
	await super.after_each()
	_instance = null

func _connect_signals() -> void:
	if not _instance:
		return
		
	if _instance.has_signal("rule_updated"):
		_instance.connect("rule_updated", _on_rule_updated)

func _disconnect_signals() -> void:
	if not _instance:
		return
		
	if _instance.has_signal("rule_updated") and _instance.is_connected("rule_updated", _on_rule_updated):
		_instance.disconnect("rule_updated", _on_rule_updated)

func _reset_signals() -> void:
	_rule_updated_signal_emitted = false
	_last_rule_data = {}

func _on_rule_updated(data: Dictionary = {}) -> void:
	_rule_updated_signal_emitted = true
	_last_rule_data = data

# Test Cases
func test_initial_state() -> void:
	assert_not_null(_instance, "Rule editor should be initialized")
	assert_false(_instance.visible, "Editor should be hidden by default")

func test_rule_update() -> void:
	_instance.visible = true
	var test_data := {"name": "Test Rule", "enabled": true}
	_instance.emit_signal("rule_updated", test_data)
	
	assert_true(_rule_updated_signal_emitted, "Rule update signal should be emitted")
	assert_eq(_last_rule_data, test_data, "Rule data should match test data")

func test_visibility() -> void:
	_instance.visible = false
	var test_data := {"name": "Test"}
	_instance.emit_signal("rule_updated", test_data)
	assert_false(_rule_updated_signal_emitted, "Rule signal should not be emitted when hidden")
	
	_instance.visible = true
	_instance.emit_signal("rule_updated", test_data)
	assert_true(_rule_updated_signal_emitted, "Rule signal should be emitted when visible")

func test_child_nodes() -> void:
	var container = _instance.get_node_or_null("Container")
	assert_not_null(container, "Editor should have a Container node")

func test_signals() -> void:
	watch_signals(_instance)
	_instance.emit_signal("rule_updated")
	verify_signal_emitted(_instance, "rule_updated")
	
	_instance.emit_signal("rule_saved")
	verify_signal_emitted(_instance, "rule_saved")

func test_state_updates() -> void:
	_instance.visible = false
	assert_false(_instance.visible, "Editor should be hidden after visibility update")
	
	_instance.visible = true
	assert_true(_instance.visible, "Editor should be visible after visibility update")
	
	var container = _instance.get_node_or_null("Container")
	if container:
		container.custom_minimum_size = Vector2(200, 300)
		assert_eq(container.custom_minimum_size, Vector2(200, 300), "Container should update minimum size")

func test_child_management() -> void:
	var container = _instance.get_node_or_null("Container")
	if container:
		var test_child = Button.new()
		container.add_child(test_child)
		assert_true(test_child in container.get_children(), "Container should manage child nodes")
		assert_true(test_child.get_parent() == container, "Child should have correct parent")
		test_child.queue_free()

func test_editor_initialization() -> void:
	assert_not_null(_instance)
	assert_true(_instance.is_inside_tree())

func test_editor_nodes() -> void:
	assert_not_null(_instance.get_node("VBoxContainer"))
	assert_not_null(_instance.get_node("VBoxContainer/RuleName"))
	assert_not_null(_instance.get_node("VBoxContainer/RuleEnabled"))
	assert_not_null(_instance.get_node("VBoxContainer/RuleConditions"))

func test_editor_properties() -> void:
	assert_eq(_instance.rule_name, "")
	assert_false(_instance.is_enabled)

func test_rule_name() -> void:
	_instance.set_rule_name("Test Rule")
	assert_eq(_instance.rule_name, "Test Rule")
	
	var name_field = _instance.get_node("VBoxContainer/RuleName")
	assert_eq(name_field.text, "Test Rule")

func test_rule_enabled() -> void:
	_instance.set_enabled(true)
	assert_true(_instance.is_enabled)
	
	_instance.set_enabled(false)
	assert_false(_instance.is_enabled)
	verify_signal_emitted(_instance, "rule_updated")

# Rule Editing Tests
func test_edit_combat_rule() -> void:
	var combat_rule = {
		"id": "cover_bonus",
		"name": "Cover Bonus",
		"description": "Applies cover bonus to defense",
		"type": GameEnums.VerificationType.COMBAT,
		"category": GameEnums.CombatModifier.COVER_LIGHT
	}
	
	_instance.edit_rule(combat_rule)
	assert_eq(_instance.current_rule.id, "cover_bonus", "Should set current rule")
	assert_eq(_instance.get_edit_mode(), GameEnums.EditMode.EDIT, "Should be in EDIT mode")
	assert_true(_instance.visible, "Editor should be visible")
	verify_signal_emitted(_instance, "rule_edit_started")

func test_edit_terrain_rule() -> void:
	var terrain_rule = {
		"id": "elevation",
		"name": "Elevation Bonus",
		"description": "Applies elevation bonus",
		"type": GameEnums.VerificationType.COMBAT,
		"category": GameEnums.TerrainModifier.ELEVATION_BONUS
	}
	
	_instance.edit_rule(terrain_rule)
	assert_eq(_instance.current_rule.category, GameEnums.TerrainModifier.ELEVATION_BONUS, "Should set terrain modifier")
	verify_signal_emitted(_instance, "rule_edit_started")

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
	
	_instance.edit_rule(test_rule)
	
	# Modify properties
	_instance.set_rule_property("name", "Updated Name")
	_instance.set_rule_property("description", "Updated description")
	_instance.set_rule_property("type", GameEnums.VerificationType.MOVEMENT)
	
	assert_eq(_instance.current_rule.name, "Updated Name", "Should update rule name")
	assert_eq(_instance.current_rule.description, "Updated description", "Should update rule description")
	assert_eq(_instance.current_rule.type, GameEnums.VerificationType.MOVEMENT, "Should update rule type")

func test_rule_validation() -> void:
	var invalid_rules = [
		{"id": "", "name": ""},
		{"id": "test", "name": ""},
		{"id": "", "name": "Test"}
	]
	
	for rule in invalid_rules:
		_instance.edit_rule(rule)
		assert_false(_instance.validate_rule(), "Should fail validation for invalid rule")
		verify_signal_not_emitted(_instance, "rule_saved")

# Save and Cancel Tests
func test_save_rule() -> void:
	var test_rule = {
		"id": "test_rule",
		"name": "Test Rule",
		"description": "Test description",
		"type": GameEnums.VerificationType.COMBAT
	}
	
	_instance.edit_rule(test_rule)
	assert_true(_instance.validate_rule(), "Should validate correct rule")
	
	_instance.save_rule()
	assert_eq(_instance.current_rule, null, "Should clear current rule")
	assert_false(_instance.visible, "Editor should be hidden")
	assert_eq(_instance.get_edit_mode(), GameEnums.EditMode.NONE, "Should return to NONE mode")
	verify_signal_emitted(_instance, "rule_saved")

func test_cancel_edit() -> void:
	var original_rule = {
		"id": "original",
		"name": "Original Name",
		"description": "Original description"
	}
	
	_instance.edit_rule(original_rule)
	_instance.set_rule_property("name", "Modified Name")
	_instance.cancel_edit()
	
	assert_eq(_instance.current_rule, null, "Should clear current rule")
	assert_false(_instance.visible, "Editor should be hidden")
	assert_eq(_instance.get_edit_mode(), GameEnums.EditMode.NONE, "Should return to NONE mode")
	verify_signal_emitted(_instance, "edit_cancelled")

# Error Condition Tests
func test_invalid_operations() -> void:
	# Test saving without active rule
	_instance.save_rule()
	verify_signal_not_emitted(_instance, "rule_saved")
	
	# Test modifying without active rule
	_instance.set_rule_property("name", "New Name")
	verify_signal_not_emitted(_instance, "rule_modified")
	
	# Test canceling without active rule
	_instance.cancel_edit()
	verify_signal_not_emitted(_instance, "edit_cancelled")

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
		_instance.edit_rule(test_rule)
		assert_eq(_instance.get_edit_mode(), mode, "Should set correct edit mode")
		_instance.cancel_edit()

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
		_instance.edit_rule(test_rule)
		if i % 2 == 0:
			_instance.save_rule()
		else:
			_instance.cancel_edit()
		assert_eq(_instance.current_rule, null, "Should maintain consistent state")