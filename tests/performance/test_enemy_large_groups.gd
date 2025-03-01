@tool
extends "res://tests/performance/base/perf_test_base.gd"

# Type-safe script references
const EnemyScript: GDScript = preload("res://src/core/battle/BattleCharacter.gd")
const EnemyDataScript: GDScript = preload("res://src/core/rivals/EnemyData.gd")
const UnifiedAISystemScript: GDScript = preload("res://src/core/systems/UnifiedAISystem.gd")
const BattlefieldManagerScript: GDScript = preload("res://src/core/battle/BattlefieldManager.gd")

# Test variables with explicit types
var _enemy_group: Array[Node] = []
var _ai_system: Node = null
var _battlefield_manager: Node = null

# Group size thresholds
const GROUP_SIZES := {
    "small": 10,
    "medium": 25,
    "large": 50,
    "massive": 100
}

# Performance thresholds for different group sizes
const GROUP_THRESHOLDS := {
    "small": {
        "average_fps": 55.0,
        "minimum_fps": 45.0,
        "memory_delta_kb": 256.0,
        "draw_calls_delta": 20
    },
    "medium": {
        "average_fps": 45.0,
        "minimum_fps": 35.0,
        "memory_delta_kb": 512.0,
        "draw_calls_delta": 40
    },
    "large": {
        "average_fps": 35.0,
        "minimum_fps": 25.0,
        "memory_delta_kb": 1024.0,
        "draw_calls_delta": 80
    },
    "massive": {
        "average_fps": 30.0,
        "minimum_fps": 20.0,
        "memory_delta_kb": 2048.0,
        "draw_calls_delta": 160
    }
}

func before_each() -> void:
    await super.before_each()
    
    # Initialize AI system
    _ai_system = UnifiedAISystemScript.new()
    if not _ai_system:
        push_error("Failed to create AI system")
        return
    add_child_autofree(_ai_system)
    track_test_node(_ai_system)
    
    # Initialize battlefield manager
    _battlefield_manager = BattlefieldManagerScript.new()
    if not _battlefield_manager:
        push_error("Failed to create battlefield manager")
        return
    add_child_autofree(_battlefield_manager)
    track_test_node(_battlefield_manager)
    
    await stabilize_engine(STABILIZE_TIME)

func after_each() -> void:
    # Cleanup test resources
    for enemy in _enemy_group:
        if is_instance_valid(enemy):
            enemy.queue_free()
    _enemy_group.clear()
    
    if is_instance_valid(_ai_system):
        _ai_system.queue_free()
    _ai_system = null
    
    if is_instance_valid(_battlefield_manager):
        _battlefield_manager.queue_free()
    _battlefield_manager = null
    
    await super.after_each()

func test_small_group_performance() -> void:
    print_debug("Testing small enemy group performance...")
    await _setup_enemy_group("small")
    
    var metrics := await measure_performance(
        func() -> void:
            TypeSafeMixin._call_node_method_bool(_ai_system, "process_group", [_enemy_group])
            await get_tree().process_frame
    )
    
    verify_performance_metrics(metrics, GROUP_THRESHOLDS.small)

func test_medium_group_performance() -> void:
    print_debug("Testing medium enemy group performance...")
    await _setup_enemy_group("medium")
    
    var metrics := await measure_performance(
        func() -> void:
            TypeSafeMixin._call_node_method_bool(_ai_system, "process_group", [_enemy_group])
            await get_tree().process_frame
    )
    
    verify_performance_metrics(metrics, GROUP_THRESHOLDS.medium)

func test_large_group_performance() -> void:
    print_debug("Testing large enemy group performance...")
    await _setup_enemy_group("large")
    
    var metrics := await measure_performance(
        func() -> void:
            TypeSafeMixin._call_node_method_bool(_ai_system, "process_group", [_enemy_group])
            await get_tree().process_frame
    )
    
    verify_performance_metrics(metrics, GROUP_THRESHOLDS.large)

func test_massive_group_performance() -> void:
    if _is_mobile:
        print_debug("Skipping massive group test on mobile platform")
        return
    
    print_debug("Testing massive enemy group performance...")
    await _setup_enemy_group("massive")
    
    var metrics := await measure_performance(
        func() -> void:
            TypeSafeMixin._call_node_method_bool(_ai_system, "process_group", [_enemy_group])
            await get_tree().process_frame
    )
    
    verify_performance_metrics(metrics, GROUP_THRESHOLDS.massive)

func test_group_memory_management() -> void:
    print_debug("Testing enemy group memory management...")
    
    var initial_memory := Performance.get_monitor(Performance.MEMORY_STATIC)
    
    # Test memory usage with increasing group sizes
    for size in GROUP_SIZES.keys():
        await _setup_enemy_group(size)
        
        # Process group actions
        for i in range(5):
            TypeSafeMixin._call_node_method_bool(_ai_system, "process_group", [_enemy_group])
            await get_tree().process_frame
        
        # Cleanup group
        for enemy in _enemy_group:
            if is_instance_valid(enemy):
                enemy.queue_free()
        _enemy_group.clear()
        await get_tree().process_frame
    
    var final_memory := Performance.get_monitor(Performance.MEMORY_STATIC)
    var memory_delta := (final_memory - initial_memory) / 1024.0 # KB
    
    assert_lt(memory_delta, PERFORMANCE_THRESHOLDS.memory.leak_threshold_kb,
        "Memory should be properly cleaned up after group processing")

func test_group_stress() -> void:
    print_debug("Running enemy group stress test...")
    
    # Setup medium-sized group
    await _setup_enemy_group("medium")
    
    await stress_test(
        func() -> void:
            TypeSafeMixin._call_node_method_bool(_ai_system, "process_group", [_enemy_group])
            
            # Randomly add/remove enemies
            if randf() < 0.2: # 20% chance each frame
                if _enemy_group.size() < GROUP_SIZES.large:
                    await _add_enemy_to_group()
                else:
                    _remove_random_enemy()
            
            await get_tree().process_frame
    )

func test_mobile_group_performance() -> void:
    if not _is_mobile:
        print_debug("Skipping mobile group test on non-mobile platform")
        return
    
    print_debug("Testing mobile enemy group performance...")
    
    # Test under memory pressure
    await simulate_memory_pressure()
    
    # Setup small group (mobile optimized)
    await _setup_enemy_group("small")
    
    var metrics := await measure_performance(
        func() -> void:
            TypeSafeMixin._call_node_method_bool(_ai_system, "process_group", [_enemy_group])
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
func _setup_enemy_group(size_key: String) -> void:
    var group_size: int = GROUP_SIZES[size_key] if GROUP_SIZES.has(size_key) else GROUP_SIZES.small
    
    for i in range(group_size):
        await _add_enemy_to_group()
    
    await stabilize_engine(STABILIZE_TIME)

func _add_enemy_to_group() -> void:
    var enemy: Node = EnemyScript.new()
    if not enemy:
        push_error("Failed to create enemy")
        return
    
    # Setup enemy
    enemy.name = "Enemy_%d" % _enemy_group.size()
    
    # Add to group
    add_child_autofree(enemy)
    track_test_node(enemy)
    _enemy_group.append(enemy)
    
    await get_tree().process_frame

func _remove_random_enemy() -> void:
    if _enemy_group.is_empty():
        return
    
    var index: int = randi() % _enemy_group.size()
    var enemy: Node = _enemy_group[index]
    if is_instance_valid(enemy):
        enemy.queue_free()
    _enemy_group.remove_at(index)