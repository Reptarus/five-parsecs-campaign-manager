@tool
extends "res://tests/performance/base/perf_test_base.gd"

# Type-safe script references
const MissionScript: GDScript = preload("res://src/core/systems/Mission.gd")
const MissionGeneratorScript: GDScript = preload("res://src/core/systems/MissionGenerator.gd")
const GameEnumsScript: GDScript = preload("res://src/core/systems/GlobalEnums.gd")

# Test variables with explicit types
var _mission: Resource = null
var _generator: Node = null
var _tracked_missions: Array[Resource] = []

# Mission complexity thresholds
const MISSION_COMPLEXITY := {
    "simple": {
        "objectives": 1,
        "enemies": 5,
        "terrain_features": 5
    },
    "moderate": {
        "objectives": 3,
        "enemies": 10,
        "terrain_features": 10
    },
    "complex": {
        "objectives": 5,
        "enemies": 20,
        "terrain_features": 20
    }
}

# Performance thresholds for different mission complexities
const MISSION_THRESHOLDS := {
    "simple": {
        "average_fps": 55.0,
        "minimum_fps": 45.0,
        "memory_delta_kb": 256.0,
        "draw_calls_delta": 20
    },
    "moderate": {
        "average_fps": 45.0,
        "minimum_fps": 35.0,
        "memory_delta_kb": 512.0,
        "draw_calls_delta": 40
    },
    "complex": {
        "average_fps": 35.0,
        "minimum_fps": 25.0,
        "memory_delta_kb": 1024.0,
        "draw_calls_delta": 80
    }
}

func before_each() -> void:
    await super.before_each()
    
    # Initialize mission generator
    _generator = MissionGeneratorScript.new()
    if not _generator:
        push_error("Failed to create mission generator")
        return
    add_child_autofree(_generator)
    track_test_node(_generator)
    
    await stabilize_engine(STABILIZE_TIME)

func after_each() -> void:
    # Cleanup test resources
    for mission in _tracked_missions:
        if is_instance_valid(mission):
            mission.free()
    _tracked_missions.clear()
    
    if is_instance_valid(_generator):
        _generator.queue_free()
    _generator = null
    
    await super.after_each()

func test_simple_mission_performance() -> void:
    print_debug("Testing simple mission performance...")
    await _setup_mission("simple")
    
    var metrics := await measure_performance(
        func() -> void:
            TypeSafeMixin._safe_method_call_bool(_mission, "update_objectives", [])
            await get_tree().process_frame
    )
    
    verify_performance_metrics(metrics, MISSION_THRESHOLDS.simple)

func test_moderate_mission_performance() -> void:
    print_debug("Testing moderate mission performance...")
    await _setup_mission("moderate")
    
    var metrics := await measure_performance(
        func() -> void:
            TypeSafeMixin._safe_method_call_bool(_mission, "update_objectives", [])
            await get_tree().process_frame
    )
    
    verify_performance_metrics(metrics, MISSION_THRESHOLDS.moderate)

func test_complex_mission_performance() -> void:
    print_debug("Testing complex mission performance...")
    await _setup_mission("complex")
    
    var metrics := await measure_performance(
        func() -> void:
            TypeSafeMixin._safe_method_call_bool(_mission, "update_objectives", [])
            await get_tree().process_frame
    )
    
    verify_performance_metrics(metrics, MISSION_THRESHOLDS.complex)

func test_mission_memory_management() -> void:
    print_debug("Testing mission memory management...")
    
    var initial_memory := Performance.get_monitor(Performance.MEMORY_STATIC)
    
    # Test memory usage with missions of increasing complexity
    for complexity in MISSION_COMPLEXITY.keys():
        await _setup_mission(complexity)
        
        # Process mission updates
        for i in range(5):
            TypeSafeMixin._safe_method_call_bool(_mission, "update_objectives", [])
            await get_tree().process_frame
        
        # Cleanup mission
        if is_instance_valid(_mission):
            _mission.free()
        _mission = null
        await get_tree().process_frame
    
    var final_memory := Performance.get_monitor(Performance.MEMORY_STATIC)
    var memory_delta := (final_memory - initial_memory) / 1024.0 # KB
    
    assert_lt(memory_delta, PERFORMANCE_THRESHOLDS.memory.leak_threshold_kb,
        "Memory should be properly cleaned up after mission processing")

func test_mission_stress() -> void:
    print_debug("Running mission stress test...")
    
    # Setup moderate mission
    await _setup_mission("moderate")
    
    await stress_test(
        func() -> void:
            TypeSafeMixin._safe_method_call_bool(_mission, "update_objectives", [])
            
            # Randomly modify mission state
            if randf() < 0.2: # 20% chance each frame
                var modification := randi() % 3
                match modification:
                    0: # Add objective
                        TypeSafeMixin._safe_method_call_bool(_mission, "add_objective", [_create_test_objective()])
                    1: # Complete objective
                        TypeSafeMixin._safe_method_call_bool(_mission, "complete_random_objective", [])
                    2: # Modify terrain
                        TypeSafeMixin._safe_method_call_bool(_mission, "update_terrain", [])
            
            await get_tree().process_frame
    )

func test_mobile_mission_performance() -> void:
    if not _is_mobile:
        print_debug("Skipping mobile mission test on non-mobile platform")
        return
    
    print_debug("Testing mobile mission performance...")
    
    # Test under memory pressure
    await simulate_memory_pressure()
    
    # Setup simple mission (mobile optimized)
    await _setup_mission("simple")
    
    var metrics := await measure_performance(
        func() -> void:
            TypeSafeMixin._safe_method_call_bool(_mission, "update_objectives", [])
            await get_tree().process_frame
    )
    
    # Use mobile-specific thresholds
    var mobile_thresholds := {
        "average_fps": PERFORMANCE_THRESHOLDS.fps.mobile_target,
        "minimum_fps": PERFORMANCE_THRESHOLDS.fps.mobile_minimum,
        "memory_delta_kb": PERFORMANCE_THRESHOLDS.memory.mobile_max_delta_mb * 1024,
        "draw_calls_delta": PERFORMANCE_THRESHOLDS.gpu.max_draw_calls / 2
    }
    
    verify_performance_metrics(metrics, mobile_thresholds)

# Helper methods
func _setup_mission(complexity: String) -> void:
    var config: Dictionary = MISSION_COMPLEXITY[complexity] if MISSION_COMPLEXITY.has(complexity) else MISSION_COMPLEXITY.simple
    
    _mission = TypeSafeMixin._safe_method_call_resource(_generator, "generate_mission_with_type",
        [GameEnumsScript.MissionType.PATROL])
    if not _mission:
        push_error("Failed to generate mission")
        return
    
    # Configure mission based on complexity
    TypeSafeMixin._safe_method_call_bool(_mission, "set_objective_count", [config.objectives])
    TypeSafeMixin._safe_method_call_bool(_mission, "set_enemy_count", [config.enemies])
    TypeSafeMixin._safe_method_call_bool(_mission, "set_terrain_feature_count", [config.terrain_features])
    
    _tracked_missions.append(_mission)
    await stabilize_engine(STABILIZE_TIME)

func _create_test_objective() -> Dictionary:
    return {
        "type": GameEnumsScript.ObjectiveType.ELIMINATION,
        "target_count": 1,
        "completed": false,
        "description": "Test objective"
    } 