@tool
extends "res://tests/performance/base/perf_test_base.gd"

# Type-safe script references
const BattleSystemScript: GDScript = preload("res://src/core/battle/state/BattleStateMachine.gd")
# For accessing the renamed class
const BattleStateMachineClass = BattleSystemScript
const CharacterScript: GDScript = preload("res://src/core/character/Base/Character.gd")
const WeaponScript: GDScript = preload("res://src/core/systems/items/GameWeapon.gd")

# Test variables with explicit types
var _battle_system: Node = null
var _characters: Array[Node] = []
var _weapons: Array[Resource] = []

# Battle-specific thresholds
const BATTLE_THRESHOLDS := {
    "small_battle": {
        "average_fps": 45.0,
        "minimum_fps": 30.0,
        "memory_delta_kb": 512.0,
        "draw_calls_delta": 25
    },
    "medium_battle": {
        "average_fps": 40.0,
        "minimum_fps": 25.0,
        "memory_delta_kb": 1024.0,
        "draw_calls_delta": 50
    },
    "large_battle": {
        "average_fps": 35.0,
        "minimum_fps": 20.0,
        "memory_delta_kb": 2048.0,
        "draw_calls_delta": 100
    }
}

func before_each() -> void:
    await super.before_each()
    
    # Initialize battle system
    _battle_system = BattleStateMachineClass.new()
    if not _battle_system:
        push_error("Failed to create battle system")
        return
    add_child_autofree(_battle_system)
    track_test_node(_battle_system)
    
    await stabilize_engine(STABILIZE_TIME)

func after_each() -> void:
    # Cleanup test resources
    for character in _characters:
        if is_instance_valid(character):
            character.queue_free()
    _characters.clear()
    
    for weapon in _weapons:
        if is_instance_valid(weapon):
            weapon.free()
    _weapons.clear()
    
    if is_instance_valid(_battle_system):
        _battle_system.queue_free()
    _battle_system = null
    
    await super.after_each()

func test_small_battle_performance() -> void:
    print_debug("Testing small battle performance (5v5)...")
    await _setup_battle(5, 5)
    
    var metrics := await measure_performance(
        func() -> void:
            TypeSafeMixin._call_node_method_bool(_battle_system, "process_round", [])
            var tree = get_tree()
            if tree != null:
                await tree.process_frame
            else:
                await Engine.get_main_loop().process_frame
    )
    
    verify_performance_metrics(metrics, BATTLE_THRESHOLDS.small_battle)

func test_medium_battle_performance() -> void:
    print_debug("Testing medium battle performance (10v10)...")
    await _setup_battle(10, 10)
    
    var metrics := await measure_performance(
        func() -> void:
            TypeSafeMixin._call_node_method_bool(_battle_system, "process_round", [])
            var tree = get_tree()
            if tree != null:
                await tree.process_frame
            else:
                await Engine.get_main_loop().process_frame
    )
    
    verify_performance_metrics(metrics, BATTLE_THRESHOLDS.medium_battle)

func test_large_battle_performance() -> void:
    print_debug("Testing large battle performance (20v20)...")
    await _setup_battle(20, 20)
    
    var metrics := await measure_performance(
        func() -> void:
            TypeSafeMixin._call_node_method_bool(_battle_system, "process_round", [])
            var tree = get_tree()
            if tree != null:
                await tree.process_frame
            else:
                await Engine.get_main_loop().process_frame
    )
    
    verify_performance_metrics(metrics, BATTLE_THRESHOLDS.large_battle)

func test_battle_memory_management() -> void:
    print_debug("Testing battle memory management...")
    
    var initial_memory := Performance.get_monitor(Performance.MEMORY_STATIC)
    
    # Run multiple battles of increasing size
    for battle_size in [5, 10, 20]:
        await _setup_battle(battle_size, battle_size)
        
        # Run battle simulation
        for i in range(5):
            TypeSafeMixin._call_node_method_bool(_battle_system, "process_round", [])
            var tree = get_tree()
            if tree != null:
                await tree.process_frame
            else:
                await Engine.get_main_loop().process_frame
        
        # Cleanup after battle
        await after_each()
        var tree = get_tree()
        if tree != null:
            await tree.process_frame
        else:
            await Engine.get_main_loop().process_frame
    
    var final_memory := Performance.get_monitor(Performance.MEMORY_STATIC)
    var memory_delta := (final_memory - initial_memory) / 1024.0 # KB
    
    assert_lt(memory_delta, PERFORMANCE_THRESHOLDS.memory.leak_threshold_kb,
        "Memory should be properly cleaned up after battles")

func test_battle_stress() -> void:
    print_debug("Running battle system stress test...")
    
    # Setup medium-sized battle
    await _setup_battle(10, 10)
    
    await stress_test(
        func() -> void:
            TypeSafeMixin._call_node_method_bool(_battle_system, "process_round", [])
            
            # Randomly add/remove combatants
            if randf() < 0.2: # 20% chance each frame
                var side := randi() % 2
                if side == 0:
                    await _add_character_to_battle(true) # Add to player side
                else:
                    await _add_character_to_battle(false) # Add to enemy side
            
            var tree = get_tree()
            if tree != null:
                await tree.process_frame
            else:
                await Engine.get_main_loop().process_frame
    )

func test_mobile_battle_performance() -> void:
    if not _is_mobile:
        print_debug("Skipping mobile battle test on non-mobile platform")
        return
    
    print_debug("Testing mobile battle performance...")
    
    # Test under memory pressure
    await simulate_memory_pressure()
    
    # Setup small battle (mobile optimized)
    await _setup_battle(3, 3)
    
    var metrics := await measure_performance(
        func() -> void:
            TypeSafeMixin._call_node_method_bool(_battle_system, "process_round", [])
            var tree = get_tree()
            if tree != null:
                await tree.process_frame
            else:
                await Engine.get_main_loop().process_frame
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
func _setup_battle(player_count: int, enemy_count: int) -> void:
    # Create player characters
    for i in range(player_count):
        await _add_character_to_battle(true)
    
    # Create enemy characters
    for i in range(enemy_count):
        await _add_character_to_battle(false)
    
    await stabilize_engine(STABILIZE_TIME)

func _add_character_to_battle(is_player: bool) -> void:
    var character: Node = CharacterScript.new()
    if not character:
        push_error("Failed to create character")
        return
    
    # Setup character
    character.name = "Character_%d" % _characters.size()
    TypeSafeMixin._call_node_method_bool(character, "set_is_player", [is_player])
    
    # Add weapon
    var weapon: Resource = WeaponScript.new()
    if not weapon:
        push_error("Failed to create weapon")
        return
    TypeSafeMixin._call_node_method_bool(character, "equip_weapon", [weapon])
    
    # Add to battle
    add_child_autofree(character)
    track_test_node(character)
    _characters.append(character)
    _weapons.append(weapon)
    
    TypeSafeMixin._call_node_method_bool(_battle_system, "add_character", [character])
    var tree = get_tree()
    if tree != null:
        await tree.process_frame
    else:
        await Engine.get_main_loop().process_frame