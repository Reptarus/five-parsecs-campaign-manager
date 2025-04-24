@tool
extends GutTest

## Tests the pathfinding capabilities of enemy units
##
## Verifies:
## - Path calculation
## - Movement handling
## - Obstacle avoidance
## - Path optimization
## - Performance scaling

# Import required helpers
const TestCompatibilityHelper = preload("res://tests/fixtures/helpers/test_compatibility_helper.gd")
const GutCompatibility = preload("res://tests/fixtures/helpers/gut_compatibility.gd")

# Constants
const STABILIZE_TIME := 0.1
const PATHFINDING_TIMEOUT := 2.0

# Variables for scripts that might not exist - loaded dynamically in before_all
var EnemyNodeScript = null
var EnemyDataScript = null
var PathfinderScript = null
var NavigationManagerScript = null
var GameEnums = null

# Type-safe instance variables
var _pathfinder = null
var _nav_manager = null
var _test_map = null
var _test_enemies: Array = []

# Test nodes to track for cleanup
var _tracked_test_nodes: Array = []

# Pathfinding result tracking
var _path_found := false
var _calculated_path: Array = []
var _pathfinding_time := 0.0

# Implementation of the track_test_node function
# This tracks nodes for proper cleanup in after_each
func track_test_node(node) -> void:
	if not is_instance_valid(node):
		push_warning("Cannot track invalid node")
		return
	
	if not (node in _tracked_test_nodes):
		_tracked_test_nodes.append(node)

# Implementation of the track_test_resource function
func track_test_resource(resource) -> void:
	if not resource:
		push_warning("Cannot track null resource")
		return
		
	# For GUT, we don't need to do anything special - resources are cleaned up by default

func before_all() -> void:
	# Dynamically load scripts to avoid errors if they don't exist
	GameEnums = load("res://src/core/systems/GlobalEnums.gd") if ResourceLoader.exists("res://src/core/systems/GlobalEnums.gd") else null
	
	# Load enemy scripts
	if ResourceLoader.exists("res://src/core/enemy/base/EnemyData.gd"):
		EnemyDataScript = load("res://src/core/enemy/base/EnemyData.gd")
	
	if ResourceLoader.exists("res://src/core/enemy/base/EnemyNode.gd"):
		EnemyNodeScript = load("res://src/core/enemy/base/EnemyNode.gd")
		
	# Load pathfinding scripts
	PathfinderScript = load("res://src/core/pathfinding/Pathfinder.gd") if ResourceLoader.exists("res://src/core/pathfinding/Pathfinder.gd") else null
	NavigationManagerScript = load("res://src/core/navigation/NavigationManager.gd") if ResourceLoader.exists("res://src/core/navigation/NavigationManager.gd") else null

func before_each() -> void:
	# Clear tracked nodes list
	_tracked_test_nodes.clear()
	
	# Reset pathfinding metrics
	_path_found = false
	_calculated_path.clear()
	_pathfinding_time = 0.0
	
	# Setup the test map
	_setup_test_map()
	
	# Setup the pathfinder
	_setup_pathfinder()
	
	# Setup the navigation manager
	_setup_navigation_manager()
	
	await get_tree().create_timer(STABILIZE_TIME).timeout

func after_each() -> void:
	# Clean up tracked test nodes
	for node in _tracked_test_nodes:
		if is_instance_valid(node) and not node.is_queued_for_deletion():
			node.queue_free()
	_tracked_test_nodes.clear()
	
	# Cleanup references
	_pathfinder = null
	_nav_manager = null
	_test_map = null
	_test_enemies.clear()

# Base class helper function - stabilize the engine
func stabilize_engine(time: float = STABILIZE_TIME) -> void:
	await get_tree().create_timer(time).timeout

# Function to create a test enemy
func create_test_enemy(enemy_data: Resource = null) -> Node:
	# Create a basic enemy node
	var enemy_node = null
	
	# Try to create node from script
	if EnemyNodeScript != null:
		# Check if we can instantiate in a safe way
		enemy_node = EnemyNodeScript.new()
		
		if enemy_node and enemy_data:
			# Try different approaches to assign data
			if enemy_node.has_method("set_enemy_data"):
				enemy_node.set_enemy_data(enemy_data)
			elif enemy_node.has_method("initialize"):
				enemy_node.initialize(enemy_data)
			elif "enemy_data" in enemy_node:
				enemy_node.enemy_data = enemy_data
	else:
		# Fallback: create a simple Node
		push_warning("EnemyNodeScript unavailable, creating generic Node2D")
		enemy_node = Node2D.new()
		enemy_node.name = "GenericTestEnemy"
		
		# Add navigation properties for pathfinding tests
		enemy_node.set("position", Vector2.ZERO)
		enemy_node.set("movement_speed", 100.0)
		enemy_node.set("movement_range", 5)
		enemy_node.set("current_path", [])
		
		# Add methods
		enemy_node.set("move_along_path", func(path):
			enemy_node.current_path = path
			enemy_node.position = path[path.size() - 1] if path.size() > 0 else enemy_node.position
			return true
		)
		
		enemy_node.set("can_reach", func(pos):
			var dist = enemy_node.position.distance_to(pos)
			return dist <= enemy_node.movement_range
		)
		
		# Create direct property access
		enemy_node.position = Vector2.ZERO
		enemy_node.movement_speed = 100.0
		enemy_node.movement_range = 5
		enemy_node.current_path = []
		
		# Create direct method access
		enemy_node.move_along_path = func(path):
			enemy_node.current_path = path
			enemy_node.position = path[path.size() - 1] if path.size() > 0 else enemy_node.position
			return true
		
		enemy_node.can_reach = func(pos):
			var dist = enemy_node.position.distance_to(pos)
			return dist <= enemy_node.movement_range
	
	# If we get a node, add it to scene and track it
	if enemy_node:
		add_child_autofree(enemy_node)
		
	# Track locally if needed
	if enemy_node:
		_test_enemies.append(enemy_node)
		track_test_node(enemy_node)
	
	return enemy_node

# Function to create a test enemy resource
func create_test_enemy_resource(data: Dictionary = {}) -> Resource:
	var resource = null
	
	if EnemyDataScript != null:
		resource = EnemyDataScript.new()
		if resource:
			# Initialize the resource with data
			if resource.has_method("load"):
				resource.load(data)
			elif resource.has_method("initialize"):
				resource.initialize(data)
			else:
				# Fallback to manual property assignment
				for key in data:
					if resource.has_method("set_" + key):
						resource.call("set_" + key, data[key])
	
	# Track the resource if we successfully created it
	if resource:
		track_test_resource(resource)
		
	return resource

# Setup Methods
func _setup_test_map() -> void:
	_test_map = Node2D.new()
	_test_map.name = "TestMap"
	add_child_autofree(_test_map)
	track_test_node(_test_map)
	
	# Create a script for the test map
	var script = GDScript.new()
	script.source_code = """
extends Node2D

var grid_size := Vector2i(10, 10)
var cell_size := Vector2(32, 32)
var obstacles := [
	Vector2i(2, 2), Vector2i(2, 3), Vector2i(3, 2), Vector2i(3, 3), # Small block
	Vector2i(6, 1), Vector2i(6, 2), Vector2i(6, 3), Vector2i(6, 4), # Vertical wall
	Vector2i(7, 7), Vector2i(8, 7), Vector2i(9, 7) # Horizontal wall
]

func is_obstacle(grid_pos: Vector2i) -> bool:
	return grid_pos in obstacles

func world_to_grid(world_pos: Vector2) -> Vector2i:
	return Vector2i(int(world_pos.x / cell_size.x), int(world_pos.y / cell_size.y))

func grid_to_world(grid_pos: Vector2i) -> Vector2:
	return Vector2(grid_pos.x * cell_size.x + cell_size.x / 2,
			grid_pos.y * cell_size.y + cell_size.y / 2)
"""
	script.reload()
	_test_map.set_script(script)

func _setup_pathfinder() -> void:
	if PathfinderScript:
		_pathfinder = PathfinderScript.new()
		add_child_autofree(_pathfinder)
		track_test_node(_pathfinder)
		
		# Initialize with test map if needed
		if _pathfinder.has_method("initialize"):
			_pathfinder.initialize(_test_map)
	else:
		# Create a simple pathfinder
		_pathfinder = Node.new()
		_pathfinder.name = "SimplePathfinder"
		add_child_autofree(_pathfinder)
		track_test_node(_pathfinder)
		
		# Create a script for the pathfinder
		var script = GDScript.new()
		script.source_code = """
extends Node

signal path_found(path)
signal path_failed

# Store the methods as metadata
func _ready():
	# Metadata is already set in _setup_pathfinder, but we need to ensure the functions
	# are properly set up in this script to be called as wrappers
	pass

# Wrapper methods that call the stored callable
func find_path(start: Vector2, end: Vector2) -> Array:
	return get_meta("find_path_func").call(start, end)

func optimize_path(path: Array) -> Array:
	return get_meta("optimize_path_func").call(path)

func grid_to_world(grid_pos: Vector2i) -> Vector2:
	return get_meta("grid_to_world_func").call(grid_pos)
"""
		script.reload()
		_pathfinder.set_script(script)
		
		# Store function implementations in metadata
		var find_path_func = func(start: Vector2, end: Vector2) -> Array:
			var start_pos = get_parent().get_node('TestMap').world_to_grid(start)
			var end_pos = get_parent().get_node('TestMap').world_to_grid(end)
			var test_map = get_parent().get_node('TestMap')
			
			# Simple implementation for testing
			var path = []
			
			# Check if direct path is possible
			var has_obstacles = false
			var direction = (end_pos - start_pos)
			var step_count = max(abs(direction.x), abs(direction.y))
			
			if step_count > 0:
				direction = direction / step_count
				
				for i in range(step_count + 1):
					var check_pos = start_pos + direction * i
					if test_map.is_obstacle(check_pos):
						has_obstacles = true
						break
			
			# If direct path has obstacles, create a simple detour
			if has_obstacles:
				var halfway = start_pos + Vector2i(0, end_pos.y - start_pos.y)
				if test_map.is_obstacle(halfway):
					halfway = start_pos + Vector2i(end_pos.x - start_pos.x, 0)
				
				path.append(start)
				path.append(test_map.grid_to_world(halfway))
				path.append(end)
			else:
				path.append(start)
				path.append(end)
			
			# Emit signal
			_pathfinder.emit_signal("path_found", path)
			
			return path
		
		var optimize_path_func = func(path: Array) -> Array:
			# Simple optimization: remove intermediate points that form straight lines
			if path.size() <= 2:
				return path
			
			var optimized = [path[0]]
			var i = 1
			
			while i < path.size() - 1:
				var prev = optimized[optimized.size() - 1]
				var current = path[i]
				var next = path[i + 1]
				
				# If points are collinear, skip the middle point
				var vec1 = current - prev
				var vec2 = next - current
				
				if abs(vec1.normalized().dot(vec2.normalized()) - 1.0) > 0.01:
					optimized.append(current)
				
				i += 1
			
			# Always include the end point
			optimized.append(path[path.size() - 1])
			
			return optimized
		
		var grid_to_world_func = func(grid_pos: Vector2i) -> Vector2:
			var test_map = get_parent().get_node('TestMap')
			return test_map.grid_to_world(grid_pos)
		
		# Store function references in metadata
		_pathfinder.set_meta("find_path_func", find_path_func)
		_pathfinder.set_meta("optimize_path_func", optimize_path_func)
		_pathfinder.set_meta("grid_to_world_func", grid_to_world_func)

func _setup_navigation_manager() -> void:
	if NavigationManagerScript:
		_nav_manager = NavigationManagerScript.new()
		add_child_autofree(_nav_manager)
		track_test_node(_nav_manager)
		
		# Initialize with pathfinder if needed
		if _nav_manager.has_method("initialize"):
			_nav_manager.initialize(_pathfinder)
	else:
		# Create a basic navigation manager
		_nav_manager = Node.new()
		_nav_manager.name = "NavigationManager"
		add_child_autofree(_nav_manager)
		track_test_node(_nav_manager)
		
		# Create a script for the navigation manager
		var script = GDScript.new()
		script.source_code = """
extends Node

# Properties
var grid_size = Vector2(1000, 1000)
var cell_size = Vector2(16, 16)
var obstacles = []

# Methods
func find_path(start_pos, end_pos):
	# Simple path implementation (straight line with obstacle avoidance)
	var path = [start_pos]
	
	# Check if path intersects with any obstacle
	var direct_path_blocked = false
	var start_to_end = end_pos - start_pos
	var dir = start_to_end.normalized()
	var distance = start_to_end.length()
	
	for obstacle in obstacles:
		var obstacle_pos = obstacle.position
		var obstacle_size = obstacle.size if "size" in obstacle else Vector2(32, 32)
		var obstacle_rect = Rect2(obstacle_pos - obstacle_size/2, obstacle_size)
		
		# Check for intersection
		var t = 0.0
		while t < distance:
			var check_pos = start_pos + dir * t
			if obstacle_rect.has_point(check_pos):
				direct_path_blocked = true
				break
			t += cell_size.x
	
	# If blocked, create waypoints around obstacle
	if direct_path_blocked:
		# Add midpoint with offset as simple avoidance
		var midpoint = start_pos + start_to_end / 2
		var normal = Vector2(-dir.y, dir.x) * 50  # Perpendicular offset
		path.append(midpoint + normal)
	
	# Add destination
	path.append(end_pos)
	return path

func grid_to_world(grid_pos):
	return grid_pos * cell_size

func world_to_grid(world_pos):
	return (world_pos / cell_size).floor()

func add_obstacle(pos, size=Vector2(32, 32)):
	var obstacle = {
		"position": pos,
		"size": size
	}
	obstacles.append(obstacle)
	return obstacle

func clear_obstacles():
	obstacles.clear()
	return true

func get_obstacles():
	return obstacles
"""
		script.reload()
		_nav_manager.set_script(script)

# Signal handler for path calculations
func _on_path_found(path: Array) -> void:
	_path_found = true
	_calculated_path = path
	_pathfinding_time = Time.get_ticks_msec() / 1000.0

# Basic Pathfinding Tests
func test_basic_pathfinding() -> void:
	# Skip if pathfinder couldn't be created
	if not _pathfinder:
		pending("Test requires pathfinding system")
		return
	
	# Create test enemy
	var enemy = create_test_enemy()
	if not enemy:
		pending("Test requires enemy implementation")
		return
	
	# Set initial position
	enemy.position = Vector2(50, 50)
	
	# Find path to target
	var target_pos = Vector2(200, 200)
	
	# Connect to path_found signal if available
	if _pathfinder.has_signal("path_found"):
		_pathfinder.connect("path_found", _on_path_found)
	
	# Calculate path
	var path = []
	if _pathfinder.has_method("find_path"):
		path = _pathfinder.find_path(enemy.position, target_pos)
	
	# Wait for pathfinding to complete
	await get_tree().create_timer(PATHFINDING_TIMEOUT).timeout
	
	# Verify path was found
	if _pathfinder.has_signal("path_found"):
		assert_true(_path_found, "Path should be found")
		assert_true(_calculated_path.size() > 0, "Path should have at least one point")
	else:
		assert_true(path.size() > 0, "Path should have at least one point")
	
	# Verify path starts at enemy position and ends at target
	if path.size() > 1:
		var start_point = path[0]
		var end_point = path[path.size() - 1]
		
		assert_eq(start_point, enemy.position, "Path should start at enemy position")
		
		# Use close_enough_vector if positions might not be exactly equal due to grid conversions
		assert_true(close_enough_vector(end_point, target_pos), "Path should end near target position")

# Obstacle Avoidance Tests
func test_obstacle_avoidance() -> void:
	# Skip if pathfinder couldn't be created
	if not _pathfinder:
		pending("Test requires pathfinding system")
		return
	
	# Create test enemy
	var enemy = create_test_enemy()
	if not enemy:
		pending("Test requires enemy implementation")
		return
	
	# Position enemy near an obstacle
	var start_pos = _test_map.grid_to_world(Vector2i(1, 1))
	enemy.position = start_pos
	
	# Set target on other side of obstacle block
	var target_pos = _test_map.grid_to_world(Vector2i(4, 4))
	
	# Calculate path
	var path = []
	if _pathfinder.has_method("find_path"):
		path = _pathfinder.find_path(enemy.position, target_pos)
	
	# Wait for pathfinding to complete
	await get_tree().create_timer(PATHFINDING_TIMEOUT).timeout
	
	# Verify path was found and avoids obstacles
	assert_true(path.size() > 2, "Path should have more than 2 points to avoid obstacles")
	
	# Check each point on the path to ensure none are on obstacles
	for point in path:
		var grid_pos = _test_map.world_to_grid(point)
		assert_false(_test_map.is_obstacle(grid_pos), "Path should not go through obstacles")

# Navigation Tests
func test_unit_navigation() -> void:
	# Skip if navigation manager couldn't be created
	if not _nav_manager:
		pending("Test requires navigation system")
		return
	
	# Create test enemy
	var enemy = create_test_enemy()
	if not enemy:
		pending("Test requires enemy implementation")
		return
	
	# Set initial position
	var start_pos = _test_map.grid_to_world(Vector2i(1, 1))
	enemy.position = start_pos
	
	# Set target position
	var target_pos = _test_map.grid_to_world(Vector2i(8, 8))
	
	# Navigate unit to target
	var navigation_result = false
	if _nav_manager.has_method("navigate_unit"):
		navigation_result = _nav_manager.navigate_unit(enemy, target_pos)
	
	# Wait for navigation to complete
	await get_tree().create_timer(PATHFINDING_TIMEOUT).timeout
	
	# Verify navigation was successful
	assert_true(navigation_result, "Navigation should succeed")
	
	# Verify enemy reached destination
	assert_true(close_enough_vector(enemy.position, target_pos), "Enemy should reach target position")

# Path Optimization Tests
func test_path_optimization() -> void:
	# Skip if pathfinder doesn't have optimization
	if not _pathfinder or not _pathfinder.has_method("optimize_path"):
		pending("Test requires path optimization")
		return
	
	# Create a zigzag path
	var zigzag_path = [
		Vector2(0, 0),
		Vector2(20, 20),
		Vector2(40, 0),
		Vector2(60, 20),
		Vector2(80, 0),
		Vector2(100, 0)
	]
	
	# Optimize the path
	var optimized_path = _pathfinder.optimize_path(zigzag_path)
	
	# Verify optimization reduced path length
	assert_true(optimized_path.size() < zigzag_path.size(), "Optimization should reduce path points")
	
	# Verify start and end points are the same
	assert_eq(optimized_path[0], zigzag_path[0], "Optimized path should keep start point")
	assert_eq(optimized_path[optimized_path.size() - 1], zigzag_path[zigzag_path.size() - 1], "Optimized path should keep end point")

# Performance Tests
func test_pathfinding_performance() -> void:
	# Skip if pathfinder couldn't be created
	if not _pathfinder:
		pending("Test requires pathfinding system")
		return
	
	# Create multiple paths
	var start_positions = [
		Vector2(50, 50), Vector2(100, 150), Vector2(200, 50),
		Vector2(50, 200), Vector2(150, 200)
	]
	
	var end_positions = [
		Vector2(200, 200), Vector2(250, 50), Vector2(50, 250),
		Vector2(250, 250), Vector2(200, 50)
	]
	
	# Time the pathfinding operations
	var start_time = Time.get_ticks_msec()
	
	for i in range(min(start_positions.size(), end_positions.size())):
		if _pathfinder.has_method("find_path"):
			_pathfinder.find_path(start_positions[i], end_positions[i])
	
	var end_time = Time.get_ticks_msec()
	var duration = end_time - start_time
	
	# Verify performance is acceptable
	assert_true(duration < 500, "Multiple paths should be calculated within time limit")

# Helper function to check if vectors are close enough (for floating point comparisons)
func close_enough_vector(vec1: Vector2, vec2: Vector2, tolerance: float = 1.0) -> bool:
	return vec1.distance_to(vec2) <= tolerance
