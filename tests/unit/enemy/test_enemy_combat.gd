@tool
extends "res://tests/fixtures/enemy_test.gd"

# This file contains unit tests for basic enemy combat functionality.
# For integration tests with the battle system, see tests/integration/battle/test_enemy_combat_integration.gd

# Type-safe instance variables
var _ai_manager: Node = null
var _tactical_ai: Node = null
var _battlefield_manager: Node = null
var _combat_manager: Node = null

func before_each() -> void:
    await super.before_each()
    
    # Initialize test components with type safety
    _ai_manager = Node.new()
    _tactical_ai = Node.new()
    _battlefield_manager = Node.new()
    _combat_manager = Node.new()
    
    add_child_autofree(_ai_manager)
    add_child_autofree(_tactical_ai)
    add_child_autofree(_battlefield_manager)
    add_child_autofree(_combat_manager)
    
    track_test_node(_ai_manager)
    track_test_node(_tactical_ai)
    track_test_node(_battlefield_manager)
    track_test_node(_combat_manager)
    
    await stabilize_engine()

func after_each() -> void:
    _ai_manager = null
    _tactical_ai = null
    _battlefield_manager = null
    _combat_manager = null
    await super.after_each()

func test_enemy_combat_initialization() -> void:
    var enemy: Node = create_test_enemy("ELITE")
    if not enemy:
        push_error("Failed to create enemy")
        return
    
    assert_not_null(enemy, "Enemy should be created")
    var can_attack: bool = _call_node_method_bool(enemy, "can_attack", [])
    assert_true(can_attack, "Elite enemy should be able to attack")

func test_enemy_combat_actions() -> void:
    var enemy: Node = create_test_enemy("ELITE")
    if not enemy:
        push_error("Failed to create enemy")
        return
    
    var target: Node2D = Node2D.new()
    add_child_autofree(target)
    track_test_node(target)
    
    watch_signals(enemy)
    _call_node_method(enemy, "attack", [target])
    verify_signal_emitted(enemy, "attack_executed")
    
    var can_attack: bool = _call_node_method_bool(enemy, "can_attack", [])
    assert_false(can_attack, "Enemy should not be able to attack after using action")

func test_enemy_combat_range() -> void:
    var enemy: Node = create_test_enemy("ELITE")
    if not enemy:
        push_error("Failed to create enemy")
        return
    
    var target: Node2D = Node2D.new()
    target.position = Vector2(1000, 1000) # Far away
    add_child_autofree(target)
    track_test_node(target)
    
    var in_range: bool = _call_node_method_bool(enemy, "is_target_in_range", [target])
    assert_false(in_range, "Target should be out of range")
    
    target.position = Vector2(50, 50) # Close by
    in_range = _call_node_method_bool(enemy, "is_target_in_range", [target])
    assert_true(in_range, "Target should be in range")