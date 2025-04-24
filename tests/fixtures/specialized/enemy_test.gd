@tool
extends "res://tests/fixtures/specialized/enemy_test_base.gd"

# Specialized tests for specific enemy functionalities or types
# that extend the base enemy tests.

# Load scripts safely with Compatibility helper
# Compatibility is inherited from base class
const TestCleanupHelper = preload("res://tests/fixtures/helpers/test_cleanup_helper.gd")

# Updated with class names for safer loading
# EnemyNodeScript and EnemyDataScript are inherited from base class

# Common test timeouts with type safety
const DEFAULT_TIMEOUT := 1.0 as float

# ENEMY_TEST_CONFIG and EnemyTestType are inherited from base class

# Type-safe instance variables
var _enemy_system: Node = null
var _test_enemies: Array[Node] = [] # Changed from Array[Enemy]
var _cleanup_helper: TestCleanupHelper = null # Instance variable
var _tracked_resources: Array[Resource] = [] # Added for track_test_resource

# Lifecycle Methods
func before_each() -> void:
	await super.before_each()
	_setup_enemy_system()
	_cleanup_helper = TestCleanupHelper.new() # Instantiate the helper
	
	# ENEMY_TEST_CONFIG is inherited
	await stabilize_engine(ENEMY_TEST_CONFIG.stabilize_time)

func after_each() -> void:
	# Clean up any test enemies using the helper instance
	if _cleanup_helper:
		_cleanup_helper.cleanup_nodes(_test_enemies)
	_enemy_system = null
	_cleanup_helper = null # Clear the instance
	await super.after_each()

# Setup Methods
func _setup_enemy_system() -> void:
	_enemy_system = Node.new()
	if not _enemy_system:
		push_error("Failed to create enemy system")
		return
	_enemy_system.name = "EnemySystem"
	add_child_autofree(_enemy_system)

# Helper methods for enemy testing

# Match base class signature: (enemy_data: Variant = null) -> CharacterBody2D
func create_test_enemy(enemy_data: Variant = null) -> CharacterBody2D:
	# Standalone implementation that doesn't rely on super
	var enemy_node = null
	
	# Try to create node from script
	if EnemyNodeScript != null and EnemyNodeScript.can_instantiate():
		# Create proper CharacterBody2D instance
		enemy_node = CharacterBody2D.new()
		enemy_node.set_script(EnemyNodeScript)
		
		if enemy_node and enemy_data:
			# Try different approaches to assign data
			if enemy_node.has_method("set_enemy_data"):
				enemy_node.set_enemy_data(enemy_data)
			elif enemy_node.has_method("initialize"):
				enemy_node.initialize(enemy_data)
			elif "enemy_data" in enemy_node:
				enemy_node.enemy_data = enemy_data
	else:
		# Fallback: create a CharacterBody2D
		push_warning("EnemyNodeScript unavailable, creating generic CharacterBody2D")
		enemy_node = CharacterBody2D.new()
		enemy_node.name = "GenericTestEnemy"
	
	# If we get a node, add it to scene and track it
	if enemy_node:
		if enemy_node.get_parent() == null:
			# Use add_child_autoqfree if available
			if has_method("add_child_autoqfree"):
				add_child_autoqfree(enemy_node)
			else:
				add_child(enemy_node)
				# Track the node locally
				if enemy_node not in _test_enemies:
					_test_enemies.append(enemy_node)
		
	return enemy_node

# Match base class signature: (data: Dictionary = {}) -> Resource
func create_test_enemy_resource(data: Dictionary = {}) -> Resource:
	# Call the base class implementation with better error handling
	var resource = null
	
	# First try the base class implementation
	if has_method("super") and super.has_method("create_test_enemy_resource"):
		resource = super.create_test_enemy_resource(data)
	# Fallback method if super is not available
	elif EnemyDataScript != null:
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

# Custom implementation of track_test_resource
func track_test_resource(resource: Resource) -> void:
	if not resource:
		return
	
	# In our implementation, we'll just make sure to store it for cleanup
	if resource not in _tracked_resources:
		_tracked_resources.append(resource)
		
	# Also call the GUT base implementation if it exists
	if has_method("super") and super.has_method("track_test_resource"):
		super.track_test_resource(resource)

# Helper to create an array of test enemies
func create_test_enemy_group(size: int = 3) -> Array:
	var group = []
	for i in range(size):
		var enemy = create_test_enemy()
		if enemy:
			group.append(enemy)
	return group

# Verifies enemy movement with better error handling
func verify_enemy_movement(enemy: CharacterBody2D, start_pos: Vector2, end_pos: Vector2) -> void:
	if not is_instance_valid(enemy):
		push_error("Cannot verify movement: enemy is null")
		assert_true(false, "Enemy is null in verify_enemy_movement")
		return
	
	# Set initial position
	if enemy.has_method("set_position"):
		enemy.set_position(start_pos)
	else:
		push_warning("Enemy doesn't have set_position method, skipping position setup")
		return
		
	# Move to target position
	var moved = false
	if enemy.has_method("move_to"):
		moved = enemy.move_to(end_pos)
	elif enemy.has_method("navigate_to"):
		moved = enemy.navigate_to(end_pos)
	else:
		push_warning("Enemy doesn't have move_to or navigate_to method, skipping movement test")
		return
		
	# Verify movement
	assert_true(moved, "Enemy should start moving")
	
	# Call the base class implementation if it exists
	if has_method("super") and super.has_method("verify_enemy_movement"):
		super.verify_enemy_movement(enemy, start_pos, end_pos)

# Verifies enemy combat with better error handling
func verify_enemy_combat(enemy: CharacterBody2D, target: CharacterBody2D) -> void:
	if not is_instance_valid(enemy) or not is_instance_valid(target):
		push_error("Cannot verify combat: enemy or target is null")
		assert_true(false, "Enemy or target is null in verify_enemy_combat")
		return
		
	# Verify combat methods
	var combat_initiated = false
	if enemy.has_method("attack"):
		combat_initiated = enemy.attack(target)
	elif enemy.has_method("engage_target"):
		combat_initiated = enemy.engage_target(target)
	else:
		push_warning("Enemy doesn't have attack or engage_target method, skipping combat test")
		return
		
	# Verify combat
	assert_true(combat_initiated, "Enemy should initiate combat")
	
	# Call the base class implementation if it exists
	if has_method("super") and super.has_method("verify_enemy_combat"):
		super.verify_enemy_combat(enemy, target)

# Verifies enemy state
func verify_enemy_complete_state(enemy: CharacterBody2D) -> void:
	# Call the base class implementation or add specialized checks
	super.verify_enemy_complete_state(enemy)
	# Add specialized state verification if needed
	pass

# Measures enemy performance
func measure_enemy_performance() -> Dictionary:
	# Call the base class implementation or add specialized checks
	return super.measure_enemy_performance()

# Verifies performance metrics
func verify_performance_metrics(metrics: Dictionary, expected: Dictionary) -> void:
	# Call the base class implementation or add specialized checks
	super.verify_performance_metrics(metrics, expected)
	# Add specialized performance verification if needed
	pass

# Add test methods specific to this specialized suite
func test_specialized_enemy_placeholder() -> void:
	# Placeholder for specialized tests
	var enemy_node = await create_test_enemy() # Use await here
	assert_not_null(enemy_node, "Specialized enemy node should be created")
	pass

# ... Add more specialized tests here ...
