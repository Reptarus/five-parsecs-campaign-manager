@tool
extends "res://tests/fixtures/specialized/enemy_test.gd"

# Type-safe instance variables
var _save_manager: Node = null

# Type-safe lifecycle methods
func before_each() -> void:
	await super.before_each()
	
	# Setup save system test environment
	_save_manager = Node.new()
	if not _save_manager:
		push_error("Failed to create save manager")
		return
	_save_manager.name = "SaveManager"
	add_child_autofree(_save_manager)
	track_test_node(_save_manager)
	
	# Create test enemies
	_test_enemies.clear()
	for i in range(3):
		var enemy: Enemy = create_test_enemy()
		if not enemy:
			push_error("Failed to create test enemy %d" % i)
			continue
		_test_enemies.append(enemy)
		track_test_node(enemy)
	
	await stabilize_engine()

func after_each() -> void:
	_save_manager = null
	_test_enemies.clear()
	await super.after_each()

# Helper methods
func _capture_enemy_state(enemy: Enemy) -> Dictionary:
	if not enemy:
		push_error("Cannot capture state: enemy is null")
		return {}
		
	return {
		"position": _call_node_method_vector2(enemy, "get_position", []),
		"health": _call_node_method_float(enemy, "get_health", []),
		"behavior": _call_node_method_int(enemy, "get_behavior", []),
		"movement_range": _call_node_method_float(enemy, "get_movement_range", []),
		"weapon_range": _call_node_method_float(enemy, "get_weapon_range", []),
		"state": _call_node_method_dict(enemy, "get_state", [])
	}

func _capture_group_states(group: Array[Enemy]) -> Array[Dictionary]:
	var states: Array[Dictionary] = []
	for enemy in group:
		if not enemy:
			push_error("Cannot capture group state: enemy is null")
			continue
		states.append(_capture_enemy_state(enemy))
	return states

func _create_test_group(size: int = 3) -> Array[Enemy]:
	var group: Array[Enemy] = []
	for i in range(size):
		var enemy: Enemy = create_test_enemy()
		if not enemy:
			push_error("Failed to create test group enemy %d" % i)
			continue
		group.append(enemy)
		track_test_node(enemy)
	return group

# Basic State Tests
func test_basic_state() -> void:
	var enemy: Enemy = create_test_enemy()
	if not enemy:
		push_error("Failed to create enemy for basic state test")
		return
	track_test_node(enemy)
	
	# Set initial state
	var health := 100.0
	var position := Vector2(10, 10)
	_call_node_method_bool(enemy, "set_health", [health])
	_call_node_method_bool(enemy, "set_position", [position])
	_call_node_method_bool(enemy, "set_stance", [GameEnums.CombatTactic.AGGRESSIVE])
	
	# Verify state was set
	var current_health: float = _call_node_method_float(enemy, "get_health", [])
	var current_position: Vector2 = _call_node_method_vector2(enemy, "get_position", [])
	var current_stance: int = _call_node_method_int(enemy, "get_stance", [])
	
	assert_eq(current_health, health, "Health should be set correctly")
	assert_eq(current_position, position, "Position should be set correctly")
	assert_eq(current_stance, GameEnums.CombatTactic.AGGRESSIVE, "Combat stance should be set correctly")

# State Persistence Tests
func test_state_persistence() -> void:
	var enemy: Enemy = create_test_enemy()
	if not enemy:
		push_error("Failed to create enemy for state persistence test")
		return
	track_test_node(enemy)
	
	var initial_state: Dictionary = _capture_enemy_state(enemy)
	
	# Modify state
	_call_node_method_bool(enemy, "take_damage", [20])
	_call_node_method_bool(enemy, "set_position", [Vector2(100, 100)])
	
	# Save state
	var saved_state: Dictionary = _call_node_method_dict(enemy, "save", [])
	
	# Create new enemy and load state
	var new_enemy: Enemy = create_test_enemy()
	if not new_enemy:
		push_error("Failed to create new enemy for state persistence test")
		return
	track_test_node(new_enemy)
	
	_call_node_method_bool(new_enemy, "load", [saved_state])
	
	# Verify state restoration
	var old_health: float = _call_node_method_float(enemy, "get_health", [])
	var new_health: float = _call_node_method_float(new_enemy, "get_health", [])
	var old_position: Vector2 = _call_node_method_vector2(enemy, "get_position", [])
	var new_position: Vector2 = _call_node_method_vector2(new_enemy, "get_position", [])
	
	assert_eq(new_health, old_health, "Health should be restored")
	assert_eq(new_position, old_position, "Position should be restored")

# Group State Tests
func test_group_state_persistence() -> void:
	var group: Array[Enemy] = _create_test_group()
	var group_states: Array[Dictionary] = _capture_group_states(group)
	
	# Modify group states
	for enemy in group:
		if not enemy:
			push_error("Invalid enemy in group")
			continue
		_call_node_method_bool(enemy, "take_damage", [10])
		var current_pos: Vector2 = _call_node_method_vector2(enemy, "get_position", [])
		_call_node_method_bool(enemy, "set_position", [current_pos + Vector2(50, 50)])
	
	# Save group states
	var saved_states: Array[Dictionary] = []
	for enemy in group:
		if not enemy:
			push_error("Invalid enemy in group during save")
			continue
		var state: Dictionary = _call_node_method_dict(enemy, "save", [])
		saved_states.append(state)
	
	# Create new group and restore states
	var new_group: Array[Enemy] = _create_test_group()
	for i in range(new_group.size()):
		if i >= saved_states.size():
			break
		if not new_group[i]:
			push_error("Invalid enemy in new group")
			continue
		_call_node_method_bool(new_group[i], "load", [saved_states[i]])
	
	# Verify group state restoration
	for i in range(group.size()):
		if i >= new_group.size():
			break
		if not group[i] or not new_group[i]:
			push_error("Invalid enemy during verification")
			continue
			
		var old_health: float = _call_node_method_float(group[i], "get_health", [])
		var new_health: float = _call_node_method_float(new_group[i], "get_health", [])
		var old_position: Vector2 = _call_node_method_vector2(group[i], "get_position", [])
		var new_position: Vector2 = _call_node_method_vector2(new_group[i], "get_position", [])
		
		assert_eq(new_health, old_health, "Group member health should be restored")
		assert_eq(new_position, old_position, "Group member position should be restored")

# Combat State Tests
func test_combat_state_persistence() -> void:
	var enemy: Enemy = create_test_enemy()
	if not enemy:
		push_error("Failed to create enemy for combat state test")
		return
	track_test_node(enemy)
	
	# Setup combat state
	_call_node_method_bool(enemy, "take_damage", [20])
	_call_node_method_bool(enemy, "apply_status_effect", ["poison", 3])
	
	var target: Enemy = create_test_enemy()
	if not target:
		push_error("Failed to create target enemy")
		return
	track_test_node(target)
	_call_node_method_bool(enemy, "set_target", [target])
	
	# Save combat state
	var saved_state: Dictionary = _call_node_method_dict(enemy, "save", [])
	
	# Create new enemy and load state
	var new_enemy: Enemy = create_test_enemy()
	if not new_enemy:
		push_error("Failed to create new enemy for combat state test")
		return
	track_test_node(new_enemy)
	
	_call_node_method_bool(new_enemy, "load", [saved_state])
	
	# Verify combat state restoration
	var old_health: float = _call_node_method_float(enemy, "get_health", [])
	var new_health: float = _call_node_method_float(new_enemy, "get_health", [])
	var has_poison: bool = _call_node_method_bool(new_enemy, "has_status_effect", ["poison"])
	var new_target: Node = _call_node_method_object(new_enemy, "get_target", [])
	
	assert_eq(new_health, old_health, "Combat health should be restored")
	assert_true(has_poison, "Status effects should be restored")
	assert_not_null(new_target, "Target should be restored")

# AI State Tests
func test_ai_state_persistence() -> void:
	var enemy: Enemy = create_test_enemy()
	if not enemy:
		push_error("Failed to create enemy for AI state test")
		return
	track_test_node(enemy)
	
	# Setup AI state
	_call_node_method_bool(enemy, "set_behavior", [GameEnums.AIBehavior.AGGRESSIVE])
	_call_node_method_bool(enemy, "set_stance", [GameEnums.CombatTactic.AGGRESSIVE])
	
	# Save AI state
	var saved_state: Dictionary = _call_node_method_dict(enemy, "save", [])
	
	# Create new enemy and load state
	var new_enemy: Enemy = create_test_enemy()
	if not new_enemy:
		push_error("Failed to create new enemy for AI state test")
		return
	track_test_node(new_enemy)
	
	_call_node_method_bool(new_enemy, "load", [saved_state])
	
	# Verify AI state restoration
	var old_behavior: int = _call_node_method_int(enemy, "get_behavior", [])
	var new_behavior: int = _call_node_method_int(new_enemy, "get_behavior", [])
	var old_stance: int = _call_node_method_int(enemy, "get_stance", [])
	var new_stance: int = _call_node_method_int(new_enemy, "get_stance", [])
	
	assert_eq(new_behavior, old_behavior, "AI behavior should be restored")
	assert_eq(new_stance, old_stance, "Combat stance should be restored")

# Equipment State Tests
func test_equipment_persistence() -> void:
	var enemy: Enemy = create_test_enemy()
	if not enemy:
		push_error("Failed to create enemy for equipment test")
		return
	track_test_node(enemy)
	
	var weapon: Object = Object.new()
	if not weapon:
		push_error("Failed to create test weapon")
		return
	track_test_resource(weapon)
	
	# Setup equipment
	_call_node_method_bool(enemy, "equip_weapon", [weapon])
	
	# Save equipment state
	var saved_state: Dictionary = _call_node_method_dict(enemy, "save", [])
	
	# Create new enemy and load state
	var new_enemy: Enemy = create_test_enemy()
	if not new_enemy:
		push_error("Failed to create new enemy for equipment test")
		return
	track_test_node(new_enemy)
	
	_call_node_method_bool(new_enemy, "load", [saved_state])
	
	# Verify equipment restoration
	var new_weapon: Node = _call_node_method_object(new_enemy, "get_weapon", [])
	assert_not_null(new_weapon, "Weapon should be restored")
	
	var old_type: int = _call_node_method_int(weapon, "get_type", [])
	var new_type: int = _call_node_method_int(new_weapon, "get_type", [])
	assert_eq(new_type, old_type, "Weapon type should be restored")

# Invalid State Tests
func test_invalid_state_handling() -> void:
	var enemy: Enemy = create_test_enemy()
	if not enemy:
		push_error("Failed to create enemy for invalid state test")
		return
	track_test_node(enemy)
	
	# Test loading invalid state
	var result: bool = _call_node_method_bool(enemy, "load", [ {}])
	assert_false(result, "Loading invalid state should fail")
	
	# Test loading corrupted state
	var corrupted_state := {"health": "invalid"}
	result = _call_node_method_bool(enemy, "load", [corrupted_state])
	assert_false(result, "Loading corrupted state should fail")
	
	# Verify enemy remains in valid state
	var health: float = _call_node_method_float(enemy, "get_health", [])
	var is_valid: bool = _call_node_method_bool(enemy, "is_valid", [])
	
	assert_true(health > 0, "Enemy should maintain valid health")
	assert_true(is_valid, "Enemy should remain in valid state")