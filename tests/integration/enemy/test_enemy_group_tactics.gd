@tool
extends "res://tests/fixtures/specialized/enemy_test_base.gd"

# Type-safe instance variables for tactical testing
var _tactical_manager: Node = null
var _combat_manager: Node = null
var _test_battlefield: Node2D = null
var _tactics_system: Node = null
var _test_squad: Array[Enemy] = []
var _test_objectives: Array[Node2D] = []

func before_each() -> void:
	await super.before_each()
	
	# Setup tactical test environment
	_tactical_manager = Node.new()
	if not _tactical_manager:
		push_error("Failed to create tactical manager")
		return
	_tactical_manager.name = "TacticalManager"
	add_child_autofree(_tactical_manager)
	track_test_node(_tactical_manager)
	
	_combat_manager = Node.new()
	if not _combat_manager:
		push_error("Failed to create combat manager")
		return
	_combat_manager.name = "CombatManager"
	add_child_autofree(_combat_manager)
	track_test_node(_combat_manager)
	
	_test_battlefield = Node2D.new()
	if not _test_battlefield:
		push_error("Failed to create test battlefield")
		return
	_test_battlefield.name = "TestBattlefield"
	add_child_autofree(_test_battlefield)
	track_test_node(_test_battlefield)
	
	await stabilize_engine(STABILIZE_TIME)

func after_each() -> void:
	_tactical_manager = null
	_combat_manager = null
	_test_battlefield = null
	await super.after_each()

# Group Tactical Tests
func test_group_tactical_initialization() -> void:
	var group: Array[Enemy] = _create_tactical_group()
	assert_eq(group.size(), 3, "Tactical group should have correct size")
	
	var leader: Enemy = group[0]
	verify_enemy_complete_state(leader)
	assert_true(TypeSafeMixin._call_node_method_bool(leader, "is_leader", []), "First enemy should be group leader")
	
	for member in group.slice(1):
		verify_enemy_complete_state(member)
		assert_false(TypeSafeMixin._call_node_method_bool(member, "is_leader", []), "Other enemies should not be leaders")

func test_group_formation_tactics() -> void:
	var group: Array[Enemy] = _create_tactical_group()
	var formation_data: Dictionary = {
		"type": "wedge",
		"spacing": 2.0,
		"facing": Vector2.RIGHT
	}
	
	# Test formation setup
	TypeSafeMixin._call_node_method_bool(_tactical_manager, "set_group_formation", [group, formation_data])
	
	# Verify positions
	var leader_pos: Vector2 = group[0].position
	for i in range(1, group.size()):
		var member_pos: Vector2 = group[i].position
		var distance: float = leader_pos.distance_to(member_pos)
		assert_gt(distance, 0.0, "Group members should be properly spaced")
		assert_lt(distance, formation_data.spacing * 3.0, "Group members should not be too far apart")

func test_group_combat_coordination() -> void:
	var group: Array[Enemy] = _create_tactical_group()
	var target: Enemy = create_test_enemy()
	add_child_autofree(target)
	
	_signal_watcher.watch_signals(group[0]) # Watch leader signals
	
	# Test group attack coordination
	TypeSafeMixin._call_node_method_bool(_tactical_manager, "coordinate_group_attack", [group, target])
	verify_signal_emitted(group[0], "group_attack_coordinated")
	
	# Verify attack assignments
	for member in group:
		var current_target: Enemy = TypeSafeMixin._call_node_method(member, "get_current_target", [])
		assert_not_null(current_target, "Each group member should have a target")

func test_group_movement_tactics() -> void:
	var group: Array[Enemy] = _create_tactical_group()
	var start_pos: Vector2 = Vector2.ZERO
	var end_pos: Vector2 = Vector2(100, 100)
	
	# Position group at start
	for member in group:
		TypeSafeMixin._call_node_method_bool(member, "set_position", [start_pos])
	
	# Test group movement
	_signal_watcher.watch_signals(group[0]) # Watch leader signals
	TypeSafeMixin._call_node_method_bool(_tactical_manager, "move_group_to", [group, end_pos])
	verify_signal_emitted(group[0], "group_movement_completed")
	
	# Verify positions
	for member in group:
		var final_pos: Vector2 = member.position
		assert_lt(final_pos.distance_to(end_pos), 50.0, "Group members should be near target position")

func test_group_target_prioritization() -> void:
	var group: Array[Enemy] = _create_tactical_group()
	var targets: Array[Enemy] = _create_target_group()
	
	# Test target assignment
	TypeSafeMixin._call_node_method_bool(_tactical_manager, "assign_group_targets", [group, targets])
	
	# Verify target assignments
	var assigned_targets: Array[Enemy] = []
	for member in group:
		var current_target: Enemy = TypeSafeMixin._call_node_method(member, "get_current_target", [])
		assert_not_null(current_target, "Each member should have a target")
		assert_false(current_target in assigned_targets, "Targets should not be duplicated")
		assigned_targets.append(current_target)

func test_group_cover_tactics() -> void:
	var group: Array[Enemy] = _create_tactical_group()
	var cover_points: Array[Vector2] = _create_cover_points()
	
	# Test cover assignment
	TypeSafeMixin._call_node_method_bool(_tactical_manager, "assign_group_cover", [group, cover_points])
	
	# Verify cover positions
	for member in group:
		var cover_pos: Vector2 = TypeSafeMixin._safe_cast_vector2(TypeSafeMixin._call_node_method(member, "get_cover_position", []))
		assert_not_null(cover_pos, "Each member should have a cover position")
		assert_true(cover_pos in cover_points, "Cover positions should be from available points")

func test_group_retreat_conditions() -> void:
	var group: Array[Enemy] = _create_tactical_group()
	var retreat_threshold: float = 0.25 # Retreat at 25% health
	
	# Set retreat threshold for group
	TypeSafeMixin._call_node_method_bool(_tactical_manager, "set_group_retreat_threshold", [group, retreat_threshold])
	
	# Damage members but not enough to trigger retreat
	for member in group:
		var max_health: float = TypeSafeMixin._safe_cast_float(TypeSafeMixin._call_node_method(member, "get_max_health", []))
		TypeSafeMixin._call_node_method_bool(member, "take_damage", [max_health * 0.8]) # Take 80% damage
	
	# Verify group doesn't retreat yet
	assert_false(
		TypeSafeMixin._call_node_method_bool(_tactical_manager, "should_group_retreat", [group]),
		"Group should not retreat yet"
	)
	
	# Apply more damage to trigger retreat
	for member in group:
		var current_health: float = TypeSafeMixin._safe_cast_float(TypeSafeMixin._call_node_method(member, "get_current_health", []))
		TypeSafeMixin._call_node_method_bool(member, "take_damage", [current_health * 0.7]) # Take 70% of remaining health
	
	# Verify group retreats
	assert_true(
		TypeSafeMixin._call_node_method_bool(_tactical_manager, "should_group_retreat", [group]),
		"Group should retreat"
	)

func test_group_reinforcement_tactics() -> void:
	var main_group: Array[Enemy] = _create_tactical_group()
	var reinforcements: Array[Enemy] = _create_tactical_group()
	
	# Test reinforcement integration
	TypeSafeMixin._call_node_method_bool(_tactical_manager, "integrate_reinforcements", [main_group, reinforcements])
	
	# Verify combined group
	var combined_group: Array[Enemy] = TypeSafeMixin._call_node_method_array(_tactical_manager, "get_group_members", [main_group[0]])
	assert_eq(combined_group.size(), main_group.size() + reinforcements.size(), "Combined group should have correct size")

func test_group_leadership_mechanics() -> void:
	var group: Array[Enemy] = _create_tactical_group()
	var leader: Enemy = group[0]
	var member: Enemy = group[1]
	
	# Test leadership transfer
	TypeSafeMixin._call_node_method_bool(leader, "set_as_leader", [false])
	TypeSafeMixin._call_node_method_bool(member, "set_as_leader", [true])
	
	# Verify leadership transfer
	assert_false(TypeSafeMixin._call_node_method_bool(leader, "is_leader", []), "Original leader should not be leader anymore")
	assert_true(TypeSafeMixin._call_node_method_bool(member, "is_leader", []), "New member should be leader")

func test_group_behavior_tree() -> void:
	var group: Array[Enemy] = _create_tactical_group()
	var targets: Array[Enemy] = _create_target_group()
	
	# Setup the behavior tree
	for member in group:
		TypeSafeMixin._call_node_method_bool(member, "start_turn", [])
	
	# Test target assignment through behavior tree
	TypeSafeMixin._call_node_method_bool(_tactical_manager, "assign_group_targets", [group, targets])
	
	# Verify behavior execution
	for member in group:
		var target: Enemy = TypeSafeMixin._call_node_method(member, "get_current_target", [])
		if target and TypeSafeMixin._call_node_method_bool(member, "can_attack", []):
			TypeSafeMixin._call_node_method_bool(member, "attack", [target])
	
	# End turn
	for member in group:
		TypeSafeMixin._call_node_method_bool(member, "end_turn", [])
	
	# Verify state changes after behavior tree execution
	for member in group:
		assert_false(TypeSafeMixin._call_node_method_bool(member, "is_acting", []), "Members should not be acting after turn end")

# Helper Methods
func _create_tactical_group() -> Array[Enemy]:
	var group: Array[Enemy] = []
	
	# Create leader
	var leader: Enemy = create_test_enemy("ELITE")
	if not leader:
		push_error("Failed to create group leader")
		return []
	TypeSafeMixin._call_node_method_bool(leader, "set_as_leader", [true])
	add_child_autofree(leader)
	group.append(leader)
	
	# Create members
	for i in range(2):
		var member: Enemy = create_test_enemy("BASIC")
		if not member:
			push_error("Failed to create group member")
			continue
		TypeSafeMixin._call_node_method_bool(member, "set_as_leader", [false])
		add_child_autofree(member)
		group.append(member)
	
	return group

func _create_target_group() -> Array[Enemy]:
	var targets: Array[Enemy] = []
	
	for i in range(3):
		var target: Enemy = create_test_enemy()
		if not target:
			push_error("Failed to create target")
			continue
		add_child_autofree(target)
		targets.append(target)
	
	return targets

func _create_cover_points() -> Array[Vector2]:
	var cover_points: Array[Vector2] = []
	
	for i in range(5):
		cover_points.append(Vector2(i * 50, i * 50))
	
	return cover_points