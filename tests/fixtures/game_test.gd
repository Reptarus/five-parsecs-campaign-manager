@tool
extends "res://tests/fixtures/base_test.gd"
class_name GameTest

# Lazy-loaded resources to avoid circular dependencies
var GameState
var Character
var TestHelper

func _init() -> void:
	if not Engine.is_editor_hint():
		GameState = load("res://src/core/state/GameState.gd")
		Character = load("res://src/core/character/Base/Character.gd")
		TestHelper = load("res://tests/fixtures/test_helper.gd")

# Game-specific test helper functions
func create_test_game_state() -> Node:
	var game_state = GameState.new()
	return game_state

func load_test_campaign(game_state: Node) -> void:
	var state_data = TestHelper.setup_test_game_state()
	game_state.load_campaign(state_data)

func setup_test_character() -> Resource:
	return TestHelper.create_test_character()

func assert_valid_game_state(game_state: Node) -> void:
	super.assert_valid_game_state(game_state)
	assert_not_null(game_state.campaign_state, "Campaign state should be initialized")
	assert_not_null(game_state.character_manager, "Character manager should be initialized")
	assert_not_null(game_state.resource_system, "Resource system should be initialized")
