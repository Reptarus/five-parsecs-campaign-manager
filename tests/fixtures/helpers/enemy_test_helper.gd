@tool
extends "res://tests/fixtures/base/game_test.gd"

# This class provides helper methods for enemy testing 
# without depending on the problematic enemy_test.gd inheritance chain

# Load the ResourcePool helper
var ResourcePoolHelper = load("res://tests/fixtures/helpers/resource_pool.gd") if ResourceLoader.exists("res://tests/fixtures/helpers/resource_pool.gd") else null
var _resource_pool = null # Will be initialized in before_each

# Common resources to preload for tests
const COMMON_TEST_RESOURCES = [
	"res://src/core/mission/MissionManager.gd",
	"res://src/core/enemy/managers/EnemyManager.gd",
	"res://src/core/managers/GameStateManager.gd",
	"res://src/game/game_state/FiveParsecsGameState.gd",
	"res://src/core/enemy/base/EnemyNode.gd",
	"res://src/core/enemy/EnemyData.gd"
]

# Type-safe script references with safe loading - use resource pool when available
var GameStateManager = null # Will load via resource pool
var FiveParsecsGameState = null # Will load via resource pool
var EnemyNodeScript: GDScript = null
var EnemyDataScript: GDScript = null
var TestCleanupHelper = load("res://tests/fixtures/helpers/test_cleanup_helper.gd") if ResourceLoader.exists("res://tests/fixtures/helpers/test_cleanup_helper.gd") else null

# Constants
# const STABILIZE_TIME := 0.1 // Removed to avoid parent class conflict
const ENEMY_STABILIZE_TIME := 0.1
const TEST_TIMEOUT := 5.0
const ENEMY_TEST_CONFIG = {
	"stabilize_time": 0.2,
	"timeout": 5.0
}

# Tracked instances
var _tracked_nodes := []
var _tracked_resources := []
var _cleanup_helper = null

# Lifecycle Methods
func before_all() -> void:
	# Initialize the resource pool if possible
	if ResourcePoolHelper:
		_resource_pool = ResourcePoolHelper.get_instance()
		
		# Preload commonly used resources
		if _resource_pool:
			_preload_common_resources()

func before_each() -> void:
	_tracked_nodes.clear()
	_tracked_resources.clear()
	
	# Initialize cleanup helper
	if TestCleanupHelper:
		_cleanup_helper = TestCleanupHelper.new()
		track_test_node(_cleanup_helper)
	
	# Initialize script references via resource pool
	_initialize_script_references()
	
	await stabilize_engine()

func after_each() -> void:
	# Clean up with helper if available
	if _cleanup_helper:
		if _cleanup_helper.has_method("cleanup_nodes"):
			_cleanup_helper.cleanup_nodes(_tracked_nodes)
		
		# Use the new cleanup_resources method if available
		if _cleanup_helper.has_method("cleanup_resources"):
			_cleanup_helper.cleanup_resources(_tracked_resources)
	else:
		# If no helper exists, manually clean up tracked nodes
		for node in _tracked_nodes:
			if node is Node and is_instance_valid(node) and not node.is_queued_for_deletion():
				node.queue_free()
	
	# Clear the tracking arrays
	_tracked_nodes.clear()
	_tracked_resources.clear()
	_cleanup_helper = null
	
	# Force cleanup to run
	if OS.has_feature("standalone"):
		# Give time for resources to be freed
		OS.delay_msec(50) # Longer delay to ensure cleanup

# Preload common resources to avoid loading during tests
func _preload_common_resources() -> void:
	if not _resource_pool:
		return
		
	for resource_path in COMMON_TEST_RESOURCES:
		if ResourceLoader.exists(resource_path):
			var resource = _resource_pool.get_test_resource(resource_path)
			if not resource:
				push_warning("Failed to preload resource: %s" % resource_path)

# Initialize script references via resource pool
func _initialize_script_references() -> void:
	if _resource_pool:
		# Load required scripts using resource pool
		GameStateManager = _resource_pool.get_test_resource("res://src/core/managers/GameStateManager.gd")
		FiveParsecsGameState = _resource_pool.get_test_resource("res://src/game/game_state/FiveParsecsGameState.gd")
		EnemyNodeScript = _resource_pool.get_test_resource("res://src/core/enemy/base/EnemyNode.gd")
		EnemyDataScript = _resource_pool.get_test_resource("res://src/core/enemy/EnemyData.gd")
	else:
		# Fall back to direct loading if resource pool isn't available
		GameStateManager = load("res://src/core/managers/GameStateManager.gd") if ResourceLoader.exists("res://src/core/managers/GameStateManager.gd") else null
		FiveParsecsGameState = load("res://src/game/game_state/FiveParsecsGameState.gd") if ResourceLoader.exists("res://src/game/game_state/FiveParsecsGameState.gd") else null
		EnemyNodeScript = load("res://src/core/enemy/base/EnemyNode.gd") if ResourceLoader.exists("res://src/core/enemy/base/EnemyNode.gd") else null
		EnemyDataScript = load("res://src/core/enemy/EnemyData.gd") if ResourceLoader.exists("res://src/core/enemy/EnemyData.gd") else null

# Helper function to track nodes for cleanup
func track_test_node(node) -> void:
	if not is_instance_valid(node):
		push_warning("Cannot track invalid node")
		return
	
	if not (node in _tracked_nodes):
		_tracked_nodes.append(node)

# Helper function to track resources - don't try to free them
func track_test_resource(resource) -> void:
	if not resource:
		push_warning("Cannot track null resource")
		return
	
	# Add to tracked resources
	_tracked_resources.append(resource)

# Helper function - stabilize the engine
func stabilize_engine(time: float = ENEMY_STABILIZE_TIME) -> void:
	await get_tree().process_frame
	await get_tree().create_timer(time).timeout

# Create a test enemy node with proper resource attachment
func create_test_enemy(enemy_data = null) -> Node:
	var enemy_node = null
	
	# Try to create node from script - use resource pool if available
	if _resource_pool and EnemyNodeScript:
		enemy_node = EnemyNodeScript.new()
	elif EnemyNodeScript != null:
		enemy_node = EnemyNodeScript.new()
	else:
		# Fallback: create a simple Node
		push_warning("EnemyNodeScript unavailable, creating generic Node")
		enemy_node = Node.new()
		enemy_node.name = "GenericTestEnemy"
	
	# Attach the enemy data if provided
	if enemy_node and enemy_data:
		# Use the static attach_to_node method if available
		if EnemyDataScript and EnemyDataScript.has_method("attach_to_node"):
			EnemyDataScript.attach_to_node(enemy_data, enemy_node)
		# Try different approaches to assign data
		elif enemy_node.has_method("set_enemy_data"):
			enemy_node.set_enemy_data(enemy_data)
		elif enemy_node.has_method("initialize"):
			enemy_node.initialize(enemy_data)
		elif "enemy_data" in enemy_node:
			enemy_node.enemy_data = enemy_data
		else:
			# Last resort: use set_meta for attaching the data
			enemy_node.set_meta("enemy_data", enemy_data)
		
		# Set up parent reference if supported
		if enemy_data.has_method("set_parent_node"):
			enemy_data.set_parent_node(enemy_node)
	
	# If we get a node, add it to scene and track it
	if enemy_node:
		if enemy_node.get_parent() == null:
			add_child_autofree(enemy_node)
			track_test_node(enemy_node)
		
	return enemy_node

# Create a test enemy resource using resource pool if available
func create_test_enemy_resource(data: Dictionary = {}) -> Resource:
	var resource = null
	
	if _resource_pool and EnemyDataScript:
		resource = _resource_pool.create_test_resource("res://src/core/enemy/EnemyData.gd", "test_enemy")
	elif EnemyDataScript != null:
		resource = EnemyDataScript.new()
	
	if resource:
		# Initialize the resource with data
		if resource.has_method("load"):
			resource.load(data)
		elif resource.has_method("initialize"):
			resource.initialize(data)
		else:
			# Properly map properties to their correct names in EnemyData
			for key in data:
				match key:
					"id":
						if "enemy_id" in resource:
							resource.enemy_id = data[key]
					"name":
						if "enemy_name" in resource:
							resource.enemy_name = data[key]
					_:
						# Try direct assignment if property exists in resource
						if key in resource:
							resource.set(key, data[key])
						# Fall back to metadata if direct assignment fails
						elif resource.has_method("set_meta"):
							resource.set_meta(key, data[key])
	
	# Track the resource if we successfully created it
	if resource:
		track_test_resource(resource)
		
	return resource

# Helper to create an array of test enemies
func create_test_enemy_group(size: int = 3) -> Array:
	var group = []
	for i in range(size):
		var enemy_data = create_test_enemy_resource({
			"enemy_id": "test_enemy_" + str(i),
			"enemy_name": "Test Enemy " + str(i),
			"health": 100,
			"max_health": 100,
			"damage": 10,
			"armor": 5
		})
		
		var enemy = create_test_enemy(enemy_data)
		if enemy:
			group.append(enemy)
	
	return group

# Setup a basic game state for testing
func setup_test_game_state() -> Node:
	var game_state = null
	
	# Create game state manager
	if GameStateManager:
		game_state = GameStateManager.new()
		add_child_autofree(game_state)
		track_test_node(game_state)
	else:
		# Fallback to basic Node
		game_state = Node.new()
		game_state.name = "GameStateManager"
		add_child_autofree(game_state)
		track_test_node(game_state)
	
	return game_state

# Create a test mission with enemies
func setup_test_mission(enemy_count: int = 3) -> Dictionary:
	var mission_data = {
		"mission_id": "test_mission_" + str(randi()),
		"mission_name": "Test Mission",
		"enemies": create_test_enemy_group(enemy_count)
	}
	
	return mission_data

# Helper to verify enemy state
func verify_enemy_state(enemy: Node) -> bool:
	if not is_instance_valid(enemy):
		push_warning("Cannot verify invalid enemy")
		return false
	
	var valid = true
	
	# Check basic properties
	if enemy.has_method("get_health"):
		valid = valid and enemy.get_health() > 0
	
	return valid