@tool
extends "res://tests/fixtures/base/game_test.gd"

## Base class for enemy-related tests
##
## Provides common functionality, type declarations, and helper methods
## for testing enemy behavior, combat, and state management.

# Required type declarations
const Enemy: GDScript = preload("res://src/core/battle/enemy/Enemy.gd")
const EnemyData: GDScript = preload("res://src/core/rivals/EnemyData.gd")

# Core script references with type safety
const _enemy_script: GDScript = preload("res://src/core/battle/enemy/Enemy.gd")
const _enemy_data_script: GDScript = preload("res://src/core/rivals/EnemyData.gd")

# Common test timeouts with type safety
const DEFAULT_TIMEOUT := 1.0 as float
const SETUP_TIMEOUT := 2.0 as float

# Common test states with type safety
var _battlefield: Node2D = null
var _enemy_campaign_system: Node = null
var _combat_system: Node = null

# Test enemy states with explicit typing
var TEST_ENEMY_STATES: Dictionary = {
	"BASIC": {
		"health": 100.0 as float,
		"movement_range": 4.0 as float,
		"weapon_range": 1.0 as float,
		"behavior": GameEnums.AIBehavior.CAUTIOUS as int
	},
	"ELITE": {
		"health": 150.0 as float,
		"movement_range": 6.0 as float,
		"weapon_range": 2.0 as float,
		"behavior": GameEnums.AIBehavior.AGGRESSIVE as int
	},
	"BOSS": {
		"health": 300.0 as float,
		"movement_range": 3.0 as float,
		"weapon_range": 3.0 as float,
		"behavior": GameEnums.AIBehavior.DEFENSIVE as int
	}
}

# Test references with type safety
var _enemy: Enemy = null
var _enemy_data: EnemyData = null

# Core script references with type safety
# Enhanced test configuration
const PERFORMANCE_TEST_CONFIG := {
	"movement_iterations": 100 as int,
	"combat_iterations": 50 as int,
	"pathfinding_iterations": 75 as int
}

const MOBILE_TEST_CONFIG := {
	"touch_target_size": Vector2(44, 44),
	"min_frame_time": 16.67 # Target 60fps
}

# Setup methods with proper error handling
func before_each() -> void:
	await super.before_each()
	if not await setup_base_systems():
		push_error("Failed to setup base systems")
		return
	await stabilize_engine()

func after_each() -> void:
	_cleanup_test_resources()
	await super.after_each()

# Base system setup with type safety
func setup_base_systems() -> bool:
	if not _setup_battlefield():
		return false
	if not _setup_enemy_campaign_system():
		return false
	if not _setup_combat_system():
		return false
	return true

func _setup_battlefield() -> bool:
	_battlefield = Node2D.new()
	if not _battlefield:
		push_error("Failed to create battlefield")
		return false
	_battlefield.name = "TestBattlefield"
	add_child_autofree(_battlefield)
	track_test_node(_battlefield)
	return true

func _setup_enemy_campaign_system() -> bool:
	_enemy_campaign_system = Node.new()
	if not _enemy_campaign_system:
		push_error("Failed to create enemy campaign system")
		return false
	_enemy_campaign_system.name = "EnemyCampaignSystem"
	add_child_autofree(_enemy_campaign_system)
	track_test_node(_enemy_campaign_system)
	return true

func _setup_combat_system() -> bool:
	_combat_system = Node.new()
	if not _combat_system:
		push_error("Failed to create combat system")
		return false
	_combat_system.name = "CombatSystem"
	add_child_autofree(_combat_system)
	track_test_node(_combat_system)
	return true

# Resource cleanup with type safety
func _cleanup_test_resources() -> void:
	_enemy = null
	_enemy_data = null
	_battlefield = null
	_enemy_campaign_system = null
	_combat_system = null

# Helper methods with type safety
func create_test_enemy(type: String = "BASIC") -> Enemy:
	var enemy: Enemy = Enemy.new()
	if not enemy:
		push_error("Failed to create enemy instance")
		return null
	
	var data: Dictionary = TEST_ENEMY_STATES.get(type, TEST_ENEMY_STATES.BASIC)
	enemy.initialize(data)
	add_child_autofree(enemy)
	track_test_node(enemy)
	
	return enemy

func verify_enemy_complete_state(enemy: Enemy) -> void:
	if not enemy:
		push_error("Enemy instance is null")
		assert_false(true, "Enemy instance is null")
		return
	
	assert_not_null(enemy, "Enemy instance should not be null")
	assert_true(enemy is Enemy, "Object should be Enemy type")
	assert_true(enemy.is_inside_tree(), "Enemy should be in scene tree")

func verify_enemy_state(enemy: Enemy, expected_state: Dictionary) -> void:
	if not enemy:
		push_error("Enemy instance is null")
		assert_false(true, "Enemy instance is null")
		return
	
	for property in expected_state:
		var actual_value: float = TypeSafeMixin._safe_cast_float(TypeSafeMixin._call_node_method(enemy, "get_" + property, []))
		var expected_value: float = expected_state[property]
		assert_eq(actual_value, expected_value,
			"Enemy %s should be %s, got %s" % [property, expected_value, actual_value])

func verify_enemy_movement(enemy: Enemy, start_pos: Vector2, end_pos: Vector2) -> void:
	if not enemy:
		push_error("Enemy instance is null")
		assert_false(true, "Enemy instance is null")
		return
	
	enemy.position = start_pos
	TypeSafeMixin._call_node_method_bool(enemy, "move_to", [end_pos])
	assert_true(enemy.position.distance_to(end_pos) < 1.0,
		"Enemy should move to target position")

func verify_enemy_combat(enemy: Enemy, target: Enemy) -> void:
	if not enemy or not target:
		push_error("Enemy or target is null")
		assert_false(true, "Enemy or target is null")
		return
	
	TypeSafeMixin._call_node_method_bool(enemy, "engage_target", [target])
	assert_true(TypeSafeMixin._call_node_method_bool(enemy, "is_in_combat", []),
		"Enemy should be in combat state")

func verify_enemy_error_handling(enemy: Enemy) -> void:
	if not enemy:
		push_error("Enemy instance is null")
		assert_false(true, "Enemy instance is null")
		return
	
	# Test invalid movement
	var invalid_pos := Vector2(-1000, -1000)
	assert_false(TypeSafeMixin._call_node_method_bool(enemy, "move_to", [invalid_pos]),
		"Enemy should handle invalid movement")
	
	# Test invalid target
	assert_false(TypeSafeMixin._call_node_method_bool(enemy, "engage_target", [null]),
		"Enemy should handle invalid target")

func verify_enemy_touch_interaction(enemy: Enemy) -> void:
	if not enemy:
		push_error("Enemy instance is null")
		assert_false(true, "Enemy instance is null")
		return
	
	_signal_watcher.watch_signals(enemy)
	TypeSafeMixin._call_node_method_bool(enemy, "handle_touch", [Vector2.ZERO])
	verify_signal_emitted(enemy, "touch_handled")

# Enhanced performance testing methods
func measure_enemy_performance() -> Dictionary:
	var metrics: Dictionary = {}
	var start_time: int = Time.get_ticks_msec()
	var start_memory: int = OS.get_static_memory_usage()
	
	await get_tree().create_timer(1.0).timeout
	
	var end_time: int = Time.get_ticks_msec()
	var end_memory: int = OS.get_static_memory_usage()
	
	metrics["average_fps"] = Engine.get_frames_per_second()
	metrics["minimum_fps"] = Engine.get_frames_per_second()
	metrics["memory_delta_kb"] = (end_memory - start_memory) / 1024.0
	
	return metrics

# Common setup methods
func setup_campaign_test() -> void:
	# Setup campaign test environment
	pass

# Common test data creation
func create_test_enemy_data(enemy_type: String = "BASIC") -> Resource:
	var data: Resource = EnemyData.new()
	if not data:
		push_error("Failed to create enemy data")
		return null
	
	var state = TEST_ENEMY_STATES[enemy_type] if TEST_ENEMY_STATES.has(enemy_type) else TEST_ENEMY_STATES.BASIC
	for key in state:
		TypeSafeMixin._call_node_method_bool(data, "set_" + key, [state[key]])
	
	track_test_resource(data)
	return data

# Signal verification helpers
func verify_enemy_signals(enemy: Node, expected_signals: Array[String]) -> void:
	if not enemy:
		push_error("Enemy not initialized")
		return
		
	for signal_name in expected_signals:
		assert_true(enemy.has_signal(signal_name),
			"Enemy should have signal '%s'" % signal_name)

func verify_performance_metrics(metrics: Dictionary, expected: Dictionary) -> void:
	if not metrics or not expected:
		push_error("Metrics or expected values are null")
		assert_false(true, "Metrics or expected values are null")
		return
	
	for metric in expected:
		assert_true(metrics.has(metric), "Should have %s metric" % metric)
		assert_true(metrics[metric] >= expected[metric],
			"%s should be at least %s" % [metric, expected[metric]])