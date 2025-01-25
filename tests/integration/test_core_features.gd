@tool
extends "res://tests/fixtures/game_test.gd"

const TableProcessor := preload("res://src/core/systems/TableProcessor.gd")

# Test variables
var game_state: Node # Using Node type since GameState extends Node

# Lifecycle Methods
func before_each() -> void:
	await super.before_each()
	game_state = create_test_game_state()
	add_child_autofree(game_state)
	assert_valid_game_state(game_state)
	watch_signals(game_state)
	await stabilize_engine()

func after_each() -> void:
	await super.after_each()
	game_state = null

# Test Methods
func test_initial_state() -> void:
	assert_not_null(game_state, "Game state should be initialized")
	assert_not_null(game_state.current_campaign, "Campaign should be initialized")
	assert_eq(game_state.difficulty_level, GameEnums.DifficultyLevel.NORMAL, "Should start with normal difficulty")
	assert_true(game_state.enable_permadeath, "Should start with permadeath enabled")
	assert_true(game_state.use_story_track, "Should start with story track enabled")
	assert_valid_game_state(game_state)

func test_crew_management() -> void:
	var character = TestHelper.create_test_character()
	game_state.current_campaign.add_crew_member(character)
	var crew_changed = await assert_async_signal(game_state.current_campaign, "crew_changed")
	assert_true(crew_changed, "Crew changed signal should be emitted")
	assert_eq(game_state.current_campaign.crew_members.size(), 1, "Crew should have one member")
	
	game_state.current_campaign.remove_crew_member(character.character_id)
	crew_changed = await assert_async_signal(game_state.current_campaign, "crew_changed")
	assert_true(crew_changed, "Crew changed signal should be emitted")
	assert_eq(game_state.current_campaign.crew_members.size(), 0, "Crew should be empty")

func test_resource_management() -> void:
	game_state.credits = 1000
	var credits_changed = await assert_async_signal(game_state, "credits_changed")
	assert_true(credits_changed, "Credits changed signal should be emitted")
	assert_eq(game_state.get_credits(), 1000, "Credits should be tracked")
	
	game_state.resources[GameEnums.ResourceType.FUEL] = 50
	var resources_changed = await assert_async_signal(game_state, "resources_changed")
	assert_true(resources_changed, "Resources changed signal should be emitted")
	assert_eq(game_state.get_resource(GameEnums.ResourceType.FUEL), 50, "Resources should be tracked")

func test_mission_management() -> void:
	var mission = TestHelper.setup_test_mission({
		"type": GameEnums.MissionType.PATROL,
		"difficulty": GameEnums.DifficultyLevel.NORMAL
	})
	track_test_resource(mission)
	game_state.add_mission(mission)
	
	var mission_added = await assert_async_signal(game_state, "mission_added")
	assert_true(mission_added, "Mission added signal should be emitted")
	assert_eq(game_state.get_active_missions().size(), 1, "Should have one active mission")
	
	game_state.complete_mission(mission.mission_id)
	var mission_completed = await assert_async_signal(game_state, "mission_completed")
	assert_true(mission_completed, "Mission completed signal should be emitted")
	assert_eq(game_state.get_active_missions().size(), 0, "Should have no active missions")
	assert_eq(game_state.get_completed_missions().size(), 1, "Should have one completed mission")
