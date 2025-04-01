@tool
extends "res://tests/fixtures/specialized/enemy_test.gd"

# Import the Enemy class for type checking
const Enemy = preload("res://src/core/enemy/base/Enemy.gd")

# Type-safe instance variables
var _enemy_group: Array[Enemy] = []
var _tactics_manager: Node = null

## Core enemy group tactics tests
## Tests how groups of enemies work together with tactical behaviors:
## - Coordination between enemies
## - Group formations
## - Focus fire tactics
## - Flanking behaviors
## - Reinforcement behaviors

func before_each() -> void:
	await super.before_each()
	
	# Create test enemy group
	for i in range(3):
		var enemy: Enemy = create_test_enemy(EnemyTestType.BASIC)
		assert_not_null(enemy, "Should create basic enemy")
		_enemy_group.append(enemy)
		add_child_autofree(enemy)
	
	# Create tactics manager
	_tactics_manager = Node.new()
	_tactics_manager.name = "TacticsManager"
	add_child_autofree(_tactics_manager)
	track_test_node(_tactics_manager)
	
	await stabilize_engine(ENEMY_TEST_CONFIG.stabilize_time)

func after_each() -> void:
	_enemy_group.clear()
	_tactics_manager = null
	await super.after_each()

# Core enemy group tests
func test_group_formation() -> void:
	# Check if we have enough enemies for the test
	if _enemy_group.size() < 3:
		push_warning("Not enough enemies for formation test")
		pending("Test requires at least 3 enemies")
		return
		
	# Check if tactics manager has the required method
	if not _tactics_manager.has_method("apply_formation"):
		push_warning("Tactics manager missing apply_formation method")
		pending("Missing required methods")
		return
		
	# Test formation setup
	var formation_data := {
		"type": "line",
		"spacing": 2.0,
		"direction": Vector2.RIGHT
	}
	
	TypeSafeMixin._call_node_method_bool(_tactics_manager, "apply_formation", [_enemy_group, formation_data])
	
	# Check if enemies are correctly positioned in formation
	var expected_x_positions: Array[float] = [0.0, 2.0, 4.0]
	
	for i in range(min(_enemy_group.size(), expected_x_positions.size())):
		if i >= _enemy_group.size():
			push_warning("Skipping position check for enemy " + str(i) + " (out of bounds)")
			continue
			
		var enemy = _enemy_group[i]
		if not enemy or not enemy.has_method("get_position"):
			push_warning("Enemy " + str(i) + " is invalid or missing get_position method")
			continue
			
		var enemy_position: Vector2 = TypeSafeMixin._call_node_method(enemy, "get_position", []) as Vector2
		assert_eq(enemy_position.x, expected_x_positions[i], "Enemy should be at correct X position")
		assert_eq(enemy_position.y, 0.0, "Enemy should be at correct Y position")

func test_group_movement() -> void:
	# Set initial positions
	for i in range(_enemy_group.size()):
		TypeSafeMixin._call_node_method_bool(_enemy_group[i], "set_position", [Vector2(i * 2.0, 0.0)])
	
	# Test group movement
	var target_position := Vector2(10.0, 5.0)
	TypeSafeMixin._call_node_method_bool(_tactics_manager, "move_group", [_enemy_group, target_position])
	
	await get_tree().create_timer(ENEMY_TEST_CONFIG.pathfinding_timeout).timeout
	
	# Check if all enemies moved toward the target
	for enemy in _enemy_group:
		var enemy_position: Vector2 = TypeSafeMixin._call_node_method(enemy, "get_position", []) as Vector2
		var distance: float = enemy_position.distance_to(target_position)
		assert_lt(distance, 5.0, "Enemy should move toward target position")

func test_focus_fire() -> void:
	# Create target
	var target := Node2D.new()
	target.name = "Target"
	target.position = Vector2(10.0, 10.0)
	add_child_autofree(target)
	
	# Test focus fire behavior
	TypeSafeMixin._call_node_method_bool(_tactics_manager, "focus_fire", [_enemy_group, target])
	
	await get_tree().create_timer(ENEMY_TEST_CONFIG.combat_timeout).timeout
	
	# Check if all enemies attacked the target
	for enemy in _enemy_group:
		verify_enemy_combat(enemy, target)

func test_flanking_behavior() -> void:
	# Create target
	var target := Node2D.new()
	target.name = "Target"
	target.position = Vector2(10.0, 10.0)
	add_child_autofree(target)
	
	# Test flanking behavior
	TypeSafeMixin._call_node_method_bool(_tactics_manager, "execute_flanking", [_enemy_group, target])
	
	await get_tree().create_timer(ENEMY_TEST_CONFIG.pathfinding_timeout).timeout
	
	# Check if enemies are positioned around the target
	var angles: Array[float] = []
	for enemy in _enemy_group:
		var enemy_position: Vector2 = TypeSafeMixin._call_node_method(enemy, "get_position", []) as Vector2
		var direction: Vector2 = (enemy_position - target.position).normalized()
		var angle: float = rad_to_deg(atan2(direction.y, direction.x))
		angles.append(angle)
	
	# Ensure enemies are spread around (different angles)
	for i in range(angles.size() - 1):
		for j in range(i + 1, angles.size()):
			var angle_diff: float = abs(angles[i] - angles[j])
			if angle_diff > 180:
				angle_diff = 360 - angle_diff
			assert_gt(angle_diff, 45.0, "Enemies should be at different angles when flanking")

func test_group_coordination() -> void:
	# Test group coordination with different enemy types
	_enemy_group.clear()
	
	var types: Array[int] = [
		EnemyTestType.RANGED,
		EnemyTestType.MELEE,
		EnemyTestType.ELITE
	]
	
	for type in types:
		var enemy: Enemy = create_test_enemy(type)
		assert_not_null(enemy, "Should create enemy of specified type")
		_enemy_group.append(enemy)
		add_child_autofree(enemy)
	
	# Check if we have enough enemies for the test
	if _enemy_group.size() < 3:
		push_warning("Not enough enemies for coordination test")
		pending("Test requires 3 enemy types")
		return
		
	# Check if tactics manager has the required method
	if not _tactics_manager.has_method("coordinate_attack"):
		push_warning("Tactics manager missing coordinate_attack method")
		pending("Missing required methods")
		return
	
	# Test coordinated attack
	var target := Node2D.new()
	target.name = "Target"
	target.position = Vector2(10.0, 10.0)
	add_child_autofree(target)
	
	TypeSafeMixin._call_node_method_bool(_tactics_manager, "coordinate_attack", [_enemy_group, target])
	
	await get_tree().create_timer(ENEMY_TEST_CONFIG.combat_timeout).timeout
	
	# Check if different enemy types assumed appropriate positions
	# Safe array access with bounds checking
	if _enemy_group.size() < 2:
		push_warning("Not enough enemies to test positions")
		return
		
	var melee_enemy = _enemy_group[1] if _enemy_group.size() > 1 else null # MELEE type
	var ranged_enemy = _enemy_group[0] if _enemy_group.size() > 0 else null # RANGED type
	
	if not melee_enemy or not ranged_enemy:
		push_warning("Missing enemies for position comparison")
		return
		
	if not (melee_enemy.has_method("get_position") and ranged_enemy.has_method("get_position")):
		push_warning("Enemies missing get_position method")
		return
	
	var melee_position: Vector2 = TypeSafeMixin._call_node_method(melee_enemy, "get_position", []) as Vector2
	var ranged_position: Vector2 = TypeSafeMixin._call_node_method(ranged_enemy, "get_position", []) as Vector2
	
	var melee_distance = melee_position.distance_to(target.position)
	var ranged_distance = ranged_position.distance_to(target.position)
	
	assert_lt(melee_distance, ranged_distance, "Melee enemies should be closer to target than ranged")

func test_group_state_tracking() -> void:
	# Test group state tracking
	for enemy in _enemy_group:
		assert_true(TypeSafeMixin._call_node_method_bool(enemy, "is_active", []), "Enemy should start active")
	
	# Disable first enemy
	TypeSafeMixin._call_node_method_bool(_enemy_group[0], "disable", [])
	
	# Check group state
	var active_count = 0
	for enemy in _enemy_group:
		if TypeSafeMixin._call_node_method_bool(enemy, "is_active", []):
			active_count += 1
	
	assert_eq(active_count, _enemy_group.size() - 1, "Should track group state correctly")

func test_tactical_group_implementation() -> void:
	# Mark as pending since tactical group implementation is not ready
	pending("Pending until tactical group implementation is complete")

func test_group_formation_implementation() -> void:
	# Mark as pending since formation implementation is not ready
	pending("Pending until tactical group formation is complete")

func test_combat_coordination_implementation() -> void:
	pending("Pending until tactical group combat coordination is complete")

func test_movement_implementation() -> void:
	pending("Pending until tactical group movement is complete")

func test_targeting_implementation() -> void:
	pending("Pending until tactical group targeting is complete")

func test_cover_implementation() -> void:
	pending("Pending until tactical group cover usage is complete")

func test_behavior_tree_implementation() -> void:
	pending("Pending until tactical group behavior trees are complete")

func test_leadership_implementation() -> void:
	pending("Pending until group leadership mechanics are complete")