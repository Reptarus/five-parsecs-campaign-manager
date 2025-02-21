@tool
extends FiveParsecsEnemyTest

# Type-safe test constants
const TEST_ENEMY_DATA := {
	"BASIC": {
		"health": 100.0 as float,
		"movement_range": 4.0 as float,
		"weapon_range": 1.0 as float,
		"behavior": GameEnums.AIBehavior.CAUTIOUS as int
	},
	"ELITE": {
		"health": 150.0 as float,
		"movement_range": 6.0 as float,
		"weapon_range": 2.0 as float,
		"behavior": GameEnums.AIBehavior.AGGRESSIVE as int
	},
	"BOSS": {
		"health": 300.0 as float,
		"movement_range": 3.0 as float,
		"weapon_range": 3.0 as float,
		"behavior": GameEnums.AIBehavior.DEFENSIVE as int
	}
}

# Type-safe instance variables
var _test_enemy: Node = null
var _test_target: Node = null

# Lifecycle Methods
func before_each() -> void:
	await super.before_each()
	
	# Initialize test components
	_test_enemy = create_test_enemy()
	if not _test_enemy:
		push_error("Failed to create test enemy")
		return
	
	_test_target = Node2D.new()
	if not _test_target:
		push_error("Failed to create test target")
		return
	
	add_child_autofree(_test_target)
	track_test_node(_test_target)
	
	await stabilize_engine(STABILIZE_TIME)

func after_each() -> void:
	_test_enemy = null
	_test_target = null
	await super.after_each()

# Test Cases
func test_enemy_initialization() -> void:
	var enemy: Node = create_test_enemy()
	if not enemy:
		push_error("Failed to create test enemy")
		return
	
	# Verify initial state
	verify_enemy_state(enemy, TEST_ENEMY_STATES["BASIC"])
	assert_true(_call_node_method_bool(enemy, "can_move"),
		"Enemy should be able to move initially")
	assert_false(_call_node_method_bool(enemy, "can_attack"),
		"Enemy should not be able to attack without a weapon")

func test_enemy_movement() -> void:
	var enemy: Node = create_test_enemy()
	if not enemy:
		push_error("Failed to create test enemy")
		return
	
	var start_pos := Vector2(0, 0)
	var end_pos := Vector2(4, 4)
	
	_call_node_method(enemy, "set_position", [start_pos])
	verify_enemy_movement(enemy, start_pos, end_pos)
	
	# Verify movement points are consumed
	var movement_points: float = _call_node_method(enemy, "get_movement_points")
	assert_true(movement_points >= 0.0, "Movement points should not be negative")
	
	# Try to move beyond movement points
	for i in range(5):
		_call_node_method(enemy, "move_to", [start_pos])
	
	assert_false(_call_node_method_bool(enemy, "can_move"),
		"Enemy should not be able to move after depleting movement points")

func test_enemy_combat() -> void:
	var enemy: Node = create_test_enemy("ELITE")
	if not enemy:
		push_error("Failed to create elite enemy")
		return
	
	var target := Node2D.new()
	if not target:
		push_error("Failed to create target")
		return
	add_child_autofree(target)
	track_test_node(target)
	
	verify_enemy_combat(enemy, target)
	
	# Verify combat state
	var can_attack: bool = _call_node_method_bool(enemy, "can_attack")
	assert_false(can_attack, "Enemy should not be able to attack after attacking")

func test_enemy_health() -> void:
	var enemy: Node = create_test_enemy("BOSS")
	if not enemy:
		push_error("Failed to create boss enemy")
		return
	
	var initial_health: float = _call_node_method(enemy, "get_health")
	
	# Test damage
	watch_signals(enemy)
	_call_node_method(enemy, "take_damage", [50.0])
	
	var current_health: float = _call_node_method(enemy, "get_health")
	assert_eq(current_health, initial_health - 50.0, "Health should be reduced by damage")
	verify_signal_emitted(enemy, "health_changed")
	
	# Test healing
	watch_signals(enemy)
	_call_node_method(enemy, "heal", [20.0])
	
	current_health = _call_node_method(enemy, "get_health")
	assert_eq(current_health, initial_health - 30.0, "Health should be increased by healing")
	verify_signal_emitted(enemy, "health_changed")
	
	# Test death
	watch_signals(enemy)
	_call_node_method(enemy, "take_damage", [1000.0])
	
	current_health = _call_node_method(enemy, "get_health")
	assert_eq(current_health, 0.0, "Health should not go below 0")
	verify_signal_emitted(enemy, "died")

func test_enemy_turn_management() -> void:
	var enemy: Node = create_test_enemy()
	if not enemy:
		push_error("Failed to create test enemy")
		return
	
	# Start turn
	watch_signals(enemy)
	_call_node_method(enemy, "start_turn")
	
	assert_true(_call_node_method_bool(enemy, "is_active"),
		"Enemy should be active after turn start")
	assert_true(_call_node_method_bool(enemy, "can_move"),
		"Enemy should be able to move after turn start")
	verify_signal_emitted(enemy, "turn_started")
	
	# End turn
	watch_signals(enemy)
	_call_node_method(enemy, "end_turn")
	
	assert_false(_call_node_method_bool(enemy, "is_active"),
		"Enemy should not be active after turn end")
	assert_false(_call_node_method_bool(enemy, "can_move"),
		"Enemy should not be able to move after turn end")
	verify_signal_emitted(enemy, "turn_ended")

func test_enemy_combat_rating() -> void:
	var enemy: Node = create_test_enemy("ELITE")
	if not enemy:
		push_error("Failed to create elite enemy")
		return
	
	var initial_rating: float = _call_node_method(enemy, "get_combat_rating")
	
	# Test rating with damage
	_call_node_method(enemy, "take_damage", [75.0]) # 50% health remaining
	var damaged_rating: float = _call_node_method(enemy, "get_combat_rating")
	
	assert_true(damaged_rating < initial_rating,
		"Combat rating should decrease with damage")
	
	# Test rating with healing
	_call_node_method(enemy, "heal", [75.0]) # Back to full health
	var healed_rating: float = _call_node_method(enemy, "get_combat_rating")
	
	assert_eq(healed_rating, initial_rating,
		"Combat rating should return to initial value after healing")

# Mobile-specific test cases
func test_enemy_mobile_performance() -> void:
	var enemy: Node = create_test_enemy("ELITE")
	if not enemy:
		push_error("Failed to create elite enemy")
		return
	
	var results := await measure_mobile_performance(func():
		_call_node_method(enemy, "start_turn")
		_call_node_method(enemy, "move_to", [Vector2(100, 100)])
		_call_node_method(enemy, "end_turn")
	)
	
	assert_true(results.average_fps >= 30.0, "Should maintain good FPS during enemy actions")
	assert_true(results.memory_delta_kb < 1024, "Should not leak memory during enemy actions")
