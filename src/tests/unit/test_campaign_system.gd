class_name TestCampaignSystem
extends "res://addons/gut/test.gd"

const GameEnums = preload("res://src/core/systems/GlobalEnums.gd")
const FiveParsecsGameState = preload("res://src/core/state/GameState.gd")
const CampaignSystem = preload("res://src/core/campaign/CampaignSystem.gd")

var game_state: FiveParsecsGameState
var campaign_system: CampaignSystem

func before_each() -> void:
    game_state = FiveParsecsGameState.new()
    campaign_system = CampaignSystem.new(game_state)

func after_each() -> void:
    game_state.free()
    campaign_system.free()

func test_campaign_initialization() -> void:
    var config = {
        "use_expanded_missions": true,
        "difficulty_mode": GameEnums.DifficultyMode.NORMAL,
        "crew_size": 5,
        "victory_condition": GameEnums.CampaignVictoryType.TURNS_20
    }
    
    campaign_system.start_campaign(config)
    
    assert_eq(campaign_system.current_phase, GameEnums.CampaignPhase.SETUP)
    assert_eq(game_state.difficulty_mode, GameEnums.DifficultyMode.NORMAL)
    assert_eq(game_state.crew_size, 5)
    assert_eq(game_state.campaign_victory_condition, GameEnums.CampaignVictoryType.TURNS_20)

func test_difficulty_system() -> void:
    campaign_system.set_difficulty(GameEnums.DifficultyMode.CHALLENGING)
    
    assert_eq(game_state.difficulty_mode, GameEnums.DifficultyMode.CHALLENGING)
    assert_eq(game_state.enemy_level_modifier, 1)
    assert_almost_eq(game_state.reward_modifier, 0.8, 0.01)
    assert_eq(game_state.injury_threshold, 6)
    
    campaign_system.set_difficulty(GameEnums.DifficultyMode.HARDCORE)
    assert_true(game_state.enable_permadeath)

func test_tutorial_system() -> void:
    campaign_system.start_tutorial("basic")
    
    assert_true(campaign_system.is_tutorial_active)
    assert_eq(campaign_system.current_tutorial_type, "basic")
    assert_true(game_state.is_tutorial_active)
    assert_eq(game_state.tutorial_progress, 0)
    assert_gt(game_state.tutorial_steps.size(), 0)
    
    campaign_system.advance_tutorial()
    assert_eq(game_state.tutorial_progress, 1)
    
    campaign_system.complete_tutorial()
    assert_false(campaign_system.is_tutorial_active)
    assert_false(game_state.is_tutorial_active)

func test_victory_conditions() -> void:
    # Test turn-based victory
    game_state.campaign_victory_condition = GameEnums.CampaignVictoryType.TURNS_20
    game_state.current_turn = 20
    campaign_system.check_victory_conditions()
    assert_signal_emitted(campaign_system, "campaign_victory_achieved")
    
    # Test quest-based victory
    game_state.campaign_victory_condition = GameEnums.CampaignVictoryType.QUESTS_3
    game_state.completed_quests = 3
    campaign_system.check_victory_conditions()
    assert_signal_emitted(campaign_system, "campaign_victory_achieved")

func test_phase_transitions() -> void:
    campaign_system.start_campaign()
    assert_eq(campaign_system.current_phase, GameEnums.CampaignPhase.SETUP)
    
    campaign_system.advance_phase()
    assert_signal_emitted(campaign_system, "campaign_phase_changed")
    
    campaign_system.process_current_phase()
    assert_signal_emitted(campaign_system, "phase_requirements_updated")

func test_serialization() -> void:
    campaign_system.start_campaign({
        "difficulty_mode": GameEnums.DifficultyMode.CHALLENGING,
        "crew_size": 6,
        "victory_condition": GameEnums.CampaignVictoryType.QUESTS_5
    })
    
    campaign_system.start_tutorial("basic")
    campaign_system.advance_tutorial()
    
    var serialized = campaign_system.serialize()
    var new_campaign = CampaignSystem.new(game_state)
    new_campaign.deserialize(serialized)
    
    assert_eq(new_campaign.current_phase, campaign_system.current_phase)
    assert_eq(new_campaign.is_tutorial_active, campaign_system.is_tutorial_active)
    assert_eq(new_campaign.current_tutorial_type, campaign_system.current_tutorial_type)
    assert_eq(new_campaign.campaign_progress, campaign_system.campaign_progress)

func test_campaign_flow() -> void:
    campaign_system.start_campaign()
    
    # Complete tutorial
    campaign_system.start_tutorial("basic")
    campaign_system.complete_tutorial()
    assert_false(campaign_system.is_tutorial_active)
    
    # Start first turn
    campaign_system.start_new_turn()
    assert_eq(game_state.campaign_turn, 1)
    
    # Process phases
    campaign_system.process_current_phase()
    assert_signal_emitted(campaign_system, "phase_requirements_updated")
    
    campaign_system.advance_phase()
    assert_signal_emitted(campaign_system, "campaign_phase_changed")