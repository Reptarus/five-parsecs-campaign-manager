class_name TestGameStateManager
extends "res://addons/gut/test.gd"

const GameEnums = preload("res://src/core/systems/GlobalEnums.gd")
const GameStateManager = preload("res://src/core/managers/GameStateManager.gd")

var game_state_manager: GameStateManager

func before_each() -> void:
	game_state_manager = GameStateManager.new()
	add_child(game_state_manager)

func after_each() -> void:
	game_state_manager.queue_free()

func test_initial_state() -> void:
	assert_eq(game_state_manager.get_game_state(), GameEnums.GameState.NONE)
	assert_eq(game_state_manager.get_campaign_phase(), GameEnums.CampaignPhase.NONE)
	assert_eq(game_state_manager.get_difficulty(), GameEnums.DifficultyLevel.NORMAL)

func test_difficulty_change() -> void:
	game_state_manager.set_difficulty(GameEnums.DifficultyLevel.HARD)
	assert_eq(game_state_manager.get_difficulty(), GameEnums.DifficultyLevel.HARD)
	
	game_state_manager.set_difficulty(GameEnums.DifficultyLevel.VETERAN)
	assert_eq(game_state_manager.get_difficulty(), GameEnums.DifficultyLevel.VETERAN)
	
	game_state_manager.set_difficulty(GameEnums.DifficultyLevel.NORMAL)
	assert_eq(game_state_manager.get_difficulty(), GameEnums.DifficultyLevel.NORMAL)

func test_resource_management() -> void:
	game_state_manager.set_credits(1000)
	assert_eq(game_state_manager.get_credits(), 1000)
	
	game_state_manager.set_supplies(5)
	assert_eq(game_state_manager.get_supplies(), 5)
	
	game_state_manager.set_reputation(10)
	assert_eq(game_state_manager.get_reputation(), 10)
	
	game_state_manager.set_story_progress(3)
	assert_eq(game_state_manager.get_story_progress(), 3)