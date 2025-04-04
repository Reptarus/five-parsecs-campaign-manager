@tool
extends "res://tests/fixtures/specialized/enemy_test.gd"

# Import the Enemy class for type checking
const Enemy = preload("res://src/core/enemy/base/Enemy.gd")

# Type-safe instance variables for pathfinding testing
var _navigation_manager: Node = null
var _test_map: Node2D = null
var _pathfinding_system: Node = null
var _test_enemy: Enemy = null
var _test_obstacles: Array[Node2D] = []

# Constants for pathfinding tests
const TEST_START_POS := Vector2(0, 0)
const TEST_END_POS := Vector2(10, 10)
const TEST_PATH := [Vector2(0, 0), Vector2(5, 5), Vector2(10, 10)]
const TEST_COMPLEX_PATH := [Vector2(0, 0), Vector2(2, 2), Vector2(4, 4), Vector2(4, 6), Vector2(6, 8), Vector2(8, 8), Vector2(10, 10)]
const OBSTACLE_SIZE := Vector2(2, 2)

# Lifecycle Methods
func before_each() -> void:
	await super.before_each()
	
	# Setup navigation test environment
	_navigation_manager = Node.new()
	if not _navigation_manager:
		push_error("Failed to create navigation manager")
		return
	_navigation_manager.name = "NavigationManager"
	add_child_autofree(_navigation_manager)
	track_test_node(_navigation_manager)
	
	_test_map = Node2D.new()
	if not _test_map:
		push_error("Failed to create test map")
		return
	_test_map.name = "TestMap"
	add_child_autofree(_test_map)
	track_test_node(_test_map)
	
	await stabilize_engine(STABILIZE_TIME)

func after_each() -> void:
	_navigation_manager = null
	_test_map = null
	await super.after_each()

# Core Pathfinding Tests
func test_pathfinding_initialization() -> void:
	var enemy := create_test_enemy()
	assert_not_null(enemy, "Enemy should be created")
	assert_not_null(enemy.get_node("NavigationAgent2D"),
		"Enemy should have a navigation agent")

func test_path_calculation() -> void:
	var enemy := create_test_enemy()
	assert_not_null(enemy, "Enemy should be created for path calculation")
	
	enemy.position = TEST_START_POS
	var path: Array = TypeSafeMixin._call_node_method_array(enemy, "calculate_path", [TEST_END_POS])
	
	assert_not_null(path, "Path should be calculated")
	assert_true(path.size() > 0, "Path should contain points")
	assert_true(path[0].distance_to(TEST_START_POS) < 0.1,
		"Path should start near the enemy position")

func test_path_following_detailed() -> void:
	var enemy := create_test_enemy()
	assert_not_null(enemy, "Enemy should be created for path following")
	
	enemy.position = TEST_PATH[0]
	var success: bool = TypeSafeMixin._call_node_method_bool(enemy, "follow_path", [TEST_PATH])
	
	assert_true(success, "Enemy should start following path")
	assert_true(enemy.is_moving(), "Enemy should be in moving state")

# Advanced Pathfinding Tests
func test_obstacle_avoidance() -> void:
	var enemy := create_test_enemy()
	assert_not_null(enemy, "Enemy should be created for obstacle avoidance")
	
	# Create test obstacle
	var obstacle: StaticBody2D = StaticBody2D.new()
	var collision: CollisionShape2D = CollisionShape2D.new()
	var shape: RectangleShape2D = RectangleShape2D.new()
	shape.size = OBSTACLE_SIZE
	collision.shape = shape
	obstacle.add_child(collision)
	_test_map.add_child(obstacle)
	track_test_node(obstacle)
	
	# Test path around obstacle
	enemy.position = TEST_START_POS
	obstacle.position = (TEST_START_POS + TEST_END_POS) / 2
	var path: Array = TypeSafeMixin._call_node_method_array(enemy, "calculate_path", [TEST_END_POS])
	
	assert_not_null(path, "Path should be calculated around obstacle")
	assert_true(path.size() > 2, "Path should have additional points to avoid obstacle")

func test_path_recalculation() -> void:
	var enemy := create_test_enemy()
	assert_not_null(enemy, "Enemy should be created for path recalculation")
	
	enemy.position = TEST_START_POS
	var initial_path: Array = TypeSafeMixin._call_node_method_array(enemy, "calculate_path", [TEST_END_POS])
	
	# Add obstacle to force recalculation
	var obstacle: StaticBody2D = StaticBody2D.new()
	var collision: CollisionShape2D = CollisionShape2D.new()
	var shape: RectangleShape2D = RectangleShape2D.new()
	shape.size = OBSTACLE_SIZE
	collision.shape = shape
	obstacle.add_child(collision)
	_test_map.add_child(obstacle)
	track_test_node(obstacle)
	
	obstacle.position = initial_path[initial_path.size() / 2]
	var new_path: Array = TypeSafeMixin._call_node_method_array(enemy, "calculate_path", [TEST_END_POS])
	
	assert_not_null(new_path, "New path should be calculated")
	assert_ne(initial_path, new_path, "New path should be different from initial path")

# Mobile Performance Tests
func test_movement_cost() -> void:
	var enemy := create_test_enemy()
	assert_not_null(enemy, "Enemy should be created for movement cost test")
	
	enemy.position = TEST_START_POS
	var start_time: float = Time.get_ticks_msec()
	var path: Array = TypeSafeMixin._call_node_method_array(enemy, "calculate_path", [TEST_END_POS])
	var end_time: float = Time.get_ticks_msec()
	
	assert_not_null(path, "Path should be calculated for movement cost")
	assert_true((end_time - start_time) < 100.0,
		"Path calculation should complete within reasonable time")

# Error Handling Tests
func test_invalid_path() -> void:
	var enemy := create_test_enemy()
	assert_not_null(enemy, "Enemy should be created for invalid path test")
	
	# Test with invalid destination
	var invalid_pos := Vector2(-1000, -1000)
	var path: Array = TypeSafeMixin._call_node_method_array(enemy, "calculate_path", [invalid_pos])
	
	assert_true(path.is_empty(), "Path should be empty for invalid destination")
	assert_false(enemy.is_moving(), "Enemy should not move with invalid path")

func test_path_cost() -> void:
	var enemy := create_test_enemy()
	assert_not_null(enemy, "Enemy should be created for path cost calculation")
	
	enemy.position = TEST_START_POS
	var cost: float = GutCompatibility._call_node_method_float(enemy, "calculate_path_cost", [TEST_END_POS])
	
	assert_gt(cost, 0.0, "Path cost should be positive")
	assert_le(cost, 1000.0, "Path cost should be reasonable")

func test_path_validation() -> void:
	var enemy := create_test_enemy()
	assert_not_null(enemy, "Enemy should be created for path validation")
	
	enemy.position = TEST_START_POS
	var is_valid: bool = TypeSafeMixin._call_node_method_bool(enemy, "is_path_valid", [TEST_PATH])
	
	assert_true(is_valid, "Path should be valid")

func test_path_simplification() -> void:
	var enemy := create_test_enemy()
	assert_not_null(enemy, "Enemy should be created for path simplification")
	
	# Verify implementation exists
	assert_true(enemy.has_method("simplify_path"),
		"Enemy should implement path simplification")
	
	# Create complex test path
	var is_valid = TypeSafeMixin._call_node_method_bool(enemy, "set_path", [TEST_COMPLEX_PATH])
	assert_true(is_valid, "Should be able to set test path")
	
	# Simplify path
	var simplified = TypeSafeMixin._call_node_method_array(enemy, "simplify_path", [TEST_COMPLEX_PATH])
	assert_not_null(simplified, "Should return simplified path")
	assert_true(simplified.size() < TEST_COMPLEX_PATH.size(),
		"Simplified path should have fewer points than complex path")

# Test NavigationAgent component
func test_navigation_agent_initialization() -> void:
	var enemy := create_test_enemy()
	assert_not_null(enemy, "Should create enemy")
	add_child_autofree(enemy)
	
	var nav_agent = enemy.get_node_or_null("NavigationAgent2D")
	assert_not_null(nav_agent, "Enemy should have NavigationAgent2D")

# Test pathfinding physics
func test_pathfinding_physics_layer() -> void:
	var enemy := create_test_enemy()
	assert_not_null(enemy, "Should create enemy")
	add_child_autofree(enemy)
	
	# Skip test if navigation agent is not available
	if not enemy.has_node("NavigationAgent2D"):
		pending("NavigationAgent2D not implemented")
		return
		
	# Check for physics layer properties
	var nav_agent = enemy.get_node("NavigationAgent2D")
	assert_true(nav_agent.has_method("get_navigation_layer") or
		nav_agent.has_property("navigation_layers"),
		"Navigation agent should have navigation layer property")

# Test basic pathfinding
func test_basic_pathfinding() -> void:
	var enemy := create_test_enemy()
	assert_not_null(enemy, "Should create enemy")
	add_child_autofree(enemy)
	
	# Skip test if required methods aren't implemented
	if not enemy.has_method("navigate_to"):
		pending("Navigate to target not implemented")
		return
		
	# Test basic navigation
	var target_pos = Vector2(5, 5)
	var success = TypeSafeMixin._call_node_method_bool(enemy, "navigate_to", [target_pos])
	assert_true(success, "Enemy should start navigating to target")

# Test path following
func test_path_advanced_following() -> void:
	var enemy := create_test_enemy()
	assert_not_null(enemy, "Should create enemy")
	add_child_autofree(enemy)
	
	# Skip test if required methods aren't implemented
	if not enemy.has_method("follow_path") or not enemy.has_method("is_path_complete"):
		pending("Path following methods not implemented")
		return
		
	# Setup test path
	enemy.position = TEST_PATH[0]
	var success = TypeSafeMixin._call_node_method_bool(enemy, "follow_path", [TEST_PATH])
	assert_true(success, "Enemy should start following path")

# Test path finding around obstacles
func test_pathfinding_obstacles() -> void:
	var enemy := create_test_enemy()
	assert_not_null(enemy, "Should create enemy")
	add_child_autofree(enemy)
	
	# Skip test if required methods aren't implemented
	if not enemy.has_method("calculate_path"):
		pending("Path calculation not implemented")
		return
		
	# Create test obstacle
	var obstacle = StaticBody2D.new()
	obstacle.position = Vector2(5, 5)
	var collision = CollisionShape2D.new()
	var shape = RectangleShape2D.new()
	shape.size = Vector2(2, 2)
	collision.shape = shape
	obstacle.add_child(collision)
	add_child_autofree(obstacle)
	
	# Calculate path around obstacle
	enemy.position = TEST_START_POS
	var path = TypeSafeMixin._call_node_method_array(enemy, "calculate_path", [TEST_END_POS])
	assert_true(path.size() > 0, "Should find path around obstacle")

# Test path re-calculation
func test_path_recalculation_advanced() -> void:
	var enemy := create_test_enemy()
	assert_not_null(enemy, "Should create enemy")
	add_child_autofree(enemy)
	
	# Skip test if required methods aren't implemented
	if not enemy.has_method("recalculate_path"):
		pending("Path recalculation not implemented")
		return
		
	# Test path recalculation
	enemy.position = TEST_START_POS
	var success = TypeSafeMixin._call_node_method_bool(enemy, "recalculate_path", [TEST_END_POS])
	assert_true(success, "Enemy should recalculate path")

# Test group movement
func test_group_movement() -> void:
	var enemy := create_test_enemy()
	assert_not_null(enemy, "Should create enemy")
	add_child_autofree(enemy)
	
	# Skip test if required methods aren't implemented
	if not enemy.has_method("move_in_formation"):
		pending("Formation movement not implemented")
		return
		
	# Create test group
	var group = []
	for i in range(3):
		var follower = create_test_enemy()
		assert_not_null(follower, "Should create follower")
		add_child_autofree(follower)
		group.append(follower)
	
	# Test formation movement
	var success = TypeSafeMixin._call_node_method_bool(enemy, "move_in_formation", [group, TEST_END_POS])
	assert_true(success, "Group should move in formation")

# Test navigation path cost
func test_navigation_path_cost() -> void:
	var enemy := create_test_enemy()
	assert_not_null(enemy, "Should create enemy")
	add_child_autofree(enemy)
	
	# Skip test if required methods aren't implemented
	if not enemy.has_method("calculate_path_cost"):
		pending("Path cost calculation not implemented")
		return
		
	# Test path cost calculation
	enemy.position = TEST_START_POS
	var cost = GutCompatibility._call_node_method_float(enemy, "calculate_path_cost", [TEST_END_POS])
	assert_gt(cost, 0.0, "Path cost should be positive")

# Test pathfinding visualization
func test_pathfinding_debug_display() -> void:
	var enemy := create_test_enemy()
	assert_not_null(enemy, "Should create enemy")
	add_child_autofree(enemy)
	
	# ... existing code ...

# Test navigation agent properties
func test_navigation_agent_properties() -> void:
	var enemy := create_test_enemy()
	assert_not_null(enemy, "Should create enemy")
	add_child_autofree(enemy)
	
	# ... existing code ...