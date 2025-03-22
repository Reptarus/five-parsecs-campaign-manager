@tool
extends "res://tests/fixtures/specialized/enemy_test_base.gd"

# Type-safe instance variables for tactical testing
var _tactical_manager: Node = null
var _combat_manager: Node = null
var _test_battlefield: Node2D = null
var _tactics_system: Node = null
var _test_squad: Array = []
var _test_objectives: Array = []

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
	_test_squad.clear()
	_test_objectives.clear()
	await super.after_each()

# Group Tactical Tests
func test_group_tactical_initialization() -> void:
	var group = _create_tactical_group()
	assert_not_null(group, "Tactical group should be created")
	assert_eq(group.size(), 3, "Tactical group should have correct size")
	
	if group.is_empty():
		push_warning("Group is empty, skipping test")
		return
		
	var leader = group[0]
	assert_not_null(leader, "Leader should be valid")
	
	verify_enemy_complete_state(leader)
	
	if not leader.has_method("is_leader"):
		push_warning("Leader doesn't have is_leader method, skipping test")
		return
		
	assert_true(TypeSafeMixin._call_node_method_bool(leader, "is_leader", [], false), "First enemy should be group leader")
	
	for member in group.slice(1):
		verify_enemy_complete_state(member)
		assert_false(TypeSafeMixin._call_node_method_bool(member, "is_leader", [], false), "Other enemies should not be leaders")

func test_group_formation_tactics() -> void:
	var group = _create_tactical_group()
	assert_not_null(group, "Tactical group should be created")
	
	if group.is_empty():
		push_warning("Group is empty, skipping test")
		return
		
	var formation_data: Dictionary = {
		"type": "wedge",
		"spacing": 2.0,
		"facing": Vector2.RIGHT
	}
	
	# Check if the tactical manager has the required method
	if not _tactical_manager.has_method("set_group_formation"):
		push_warning("Tactical manager doesn't have set_group_formation method, skipping test")
		return
	
	# Test formation setup
	var formation_set = TypeSafeMixin._call_node_method_bool(_tactical_manager, "set_group_formation", [group, formation_data], false)
	assert_true(formation_set, "Formation should be set successfully")
	
	# Verify positions
	if group.size() < 2:
		push_warning("Group too small to verify formations, skipping position verification")
		return
		
	var leader_pos = group[0].position
	for i in range(1, group.size()):
		var member_pos = group[i].position
		var distance = leader_pos.distance_to(member_pos)
		assert_gt(distance, 0.0, "Group members should be properly spaced")
		assert_lt(distance, formation_data.spacing * 3.0, "Group members should not be too far apart")

func test_group_combat_coordination() -> void:
	var group = _create_tactical_group()
	assert_not_null(group, "Tactical group should be created")
	
	if group.is_empty():
		push_warning("Group is empty, skipping test")
		return
		
	var target = create_test_enemy()
	assert_not_null(target, "Target enemy should be created")
	
	add_child_autofree(target)
	
	# Check if the tactical manager has the required method
	if not _tactical_manager.has_method("coordinate_group_attack"):
		push_warning("Tactical manager doesn't have coordinate_group_attack method, skipping test")
		return
		
	# Watch leader signals if signals exist
	if group[0].has_signal("group_attack_coordinated"):
		_signal_watcher.watch_signals(group[0])
	
	# Test group attack coordination
	var coordination_result = TypeSafeMixin._call_node_method_bool(_tactical_manager, "coordinate_group_attack", [group, target], false)
	assert_true(coordination_result, "Group attack coordination should succeed")
	
	# Verify signal if it exists
	if group[0].has_signal("group_attack_coordinated"):
		verify_signal_emitted(group[0], "group_attack_coordinated", "Leader should emit group_attack_coordinated signal")
	
	# Verify attack assignments
	for member in group:
		if not member.has_method("get_current_target"):
			push_warning("Enemy doesn't have get_current_target method, skipping target verification")
			continue
			
		var current_target = TypeSafeMixin._call_node_method(member, "get_current_target", [])
		assert_not_null(current_target, "Each group member should have a target")

func test_group_movement_tactics() -> void:
	var group = _create_tactical_group()
	assert_not_null(group, "Tactical group should be created")
	
	if group.is_empty():
		push_warning("Group is empty, skipping test")
		return
		
	var start_pos = Vector2.ZERO
	var end_pos = Vector2(100, 100)
	
	# Position group at start
	for member in group:
		if not member.has_method("set_position"):
			push_warning("Enemy doesn't have set_position method, skipping test")
			return
			
		TypeSafeMixin._call_node_method_bool(member, "set_position", [start_pos], false)
	
	# Check if the tactical manager has the required method
	if not _tactical_manager.has_method("move_group_to"):
		push_warning("Tactical manager doesn't have move_group_to method, skipping test")
		return
		
	# Watch leader signals if signals exist
	if group[0].has_signal("group_movement_completed"):
		_signal_watcher.watch_signals(group[0])
	
	# Test group movement
	var movement_result = TypeSafeMixin._call_node_method_bool(_tactical_manager, "move_group_to", [group, end_pos], false)
	assert_true(movement_result, "Group movement should succeed")
	
	# Verify signal if it exists
	if group[0].has_signal("group_movement_completed"):
		verify_signal_emitted(group[0], "group_movement_completed", "Leader should emit group_movement_completed signal")
	
	# Verify positions
	for member in group:
		var final_pos = member.position
		assert_lt(final_pos.distance_to(end_pos), 50.0, "Group members should be near target position (distance: %f)" % final_pos.distance_to(end_pos))

func test_group_target_prioritization() -> void:
	var group = _create_tactical_group()
	assert_not_null(group, "Tactical group should be created")
	
	if group.is_empty():
		push_warning("Group is empty, skipping test")
		return
		
	var targets = _create_target_group()
	assert_not_null(targets, "Target group should be created")
	assert_gt(targets.size(), 0, "Target group should not be empty")
	
	# Check if the tactical manager has the required method
	if not _tactical_manager.has_method("assign_group_targets"):
		push_warning("Tactical manager doesn't have assign_group_targets method, skipping test")
		return
	
	# Test target assignment
	var assignment_result = TypeSafeMixin._call_node_method_bool(_tactical_manager, "assign_group_targets", [group, targets], false)
	assert_true(assignment_result, "Target assignment should succeed")
	
	# Verify target assignments
	var assigned_targets = []
	for member in group:
		if not member.has_method("get_current_target"):
			push_warning("Enemy doesn't have get_current_target method, skipping target verification")
			continue
			
		var current_target = TypeSafeMixin._call_node_method(member, "get_current_target", [])
		assert_not_null(current_target, "Each member should have a target")
		assert_false(current_target in assigned_targets, "Targets should not be duplicated")
		assigned_targets.append(current_target)

func test_group_cover_tactics() -> void:
	var group = _create_tactical_group()
	assert_not_null(group, "Tactical group should be created")
	
	if group.is_empty():
		push_warning("Group is empty, skipping test")
		return
		
	var cover_points = _create_cover_points()
	assert_gt(cover_points.size(), 0, "Cover points should not be empty")
	
	# Check if the tactical manager has the required method
	if not _tactical_manager.has_method("assign_group_cover"):
		push_warning("Tactical manager doesn't have assign_group_cover method, skipping test")
		return
	
	# Test cover assignment
	var cover_result = TypeSafeMixin._call_node_method_bool(_tactical_manager, "assign_group_cover", [group, cover_points], false)
	assert_true(cover_result, "Cover assignment should succeed")
	
	# Verify cover positions
	for member in group:
		if not member.has_method("get_cover_position"):
			push_warning("Enemy doesn't have get_cover_position method, skipping cover verification")
			continue
			
		var cover_pos = TypeSafeMixin._safe_cast_vector2(TypeSafeMixin._call_node_method(member, "get_cover_position", []))
		assert_not_null(cover_pos, "Each member should have a cover position")
		
		var found_pos = false
		for point in cover_points:
			if point.is_equal_approx(cover_pos):
				found_pos = true
				break
				
		assert_true(found_pos, "Cover position %s should be from available points %s" % [cover_pos, cover_points])

func test_group_retreat_conditions() -> void:
	var group = _create_tactical_group()
	assert_not_null(group, "Tactical group should be created")
	
	if group.is_empty():
		push_warning("Group is empty, skipping test")
		return
		
	var retreat_threshold: float = 0.25 # Retreat at 25% health
	
	# Check if the tactical manager has the required methods
	if not _tactical_manager.has_method("set_group_retreat_threshold") or not _tactical_manager.has_method("should_group_retreat"):
		push_warning("Tactical manager doesn't have required retreat methods, skipping test")
		return
	
	# Set retreat threshold for group
	var threshold_result = TypeSafeMixin._call_node_method_bool(_tactical_manager, "set_group_retreat_threshold", [group, retreat_threshold], false)
	assert_true(threshold_result, "Retreat threshold should be set successfully")
	
	# Damage members but not enough to trigger retreat
	for member in group:
		if not member.has_method("get_max_health") or not member.has_method("take_damage"):
			push_warning("Enemy doesn't have required health methods, skipping test")
			return
			
		var max_health = TypeSafeMixin._safe_cast_float(TypeSafeMixin._call_node_method(member, "get_max_health", []))
		assert_gt(max_health, 0.0, "Enemy max health should be greater than zero")
		
		var damage_result = TypeSafeMixin._call_node_method_bool(member, "take_damage", [max_health * 0.8], false)
		assert_true(damage_result, "Enemy should take damage successfully")
	
	# Verify group doesn't retreat yet
	var should_retreat = TypeSafeMixin._call_node_method_bool(_tactical_manager, "should_group_retreat", [group], false)
	assert_false(should_retreat, "Group should not retreat yet")
	
	# Apply more damage to trigger retreat
	for member in group:
		if not member.has_method("get_current_health") or not member.has_method("take_damage"):
			push_warning("Enemy doesn't have required health methods, skipping test")
			return
			
		var current_health = TypeSafeMixin._safe_cast_float(TypeSafeMixin._call_node_method(member, "get_current_health", []))
		assert_gt(current_health, 0.0, "Enemy should still have some health")
		
		var damage_result = TypeSafeMixin._call_node_method_bool(member, "take_damage", [current_health * 0.7], false)
		assert_true(damage_result, "Enemy should take additional damage successfully")
	
	# Verify group retreats
	should_retreat = TypeSafeMixin._call_node_method_bool(_tactical_manager, "should_group_retreat", [group], false)
	assert_true(should_retreat, "Group should retreat now that health is low")

func test_group_reinforcement_tactics() -> void:
	var main_group = _create_tactical_group()
	assert_not_null(main_group, "Main tactical group should be created")
	
	if main_group.is_empty():
		push_warning("Main group is empty, skipping test")
		return
		
	var reinforcements = _create_tactical_group()
	assert_not_null(reinforcements, "Reinforcement group should be created")
	
	if reinforcements.is_empty():
		push_warning("Reinforcement group is empty, skipping test")
		return
	
	# Check if the tactical manager has the required methods
	if not _tactical_manager.has_method("integrate_reinforcements") or not _tactical_manager.has_method("get_group_members"):
		push_warning("Tactical manager doesn't have required reinforcement methods, skipping test")
		return
	
	# Test reinforcement integration
	var integration_result = TypeSafeMixin._call_node_method_bool(_tactical_manager, "integrate_reinforcements", [main_group, reinforcements], false)
	assert_true(integration_result, "Reinforcements should be integrated successfully")
	
	# Verify combined group
	var combined_group = TypeSafeMixin._call_node_method_array(_tactical_manager, "get_group_members", [main_group[0]], [])
	assert_not_null(combined_group, "Combined group should be returned")
	assert_eq(combined_group.size(), main_group.size() + reinforcements.size(),
		"Combined group should have correct size (expected: %d, actual: %d)" % [main_group.size() + reinforcements.size(), combined_group.size()])

func test_group_leadership_mechanics() -> void:
	var group = _create_tactical_group()
	assert_not_null(group, "Tactical group should be created")
	
	if group.size() < 2:
		push_warning("Group needs at least 2 members for leadership test, skipping test")
		return
		
	var leader = group[0]
	var member = group[1]
	
	# Check if enemies have the required methods
	if not leader.has_method("set_as_leader") or not member.has_method("set_as_leader") or not leader.has_method("is_leader") or not member.has_method("is_leader"):
		push_warning("Enemies don't have required leadership methods, skipping test")
		return
	
	# Test leadership transfer
	var leader_unset = TypeSafeMixin._call_node_method_bool(leader, "set_as_leader", [false], false)
	assert_true(leader_unset, "Leader status should be unset successfully")
	
	var member_set = TypeSafeMixin._call_node_method_bool(member, "set_as_leader", [true], false)
	assert_true(member_set, "Member should be set as leader successfully")
	
	# Verify leadership transfer
	assert_false(TypeSafeMixin._call_node_method_bool(leader, "is_leader", [], false), "Original leader should not be leader anymore")
	assert_true(TypeSafeMixin._call_node_method_bool(member, "is_leader", [], false), "New member should be leader")

func test_group_behavior_tree() -> void:
	var group = _create_tactical_group()
	assert_not_null(group, "Tactical group should be created")
	
	if group.is_empty():
		push_warning("Group is empty, skipping test")
		return
		
	var targets = _create_target_group()
	assert_not_null(targets, "Target group should be created")
	
	if targets.is_empty():
		push_warning("Target group is empty, skipping test")
		return
	
	# Check if the tactical manager has the required method
	if not _tactical_manager.has_method("assign_group_targets"):
		push_warning("Tactical manager doesn't have assign_group_targets method, skipping test")
		return
	
	# Setup the behavior tree
	var all_have_required_methods = true
	for member in group:
		if not member.has_method("start_turn"):
			all_have_required_methods = false
			break
			
	if not all_have_required_methods:
		push_warning("Some group members lack required turn methods, skipping test")
		return
		
	for member in group:
		var result = TypeSafeMixin._call_node_method_bool(member, "start_turn", [], false)
		assert_true(result, "Member should start turn successfully")
	
	# Test target assignment through behavior tree
	var assignment_result = TypeSafeMixin._call_node_method_bool(_tactical_manager, "assign_group_targets", [group, targets], false)
	assert_true(assignment_result, "Target assignment should succeed")
	
	# Verify behavior execution
	for member in group:
		if not member.has_method("get_current_target") or not member.has_method("can_attack") or not member.has_method("attack"):
			push_warning("Enemy doesn't have required combat methods, skipping attack verification")
			continue
			
		var target = TypeSafeMixin._call_node_method(member, "get_current_target", [])
		if target and TypeSafeMixin._call_node_method_bool(member, "can_attack", [], false):
			var attack_result = TypeSafeMixin._call_node_method_bool(member, "attack", [target], false)
			assert_true(attack_result, "Attack should succeed")
	
	# End turn
	for member in group:
		if not member.has_method("end_turn"):
			push_warning("Enemy doesn't have end_turn method, skipping verification")
			continue
			
		var end_result = TypeSafeMixin._call_node_method_bool(member, "end_turn", [], false)
		assert_true(end_result, "Member should end turn successfully")
	
	# Verify state changes after behavior tree execution
	for member in group:
		if not member.has_method("is_acting"):
			push_warning("Enemy doesn't have is_acting method, skipping verification")
			continue
			
		assert_false(TypeSafeMixin._call_node_method_bool(member, "is_acting", [], false), "Members should not be acting after turn end")

# Helper Methods
func _create_tactical_group() -> Array:
	var group = []
	
	# Create leader
	var leader = create_test_enemy(EnemyTestType.ELITE)
	if not leader:
		push_error("Failed to create group leader")
		return []
		
	if leader.has_method("set_as_leader"):
		TypeSafeMixin._call_node_method_bool(leader, "set_as_leader", [true], false)
		
	add_child_autofree(leader)
	group.append(leader)
	
	# Create members
	for i in range(2):
		var member = create_test_enemy(EnemyTestType.BASIC)
		if not member:
			push_error("Failed to create group member")
			continue
			
		if member.has_method("set_as_leader"):
			TypeSafeMixin._call_node_method_bool(member, "set_as_leader", [false], false)
			
		add_child_autofree(member)
		group.append(member)
	
	return group

func _create_target_group() -> Array:
	var targets = []
	
	for i in range(3):
		var target = create_test_enemy()
		if not target:
			push_error("Failed to create target")
			continue
			
		add_child_autofree(target)
		targets.append(target)
	
	return targets

func _create_cover_points() -> Array:
	var cover_points = []
	
	for i in range(5):
		cover_points.append(Vector2(i * 50, i * 50))
	
	return cover_points