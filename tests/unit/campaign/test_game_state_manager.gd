## Test suite for GameStateManager class
## Tests state transitions, resource management, and game progression
## @class TestGameStateManager
@tool
extends "res://tests/fixtures/base/game_test.gd"

const GameStateManager = preload("res://src/core/managers/GameStateManager.gd")
const MAX_CREDITS := 999999
const MAX_SUPPLIES := 100
const MAX_REPUTATION := 100

# Test variables
var game_state_manager: GameStateManager = null
var _test_game_state = null

# Helper methods
func setup_basic_game_state() -> void:
	game_state_manager.set_credits(1000)
	game_state_manager.set_supplies(10)
	game_state_manager.set_reputation(50)
	game_state_manager.set_story_progress(1)

# Lifecycle Methods
func before_all() -> void:
	super.before_all()

func after_all() -> void:
	super.after_all()

func before_each() -> void:
	await super.before_each()
	
	# Initialize game state first
	_test_game_state = create_test_game_state()
	assert_valid_game_state(_test_game_state)
	
	# Initialize game state manager
	game_state_manager = GameStateManager.new()
	add_child_autofree(game_state_manager)
	track_test_node(game_state_manager)
	
	# Set up initial state
	game_state_manager.set_game_state(_test_game_state)
	game_state_manager.set_campaign_phase(GameEnums.FiveParcsecsCampaignPhase.NONE)
	
	await stabilize_engine()

func after_each() -> void:
	# Clean up nodes first
	if is_instance_valid(_test_game_state):
		if _test_game_state.get_parent():
			remove_child(_test_game_state)
		_test_game_state.queue_free()
	
	if is_instance_valid(game_state_manager):
		if game_state_manager.get_parent():
			remove_child(game_state_manager)
		game_state_manager.queue_free()
	
	# Wait for nodes to be freed
	await get_tree().process_frame
	
	# Clear references
	game_state_manager = null
	_test_game_state = null
	
	# Let parent handle remaining cleanup
	await super.after_each()
	
	# Clear tracked resources
	_tracked_resources.clear()

# Initial State Tests
func test_initial_state() -> void:
	assert_not_null(game_state_manager, "Game state manager should be initialized")
	assert_not_null(game_state_manager.game_state, "Game state should be set")
	assert_eq(game_state_manager.get_campaign_phase(), GameEnums.FiveParcsecsCampaignPhase.NONE, "Should start in NONE phase")

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
	
	var new_state = create_test_game_state()
	game_state_manager.set_game_state(new_state)
	assert_eq(game_state_manager.get_game_state(), new_state, "Game state should be updated")
	assert_signal_emitted(game_state_manager, "game_state_changed")

func test_campaign_phase_transitions() -> void:
	watch_signals(game_state_manager)
	
	game_state_manager.set_campaign_phase(GameEnums.FiveParcsecsCampaignPhase.SETUP)
	assert_eq(game_state_manager.get_campaign_phase(), GameEnums.FiveParcsecsCampaignPhase.SETUP, "Campaign phase should change to SETUP")
	assert_signal_emitted(game_state_manager, "campaign_phase_changed")
	
	game_state_manager.set_campaign_phase(GameEnums.FiveParcsecsCampaignPhase.CAMPAIGN)
	assert_eq(game_state_manager.get_campaign_phase(), GameEnums.FiveParcsecsCampaignPhase.CAMPAIGN, "Campaign phase should change to CAMPAIGN")
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
	var test_state = create_test_game_state()
	for i in range(1000):
		game_state_manager.set_game_state(test_state)
	assert_true(true, "Should handle rapid state changes without crashing")

# Error Boundary Tests
func test_invalid_state_transitions() -> void:
	var test_state = create_test_game_state()
	game_state_manager.set_game_state(test_state)
	game_state_manager.set_campaign_phase(GameEnums.FiveParcsecsCampaignPhase.NONE)
	assert_eq(game_state_manager.get_campaign_phase(), GameEnums.FiveParcsecsCampaignPhase.NONE,
		"Should not allow campaign phase change in NONE state")
	
	game_state_manager.set_campaign_phase(GameEnums.FiveParcsecsCampaignPhase.BATTLE_SETUP)
	assert_eq(game_state_manager.get_campaign_phase(), GameEnums.FiveParcsecsCampaignPhase.NONE,
		"Should not allow campaign phase change in BATTLE state")
