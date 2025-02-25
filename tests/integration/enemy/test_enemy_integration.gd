@tool
extends "res://tests/fixtures/base/game_test.gd"

# Type-safe script references
const Enemy: GDScript = preload("res://src/core/enemy/base/Enemy.gd")
const GameStateManager: GDScript = preload("res://src/core/managers/GameStateManager.gd")
const EnemyData: GDScript = preload("res://src/core/rivals/EnemyData.gd")

# Type-safe instance variables
var _enemy: CharacterBody2D
var _tracked_enemies: Array[CharacterBody2D] = []
var _enemy_data: Resource

# Type-safe constants
const TEST_TIMEOUT := 2.0

func before_each() -> void:
    await super.before_each()
    
    # Initialize game state with type safety
    _game_state = GameStateManager.new()
    if not _game_state:
        push_error("Failed to create game state manager")
        return
    add_child_autofree(_game_state)
    track_test_node(_game_state)
    
    # Initialize enemy data
    _enemy_data = EnemyData.new(GameEnums.EnemyType.GANGERS, GameEnums.EnemyCategory.CRIMINAL_ELEMENTS)
    if not _enemy_data:
        push_error("Failed to create enemy data")
        return
    track_test_resource(_enemy_data)
    
    # Initialize enemy with type safety
    _enemy = Enemy.new()
    if not _enemy:
        push_error("Failed to create enemy")
        return
    _enemy.enemy_data = _enemy_data
    add_child_autofree(_enemy)
    track_test_node(_enemy)
    
    await stabilize_engine()

func after_each() -> void:
    _cleanup_test_enemies()
    
    if is_instance_valid(_enemy):
        _enemy.queue_free()
        
    _enemy = null
    _enemy_data = null
    
    await super.after_each()

# Helper Methods
func _create_test_enemy_data() -> Dictionary:
    return {
        "enemy_id": str(Time.get_unix_time_from_system()),
        "enemy_type": GameEnums.EnemyType.GANGERS,
        "name": "Test Enemy",
        "level": 1,
        "health": 100,
        "max_health": 100,
        "armor": 10,
        "damage": 20,
        "abilities": [],
        "loot_table": {
            "credits": 50,
            "items": []
        }
    }

func _create_test_ability(ability_type: int) -> Dictionary:
    return {
        "ability_type": ability_type,
        "damage": 15,
        "cooldown": 2,
        "range": 3,
        "area_effect": false
    }

func _cleanup_test_enemies() -> void:
    for enemy in _tracked_enemies:
        if is_instance_valid(enemy):
            enemy.queue_free()
    _tracked_enemies.clear()

# Test Methods
func test_enemy_initialization() -> void:
    var enemy_data := _create_test_enemy_data()
    assert_not_null(enemy_data, "Enemy data should be created")
    
    # Initialize enemy properties
    _enemy.enemy_data.enemy_type = enemy_data.enemy_type
    _enemy.enemy_data.character_name = enemy_data.name
    _enemy.enemy_data.stats[GameEnums.CharacterStats.TOUGHNESS] = enemy_data.health
    _enemy.enemy_data.armor_save = enemy_data.armor
    
    # Verify enemy state
    assert_eq(
        _enemy.enemy_data.enemy_type,
        GameEnums.EnemyType.GANGERS,
        "Enemy type should be set correctly"
    )
    assert_eq(
        _enemy.enemy_data.stats[GameEnums.CharacterStats.TOUGHNESS],
        100,
        "Enemy health should be set correctly"
    )

func test_enemy_damage() -> void:
    # Setup enemy
    var enemy_data := _create_test_enemy_data()
    _enemy.enemy_data.enemy_type = enemy_data.enemy_type
    _enemy.enemy_data.stats[GameEnums.CharacterStats.TOUGHNESS] = enemy_data.health
    _enemy.enemy_data.armor_save = enemy_data.armor
    
    # Test damage calculation
    var damage := 50
    var actual_damage: int = _enemy.take_damage(damage)
    
    # Verify damage reduction from armor
    assert_lt(
        actual_damage,
        damage,
        "Damage should be reduced by armor"
    )
    
    # Apply damage
    _enemy.take_damage(damage)
    
    # Verify health reduction
    assert_lt(
        _enemy.get_health(),
        enemy_data.health,
        "Enemy health should be reduced after taking damage"
    )

func test_enemy_death() -> void:
    # Setup enemy
    var enemy_data := _create_test_enemy_data()
    _enemy.enemy_data.enemy_type = enemy_data.enemy_type
    _enemy.enemy_data.stats[GameEnums.CharacterStats.TOUGHNESS] = enemy_data.health
    
    # Kill enemy
    _enemy.take_damage(_enemy.get_max_health())
    
    # Verify death state
    assert_eq(
        _enemy.get_health(),
        0,
        "Enemy health should be zero after death"
    )
    assert_true(
        _enemy.get_health() <= 0,
        "Enemy should be marked as dead"
    )

func test_enemy_abilities() -> void:
    # Setup enemy
    var enemy_data := _create_test_enemy_data()
    var ability := _create_test_ability(GameEnums.UnitAction.ATTACK)
    
    _enemy.enemy_data.enemy_type = enemy_data.enemy_type
    _enemy.enemy_data.enemy_behavior = GameEnums.EnemyBehavior.AGGRESSIVE
    
    # Verify ability
    assert_eq(
        _enemy.enemy_data.enemy_behavior,
        GameEnums.EnemyBehavior.AGGRESSIVE,
        "Enemy behavior should be set correctly"
    )
    
    # Test ability usage
    var target_position := Vector2(3, 3)
    var ability_result: Dictionary = _enemy.attack(target_position)
    
    # Verify ability result
    assert_true(
        ability_result.has("success"),
        "Ability result should contain success status"
    )
    assert_true(
        ability_result.has("damage"),
        "Ability result should contain damage value"
    )

func test_enemy_loot() -> void:
    # Setup enemy
    var enemy_data := _create_test_enemy_data()
    _enemy.enemy_data.enemy_type = enemy_data.enemy_type
    _enemy.enemy_data.loot_table = enemy_data.loot_table
    
    # Kill enemy to trigger loot
    _enemy.take_damage(_enemy.get_max_health())
    
    # Get loot
    var loot: Dictionary = _enemy.generate_loot()
    
    # Verify loot
    assert_true(
        loot.has("credits"),
        "Loot should contain credits"
    )
    assert_eq(
        loot.credits,
        enemy_data.loot_table.credits,
        "Loot credits should match configuration"
    )

# Performance Testing
func test_enemy_performance() -> void:
    var enemy_data := _create_test_enemy_data()
    
    # Initialize enemy properties
    _enemy.enemy_data.enemy_type = enemy_data.enemy_type
    _enemy.enemy_data.stats[GameEnums.CharacterStats.TOUGHNESS] = enemy_data.health
    _enemy.enemy_data.armor_save = enemy_data.armor
    _enemy.enemy_data.enemy_behavior = GameEnums.EnemyBehavior.AGGRESSIVE
    
    # Add multiple abilities for stress testing
    var abilities: Array[Dictionary] = []
    for i in range(5):
        abilities.append(_create_test_ability(GameEnums.UnitAction.ATTACK))
    
    var metrics := await measure_performance(
        func(): _update_enemy_state(),
        50 # Reduced iterations for enemy performance test
    )
    
    verify_performance_metrics(metrics, {
        "average_fps": 30.0,
        "minimum_fps": 20.0,
        "memory_delta_kb": 128.0,
        "draw_calls_delta": 10
    })

# Helper function for performance testing
func _update_enemy_state() -> void:
    # Simulate combat actions
    _enemy.take_damage(5)
    _enemy.attack(Vector2(3, 3))
    _enemy.heal(2)
    _enemy.start_turn()

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
        await stabilize_engine()
    
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