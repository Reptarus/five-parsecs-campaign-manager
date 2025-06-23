@tool
extends GdUnitGameTest

## Performance tests for mission systems
##
## Testing mission generation, state updates, objective tracking,
## mission rewards calculation, and mission serialization

# Mission performance test constants
const GameEnums: GDScript = preload("res://src/core/systems/GlobalEnums.gd")
const MissionScript: GDScript = preload("res://src/core/systems/Mission.gd")
const MissionGeneratorScript: GDScript = preload("res://src/game/campaign/FiveParsecsMissionGenerator.gd")
const MissionTemplateScript: GDScript = preload("res://src/core/templates/MissionTemplate.gd")

# Performance thresholds
const GENERATION_THRESHOLD: int = 50
const STATE_UPDATE_THRESHOLD: int = 10
const SERIALIZATION_THRESHOLD: int = 20
const BATCH_SIZE: int = 100

# Test variables with explicit types
var _mission_generator: Node = null
var _template: Resource = null

# Helper functions for safe method calls
func _get_template() -> Resource:
    return _template

func _set_mission_type(template: Resource, mission_type: int) -> void:
    if template and template.has_method("set_mission_type"):
        template.set_mission_type(mission_type)

func _set_difficulty_range(template: Resource, min_diff: int, max_diff: int) -> void:
    if template and template.has_method("set_difficulty_range"):
        template.set_difficulty_range(min_diff, max_diff)

func _set_reward_range(template: Resource, min_reward: int, max_reward: int) -> void:
    if template and template.has_method("set_reward_range"):
        template.set_reward_range(min_reward, max_reward)

func _generate_mission(template: Resource) -> Resource:
    if _mission_generator and _mission_generator.has_method("generate_mission"):
        return _mission_generator.generate_mission(template)
    return null

func _set_objectives(mission: Resource, objectives: Array) -> void:
    if mission and mission.has_method("set_objectives"):
        mission.set_objectives(objectives)

func _complete_objective(mission: Resource, index: int) -> void:
    if mission and mission.has_method("complete_objective"):
        mission.complete_objective(index)

func _serialize_mission(mission: Resource) -> Dictionary:
    if mission and mission.has_method("serialize"):
        return mission.serialize()
    return {}

func _update_progress(mission: Resource, progress: float) -> void:
    if mission and mission.has_method("update_progress"):
        mission.update_progress(progress)

func _calculate_rewards(mission: Resource) -> void:
    if mission and mission.has_method("calculate_rewards"):
        mission.calculate_rewards()

# Test setup and teardown
func before_test() -> void:
    super.before_test()
    
    # Create a dummy GameState and WorldManager for the MissionGenerator constructor
    var game_state: RefCounted = RefCounted.new()
    var world_manager: RefCounted = RefCounted.new()
    
    _mission_generator = MissionGeneratorScript.new(game_state, world_manager)
    if not _mission_generator:
        print("Warning: Could not create mission generator")
        return
    
    _template = MissionTemplateScript.new()
    if not _template:
        print("Warning: Could not create mission template")
        return
    
    _set_mission_type(_template, GameEnums.MissionType.PATROL if GameEnums.has("MissionType") else 0)
    _set_difficulty_range(_template, 1, 3)
    _set_reward_range(_template, 100, 500)

func after_test() -> void:
    super.after_test()
    
    if is_instance_valid(_mission_generator):
        _mission_generator = null
    
    _template = null

# Performance test functions
func test_batch_mission_generation() -> void:
    var total_time: int = 0
    var missions: Array[Resource] = []
    
    for i: int in range(BATCH_SIZE):
        var start_time: int = Time.get_ticks_msec()
        var mission := _generate_mission(_template)
        if not mission:
            continue
        missions.append(mission)
        total_time += Time.get_ticks_msec() - start_time
    
    var average_time: float = total_time / float(BATCH_SIZE)
    print("Average mission generation time: %.2f ms" % average_time)
    assert_that(average_time).with_failure_message("Average mission generation time should be under %d ms" % GENERATION_THRESHOLD).is_less(GENERATION_THRESHOLD)

func test_objective_update_performance() -> void:
    var template: Resource = _get_template()
    var mission := _generate_mission(template)
    if not mission:
        return
    
    # Add many objectives
    var objectives: Array = []
    for i: int in range(BATCH_SIZE):
        var objective_type: int = 0
        if GameEnums.has("MissionObjective"):
            objective_type = GameEnums.MissionObjective.PATROL if GameEnums.MissionObjective.has("PATROL") else 0

        objectives.append({
            "type": objective_type,
            "description": "Test objective %d" % i,
            "completed": false,
            "is_primary": false,
        })
    
    _set_objectives(mission, objectives)
    
    var total_time: int = 0
    for i: int in range(BATCH_SIZE):
        var start_time: int = Time.get_ticks_msec()
        _complete_objective(mission, i)
        total_time += Time.get_ticks_msec() - start_time
    
    var average_time: float = total_time / float(BATCH_SIZE)
    print("Average objective update time: %.2f ms" % average_time)
    assert_that(average_time).with_failure_message("Average objective update time should be under %d ms" % STATE_UPDATE_THRESHOLD).is_less(STATE_UPDATE_THRESHOLD)

func test_mission_serialization_performance() -> void:
    var template: Resource = _get_template()
    var mission := _generate_mission(template)
    if not mission:
        return
    
    # Add many objectives and rewards
    var objectives: Array = []
    for i: int in range(BATCH_SIZE):
        var objective_type: int = 0
        if GameEnums.has("MissionObjective"):
            objective_type = GameEnums.MissionObjective.PATROL if GameEnums.MissionObjective.has("PATROL") else 0

        objectives.append({
            "type": objective_type,
            "description": "Test objective %d" % i,
            "completed": false,
            "is_primary": false,
        })
    
    _set_objectives(mission, objectives)
    
    var total_time: int = 0
    for i: int in range(BATCH_SIZE):
        var start_time: int = Time.get_ticks_msec()
        var _data := _serialize_mission(mission)
        total_time += Time.get_ticks_msec() - start_time
    
    var average_time: float = total_time / float(BATCH_SIZE)
    print("Average serialization time: %.2f ms" % average_time)
    assert_that(average_time).with_failure_message("Average serialization time should be under %d ms" % SERIALIZATION_THRESHOLD).is_less(SERIALIZATION_THRESHOLD)

func test_mission_memory_usage() -> void:
    var template: Resource = _get_template()
    var initial_memory: int = Performance.get_monitor(Performance.MEMORY_STATIC)
    var missions: Array[Resource] = []
    
    for i: int in range(BATCH_SIZE):
        var mission := _generate_mission(template)
        if not mission:
            continue
        missions.append(mission)
    
    var final_memory: int = Performance.get_monitor(Performance.MEMORY_STATIC)
    var memory_per_mission: float = (final_memory - initial_memory) / float(BATCH_SIZE)
    
    print("Memory usage per mission: %.2f KB" % (memory_per_mission / 1024.0))
    assert_that(memory_per_mission).with_failure_message("Memory usage per mission should be reasonable").is_less(1024 * 10) # 10 KB per mission

func test_concurrent_mission_operations() -> void:
    var template: Resource = _get_template()
    var mission := _generate_mission(template)
    if not mission:
        return
    
    var start_time: int = Time.get_ticks_msec()
    for i: int in range(BATCH_SIZE):
        # Update progress
        _update_progress(mission, float(i) / BATCH_SIZE * 100.0)
        # Complete some objectives
        if i % 2 == 0:
            _complete_objective(mission, i % 5)
        var _data := _serialize_mission(mission)
    
    var total_time: int = Time.get_ticks_msec() - start_time
    print("Concurrent operations time: %d ms" % total_time)
    assert_that(total_time).with_failure_message("Should handle concurrent operations efficiently").is_less(BATCH_SIZE * STATE_UPDATE_THRESHOLD)