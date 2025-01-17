@tool
extends BaseTest

const CampaignManager = preload("res://src/core/managers/CampaignManager.gd")
const FiveParsecsGameState = preload("res://src/core/state/GameState.gd")

var game_state: FiveParsecsGameState
var campaign_manager: CampaignManager

func before_each() -> void:
	game_state = FiveParsecsGameState.new()
	campaign_manager = CampaignManager.new(game_state)
	
	game_state.current_phase = GameEnums.CampaignPhase.NONE
	game_state.credits = 1000
	game_state.resources = {
		"fuel": 10,
		"supplies": 20,
		"spare_parts": 5
	}

func after_each() -> void:
	super.after_each()
	game_state = null
	campaign_manager = null

func test_campaign_state_initialization() -> void:
	assert_eq(game_state.current_phase, GameEnums.CampaignPhase.NONE)
	assert_eq(game_state.credits, 1000)
	assert_eq(game_state.resources["fuel"], 10)
	assert_eq(game_state.resources["supplies"], 20)
	assert_eq(game_state.resources["spare_parts"], 5)

func test_campaign_state_update() -> void:
	game_state.credits = 2000
	game_state.resources["fuel"] = 15
	
	assert_eq(game_state.credits, 2000)
	assert_eq(game_state.resources["fuel"], 15)