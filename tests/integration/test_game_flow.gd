@tool
extends "res://tests/fixtures/base_test.gd"

const GameCampaignManager = preload("res://src/core/campaign/GameCampaignManager.gd")
const FiveParsecsGameState = preload("res://src/core/state/GameState.gd")

var game_state: FiveParsecsGameState
var campaign_manager: GameCampaignManager

func before_each() -> void:
    game_state = FiveParsecsGameState.new()
    campaign_manager = GameCampaignManager.new(game_state)
    
    # Setup test state
    game_state.current_phase = GameEnums.CampaignPhase.NONE
    game_state.credits = 1000
    game_state.resources = {
        GameEnums.ResourceType.SUPPLIES: 10,
        GameEnums.ResourceType.FUEL: 5
    }

func after_each() -> void:
    game_state = null
    campaign_manager = null

func test_game_initialization() -> void:
    assert_eq(game_state.current_phase, GameEnums.CampaignPhase.NONE, "Game should start in NONE phase")
    assert_eq(game_state.credits, 1000, "Game should start with 1000 credits")
    assert_eq(game_state.resources[GameEnums.ResourceType.SUPPLIES], 10, "Game should start with 10 supplies")
    assert_eq(game_state.resources[GameEnums.ResourceType.FUEL], 5, "Game should start with 5 fuel")