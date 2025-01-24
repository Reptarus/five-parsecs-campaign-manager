@tool
extends "res://tests/fixtures/base_test.gd"

const FiveParsecsGameState := preload("res://src/core/state/GameState.gd")
const FiveParsecsCampaignSystem := preload("res://src/core/campaign/CampaignSystem.gd")

var game_state: FiveParsecsGameState
var campaign_system: FiveParsecsCampaignSystem

func before_each() -> void:
	await super.before_each()
	game_state = FiveParsecsGameState.new()
	campaign_system = FiveParsecsCampaignSystem.new(game_state)
	add_child(game_state)
	add_child(campaign_system)
	track_test_node(game_state)
	track_test_node(campaign_system)
	watch_signals(game_state)
	watch_signals(campaign_system)

func after_each() -> void:
	await super.after_each()
	if is_instance_valid(game_state):
		game_state.queue_free()
		game_state = null
	if is_instance_valid(campaign_system):
		campaign_system.queue_free()
		campaign_system = null

func test_campaign_mission_flow() -> void:
	# Setup campaign
	var campaign_config = {
		"difficulty": GameEnums.DifficultyLevel.NORMAL,
		"victory_type": GameEnums.FiveParcsecsCampaignVictoryType.STANDARD,
		"crew_size": GameEnums.CrewSize.FOUR
	}
	campaign_system.start_campaign(campaign_config)
	
	# Verify initial state
	assert_eq(campaign_system.get_current_phase(), GameEnums.CampaignPhase.SETUP,
		"Campaign should start in setup phase")
	
	# Complete setup phase
	campaign_system.complete_current_phase()
	assert_eq(campaign_system.get_current_phase(), GameEnums.CampaignPhase.UPKEEP,
		"Campaign should move to upkeep phase after setup")
	
	# Complete upkeep phase
	campaign_system.complete_current_phase()
	assert_eq(campaign_system.get_current_phase(), GameEnums.CampaignPhase.CAMPAIGN,
		"Campaign should move to campaign phase after upkeep")
	
	# Generate and start mission
	var mission = campaign_system.generate_mission()
	assert_not_null(mission, "Should generate valid mission")
	campaign_system.start_mission(mission)
	
	# Verify mission state
	assert_eq(campaign_system.get_current_phase(), GameEnums.CampaignPhase.BATTLE_SETUP,
		"Campaign should move to battle setup phase when starting mission")
	
	# Complete battle setup
	campaign_system.complete_current_phase()
	assert_eq(campaign_system.get_current_phase(), GameEnums.CampaignPhase.BATTLE_RESOLUTION,
		"Campaign should move to battle resolution phase after setup")
	
	# Complete battle
	campaign_system.complete_current_phase()
	assert_eq(campaign_system.get_current_phase(), GameEnums.CampaignPhase.ADVANCEMENT,
		"Campaign should move to advancement phase after battle")
	
	# Complete advancement
	campaign_system.complete_current_phase()
	assert_eq(campaign_system.get_current_phase(), GameEnums.CampaignPhase.TRADE,
		"Campaign should move to trade phase after advancement")
	
	# Complete trade
	campaign_system.complete_current_phase()
	assert_eq(campaign_system.get_current_phase(), GameEnums.CampaignPhase.UPKEEP,
		"Campaign should return to upkeep phase after trade")
