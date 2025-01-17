extends "res://tests/unit/test_simple.gd"

const GameEnums = preload("res://src/core/systems/GlobalEnums.gd")
const FiveParsecsGameState = preload("res://src/core/state/GameState.gd")
const CampaignSystem = preload("res://src/core/campaign/CampaignSystem.gd")

var game_state: FiveParsecsGameState
var campaign_system: CampaignSystem

func setup():
	game_state = FiveParsecsGameState.new()
	campaign_system = CampaignSystem.new(game_state)

func test_campaign_initialization():
	assert_eq(campaign_system.total_resources, 0, "Should start with 0 resources")
	assert_eq(campaign_system.reputation, 0, "Should start with 0 reputation")
	assert_eq(campaign_system.completed_missions, 0, "Should start with 0 completed missions")

func test_resource_management():
	campaign_system.add_resources(100)
	assert_eq(campaign_system.get_total_resources(), 100, "Resources should be added")
	
	campaign_system.add_resources(50)
	assert_eq(campaign_system.get_total_resources(), 150, "Resources should accumulate")

func test_reputation_system():
	campaign_system.add_reputation(10)
	assert_eq(campaign_system.get_reputation(), 10, "Reputation should be added")
	
	campaign_system.add_reputation(5)
	assert_eq(campaign_system.get_reputation(), 15, "Reputation should accumulate")

func test_mission_tracking():
	assert_eq(campaign_system.get_completed_missions_count(), 0, "Should start with no completed missions")
	
	campaign_system.complete_mission()
	assert_eq(campaign_system.get_completed_missions_count(), 1, "Should track completed mission")
	
	campaign_system.complete_mission()
	assert_eq(campaign_system.get_completed_missions_count(), 2, "Should accumulate completed missions")