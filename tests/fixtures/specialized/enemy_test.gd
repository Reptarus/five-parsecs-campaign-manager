@tool
extends "res://tests/fixtures/base/game_test.gd"

## Base class for enemy-related tests
##
## This class provides common functionality for testing enemies,
## enemy behavior, and combat mechanics.

# Required type declarations
const Enemy: GDScript = preload("res://src/core/battle/enemy/Enemy.gd")
const EnemyData: GDScript = preload("res://src/core/rivals/EnemyData.gd")

# Common test timeouts with type safety
const DEFAULT_TIMEOUT := 1.0 as float
const SETUP_TIMEOUT := 2.0 as float

# Enemy test configuration
const ENEMY_TEST_CONFIG := {
	"stabilize_time": 0.2 as float,
	"combat_timeout": 2.0 as float,
	"animation_timeout": 1.0 as float,
	"pathfinding_timeout": 3.0 as float
}

# Test enemy types
enum EnemyTestType {
	BASIC,
	ELITE,
	BOSS,
	MINION,
	RANGED,
	MELEE
}

# Type-safe instance variables for test tracking
var _test_enemies: Array[Enemy] = []
var _enemy_combat_manager: Node = null
var _enemy_ai_manager: Node = null

## Lifecycle methods

func before_each() -> void:
	await super.before_each()
	_test_enemies = []
	_enemy_combat_manager = null
	_enemy_ai_manager = null
	
	# Initialize enemy system for tests
	_setup_enemy_system()
	
	await stabilize_engine(ENEMY_TEST_CONFIG.stabilize_time)

func after_each() -> void:
	# Clean up any test enemies
	for enemy in _test_enemies:
		if is_instance_valid(enemy) and enemy.is_inside_tree():
			enemy.queue_free()
	
	_test_enemies = []
	_enemy_combat_manager = null
	_enemy_ai_manager = null
	
	await super.after_each()

## Helper methods for enemy testing

# Creates a test enemy of the specified type
func create_test_enemy(enemy_type: EnemyTestType = EnemyTestType.BASIC) -> Enemy:
	var enemy_instance: Enemy = Enemy.new()
	if not enemy_instance:
		push_error("Failed to create test enemy")
		return null
	
	var enemy_data := _create_enemy_test_data(enemy_type)
	TypeSafeMixin._call_node_method_bool(enemy_instance, "initialize", [enemy_data])
	
	_test_enemies.append(enemy_instance)
	return enemy_instance

# Creates test enemy data
func _create_enemy_test_data(enemy_type: EnemyTestType) -> Dictionary:
	var data: Dictionary = {}
	
	# Set base properties with explicit types
	data["id"] = "test_enemy_%s" % [enemy_type] as String
	data["name"] = "Test Enemy" as String
	data["health"] = 10 as int
	data["damage"] = 2 as int
	data["speed"] = 3 as int
	data["defense"] = 1 as int
	
	match enemy_type:
		EnemyTestType.ELITE:
			data["health"] = 20 as int
			data["damage"] = 4 as int
			data["name"] = "Elite Test Enemy" as String
		EnemyTestType.BOSS:
			data["health"] = 50 as int
			data["damage"] = 8 as int
			data["name"] = "Boss Test Enemy" as String
		EnemyTestType.MINION:
			data["health"] = 5 as int
			data["damage"] = 1 as int
			data["name"] = "Minion Test Enemy" as String
		EnemyTestType.RANGED:
			data["attack_range"] = 10 as int
			data["name"] = "Ranged Test Enemy" as String
		EnemyTestType.MELEE:
			data["attack_range"] = 1 as int
			data["name"] = "Melee Test Enemy" as String
	
	return data

# Verifies enemy movement
func verify_enemy_movement(enemy: Enemy, start_pos: Vector2, end_pos: Vector2) -> void:
	TypeSafeMixin._call_node_method_bool(enemy, "set_position", [start_pos])
	TypeSafeMixin._call_node_method_bool(enemy, "move_to", [end_pos])
	
	# Wait for movement to complete
	await get_tree().create_timer(ENEMY_TEST_CONFIG.pathfinding_timeout).timeout
	
	var final_pos: Vector2 = TypeSafeMixin._safe_cast_vector2(TypeSafeMixin._call_node_method(enemy, "get_position", []))
	var x_distance: float = abs(final_pos.x - end_pos.x)
	var y_distance: float = abs(final_pos.y - end_pos.y)
	assert_le(x_distance, 1.0, "Enemy should move to target X position")
	assert_le(y_distance, 1.0, "Enemy should move to target Y position")

# Verifies enemy combat
func verify_enemy_combat(enemy: Enemy, target: Node) -> void:
	watch_signals(enemy)
	TypeSafeMixin._call_node_method_bool(enemy, "attack", [target])
	
	# Wait for combat to complete
	await get_tree().create_timer(ENEMY_TEST_CONFIG.combat_timeout).timeout
	
	assert_signal_emitted(enemy, "attack_completed")

# Verifies enemy state matches expected values
func verify_enemy_state(enemy: Enemy, expected_state: Dictionary) -> void:
	for key in expected_state:
		var value = null
		
		match key:
			"health":
				value = TypeSafeMixin._call_node_method(enemy, "get_health", [])
				if value != null:
					value = float(value)
			"level":
				value = TypeSafeMixin._call_node_method_int(enemy, "get_level", [])
			"experience":
				value = TypeSafeMixin._call_node_method_int(enemy, "get_experience", [])
			"damage":
				value = TypeSafeMixin._call_node_method(enemy, "get_damage", [])
				if value != null:
					value = float(value)
			_:
				push_error("Unknown state key: %s" % key)
				continue
		
		assert_eq(value, expected_state[key], "Enemy %s should match expected value" % key)

# Verifies all enemy state is valid
func verify_enemy_complete_state(enemy: Enemy) -> void:
	assert_true(TypeSafeMixin._call_node_method_bool(enemy, "is_valid", []), "Enemy should be in valid state")
	
	var health = TypeSafeMixin._call_node_method(enemy, "get_health", [])
	assert_gt(float(health) if health != null else 0.0, 0.0, "Enemy health should be positive")
	
	var damage = TypeSafeMixin._call_node_method(enemy, "get_damage", [])
	assert_gt(float(damage) if damage != null else 0.0, 0.0, "Enemy damage should be positive")

# Helper to measure enemy performance
func measure_enemy_performance(count: int = 10) -> Dictionary:
	var performance_metrics := {
		"average_fps": 0.0,
		"minimum_fps": 0.0,
		"memory_increase_mb": 0.0,
		"load_time_ms": 0.0,
	}
	
	# Create test enemies
	var start_time := Time.get_ticks_msec()
	var memory_before := OS.get_static_memory_usage()
	
	var enemies := []
	for i in range(count):
		var enemy := create_test_enemy()
		add_child_autofree(enemy)
		enemies.append(enemy)
	
	var end_time := Time.get_ticks_msec()
	var memory_after := OS.get_static_memory_usage()
	
	# Calculate performance metrics
	performance_metrics.load_time_ms = end_time - start_time
	performance_metrics.memory_increase_mb = (memory_after - memory_before) / (1024.0 * 1024.0)
	
	# Measure FPS
	var fps_samples := []
	for i in range(30):
		await get_tree().process_frame
		fps_samples.append(Engine.get_frames_per_second())
	
	# Calculate FPS metrics
	var fps_sum := 0.0
	var min_fps := 1000.0
	for fps in fps_samples:
		fps_sum += fps
		min_fps = min(min_fps, fps)
	
	performance_metrics.average_fps = fps_sum / fps_samples.size()
	performance_metrics.minimum_fps = min_fps
	
	return performance_metrics

# Helper to verify performance metrics
func verify_performance_metrics(metrics: Dictionary, thresholds: Dictionary) -> void:
	for key in thresholds:
		assert_true(metrics.has(key), "Performance metrics should include %s" % key)
		
		match key:
			"average_fps", "minimum_fps":
				assert_gt(metrics[key], thresholds[key], "%s should exceed threshold" % key)
			"load_time_ms", "memory_increase_mb":
				assert_lt(metrics[key], thresholds[key], "%s should be below threshold" % key)
			_:
				push_error("Unknown performance metric: %s" % key)

# Helper to setup the enemy system for testing
func _setup_enemy_system() -> void:
	_enemy_combat_manager = Node.new()
	_enemy_combat_manager.name = "EnemyCombatManager"
	add_child_autofree(_enemy_combat_manager)
	
	_enemy_ai_manager = Node.new()
	_enemy_ai_manager.name = "EnemyAIManager"
	add_child_autofree(_enemy_ai_manager)

# Core Pathfinding Tests
func test_pathfinding_initialization() -> void:
	var enemy: Enemy = create_test_enemy()
	assert_not_null(enemy, "Enemy should be created")
	assert_not_null(enemy.get_node("NavigationAgent2D"),
		"Enemy should have a navigation agent")

# Fix for missing assertion functions
func assert_le(a, b, text: String = "") -> void:
	if text.length() > 0:
		assert_true(a <= b, text)
	else:
		assert_true(a <= b, "Expected %s <= %s" % [a, b])

func assert_ge(a, b, text: String = "") -> void:
	if text.length() > 0:
		assert_true(a >= b, text)
	else:
		assert_true(a >= b, "Expected %s >= %s" % [a, b])
