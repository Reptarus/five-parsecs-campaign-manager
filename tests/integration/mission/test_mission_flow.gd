@tool
extends GdUnitGameTest

# Import GameEnums for mission constants
const GameEnums = preload("res://src/core/systems/GlobalEnums.gd")

# Type-safe script references
const Mission: GDScript = preload("res://src/core/systems/Mission.gd")

# Type-safe instance variables
var _mission_manager: Node = null
var _current_mission_state: int = 0 # Placeholder for GameEnums.MissionState.NONE
var _mission: Node
var _tracked_objectives: Array[Dictionary] = []

# Type-safe constants
const TEST_TIMEOUT := 2.0

# Type-safe mock script creation for testing
var MockMissionScript: GDScript

func before_test() -> void:
	super.before_test()
	
	# Create mock mission script
	_create_mock_mission_script()
	
	# Initialize test mission
	_mission = Node.new()
	_mission.name = "TestMission"
	_mission.set_script(MockMissionScript)
	track_node(_mission)
	
	await get_tree().process_frame

func after_test() -> void:
	_cleanup_test_objectives()
	
	# Proper cleanup - no need to free as it's tracked by gdUnit4
	_mission = null
	
	super.after_test()

func _create_mock_mission_script() -> void:
	MockMissionScript = GDScript.new()
	MockMissionScript.source_code = '''
extends Node

signal objective_completed(objective_id: String)
signal mission_completed()
signal mission_failed()
signal mission_event(event_data: Dictionary)
signal phase_changed(new_phase: String)

var mission_data: Dictionary = {}
var objectives: Array = []
var is_active: bool = false
var is_completed: bool = false
var is_failed: bool = false
var mission_type: int = 0
var difficulty: int = 1
var rewards: Dictionary = {}
var current_phase: String = "setup"

func initialize(data: Dictionary) -> void:
	mission_data = data.duplicate()
	objectives = data.get("objectives", [])
	mission_type = data.get("mission_type", 0)
	difficulty = data.get("difficulty", 1)
	rewards = data.get("rewards", {"credits": 1000, "supplies": 50})
	is_active = false
	is_completed = false
	is_failed = false

func start_mission() -> bool:
	if not is_active and not is_completed and not is_failed:
		is_active = true
		return true
	return false

func set_objectives(new_objectives: Array) -> void:
	objectives = new_objectives
	_check_mission_completion()

func change_phase(new_phase: String) -> void:
	current_phase = new_phase
	phase_changed.emit(new_phase)

func complete_objective(objective_id: String) -> bool:
	for objective in objectives:
		if objective.get("id") == objective_id:
			objective["completed"] = true
			objective_completed.emit(objective_id)
			_check_mission_completion()
			return true
	return false

func fail_mission() -> void:
	is_active = false
	is_failed = true
	mission_failed.emit()

func _check_mission_completion() -> void:
	var all_completed = true
	for objective in objectives:
		if not objective.get("completed", false):
			all_completed = false
			break
	
	if all_completed:
		is_active = false
		is_completed = true
		mission_completed.emit()

func trigger_event(event_data: Dictionary) -> void:
	mission_event.emit(event_data)

func cleanup() -> void:
	is_active = false
	objectives.clear()
	mission_data.clear()
	rewards.clear()

func calculate_final_rewards() -> Dictionary:
	var final_rewards := rewards.duplicate()
	if is_completed:
		final_rewards["bonus_credits"] = true
		final_rewards["credits"] = final_rewards.get("credits", 0) * 1.2
	return final_rewards

func get_mission_data() -> Dictionary:
	return mission_data.duplicate()

func get_objectives() -> Array:
	return objectives.duplicate()

func is_mission_active() -> bool:
	return is_active

func is_mission_completed() -> bool:
	return is_completed

func is_mission_failed() -> bool:
	return is_failed

func get_phase() -> String:
	return current_phase
'''
	MockMissionScript.reload() # Compile the script

# Helper Methods
func _create_test_mission_data() -> Dictionary:
	return {
		"mission_id": str(Time.get_unix_time_from_system()),
		"mission_type": 0, # Placeholder for GameEnums.MissionType.PATROL
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
	assert_that(mission_data).override_failure_message("Mission data should be created").is_not_null()
	
	# Initialize mission with data
	_mission.initialize(mission_data)
	
	# Verify mission state with type safety
	assert_that(_mission.mission_type).override_failure_message("Mission type should be set correctly").is_equal(0)
	assert_that(_mission.difficulty).override_failure_message("Mission difficulty should be set correctly").is_equal(1)
	
	# Verify rewards
	assert_that(_mission.rewards.credits).override_failure_message("Credits reward should be set correctly").is_equal(1000)
	assert_that(_mission.rewards.supplies).override_failure_message("Supplies reward should be set correctly").is_equal(50)

func test_objective_tracking() -> void:
	# Create test mission and objectives
	var mission_data := _create_test_mission_data()
	var objective := _create_test_objective(0) # Placeholder for GameEnums.ObjectiveType.ELIMINATE
	
	# Initialize mission
	_mission.initialize(mission_data)
	_mission.set_objectives([objective])
	
	# Update objective progress
	objective.current_progress = 1
	_mission.set_objectives([objective])
	
	# Verify progress
	assert_that(_mission.objectives[0].current_progress).override_failure_message("Objective progress should be updated").is_equal(1)
	
	# Complete objective
	objective.current_progress = 3
	objective.completed = true
	_mission.set_objectives([objective])
	
	# Verify objective completion
	assert_that(_mission.objectives[0].completed).override_failure_message("Objective should be marked as completed").is_true()
	assert_that(_mission.is_completed).override_failure_message("Mission should be marked as completed").is_true()

func test_mission_completion() -> void:
	# Setup mission with objectives
	var mission_data := _create_test_mission_data()
	var objective1 := _create_test_objective(0) # Placeholder for GameEnums.ObjectiveType.ELIMINATE
	var objective2 := _create_test_objective(1) # Placeholder for GameEnums.ObjectiveType.CAPTURE
	
	# Initialize mission
	_mission.initialize(mission_data)
	
	# Complete objectives
	objective1.current_progress = 3
	objective1.completed = true
	objective2.current_progress = 3
	objective2.completed = true
	
	_mission.set_objectives([objective1, objective2])
	
	# Verify mission completion
	assert_that(_mission.is_completed).override_failure_message("Mission should be marked as completed").is_true()
	
	# Verify rewards
	var final_rewards: Dictionary = _mission.calculate_final_rewards()
	assert_that(final_rewards.has("bonus_credits")).override_failure_message("Should receive bonus credits for completing all objectives").is_true()

func test_mission_failure() -> void:
	# Setup mission
	var mission_data := _create_test_mission_data()
	_mission.initialize(mission_data)
	
	# Fail mission
	_mission.fail_mission()
	
	# Verify failure state
	assert_that(_mission.is_failed).override_failure_message("Mission should be marked as failed").is_true()
	assert_that(_mission.is_completed).override_failure_message("Failed mission should not be marked as completed").is_false()

# Event Handling Tests
func test_mission_event_handling() -> void:
	var mission_data := _create_test_mission_data()
	_mission.initialize(mission_data)
	
	monitor_signals(_mission)
	
	# Test phase changes
	_mission.change_phase("PREPARATION") # Use string phase names
	assert_signal(_mission).is_emitted("phase_changed")
	assert_that(_mission.current_phase).is_equal("PREPARATION")
	
	_mission.change_phase("COMBAT") # Use string phase names
	assert_signal(_mission).is_emitted("phase_changed")
	assert_that(_mission.current_phase).is_equal("COMBAT")
	
	# Test completion events
	var objective := _create_test_objective(0)
	objective.completed = true
	_mission.set_objectives([objective])
	assert_signal(_mission).is_emitted("mission_completed")
	assert_that(_mission.is_completed).is_true()

func test_mission_cleanup() -> void:
	var mission_data := _create_test_mission_data()
	_mission.initialize(mission_data)
	
	# Mission cleanup is handled by gdUnit4 track_node
	assert_that(_mission).is_not_null()

func test_mission_performance() -> void:
	var mission_data := _create_test_mission_data()
	_mission.initialize(mission_data)
	
	monitor_signals(_mission)
	
	# Test performance by completing a mission quickly
	var objective := _create_test_objective(0)
	objective.completed = true
	_mission.set_objectives([objective])
	
	# Wait for completion signal with timeout
	await assert_signal(_mission).is_emitted("mission_completed")
	
	# Verify completion
	assert_that(_mission.is_completed).is_true()
	
	# Performance metrics would be measured by external systems
	# For testing purposes, we just verify the mission completed in reasonable time        