@tool
extends "../fixtures/base_test.gd"

const TestHelper = preload("res://tests/fixtures/test_helper.gd")
const GameState = preload("res://src/core/state/GameState.gd")
const StoryQuestData = preload("res://src/core/story/StoryQuestData.gd")

var game_state: GameState
var test_mission: StoryQuestData

func before_each() -> void:
	super.before_each()
	game_state = GameState.new()
	game_state.load_state(TestHelper.setup_test_game_state())
	test_mission = TestHelper.create_test_mission(GameEnums.MissionType.PATROL)
	track_test_resource(test_mission)

func after_each() -> void:
	super.after_each()
	game_state = null
	test_mission = null

# Test Cases - Mission Creation
func test_mission_creation() -> void:
	assert_not_null(test_mission, "Mission should be created")
	assert_eq(test_mission.mission_type, GameEnums.MissionType.PATROL, "Mission type should be PATROL")

func test_mission_with_custom_config() -> void:
	var config := {
		"name": "Custom Mission",
		"description": "Test custom mission",
		"required_reputation": 5,
		"risk_level": 3
	}
	var custom_mission: StoryQuestData = StoryQuestData.create_mission(GameEnums.MissionType.SABOTAGE, config)
	track_test_resource(custom_mission)
	
	watch_signals(custom_mission)
	assert_eq(custom_mission.name, "Custom Mission", "Mission name should match config")
	assert_eq(custom_mission.risk_level, 3, "Risk level should match config")

func test_mission_validation() -> void:
	var mission := TestHelper.create_test_mission(GameEnums.MissionType.PATROL)
	track_test_resource(mission)
	
	var validation: Dictionary = mission.validate()
	assert_true(validation.is_valid, "Mission data should be valid")

func test_mission_rewards() -> void:
	var mission := TestHelper.create_test_mission(GameEnums.MissionType.RAID)
	track_test_resource(mission)
	
	var rewards: Dictionary = mission.calculate_rewards()
	assert_gt(rewards.credits, 0, "Mission should have credit rewards")
	assert_gt(rewards.reputation, 0, "Mission should have reputation rewards")

func test_mission_objectives() -> void:
	var mission := TestHelper.create_test_mission(GameEnums.MissionType.SABOTAGE)
	track_test_resource(mission)
	
	assert_gt(mission.objectives.size(), 0, "Mission should have objectives")
	for objective in mission.objectives:
		assert_not_null(objective, "Objective should not be null")

func test_mission_state_transitions() -> void:
	var mission := TestHelper.create_test_mission(GameEnums.MissionType.PATROL)
	track_test_resource(mission)
	
	watch_signals(mission)
	mission.is_active = true
	assert_true(mission.is_active, "Mission should be active")
	
	mission.is_completed = true
	mission.is_active = false
	assert_true(mission.is_completed, "Mission should be completed")

func test_mission_difficulty_scaling() -> void:
	var mission := TestHelper.create_test_mission(GameEnums.MissionType.RAID)
	track_test_resource(mission)
	
	var rewards: Dictionary = mission.calculate_rewards()
	assert_gt(mission.risk_level, 0, "Mission should have risk level")
	assert_gt(rewards.credits, mission.risk_level * 50, "Rewards should scale with risk level")

func test_mission_serialization() -> void:
	var mission := TestHelper.create_test_mission(GameEnums.MissionType.PATROL)
	track_test_resource(mission)
	
	var data: Dictionary = mission.serialize()
	var restored := StoryQuestData.new()
	restored.deserialize(data)
	track_test_resource(restored)
	
	assert_eq(restored.mission_type, mission.mission_type, "Mission type should be preserved")
	assert_eq(restored.reward_credits, mission.reward_credits, "Rewards should be preserved")