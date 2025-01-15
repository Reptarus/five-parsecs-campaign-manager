@tool
extends BaseTest

# Dependencies - only include what's not in BaseTest
const TestHelper := preload("res://tests/fixtures/test_helper.gd")

var game_state: GameState
var test_mission: StoryQuestData

func before_all() -> void:
	super.before_all()
	_performance_monitoring = true

func after_all() -> void:
	super.after_all()
	_performance_monitoring = false

func before_each() -> void:
	super.before_each()
	game_state = create_test_game_state()
	test_mission = _create_test_mission()
	track_resource(test_mission)

func after_each() -> void:
	super.after_each()
	game_state = null
	test_mission = null

func _create_test_mission() -> StoryQuestData:
	return StoryQuestData.create_mission(GameEnums.MissionType.PATROL)

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
	var custom_mission := StoryQuestData.create_mission(GameEnums.MissionType.SABOTAGE, config)
	track_resource(custom_mission)
	
	assert_eq(custom_mission.name, "Custom Mission", "Mission name should match config")
	assert_eq(custom_mission.risk_level, 3, "Risk level should match config")

# Test Cases - Mission Validation
func test_mission_validation() -> void:
	var validation := test_mission.validate()
	assert_true(validation.is_valid, "Default mission should be valid")
	
	# Test invalid mission
	test_mission.mission_id = ""
	validation = test_mission.validate()
	assert_false(validation.is_valid, "Mission without ID should be invalid")

func test_mission_requirements() -> void:
	var config := {
		"required_reputation": 10,
		"required_crew_size": 3,
		"required_resources": {
			GameEnums.ResourceType.FUEL: 5,
			GameEnums.ResourceType.MEDICAL_SUPPLIES: 2
		}
	}
	var mission := StoryQuestData.create_mission(GameEnums.MissionType.RESCUE, config)
	track_resource(mission)
	
	assert_false(
		mission.can_start(game_state),
		"Mission should not start without meeting requirements"
	)
	
	# Update game state to meet requirements
	game_state.modify_reputation(10)
	game_state.modify_resource(GameEnums.ResourceType.FUEL, 10)
	game_state.modify_resource(GameEnums.ResourceType.MEDICAL_SUPPLIES, 5)
	
	assert_true(
		mission.can_start(game_state),
		"Mission should start after meeting requirements"
	)

# Test Cases - Mission Objectives
func test_mission_objectives() -> void:
	var mission := StoryQuestData.create_mission(GameEnums.MissionType.PATROL)
	track_resource(mission)
	
	mission.add_objective(GameEnums.MissionObjective.WIN_BATTLE, "Win the battle", true)
	mission.add_objective(GameEnums.MissionObjective.PATROL, "Patrol the area", false)
	mission.add_objective(GameEnums.MissionObjective.RECON, "Scout the area", false)
	
	assert_eq(mission.objectives.size(), 3, "Should have 3 objectives")
	assert_true(mission.objectives[0].required, "Primary objective should be required")
	assert_false(mission.objectives[1].required, "Secondary objectives should not be required")

func test_objective_completion() -> void:
	var mission := StoryQuestData.create_mission(GameEnums.MissionType.PATROL)
	track_resource(mission)
	
	mission.add_objective(GameEnums.MissionObjective.WIN_BATTLE, "Win the battle", true)
	mission.add_objective(GameEnums.MissionObjective.PATROL, "Patrol the area", false)
	
	assert_eq(mission.completion_percentage, 0.0, "Initial completion should be 0%")
	
	mission.objectives[0].completed = true
	assert_true(mission.objectives[0].completed, "Primary objective should be complete")
	
	mission.objectives[1].completed = true
	assert_eq(mission.completion_percentage, 100.0, "All objectives complete should be 100%")

# Test Cases - Mission Rewards
func test_mission_rewards() -> void:
	var config := {
		"reward_credits": 1000,
		"reward_reputation": 5,
		"reward_items": ["TEST_ITEM_1", "TEST_ITEM_2"]
	}
	var mission := StoryQuestData.create_mission(GameEnums.MissionType.SABOTAGE, config)
	track_resource(mission)
	
	var rewards: Dictionary = mission.calculate_rewards()
	assert_has(rewards, "credits", "Rewards should include credits")
	assert_has(rewards, "reputation", "Rewards should include reputation")
	assert_has(rewards, "items", "Rewards should include items")
	
	assert_eq(rewards.credits, 1000, "Credits reward should match config")
	assert_eq(rewards.reputation, 5, "Reputation reward should match config")
	assert_eq(rewards.items.size(), 2, "Should have 2 reward items")

func test_reward_modifiers() -> void:
	var mission := StoryQuestData.create_mission(GameEnums.MissionType.PATROL, {
		"reward_credits": 1000
	})
	track_resource(mission)
	
	var base_rewards: Dictionary = mission.calculate_rewards()
	mission.reward_modifiers["credits"] = 1.5
	var modified_rewards: Dictionary = mission.calculate_rewards()
	
	assert_eq(
		modified_rewards.credits,
		base_rewards.credits * 1.5,
		"Rewards should be modified by multiplier"
	)

# Test Cases - Mission State
func test_mission_state_transitions() -> void:
	assert_false(test_mission.is_active, "Initial state should be inactive")
	
	test_mission.is_active = true
	assert_true(test_mission.is_active, "State should be active after starting")
	
	test_mission.is_completed = true
	test_mission.is_active = false
	assert_true(test_mission.is_completed, "State should be completed after completion")

func test_mission_failure() -> void:
	test_mission.is_active = true
	test_mission.is_failed = true
	test_mission.is_active = false
	
	assert_true(test_mission.is_failed, "State should be failed after failure")
	assert_false(test_mission.is_active, "Mission should not be active after failure")

# Test Cases - Performance
func test_mission_generation_performance() -> void:
	if not _performance_monitoring:
		return
		
	var execution_time := TestHelper.measure_execution_time(func():
		for i in range(100):
			var mission := StoryQuestData.create_mission(GameEnums.MissionType.PATROL)
			track_resource(mission)
	)
	
	print("Mission generation time (100 missions): %.3f seconds" % execution_time)
	assert_between(
		execution_time,
		0.0,
		2.0,
		"Mission generation should complete within 2 seconds"
	)

func test_mission_serialization_performance() -> void:
	if not _performance_monitoring:
		return
		
	var missions := []
	for i in range(100):
		missions.append(StoryQuestData.create_mission(GameEnums.MissionType.PATROL))
	
	var execution_time := TestHelper.measure_execution_time(func():
		for mission in missions:
			var data: Dictionary = mission.to_dictionary()
			var restored := StoryQuestData.create_mission(GameEnums.MissionType.NONE)
			restored.from_dictionary(data)
			track_resource(restored)
	)
	
	print("Mission serialization time (100 missions): %.3f seconds" % execution_time)
	assert_between(
		execution_time,
		0.0,
		2.0,
		"Mission serialization should complete within 2 seconds"
	)