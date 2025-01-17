extends "res://addons/gut/test.gd"

const CampaignManager = preload("res://src/core/managers/CampaignManager.gd")
const FiveParsecsGameState = preload("res://src/core/state/GameState.gd")
const GameEnums = preload("res://src/core/systems/GlobalEnums.gd")

var game_state: FiveParsecsGameState
var campaign_manager: CampaignManager

func before_each():
	game_state = FiveParsecsGameState.new()
	campaign_manager = CampaignManager.new(game_state)
	
	# Setup test state
	game_state.current_phase = GameEnums.CampaignPhase.NONE
	game_state.credits = 1000
	game_state.resources = {
		GameEnums.ResourceType.SUPPLIES: 10,
		GameEnums.ResourceType.FUEL: 5
	}

func after_each():
	game_state = null
	campaign_manager = null

func test_game_initialization():
	assert_eq(game_state.current_phase, GameEnums.CampaignPhase.NONE, "Game should start in NONE phase")
	assert_eq(game_state.credits, 1000, "Game should start with 1000 credits")
	assert_eq(game_state.resources[GameEnums.ResourceType.SUPPLIES], 10, "Game should start with 10 supplies")
	assert_eq(game_state.resources[GameEnums.ResourceType.FUEL], 5, "Game should start with 5 fuel")