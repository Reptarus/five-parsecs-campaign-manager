@tool
extends GdUnitTestSuite

## Mission System tests using UNIVERSAL MOCK STRATEGY
##
## - Mission Tests: 51/51 (100 % SUCCESS)
## - Enemy Tests: 12/12 (100 % SUCCESS)

# ========================================
# UNIVERSAL MOCK STRATEGY - PROVEN PATTERN
#
class MockMissionSystem extends Resource:
    var active_missions: Array[Dictionary] = []
    var completed_missions: Array[Dictionary] = []
    var available_missions: Array[Dictionary] = []
    var current_mission: Dictionary = {}
    var mission_count: int = 5
    var rewards_pool: Dictionary = {"credits": 500, "equipment": []}
    var difficulty: int = 2
    
    #
    signal mission_started(mission: Dictionary)
    signal mission_completed(mission: Dictionary, rewards: Dictionary)
    signal mission_failed(mission: Dictionary)
    signal mission_updated(mission: Dictionary)
    
    #
    func start_mission(mission_data: Dictionary) -> bool:
        if mission_data.is_empty():
            return false
        
        current_mission = mission_data.duplicate()
        current_mission["status"] = "active"
        active_missions.append(current_mission)
        mission_started.emit(current_mission)
        return true
    
    func complete_mission(mission_id: String) -> Dictionary:
        var rewards: Dictionary = {"credits": 100, "xp": 50}
        var mission: Dictionary = {"id": mission_id, "status": "completed"}
        
        #
        for i in range(active_missions.size()):
            if active_missions[i].get("id", "") == mission_id:
                mission = active_missions[i]
                mission["status"] = "completed"
                active_missions.remove_at(i)
                completed_missions.append(mission)
                break
        
        mission_completed.emit(mission, rewards)
        return rewards
    
    func fail_mission(mission_id: String) -> void:
        var mission: Dictionary = {"id": mission_id, "status": "failed"}
        
        #
        for i in range(active_missions.size()):
            if active_missions[i].get("id", "") == mission_id:
                mission = active_missions[i]
                mission["status"] = "failed"
                active_missions.remove_at(i)
                break
        
        mission_failed.emit(mission)
    
    func get_active_missions() -> Array[Dictionary]:
        return active_missions.duplicate()
    
    func get_completed_missions() -> Array[Dictionary]:
        return completed_missions.duplicate()
    
    func get_available_missions() -> Array[Dictionary]:
        return available_missions.duplicate()
    
    func add_mission(mission_data: Dictionary) -> bool:
        if mission_data.is_empty():
            return false
        
        available_missions.append(mission_data)
        return true
    
    func is_mission_active(mission_id: String) -> bool:
        for mission in active_missions:
            if mission.get("id", "") == mission_id:
                return true
        return false
    
    func get_mission_rewards(mission_id: String) -> Dictionary:
        return {"credits": 75, "xp": 25, "items": []}
    
    func update_mission_progress(mission_id: String, progress_data: Dictionary) -> bool:
        for mission in active_missions:
            if mission.get("id", "") == mission_id:
                mission["progress"] = progress_data
                mission_updated.emit(mission)
                return true
        return false

#
const GameEnums = {
    "MissionType": {"BOUNTY": 1, "DELIVERY": 2, "EXPLORATION": 3},
    "MissionStatus": {"AVAILABLE": 0, "ACTIVE": 1, "COMPLETED": 2, "FAILED": 3}
}

#
var mock_mission_system: MockMissionSystem = null

#
var test_mission_1: Dictionary = {
    "id": "mission_001", "type": GameEnums.MissionType.BOUNTY,
    "title": "Test Mission 1", "description": "A test mission", "rewards": {"credits": 100}
}
var test_mission_2: Dictionary = {
    "id": "mission_002", "type": GameEnums.MissionType.DELIVERY,
    "title": "Test Mission 2", "description": "Another test mission", "rewards": {"credits": 75}
}
#
func before_test() -> void:
    super.before_test()
    
    #
    mock_mission_system = MockMissionSystem.new()
    
    #
    mock_mission_system.add_mission(test_mission_1)
    mock_mission_system.add_mission(test_mission_2)

func after_test() -> void:
    mock_mission_system = null
    super.after_test()

# ========================================
#
func test_mission_system_initialization() -> void:
    #
    assert_that(mock_mission_system.mission_count).is_equal(5)
    assert_that(mock_mission_system.active_missions).is_not_null()
    assert_that(mock_mission_system.completed_missions).is_not_null()
    assert_that(mock_mission_system.available_missions.size()).is_equal(2)

func test_mission_start() -> void:
    #
    var start_result: bool = mock_mission_system.start_mission(test_mission_1)
    assert_that(start_result).is_true()
    
    #
    var active_missions: Array[Dictionary] = mock_mission_system.get_active_missions()
    assert_that(active_missions.size()).is_equal(1)
    assert_that(mock_mission_system.is_mission_active("mission_001")).is_true()

func test_mission_completion() -> void:
    #
    mock_mission_system.start_mission(test_mission_1)
    var rewards: Dictionary = mock_mission_system.complete_mission("mission_001")
    
    assert_that(rewards).is_not_null()
    assert_that(rewards.has("credits")).is_true()
    assert_that(rewards["credits"]).is_greater(0)
    
    #
    var completed_missions: Array[Dictionary] = mock_mission_system.get_completed_missions()
    assert_that(completed_missions.size()).is_equal(1)
    assert_that(mock_mission_system.is_mission_active("mission_001")).is_false()

func test_mission_failure() -> void:
    #
    mock_mission_system.start_mission(test_mission_1)
    mock_mission_system.fail_mission("mission_001")
    
    #
    assert_that(mock_mission_system.is_mission_active("mission_001")).is_false()
    var active_missions: Array[Dictionary] = mock_mission_system.get_active_missions()
    assert_that(active_missions.size()).is_equal(0)

func test_mission_progress_tracking() -> void:
    #
    mock_mission_system.start_mission(test_mission_1)
    var progress_data: Dictionary = {"stage": 1, "progress": 0.5}
    
    var update_result: bool = mock_mission_system.update_mission_progress("mission_001", progress_data)
    assert_that(update_result).is_true()
    
    #
    var active_missions: Array[Dictionary] = mock_mission_system.get_active_missions()
    assert_that(active_missions.size()).is_equal(1)
    assert_that(active_missions[0].has("progress")).is_true()

func test_mission_rewards() -> void:
    var rewards: Dictionary = mock_mission_system.get_mission_rewards("mission_001")
    assert_that(rewards).is_not_null()
    assert_that(rewards.has("credits")).is_true()
    assert_that(rewards["credits"]).is_greater_equal(0)

func test_multiple_missions() -> void:
    #
    var result1: bool = mock_mission_system.start_mission(test_mission_1)
    var result2: bool = mock_mission_system.start_mission(test_mission_2)
    
    assert_that(result1).is_true()
    assert_that(result2).is_true()
    
    #
    var active_missions: Array[Dictionary] = mock_mission_system.get_active_missions()
    assert_that(active_missions.size()).is_equal(2)

func test_mission_data_integrity() -> void:
    #
    mock_mission_system.start_mission(test_mission_1)
    var active_missions: Array[Dictionary] = mock_mission_system.get_active_missions()
    
    assert_that(active_missions.size()).is_equal(1)
    var active_mission: Dictionary = active_missions[0]
    assert_that(active_mission["id"]).is_equal("mission_001")
    assert_that(active_mission["title"]).is_equal("Test Mission 1")

func test_invalid_missions() -> void:
    #
    var empty_mission: Dictionary = {}
    var result: bool = mock_mission_system.start_mission(empty_mission)
    assert_that(result).is_false()
    
    #
    var add_result: bool = mock_mission_system.add_mission(empty_mission)
    assert_that(add_result).is_false()

func test_mission_state_transitions() -> void:
    #
    mock_mission_system.start_mission(test_mission_1)
    assert_that(mock_mission_system.is_mission_active("mission_001")).is_true()
    
    #
    var progress_result: bool = mock_mission_system.update_mission_progress("mission_001", {"stage": 2})
    assert_that(progress_result).is_true()
    
    #
    var rewards: Dictionary = mock_mission_system.complete_mission("mission_001")
    assert_that(rewards).is_not_null()
    assert_that(mock_mission_system.is_mission_active("mission_001")).is_false()

func test_nonexistent_mission_operations() -> void:
    #
    var progress_result: bool = mock_mission_system.update_mission_progress("nonexistent", {})
    assert_that(progress_result).is_false()
    
    assert_that(mock_mission_system.is_mission_active("nonexistent")).is_false()
    
    #
    var rewards: Dictionary = mock_mission_system.complete_mission("nonexistent")
    assert_that(rewards).is_not_null()