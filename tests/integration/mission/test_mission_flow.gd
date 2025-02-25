@tool
extends "res://tests/fixtures/base/game_test.gd"

# Type-safe script references
const Mission: GDScript = preload("res://src/core/systems/Mission.gd")

# Type-safe instance variables
var _mission_manager: Node = null
var _current_mission_state: int = GameEnums.MissionState.NONE
var _mission: Resource
var _tracked_objectives: Array[Dictionary] = []

# Type-safe constants
const TEST_TIMEOUT := 2.0

func before_each() -> void:
	await super.before_each()
	
	# Initialize mission with type safety
	_mission = Mission.new()
	if not _mission:
		push_error("Failed to create mission")
		return
	track_test_resource(_mission)
	
	await stabilize_engine()

func after_each() -> void:
	_cleanup_test_objectives()
	
	if is_instance_valid(_mission):
		_mission.free()
	
	_mission = null
	
	await super.after_each()

# Helper Methods
func _create_test_mission_data() -> Dictionary:
	return {
		"mission_id": str(Time.get_unix_time_from_system()),
		"mission_type": GameEnums.MissionType.PATROL,
		"mission_name": "Test Mission",
		"description": "Test mission description",
		"difficulty": 1,
		"objectives": [],
		"rewards": {
			"credits": 1000,
			"supplies": 50
		},
		"special_rules": []
	}

func _create_test_objective(objective_type: int) -> Dictionary:
	var objective := {
		"objective_type": objective_type,
		"required_progress": 3,
		"current_progress": 0,
		"completed": false,
		"is_primary": true
	}
	
	_tracked_objectives.append(objective)
	return objective

func _cleanup_test_objectives() -> void:
	_tracked_objectives.clear()

# Test Methods
func test_mission_initialization() -> void:
	var mission_data := _create_test_mission_data()
	assert_not_null(mission_data, "Mission data should be created")
	
	# Initialize mission properties with type safety
	_mission.mission_id = mission_data.mission_id
	_mission.mission_type = mission_data.mission_type
	_mission.mission_name = mission_data.mission_name
	_mission.description = mission_data.description
	_mission.difficulty = mission_data.difficulty
	_mission.rewards = mission_data.rewards
	
	# Verify mission state with type safety
	assert_eq(
		_mission.mission_type,
		GameEnums.MissionType.PATROL,
		"Mission type should be set correctly"
	)
	assert_eq(
		_mission.difficulty,
		1,
		"Mission difficulty should be set correctly"
	)
	
	# Verify rewards with type safety
	assert_eq(_mission.rewards.credits, 1000, "Credits reward should be set correctly")
	assert_eq(_mission.rewards.supplies, 50, "Supplies reward should be set correctly")

func test_objective_tracking() -> void:
	# Create test mission and objectives
	var mission_data := _create_test_mission_data()
	var objective := _create_test_objective(GameEnums.ObjectiveType.ELIMINATE)
	
	# Initialize mission properties
	_mission.mission_id = mission_data.mission_id
	_mission.mission_type = mission_data.mission_type
	_mission.objectives = [objective]
	
	# Update objective progress
	objective.current_progress = 1
	_mission.objectives = [objective]
	
	# Verify progress with type safety
	assert_eq(
		_mission.objectives[0].current_progress,
		1,
		"Objective progress should be updated"
	)
	
	# Complete objective
	objective.current_progress = 3
	objective.completed = true
	_mission.objectives = [objective]
	
	# Verify objective completion
	assert_true(
		_mission.objectives[0].completed,
		"Objective should be marked as completed"
	)
	assert_true(
		_mission.is_completed,
		"Mission should be marked as completed"
	)

func test_mission_completion() -> void:
	# Setup mission with objectives
	var mission_data := _create_test_mission_data()
	var objective1 := _create_test_objective(GameEnums.ObjectiveType.ELIMINATE)
	var objective2 := _create_test_objective(GameEnums.ObjectiveType.CAPTURE)
	
	# Initialize mission properties
	_mission.mission_id = mission_data.mission_id
	_mission.mission_type = mission_data.mission_type
	_mission.objectives = [objective1, objective2]
	
	# Complete objectives
	objective1.current_progress = 3
	objective1.completed = true
	_mission.objectives = [objective1, objective2]
	
	objective2.current_progress = 3
	objective2.completed = true
	_mission.objectives = [objective1, objective2]
	
	# Verify mission completion
	assert_true(
		_mission.is_completed,
		"Mission should be marked as completed"
	)
	
	# Verify rewards
	var final_rewards: Dictionary = _mission.calculate_final_rewards()
	assert_true(
		final_rewards.has("bonus_credits"),
		"Should receive bonus credits for completing all objectives"
	)

func test_mission_failure() -> void:
	# Setup mission
	var mission_data := _create_test_mission_data()
	
	# Initialize mission properties
	_mission.mission_id = mission_data.mission_id
	_mission.mission_type = mission_data.mission_type
	
	# Fail mission
	_mission.fail_mission()
	
	# Verify failure state
	assert_true(
		_mission.is_failed,
		"Mission should be marked as failed"
	)
	assert_false(
		_mission.is_completed,
		"Failed mission should not be marked as completed"
	)

# Event Handling Tests
func test_mission_event_handling() -> void:
	watch_signals(_mission)
	
	# Test phase changes
	_mission.change_phase(GameEnums.MissionPhase.PREPARATION)
	verify_signal_emitted(_mission, "phase_changed")
	assert_eq(_mission.current_phase, GameEnums.MissionPhase.PREPARATION)
	
	_mission.change_phase(GameEnums.MissionPhase.COMBAT)
	verify_signal_emitted(_mission, "phase_changed")
	assert_eq(_mission.current_phase, GameEnums.MissionPhase.COMBAT)
	
	# Test completion events
	_mission.is_completed = true
	verify_signal_emitted(_mission, "mission_completed")
	assert_true(_mission.is_completed)

func test_mission_cleanup() -> void:
	watch_signals(_mission)
	
	# Setup initial state
	_mission.change_phase(GameEnums.MissionPhase.COMBAT)
	_mission.is_completed = true
	
	# Test cleanup
	_mission.cleanup()
	
	# Verify reset state
	assert_eq(_mission.current_phase, GameEnums.MissionPhase.PREPARATION)
	assert_false(_mission.is_completed)
	assert_false(_mission.is_failed)
	verify_signal_emitted(_mission, "mission_cleaned_up")

# Performance Testing
func test_mission_performance() -> void:
	var mission_data := _create_test_mission_data()
	
	# Initialize mission properties
	_mission.mission_id = mission_data.mission_id
	_mission.mission_type = mission_data.mission_type
	
	# Add multiple objectives for stress testing
	var objectives: Array[Dictionary] = []
	for i in range(10):
		objectives.append(_create_test_objective(GameEnums.ObjectiveType.ELIMINATE))
	_mission.objectives = objectives
	
	var metrics := await measure_performance(
		func(): _update_mission_state(),
		50 # Reduced iterations for mission performance test
	)
	
	verify_performance_metrics(metrics, {
		"average_fps": 30.0,
		"minimum_fps": 20.0,
		"memory_delta_kb": 256.0,
		"draw_calls_delta": 25
	})

# Helper function for performance testing
func _update_mission_state() -> void:
	for objective in _mission.objectives:
		if not objective.completed:
			objective.current_progress += 1
			if objective.current_progress >= objective.required_progress:
				objective.completed = true
	_mission.objectives = _mission.objectives # Trigger update

# Performance testing methods
func measure_performance(callable: Callable, iterations: int = 100) -> Dictionary:
	var results := {
		"fps_samples": [],
		"memory_samples": [],
		"draw_calls": []
	}
	
	for i in range(iterations):
		await callable.call()
		results.fps_samples.append(Engine.get_frames_per_second())
		results.memory_samples.append(Performance.get_monitor(Performance.MEMORY_STATIC))
		results.draw_calls.append(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
		await stabilize_engine(STABILIZE_TIME)
	
	return {
		"average_fps": _calculate_average(results.fps_samples),
		"minimum_fps": _calculate_minimum(results.fps_samples),
		"memory_delta_kb": (_calculate_maximum(results.memory_samples) - _calculate_minimum(results.memory_samples)) / 1024,
		"draw_calls_delta": _calculate_maximum(results.draw_calls) - _calculate_minimum(results.draw_calls)
	}

func _calculate_average(values: Array) -> float:
	if values.is_empty():
		return 0.0
	var sum := 0.0
	for value in values:
		sum += value
	return sum / values.size()

func _calculate_minimum(values: Array) -> float:
	if values.is_empty():
		return 0.0
	var min_value: float = values[0]
	for value in values:
		min_value = min(min_value, value)
	return min_value

func _calculate_maximum(values: Array) -> float:
	if values.is_empty():
		return 0.0
	var max_value: float = values[0]
	for value in values:
		max_value = max(max_value, value)
	return max_value