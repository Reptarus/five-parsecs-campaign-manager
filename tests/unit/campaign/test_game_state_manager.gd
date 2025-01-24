## Test suite for GameStateManager class
## Tests state transitions, resource management, and game progression
## @class TestGameStateManager
@tool
extends "res://tests/fixtures/game_test.gd"

const GameStateManager := preload("res://src/core/managers/GameStateManager.gd")
const MAX_CREDITS := 999999
const MAX_SUPPLIES := 100
const MAX_REPUTATION := 100

# Test variables
var game_state_manager: GameStateManager

# Helper methods
func setup_basic_game_state() -> void:
	game_state_manager.set_credits(1000)
	game_state_manager.set_supplies(10)
	game_state_manager.set_reputation(50)
	game_state_manager.set_story_progress(1)

func setup_campaign_state() -> void:
	game_state_manager.set_game_state(GameEnums.GameState.CAMPAIGN)
	game_state_manager.set_campaign_phase(GameEnums.CampaignPhase.SETUP)

# Lifecycle Methods
func before_each() -> void:
	await super.before_each()
	game_state_manager = GameStateManager.new()
	add_child(game_state_manager)
	track_test_node(game_state_manager)

func after_each() -> void:
	await super.after_each()
	game_state_manager = null

# Initial State Tests
func test_initial_state() -> void:
	assert_eq(game_state_manager.get_game_state(), GameEnums.GameState.NONE, "Initial game state should be NONE")
	assert_eq(game_state_manager.get_campaign_phase(), GameEnums.CampaignPhase.NONE, "Initial campaign phase should be NONE")
	assert_eq(game_state_manager.get_difficulty(), GameEnums.DifficultyLevel.NORMAL, "Initial difficulty should be NORMAL")

# Difficulty Management Tests
func test_difficulty_change() -> void:
	watch_signals(game_state_manager)
	
	game_state_manager.set_difficulty(GameEnums.DifficultyLevel.HARD)
	assert_eq(game_state_manager.get_difficulty(), GameEnums.DifficultyLevel.HARD, "Difficulty should change to HARD")
	assert_signal_emitted(game_state_manager, "difficulty_changed")
	
	game_state_manager.set_difficulty(GameEnums.DifficultyLevel.HARDCORE)
	assert_eq(game_state_manager.get_difficulty(), GameEnums.DifficultyLevel.HARDCORE, "Difficulty should change to HARDCORE")
	assert_signal_emitted(game_state_manager, "difficulty_changed")
	
	game_state_manager.set_difficulty(GameEnums.DifficultyLevel.NORMAL)
	assert_eq(game_state_manager.get_difficulty(), GameEnums.DifficultyLevel.NORMAL, "Difficulty should change back to NORMAL")
	assert_signal_emitted(game_state_manager, "difficulty_changed")

# Resource Management Tests
func test_resource_management() -> void:
	watch_signals(game_state_manager)
	setup_basic_game_state()
	
	assert_eq(game_state_manager.get_credits(), 1000, "Credits should be set correctly")
	assert_eq(game_state_manager.get_supplies(), 10, "Supplies should be set correctly")
	assert_eq(game_state_manager.get_reputation(), 50, "Reputation should be set correctly")
	assert_signal_emitted(game_state_manager, "resources_changed")

# State Transition Tests
func test_game_state_transitions() -> void:
	watch_signals(game_state_manager)
	
	game_state_manager.set_game_state(GameEnums.GameState.SETUP)
	assert_eq(game_state_manager.get_game_state(), GameEnums.GameState.SETUP, "Game state should change to SETUP")
	assert_signal_emitted(game_state_manager, "game_state_changed")
	
	game_state_manager.set_game_state(GameEnums.GameState.CAMPAIGN)
	assert_eq(game_state_manager.get_game_state(), GameEnums.GameState.CAMPAIGN, "Game state should change to CAMPAIGN")
	assert_signal_emitted(game_state_manager, "game_state_changed")

func test_campaign_phase_transitions() -> void:
	watch_signals(game_state_manager)
	
	game_state_manager.set_campaign_phase(GameEnums.CampaignPhase.SETUP)
	assert_eq(game_state_manager.get_campaign_phase(), GameEnums.CampaignPhase.SETUP, "Campaign phase should change to SETUP")
	assert_signal_emitted(game_state_manager, "campaign_phase_changed")
	
	game_state_manager.set_campaign_phase(GameEnums.CampaignPhase.CAMPAIGN)
	assert_eq(game_state_manager.get_campaign_phase(), GameEnums.CampaignPhase.CAMPAIGN, "Campaign phase should change to CAMPAIGN")
	assert_signal_emitted(game_state_manager, "campaign_phase_changed")

# Resource Boundary Tests
func test_resource_limits() -> void:
	game_state_manager.set_credits(MAX_CREDITS + 1)
	assert_eq(game_state_manager.get_credits(), MAX_CREDITS, "Credits should not exceed maximum")
	
	game_state_manager.set_credits(-1)
	assert_eq(game_state_manager.get_credits(), 0, "Credits should not go below 0")
	
	game_state_manager.set_supplies(MAX_SUPPLIES + 1)
	assert_eq(game_state_manager.get_supplies(), MAX_SUPPLIES, "Supplies should not exceed maximum")
	
	game_state_manager.set_supplies(-1)
	assert_eq(game_state_manager.get_supplies(), 0, "Supplies should not go below 0")
	
	game_state_manager.set_reputation(MAX_REPUTATION + 1)
	assert_eq(game_state_manager.get_reputation(), MAX_REPUTATION, "Reputation should not exceed maximum")
	
	game_state_manager.set_reputation(-1)
	assert_eq(game_state_manager.get_reputation(), 0, "Reputation should not go below 0")
	
	game_state_manager.set_story_progress(-2)
	assert_eq(game_state_manager.get_story_progress(), 0, "Story progress should not go below 0")

# Performance Tests
func test_rapid_state_changes() -> void:
	watch_signals(game_state_manager)
	for i in range(1000):
		game_state_manager.set_game_state(GameEnums.GameState.SETUP)
		game_state_manager.set_game_state(GameEnums.GameState.CAMPAIGN)
	assert_true(true, "Should handle rapid state changes without crashing")

# Error Boundary Tests
func test_invalid_state_transitions() -> void:
	game_state_manager.set_game_state(GameEnums.GameState.NONE)
	game_state_manager.set_campaign_phase(GameEnums.CampaignPhase.CAMPAIGN)
	assert_eq(game_state_manager.get_campaign_phase(), GameEnums.CampaignPhase.NONE,
		"Should not allow campaign phase change in NONE state")
	
	game_state_manager.set_game_state(GameEnums.GameState.BATTLE)
	game_state_manager.set_campaign_phase(GameEnums.CampaignPhase.STORY)
	assert_eq(game_state_manager.get_campaign_phase(), GameEnums.CampaignPhase.NONE,
		"Should not allow campaign phase change in BATTLE state")