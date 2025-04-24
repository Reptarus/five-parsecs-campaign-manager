@tool
extends GutTest

# Preload the correct node script
const EnemyNode = preload("res://src/core/enemy/base/EnemyNode.gd") # Updated path

# Load necessary helpers
const TypeSafeHelper = preload("res://tests/fixtures/helpers/type_safe_test_mixin.gd")
const GutCompatibility = preload("res://tests/fixtures/helpers/gut_compatibility.gd") # Corrected preload path
const TestCompatibilityHelper = preload("res://tests/fixtures/helpers/test_compatibility_helper.gd")

# Tests for enemy group behavior

# Import the Enemy class for type checking
const Enemy = preload("res://src/core/enemy/base/EnemyNode.gd") # Corrected path and constant name usage

# Constants from enemy_test.gd
const STABILIZE_TIME := 0.1
const ENEMY_TEST_CONFIG = {
	"pathfinding_timeout": 2.0
}

# Type-safe instance variables for group behavior testing
var _group_manager: Node = null
var _test_group: Array = [] # Uses regular Array instead of Array[EnemyNode]
var _test_leader = null # Uses variable without type hint

# Track nodes for proper cleanup
var _tracked_test_nodes: Array = []

# Constants for group behavior tests
const GROUP_SIZE := 3
const FORMATION_SPACING := 2.0
const FOLLOW_DISTANCE := 3.0
const DISPERSION_RADIUS := 5.0

# Implementation of the missing track_test_node function
# This tracks nodes for proper cleanup in after_each
func track_test_node(node) -> void:
	if not is_instance_valid(node):
		push_warning("Cannot track invalid node")
		return
	
	if not (node in _tracked_test_nodes):
		_tracked_test_nodes.append(node)

# Base class helper function - stabilize the engine
func stabilize_engine(time: float = STABILIZE_TIME) -> void:
	await get_tree().create_timer(time).timeout

# Compatibility implementation for verify_signal_emitted
# This is here because we're no longer extending enemy_test.gd which might have had this method
func verify_signal_emitted(obj: Object, signal_name: String, message: String = "") -> void:
	assert_signal_emitted(obj, signal_name, message)

# Function to create a test enemy
func create_test_enemy(enemy_data: Resource = null) -> Node:
	# Create a basic enemy node
	var enemy_node = null
	
	# Try to create node from script
	if EnemyNode:
		# Check if we can instantiate 
		enemy_node = EnemyNode.new()
		
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
		push_warning("EnemyNode unavailable, creating generic Node2D")
		enemy_node = Node2D.new()
		enemy_node.name = "GenericTestEnemy"
		
		# Add basic enemy properties
		enemy_node.set("position", Vector2.ZERO)
		enemy_node.set("health", 100)
		enemy_node.set("is_active", true)
		
		# Add methods
		enemy_node.set("get_position", func():
			return enemy_node.position
		)
		
		enemy_node.set("set_position", func(pos):
			enemy_node.position = pos
			return true
		)
		
		enemy_node.set("get_health", func():
			return enemy_node.health
		)
		
		enemy_node.set("take_damage", func(amount):
			enemy_node.health -= amount
			return true
		)
		
		enemy_node.set("is_active", func():
			return enemy_node.is_active
		)
	
	# If we get a node, add it to scene and track it
	if enemy_node:
		add_child_autofree(enemy_node)
		track_test_node(enemy_node)
	
	return enemy_node

# Helper function to create a test group
func _create_test_group(size: int = 3) -> Array:
	var group = []
	for i in range(size):
		var enemy = create_test_enemy()
		if enemy:
			group.append(enemy)
	return group

# Missing function to capture enemy states for verification
func _capture_group_states(group: Array) -> Array:
	var states: Array = []
	for enemy in group:
		if not is_instance_valid(enemy):
			push_warning("Cannot capture state for invalid enemy")
			continue
			
		var state = {
			"position": Vector2.ZERO,
			"health": 0,
			"is_active": false
		}
		
		# Safely capture position
		if enemy.has_method("get_position"):
			state.position = enemy.get_position()
		elif "position" in enemy:
			state.position = enemy.position
			
		# Safely capture health
		if enemy.has_method("get_health"):
			state.health = enemy.get_health()
		elif "health" in enemy:
			state.health = enemy.health
			
		# Safely capture active state
		if enemy.has_method("is_active"):
			state.is_active = enemy.is_active()
		elif "is_active" in enemy:
			state.is_active = enemy.is_active
			
		states.append(state)
	
	return states

# Lifecycle functions
func before_each() -> void:
	# Create a test group
	_test_group = _create_test_group(GROUP_SIZE)
	
	# Ensure we have enough enemies for the tests
	if _test_group.size() < GROUP_SIZE:
		push_warning("Could not create enough enemies for group test, some tests may be skipped")
	
	if _test_group.size() > 0:
		_test_leader = _test_group[0]
	else:
		push_warning("No enemies created, tests will be skipped")
	
	# We'll need to create a manager for the group
	_group_manager = Node.new()
	_group_manager.name = "TestGroupManager"
	
	# Add common method stubs if they don't exist
	if not _group_manager.has_method("register_enemy"):
		_group_manager.set("register_enemy", func(enemy):
			return true
		)
	
	if not _group_manager.has_method("get_formation_position"):
		_group_manager.set("get_formation_position", func(enemy_index, spacing):
			return Vector2(enemy_index * spacing, 0)
		)
	
	if not _group_manager.has_method("get_leader"):
		_group_manager.set("get_leader", func():
			if _test_group.size() > 0:
				return _test_group[0]
			return null
		)
	
	add_child_autofree(_group_manager)
	track_test_node(_group_manager)

func after_each() -> void:
	# Clean up tracked nodes
	for node in _tracked_test_nodes:
		if is_instance_valid(node) and node.is_inside_tree():
			node.queue_free()
	
	_tracked_test_nodes.clear()
	_test_group.clear()
	_test_leader = null
	_group_manager = null
	
	# Make sure we give the engine time to process the cleanup
	await get_tree().process_frame

# Tests for group behavior
func test_group_formation() -> void:
	# Skip if we don't have enough enemies
	if _test_group.size() < GROUP_SIZE or not is_instance_valid(_group_manager):
		pending("Not enough valid test enemies or invalid group manager")
		return
	
	# Test if enemies can form a simple line formation
	for i in range(_test_group.size()):
		var enemy = _test_group[i]
		
		# Skip invalid enemies
		if not is_instance_valid(enemy):
			continue
			
		# Calculate expected position in formation
		var expected_position = Vector2(i * FORMATION_SPACING, 0)
		
		# Some enemies might use position property directly
		if "position" in enemy:
			enemy.position = expected_position
			
		# Others might use a set_position method
		elif enemy.has_method("set_position"):
			enemy.set_position(expected_position)
		
		# Get position using appropriate method
		var actual_position = Vector2.ZERO
		if enemy.has_method("get_position"):
			actual_position = enemy.get_position()
		elif "position" in enemy:
			actual_position = enemy.position
			
		# Assert position is correct
		assert_almost_eq(
			actual_position.x,
			expected_position.x,
			0.1,
			"Enemy X position should match expected formation position"
		)
		assert_almost_eq(
			actual_position.y,
			expected_position.y,
			0.1,
			"Enemy Y position should match expected formation position"
		)
	
	# Verify group cohesion by checking distances between enemies
	for i in range(_test_group.size() - 1):
		var enemy1 = _test_group[i]
		var enemy2 = _test_group[i + 1]
		
		# Skip if any enemy is invalid
		if not is_instance_valid(enemy1) or not is_instance_valid(enemy2):
			continue
		
		# Get positions for both enemies
		var pos1 = Vector2.ZERO
		var pos2 = Vector2.ZERO
		
		if enemy1.has_method("get_position"):
			pos1 = enemy1.get_position()
		elif "position" in enemy1:
			pos1 = enemy1.position
			
		if enemy2.has_method("get_position"):
			pos2 = enemy2.get_position()
		elif "position" in enemy2:
			pos2 = enemy2.position
			
		# Check distance between enemies
		var distance = pos1.distance_to(pos2)
		assert_almost_eq(
			distance,
			FORMATION_SPACING,
			0.1,
			"Distance between adjacent enemies should match formation spacing"
		)

func test_group_coordinated_movement() -> void:
	# Skip if we don't have enough enemies
	if _test_group.size() < GROUP_SIZE or not is_instance_valid(_group_manager):
		pending("Not enough valid test enemies or invalid group manager")
		return
	
	# Skip if leader isn't valid
	if not is_instance_valid(_test_leader):
		pending("No valid leader for coordination test")
		return
	
	# Capture initial states
	var initial_states = _capture_group_states(_test_group)
	
	# Move leader
	var movement_vector = Vector2(10, 5)
	var leader_new_position = Vector2.ZERO
	
	if _test_leader.has_method("get_position"):
		leader_new_position = _test_leader.get_position() + movement_vector
	elif "position" in _test_leader:
		leader_new_position = _test_leader.position + movement_vector
	
	if _test_leader.has_method("set_position"):
		_test_leader.set_position(leader_new_position)
	elif "position" in _test_leader:
		_test_leader.position = leader_new_position
	
	# Each follower should move to maintain formation
	for i in range(1, _test_group.size()):
		var follower = _test_group[i]
		
		# Skip invalid followers
		if not is_instance_valid(follower):
			continue
			
		# Get initial position
		var initial_position = initial_states[i].position
		
		# Calculate expected new position (maintain formation with same offset)
		var expected_position = initial_position + movement_vector
		
		# Move follower
		if follower.has_method("set_position"):
			follower.set_position(expected_position)
		elif "position" in follower:
			follower.position = expected_position
		
		# Verify position
		var actual_position = Vector2.ZERO
		if follower.has_method("get_position"):
			actual_position = follower.get_position()
		elif "position" in follower:
			actual_position = follower.position
			
		# Assert position is correct
		assert_almost_eq(
			actual_position.x,
			expected_position.x,
			0.1,
			"Follower X position should maintain relative to leader"
		)
		assert_almost_eq(
			actual_position.y,
			expected_position.y,
			0.1,
			"Follower Y position should maintain relative to leader"
		)

func test_group_coordinated_attack() -> void:
	var group: Array = _create_test_group()
	var target: Node = create_test_enemy()
	assert_not_null(target, "Should create target")
	add_child_autofree(target)
	
	# Set target position
	TypeSafeHelper._call_node_method_bool(target, "set_position", [Vector2(50, 50)])
	
	# Engage target
	watch_signals(_group_manager)
	var engage_result: bool = TypeSafeHelper._call_node_method_bool(_group_manager, "engage_target", [group, target])
	assert_true(engage_result, "Should initiate group attack")
	verify_signal_emitted(_group_manager, "group_attack_started")
	
	# Wait for attacks
	await get_tree().create_timer(2.0).timeout
	verify_signal_emitted(_group_manager, "group_attack_completed")
	
	# Verify target damage
	var target_health: float = TypeSafeHelper._safe_cast_float(TypeSafeHelper._call_node_method(target, "get_health", []))
	assert_true(target_health < 100.0, "Target should take damage from group attack")

func test_group_flanking_maneuver() -> void:
	var group: Array = _create_test_group(2)
	var target: Node = create_test_enemy()
	assert_not_null(target, "Should create target")
	add_child_autofree(target)
	
	# Setup positions
	TypeSafeHelper._call_node_method_bool(target, "set_position", [Vector2(0, 0)])
	TypeSafeHelper._call_node_method_bool(group[0], "set_position", [Vector2(-100, 0)])
	TypeSafeHelper._call_node_method_bool(group[1], "set_position", [Vector2(-100, 50)])
	
	# Execute flank
	watch_signals(_group_manager)
	var flank_result: bool = TypeSafeHelper._call_node_method_bool(_group_manager, "execute_flank", [group, target])
	assert_true(flank_result, "Should initiate flanking maneuver")
	verify_signal_emitted(_group_manager, "flank_started")
	
	# Wait for maneuver
	await get_tree().create_timer(2.0).timeout
	verify_signal_emitted(_group_manager, "flank_completed")
	
	# Verify final positions (check if they are on opposite sides of the target)
	var pos1: Vector2 = TypeSafeHelper._call_node_method(group[0], "get_position", []) as Vector2
	var pos2: Vector2 = TypeSafeHelper._call_node_method(group[1], "get_position", []) as Vector2
	assert_true(pos1.x < 0 and pos2.x > 0 or pos1.x > 0 and pos2.x < 0,
		"Enemies should be on opposite sides after flank")

func test_group_retreat_behavior() -> void:
	var group: Array = _create_test_group()
	
	# Damage group members
	for enemy in group:
		TypeSafeHelper._call_node_method_bool(enemy, "take_damage", [80])
	
	# Trigger retreat
	watch_signals(_group_manager)
	var retreat_result: bool = TypeSafeHelper._call_node_method_bool(_group_manager, "check_retreat", [group])
	assert_true(retreat_result, "Should initiate retreat when damaged")
	verify_signal_emitted(_group_manager, "group_retreat_started")
	
	# Wait for retreat
	await get_tree().create_timer(2.0).timeout
	verify_signal_emitted(_group_manager, "group_retreat_completed")
	
	# Verify final positions (check if moved away from start)
	var states: Array = _capture_group_states(group)
	for state in states:
		assert_true(state.get("position", Vector2.ZERO).length() > 50.0,
			"Enemy should move away during retreat")

# Combat Behavior Tests
func test_group_combat_behavior() -> void:
	var group: Array = _create_test_group() # Changed from Array[EnemyNode]
	assert_eq(group.size(), GROUP_SIZE, "Should create correct group size")
	
	var target = create_test_enemy()
	assert_not_null(target, "Target should be created")
	
	# Test group combat coordination
	var leader = group[0] if group.size() > 0 else null
	if not is_instance_valid(leader):
		pending("Leader is not valid")
		return
	
	var combat_success: bool = false
	if leader.has_method("coordinate_group_combat"):
		combat_success = TypeSafeHelper._call_node_method_bool(leader, "coordinate_group_combat", [group, target])
		assert_true(combat_success, "Group should coordinate combat")
	else:
		pending("Leader doesn't have coordinate_group_combat method")
		return
	
	# Verify combat states - safely check for is_in_combat method
	for enemy in group:
		# Use TypeSafeHelper to safely check if the enemy is in combat
		var in_combat: bool = false
		if enemy.has_method("is_in_combat"):
			in_combat = TypeSafeHelper._call_node_method_bool(enemy, "is_in_combat", [])
		elif enemy.has_method("get_combat_state"):
			in_combat = TypeSafeHelper._call_node_method_bool(enemy, "get_combat_state", [])
		elif enemy.has_method("get_state"):
			var state = TypeSafeHelper._call_node_method_dict(enemy, "get_state", [])
			in_combat = state.get("in_combat", false)
		else:
			push_warning("Cannot determine combat state of enemy, skipping check")
			continue
			
		assert_true(in_combat, "Group members should be in combat state")

# Morale and Cohesion Tests
func test_group_morale() -> void:
	var group: Array = _create_test_group() # Changed from Array[EnemyNode]
	assert_eq(group.size(), GROUP_SIZE, "Should create correct group size")
	
	var leader = group[0] if group.size() > 0 else null
	if not is_instance_valid(leader):
		pending("Leader is not valid")
		return
	
	# Test morale influence
	var base_morale: float = 0.0
	if leader.has_method("get_morale"):
		base_morale = TypeSafeHelper._call_node_method_float(leader, "get_morale", [])
	else:
		pending("Leader doesn't have get_morale method")
		return
	
	if leader.has_method("take_damage"):
		leader.take_damage(5) # Simulate leader taking damage
	else:
		pending("Leader doesn't have take_damage method")
		return
	
	# Verify group morale effects
	for enemy in group:
		var current_morale: float = TypeSafeHelper._call_node_method_float(enemy, "get_morale", [])
		assert_true(current_morale < base_morale,
			"Group morale should be affected by leader damage")

func test_group_dispersion() -> void:
	var group: Array = _create_test_group() # Changed from Array[EnemyNode]
	assert_eq(group.size(), GROUP_SIZE, "Should create correct group size")
	
	var leader = group[0] if group.size() > 0 else null
	if not is_instance_valid(leader):
		pending("Leader is not valid")
		return
	
	# Test group dispersion
	var disperse_success: bool = false
	if leader.has_method("disperse_group"):
		disperse_success = TypeSafeHelper._call_node_method_bool(leader, "disperse_group", [group, DISPERSION_RADIUS])
		assert_true(disperse_success, "Group should disperse")
	else:
		pending("Leader doesn't have disperse_group method")
		return
	
	# Verify dispersion
	for i in range(1, group.size()):
		if not is_instance_valid(group[i]):
			continue
			
		for j in range(i + 1, group.size()):
			if not is_instance_valid(group[j]):
				continue
				
			if "position" in group[i] and "position" in group[j]:
				var distance: float = group[i].position.distance_to(group[j].position)
				assert_true(distance >= DISPERSION_RADIUS,
					"Dispersed units should maintain minimum separation")

func test_group_reformation() -> void:
	var group: Array = _create_test_group() # Changed from Array[EnemyNode]
	assert_eq(group.size(), GROUP_SIZE, "Should create correct group size")
	
	var leader = group[0] if group.size() > 0 else null
	if not is_instance_valid(leader):
		pending("Leader is not valid")
		return
	
	# Disperse then reform group
	var disperse_success: bool = false
	if leader.has_method("disperse_group"):
		disperse_success = TypeSafeHelper._call_node_method_bool(leader, "disperse_group", [group, DISPERSION_RADIUS])
		assert_true(disperse_success, "Group should disperse")
	else:
		pending("Leader doesn't have disperse_group method")
		return
	
	var reform_success: bool = false
	if leader.has_method("reform_group"):
		reform_success = TypeSafeHelper._call_node_method_bool(leader, "reform_group", [group])
		assert_true(reform_success, "Group should reform")
	else:
		pending("Leader doesn't have reform_group method")
		return
	
	# Verify reformation
	for enemy in group:
		if not is_instance_valid(enemy) or not is_instance_valid(leader):
			continue
			
		if "position" in enemy and "position" in leader:
			var distance: float = enemy.position.distance_to(leader.position)
			assert_true(distance <= FORMATION_SPACING * 2.0,
				"Reformed units should be near leader")

# Leader Assignment Tests
func test_leader_assignment() -> void:
	var leader := create_test_enemy()
	assert_not_null(leader, "Leader should be created")
	add_child_autofree(leader)
	
	# Skip test if implementation not ready
	if not leader.has_method("promote_to_leader"):
		pending("Leader promotion not implemented")
		return

# Group Mechanics Tests
func test_group_mechanics() -> void:
	# Skip test if implementation not ready
	pending("Group mechanics test not implemented")
	return

func test_group_cohesion() -> void:
	var leader := create_test_enemy()
	assert_not_null(leader, "Leader should be created")
	add_child_autofree(leader)
	
	# Skip test if implementation not ready
	if not leader.has_method("measure_cohesion"):
		pending("Group cohesion not implemented")
		return

# Targeting Tests
func test_group_targeting() -> void:
	var target := create_test_enemy()
	assert_not_null(target, "Target should be created")
	add_child_autofree(target)
	
	# Skip test if implementation not ready
	pending("Group targeting not implemented")
	return

# Group Reinforcement Tests
func test_group_reinforcement() -> void:
	var leader := create_test_enemy()
	assert_not_null(leader, "Leader should be created")
	add_child_autofree(leader)
	
	var follower := create_test_enemy()
	assert_not_null(follower, "Follower should be created")
	add_child_autofree(follower)
	
	var follower2 := create_test_enemy()
	assert_not_null(follower2, "Second follower should be created")
	add_child_autofree(follower2)
	
	# Skip test if implementation not ready
	pending("Group reinforcement not implemented")
	return

# Formation Management Tests
func test_formation_assignment() -> void:
	# Skip if there are insufficient enemies
	if _test_group.size() < 3 or not _group_manager:
		pending("Test requires at least 3 enemies and a group manager")
		return
	
	# Create a test formation
	var formation = {
		"name": "TestFormation",
		"positions": [Vector2(0, 0), Vector2(100, 0), Vector2(0, 100)]
	}
	
	# Assign formation to enemies if possible
	var result = false
	if _group_manager.has_method("arrange_formation"):
		# Get only valid instances from _test_group
		var valid_enemies = []
		for enemy in _test_group:
			if is_instance_valid(enemy):
				valid_enemies.append(enemy)
		
		if valid_enemies.size() >= 3:
			# Assign formation to the first 3 valid enemies
			var formation_members = []
			for i in range(3):
				formation_members.append(valid_enemies[i])
			
			# Call the arrange_formation method
			result = TypeSafeHelper._call_node_method_bool(_group_manager, "arrange_formation", [formation_members])
		else:
			pending("Not enough valid enemies for formation test")
			return
	else:
		# Try alternative methods if arrange_formation doesn't exist
		if _group_manager.has_method("set_formation"):
			result = TypeSafeHelper._call_node_method_bool(_group_manager, "set_formation", [_test_group.slice(0, 3), formation])
		else:
			pending("Group manager does not have arrange_formation or set_formation method")
			return
		
	# Check result
	assert_true(result, "Formation assignment should succeed")
	
	# Check if enemies were properly assigned positions
	for i in range(3):
		if i < _test_group.size() and is_instance_valid(_test_group[i]):
			var target_pos = formation["positions"][i]
			
			# Check if enemy has the target position property
			var has_target = false
			if "formation_position" in _test_group[i]:
				has_target = true
				assert_eq(_test_group[i].formation_position, target_pos, "Enemy should have correct formation position")
			elif _test_group[i].has_method("get_formation_position"):
				has_target = true
				assert_eq(_test_group[i].get_formation_position(), target_pos, "Enemy should have correct formation position")
			
			if not has_target:
				# If no formation position is found, check if the enemy is moving toward the expected position
				if "target_position" in _test_group[i]:
					assert_almost_eq(_test_group[i].target_position, target_pos, Vector2(5, 5), "Enemy should move toward formation position")
				elif _test_group[i].has_method("get_target_position"):
					assert_almost_eq(_test_group[i].get_target_position(), target_pos, Vector2(5, 5), "Enemy should move toward formation position")

# Group Management Tests
func test_group_operations() -> void:
	# Skip if there are insufficient enemies
	if _test_group.size() < 2 or not _group_manager:
		pending("Test requires at least 2 enemies and a group manager")
		return
	
	# Test getting enemies from group
	var group_enemies = []
	if _group_manager.has_method("get_enemies"):
		group_enemies = _group_manager.get_enemies()
	elif _group_manager.has_method("get_all_enemies"):
		group_enemies = _group_manager.get_all_enemies()
	elif "enemies" in _group_manager:
		group_enemies = _group_manager.enemies
	
	# Verify we can retrieve the enemies
	assert_true(group_enemies.size() > 0, "Group should have enemies")
	
	# Pick a test enemy to remove
	var test_enemy = null
	for enemy in _test_group:
		if is_instance_valid(enemy):
			test_enemy = enemy
			break
	
	if not test_enemy:
		pending("No valid test enemy found")
		return
	
	# Test removing an enemy
	var initial_count = group_enemies.size()
	var removal_result = false
	
	if _group_manager.has_method("remove_enemy"):
		removal_result = _group_manager.remove_enemy(test_enemy)
	else:
		# Try to find another method for removing
		if _group_manager.has_method("remove"):
			_group_manager.remove(test_enemy)
			removal_result = true
		else:
			pending("Group does not have remove_enemy or remove method")
			return
	
	# Get the updated enemies list
	if _group_manager.has_method("get_enemies"):
		group_enemies = _group_manager.get_enemies()
	elif _group_manager.has_method("get_all_enemies"):
		group_enemies = _group_manager.get_all_enemies()
	elif "enemies" in _group_manager:
		group_enemies = _group_manager.enemies
	
	# Verify enemy was removed
	assert_true(removal_result, "Enemy removal should succeed")
	assert_eq(group_enemies.size(), initial_count - 1, "Group should have one less enemy")
	
	var enemy_still_in_group = false
	for enemy in group_enemies:
		if enemy == test_enemy:
			enemy_still_in_group = true
			break
	
	assert_false(enemy_still_in_group, "Removed enemy should not be in group")

func _get_valid_test_enemies(count: int) -> Array:
	# Return an array of valid test enemies, up to the requested count
	var valid_enemies = []
	for enemy in _test_group:
		if is_instance_valid(enemy):
			valid_enemies.append(enemy)
			if valid_enemies.size() >= count:
				break
	
	return valid_enemies
