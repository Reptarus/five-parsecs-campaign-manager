@tool
extends "res://tests/fixtures/game_test.gd"

const CampaignSystem := preload("res://src/core/campaign/CampaignSystem.gd")

# Test variables
var campaign_system: Node # Using Node type to avoid casting issues
var game_state: GameState

# Lifecycle Methods
func before_each() -> void:
	await super.before_each()
	game_state = create_test_game_state()
	add_child(game_state)
	track_test_node(game_state)
	
	campaign_system = CampaignSystem.new(game_state)
	add_child(campaign_system)
	track_test_node(campaign_system)

func after_each() -> void:
	await super.after_each()
	campaign_system = null
	game_state = null

# Test Methods
func test_campaign_initialization() -> void:
	assert_eq(campaign_system.total_resources, 0, "Should start with 0 resources")
	assert_eq(campaign_system.reputation, 0, "Should start with 0 reputation")
	assert_eq(campaign_system.completed_missions, 0, "Should start with 0 completed missions")

func test_resource_management() -> void:
	watch_signals(campaign_system)
	
	campaign_system.add_resources(100)
	assert_eq(campaign_system.get_total_resources(), 100, "Resources should be added")
	assert_signal_emitted(campaign_system, "resources_changed")
	
	campaign_system.add_resources(50)
	assert_eq(campaign_system.get_total_resources(), 150, "Resources should accumulate")
	assert_signal_emitted(campaign_system, "resources_changed")

func test_reputation_system() -> void:
	watch_signals(campaign_system)
	
	campaign_system.add_reputation(10)
	assert_eq(campaign_system.get_reputation(), 10, "Reputation should be added")
	assert_signal_emitted(campaign_system, "reputation_changed")
	
	campaign_system.add_reputation(5)
	assert_eq(campaign_system.get_reputation(), 15, "Reputation should accumulate")
	assert_signal_emitted(campaign_system, "reputation_changed")

func test_mission_tracking() -> void:
	watch_signals(campaign_system)
	
	assert_eq(campaign_system.get_completed_missions_count(), 0, "Should start with no completed missions")
	
	campaign_system.complete_mission()
	assert_eq(campaign_system.get_completed_missions_count(), 1, "Should track completed mission")
	assert_signal_emitted(campaign_system, "mission_completed")
	
	campaign_system.complete_mission()
	assert_eq(campaign_system.get_completed_missions_count(), 2, "Should accumulate completed missions")
	assert_signal_emitted(campaign_system, "mission_completed")