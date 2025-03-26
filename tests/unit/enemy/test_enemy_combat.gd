@tool
extends "res://tests/fixtures/specialized/enemy_test.gd"

# Import the Enemy class for type checking
const Enemy = preload("res://src/core/enemy/Enemy.gd")

## Enemy Combat System Tests
##
## Tests enemy combat functionality including:
## - Combat initialization and state
## - Attack actions and cooldowns
## - Range calculations and targeting
## - Damage dealing and receiving
## - Combat AI behavior

# Type-safe instance variables
var _ai_manager: Node = null
var _tactical_ai: Node = null
var _battlefield_manager: Node = null
var _combat_manager: Node = null

# Lifecycle Methods
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

# Combat Initialization Tests
func test_enemy_combat_initialization() -> void:
	var enemy: Node = create_test_enemy(EnemyTestType.ELITE)
	assert_not_null(enemy, "Should create elite enemy")
	add_child_autofree(enemy)
	
	# Verify combat state
	verify_enemy_combat_state(enemy)
	
	# Verify initial combat capabilities
	var can_attack: bool = TypeSafeMixin._call_node_method_bool(enemy, "can_attack", [])
	assert_true(can_attack, "Elite enemy should be able to attack")

# Combat Action Tests
func test_enemy_basic_attack() -> void:
	var enemy: Node = create_test_enemy(EnemyTestType.ELITE)
	assert_not_null(enemy, "Should create elite enemy")
	add_child_autofree(enemy)
	
	var target: Node2D = Node2D.new()
	assert_not_null(target, "Should create target")
	add_child_autofree(target)
	
	# Test attack execution
	verify_enemy_combat(enemy, target)

func test_enemy_attack_cooldown() -> void:
	var enemy: Node = create_test_enemy(EnemyTestType.ELITE)
	assert_not_null(enemy, "Should create elite enemy")
	add_child_autofree(enemy)
	
	var target: Node2D = Node2D.new()
	assert_not_null(target, "Should create target")
	add_child_autofree(target)
	
	# First attack
	watch_signals(enemy)
	var attack_result: bool = TypeSafeMixin._call_node_method_bool(enemy, "attack", [target])
	assert_true(attack_result, "Should successfully execute first attack")
	verify_signal_emitted(enemy, "attack_executed")
	
	# Verify cooldown
	var can_attack: bool = TypeSafeMixin._call_node_method_bool(enemy, "can_attack", [])
	assert_false(can_attack, "Should not be able to attack during cooldown")
	
	# Wait for cooldown
	await get_tree().create_timer(1.0).timeout
	can_attack = TypeSafeMixin._call_node_method_bool(enemy, "can_attack", [])
	assert_true(can_attack, "Should be able to attack after cooldown")

# Combat Range Tests
func test_enemy_attack_range() -> void:
	var enemy: Node = create_test_enemy(EnemyTestType.ELITE)
	assert_not_null(enemy, "Should create elite enemy")
	add_child_autofree(enemy)
	
	var target: Node2D = Node2D.new()
	assert_not_null(target, "Should create target")
	add_child_autofree(target)
	
	# Test out of range
	enemy.position = Vector2.ZERO
	target.position = Vector2(1000, 1000)
	var in_range: bool = TypeSafeMixin._call_node_method_bool(enemy, "is_target_in_range", [target])
	assert_false(in_range, "Target should be out of range")
	
	# Test in range
	target.position = Vector2(50, 50)
	in_range = TypeSafeMixin._call_node_method_bool(enemy, "is_target_in_range", [target])
	assert_true(in_range, "Target should be in range")

func test_enemy_attack_angle() -> void:
	var enemy: Node = create_test_enemy(EnemyTestType.ELITE)
	assert_not_null(enemy, "Should create elite enemy")
	add_child_autofree(enemy)
	
	var target: Node2D = Node2D.new()
	assert_not_null(target, "Should create target")
	add_child_autofree(target)
	
	# Test front attack
	enemy.rotation = 0
	target.position = Vector2(50, 0)
	var can_hit: bool = TypeSafeMixin._call_node_method_bool(enemy, "can_hit_target", [target])
	assert_true(can_hit, "Should be able to hit target in front")
	
	# Test rear attack
	target.position = Vector2(-50, 0)
	can_hit = TypeSafeMixin._call_node_method_bool(enemy, "can_hit_target", [target])
	assert_false(can_hit, "Should not be able to hit target from behind")

# Combat Damage Tests
func test_enemy_damage_dealing() -> void:
	var enemy: Node = create_test_enemy(EnemyTestType.ELITE)
	assert_not_null(enemy, "Should create elite enemy")
	add_child_autofree(enemy)
	
	var target: Node2D = Node2D.new()
	assert_not_null(target, "Should create target")
	add_child_autofree(target)
	
	# Setup target health
	TypeSafeMixin._call_node_method_bool(target, "set_health", [100.0])
	var initial_health: float = TypeSafeMixin._safe_cast_float(TypeSafeMixin._call_node_method(target, "get_health", []))
	
	# Execute attack
	watch_signals(enemy)
	TypeSafeMixin._call_node_method_bool(enemy, "attack", [target])
	verify_signal_emitted(enemy, "attack_executed")
	
	# Verify damage
	var final_health: float = TypeSafeMixin._safe_cast_float(TypeSafeMixin._call_node_method(target, "get_health", []))
	assert_true(final_health < initial_health, "Target should take damage from attack")

# Combat AI Tests
func test_enemy_target_selection() -> void:
	var enemy: Node = create_test_enemy(EnemyTestType.ELITE)
	assert_not_null(enemy, "Should create elite enemy")
	add_child_autofree(enemy)
	
	var target1: Node2D = Node2D.new()
	var target2: Node2D = Node2D.new()
	add_child_autofree(target1)
	add_child_autofree(target2)
	
	# Setup targets
	target1.position = Vector2(50, 0) # Close target
	target2.position = Vector2(200, 0) # Far target
	TypeSafeMixin._call_node_method_bool(target1, "set_health", [50.0]) # Weak target
	TypeSafeMixin._call_node_method_bool(target2, "set_health", [100.0]) # Strong target
	
	# Test target selection
	var selected_target: Node2D = TypeSafeMixin._call_node_method(enemy, "select_best_target", [[target1, target2]])
	assert_eq(selected_target, target1, "Should select closer, weaker target")

# Mobile Performance Tests
func test_enemy_combat_performance() -> void:
	var enemy: Node = create_test_enemy(EnemyTestType.ELITE)
	assert_not_null(enemy, "Should create elite enemy")
	add_child_autofree(enemy)
	
	var target: Node2D = Node2D.new()
	assert_not_null(target, "Should create target")
	add_child_autofree(target)
	
	# Measure combat performance
	var metrics := await measure_enemy_performance()
	verify_performance_metrics(metrics, {
		"average_fps": 30.0,
		"minimum_fps": 20.0,
		"memory_delta_kb": 1024.0
	})

# Helper Methods
func verify_enemy_combat_state(enemy: Node) -> void:
	if not enemy:
		push_error("Enemy not initialized")
		return
		
	# Verify combat properties
	assert_true(enemy.has_method("can_attack"), "Should have attack capability check")
	assert_true(enemy.has_method("is_target_in_range"), "Should have range check")
	assert_true(enemy.has_method("get_attack_damage"), "Should have damage calculation")
	
	# Verify combat signals
	var required_signals := [
		"attack_started",
		"attack_executed",
		"attack_completed",
		"target_acquired",
		"target_lost"
	]
	verify_enemy_signals(enemy, required_signals)

# Helper method to verify that the enemy has the expected signals
func verify_enemy_signals(enemy: Node, required_signals: Array) -> void:
	if not enemy:
		push_error("Enemy not initialized")
		return
		
	for signal_name in required_signals:
		assert_true(enemy.has_signal(signal_name),
			"Enemy should have signal: %s" % signal_name)
