@tool
extends "res://tests/fixtures/base_test.gd"

const TestHelper := preload("res://tests/fixtures/test_helper.gd")
const GameState := preload("res://src/core/state/GameState.gd")
const Character := preload("res://src/core/character/Base/Character.gd")

func _init() -> void:
	if not Engine.is_editor_hint():
		_was_ready_called = true

# Game-specific test helper functions
func create_test_game_state() -> GameState:
	var game_state := GameState.new()
	var state_data = TestHelper.setup_test_game_state()
	game_state.load_state(state_data)
	return game_state

func assert_valid_game_state(game_state: Node) -> void:
	assert_not_null(game_state, "Game state should not be null")
	assert_true(game_state.is_initialized(), "Game state should be initialized")
	assert_not_null(game_state.campaign_state, "Campaign state should be initialized")
	assert_not_null(game_state.character_manager, "Character manager should be initialized")
	assert_not_null(game_state.resource_system, "Resource system should be initialized")

func setup_test_character() -> Character:
	return TestHelper.create_test_character()
