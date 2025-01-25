## Test class for state verification panel functionality
##
## Tests the UI components and logic for game state verification
## including state comparison, validation, and result tracking
@tool
extends "res://tests/fixtures/base_test.gd"

const StateVerificationPanel := preload("res://src/ui/components/combat/state/state_verification_panel.gd")


var panel: StateVerificationPanel

func before_each() -> void:
	await super.before_each()
	panel = StateVerificationPanel.new()
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
	assert_eq(panel.current_state, {}, "Should start with empty current state")
	assert_eq(panel.expected_state, {}, "Should start with empty expected state")
	assert_false(panel.auto_verify, "Should start with auto verify disabled")

# State Management Tests
func test_set_current_state() -> void:
	var combat_state = {
		"unit_position": Vector2(1, 1),
		"action_points": 2,
		"combat_status": GameEnums.CombatStatus.NONE,
		"combat_modifiers": [GameEnums.CombatModifier.COVER_LIGHT]
	}
	
	panel.current_state = combat_state
	assert_eq(panel.current_state, combat_state, "Should set current combat state")

func test_set_expected_state() -> void:
	var expected_state = {
		"unit_position": Vector2(2, 2),
		"action_points": 1,
		"combat_status": GameEnums.CombatStatus.SUPPRESSED,
		"combat_modifiers": [GameEnums.CombatModifier.COVER_HEAVY]
	}
	
	panel.expected_state = expected_state
	assert_eq(panel.expected_state, expected_state, "Should set expected combat state")

# Verification Tests
func test_state_verification_match() -> void:
	var test_state = {
		"unit_position": Vector2(1, 1),
		"combat_status": GameEnums.CombatStatus.NONE
	}
	
	panel.current_state = test_state.duplicate()
	panel.expected_state = test_state.duplicate()
	
	panel.verify_button.emit_signal("pressed")
	assert_signal_emitted(panel, "state_verified")
	assert_signal_emitted(panel, "verification_completed")

func test_state_verification_mismatch() -> void:
	panel.current_state = {
		"unit_position": Vector2(1, 1),
		"combat_status": GameEnums.CombatStatus.NONE
	}
	
	panel.expected_state = {
		"unit_position": Vector2(2, 2),
		"combat_status": GameEnums.CombatStatus.SUPPRESSED
	}
	
	panel.verify_button.emit_signal("pressed")
	assert_signal_emitted(panel, "state_mismatch_detected")
	assert_signal_emitted(panel, "verification_completed")

# Auto-Verification Tests
func test_auto_verify_behavior() -> void:
	panel.auto_verify = true
	
	var test_state = {
		"unit_position": Vector2(1, 1),
		"combat_status": GameEnums.CombatStatus.NONE
	}
	
	# State changes should trigger automatic verification
	panel.current_state = test_state.duplicate()
	panel.expected_state = test_state.duplicate()
	
	assert_signal_emitted(panel, "verification_completed")

# Manual Correction Tests
func test_manual_correction_request() -> void:
	panel.current_state = {
		"action_points": 1,
		"combat_status": GameEnums.CombatStatus.NONE
	}
	
	panel.expected_state = {
		"action_points": 2,
		"combat_status": GameEnums.CombatStatus.SUPPRESSED
	}
	
	panel.correction_button.emit_signal("pressed")
	assert_signal_emitted(panel, "manual_correction_requested")

# UI State Tests
func test_ui_state_management() -> void:
	# Test visibility
	panel.show()
	assert_true(panel.visible, "Panel should be visible")
	assert_signal_emitted(panel, "visibility_changed")
	
	panel.hide()
	assert_false(panel.visible, "Panel should be hidden")
	assert_signal_emitted(panel, "visibility_changed")

# Error Condition Tests
func test_invalid_states() -> void:
	# Test setting invalid states
	panel.current_state = {}
	assert_eq(panel.current_state, {}, "Should handle empty current state")
	
	panel.expected_state = {}
	assert_eq(panel.expected_state, {}, "Should handle empty expected state")
	
	# Test setting invalid state values
	panel.current_state = {"invalid_key": ""}
	assert_eq(panel.current_state, {"invalid_key": ""}, "Should handle invalid state values")

# Boundary Tests
func test_large_state_objects() -> void:
	var large_state = {}
	for i in range(100):
		large_state["key_%d" % i] = "value_%d" % i
	
	panel.current_state = large_state
	panel.expected_state = large_state.duplicate()
	
	panel.verify_button.emit_signal("pressed")
	assert_signal_emitted(panel, "state_verified")
	assert_signal_emitted(panel, "verification_completed")

func test_state_categories() -> void:
	var categories = [
		"combat",
		"movement",
		"resources",
		"equipment"
	]
	
	panel.state_categories = categories
	assert_eq(panel.state_categories, categories, "Should set state categories")
	
	# Verify state tree is updated
	assert_true(panel.state_tree.get_root() != null, "Should create category tree")