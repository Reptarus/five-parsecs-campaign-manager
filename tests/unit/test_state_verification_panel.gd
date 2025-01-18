@tool
extends "../fixtures/base_test.gd"

const StateVerificationPanel := preload("res://src/ui/components/combat/state/state_verification_panel.gd")

var panel: Node
var _signals_received := {}

func before_each() -> void:
	panel = StateVerificationPanel.new()
	add_child_autoqfree(panel)
	await get_tree().process_frame

func test_initial_state() -> void:
	assert_false(panel.visible, "Panel should start hidden")
	assert_eq(panel.current_state, null, "Should start with no state")
	assert_eq(panel.verification_status, GameEnums.VerificationStatus.NONE, "Should start with NONE status")

func test_set_state() -> void:
	var test_state = {
		"phase": GameEnums.BattlePhase.ACTIVATION,
		"round": 1,
		"active_unit": null
	}
	
	panel.set_state(test_state)
	
	assert_eq(panel.current_state, test_state, "Should store state")
	assert_eq(panel.verification_status, GameEnums.VerificationStatus.PENDING, "Should set status to PENDING")
	assert_true(panel.visible, "Panel should be visible")

func test_verify_state() -> void:
	var test_state = {
		"phase": GameEnums.BattlePhase.ACTIVATION,
		"round": 1,
		"active_unit": null
	}
	panel.set_state(test_state)
	
	watch_signals(panel)
	panel.verify_state()
	
	assert_eq(panel.verification_status, GameEnums.VerificationStatus.VERIFIED, "Should set status to VERIFIED")
	assert_signal_emitted(panel, "state_verified")

func test_reject_state() -> void:
	var test_state = {
		"phase": GameEnums.BattlePhase.ACTIVATION,
		"round": 1,
		"active_unit": null
	}
	panel.set_state(test_state)
	
	watch_signals(panel)
	panel.reject_state()
	
	assert_eq(panel.verification_status, GameEnums.VerificationStatus.REJECTED, "Should set status to REJECTED")
	assert_signal_emitted(panel, "state_rejected")

func test_reset_panel() -> void:
	var test_state = {
		"phase": GameEnums.BattlePhase.ACTIVATION,
		"round": 1,
		"active_unit": null
	}
	panel.set_state(test_state)
	panel.verify_state()
	
	panel.reset()
	
	assert_false(panel.visible, "Panel should be hidden")
	assert_eq(panel.current_state, null, "Should clear state")
	assert_eq(panel.verification_status, GameEnums.VerificationStatus.NONE, "Should reset status to NONE")

func test_state_comparison() -> void:
	var initial_state = {
		"phase": GameEnums.BattlePhase.ACTIVATION,
		"round": 1,
		"active_unit": null
	}
	var modified_state = {
		"phase": GameEnums.BattlePhase.REACTION,
		"round": 1,
		"active_unit": null
	}
	
	panel.set_state(initial_state)
	var differences = panel._compare_states(modified_state)
	
	assert_eq(differences.size(), 1, "Should detect one difference")
	assert_eq(differences[0].field, "phase", "Should identify phase change")
	assert_eq(differences[0].old_value, GameEnums.BattlePhase.ACTIVATION, "Should store old phase")
	assert_eq(differences[0].new_value, GameEnums.BattlePhase.REACTION, "Should store new phase")