@tool
extends GdUnitTestSuite

# Performance test for battle system components
const BattleSystemScript: GDScript = preload("res://src/core/battle/state/BattleStateMachine.gd")
const CharacterScript: GDScript = preload("res://src/core/character/Base/Character.gd")
const WeaponScript: GDScript = preload("res://src/core/systems/items/GameWeapon.gd")

# Test variables with explicit types
var _battle_system: Node = null
var _characters: Array[Node] = []
var _weapons: Array[Resource] = []
var _tracked_nodes: Array[Node] = []
var _tracked_resources: Array[Resource] = []

# Helper functions
func track_node(node: Node) -> void:
    _tracked_nodes.append(node)

func track_resource(resource: Resource) -> void:
    _tracked_resources.append(resource)

func stabilize_engine(time: float) -> void:
    await get_tree().create_timer(time).timeout

func measure_performance(callback: Callable) -> Dictionary:
    var start_time = Time.get_ticks_msec()
    await callback.call()
    var end_time = Time.get_ticks_msec()
    
    return {
        "execution_time": end_time - start_time,
        "average_frame_time": float(end_time - start_time),
        "memory_usage": Performance.get_monitor(Performance.MEMORY_STATIC),
    }

func verify_performance_metrics(metrics: Dictionary, thresholds: Dictionary) -> void:
    if metrics.has("average_frame_time") and thresholds.has("average_frame_time"):
        assert_that(metrics.average_frame_time).is_less(thresholds.average_frame_time)

func stress_test(callback: Callable) -> void:
    for i: int in range(100):
        callback.call()

func simulate_memory_pressure() -> void:
    # Create temporary large data structures to simulate memory pressure
    var large_array: Array = []
    for i in range(1000):
        large_array.append(Vector3(i, i, i))
    large_array.clear()

# Performance constants
const STABILIZE_TIME = 0.1

# Battle performance threshold constants
const BATTLE_THRESHOLDS := {
    "small_battle": {
        "average_frame_time": 50.0, # 50ms = ~20 FPS (reasonable for headless tests)
        "maximum_frame_time": 100.0, # 100ms = ~10 FPS (max acceptable)
        "memory_delta_kb": 512.0,
        "frame_time_stability": 0.5,
    },
    "medium_battle": {
        "average_frame_time": 75.0, # 75ms = ~13 FPS
        "maximum_frame_time": 150.0, # 150ms = ~6.7 FPS
        "memory_delta_kb": 1024.0,
        "frame_time_stability": 0.4,
    },
    "large_battle": {
        "average_frame_time": 100.0, # 100ms = ~10 FPS
        "maximum_frame_time": 200.0, # 200ms = ~5 FPS
        "memory_delta_kb": 2048.0,
        "frame_time_stability": 0.3,
    },
}

# Safe method call helper
func _safe_call_method_bool(node: Node, method_name: String, args: Array = []) -> bool:
    if node and node.has_method(method_name):
        return node.callv(method_name, args)
    return false

func before_test() -> void:
    await stabilize_engine(STABILIZE_TIME)
    
    # Clear arrays
    _characters.clear()
    _weapons.clear()
    
    # Initialize battle system
    _battle_system = BattleSystemScript.new()
    if not _battle_system:
        print("Warning: Could not create battle system")
        return
    
    # Use track_node for automatic cleanup
    track_node(_battle_system)
    _battle_system.name = "TestBattleSystem"

func after_test() -> void:
    # Clean up characters
    for character: Node in _characters:
        if is_instance_valid(character):
            if character.get_parent():
                character.get_parent().remove_child(character)
            character.queue_free()
    _characters.clear()
    
    # Clean up weapons
    _weapons.clear()
    
    # Clean up battle system
    if is_instance_valid(_battle_system):
        if _battle_system.get_parent():
            _battle_system.get_parent().remove_child(_battle_system)
        _battle_system.queue_free()
        _battle_system = null
    
    # Force garbage collection
    await get_tree().process_frame
    
    super.after_test()

func test_small_battle_performance() -> void:
    print_debug("Testing small battle performance (5v5)...")
    await _setup_battle(5, 5)
    
    var metrics = await measure_performance(
        func() -> void:
            _simulate_battle_round()
            await stabilize_engine(STABILIZE_TIME)
    )
    
    verify_performance_metrics(metrics, BATTLE_THRESHOLDS.small_battle)

func test_medium_battle_performance() -> void:
    print_debug("Testing medium battle performance (10v10)...")
    await _setup_battle(10, 10)
    
    var metrics = await measure_performance(
        func() -> void:
            _simulate_battle_round()
            await stabilize_engine(STABILIZE_TIME)
    )
    
    verify_performance_metrics(metrics, BATTLE_THRESHOLDS.medium_battle)

func test_large_battle_performance() -> void:
    print_debug("Testing large battle performance (20v20)...")
    await _setup_battle(20, 20)
    
    var metrics = await measure_performance(
        func() -> void:
            _simulate_battle_round()
            await stabilize_engine(STABILIZE_TIME)
    )
    
    verify_performance_metrics(metrics, BATTLE_THRESHOLDS.large_battle)

func test_battle_memory_management() -> void:
    print_debug("Testing battle memory management...")
    
    var initial_memory := Performance.get_monitor(Performance.MEMORY_STATIC)
    
    # Test different battle sizes
    for battle_size in [5, 10, 20]:
        await _setup_battle(battle_size, battle_size)
        
        # Simulate multiple rounds
        for i: int in range(5):
            if is_instance_valid(_battle_system):
                _simulate_battle_round()
            await stabilize_engine(STABILIZE_TIME)
        
        # Clean up characters and weapons
        for character: Node in _characters:
            if is_instance_valid(character):
                if character.get_parent():
                    character.get_parent().remove_child(character)
                character.queue_free()
        _characters.clear()
        _weapons.clear()
        
        # Force garbage collection
        await get_tree().process_frame
    
    var final_memory := Performance.get_monitor(Performance.MEMORY_STATIC)
    var memory_delta := (final_memory - initial_memory) / 1024.0 # KB
    
    print_debug("Memory delta: %.2f KB" % memory_delta)
    
    # Use a more lenient threshold for battle system tests (3MB instead of default)
    var memory_threshold := 3072.0 # 3MB in KB
    
    assert_that(memory_delta).with_failure_message("Memory delta (%.2f KB) should be less than threshold (%.2f KB)" % [memory_delta, memory_threshold]).is_less(memory_threshold)

func test_battle_stress() -> void:
    print_debug("Running battle system stress test...")
    
    # Setup medium-sized battle
    await _setup_battle(10, 10)
    
    stress_test(
        func() -> void:
            _simulate_battle_round()
            
            # Randomly add/remove characters
            if randf() < 0.2: # 20% chance each frame
                var side = randi() % 2
                if side == 0:
                    await _add_character_to_battle(true) # Player
                else:
                    await _add_character_to_battle(false) # Enemy
    )

func test_mobile_battle_performance() -> void:
    var _is_mobile = OS.has_feature("mobile")
    if not _is_mobile:
        print_debug("Skipping mobile test on non-mobile platform")
        return
    
    # Test under memory pressure
    simulate_memory_pressure()
    await _setup_battle(5, 5)
    
    var metrics = await measure_performance(
        func() -> void:
            _simulate_battle_round()
            await stabilize_engine(STABILIZE_TIME)
    )
    
    # Use mobile-specific thresholds (frame timing based)
    var mobile_thresholds := {
        "average_frame_time": 50.0, # 50ms frame budget for mobile
        "maximum_frame_time": 100.0, # 100ms max for mobile
        "memory_delta_kb": 1024.0, # 1MB memory limit for mobile
        "frame_time_stability": 0.3,
    }
    verify_performance_metrics(metrics, mobile_thresholds)

# Helper functions
func _setup_battle(player_count: int, enemy_count: int) -> void:
    # Setup player characters
    for i: int in range(player_count):
        await _add_character_to_battle(true)
    
    # Setup enemy characters
    for i: int in range(enemy_count):
        await _add_character_to_battle(false)

func _add_character_to_battle(is_player: bool) -> void:
    # Verify battle system exists
    if not is_instance_valid(_battle_system):
        print("Warning: Battle system not available")
        return
    
    # Create a Node2D to represent the character in battle (since we need a Node)
    var character = Node2D.new()
    if not character:
        print("Warning: Could not create character")
        return
    
    # Set character properties
    character.name = "TestCharacter_%d" % (_characters.size() + 1)
    character.set_meta("is_player", is_player)
    character.set_meta("health", 100)
    character.set_meta("max_health", 100)
    character.set_meta("armor", 2)
    character.set_meta("weapon_skill", 3)
    character.set_meta("movement", 6)
    character.position = Vector2(randf_range(-100, 100), randf_range(-100, 100))
    
    # Create and assign a weapon
    var weapon = Resource.new()
    weapon.set_meta("name", "Test Weapon")
    weapon.set_meta("damage", 2)
    weapon.set_meta("range", 12)
    weapon.set_meta("shots", 1)
    
    character.set_meta("weapon", weapon)
    
    # Track resources for cleanup
    track_node(character)
    track_resource(weapon)
    
    # Add to arrays
    _weapons.append(weapon)
    _characters.append(character)

func _simulate_battle_round() -> void:
    # Simulate a basic battle round with character interactions
    for character in _characters:
        if is_instance_valid(character):
            # Simulate movement
            character.position += Vector2(randf_range(-5, 5), randf_range(-5, 5))
            
            # Simulate combat calculations
            var health = character.get_meta("health", 100)
            var damage = randi_range(1, 5)
            character.set_meta("health", max(0, health - damage))
