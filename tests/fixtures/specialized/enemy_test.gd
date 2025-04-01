@tool
extends "res://tests/fixtures/base/game_test.gd"

## Base class for enemy-related tests
##
## This class provides common functionality for testing enemies,
## enemy behavior, and combat mechanics.

# Load scripts safely with Compatibility helper
const Compatibility = preload("res://tests/fixtures/helpers/test_compatibility_helper.gd")
const TestCleanup = preload("res://tests/fixtures/helpers/test_cleanup_helper.gd")

var EnemyScript = load("res://src/core/battle/enemy/Enemy.gd") if ResourceLoader.exists("res://src/core/battle/enemy/Enemy.gd") else null
var EnemyDataScript = load("res://src/core/rivals/EnemyData.gd") if ResourceLoader.exists("res://src/core/rivals/EnemyData.gd") else null

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
var _test_enemies: Array = []
var _enemy_combat_manager: Node = null
var _enemy_ai_manager: Node = null

## Lifecycle methods

func before_all() -> void:
	await super.before_all()
	
	# Ensure temp directory exists
	Compatibility.ensure_temp_directory()

func after_all() -> void:
	# Clean up temporary files that might have been created during tests
	# Only clean up temp files older than 1 hour to avoid interfering with active tests
	TestCleanup.cleanup_old_files(1)
	await super.after_all()

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
func create_test_enemy(enemy_type: EnemyTestType = EnemyTestType.BASIC) -> Node:
	if not EnemyScript:
		push_error("Enemy script is null")
		return null
		
	var enemy_instance = EnemyScript.new()
	if not enemy_instance:
		push_error("Failed to create test enemy")
		return null
	
	var enemy_data := _create_enemy_test_data(enemy_type)
	Compatibility.safe_call_method(enemy_instance, "initialize", [enemy_data])
	
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
func verify_enemy_movement(enemy: Node, start_pos: Vector2, end_pos: Vector2) -> void:
	Compatibility.safe_call_method(enemy, "set_position", [start_pos])
	Compatibility.safe_call_method(enemy, "move_to", [end_pos])
	
	# Wait for movement to complete
	await get_tree().create_timer(ENEMY_TEST_CONFIG.pathfinding_timeout).timeout
	
	var final_pos = Compatibility.safe_call_method(enemy, "get_position", [], Vector2())
	var x_distance: float = abs(final_pos.x - end_pos.x)
	var y_distance: float = abs(final_pos.y - end_pos.y)
	assert_le(x_distance, 1.0, "Enemy should move to target X position")
	assert_le(y_distance, 1.0, "Enemy should move to target Y position")

# Verifies enemy combat
func verify_enemy_combat(enemy: Node, target: Node) -> void:
	watch_signals(enemy)
	Compatibility.safe_call_method(enemy, "attack", [target])
	
	# Wait for combat to complete
	await get_tree().create_timer(ENEMY_TEST_CONFIG.combat_timeout).timeout
	
	assert_signal_emitted(enemy, "attack_completed")

# Verifies enemy state matches expected values
func verify_enemy_state(enemy: Node, expected_state: Dictionary) -> void:
	for key in expected_state:
		var value = null
		
		match key:
			"health":
				value = Compatibility.safe_call_method(enemy, "get_health", [], 0)
				if value != null:
					value = float(value)
			"level":
				value = Compatibility.safe_call_method(enemy, "get_level", [], 0)
			"experience":
				value = Compatibility.safe_call_method(enemy, "get_experience", [], 0)
			"damage":
				value = Compatibility.safe_call_method(enemy, "get_damage", [], 0)
				if value != null:
					value = float(value)
			_:
				push_error("Unknown state key: %s" % key)
				continue
		
		assert_eq(value, expected_state[key], "Enemy %s should match expected value" % key)

# Verifies all enemy state is valid
func verify_enemy_complete_state(enemy: Node) -> void:
	assert_true(Compatibility.safe_call_method(enemy, "is_valid", [], false), "Enemy should be in valid state")
	
	var health = Compatibility.safe_call_method(enemy, "get_health", [], 0)
	assert_gt(float(health) if health != null else 0.0, 0.0, "Enemy health should be positive")
	
	var damage = Compatibility.safe_call_method(enemy, "get_damage", [], 0)
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
	
	# Add initialize method to the AI manager
	var script = GDScript.new()
	
	script.source_code = """
extends Node

signal action_completed
signal turn_completed
signal attack_completed
signal move_completed

var last_action = ""
var last_target = null
var action_successful = true

func _init():
	pass

func take_turn(enemy_data):
	last_action = "take_turn"
	emit_signal("turn_completed")
	return true

func perform_attack(attacker, target):
	last_action = "attack"
	last_target = target
	emit_signal("attack_completed")
	return true

func perform_move(enemy, target_position):
	last_action = "move"
	emit_signal("move_completed")
	return true

func calculate_path(enemy, start_pos, end_pos):
	return [start_pos, end_pos]
"""
	script.reload()
	
	_enemy_ai_manager.set_script(script)
	add_child_autofree(_enemy_ai_manager)

# Helper class for compatibility path generation
class CompatibilityPath:
	func _init():
		pass
		
	func create_script() -> GDScript:
		return GDScript.new()
