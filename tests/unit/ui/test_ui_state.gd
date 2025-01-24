## Test class for UI state management functionality
##
## Tests UI state transitions, phase management, and difficulty settings
## Ensures proper state tracking and signal emission for UI-related changes
@tool
extends "res://tests/fixtures/base_test.gd"

const GameStateManager = preload("res://src/core/managers/GameStateManager.gd")
const GameEnums := preload("res://src/core/systems/GlobalEnums.gd")

var game_state_manager: GameStateManager

func before_each() -> void:
	await super.before_each()
	game_state_manager = GameStateManager.new()
	add_child(game_state_manager)
	track_test_node(game_state_manager)
	await get_tree().process_frame

func after_each() -> void:
	await super.after_each()
	game_state_manager = null

# Basic State Tests
func test_initial_state() -> void:
	assert_not_null(game_state_manager, "Game state manager should be initialized")
	assert_eq(game_state_manager.campaign_phase, GameEnums.CampaignPhase.NONE, "Should start in NONE phase")
	assert_eq(game_state_manager.difficulty_level, GameEnums.DifficultyLevel.NORMAL, "Should start with NORMAL difficulty")
	assert_eq(game_state_manager.game_state, GameEnums.GameState.NONE, "Should start in NONE game state")

# Phase Management Tests
func test_campaign_phase_transitions() -> void:
	watch_signals(game_state_manager)
	
	var valid_phases = [
		GameEnums.CampaignPhase.SETUP,
		GameEnums.CampaignPhase.UPKEEP,
		GameEnums.CampaignPhase.STORY,
		GameEnums.CampaignPhase.CAMPAIGN,
		GameEnums.CampaignPhase.BATTLE_SETUP,
		GameEnums.CampaignPhase.BATTLE_RESOLUTION,
		GameEnums.CampaignPhase.ADVANCEMENT,
		GameEnums.CampaignPhase.TRADE
	]
	
	for phase in valid_phases:
		game_state_manager.set_campaign_phase(phase)
		assert_eq(game_state_manager.campaign_phase, phase, "Should transition to %s phase" % GameEnums.PHASE_NAMES[phase])
		assert_signal_emitted(game_state_manager, "campaign_phase_changed")
		assert_eq(game_state_manager.get_phase_name(), GameEnums.PHASE_NAMES[phase], "Should return correct phase name")
		assert_eq(game_state_manager.get_phase_description(), GameEnums.PHASE_DESCRIPTIONS[phase], "Should return correct phase description")

# Difficulty Management Tests
func test_difficulty_transitions() -> void:
	watch_signals(game_state_manager)
	
	var difficulties = [
		GameEnums.DifficultyLevel.EASY,
		GameEnums.DifficultyLevel.NORMAL,
		GameEnums.DifficultyLevel.HARD,
		GameEnums.DifficultyLevel.NIGHTMARE,
		GameEnums.DifficultyLevel.HARDCORE,
		GameEnums.DifficultyLevel.ELITE
	]
	
	for difficulty in difficulties:
		game_state_manager.set_difficulty(difficulty)
		assert_eq(game_state_manager.difficulty_level, difficulty, "Should change to %s difficulty" % GameEnums.DifficultyLevel.keys()[difficulty])
		assert_signal_emitted(game_state_manager, "difficulty_changed")

# Game State Tests
func test_game_state_transitions() -> void:
	watch_signals(game_state_manager)
	
	var states = [
		GameEnums.GameState.SETUP,
		GameEnums.GameState.CAMPAIGN,
		GameEnums.GameState.BATTLE,
		GameEnums.GameState.GAME_OVER
	]
	
	for state in states:
		game_state_manager.set_game_state(state)
		assert_eq(game_state_manager.game_state, state, "Should transition to %s state" % GameEnums.GameState.keys()[state])
		assert_signal_emitted(game_state_manager, "game_state_changed")

# Error Condition Tests
func test_invalid_phase_transition() -> void:
	watch_signals(game_state_manager)
	
	# Test transitioning to battle resolution without battle setup
	game_state_manager.set_campaign_phase(GameEnums.CampaignPhase.CAMPAIGN)
	game_state_manager.set_campaign_phase(GameEnums.CampaignPhase.BATTLE_RESOLUTION)
	assert_eq(game_state_manager.campaign_phase, GameEnums.CampaignPhase.CAMPAIGN, "Should not allow invalid phase transition")
	assert_signal_not_emitted(game_state_manager, "campaign_phase_changed")

func test_invalid_difficulty() -> void:
	watch_signals(game_state_manager)
	
	# Test setting invalid difficulty
	game_state_manager.set_difficulty(-1)
	assert_eq(game_state_manager.difficulty_level, GameEnums.DifficultyLevel.NORMAL, "Should maintain default difficulty for invalid value")
	assert_signal_not_emitted(game_state_manager, "difficulty_changed")

# Boundary Tests
func test_rapid_phase_changes() -> void:
	watch_signals(game_state_manager)
	
	# Test rapid phase transitions
	var phases = [
		GameEnums.CampaignPhase.SETUP,
		GameEnums.CampaignPhase.CAMPAIGN,
		GameEnums.CampaignPhase.BATTLE_SETUP,
		GameEnums.CampaignPhase.BATTLE_RESOLUTION
	]
	
	for i in range(100):
		var phase = phases[i % phases.size()]
		game_state_manager.set_campaign_phase(phase)
		assert_eq(game_state_manager.campaign_phase, phase, "Should handle rapid phase changes correctly")

func test_state_consistency() -> void:
	watch_signals(game_state_manager)
	
	# Test state consistency across different aspects
	game_state_manager.set_game_state(GameEnums.GameState.CAMPAIGN)
	game_state_manager.set_campaign_phase(GameEnums.CampaignPhase.STORY)
	game_state_manager.set_difficulty(GameEnums.DifficultyLevel.HARD)
	
	assert_eq(game_state_manager.game_state, GameEnums.GameState.CAMPAIGN, "Should maintain game state")
	assert_eq(game_state_manager.campaign_phase, GameEnums.CampaignPhase.STORY, "Should maintain campaign phase")
	assert_eq(game_state_manager.difficulty_level, GameEnums.DifficultyLevel.HARD, "Should maintain difficulty level")