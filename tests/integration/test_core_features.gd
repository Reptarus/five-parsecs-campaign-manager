@tool
extends "res://tests/fixtures/game_test.gd"

const TableProcessor := preload("res://src/core/systems/TableProcessor.gd")

# Test variables
var game_state: Node # Using Node type since GameState extends Node

# Lifecycle Methods
func before_each() -> void:
	await super.before_each()
	game_state = create_test_game_state()
	add_child(game_state)
	track_test_node(game_state)
	await get_tree().process_frame

func after_each() -> void:
	await super.after_each()
	game_state = null

# Test Methods
func test_initial_state() -> void:
	assert_not_null(game_state, "Game state should be initialized")
	assert_eq(game_state.get_crew_size(), 0, "Should start with empty crew")
	assert_eq(game_state.get_credits(), 0, "Should start with no credits")
	assert_valid_game_state(game_state)

func test_crew_management() -> void:
	var character = setup_test_character()
	game_state.add_crew_member(character)
	assert_eq(game_state.get_crew_size(), 1, "Crew should have one member")
	assert_signal_emitted(game_state, "crew_updated")
	
	game_state.remove_crew_member(character.character_id)
	assert_eq(game_state.get_crew_size(), 0, "Crew should be empty")
	assert_signal_emitted(game_state, "crew_updated")

func test_resource_management() -> void:
	game_state.credits = 1000
	assert_eq(game_state.get_credits(), 1000, "Credits should be tracked")
	assert_signal_emitted(game_state, "credits_changed")
	
	game_state.resources[GameEnums.ResourceType.FUEL] = 50
	assert_eq(game_state.get_resource(GameEnums.ResourceType.FUEL), 50, "Resources should be tracked")
	assert_signal_emitted(game_state, "resources_changed")

func test_mission_management() -> void:
	var mission = TestHelper.create_test_mission(GameEnums.MissionType.PATROL)
	track_test_resource(mission)
	game_state.add_mission(mission)
	assert_eq(game_state.get_active_missions().size(), 1, "Should have one active mission")
	assert_signal_emitted(game_state, "mission_added")
	
	game_state.complete_mission(mission.mission_id)
	assert_eq(game_state.get_active_missions().size(), 0, "Should have no active missions")
	assert_eq(game_state.get_completed_missions().size(), 1, "Should have one completed mission")
	assert_signal_emitted(game_state, "mission_completed")
