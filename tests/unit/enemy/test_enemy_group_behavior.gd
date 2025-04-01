@tool
extends "res://tests/fixtures/specialized/enemy_test.gd"

# Import the Enemy class for type checking
const Enemy = preload("res://src/core/enemy/base/Enemy.gd")

# Type-safe instance variables for group behavior testing
var _group_manager: Node = null
var _test_group: Array[Enemy] = []
var _test_leader: Enemy = null

# Constants for group behavior tests
const GROUP_SIZE := 3
const FORMATION_SPACING := 2.0
const FOLLOW_DISTANCE := 3.0
const DISPERSION_RADIUS := 5.0

# Lifecycle Methods
func before_each() -> void:
	await super.before_each()
	
	# Setup group test environment
	_group_manager = Node.new()
	if not _group_manager:
		push_error("Failed to create group manager")
		return
	_group_manager.name = "GroupManager"
	add_child_autofree(_group_manager)
	track_test_node(_group_manager)
	
	# Create test group
	_test_group = []
	for i in range(GROUP_SIZE):
		var enemy := create_test_enemy()
		if not enemy:
			push_error("Failed to create test enemy %d" % i)
			continue
		_test_group.append(enemy)
	
	await stabilize_engine(STABILIZE_TIME)

func after_each() -> void:
	_group_manager = null
	_test_group.clear()
	await super.after_each()

# Formation Tests
func test_group_formation() -> void:
	var enemy := create_test_enemy()
	assert_not_null(enemy, "Enemy should be created")
	add_child_autofree(enemy)
	
	var leader: Enemy = create_test_enemy(EnemyTestType.ELITE)
	assert_not_null(leader, "Leader should be created")
	
	var followers: Array[Enemy] = _create_follower_group(2)
	assert_eq(followers.size(), 2, "Should create correct number of followers")
	
	# Test formation setup
	var formation_success: bool = TypeSafeMixin._call_node_method_bool(leader, "setup_formation", [followers, FORMATION_SPACING])
	assert_true(formation_success, "Formation should be set up successfully")
	
	# Verify formation positions
	for i in range(followers.size()):
		var distance: float = followers[i].position.distance_to(leader.position)
		assert_true(distance <= FORMATION_SPACING * 1.5,
			"Follower should be within formation spacing")

# Coordination Tests
func test_group_coordination() -> void:
	var group: Array[Enemy] = _create_test_group()
	assert_eq(group.size(), GROUP_SIZE, "Should create correct group size")
	
	var leader: Enemy = group[0]
	assert_not_null(leader, "Leader should be available")
	
	# Test group movement coordination
	var target_pos := Vector2(10, 10)
	var move_success: bool = TypeSafeMixin._call_node_method_bool(leader, "coordinate_group_movement", [group, target_pos])
	assert_true(move_success, "Group should coordinate movement")
	
	# Verify group is moving together
	for enemy in group:
		assert_true(enemy.is_moving(), "All group members should be moving")

func test_leader_following() -> void:
	var leader: Enemy = create_test_enemy(EnemyTestType.ELITE)
	assert_not_null(leader, "Leader should be created")
	
	var followers: Array[Enemy] = _create_follower_group(2)
	assert_eq(followers.size(), 2, "Should create correct number of followers")
	
	# Setup following behavior
	for follower in followers:
		var follow_success: bool = _call_node_method_bool(follower, "follow_leader", [leader, FOLLOW_DISTANCE])
		assert_true(follow_success, "Follower should start following leader")
	
	# Move leader and verify followers update
	leader.position += Vector2(5, 0)
	await stabilize_engine(STABILIZE_TIME)
	
	for follower in followers:
		var distance: float = follower.position.distance_to(leader.position)
		assert_true(distance <= FOLLOW_DISTANCE * 1.5,
			"Followers should maintain following distance")

# Combat Behavior Tests
func test_group_combat_behavior() -> void:
	var group: Array[Enemy] = _create_test_group()
	assert_eq(group.size(), GROUP_SIZE, "Should create correct group size")
	
	var target: Enemy = create_test_enemy()
	assert_not_null(target, "Target should be created")
	
	# Test group combat coordination
	var leader: Enemy = group[0]
	var combat_success: bool = _call_node_method_bool(leader, "coordinate_group_combat", [group, target])
	assert_true(combat_success, "Group should coordinate combat")
	
	# Verify combat states
	for enemy in group:
		assert_true(enemy.is_in_combat(), "All group members should be in combat")

# Morale and Cohesion Tests
func test_group_morale() -> void:
	var group: Array[Enemy] = _create_test_group()
	assert_eq(group.size(), GROUP_SIZE, "Should create correct group size")
	
	var leader: Enemy = group[0]
	assert_not_null(leader, "Leader should be available")
	
	# Test morale influence
	var base_morale: float = _call_node_method_float(leader, "get_morale", [])
	leader.take_damage(5) # Simulate leader taking damage
	
	# Verify group morale effects
	for enemy in group:
		var current_morale: float = _call_node_method_float(enemy, "get_morale", [])
		assert_true(current_morale < base_morale,
			"Group morale should be affected by leader damage")

func test_group_dispersion() -> void:
	var group: Array[Enemy] = _create_test_group()
	assert_eq(group.size(), GROUP_SIZE, "Should create correct group size")
	
	var leader: Enemy = group[0]
	assert_not_null(leader, "Leader should be available")
	
	# Test group dispersion
	var disperse_success: bool = _call_node_method_bool(leader, "disperse_group", [group, DISPERSION_RADIUS])
	assert_true(disperse_success, "Group should disperse")
	
	# Verify dispersion
	for i in range(1, group.size()):
		for j in range(i + 1, group.size()):
			var distance: float = group[i].position.distance_to(group[j].position)
			assert_true(distance >= DISPERSION_RADIUS,
				"Dispersed units should maintain minimum separation")

func test_group_reformation() -> void:
	var group: Array[Enemy] = _create_test_group()
	assert_eq(group.size(), GROUP_SIZE, "Should create correct group size")
	
	var leader: Enemy = group[0]
	assert_not_null(leader, "Leader should be available")
	
	# Disperse then reform group
	var disperse_success: bool = _call_node_method_bool(leader, "disperse_group", [group, DISPERSION_RADIUS])
	assert_true(disperse_success, "Group should disperse")
	
	var reform_success: bool = _call_node_method_bool(leader, "reform_group", [group])
	assert_true(reform_success, "Group should reform")
	
	# Verify reformation
	for enemy in group:
		var distance: float = enemy.position.distance_to(leader.position)
		assert_true(distance <= FORMATION_SPACING * 2.0,
			"Reformed units should be near leader")

# Leader Assignment Tests
func test_leader_assignment() -> void:
	var leader := create_test_enemy(EnemyTestType.ELITE)
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
	var leader := create_test_enemy(EnemyTestType.ELITE)
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
	var leader := create_test_enemy(EnemyTestType.ELITE)
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

# Helper Methods
func _create_test_group(size: int = GROUP_SIZE) -> Array[Enemy]:
	var group: Array[Enemy] = []
	var leader: Enemy = create_test_enemy(EnemyTestType.ELITE)
	if not leader:
		push_error("Failed to create leader")
		return group
	group.append(leader)
	
	for i in range(size - 1):
		var follower := create_test_enemy()
		if not follower:
			push_error("Failed to create follower %d" % i)
			continue
		group.append(follower)
	
	return group

func _create_follower_group(size: int) -> Array[Enemy]:
	var followers: Array[Enemy] = []
	for i in range(size):
		var follower := create_test_enemy()
		if not follower:
			push_error("Failed to create follower %d" % i)
			continue
		followers.append(follower)
	return followers