## Campaign State Test Suite
## Tests the functionality of the game state management specifically for campaigns,
## including initialization, loading, and settings management.
@tool
extends "res://tests/fixtures/game_test.gd"

const Campaign = preload("res://src/core/campaign/Campaign.gd")

# Type hints for better safety
var game_state: GameState

## Test Lifecycle Methods
func before_each() -> void:
	await super.before_each()
	game_state = create_test_game_state()
	add_child(game_state)
	track_test_node(game_state)
	await get_tree().process_frame

func after_each() -> void:
	await super.after_each()
	game_state = null

## Initial State Tests
func test_initial_state() -> void:
	assert_not_null(game_state, "Game state should be initialized")
	assert_false(game_state.has_active_campaign(), "Should start with no active campaign")
	assert_eq(game_state.credits, 0, "Should start with 0 credits")
	assert_eq(game_state.reputation, 0, "Should start with 0 reputation")

## Campaign Management Tests
func test_campaign_loading() -> void:
	watch_signals(game_state)
	
	var campaign: Campaign = Campaign.new()
	campaign.campaign_name = "Test Campaign"
	campaign.difficulty = GameEnums.DifficultyLevel.NORMAL
	
	game_state.set_active_campaign(campaign)
	assert_true(game_state.has_active_campaign(), "Campaign should be loaded")
	assert_eq(game_state.get_active_campaign().campaign_name, "Test Campaign", "Campaign name should match")
	assert_signal_emitted(game_state, "campaign_changed")

## Game Settings Tests
func test_game_settings() -> void:
	watch_signals(game_state)
	
	game_state.set_difficulty_level(GameEnums.DifficultyLevel.HARD)
	assert_eq(game_state.difficulty_level, GameEnums.DifficultyLevel.HARD, "Difficulty should be HARD")
	assert_signal_emitted(game_state, "difficulty_changed")
	
	game_state.set_permadeath_enabled(false)
	assert_false(game_state.is_permadeath_enabled(), "Permadeath should be disabled")
	assert_signal_emitted(game_state, "settings_changed")
	
	game_state.set_story_track_enabled(false)
	assert_false(game_state.is_story_track_enabled(), "Story track should be disabled")
	assert_signal_emitted(game_state, "settings_changed")
	
	game_state.set_auto_save_enabled(false)
	assert_false(game_state.is_auto_save_enabled(), "Auto save should be disabled")
	assert_signal_emitted(game_state, "settings_changed")
