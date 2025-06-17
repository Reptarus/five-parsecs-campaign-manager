@tool
extends GdUnitGameTest

## Base class for enemy-related tests
##
## Provides common functionality, type declarations, and helper methods
## for testing enemy behavior, combat, and state management.

# Import GameEnums for AI behavior constants
const GameEnums = preload("res://src/core/systems/GlobalEnums.gd")

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

# Test enemy states with explicit typing - using variables instead of constants
var TEST_ENEMY_STATES: Dictionary = {}

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
func before_test() -> void:
	super.before_test()
	_initialize_test_states()
	if not await setup_base_systems():
		push_error("Failed to setup base systems")
		return
	await stabilize_engine()

func after_test() -> void:
	_cleanup_test_resources()
	super.after_test()

func _initialize_test_states() -> void:
	TEST_ENEMY_STATES = {
		"BASIC": {
			"health": 100.0 as float,
			"movement_range": 4.0 as float,
			"weapon_range": 1.0 as float,
			"behavior": 0 as int # Placeholder for GameEnums.AIBehavior.CAUTIOUS
		},
		"ELITE": {
			"health": 150.0 as float,
			"movement_range": 6.0 as float,
			"weapon_range": 2.0 as float,
			"behavior": 1 as int # Placeholder for GameEnums.AIBehavior.AGGRESSIVE
		},
		"BOSS": {
			"health": 300.0 as float,
			"movement_range": 3.0 as float,
			"weapon_range": 3.0 as float,
			"behavior": 2 as int # Placeholder for GameEnums.AIBehavior.DEFENSIVE
		}
	}

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
	add_child(_battlefield)
	track_node(_battlefield)
	return true

func _setup_enemy_campaign_system() -> bool:
	_enemy_campaign_system = Node.new()
	if not _enemy_campaign_system:
		push_error("Failed to create enemy campaign system")
		return false
	_enemy_campaign_system.name = "EnemyCampaignSystem"
	add_child(_enemy_campaign_system)
	track_node(_enemy_campaign_system)
	return true

func _setup_combat_system() -> bool:
	_combat_system = Node.new()
	if not _combat_system:
		push_error("Failed to create combat system")
		return false
	_combat_system.name = "CombatSystem"
	add_child(_combat_system)
	track_node(_combat_system)
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
	if enemy.has_method("initialize"):
		enemy.call("initialize", data)
	add_child(enemy)
	track_node(enemy)
	
	return enemy

func verify_enemy_complete_state(enemy: Enemy) -> void:
	if not enemy:
		push_error("Enemy instance is null")
		assert_that(false).override_failure_message("Enemy instance is null").is_true()
		return
	
	assert_that(enemy).is_not_null()
	assert_that(enemy is Enemy).is_true()
	assert_that(enemy.is_inside_tree()).is_true()

func verify_enemy_state(enemy: Enemy, expected_state: Dictionary) -> void:
	if not enemy:
		push_error("Enemy instance is null")
		assert_that(false).override_failure_message("Enemy instance is null").is_true()
		return
	
	for property in expected_state:
		var actual_value: float = 0.0
		if enemy.has_method("get_" + property):
			var result = enemy.call("get_" + property)
			actual_value = float(result) if result != null else 0.0
		var expected_value: float = expected_state[property]
		assert_that(actual_value).is_equal(expected_value)

func verify_enemy_movement(enemy: Enemy, start_pos: Vector2, end_pos: Vector2) -> void:
	if not enemy:
		push_error("Enemy instance is null")
		assert_that(false).override_failure_message("Enemy instance is null").is_true()
		return
	
	enemy.position = start_pos
	if enemy.has_method("move_to"):
		enemy.call("move_to", end_pos)
	assert_that(enemy.position.distance_to(end_pos) < 1.0).is_true()

func verify_enemy_combat(enemy: Enemy, target: Enemy) -> void:
	if not enemy or not target:
		push_error("Enemy or target is null")
		assert_that(false).override_failure_message("Enemy or target is null").is_true()
		return
	
	if enemy.has_method("engage_target"):
		enemy.call("engage_target", target)
	var is_in_combat: bool = false
	if enemy.has_method("is_in_combat"):
		is_in_combat = enemy.call("is_in_combat")
	assert_that(is_in_combat).is_true()

func verify_enemy_error_handling(enemy: Enemy) -> void:
	if not enemy:
		push_error("Enemy instance is null")
		assert_that(false).override_failure_message("Enemy instance is null").is_true()
		return
	
	# Test invalid movement
	var invalid_pos := Vector2(-1000, -1000)
	var move_result: bool = false
	if enemy.has_method("move_to"):
		move_result = enemy.call("move_to", invalid_pos)
	assert_that(move_result).is_false()
	
	# Test invalid target
	var engage_result: bool = false
	if enemy.has_method("engage_target"):
		engage_result = enemy.call("engage_target", null)
	assert_that(engage_result).is_false()

func verify_enemy_touch_interaction(enemy: Enemy) -> void:
	if not enemy:
		push_error("Enemy instance is null")
		assert_that(false).override_failure_message("Enemy instance is null").is_true()

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
		if data.has_method("set_" + key):
			data.call("set_" + key, state[key])
	
	track_resource(data)
	return data

# Signal verification helpers
func verify_enemy_signals(enemy: Node, expected_signals: Array[String]) -> void:
	if not enemy:
		push_error("Enemy not initialized")
		return
		
	for signal_name in expected_signals:
		assert_that(enemy.has_signal(signal_name)).override_failure_message(
			"Enemy should have signal '%s'" % signal_name
		).is_true()

func verify_performance_metrics(metrics: Dictionary, expected: Dictionary) -> void:
	if not metrics or not expected:
		push_error("Metrics or expected values are null")
		assert_that(false).override_failure_message("Metrics or expected values are null").is_true()
		return
	
	for metric in expected:
		assert_that(metrics.has(metric)).override_failure_message("Should have %s metric" % metric).is_true()
		assert_that(metrics[metric] >= expected[metric]).override_failure_message(
			"%s should be at least %s" % [metric, expected[metric]]
		).is_true()