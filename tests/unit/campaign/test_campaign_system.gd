## Campaign System Test Suite
## Tests the core functionality of the campaign system including:
## - Resource management (credits, reputation)
## - Mission tracking and progression
## - Campaign state management
## - Signal handling for campaign events
@tool
extends "res://tests/fixtures/game_test.gd"

# Type definitions
const Mission := preload("res://src/core/systems/Mission.gd")
const CampaignSystem := preload("res://src/core/campaign/CampaignSystem.gd")
const DEFAULT_TEST_CREDITS := 100
const DEFAULT_TEST_REPUTATION := 10

# Test variables with strict typing
var campaign_system: Node # Using Node type to avoid casting issues
var game_state: GameState

# Helper methods for common test scenarios
func create_test_mission() -> Resource:
	var mission = Mission.new()
	mission.type = GameEnums.MissionType.PATROL
	return mission

func setup_basic_campaign_state() -> void:
	game_state.add_credits(DEFAULT_TEST_CREDITS)
	game_state.add_reputation(DEFAULT_TEST_REPUTATION)

# Lifecycle Methods
func before_each() -> void:
	await super.before_each()
	game_state = create_test_game_state()
	add_child(game_state)
	
	campaign_system = CampaignSystem.new(game_state)
	add_child(campaign_system)
	track_test_node(campaign_system)

func after_each() -> void:
	await super.after_each()
	campaign_system.queue_free()
	game_state.queue_free()
	campaign_system = null
	game_state = null

# Initial State Tests
func test_campaign_initialization() -> void:
	assert_eq(game_state.credits, 0, "Should start with 0 credits")
	assert_eq(game_state.reputation, 0, "Should start with 0 reputation")
	assert_eq(game_state.completed_missions.size(), 0, "Should start with 0 completed missions")

# Resource Management Tests
func test_resource_management() -> void:
	watch_signals(game_state)
	
	game_state.add_credits(DEFAULT_TEST_CREDITS)
	assert_eq(game_state.credits, DEFAULT_TEST_CREDITS, "Credits should be added")
	assert_signal_emitted(game_state, "credits_changed")
	
	game_state.add_credits(DEFAULT_TEST_CREDITS)
	assert_eq(game_state.credits, DEFAULT_TEST_CREDITS * 2, "Credits should accumulate")
	assert_signal_emitted(game_state, "credits_changed")

# Reputation System Tests
func test_reputation_system() -> void:
	watch_signals(game_state)
	
	game_state.add_reputation(DEFAULT_TEST_REPUTATION)
	assert_eq(game_state.reputation, DEFAULT_TEST_REPUTATION, "Reputation should be added")
	assert_signal_emitted(game_state, "reputation_changed")
	
	game_state.add_reputation(DEFAULT_TEST_REPUTATION)
	assert_eq(game_state.reputation, DEFAULT_TEST_REPUTATION * 2, "Reputation should accumulate")
	assert_signal_emitted(game_state, "reputation_changed")

# Mission Tracking Tests
func test_mission_tracking() -> void:
	watch_signals(game_state)
	
	assert_eq(game_state.completed_missions.size(), 0, "Should start with no completed missions")
	
	var patrol_mission := create_test_mission()
	game_state.add_completed_mission(patrol_mission)
	assert_eq(game_state.completed_missions.size(), 1, "Should track completed mission")
	assert_signal_emitted(game_state, "mission_completed")
	
	var rescue_mission := create_test_mission()
	game_state.add_completed_mission(rescue_mission)
	assert_eq(game_state.completed_missions.size(), 2, "Should accumulate completed missions")
	assert_signal_emitted(game_state, "mission_completed")

# Performance Tests
func test_rapid_mission_completion() -> void:
	watch_signals(game_state)
	
	for i in range(100):
		var mission := create_test_mission()
		game_state.add_completed_mission(mission)
	
	assert_true(game_state.completed_missions.size() <= 100, "Should handle rapid mission completions")
	assert_signal_emit_count(game_state, "mission_completed", 100)

# Error Boundary Tests
func test_invalid_mission_handling() -> void:
	watch_signals(game_state)
	
	var invalid_mission = null
	game_state.add_completed_mission(invalid_mission)
	assert_eq(game_state.completed_missions.size(), 0, "Should handle null mission gracefully")

# Signal Tests
func test_resource_signals() -> void:
	watch_signals(game_state)
	var credits_changed_count := 0
	var reputation_changed_count := 0
	
	game_state.credits_changed.connect(func(): credits_changed_count += 1)
	game_state.reputation_changed.connect(func(): reputation_changed_count += 1)
	
	setup_basic_campaign_state()
	
	assert_eq(credits_changed_count, 1, "Should emit credits_changed signal once")
	assert_eq(reputation_changed_count, 1, "Should emit reputation_changed signal once")

# Boundary Tests
func test_resource_boundaries() -> void:
	watch_signals(game_state)
	
	# Test maximum values
	game_state.add_credits(999999)
	assert_true(game_state.credits <= 999999, "Credits should not exceed maximum")
	
	game_state.add_reputation(100)
	assert_true(game_state.reputation <= 100, "Reputation should not exceed maximum")
	
	# Test negative values
	game_state.add_credits(-game_state.credits - 100)
	assert_eq(game_state.credits, 0, "Credits should not go below 0")
	
	game_state.add_reputation(-game_state.reputation - 50)
	assert_eq(game_state.reputation, 0, "Reputation should not go below 0")
