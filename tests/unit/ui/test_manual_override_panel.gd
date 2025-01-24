## Test class for manual override panel functionality
##
## Tests the UI components and logic for manual combat overrides
## including value management, validation, and state tracking
@tool
extends "res://tests/fixtures/base_test.gd"

const ManualOverridePanel := preload("res://src/ui/components/combat/overrides/manual_override_panel.gd")
const GameEnums := preload("res://src/core/systems/GlobalEnums.gd")

var panel: ManualOverridePanel

func before_each() -> void:
	await super.before_each()
	panel = ManualOverridePanel.new()
	add_child(panel)
	track_test_node(panel)
	watch_signals(panel)
	await get_tree().process_frame

func after_each() -> void:
	await super.after_each()
	panel = null

# Basic Panel Tests
func test_initial_state() -> void:
	assert_false(panel.visible, "Panel should start hidden")
	assert_eq(panel.override_value, 0, "Should start with zero override value")
	assert_eq(panel.get_override_type(), GameEnums.VerificationType.NONE, "Should start with no override type")
	assert_eq(panel.get_override_scope(), GameEnums.VerificationScope.NONE, "Should start with no override scope")

# Override Value Tests
func test_combat_override_values() -> void:
	var combat_overrides = {
		GameEnums.CombatModifier.COVER_LIGHT: 1,
		GameEnums.CombatModifier.COVER_MEDIUM: 2,
		GameEnums.CombatModifier.COVER_HEAVY: 3,
		GameEnums.CombatModifier.FLANKING: 2,
		GameEnums.CombatModifier.ELEVATION: 1
	}
	
	for modifier in combat_overrides:
		panel.set_override_value(combat_overrides[modifier], GameEnums.VerificationType.COMBAT)
		assert_eq(panel.override_value, combat_overrides[modifier], "Should set %s override value" % modifier)
		assert_signal_emitted(panel, "override_value_changed")
		assert_eq(panel.get_override_type(), GameEnums.VerificationType.COMBAT, "Should set combat override type")

func test_terrain_override_values() -> void:
	var terrain_overrides = {
		GameEnums.TerrainModifier.DIFFICULT_TERRAIN: - 1,
		GameEnums.TerrainModifier.HAZARDOUS: - 2,
		GameEnums.TerrainModifier.MOVEMENT_PENALTY: - 1,
		GameEnums.TerrainModifier.ELEVATION_BONUS: 2
	}
	
	for modifier in terrain_overrides:
		panel.set_override_value(terrain_overrides[modifier], GameEnums.VerificationType.MOVEMENT)
		assert_eq(panel.override_value, terrain_overrides[modifier], "Should set %s override value" % modifier)
		assert_signal_emitted(panel, "override_value_changed")
		assert_eq(panel.get_override_type(), GameEnums.VerificationType.MOVEMENT, "Should set movement override type")

# Scope Tests
func test_override_scopes() -> void:
	var scopes = [
		GameEnums.VerificationScope.SINGLE,
		GameEnums.VerificationScope.ALL,
		GameEnums.VerificationScope.SELECTED,
		GameEnums.VerificationScope.GROUP
	]
	
	for scope in scopes:
		panel.set_override_scope(scope)
		assert_eq(panel.get_override_scope(), scope, "Should set override scope to %s" % scope)
		assert_signal_emitted(panel, "override_scope_changed")

# Reset Tests
func test_reset_override() -> void:
	# Set multiple values then reset
	panel.set_override_value(5, GameEnums.VerificationType.COMBAT)
	panel.set_override_scope(GameEnums.VerificationScope.ALL)
	panel.reset_override()
	
	assert_eq(panel.override_value, 0, "Should reset override value")
	assert_eq(panel.get_override_type(), GameEnums.VerificationType.NONE, "Should reset override type")
	assert_eq(panel.get_override_scope(), GameEnums.VerificationScope.NONE, "Should reset override scope")
	assert_signal_emitted(panel, "override_reset")

# Validation Tests
func test_value_validation() -> void:
	# Test value bounds
	var invalid_values = [-10, 11]
	for value in invalid_values:
		panel.set_override_value(value, GameEnums.VerificationType.COMBAT)
		assert_true(abs(panel.override_value) <= 5, "Should clamp override values to valid range")
	
	# Test invalid type
	panel.set_override_value(5, -1)
	assert_eq(panel.get_override_type(), GameEnums.VerificationType.NONE, "Should reject invalid override type")

# UI State Tests
func test_ui_state_management() -> void:
	# Test visibility
	panel.show()
	assert_true(panel.visible, "Panel should be visible")
	assert_signal_emitted(panel, "visibility_changed")
	
	panel.hide()
	assert_false(panel.visible, "Panel should be hidden")
	assert_signal_emitted(panel, "visibility_changed")
	
	# Test enabled state
	panel.set_enabled(false)
	assert_false(panel.is_enabled(), "Panel should be disabled")
	assert_signal_emitted(panel, "enabled_changed")
	
	panel.set_enabled(true)
	assert_true(panel.is_enabled(), "Panel should be enabled")
	assert_signal_emitted(panel, "enabled_changed")

# Interaction Tests
func test_rapid_value_changes() -> void:
	# Test rapid value changes
	for i in range(-5, 6):
		panel.set_override_value(i, GameEnums.VerificationType.COMBAT)
		assert_eq(panel.override_value, i, "Should handle rapid value changes")
		assert_signal_emitted(panel, "override_value_changed")

func test_scope_value_combinations() -> void:
	var test_cases = [
		{
			"value": 2,
			"type": GameEnums.VerificationType.COMBAT,
			"scope": GameEnums.VerificationScope.SINGLE
		},
		{
			"value": - 1,
			"type": GameEnums.VerificationType.MOVEMENT,
			"scope": GameEnums.VerificationScope.GROUP
		},
		{
			"value": 3,
			"type": GameEnums.VerificationType.OBJECTIVES,
			"scope": GameEnums.VerificationScope.ALL
		}
	]
	
	for test in test_cases:
		panel.set_override_value(test.value, test.type)
		panel.set_override_scope(test.scope)
		
		assert_eq(panel.override_value, test.value, "Should set correct value")
		assert_eq(panel.get_override_type(), test.type, "Should set correct type")
		assert_eq(panel.get_override_scope(), test.scope, "Should set correct scope")

# Error Condition Tests
func test_invalid_operations() -> void:
	# Test operations when disabled
	panel.set_enabled(false)
	
	panel.set_override_value(5, GameEnums.VerificationType.COMBAT)
	assert_eq(panel.override_value, 0, "Should not change value when disabled")
	assert_signal_not_emitted(panel, "override_value_changed")
	
	panel.set_override_scope(GameEnums.VerificationScope.ALL)
	assert_eq(panel.get_override_scope(), GameEnums.VerificationScope.NONE, "Should not change scope when disabled")
	assert_signal_not_emitted(panel, "override_scope_changed")
	
	# Test invalid scope changes
	panel.set_enabled(true)
	panel.set_override_scope(-1)
	assert_eq(panel.get_override_scope(), GameEnums.VerificationScope.NONE, "Should reject invalid scope")