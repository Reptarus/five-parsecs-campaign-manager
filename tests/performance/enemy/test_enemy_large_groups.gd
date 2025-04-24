@tool
extends "res://tests/fixtures/helpers/enemy_test_helper.gd"

# Performance test configuration
const PERFORMANCE_THRESHOLDS = {
	"small_group": {
		"create_time": 0.5, # seconds
		"process_time": 0.05, # seconds per frame
		"memory_usage": 10 # MB
	},
	"medium_group": {
		"create_time": 1.5,
		"process_time": 0.1,
		"memory_usage": 25
	},
	"large_group": {
		"create_time": 3.0,
		"process_time": 0.2,
		"memory_usage": 50
	}
}

# Define missing constants
const PERFORMANCE_THRESHOLD_MS = 16.0 # 60fps = ~16ms per frame
const MAX_FRAME_TIME_MS = 32.0 # 30fps minimum
const MAX_ENEMIES = 30 # Maximum number of enemies to test with

# Test variables
var _enemy_counts = {
	"small": 10,
	"medium": 50,
	"large": 100
}

# Use explicit preloads instead of global class names
const TestEnums = preload("res://tests/fixtures/base/test_helper.gd")
const GameEnums = preload("res://src/core/systems/GameEnums.gd")

# Game objects - rename _game_state to avoid conflict with parent class
var _performance_game_state = null
var _campaign = null
var _mission = null
var _mission_manager = null
var _enemy_manager = null
var _enemy_groups := []

# Performance tracking
var _performance_timer := 0.0
var _frame_count := 0
var _total_process_time := 0.0
var _max_frame_time := 0.0

func before_all() -> void:
	# Call parent implementation
	super.before_all()
	
	# Check if we can run these tests
	var required_scripts = [
		"res://src/core/enemy/base/EnemyNode.gd",
		"res://src/core/enemy/EnemyData.gd",
		"res://src/core/enemy/managers/EnemyManager.gd"
	]
	
	for script_path in required_scripts:
		if not ResourceLoader.exists(script_path):
			push_warning("Required script %s not found, some tests may fail" % script_path)

func before_each() -> void:
	# Call parent implementation first
	await super.before_each()
	
	# Clear enemy groups
	_enemy_groups.clear()
	
	# Reset performance tracking
	_performance_timer = 0.0
	_frame_count = 0
	_total_process_time = 0.0
	_max_frame_time = 0.0
	
	# Create game state
	_setup_game_state()
	
	await stabilize_engine()

func after_each() -> void:
	# Clean up any enemy groups
	for group in _enemy_groups:
		for enemy in group:
			if enemy is Node and is_instance_valid(enemy) and not enemy.is_queued_for_deletion():
				enemy.queue_free()
	_enemy_groups.clear()
	
	# Reset references
	_performance_game_state = null
	_campaign = null
	_mission = null
	_mission_manager = null
	_enemy_manager = null
	
	# Call parent implementation
	await super.after_each()

func _setup_game_state() -> void:
	# Create game state - use helper function from parent class
	_performance_game_state = setup_test_game_state()
	
	# Create campaign
	var CampaignClass = load("res://src/core/campaign/GameCampaignManager.gd")
	if CampaignClass:
		_campaign = CampaignClass.new()
		track_test_resource(_campaign)
		
		# Initialize campaign with test data
		var campaign_data = {
			"campaign_id": "perf_test_" + str(randi()),
			"campaign_name": "Performance Test",
			"difficulty": 1,
			"credits": 1000,
			"supplies": 5,
			"turn": 1
		}
		
		if _campaign.has_method("initialize_from_data"):
			_campaign.initialize_from_data(campaign_data)
		elif _campaign.has_method("initialize"):
			_campaign.initialize()
		
		# Add campaign to game state
		if _performance_game_state.has_method("set_current_campaign"):
			_performance_game_state.set_current_campaign(_campaign)
		elif _performance_game_state.get("current_campaign") != null:
			_performance_game_state.current_campaign = _campaign
	
	# Create mission manager
	var MissionManagerClass = load("res://src/core/mission/MissionManager.gd")
	if MissionManagerClass:
		_mission_manager = MissionManagerClass.new()
		if _performance_game_state and _performance_game_state.has_method("add_child"):
			_performance_game_state.add_child(_mission_manager)
		else:
			add_child_autofree(_mission_manager)
		track_test_node(_mission_manager)
	
	# Create enemy manager
	var EnemyManagerClass = load("res://src/core/enemy/managers/EnemyManager.gd")
	if EnemyManagerClass:
		_enemy_manager = EnemyManagerClass.new()
		if _performance_game_state and _performance_game_state.has_method("add_child"):
			_performance_game_state.add_child(_enemy_manager)
		else:
			add_child_autofree(_enemy_manager)
		track_test_node(_enemy_manager)

func _create_enemy_group(count: int) -> Array:
	var enemies = []
	
	# Create enemies
	for i in range(count):
		# Create enemy data with proper naming
		var enemy_data = create_test_enemy_resource({
			"enemy_id": "perf_enemy_" + str(i),
			"enemy_name": "Performance Enemy " + str(i), # Use enemy_name, not name
			"health": 100,
			"max_health": 100,
			"damage": 10,
			"armor": 5
		})
		
		# Create enemy node using the parent class helper method
		# which will properly attach the enemy_data resource
		var enemy = create_test_enemy(enemy_data)
		
		# Position enemy if it was created successfully
		if enemy:
			enemy.position = Vector2(randf_range(-500, 500), randf_range(-500, 500))
			enemies.append(enemy)
	
	# Track the group
	_enemy_groups.append(enemies)
	
	return enemies

func _check_performance_threshold(operation_name: String, elapsed_ms: float, threshold_ms: float = PERFORMANCE_THRESHOLD_MS) -> void:
	assert_lt(elapsed_ms, threshold_ms,
		"Performance check failed for %s: %.2f ms (threshold: %.2f ms)" % [operation_name, elapsed_ms, threshold_ms])

func _start_performance_timer() -> void:
	_performance_timer = Time.get_ticks_msec()

func _end_performance_timer(operation_name: String, threshold_ms: float = PERFORMANCE_THRESHOLD_MS) -> float:
	var elapsed_ms = Time.get_ticks_msec() - _performance_timer
	_check_performance_threshold(operation_name, elapsed_ms, threshold_ms)
	return elapsed_ms

func _process_frame(delta: float = 0.016) -> void:
	# Start frame timer
	var frame_start = Time.get_ticks_msec()
	
	# Process all nodes in the scene
	get_tree().root.propagate_notification(Node.NOTIFICATION_PROCESS)
	
	# Calculate frame time
	var frame_time = Time.get_ticks_msec() - frame_start
	_total_process_time += frame_time
	_max_frame_time = max(_max_frame_time, frame_time)
	_frame_count += 1
	
	# Process physics if needed
	if delta > 0:
		get_tree().root.propagate_notification(Node.NOTIFICATION_PHYSICS_PROCESS)

func test_create_large_enemy_group() -> void:
	_start_performance_timer()
	
	# Create a large group of enemies
	var enemies = _create_enemy_group(MAX_ENEMIES)
	
	var creation_time = _end_performance_timer("Creating %d enemies" % MAX_ENEMIES)
	
	# Verify group creation
	assert_eq(enemies.size(), MAX_ENEMIES, "Should create exactly %d enemies" % MAX_ENEMIES)
	
	# Verify all enemies are valid
	var valid_count = 0
	for enemy in enemies:
		if is_instance_valid(enemy):
			valid_count += 1
	
	assert_eq(valid_count, MAX_ENEMIES, "All %d enemies should be valid instances" % MAX_ENEMIES)
	
	# Print performance metrics
	gut.p("Created %d enemies in %.2f ms (%.2f ms per enemy)" %
		[MAX_ENEMIES, creation_time, creation_time / MAX_ENEMIES])

func test_move_large_enemy_group() -> void:
	# Create a large group of enemies
	var enemies = _create_enemy_group(MAX_ENEMIES)
	
	# Wait for enemies to be added to scene
	await stabilize_engine()
	
	# Start performance timer
	_start_performance_timer()
	
	# Move all enemies in a random direction
	for enemy in enemies:
		if is_instance_valid(enemy):
			var move_direction = Vector2(randf_range(-1, 1), randf_range(-1, 1)).normalized()
			var move_distance = randf_range(50, 100)
			
			# Use direct position update for performance testing
			enemy.position += move_direction * move_distance
	
	var move_time = _end_performance_timer("Moving %d enemies" % MAX_ENEMIES)
	
	# Process a few frames to let everything settle
	for i in range(5):
		_process_frame()
		await get_tree().process_frame
	
	# Verify movement succeeded (all enemies still valid)
	var valid_count = 0
	for enemy in enemies:
		if is_instance_valid(enemy):
			valid_count += 1
	
	assert_eq(valid_count, MAX_ENEMIES, "All %d enemies should remain valid after moving" % MAX_ENEMIES)
	
	# Print performance metrics
	gut.p("Moved %d enemies in %.2f ms (%.2f ms per enemy)" %
		[MAX_ENEMIES, move_time, move_time / MAX_ENEMIES])

func test_process_large_enemy_group() -> void:
	# Create a large group of enemies
	var enemies = _create_enemy_group(MAX_ENEMIES)
	
	# Wait for enemies to be added to scene
	await stabilize_engine()
	
	# Process several frames and measure performance
	_frame_count = 0
	_total_process_time = 0
	_max_frame_time = 0
	
	# Process 10 frames
	for i in range(10):
		_start_performance_timer()
		_process_frame()
		var frame_time = _end_performance_timer("Processing frame %d with %d enemies" % [i, MAX_ENEMIES], MAX_FRAME_TIME_MS)
		await get_tree().process_frame
	
	# Calculate average frame time
	var avg_frame_time = _total_process_time / max(1, _frame_count)
	
	# Verify frame times are acceptable
	assert_lt(avg_frame_time, MAX_FRAME_TIME_MS,
		"Average frame time (%.2f ms) should be below threshold (%.2f ms)" % [avg_frame_time, MAX_FRAME_TIME_MS])
	
	assert_lt(_max_frame_time, MAX_FRAME_TIME_MS * 1.5,
		"Max frame time (%.2f ms) should be below threshold (%.2f ms)" % [_max_frame_time, MAX_FRAME_TIME_MS * 1.5])
	
	# Print performance metrics
	gut.p("Processed %d frames with %d enemies" % [_frame_count, MAX_ENEMIES])
	gut.p("Average frame time: %.2f ms, Max frame time: %.2f ms" % [avg_frame_time, _max_frame_time])

func test_enemy_ai_decision_making() -> void:
	# Create a smaller group for AI testing (fewer enemies for faster test)
	var enemy_count = 10
	var enemies = _create_enemy_group(enemy_count)
	
	# Wait for enemies to be added to scene
	await stabilize_engine()
	
	# Try to simulate AI decision making
	_start_performance_timer()
	
	for enemy in enemies:
		if is_instance_valid(enemy):
			# Create a simulated AI decision context
			var decision_context = {
				"target_position": Vector2(randf_range(-500, 500), randf_range(-500, 500)),
				"current_health_percent": randf_range(0.1, 1.0),
				"visible_targets": randi_range(0, 3),
				"distance_to_closest_target": randf_range(50, 500)
			}
			
			# Make a simulated decision
			var decision = _make_simulated_ai_decision(enemy, decision_context)
			
			# Apply the decision effect
			_apply_simulated_decision(enemy, decision)
	
	var decision_time = _end_performance_timer("AI decisions for %d enemies" % enemy_count)
	
	# Print performance metrics
	gut.p("Made AI decisions for %d enemies in %.2f ms (%.2f ms per enemy)" %
		[enemy_count, decision_time, decision_time / enemy_count])

func _make_simulated_ai_decision(enemy, context) -> Dictionary:
	# This is a simplified AI decision model for performance testing
	var decision = {
		"type": "none",
		"target_position": Vector2.ZERO,
		"action": "none"
	}
	
	# Basic decision making based on context
	if context.current_health_percent < 0.3:
		decision.type = "flee"
		decision.action = "move"
		# Move away from targets
		decision.target_position = - context.target_position.normalized() * 100
	elif context.visible_targets > 0 and context.distance_to_closest_target < 200:
		decision.type = "attack"
		decision.action = "attack"
		decision.target_position = context.target_position
	else:
		decision.type = "patrol"
		decision.action = "move"
		decision.target_position = context.target_position
	
	return decision

func _apply_simulated_decision(enemy, decision) -> void:
	# Apply the decision effect to the enemy
	match decision.type:
		"move", "patrol", "flee":
			# Update position based on decision
			enemy.position = enemy.position.move_toward(
				enemy.position + decision.target_position,
				50.0
			)
		"attack":
			# Simulate attack logic
			pass
		_:
			# Default behavior
			pass

func test_enemy_combat_processing() -> void:
	# Create two smaller groups for combat testing
	var group_size = 5
	var enemies_a = _create_enemy_group(group_size)
	var enemies_b = _create_enemy_group(group_size)
	
	# Position groups opposite each other
	for i in range(group_size):
		if i < enemies_a.size() and is_instance_valid(enemies_a[i]):
			enemies_a[i].position = Vector2(-200, i * 50 - 100)
		
		if i < enemies_b.size() and is_instance_valid(enemies_b[i]):
			enemies_b[i].position = Vector2(200, i * 50 - 100)
	
	# Wait for enemies to be added to scene
	await stabilize_engine()
	
	# Simulate combat between groups
	_start_performance_timer()
	
	# Process several rounds of combat
	for round in range(3):
		# Group A attacks group B
		for attacker in enemies_a:
			if not is_instance_valid(attacker):
				continue
				
			# Find closest enemy in group B
			var closest_target = null
			var closest_distance = INF
			
			for target in enemies_b:
				if not is_instance_valid(target):
					continue
					
				var distance = attacker.position.distance_to(target.position)
				if distance < closest_distance:
					closest_distance = distance
					closest_target = target
			
			# Attack if target found
			if closest_target and closest_target.has_method("take_damage"):
				var damage = 10 + randi() % 10 # Random damage between 10-19
				closest_target.take_damage(damage)
		
		# Group B attacks group A
		for attacker in enemies_b:
			if not is_instance_valid(attacker):
				continue
				
			# Find closest enemy in group A
			var closest_target = null
			var closest_distance = INF
			
			for target in enemies_a:
				if not is_instance_valid(target):
					continue
					
				var distance = attacker.position.distance_to(target.position)
				if distance < closest_distance:
					closest_distance = distance
					closest_target = target
			
			# Attack if target found
			if closest_target and closest_target.has_method("take_damage"):
				var damage = 10 + randi() % 10 # Random damage between 10-19
				closest_target.take_damage(damage)
		
		# Process a frame between combat rounds
		_process_frame()
		await get_tree().process_frame
	
	var combat_time = _end_performance_timer("Combat processing for %d enemies" % (group_size * 2))
	
	# Verify combat effects (some enemies should have taken damage)
	var damaged_count = 0
	
	for enemy in enemies_a + enemies_b:
		if is_instance_valid(enemy) and enemy.has_method("get_health"):
			if enemy.get_health() < enemy.get("max_health"):
				damaged_count += 1
	
	assert_gt(damaged_count, 0, "At least some enemies should have taken damage during combat")
	
	# Print performance metrics
	gut.p("Processed combat for %d enemies in %.2f ms (%.2f ms per enemy)" %
		[group_size * 2, combat_time, combat_time / (group_size * 2)])

# Performance test helpers
func _measure_creation_time(count: int) -> float:
	var start_time = Time.get_ticks_msec()
	
	# Create group
	var group = create_test_enemy_group(count)
	
	var end_time = Time.get_ticks_msec()
	var creation_time = (end_time - start_time) / 1000.0
	
	return creation_time

# Performance tests
func test_small_group_creation() -> void:
	var time = _measure_creation_time(_enemy_counts.small)
	assert_true(time < PERFORMANCE_THRESHOLDS.small_group.create_time,
		"Small group creation time should be under threshold")

func test_medium_group_creation() -> void:
	var time = _measure_creation_time(_enemy_counts.medium)
	assert_true(time < PERFORMANCE_THRESHOLDS.medium_group.create_time,
		"Medium group creation time should be under threshold")

func test_large_group_creation() -> void:
	var time = _measure_creation_time(_enemy_counts.large)
	assert_true(time < PERFORMANCE_THRESHOLDS.large_group.create_time,
		"Large group creation time should be under threshold")
