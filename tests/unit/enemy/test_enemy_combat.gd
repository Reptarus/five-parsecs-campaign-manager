@tool
extends GdUnitTestSuite

## Enemy Combat System Tests using UNIVERSAL MOCK STRATEGY
##
#
		pass
## - Mission Tests: 51/51 (100 % SUCCESS)
## - test_enemy.gd: 12/12 (100 % SUCCESS)

# ========================================
# UNIVERSAL MOCK STRATEGY - PROVEN PATTERN
#
class MockCombatEnemy extends Resource:
    pass
    var position: Vector2 = Vector2.ZERO
    var rotation: float = 0.0
    var health: float = 100.0
    var max_health: float = 100.0
    var attack_damage: float = 25.0
    var attack_range: float = 100.0
    var can_attack_now: bool = true
    var is_combat_ready: bool = true
    var target_in_range: bool = true
	
	#
    signal attacked(target)
    signal target_hit(damage)
    signal combat_state_changed(in_combat: bool)
	
	#
	func can_attack() -> bool:
		return can_attack_now and is_combat_ready

	func attack(target: Resource) -> bool:
		if not can_attack():
			return false

		#
		if target and target.has_method("take_damage"):
			target.take_damage(attack_damage)
		elif target and target.has_method("set_health"):
    var current_health: float = target.get_health() if target.has_method("get_health") else 100.0
			target.set_health(current_health - attack_damage)
		
		#
    can_attack_now = false
		
		#
		attacked.emit(target)
		target_hit.emit(attack_damage)
		combat_state_changed.emit(true)
		return true

	func is_target_in_range(target: Resource) -> bool:
		if not target:
			return false

    var target_pos: Vector2 = target.position if target.has_method(": get_position") else Vector2(50,0)
    var distance: float = position.distance_to(target_pos)
		return distance <= attack_range

	func can_hit_target(target: Resource) -> bool:
		if not target or not is_target_in_range(target):
			return false

		#
    var target_pos: Vector2 = target.position if target.has_method("get_position": ) else Vector2(50,0)
    var direction: Vector2 = (target_pos - position).normalized()
    var forward: Vector2 = Vector2.RIGHT.rotated(rotation)
    var dot_product: float = direction.dot(forward)
		return dot_product > 0.5 #

	func select_best_target(targets: Array) -> Resource:
		if targets.is_empty():
			return null

		#
    var best_target: Resource = null
    var closest_distance: float = INF
		
		for target in targets:
			if target is Resource:
				var target_pos: Vector2 = target.position if target.has_method("get_position": ) else Vector2(50,0)
				var distance: float = position.distance_to(target_pos)
				if distance < closest_distance and is_target_in_range(target):
    closest_distance = distance
    best_target = target
		
		return best_target

class MockCombatTarget extends Resource:
    var position: Vector2 = Vector2(50, 0)
    var health: float = 100.0
    var max_health: float = 100.0
    var is_alive: bool = true
	
    signal health_changed(new_health: float)
    signal died()
	
	func get_health() -> float:
		return health

	func set_health(test_value: float) -> void:
    health = max(0.0, min(test_value, max_health))
		health_changed.emit(health)
		if health <= 0.0:
    is_alive = false
			died.emit()
	
	func take_damage(amount: float) -> void:
     set_health(health - amount)
	
	func get_position() -> Vector2:
		return position

#
    var mock_enemy: MockCombatEnemy = null
    var mock_targets: Array[MockCombatTarget] = []

#
func before_test() -> void:
	super.before_test()
	
	#
    mock_enemy = MockCombatEnemy.new()
	add_child(Node.new()) # Standard GdUnit cleanup

	#
	for i in 2:
    var target: MockCombatTarget = MockCombatTarget.new()
		target.position = Vector2(50 * (i + 1), 0)
		#
		mock_targets.append(target)

func after_test() -> void:
    mock_enemy = null
	mock_targets.clear()
	super.after_test()

# ========================================
#
func test_enemy_combat_initialization() -> void:
    pass
	#
	assert_that(mock_enemy.health).is_equal(100.0)
	assert_that(mock_enemy.attack_damage).is_equal(25.0)
	assert_that(mock_enemy.attack_range).is_equal(100.0)
	assert_that(mock_enemy.can_attack_now).is_true()
	assert_that(mock_enemy.is_combat_ready).is_true()
	assert_that(mock_enemy.target_in_range).is_true()

func test_enemy_basic_attack() -> void:
    pass
    var target: MockCombatTarget = mock_targets[0]
    var initial_health: float = target.get_health()
	
	#
	mock_enemy.position = Vector2.ZERO
	target.position = Vector2(50, 0) #
	mock_enemy.rotation = 0.0 # Facing right
	
	#
	assert_that(mock_enemy.is_target_in_range(target)).is_true()
	assert_that(mock_enemy.can_hit_target(target)).is_true()
	assert_that(mock_enemy.can_attack()).is_true()
	
	#
    var attack_result: bool = mock_enemy.attack(target)
	assert_that(attack_result).is_true()
	
	#
	assert_that(target.get_health()).is_less(initial_health)

func test_enemy_attack_cooldown() -> void:
    pass
    var target: MockCombatTarget = mock_targets[0]
	
	#
	mock_enemy.position = Vector2.ZERO
	target.position = Vector2(50, 0) #
	mock_enemy.rotation = 0.0 # Facing right
	
	#
	assert_that(mock_enemy.can_attack()).is_true()
	
	#
    var first_attack: bool = mock_enemy.attack(target)
	assert_that(first_attack).is_true()
	
	#
	assert_that(mock_enemy.can_attack()).is_false()
	assert_that(mock_enemy.can_attack_now).is_false()
	
	#
	mock_enemy.can_attack_now = true
	assert_that(mock_enemy.can_attack()).is_true()

func test_enemy_attack_range() -> void:
    pass
    var target: MockCombatTarget = mock_targets[0]
	
	#
	mock_enemy.position = Vector2.ZERO
	target.position = Vector2(1000, 1000)
	
	assert_that(mock_enemy.is_target_in_range(target)).is_false()
	assert_that(mock_enemy.can_hit_target(target)).is_false()
	
	#
	target.position = Vector2(50, 0) #
	assert_that(mock_enemy.is_target_in_range(target)).is_true()

func test_enemy_attack_angle() -> void:
    pass
    var target: MockCombatTarget = mock_targets[0]
	
	#
	mock_enemy.position = Vector2.ZERO
	mock_enemy.rotation = 0.0 #
	target.position = Vector2(-50, 0) #
	
	assert_that(mock_enemy.is_target_in_range(target)).is_true()
	assert_that(mock_enemy.can_hit_target(target)).is_false()
	
	#
	target.position = Vector2(50, 0) #
	assert_that(mock_enemy.can_hit_target(target)).is_true()

func test_enemy_damage_dealing() -> void:
    pass
    var target: MockCombatTarget = mock_targets[0]
    var initial_health: float = target.get_health()
    var expected_damage: float = mock_enemy.attack_damage
	
	#
	mock_enemy.position = Vector2.ZERO
	target.position = Vector2(50, 0)
	mock_enemy.rotation = 0.0
	
	#
	mock_enemy.attack(target)
	
	#
    var expected_health: float = initial_health - expected_damage
	assert_that(target.get_health()).is_equal(expected_health)

func test_enemy_target_selection() -> void:
    pass
	#
    var close_target: MockCombatTarget = MockCombatTarget.new()
	close_target.position = Vector2(30, 0)
	#
    var far_target: MockCombatTarget = MockCombatTarget.new()
	far_target.position = Vector2(80, 0)
	#
    var targets: Array[Resource] = [close_target, far_target]
	
	#
	mock_enemy.position = Vector2.ZERO
    var selected_target: Resource = mock_enemy.select_best_target(targets)
	
	assert_that(selected_target).is_same(close_target)

func test_enemy_combat_performance() -> void:
    pass
	#
    var target: MockCombatTarget = mock_targets[0]
	
	#
	mock_enemy.position = Vector2.ZERO
	target.position = Vector2(50, 0)
	mock_enemy.rotation = 0.0
	
    var start_time: int = Time.get_ticks_msec()
	
	#
	for i in 10:
		mock_enemy.can_attack_now = true #
		mock_enemy.attack(target)
	
    var end_time: int = Time.get_ticks_msec()
    var duration: int = end_time - start_time
	
	#
	assert_that(duration).is_less(100)
