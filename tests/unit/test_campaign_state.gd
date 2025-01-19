@tool
extends "res://tests/fixtures/game_test.gd"

# Test variables
var state: Node # Using Node type to avoid casting issues

# Lifecycle Methods
func before_each() -> void:
	await super.before_each()
	state = GameState.new()
	add_child(state)
	track_test_node(state)
	await get_tree().process_frame

func after_each() -> void:
	await super.after_each()
	state = null

# Test Methods
func test_initial_state() -> void:
	assert_eq(state.current_phase, GameEnums.CampaignPhase.NONE, "Should start with NONE phase")
	assert_eq(state.credits, 0, "Should start with no credits")
	assert_eq(state.resources.size(), 0, "Should start with no resources")

func test_set_phase() -> void:
	watch_signals(state)
	
	state.current_phase = GameEnums.CampaignPhase.CAMPAIGN
	assert_eq(state.current_phase, GameEnums.CampaignPhase.CAMPAIGN, "Should set phase")
	assert_signal_emitted(state, "phase_changed")

func test_modify_credits() -> void:
	watch_signals(state)
	
	state.credits = 100
	assert_eq(state.credits, 100, "Should set credits")
	assert_signal_emitted(state, "credits_changed")

func test_modify_resources() -> void:
	watch_signals(state)
	
	state.resources = {
		"fuel": 10,
		"supplies": 20
	}
	assert_eq(state.resources["fuel"], 10, "Should set fuel")
	assert_eq(state.resources["supplies"], 20, "Should set supplies")
	assert_signal_emitted(state, "resources_changed")