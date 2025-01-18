@tool
extends "res://tests/test_base.gd"

const CampaignManager = preload("res://src/core/managers/CampaignManager.gd")
const TestHelper = preload("res://tests/fixtures/test_helper.gd")
const GameState = preload("res://src/core/state/GameState.gd")

var campaign_manager: CampaignManager
var test_character: Character
var game_state: GameState

func before_each():
	await super.before_each()
	game_state = GameState.new()
	game_state.load_state(TestHelper.setup_test_game_state())
	campaign_manager = CampaignManager.new(game_state)
	test_character = TestHelper.create_test_character()
	
	# Track resources for cleanup
	track_test_resource(campaign_manager)
	track_test_resource(test_character)

func after_each():
	await super.after_each()

func test_campaign_manager_initialization():
	assert_resource_valid(campaign_manager)
	assert_node_valid(game_state)
	assert_eq(game_state.difficulty_level, GameEnums.DifficultyLevel.NORMAL)

func test_add_character():
	# First verify the method exists
	assert_has_method(campaign_manager, "add_character")
	
	# Then test the functionality
	campaign_manager.add_character(test_character)
	var loaded_character = campaign_manager.get_character(test_character.character_name)
	assert_not_null(loaded_character, "Character should be added and retrievable")
	assert_eq(loaded_character.character_name, "Test Character", "Character name should match")
	assert_valid_character(loaded_character)
