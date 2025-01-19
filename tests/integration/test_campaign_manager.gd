@tool
extends "res://tests/fixtures/game_test.gd"

const CampaignManager := preload("res://src/core/managers/CampaignManager.gd")

# Test variables
var game_state: Node # Using Node type since GameState extends Node
var campaign_manager: Resource # Using Resource type since CampaignManager extends Resource

# Lifecycle Methods
func before_each() -> void:
	await super.before_each()
	game_state = create_test_game_state()
	add_child(game_state)
	track_test_node(game_state)
	
	campaign_manager = CampaignManager.new(game_state)
	track_test_resource(campaign_manager)
	
	await get_tree().process_frame

func after_each() -> void:
	await super.after_each()
	campaign_manager = null
	game_state = null

# Test Methods
func test_initial_state() -> void:
	assert_not_null(campaign_manager, "Campaign manager should be initialized")
	assert_not_null(game_state, "Game state should be initialized")
	assert_eq(game_state.difficulty_level, GameEnums.DifficultyLevel.NORMAL, "Should have normal difficulty")
	assert_valid_game_state(game_state)

func test_mission_management() -> void:
	watch_signals(campaign_manager)
	
	var test_mission = {
		"id": "test_mission",
		"type": GameEnums.MissionType.PATROL,
		"difficulty": GameEnums.DifficultyLevel.NORMAL,
		"rewards": {
			"credits": 100
		}
	}
	
	campaign_manager.add_mission(test_mission)
	assert_eq(campaign_manager.active_missions.size(), 1, "Should add mission")
	assert_eq(campaign_manager.active_missions[0].id, "test_mission", "Should set mission ID")
	assert_signal_emitted(campaign_manager, "mission_added")

func test_campaign_persistence() -> void:
	watch_signals(campaign_manager)
	
	var save_data = campaign_manager.save()
	assert_not_null(save_data, "Should generate save data")
	assert_has(save_data, "active_missions", "Save data should include active missions")
	assert_has(save_data, "completed_missions", "Save data should include completed missions")
	assert_signal_emitted(campaign_manager, "campaign_saved")
