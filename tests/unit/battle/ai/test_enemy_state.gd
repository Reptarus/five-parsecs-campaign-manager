@tool
extends FiveParsecsEnemyTest

var _save_manager: Node
var _test_enemies: Array[Enemy]

func before_each() -> void:
	await super.before_each()
	
	# Setup save system test environment
	_save_manager = Node.new()
	_save_manager.name = "SaveManager"
	add_child_autofree(_save_manager)
	
	# Create test enemies
	_test_enemies = []
	for i in range(3):
		var enemy = create_test_enemy()
		_test_enemies.append(enemy)
	
	await stabilize_engine(STABILIZE_TIME)

func after_each() -> void:
	_save_manager = null
	_test_enemies.clear()
	await super.after_each()

# Basic State Tests
func test_basic_state() -> void:
	var enemy = create_test_enemy()
	var initial_state = _capture_enemy_state(enemy)
	
	assert_not_null(initial_state, "Enemy state should be captured")
	assert_eq(initial_state.health, enemy.get_health(), "Health should be captured")
	assert_eq(initial_state.position, enemy.position, "Position should be captured")

# State Persistence Tests
func test_state_persistence() -> void:
	var enemy = create_test_enemy()
	var initial_state = _capture_enemy_state(enemy)
	
	# Modify state
	enemy.take_damage(20)
	enemy.position = Vector2(100, 100)
	
	# Save state
	var saved_state = enemy.save()
	
	# Create new enemy and load state
	var new_enemy = create_test_enemy()
	new_enemy.load(saved_state)
	
	# Verify state restoration
	assert_eq(new_enemy.get_health(), enemy.get_health(), "Health should be restored")
	assert_eq(new_enemy.position, enemy.position, "Position should be restored")

# Group State Tests
func test_group_state_persistence() -> void:
	var group = _create_test_group()
	var group_states = _capture_group_states(group)
	
	# Modify group states
	for enemy in group:
		enemy.take_damage(10)
		enemy.position += Vector2(50, 50)
	
	# Save group states
	var saved_states = []
	for enemy in group:
		saved_states.append(enemy.save())
	
	# Create new group and restore states
	var new_group = _create_test_group()
	for i in range(new_group.size()):
		new_group[i].load(saved_states[i])
	
	# Verify group state restoration
	for i in range(group.size()):
		assert_eq(new_group[i].get_health(), group[i].get_health(),
			"Group member health should be restored")
		assert_eq(new_group[i].position, group[i].position,
			"Group member position should be restored")

# Combat State Tests
func test_combat_state_persistence() -> void:
	var enemy = create_test_enemy()
	
	# Setup combat state
	enemy.take_damage(20)
	enemy.apply_status_effect("poison", 3)
	enemy.set_target(create_test_enemy())
	
	# Save combat state
	var saved_state = enemy.save()
	
	# Create new enemy and load state
	var new_enemy = create_test_enemy()
	new_enemy.load(saved_state)
	
	# Verify combat state restoration
	assert_eq(new_enemy.get_health(), enemy.get_health(),
		"Combat health should be restored")
	assert_true(new_enemy.has_status_effect("poison"),
		"Status effects should be restored")
	assert_not_null(new_enemy.get_target(),
		"Target should be restored")

# AI State Tests
func test_ai_state_persistence() -> void:
	var enemy = create_test_enemy()
	
	# Setup AI state
	enemy.set_behavior(GameEnums.AIBehavior.AGGRESSIVE)
	enemy.set_combat_stance(GameEnums.CombatStance.OFFENSIVE)
	
	# Save AI state
	var saved_state = enemy.save()
	
	# Create new enemy and load state
	var new_enemy = create_test_enemy()
	new_enemy.load(saved_state)
	
	# Verify AI state restoration
	assert_eq(new_enemy.get_behavior(), enemy.get_behavior(),
		"AI behavior should be restored")
	assert_eq(new_enemy.get_combat_stance(), enemy.get_combat_stance(),
		"Combat stance should be restored")

# Equipment State Tests
func test_equipment_persistence() -> void:
	var enemy = create_test_enemy()
	var weapon = GameWeapon.new()
	
	# Setup equipment
	enemy.equip_weapon(weapon)
	
	# Save equipment state
	var saved_state = enemy.save()
	
	# Create new enemy and load state
	var new_enemy = create_test_enemy()
	new_enemy.load(saved_state)
	
	# Verify equipment restoration
	assert_not_null(new_enemy.get_weapon(),
		"Weapon should be restored")
	assert_eq(new_enemy.get_weapon().get_type(), weapon.get_type(),
		"Weapon type should be restored")

# Invalid State Tests
func test_invalid_state_handling() -> void:
	var enemy = create_test_enemy()
	
	# Test loading invalid state
	var result = enemy.load({})
	assert_false(result, "Loading invalid state should fail")
	
	# Test loading corrupted state
	var corrupted_state = {"health": "invalid"}
	result = enemy.load(corrupted_state)
	assert_false(result, "Loading corrupted state should fail")
	
	# Verify enemy remains in valid state
	assert_true(enemy.get_health() > 0, "Enemy should maintain valid health")
	assert_true(enemy.is_valid(), "Enemy should remain in valid state")

# Helper Methods
func _capture_enemy_state(enemy: Enemy) -> Dictionary:
	return {
		"position": enemy.position,
		"health": enemy.get_health(),
		"behavior": enemy.get_behavior(),
		"movement_range": enemy.get_movement_range(),
		"weapon_range": enemy.get_weapon_range(),
		"state": enemy.get_state()
	}

func _capture_group_states(group: Array[Enemy]) -> Array[Dictionary]:
	var states: Array[Dictionary] = []
	for enemy in group:
		states.append(_capture_enemy_state(enemy))
	return states

func _create_test_group(size: int = 3) -> Array[Enemy]:
	var group: Array[Enemy] = []
	for i in range(size):
		var enemy = create_test_enemy()
		group.append(enemy)
	return group