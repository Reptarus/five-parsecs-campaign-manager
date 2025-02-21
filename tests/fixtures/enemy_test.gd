@tool
extends GameTest
class_name FiveParsecsEnemyTest

# Core script references with type safety
const EnemyScript: GDScript = preload("res://src/core/battle/enemy/Enemy.gd")

# Constants for enemy testing
const STABILIZE_TIME := 0.1
const TEST_ENEMY_STATES := {
	"BASIC": {
		"health": 100,
		"movement_points": 6,
		"action_points": 2
	},
	"ELITE": {
		"health": 150,
		"movement_points": 8,
		"action_points": 3
	}
}

# Helper methods for enemy testing
func create_test_enemy(type: String = "BASIC") -> Node:
	var enemy: Node = EnemyScript.new()
	var state: Dictionary = TEST_ENEMY_STATES.get(type, TEST_ENEMY_STATES["BASIC"])
	
	for property in state:
		_set_property_safe(enemy, property, state[property])
	
	add_child_autofree(enemy)
	return enemy

func create_test_enemy_data(type: String = "BASIC") -> Resource:
	var data := Resource.new()
	var state: Dictionary = TEST_ENEMY_STATES.get(type, TEST_ENEMY_STATES["BASIC"])
	
	for property in state:
		_set_property_safe(data, property, state[property])
	
	track_test_resource(data)
	return data

func verify_enemy_state(enemy: Node, expected_state: Dictionary) -> void:
	for property in expected_state:
		var actual_value = _get_property_safe(enemy, property)
		var expected_value = expected_state[property]
		assert_eq(actual_value, expected_value,
			"Enemy %s should be %s but was %s" % [property, expected_value, actual_value])

func verify_enemy_movement(enemy: Node, start_pos: Vector2, end_pos: Vector2) -> void:
	assert_eq(enemy.position, start_pos, "Enemy should start at correct position")
	
	# Watch for movement signals
	watch_signals(enemy)
	
	# Move enemy
	_call_node_method(enemy, "move_to", [end_pos])
	
	# Verify movement
	assert_eq(enemy.position, end_pos, "Enemy should move to target position")
	verify_signal_emitted(enemy, "movement_completed")

func verify_enemy_combat(enemy: Node, target: Node) -> void:
	assert_not_null(enemy, "Enemy should exist")
	assert_not_null(target, "Target should exist")
	
	# Watch for combat signals
	watch_signals(enemy)
	
	# Execute attack
	_call_node_method(enemy, "attack", [target])
	
	# Verify combat
	verify_signal_emitted(enemy, "attack_executed")
	assert_false(_call_node_method_bool(enemy, "can_attack"), "Enemy should not be able to attack again immediately")
