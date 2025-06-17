@tool
extends "res://tests/fixtures/specialized/enemy_test.gd"

const LARGE_GROUP_SIZE := 100
const PERFORMANCE_THRESHOLD := 16.67 # ms (targeting 60 FPS)
const STABILIZE_TIME := 0.1 # seconds to stabilize engine

var _performance_monitor: Node
var _test_battlefield: Node2D
var _created_enemies: Array[Node2D] = []
var _enemy_manager: Node

func before_test() -> void:
	await super.before_test()
	
	# Initialize enemy manager with auto_free
	_enemy_manager = auto_free(Node.new())
	_enemy_manager.name = "EnemyManager"
	add_child(_enemy_manager)
	
	# Initialize performance monitor with auto_free
	_performance_monitor = auto_free(Node.new())
	_performance_monitor.name = "PerformanceMonitor"
	add_child(_performance_monitor)
	
	# Create test battlefield with auto_free
	_test_battlefield = auto_free(Node2D.new())
	_test_battlefield.name = "TestBattlefield"
	add_child(_test_battlefield)
	
	await stabilize_engine(STABILIZE_TIME)

func after_test() -> void:
	# Clean up all created enemies first
	for enemy in _created_enemies:
		if is_instance_valid(enemy):
			if enemy.get_parent():
				enemy.get_parent().remove_child(enemy)
			enemy.queue_free()
	_created_enemies.clear()
	
	# Clean up test battlefield
	if is_instance_valid(_test_battlefield):
		for child in _test_battlefield.get_children():
			if is_instance_valid(child):
				_test_battlefield.remove_child(child)
				child.queue_free()
		_test_battlefield.queue_free()
	_test_battlefield = null
	
	# Clean up enemy manager
	if is_instance_valid(_enemy_manager):
		if _enemy_manager.get_parent():
			_enemy_manager.get_parent().remove_child(_enemy_manager)
		_enemy_manager.queue_free()
	_enemy_manager = null
	
	# Clean up performance monitor
	if is_instance_valid(_performance_monitor):
		if _performance_monitor.get_parent():
			_performance_monitor.get_parent().remove_child(_performance_monitor)
		_performance_monitor.queue_free()
	_performance_monitor = null
	
	# Wait for cleanup to complete
	await get_tree().process_frame
	await get_tree().process_frame
	
	super.after_test()

func test_large_group_creation() -> void:
	var start_time = Time.get_ticks_msec()
	
	var group = _create_enemy_group(LARGE_GROUP_SIZE)
	
	var creation_time = Time.get_ticks_msec() - start_time
	assert_that(creation_time < PERFORMANCE_THRESHOLD).is_true()

func test_large_group_movement() -> void:
	var enemies = _create_enemy_group(LARGE_GROUP_SIZE)
	
	var metrics := await measure_performance(
		func() -> void:
			_simulate_enemy_movement(enemies)
			await get_tree().process_frame
	)
	
	verify_performance_metrics(metrics, {
		"average_frame_time": 50.0, # 50ms = ~20 FPS
		"maximum_frame_time": 100.0, # 100ms = ~10 FPS
		"memory_delta_kb": 512.0
	})

func test_large_group_ai_decisions() -> void:
	var enemies = _create_enemy_group(LARGE_GROUP_SIZE)
	
	var metrics := await measure_performance(
		func() -> void:
			_simulate_enemy_ai_decisions(enemies)
			await get_tree().process_frame
	)
	
	verify_performance_metrics(metrics, {
		"average_frame_time": 50.0, # 50ms = ~20 FPS
		"maximum_frame_time": 100.0, # 100ms = ~10 FPS
		"memory_delta_kb": 512.0
	})

func test_large_group_combat() -> void:
	var enemies = _create_enemy_group(LARGE_GROUP_SIZE)
	
	var metrics := await measure_performance(
		func() -> void:
			_simulate_enemy_combat(enemies)
			await get_tree().process_frame
	)
	
	verify_performance_metrics(metrics, {
		"average_frame_time": 50.0, # 50ms = ~20 FPS
		"maximum_frame_time": 100.0, # 100ms = ~10 FPS
		"memory_delta_kb": 512.0
	})

func test_large_group_pathfinding() -> void:
	var enemies = _create_enemy_group(LARGE_GROUP_SIZE)
	
	var metrics := await measure_performance(
		func() -> void:
			_simulate_enemy_pathfinding(enemies)
			await get_tree().process_frame
	)
	
	verify_performance_metrics(metrics, {
		"average_frame_time": 50.0, # 50ms = ~20 FPS
		"maximum_frame_time": 100.0, # 100ms = ~10 FPS
		"memory_delta_kb": 512.0
	})

# Helper methods
func _create_enemy_group(size: int) -> Array[Node2D]:
	var enemies: Array[Node2D] = []
	for i in range(size):
		var enemy = auto_free(Node2D.new())
		enemy.name = "Enemy_%d" % i
		
		# Set enemy properties as metadata
		enemy.set_meta("health", 5)
		enemy.set_meta("armor", 1)
		enemy.set_meta("weapon_skill", 2)
		enemy.set_meta("ai_state", "patrol")
		
		# Add to battlefield - auto_free will handle cleanup
		_test_battlefield.add_child(enemy)
		
		enemies.append(enemy)
		_created_enemies.append(enemy)
	
	return enemies

func _move_group(group: Array[Node2D]) -> void:
	for enemy in group:
		enemy.position += Vector2(10, 10)

func _process_group_ai(group: Array[Node2D]) -> void:
	for enemy in group:
		if enemy.has_method("get_state"):
			enemy.get_state() # Trigger AI processing

func _process_group_combat(attackers: Array[Node2D], defenders: Array[Node2D]) -> void:
	for attacker in attackers:
		if defenders.size() > 0 and attacker.has_method("attack"):
			attacker.attack(defenders[0])

func _process_group_pathfinding(group: Array[Node2D]) -> void:
	var target_pos = Vector2(100, 100)
	for enemy in group:
		if enemy.has_method("move_to"):
			enemy.move_to(target_pos)

func _simulate_enemy_movement(enemies: Array[Node2D]) -> void:
	for enemy in enemies:
		if is_instance_valid(enemy):
			# Simulate movement by changing position
			enemy.position += Vector2(randf_range(-10, 10), randf_range(-10, 10))

func _simulate_enemy_ai_decisions(enemies: Array[Node2D]) -> void:
	for enemy in enemies:
		if is_instance_valid(enemy):
			# Simulate AI decision making
			var states = ["patrol", "alert", "combat", "retreat"]
			enemy.set_meta("ai_state", states[randi() % states.size()])

func _simulate_enemy_combat(enemies: Array[Node2D]) -> void:
	for enemy in enemies:
		if is_instance_valid(enemy):
			# Simulate combat calculations
			var damage = randi_range(1, 3)
			var current_health = enemy.get_meta("health", 5)
			enemy.set_meta("health", max(0, current_health - damage))

func _simulate_enemy_pathfinding(enemies: Array[Node2D]) -> void:
	for enemy in enemies:
		if is_instance_valid(enemy):
			# Simulate pathfinding calculations
			var target_pos = Vector2(randf_range(0, 100), randf_range(0, 100))
			var path_length = enemy.position.distance_to(target_pos)
			enemy.set_meta("path_length", path_length)

func verify_performance_metrics(metrics: Dictionary, thresholds: Dictionary) -> void:
	# Use frame timing instead of FPS for headless test compatibility
	assert_that(metrics.average_frame_time).override_failure_message(
		"Average frame time should be below threshold"
	).is_less(thresholds.get("average_frame_time", 50.0))
	
	assert_that(metrics.maximum_frame_time).override_failure_message(
		"Maximum frame time should be below threshold"
	).is_less(thresholds.get("maximum_frame_time", 100.0))
	
	assert_that(metrics.memory_delta_kb).override_failure_message(
		"Memory delta should be below threshold"
	).is_less(thresholds.get("memory_delta_kb", 512.0))

# Performance measurement utilities - Headless compatible
func measure_performance(callable: Callable, iterations: int = 50) -> Dictionary:
	var frame_times: Array[float] = []
	var memory_samples: Array[float] = []
	
	for i in range(iterations):
		var frame_start = Time.get_ticks_msec()
		
		await callable.call()
		await get_tree().process_frame
		
		var frame_end = Time.get_ticks_msec()
		var frame_time = frame_end - frame_start
		frame_times.append(frame_time)
		
		memory_samples.append(Performance.get_monitor(Performance.MEMORY_STATIC))
		await stabilize_engine(STABILIZE_TIME)
	
	return {
		"average_frame_time": _calculate_average(frame_times),
		"minimum_frame_time": _calculate_minimum(frame_times),
		"maximum_frame_time": _calculate_maximum(frame_times),
		"memory_delta_kb": (_calculate_maximum(memory_samples) - _calculate_minimum(memory_samples)) / 1024.0
	}

# Statistical utilities
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
