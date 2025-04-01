@tool
extends "res://tests/fixtures/specialized/enemy_test.gd"

# Import the Enemy class for type checking
const Enemy = preload("res://src/core/enemy/base/Enemy.gd")

const LARGE_GROUP_SIZE := 100
const PERFORMANCE_THRESHOLD := 16.67 # ms (targeting 60 FPS)

var _performance_monitor: Node
var _test_battlefield: Node2D

func before_each() -> void:
	await super.before_each()
	
	# Setup performance test environment
	_performance_monitor = Node.new()
	_performance_monitor.name = "PerformanceMonitor"
	add_child_autofree(_performance_monitor)
	
	_test_battlefield = Node2D.new()
	_test_battlefield.name = "TestBattlefield"
	add_child_autofree(_test_battlefield)
	
	await stabilize_engine()

func after_each() -> void:
	_performance_monitor = null
	_test_battlefield = null
	await super.after_each()

func test_large_group_creation() -> void:
	var start_time = Time.get_ticks_msec()
	
	var group = await _create_large_group(LARGE_GROUP_SIZE)
	
	var creation_time = Time.get_ticks_msec() - start_time
	assert_true(creation_time < PERFORMANCE_THRESHOLD,
		"Large group creation should be within performance threshold")

func test_large_group_movement() -> void:
	var group = await _create_large_group(LARGE_GROUP_SIZE)
	var start_time = Time.get_ticks_msec()
	
	_move_group(group)
	
	var movement_time = Time.get_ticks_msec() - start_time
	assert_true(movement_time < PERFORMANCE_THRESHOLD,
		"Large group movement should be within performance threshold")

func test_large_group_ai_decisions() -> void:
	var group = await _create_large_group(LARGE_GROUP_SIZE)
	var start_time = Time.get_ticks_msec()
	
	_process_group_ai(group)
	
	var ai_time = Time.get_ticks_msec() - start_time
	assert_true(ai_time < PERFORMANCE_THRESHOLD,
		"Large group AI processing should be within performance threshold")

func test_large_group_combat() -> void:
	var attackers = await _create_large_group(LARGE_GROUP_SIZE / 2)
	var defenders = await _create_large_group(LARGE_GROUP_SIZE / 2)
	var start_time = Time.get_ticks_msec()
	
	_process_group_combat(attackers, defenders)
	
	var combat_time = Time.get_ticks_msec() - start_time
	assert_true(combat_time < PERFORMANCE_THRESHOLD,
		"Large group combat should be within performance threshold")

func test_large_group_pathfinding() -> void:
	var group = await _create_large_group(LARGE_GROUP_SIZE)
	var start_time = Time.get_ticks_msec()
	
	_process_group_pathfinding(group)
	
	var pathfinding_time = Time.get_ticks_msec() - start_time
	assert_true(pathfinding_time < PERFORMANCE_THRESHOLD,
		"Large group pathfinding should be within performance threshold")

# Helper methods
# Returns an array of enemy nodes - using untyped array to avoid type checking errors
func _create_large_group(size: int) -> Array:
	var group = []
	for i in range(size):
		var enemy = await create_test_enemy()
		group.append(enemy)
	return group

# Takes an array of enemy nodes
func _move_group(group: Array) -> void:
	for enemy in group:
		enemy.position += Vector2(10, 10)

# Takes an array of enemy nodes
func _process_group_ai(group: Array) -> void:
	for enemy in group:
		# Use safer method calls to handle AI processing
		if enemy and enemy.has_method("get_state"):
			enemy.get_state() # Trigger AI processing
		elif enemy and enemy.has_method("process_ai"):
			enemy.process_ai()
		elif enemy and enemy.has_method("update_state"):
			enemy.update_state()

# Takes arrays of enemy nodes
func _process_group_combat(attackers: Array, defenders: Array) -> void:
	if defenders.size() == 0:
		return
		
	for attacker in attackers:
		# Use safer method calls to handle the attack
		if attacker and attacker.has_method("attack"):
			attacker.attack(defenders[0])
		elif attacker and attacker.has_method("take_damage"):
			# Fallback to direct damage if attack method doesn't exist
			defenders[0].take_damage(attacker.get_attack_damage() if attacker.has_method("get_attack_damage") else 5)

# Takes an array of enemy nodes
func _process_group_pathfinding(group: Array) -> void:
	var target_pos = Vector2(100, 100)
	for enemy in group:
		# Use safer method calls to handle pathfinding
		if enemy and enemy.has_method("move_to"):
			enemy.move_to(target_pos)
		elif enemy and enemy.has_method("navigate_to"):
			enemy.navigate_to(target_pos)
		elif enemy and enemy.has_method("set_position") or enemy.has_method("global_position"):
			# Direct position setting fallback
			enemy.global_position = target_pos
