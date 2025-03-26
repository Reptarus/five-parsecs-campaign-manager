@tool
extends "res://tests/fixtures/specialized/enemy_test.gd"
# Use explicit preloads instead of global class names

# Import the Enemy class for type checking
const Enemy = preload("res://src/core/enemy/Enemy.gd")

# These are already declared in the parent class - no need to redeclare

## Core enemy functionality tests
##
## Tests basic enemy behavior, state management, and interactions.
## Covers initialization, movement, combat, health, and turn management.

# Type-safe test constants
const TEST_ENEMY_DATA = {
	"id": "test_enemy",
	"name": "Test Enemy",
	"type": GameEnums.EnemyType.RAIDERS,
	"health": 100,
	"armor": 0,
	"movement": 6,
	"actions": 2
}

# Type-safe instance variables
var _test_enemy: Enemy = null
var _test_target: Node2D = null

# Lifecycle Methods
func before_each() -> void:
	await super.before_each()
	
	# Initialize test components
	_test_enemy = create_test_enemy()
	if not _test_enemy:
		push_error("Failed to create test enemy")
		return
	
	_test_target = Node2D.new()
	if not _test_target:
		push_error("Failed to create test target")
		return
	
	add_child_autofree(_test_target)
	
	await stabilize_engine(STABILIZE_TIME)

func after_each() -> void:
	_test_enemy = null
	_test_target = null
	await super.after_each()

# Initialization Tests
func test_enemy_initialization() -> void:
	var enemy := create_test_enemy()
	verify_enemy_complete_state(enemy)
	
	assert_eq(enemy.get_health(), 100.0, "Should have default health")
	assert_eq(enemy.get_movement_range(), 4.0, "Should have default movement range")
	assert_eq(enemy.get_weapon_range(), 1.0, "Should have default weapon range")
	assert_eq(enemy.get_behavior(), GameEnums.AIBehavior.CAUTIOUS, "Should have default behavior")

# Movement Tests
func test_enemy_movement() -> void:
	var enemy := create_test_enemy()
	verify_enemy_complete_state(enemy)
	
	var start_pos := Vector2.ZERO
	var end_pos := Vector2(10, 10)
	verify_enemy_movement(enemy, start_pos, end_pos)

# Combat Tests
func test_enemy_combat() -> void:
	var enemy := create_test_enemy()
	var target := create_test_enemy()
	verify_enemy_complete_state(enemy)
	verify_enemy_complete_state(target)
	
	verify_enemy_combat(enemy, target)

# Health System Tests
func test_enemy_health_system() -> void:
	var enemy := create_test_enemy(EnemyTestType.BOSS) as Enemy
	assert_not_null(enemy, "Should create boss enemy")
	add_child_autofree(enemy)
	
	var initial_health: float = TypeSafeMixin._safe_cast_float(TypeSafeMixin._call_node_method(enemy, "get_health", []))
	
	# Test damage
	watch_signals(enemy)
	TypeSafeMixin._call_node_method_bool(enemy, "take_damage", [50.0])
	
	var current_health: float = TypeSafeMixin._safe_cast_float(TypeSafeMixin._call_node_method(enemy, "get_health", []))
	assert_eq(current_health, initial_health - 50.0, "Health should be reduced by damage")
	verify_signal_emitted(enemy, "health_changed")
	
	# Test healing
	watch_signals(enemy)
	TypeSafeMixin._call_node_method_bool(enemy, "heal", [20.0])
	
	current_health = TypeSafeMixin._safe_cast_float(TypeSafeMixin._call_node_method(enemy, "get_health", []))
	assert_eq(current_health, initial_health - 30.0, "Health should be increased by healing")
	verify_signal_emitted(enemy, "health_changed")

func test_enemy_death() -> void:
	var enemy := create_test_enemy(EnemyTestType.BOSS) as Enemy
	assert_not_null(enemy, "Should create boss enemy")
	add_child_autofree(enemy)
	
	watch_signals(enemy)
	TypeSafeMixin._call_node_method_bool(enemy, "take_damage", [1000.0])
	
	var current_health: float = TypeSafeMixin._safe_cast_float(TypeSafeMixin._call_node_method(enemy, "get_health", []))
	assert_eq(current_health, 0.0, "Health should not go below 0")
	verify_signal_emitted(enemy, "died")

# Turn Management Tests
func test_enemy_turn_system() -> void:
	var enemy: Enemy = create_test_enemy()
	assert_not_null(enemy, "Should create enemy instance")
	add_child_autofree(enemy)
	
	# Start turn
	watch_signals(enemy)
	TypeSafeMixin._call_node_method_bool(enemy, "start_turn", [])
	
	assert_true(TypeSafeMixin._call_node_method_bool(enemy, "is_active", []),
		"Enemy should be active after turn start")
	assert_true(TypeSafeMixin._call_node_method_bool(enemy, "can_move", []),
		"Enemy should be able to move after turn start")
	verify_signal_emitted(enemy, "turn_started")
	
	# End turn
	watch_signals(enemy)
	TypeSafeMixin._call_node_method_bool(enemy, "end_turn", [])
	
	assert_false(TypeSafeMixin._call_node_method_bool(enemy, "is_active", []),
		"Enemy should not be active after turn end")
	assert_false(TypeSafeMixin._call_node_method_bool(enemy, "can_move", []),
		"Enemy should not be able to move after turn end")
	verify_signal_emitted(enemy, "turn_ended")

# Combat Rating Tests
func test_enemy_combat_rating() -> void:
	var enemy: Enemy = create_test_enemy(EnemyTestType.ELITE)
	assert_not_null(enemy, "Should create elite enemy")
	add_child_autofree(enemy)
	
	var initial_rating: float = TypeSafeMixin._safe_cast_float(TypeSafeMixin._call_node_method(enemy, "get_combat_rating", []))
	
	# Test rating with damage
	TypeSafeMixin._call_node_method_bool(enemy, "take_damage", [75.0]) # 50% health remaining
	var damaged_rating: float = TypeSafeMixin._safe_cast_float(TypeSafeMixin._call_node_method(enemy, "get_combat_rating", []))
	
	assert_true(damaged_rating < initial_rating,
		"Combat rating should decrease with damage")
	
	# Test rating with healing
	TypeSafeMixin._call_node_method_bool(enemy, "heal", [75.0]) # Back to full health
	var healed_rating: float = TypeSafeMixin._safe_cast_float(TypeSafeMixin._call_node_method(enemy, "get_combat_rating", []))
	
	assert_eq(healed_rating, initial_rating,
		"Combat rating should return to initial value after healing")

# Error Handling Tests
func test_enemy_error_handling() -> void:
	var enemy := create_test_enemy()
	verify_enemy_complete_state(enemy)
	verify_enemy_error_handling(enemy)

# Mobile Performance Tests
func test_enemy_mobile_performance() -> void:
	var enemy: Enemy = create_test_enemy(EnemyTestType.ELITE)
	assert_not_null(enemy, "Should create elite enemy")
	add_child_autofree(enemy)
	
	var metrics := await measure_enemy_performance()
	verify_performance_metrics(metrics, {
		"average_fps": 30.0,
		"minimum_fps": 20.0,
		"memory_delta_kb": 1024.0
	})

# Mobile Touch Tests
func test_enemy_touch_interaction() -> void:
	var enemy: Enemy = create_test_enemy()
	assert_not_null(enemy, "Should create enemy instance")
	add_child_autofree(enemy)
	
	verify_enemy_touch_interaction(enemy)

func test_enemy_state_changes() -> void:
	var enemy := create_test_enemy()
	verify_enemy_complete_state(enemy)
	
	enemy.set_current_health(50.0)
	assert_eq(enemy.get_current_health(), 50.0, "Should update health")
	
	enemy.set_movement_range(6.0)
	assert_eq(enemy.get_movement_range(), 6.0, "Should update movement range")
	
	enemy.set_weapon_range(2.0)
	assert_eq(enemy.get_weapon_range(), 2.0, "Should update weapon range")
	
	enemy.set_behavior(GameEnums.AIBehavior.AGGRESSIVE)
	assert_eq(enemy.get_behavior(), GameEnums.AIBehavior.AGGRESSIVE, "Should update behavior")

func test_enemy_signals() -> void:
	var enemy := create_test_enemy()
	verify_enemy_complete_state(enemy)
	
	watch_signals(enemy)
	enemy.set_current_health(50.0)
	verify_signal_emitted(enemy, "health_changed")
	
	enemy.set_behavior(GameEnums.AIBehavior.AGGRESSIVE)
	verify_signal_emitted(enemy, "behavior_changed")

# Add the missing functions
func verify_enemy_error_handling(enemy: Enemy) -> void:
	# Test invalid damage values
	var initial_health = TypeSafeMixin._call_node_method_int(enemy, "get_health", [], 0)
	TypeSafeMixin._call_node_method_bool(enemy, "take_damage", [-10])
	var health_after_invalid = TypeSafeMixin._call_node_method_int(enemy, "get_health", [], 0)
	assert_eq(initial_health, health_after_invalid, "Should not change health with invalid damage value")
	
	# Test invalid heal values
	TypeSafeMixin._call_node_method_bool(enemy, "take_damage", [10])
	var reduced_health = TypeSafeMixin._call_node_method_int(enemy, "get_health", [], 0)
	TypeSafeMixin._call_node_method_bool(enemy, "heal", [-5])
	var health_after_invalid_heal = TypeSafeMixin._call_node_method_int(enemy, "get_health", [], 0)
	assert_eq(reduced_health, health_after_invalid_heal, "Should not change health with invalid heal value")

func verify_enemy_touch_interaction(enemy: Enemy) -> void:
	# Test touch interaction signals
	watch_signals(enemy)
	TypeSafeMixin._call_node_method_bool(enemy, "handle_touch", [Vector2(0, 0)])
	assert_signal_emitted(enemy, "enemy_touched")
	
	# Test long press interaction
	TypeSafeMixin._call_node_method_bool(enemy, "handle_long_press", [Vector2(0, 0)])
	assert_signal_emitted(enemy, "enemy_selected")
