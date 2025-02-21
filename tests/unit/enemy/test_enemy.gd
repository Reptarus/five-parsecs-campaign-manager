@tool
extends FiveParsecsEnemyTest

func test_enemy_initialization() -> void:
	var enemy := create_test_enemy() as Enemy
	
	# Verify initial state
	verify_enemy_state(enemy, TEST_ENEMY_STATES["BASIC"])
	assert_true(enemy.can_move(), "Enemy should be able to move initially")
	assert_false(enemy.can_attack(), "Enemy should not be able to attack without a weapon")

func test_enemy_movement() -> void:
	var enemy := create_test_enemy() as Enemy
	var start_pos := Vector2(0, 0)
	var end_pos := Vector2(4, 4)
	
	enemy.position = start_pos
	verify_enemy_movement(enemy, start_pos, end_pos)
	
	# Verify movement points are consumed
	var state := enemy.get_state()
	assert_eq(enemy.get_movement_points(), state.movement_points,
		"Movement points should be updated")
	
	# Try to move beyond movement points
	for i in range(5):
		enemy.move_to(start_pos)
	
	assert_false(enemy.can_move(), "Enemy should not be able to move after depleting movement points")

func test_enemy_combat() -> void:
	var enemy := create_test_enemy("ELITE") as Enemy # Elite has better combat stats
	var target := Node2D.new()
	add_child_autofree(target)
	
	# Set up weapon
	var weapon := GameWeapon.new()
	enemy.enemy_data = create_test_enemy_data("ELITE")
	
	verify_enemy_combat(enemy, target)
	
	# Verify combat state
	var state := enemy.get_state()
	assert_false(state.can_attack, "Enemy should not be able to attack after attacking")

func test_enemy_health() -> void:
	var enemy := create_test_enemy("BOSS") as Enemy # Boss has more health
	var initial_health := enemy.get_health()
	
	# Test damage
	watch_signals(enemy)
	enemy.take_damage(50)
	
	assert_eq(enemy.get_health(), initial_health - 50, "Health should be reduced by damage")
	verify_signal_emitted(enemy, "health_changed")
	
	# Test healing
	watch_signals(enemy)
	enemy.heal(20)
	
	assert_eq(enemy.get_health(), initial_health - 30, "Health should be increased by healing")
	verify_signal_emitted(enemy, "health_changed")
	
	# Test death
	watch_signals(enemy)
	enemy.take_damage(1000)
	
	assert_eq(enemy.get_health(), 0, "Health should not go below 0")
	verify_signal_emitted(enemy, "died")

func test_enemy_turn_management() -> void:
	var enemy := create_test_enemy() as Enemy
	
	# Start turn
	watch_signals(enemy)
	enemy.start_turn()
	
	var state := enemy.get_state()
	assert_true(state.is_active, "Enemy should be active after turn start")
	assert_true(state.can_move, "Enemy should be able to move after turn start")
	verify_signal_emitted(enemy, "state_changed")
	
	# End turn
	watch_signals(enemy)
	enemy.end_turn()
	
	state = enemy.get_state()
	assert_false(state.is_active, "Enemy should not be active after turn end")
	assert_false(state.can_move, "Enemy should not be able to move after turn end")
	verify_signal_emitted(enemy, "state_changed")

func test_enemy_combat_rating() -> void:
	var enemy := create_test_enemy("ELITE") as Enemy
	var initial_rating := enemy.get_combat_rating()
	
	# Test rating with damage
	enemy.take_damage(75) # 50% health remaining
	var damaged_rating := enemy.get_combat_rating()
	
	assert_true(damaged_rating < initial_rating,
		"Combat rating should decrease with damage")
	
	# Test rating with healing
	enemy.heal(75) # Back to full health
	var healed_rating := enemy.get_combat_rating()
	
	assert_eq(healed_rating, initial_rating,
		"Combat rating should return to initial value after healing")