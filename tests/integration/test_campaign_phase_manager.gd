@tool
extends "res://tests/fixtures/game_test.gd"

const CampaignPhaseManager := preload("res://src/core/campaign/CampaignPhaseManager.gd")
const CampaignManager := preload("res://src/core/managers/CampaignManager.gd")

# Test variables
var manager: Node
var game_state: Node
var campaign_manager: Resource

# Lifecycle Methods
func before_each() -> void:
	await super.before_each()
	game_state = create_test_game_state()
	add_child(game_state)
	track_test_node(game_state)
	
	campaign_manager = CampaignManager.new(game_state)
	track_test_resource(campaign_manager)
	
	manager = CampaignPhaseManager.new()
	manager.setup(game_state)
	add_child(manager)
	track_test_node(manager)
	
	await get_tree().process_frame

func after_each() -> void:
	await super.after_each()
	manager = null
	campaign_manager = null
	game_state = null

# Test Methods
func test_initial_state() -> void:
	assert_not_null(campaign_manager, "Campaign manager should be initialized")
	assert_not_null(game_state, "Game state should be initialized")
	assert_eq(game_state.difficulty_level, GameEnums.DifficultyLevel.NORMAL, "Should have normal difficulty")
	assert_valid_game_state(game_state)

func test_initial_phase() -> void:
	watch_signals(manager)
	
	assert_eq(manager.current_phase, GameEnums.CampaignPhase.NONE, "Initial phase should be NONE")
	
	manager.start_phase(GameEnums.CampaignPhase.SETUP)
	assert_eq(manager.current_phase, GameEnums.CampaignPhase.SETUP, "Phase should be SETUP after start")
	assert_signal_emitted(manager, "phase_changed")

func test_phase_transition_requirements() -> void:
	watch_signals(manager)
	
	manager.start_phase(GameEnums.CampaignPhase.SETUP)
	assert_eq(manager.current_phase, GameEnums.CampaignPhase.SETUP, "Should start in SETUP phase")
	assert_signal_emitted(manager, "phase_changed")
	
	# Test transition to UPKEEP
	assert_true(manager.start_phase(GameEnums.CampaignPhase.UPKEEP), "Should transition to UPKEEP from SETUP")
	assert_eq(manager.current_phase, GameEnums.CampaignPhase.UPKEEP, "Phase should be UPKEEP")
	assert_signal_emitted(manager, "phase_changed")
	
	# Test invalid transition
	assert_false(manager.start_phase(GameEnums.CampaignPhase.BATTLE_RESOLUTION), "Should not transition to invalid phase")
