@tool
extends "res://tests/test_base.gd"

const CampaignManager = preload("res://src/core/managers/CampaignManager.gd")
const TestHelper = preload("res://tests/fixtures/test_helper.gd")
const GameState = preload("res://src/core/state/GameState.gd")

var campaign_manager: CampaignManager
var game_state: GameState

func before_each():
	super.before_each()
	game_state = GameState.new()
	game_state.load_state(TestHelper.setup_test_game_state())
	campaign_manager = CampaignManager.new(game_state)
	track_test_resource(campaign_manager)
	
	game_state.current_phase = GameEnums.CampaignPhase.NONE
	game_state.credits = 1000
	game_state.resources = {
		GameEnums.ResourceType.SUPPLIES: 10,
		GameEnums.ResourceType.FUEL: 5
	}

func after_each():
	super.after_each()

func test_game_initialization():
	assert_eq(game_state.current_phase, GameEnums.CampaignPhase.NONE)
	assert_eq(game_state.credits, 1000)
	assert_eq(game_state.resources[GameEnums.ResourceType.SUPPLIES], 10)
	assert_eq(game_state.resources[GameEnums.ResourceType.FUEL], 5)