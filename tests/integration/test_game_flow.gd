@tool
extends "res://tests/fixtures/game_test.gd"

const GameStateManager = preload("res://src/core/managers/GameStateManager.gd")

var game_state_manager
var game_state

func before_each() -> void:
	await super.before_each()
	game_state = create_test_game_state()
	add_child(game_state)
	track_test_node(game_state)
	
	game_state_manager = GameStateManager.new()
	add_child(game_state_manager)
	track_test_node(game_state_manager)
	await get_tree().process_frame

func after_each() -> void:
	await super.after_each()
	game_state_manager = null
	game_state = null

func test_initial_state() -> void:
	assert_not_null(game_state_manager, "Game state manager should be initialized")
	assert_eq(game_state_manager.campaign_phase, GameEnums.CampaignPhase.NONE, "Should start in NONE phase")
	assert_valid_game_state(game_state)

func test_state_transition() -> void:
	watch_signals(game_state_manager)
	
	game_state_manager.set_campaign_phase(GameEnums.CampaignPhase.SETUP)
	assert_eq(game_state_manager.campaign_phase, GameEnums.CampaignPhase.SETUP, "Should transition to SETUP phase")
	assert_signal_emitted(game_state_manager, "phase_changed")
	
	game_state_manager.set_campaign_phase(GameEnums.CampaignPhase.NONE)
	assert_eq(game_state_manager.campaign_phase, GameEnums.CampaignPhase.NONE, "Should return to NONE phase")
	assert_signal_emitted(game_state_manager, "phase_changed")

func test_invalid_state_transition() -> void:
	watch_signals(game_state_manager)
	
	# Try to transition to the same phase
	game_state_manager.set_campaign_phase(GameEnums.CampaignPhase.NONE)
	assert_eq(game_state_manager.campaign_phase, GameEnums.CampaignPhase.NONE, "Should stay in NONE phase")
	assert_signal_not_emitted(game_state_manager, "phase_changed")
	
	# Try to transition to an invalid phase
	game_state_manager.set_campaign_phase(-1)
	assert_eq(game_state_manager.campaign_phase, GameEnums.CampaignPhase.NONE, "Should stay in NONE phase")
	assert_signal_not_emitted(game_state_manager, "phase_changed")