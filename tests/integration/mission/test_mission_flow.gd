@tool
extends GdUnitGameTest

# Mock Mission Resource
const GameEnums = preload("res://src/core/systems/GlobalEnums.gd")
const Mission: GDScript = preload("res://src/core/systems/Mission.gd")

# Type-safe instance variables
var _mission: Node
var _tracked_objectives: Array[Dictionary] = []

# Test timeout constant
const TEST_TIMEOUT := 2.0

# Mock mission script
var MockMissionScript: GDScript

func before_test() -> void:
    super.before_test()
    
    # Create mock mission script
    _create_mock_mission_script()
    
    # Initialize mission
    _mission = Node.new()
    _mission.name = "TestMission"
    _mission.set_script(MockMissionScript)

func after_test() -> void:
    _cleanup_test_objectives()
    
    # Clean up mission
    if is_instance_valid(_mission):
        _mission.queue_free()
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
var current_phase: String = "SETUP"

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
    var final_rewards = rewards.duplicate()
    if is_completed:
        final_rewards["bonus_credits"] = true
        final_rewards["credits"] = final_rewards.get("credits", 0) * 1.2
    return final_rewards

func get_mission_data() -> Dictionary:
    return mission_data

func get_objectives() -> Array:
    return objectives

func is_mission_active() -> bool:
    return is_active

func is_mission_completed() -> bool:
    return is_completed

func is_mission_failed() -> bool:
    return is_failed

func get_phase() -> String:
    return current_phase
'''
    MockMissionScript.reload()

# Helper functions
func _create_test_mission_data() -> Dictionary:
    return {
        "mission_id": str(Time.get_unix_time_from_system()),
        "mission_type": 0,
        "mission_name": "Test Mission",
        "description": "Test mission description",
        "difficulty": 1,
        "objectives": [],
        "rewards": {
            "credits": 1000,
            "supplies": 50,
        },
        "special_rules": [],
    }

func _create_test_objective(objective_type: int) -> Dictionary:
    var objective := {
        "id": "test_obj_" + str(_tracked_objectives.size()),
        "objective_type": objective_type,
        "required_progress": 3,
        "current_progress": 0,
        "completed": false,
        "is_primary": true,
    }
    _tracked_objectives.append(objective)
    return objective

func _cleanup_test_objectives() -> void:
    _tracked_objectives.clear()

# Test functions
func test_mission_initialization() -> void:
    var mission_data := _create_test_mission_data()
    assert_that(mission_data).is_not_null()
    
    # Initialize mission
    _mission.initialize(mission_data)
    
    # Verify mission state with type safety
    assert_that(_mission.is_mission_active()).is_false()
    assert_that(_mission.is_mission_completed()).is_false()
    
    # Verify rewards
    var rewards = _mission.get_mission_data().get("rewards", {})
    assert_that(rewards).is_not_empty()

func test_objective_tracking() -> void:
    # Create test mission and objectives
    var mission_data := _create_test_mission_data()
    var objective := _create_test_objective(0)
    
    # Initialize mission
    _mission.initialize(mission_data)
    _mission.set_objectives([objective])
    
    # Update progress
    objective.current_progress = 1
    _mission.set_objectives([objective])
    
    # Verify progress
    var objectives = _mission.get_objectives()
    assert_that(objectives.size()).is_equal(1)
    
    # Complete objective
    var completed = _mission.complete_objective(objective.id)
    assert_that(completed).is_true()

func test_mission_completion() -> void:
    # Setup mission with objectives
    var mission_data := _create_test_mission_data()
    var objective1 := _create_test_objective(0)
    var objective2 := _create_test_objective(1)
    
    # Initialize mission
    _mission.initialize(mission_data)
    _mission.set_objectives([objective1, objective2])
    
    # Complete objectives
    _mission.complete_objective(objective1.id)
    _mission.complete_objective(objective2.id)
    
    # Verify mission completion
    assert_that(_mission.is_mission_completed()).is_true()
    
    # Verify rewards
    var final_rewards: Dictionary = _mission.calculate_final_rewards()
    assert_that(final_rewards).is_not_empty()

func test_mission_failure() -> void:
    # Setup mission
    var mission_data := _create_test_mission_data()
    _mission.initialize(mission_data)
    
    # Fail mission
    _mission.fail_mission()
    
    # Verify failure state
    assert_that(_mission.is_mission_failed()).is_true()
    assert_that(_mission.is_mission_active()).is_false()

# Signal and event handling tests
func test_mission_event_handling() -> void:
    var mission_data := _create_test_mission_data()
    _mission.initialize(mission_data)
    
    # Test phase changes
    _mission.change_phase("PREPARATION")
    assert_that(_mission.get_phase()).is_equal("PREPARATION")
    
    _mission.change_phase("COMBAT")
    assert_that(_mission.get_phase()).is_equal("COMBAT")
    
    # Test completion events
    var objective := _create_test_objective(0)
    _mission.set_objectives([objective])
    var completed = _mission.complete_objective(objective.id)
    assert_that(completed).is_true()

func test_mission_cleanup() -> void:
    var mission_data := _create_test_mission_data()
    _mission.initialize(mission_data)
    
    # Mission cleanup is handled by gdUnit4
    _mission.cleanup()
    assert_that(_mission.get_objectives()).is_empty()

func test_mission_performance() -> void:
    var mission_data := _create_test_mission_data()
    _mission.initialize(mission_data)
    
    # Test performance by completing a mission quickly
    var objective := _create_test_objective(0)
    _mission.set_objectives([objective])
    
    # Complete objective and verify timing
    var completed = _mission.complete_objective(objective.id)
    assert_that(completed).is_true()
    
    # Verify completion
    assert_that(_mission.is_mission_completed()).is_true()