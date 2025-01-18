@tool
extends "res://tests/test_base.gd"

const CampaignPhaseManager := preload("res://src/core/campaign/CampaignPhaseManager.gd")
const CampaignManager := preload("res://src/core/managers/CampaignManager.gd")
const TestHelper := preload("res://tests/fixtures/test_helper.gd")
const GameState := preload("res://src/core/state/GameState.gd")

var manager: Node
var game_state: GameState
var campaign_manager: CampaignManager

func before_each() -> void:
	super.before_each()
	game_state = GameState.new()
	game_state.load_state(TestHelper.setup_test_game_state())
	add_child(game_state)
	
	campaign_manager = CampaignManager.new(game_state)
	track_test_resource(campaign_manager)
	
	manager = CampaignPhaseManager.new()
	manager.initialize(game_state, campaign_manager)
	add_child(manager)

func after_each() -> void:
	super.after_each()
	manager = null
	game_state = null
	campaign_manager = null

func test_initial_phase() -> void:
	# Test that the campaign starts in NONE phase
	assert_eq(manager.current_phase, GameEnums.CampaignPhase.NONE, "Initial phase should be NONE")
	
	manager.start_phase(GameEnums.CampaignPhase.SETUP)
	assert_eq(manager.current_phase, GameEnums.CampaignPhase.SETUP, "Phase should be SETUP after start")

func test_phase_transition_requirements() -> void:
	# Test that phase transition is blocked by minimum requirements
	manager.start_phase(GameEnums.CampaignPhase.SETUP)
	assert_eq(manager.current_phase, GameEnums.CampaignPhase.SETUP, "Should start in SETUP phase")
	
	# Test transition to UPKEEP
	assert_true(manager.start_phase(GameEnums.CampaignPhase.UPKEEP), "Should transition to UPKEEP from SETUP")
	assert_eq(manager.current_phase, GameEnums.CampaignPhase.UPKEEP, "Phase should be UPKEEP")
	
	# Test invalid transition
	assert_false(manager.start_phase(GameEnums.CampaignPhase.BATTLE_RESOLUTION), "Should not transition to invalid phase")
	assert_eq(manager.current_phase, GameEnums.CampaignPhase.UPKEEP, "Phase should remain UPKEEP")

func test_phase_event_generation() -> void:
	manager.start_phase(GameEnums.CampaignPhase.SETUP)
	
	# Test that phase requirements are initialized
	var phase_state: Dictionary = manager.phase_state
	assert_not_null(phase_state, "Phase state should be initialized")
	assert_has(phase_state.phase_requirements, "crew_created", "Setup phase should have crew_created requirement")
	assert_has(phase_state.phase_requirements, "resources_allocated", "Setup phase should have resources_allocated requirement")
