@tool
extends "res://tests/fixtures/game_test.gd"

const CampaignManager := preload("res://src/core/managers/CampaignManager.gd")

# Test variables
var game_state: Node # Using Node type since GameState extends Node
var campaign_manager: Resource # Using Resource type since CampaignManager extends Resource

# Lifecycle Methods
func before_each() -> void:
	await super.before_each()
	game_state = create_test_game_state()
	add_child(game_state)
	track_test_node(game_state)
	
	campaign_manager = CampaignManager.new(game_state)
	track_test_resource(campaign_manager)
	
	# Set initial game state
	game_state.current_phase = GameEnums.CampaignPhase.NONE
	game_state.credits = 1000
	game_state.resources = {
		GameEnums.ResourceType.SUPPLIES: 10,
		GameEnums.ResourceType.FUEL: 5
	}
	
	await get_tree().process_frame

func after_each() -> void:
	await super.after_each()
	campaign_manager = null
	game_state = null

# Test Methods
func test_initial_state() -> void:
	assert_eq(game_state.current_phase, GameEnums.CampaignPhase.NONE, "Should start in NONE phase")
	assert_eq(game_state.credits, 1000, "Should have initial credits")
	assert_eq(game_state.resources[GameEnums.ResourceType.SUPPLIES], 10, "Should have initial supplies")
	assert_eq(game_state.resources[GameEnums.ResourceType.FUEL], 5, "Should have initial fuel")

func test_phase_flow() -> void:
	watch_signals(game_state)
	
	game_state.current_phase = GameEnums.CampaignPhase.SETUP
	assert_eq(game_state.current_phase, GameEnums.CampaignPhase.SETUP, "Should transition to SETUP phase")
	assert_signal_emitted(game_state, "phase_changed")
	
	game_state.current_phase = GameEnums.CampaignPhase.UPKEEP
	assert_eq(game_state.current_phase, GameEnums.CampaignPhase.UPKEEP, "Should transition to UPKEEP phase")
	assert_signal_emitted(game_state, "phase_changed")

func test_resource_management() -> void:
	watch_signals(game_state)
	
	game_state.credits = 500
	assert_eq(game_state.credits, 500, "Should update credits")
	assert_signal_emitted(game_state, "credits_changed")
	
	game_state.resources[GameEnums.ResourceType.SUPPLIES] = 5
	assert_eq(game_state.resources[GameEnums.ResourceType.SUPPLIES], 5, "Should update supplies")
	assert_signal_emitted(game_state, "resources_changed")