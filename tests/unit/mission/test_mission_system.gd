@tool
extends "res://tests/fixtures/game_test.gd"

## Mission system test suite
## Tests core functionality, edge cases, and performance of the mission system
## @class TestMissionSystem
## @description Validates mission lifecycle, objectives, rewards, and state management

const Mission = preload("res://src/core/systems/Mission.gd")

var mission: Mission

# Test lifecycle methods
func before_each() -> void:
	await super.before_each()
	mission = Mission.new()
	track_test_resource(mission)
	await get_tree().process_frame

func after_each() -> void:
	await super.after_each()
	mission = null

# Helper methods
func create_test_objective(index: int, type: String = "primary") -> Dictionary:
	return {
		"index": index,
		"description": "Test objective",
		"type": type,
		"completed": false
	}

func setup_mission_with_objectives(objective_count: int) -> void:
	for i in range(objective_count):
		mission.add_objective(create_test_objective(i))

# Basic functionality tests
func test_initial_state() -> void:
	assert_eq(mission.get_mission_type(), GameEnums.MissionType.NONE, "Should start with no mission type")
	assert_eq(mission.get_objectives().size(), 0, "Should start with no objectives")
	assert_false(mission.is_mission_completed(), "Should not be completed")
	assert_false(mission.is_mission_failed(), "Should not be failed")

func test_mission_completion() -> void:
	watch_signals(mission)
	mission.complete_mission()
	assert_true(mission.is_mission_completed(), "Should be marked as completed")
	assert_signal_emitted(mission, "mission_completed")

func test_mission_failure() -> void:
	watch_signals(mission)
	mission.fail_mission()
	assert_true(mission.is_mission_failed(), "Should be marked as failed")
	assert_signal_emitted(mission, "mission_failed")

func test_phase_change() -> void:
	watch_signals(mission)
	mission.set_phase("combat")
	assert_eq(mission.get_current_phase(), "combat", "Should update phase")
	assert_signal_emitted(mission, "phase_changed")

func test_progress_update() -> void:
	watch_signals(mission)
	mission.update_progress(50.0)
	assert_eq(mission.get_completion_percentage(), 50.0, "Should update progress")
	assert_signal_emitted(mission, "progress_updated")

# Objective system tests
func test_objective_management() -> void:
	watch_signals(mission)
	var objective = create_test_objective(0)
	
	mission.add_objective(objective)
	assert_eq(mission.get_objectives().size(), 1, "Should add objective")
	assert_signal_emitted(mission, "objective_added")
	
	mission.complete_objective(0)
	assert_true(mission.get_objectives()[0].completed, "Should complete objective")
	assert_signal_emitted(mission, "objective_completed")

# Performance tests
func test_large_objective_set_performance() -> void:
	var start_time = Time.get_ticks_msec()
	setup_mission_with_objectives(100)
	var end_time = Time.get_ticks_msec()
	
	assert_lt(end_time - start_time, 100, "Should handle large objective sets efficiently")
	assert_eq(mission.get_objectives().size(), 100, "Should maintain all objectives")

# Boundary tests
func test_invalid_objective_operations() -> void:
	assert_null(mission.get_objective(-1), "Should handle invalid index gracefully")
	assert_false(mission.has_objective(999), "Should handle nonexistent objective index")
	
	# Test objective limit
	setup_mission_with_objectives(999)
	var result = mission.add_objective(create_test_objective(999))
	assert_false(result, "Should handle objective limit gracefully")

# State persistence tests
func test_mission_state_persistence() -> void:
	watch_signals(mission)
	
	mission.set_mission_name("Test Mission")
	mission.set_mission_type(GameEnums.MissionType.PATROL)
	mission.set_difficulty(GameEnums.DifficultyLevel.NORMAL)
	mission.update_progress(50.0)
	
	var save_data = mission.save_state()
	assert_not_null(save_data, "Should generate save data")
	assert_signal_emitted(mission, "state_saved")
	
	var new_mission = Mission.new()
	new_mission.load_state(save_data)
	assert_signal_emitted(new_mission, "state_loaded")
	
	assert_eq(new_mission.get_mission_name(), "Test Mission", "Should restore mission name")
	assert_eq(new_mission.get_mission_type(), GameEnums.MissionType.PATROL, "Should restore mission type")
	assert_eq(new_mission.get_difficulty(), GameEnums.DifficultyLevel.NORMAL, "Should restore difficulty")
	assert_eq(new_mission.get_completion_percentage(), 50.0, "Should restore progress")

# Stress tests
func test_rapid_state_changes() -> void:
	watch_signals(mission)
	for i in range(100):
		mission.update_progress(float(i))
		mission.set_phase("phase_%d" % i)
	
	assert_signal_emit_count(mission, "progress_updated", 100)
	assert_signal_emit_count(mission, "phase_changed", 100)

func test_reward_calculation() -> void:
	mission.set_base_rewards({
		"credits": 1000,
		"reputation": 2
	})
	mission.set_reward_multiplier(1.5)
	
	var rewards = mission.calculate_rewards()
	assert_eq(rewards.credits, 1500, "Should calculate credits with multiplier")
	assert_eq(rewards.reputation, 3, "Should calculate reputation with multiplier")

func test_mission_requirements() -> void:
	var requirements = {
		"min_crew": 3,
		"required_skills": ["combat", "tech"],
		"required_equipment": ["armor"]
	}
	mission.set_requirements(requirements)
	
	var valid_crew = {
		"size": 4,
		"skills": ["combat", "tech", "medical"],
		"equipment": ["armor", "weapons"]
	}
	assert_true(mission.check_requirements(valid_crew), "Should pass valid requirements")
	
	var invalid_crew = {
		"size": 2,
		"skills": ["combat"],
		"equipment": []
	}
	assert_false(mission.check_requirements(invalid_crew), "Should fail invalid requirements")