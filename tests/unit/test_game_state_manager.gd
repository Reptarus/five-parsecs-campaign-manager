@tool
extends "res://tests/fixtures/game_test.gd"

const GameStateManager := preload("res://src/core/managers/GameStateManager.gd")

# Test variables
var game_state_manager: Node # Using Node type to avoid casting issues

# Lifecycle Methods
func before_each() -> void:
	await super.before_each()
	game_state_manager = GameStateManager.new()
	add_child(game_state_manager)
	track_test_node(game_state_manager)

func after_each() -> void:
	await super.after_each()
	game_state_manager = null

# Test Methods
func test_initial_state() -> void:
	assert_eq(game_state_manager.get_game_state(), GameEnums.GameState.NONE, "Initial game state should be NONE")
	assert_eq(game_state_manager.get_campaign_phase(), GameEnums.CampaignPhase.NONE, "Initial campaign phase should be NONE")
	assert_eq(game_state_manager.get_difficulty(), GameEnums.DifficultyLevel.NORMAL, "Initial difficulty should be NORMAL")

func test_difficulty_change() -> void:
	game_state_manager.set_difficulty(GameEnums.DifficultyLevel.HARD)
	assert_eq(game_state_manager.get_difficulty(), GameEnums.DifficultyLevel.HARD, "Difficulty should change to HARD")
	
	game_state_manager.set_difficulty(GameEnums.DifficultyLevel.HARDCORE)
	assert_eq(game_state_manager.get_difficulty(), GameEnums.DifficultyLevel.HARDCORE, "Difficulty should change to HARDCORE")
	
	game_state_manager.set_difficulty(GameEnums.DifficultyLevel.NORMAL)
	assert_eq(game_state_manager.get_difficulty(), GameEnums.DifficultyLevel.NORMAL, "Difficulty should change back to NORMAL")

func test_resource_management() -> void:
	game_state_manager.set_credits(1000)
	assert_eq(game_state_manager.get_credits(), 1000, "Credits should be set correctly")
	
	game_state_manager.set_supplies(5)
	assert_eq(game_state_manager.get_supplies(), 5, "Supplies should be set correctly")
	
	game_state_manager.set_reputation(10)
	assert_eq(game_state_manager.get_reputation(), 10, "Reputation should be set correctly")
	
	game_state_manager.set_story_progress(3)
	assert_eq(game_state_manager.get_story_progress(), 3, "Story progress should be set correctly")

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

func test_resource_limits() -> void:
	game_state_manager.set_credits(-100)
	assert_eq(game_state_manager.get_credits(), 0, "Credits should not go below 0")
	
	game_state_manager.set_supplies(-1)
	assert_eq(game_state_manager.get_supplies(), 0, "Supplies should not go below 0")
	
	game_state_manager.set_reputation(-5)
	assert_eq(game_state_manager.get_reputation(), 0, "Reputation should not go below 0")
	
	game_state_manager.set_story_progress(-2)
	assert_eq(game_state_manager.get_story_progress(), 0, "Story progress should not go below 0")