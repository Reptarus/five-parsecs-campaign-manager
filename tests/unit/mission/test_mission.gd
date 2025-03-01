@tool
extends GameTest

## Mission System Unit Tests
##
## Tests comprehensive mission functionality including:
## - Mission creation and initialization
## - Mission state management and persistence
## - Objective completion and validation
## - Resource calculation and reward systems
## - Performance under stress conditions
## - Signal handling and state transitions

const Mission = preload("res://src/core/mission/base/mission.gd")
const TEST_SAVE_PATH := "user://test_mission_save.tres"

# Helper variables
var _mission: Mission
var _received_signals: Array[String] = []

# Helper methods
func _connect_mission_signals() -> void:
	var mission_object = _mission as Object
	if mission_object:
		TypeSafeMixin._safe_connect(mission_object, "objective_completed", _on_objective_completed)
		TypeSafeMixin._safe_connect(mission_object, "mission_completed", _on_mission_completed)
		TypeSafeMixin._safe_connect(mission_object, "mission_failed", _on_mission_failed)

func _on_objective_completed(index: int) -> void:
	_received_signals.append("objective_completed")

func _on_mission_completed() -> void:
	_received_signals.append("mission_completed")

func _on_mission_failed() -> void:
	_received_signals.append("mission_failed")

func before_each() -> void:
	await super.before_each()
	# Initialize and track mission resource
	_mission = Mission.new()
	track_test_resource(_mission)
	
	# Setup default mission parameters
	_mission.mission_name = "Test Mission"
	_mission.mission_type = GameEnums.MissionType.RED_ZONE
	_mission.difficulty = GameEnums.DifficultyLevel.NORMAL
	_mission.objectives = [
		{
			"type": GameEnums.MissionObjective.SEEK_AND_DESTROY,
			"description": "Find and eliminate the target",
			"completed": false,
			"is_primary": true
		},
		{
			"type": GameEnums.MissionObjective.CAPTURE_POINT,
			"description": "Secure the area",
			"completed": false,
			"is_primary": false
		}
	]
	_mission.rewards = {
		"credits": 1000,
		"reputation": 2
	}

func after_each() -> void:
	await super.after_each()
	_mission = null

# Basic Functionality Tests

func test_mission_initialization() -> void:
	assert_not_null(_mission.mission_id, "Mission should have an ID")
	assert_eq(_mission.mission_name, "Test Mission", "Mission name should be set")
	assert_eq(_mission.mission_type, GameEnums.MissionType.RED_ZONE, "Mission type should be set")
	assert_eq(_mission.difficulty, GameEnums.DifficultyLevel.NORMAL, "Difficulty should be set")
	assert_eq(_mission.objectives.size(), 2, "Should have 2 objectives")
	assert_false(_mission.is_completed, "Mission should not be completed initially")

func test_mission_types() -> void:
	# Test all mission types
	var mission_types = [
		GameEnums.MissionType.SABOTAGE,
		GameEnums.MissionType.RESCUE,
		GameEnums.MissionType.BLACK_ZONE,
		GameEnums.MissionType.GREEN_ZONE,
		GameEnums.MissionType.RED_ZONE,
		GameEnums.MissionType.PATROL,
		GameEnums.MissionType.ESCORT,
		GameEnums.MissionType.ASSASSINATION,
		GameEnums.MissionType.PATRON,
		GameEnums.MissionType.RAID,
		GameEnums.MissionType.DEFENSE
	]
	
	for type in mission_types:
		_mission.mission_type = type
		assert_eq(_mission.mission_type, type,
			"Should set mission type: %s" % GameEnums.MissionType.keys()[type])

func test_mission_objectives() -> void:
	# Test all objective types
	var objective_types = [
		GameEnums.MissionObjective.WIN_BATTLE,
		GameEnums.MissionObjective.SABOTAGE,
		GameEnums.MissionObjective.RECON,
		GameEnums.MissionObjective.RESCUE,
		GameEnums.MissionObjective.PATROL,
		GameEnums.MissionObjective.SEEK_AND_DESTROY,
		GameEnums.MissionObjective.DEFEND,
		GameEnums.MissionObjective.CAPTURE_POINT
	]
	
	_mission.objectives.clear()
	for objective_type in objective_types:
		var objective = {
			"type": objective_type,
			"description": "Test objective %s" % GameEnums.MissionObjective.keys()[objective_type],
			"completed": false,
			"is_primary": true
		}
		_mission.objectives.append(objective)
		assert_eq(_mission.objectives.back().type, objective_type,
			"Should add objective type: %s" % GameEnums.MissionObjective.keys()[objective_type])

# Signal Tests
func test_mission_signals() -> void:
	_connect_mission_signals()
	
	_mission.complete_objective(0)
	assert_has(_received_signals, "objective_completed")
	assert_has(_received_signals, "mission_completed")
	
	_mission.fail_mission()
	assert_has(_received_signals, "mission_failed")

# Performance Tests
func test_large_objective_list_performance() -> void:
	var start_time := Time.get_ticks_msec()
	for i in range(1000):
		_mission.objectives.append({
			"type": GameEnums.MissionObjective.SEEK_AND_DESTROY,
			"description": "Performance test objective %d" % i,
			"completed": false,
			"is_primary": false
		})
	var end_time := Time.get_ticks_msec()
	assert_lt(end_time - start_time, 100, "Should handle large objective lists efficiently")

# State Persistence Tests
func test_mission_state_persistence() -> void:
	_mission.complete_objective(0)
	var err := ResourceSaver.save(_mission, TEST_SAVE_PATH)
	assert_eq(err, OK, "Should save mission state without errors")
	
	var loaded_mission: Mission = load(TEST_SAVE_PATH)
	assert_not_null(loaded_mission, "Should load saved mission")
	assert_eq(loaded_mission.completion_percentage, _mission.completion_percentage,
		"Should preserve completion state")

# Stress Tests
func test_rapid_objective_updates() -> void:
	for i in range(100):
		_mission.complete_objective(0)
		_mission.reset_objective(0)
	assert_false(_mission.objectives[0]["completed"],
		"Should handle rapid objective state changes")

# Validation Tests

func test_requirement_validation() -> void:
	_mission.required_skills = ["combat", "tech"]
	_mission.required_equipment = ["armor"]
	_mission.minimum_crew_size = 2
	
	# Test with insufficient capabilities
	var insufficient_capabilities := {
		"skills": ["combat"],
		"equipment": [],
		"crew_size": 1
	}
	var result1 = _mission.validate_requirements(insufficient_capabilities)
	assert_false(result1["valid"], "Should fail with insufficient capabilities")
	assert_eq(result1["missing"].size(), 2, "Should have 2 missing requirements")
	
	# Test with sufficient capabilities
	var sufficient_capabilities := {
		"skills": ["combat", "tech", "medical"],
		"equipment": ["armor", "weapons"],
		"crew_size": 3
	}
	var result2 = _mission.validate_requirements(sufficient_capabilities)
	assert_true(result2["valid"], "Should pass with sufficient capabilities")
	assert_eq(result2["missing"].size(), 0, "Should have no missing requirements")

# Completion Tests

func test_objective_completion() -> void:
	# Complete primary objective
	_mission.complete_objective(0)
	assert_true(_mission.objectives[0]["completed"], "Primary objective should be completed")
	assert_true(_mission.is_completed, "Mission should be completed when primary objective is done")
	
	# Verify completion percentage
	assert_eq(_mission.completion_percentage, 50.0, "Completion should be 50% with one objective done")
	
	# Complete secondary objective
	_mission.complete_objective(1)
	assert_eq(_mission.completion_percentage, 100.0, "Completion should be 100% with all objectives done")

func test_mission_failure() -> void:
	_mission.fail_mission()
	assert_true(_mission.is_failed, "Mission should be marked as failed")
	assert_false(_mission.is_completed, "Failed mission should not be marked as completed")

# Victory Condition Tests

func test_mission_victory_conditions() -> void:
	# Test all victory condition types
	var victory_types = [
		GameEnums.MissionVictoryType.ELIMINATION,
		GameEnums.MissionVictoryType.EXTRACTION,
		GameEnums.MissionVictoryType.SURVIVAL,
		GameEnums.MissionVictoryType.CONTROL_POINTS,
		GameEnums.MissionVictoryType.OBJECTIVE
	]
	
	for victory_type in victory_types:
		_mission.victory_condition = victory_type
		assert_eq(_mission.victory_condition, victory_type,
			"Should set victory condition: %s" % GameEnums.MissionVictoryType.keys()[victory_type])

# Reward Tests

func test_reward_calculation() -> void:
	# Test basic reward calculation
	var base_rewards = _mission.calculate_final_rewards()
	assert_eq(base_rewards.size(), 0, "Should not give rewards for incomplete mission")
	
	# Complete mission and test rewards
	_mission.complete_objective(0)
	var final_rewards = _mission.calculate_final_rewards()
	assert_eq(final_rewards["credits"], 1000, "Should get base credits")
	assert_eq(final_rewards["reputation"], 2, "Should get base reputation")
	
	# Test reward multipliers
	_mission.resource_multiplier = 1.5
	_mission.reputation_multiplier = 2.0
	final_rewards = _mission.calculate_final_rewards()
	assert_eq(final_rewards["credits"], 1500, "Credits should be multiplied")
	assert_eq(final_rewards["reputation"], 4, "Reputation should be multiplied")
	
	# Complete all objectives and test bonus rewards
	_mission.complete_objective(1)
	final_rewards = _mission.calculate_final_rewards()
	assert_has(final_rewards, "bonus_credits", "Should have bonus credits for all objectives")
	assert_has(final_rewards, "bonus_reputation", "Should have bonus reputation for all objectives")

# Summary Tests

func test_mission_summary() -> void:
	var summary = _mission.get_summary()
	assert_has(summary, "id", "Summary should have mission ID")
	assert_has(summary, "name", "Summary should have mission name")
	assert_has(summary, "type", "Summary should have mission type")
	assert_has(summary, "difficulty", "Summary should have difficulty")
	assert_has(summary, "completion", "Summary should have completion percentage")
	assert_has(summary, "status", "Summary should have status")
	assert_has(summary, "objectives", "Summary should have objectives")
	assert_has(summary, "rewards", "Summary should have rewards")

# Error Condition Tests

func test_invalid_objective_completion() -> void:
	# Test completing non-existent objective
	_mission.complete_objective(99)
	assert_false(_mission.objectives.any(func(obj): return obj["completed"]),
		"No objectives should be completed when index is invalid")
	
	# Test completing already completed objective
	_mission.complete_objective(0)
	var initial_completion = _mission.completion_percentage
	_mission.complete_objective(0)
	assert_eq(_mission.completion_percentage, initial_completion,
		"Completion percentage should not change when completing already completed objective")

func test_invalid_requirement_validation() -> void:
	# Test with empty capabilities
	var result = _mission.validate_requirements({})
	assert_false(result["valid"], "Should fail with empty capabilities")
	
	# Test with invalid capability types
	result = _mission.validate_requirements({
		"skills": null,
		"equipment": null,
		"crew_size": "invalid"
	})
	assert_false(result["valid"], "Should fail with invalid capability types")

# Boundary Tests

func test_mission_difficulty_boundaries() -> void:
	# Test minimum difficulty
	_mission.difficulty = GameEnums.DifficultyLevel.values().min()
	assert_eq(_mission.difficulty, GameEnums.DifficultyLevel.values().min(),
		"Should accept minimum difficulty level")
	
	# Test maximum difficulty
	_mission.difficulty = GameEnums.DifficultyLevel.values().max()
	assert_eq(_mission.difficulty, GameEnums.DifficultyLevel.values().max(),
		"Should accept maximum difficulty level")

func test_reward_multiplier_boundaries() -> void:
	# Test minimum multipliers
	_mission.resource_multiplier = 0.0
	_mission.reputation_multiplier = 0.0
	var rewards = _mission.calculate_final_rewards()
	assert_eq(rewards["credits"], 0, "Should handle zero resource multiplier")
	assert_eq(rewards["reputation"], 0, "Should handle zero reputation multiplier")
	
	# Test large multipliers
	_mission.resource_multiplier = 1000.0
	_mission.reputation_multiplier = 1000.0
	rewards = _mission.calculate_final_rewards()
	assert_gt(rewards["credits"], 0, "Should handle large resource multiplier")
	assert_gt(rewards["reputation"], 0, "Should handle large reputation multiplier")

func test_extreme_mission_parameters() -> void:
	_mission.required_crew_size = 999999
	_mission.resource_multiplier = 1e10
	_mission.reputation_multiplier = -1e10
	
	var result = _mission.validate_requirements({"crew_size": 1000000})
	assert_false(result["valid"], "Should handle extreme crew requirements")
	
	var rewards = _mission.calculate_final_rewards()
	assert_not_null(rewards, "Should handle extreme multipliers without crashing")

func test_null_and_empty_values() -> void:
	_mission.mission_name = ""
	_mission.objectives = []
	_mission.rewards = {}
	
	var summary = _mission.get_summary()
	assert_not_null(summary, "Should handle empty/null values gracefully")