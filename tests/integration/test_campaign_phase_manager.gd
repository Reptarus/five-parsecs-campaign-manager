extends "res://addons/gut/test.gd"

const CampaignPhaseManager = preload("res://src/core/campaign/CampaignPhaseManager.gd")
const GameCampaignManager = preload("res://src/core/campaign/GameCampaignManager.gd")
const FiveParsecsGameState = preload("res://src/core/state/GameState.gd")
const GameEnums = preload("res://src/core/systems/GlobalEnums.gd")

var manager: CampaignPhaseManager
var game_state: FiveParsecsGameState
var campaign_manager: GameCampaignManager

func before_each() -> void:
    game_state = FiveParsecsGameState.new()
    campaign_manager = GameCampaignManager.new(game_state)
    manager = CampaignPhaseManager.new()
    
    # Setup test state
    game_state.current_phase = GameEnums.CampaignPhase.NONE
    game_state.credits = 1000
    game_state.resources = {
        GameEnums.ResourceType.SUPPLIES: 10,
        GameEnums.ResourceType.FUEL: 5
    }
    
    manager.setup(game_state, campaign_manager)

func after_each() -> void:
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
    var phase_state = manager.phase_state
    assert_not_null(phase_state, "Phase state should be initialized")
    assert_has(phase_state.phase_requirements, "crew_created", "Setup phase should have crew_created requirement")
    assert_has(phase_state.phase_requirements, "resources_allocated", "Setup phase should have resources_allocated requirement")