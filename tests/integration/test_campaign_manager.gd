extends "res://addons/gut/test.gd"

const CampaignManager = preload("res://src/core/managers/CampaignManager.gd")
const FiveParsecsGameState = preload("res://src/core/state/GameState.gd")
const Character = preload("res://src/core/character/Base/Character.gd")
const GameEnums = preload("res://src/core/systems/GlobalEnums.gd")

var game_state: FiveParsecsGameState
var campaign_manager: CampaignManager
var test_character: Character

func before_each():
	game_state = FiveParsecsGameState.new()
	campaign_manager = CampaignManager.new(game_state)
	test_character = Character.new()
	test_character.character_name = "Test Character"
	test_character.status = GameEnums.CharacterStatus.HEALTHY
	
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
	test_character = null

func test_campaign_manager_initialization():
	assert_not_null(campaign_manager, "Campaign manager should be initialized")
	assert_not_null(game_state, "Game state should be initialized")
	assert_eq(game_state.current_phase, GameEnums.CampaignPhase.NONE, "Campaign should start in NONE phase")

func test_add_character():
	campaign_manager.add_character(test_character)
	var loaded_character = campaign_manager.get_character(test_character.character_name)
	assert_not_null(loaded_character, "Character should be added and retrievable")
	assert_eq(loaded_character.character_name, "Test Character", "Character name should match")
	assert_eq(loaded_character.status, GameEnums.CharacterStatus.HEALTHY, "Character status should match")
