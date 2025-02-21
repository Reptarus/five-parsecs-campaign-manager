@tool
extends GameTest

const STABILIZE_TIME: float = 0.1

# Type-safe component references
var _combat_manager: Node
var _combat_arena: Node2D
var _player_character: Node
var _battlefield_manager: Node

func before_each() -> void:
	await super.before_each()
	
	# Setup combat test environment with type safety
	_combat_manager = Node.new()
	_combat_manager.name = "CombatManager"
	add_child_autofree(_combat_manager)
	track_test_node(_combat_manager)
	
	_combat_arena = Node2D.new()
	_combat_arena.name = "CombatArena"
	add_child_autofree(_combat_arena)
	track_test_node(_combat_arena)
	
	_player_character = Node2D.new()
	_player_character.name = "PlayerCharacter"
	add_child_autofree(_player_character)
	track_test_node(_player_character)
	
	_battlefield_manager = Node.new()
	_battlefield_manager.name = "BattlefieldManager"
	add_child_autofree(_battlefield_manager)
	track_test_node(_battlefield_manager)
	
	await stabilize_engine(STABILIZE_TIME)

func after_each() -> void:
	_combat_manager = null
	_combat_arena = null
	_player_character = null
	_battlefield_manager = null
	await super.after_each()

# Type-safe enemy creation
func create_test_enemy(type: String = "NORMAL") -> Node:
	var enemy: Node = Node2D.new()
	enemy.set_script(EnemyScript)
	if not enemy.get_script() == EnemyScript:
		push_error("Failed to set Enemy script")
		return null
	
	_call_node_method(enemy, "initialize", [type])
	add_child_autofree(enemy)
	track_test_node(enemy)
	return enemy

# Basic Combat Tests
func test_combat_initialization() -> void:
	var enemy: Node = create_test_enemy()
	assert_not_null(enemy, "Enemy should be created")
	assert_true(_call_node_method_bool(enemy, "has_method", ["can_attack"]), "Enemy should have combat capabilities")
	assert_true(_call_node_method_bool(enemy, "has_method", ["get_health"]), "Enemy should have health system")

func test_combat_turn_sequence() -> void:
	var enemy: Node = create_test_enemy()
	watch_signals(enemy)
	
	# Start turn with type safety
	_call_node_method(enemy, "start_turn")
	assert_true(_call_node_method_bool(enemy, "can_act"), "Enemy should be able to act on turn start")
	verify_signal_emitted(enemy, "turn_started")
	
	# End turn with type safety
	_call_node_method(enemy, "end_turn")
	assert_false(_call_node_method_bool(enemy, "can_act"), "Enemy should not be able to act after turn end")
	verify_signal_emitted(enemy, "turn_ended")

# Combat Action Tests
func test_attack_resolution() -> void:
	var enemy: Node = create_test_enemy("ELITE")
	var target: Node = _player_character
	watch_signals(enemy)
	
	_call_node_method(enemy, "attack", [target])
	verify_signal_emitted(enemy, "attack_executed")
	assert_false(_call_node_method_bool(enemy, "can_attack"), "Enemy should not be able to attack again immediately")

func test_damage_application() -> void:
	var enemy: Node = create_test_enemy()
	var initial_health: int = _call_node_method_int(enemy, "get_health")
	
	_call_node_method(enemy, "take_damage", [20])
	assert_eq(_call_node_method_int(enemy, "get_health"), initial_health - 20, "Damage should be properly applied")
	
	_call_node_method(enemy, "heal", [10])
	assert_eq(_call_node_method_int(enemy, "get_health"), initial_health - 10, "Healing should be properly applied")

# Combat Status Tests
func test_combat_status_effects() -> void:
	var enemy: Node = create_test_enemy()
	
	# Test stun effect with type safety
	_call_node_method(enemy, "apply_status_effect", ["stun", 2])
	assert_false(_call_node_method_bool(enemy, "can_act"), "Stunned enemy should not be able to act")
	
	# Test poison effect with type safety
	_call_node_method(enemy, "apply_status_effect", ["poison", 3])
	var initial_health: int = _call_node_method_int(enemy, "get_health")
	_call_node_method(enemy, "process_status_effects")
	assert_true(_call_node_method_int(enemy, "get_health") < initial_health, "Poison should deal damage over time")

# Combat Movement Tests
func test_combat_movement() -> void:
	var enemy: Node = create_test_enemy()
	var start_pos := Vector2(0, 0)
	var end_pos := Vector2(100, 100)
	
	_set_property_safe(enemy, "position", start_pos)
	watch_signals(enemy)
	
	_call_node_method(enemy, "move_to", [end_pos])
	verify_signal_emitted(enemy, "movement_completed")
	assert_eq(_get_property_safe(enemy, "position"), end_pos, "Enemy should move to target position")

func test_combat_reactions() -> void:
	var enemy: Node = create_test_enemy()
	var trigger: Node = create_test_enemy()
	
	watch_signals(enemy)
	_call_node_method(enemy, "setup_reaction", ["attack", trigger])
	
	_call_node_method(trigger, "move_to", [Vector2(50, 50)])
	verify_signal_emitted(enemy, "reaction_triggered")

# Combat AI Tests
func test_combat_ai_decisions() -> void:
	var enemy: Node = create_test_enemy()
	var ai_manager: Node = _call_node_method(_combat_manager, "get_ai_manager")
	
	watch_signals(ai_manager)
	var decision: Dictionary = _call_node_method_dict(ai_manager, "make_combat_decision", [enemy])
	
	assert_not_null(decision, "AI should make a combat decision")
	verify_signal_emitted(ai_manager, "decision_made")

# Group Combat Tests
func test_group_combat_coordination() -> void:
	var leader: Node = create_test_enemy("ELITE")
	var followers: Array[Node] = _create_follower_group(2)
	var group: Array[Node] = [leader] + followers
	
	watch_signals(leader)
	_call_node_method(_combat_manager, "coordinate_group_attack", [group, _player_character])
	
	verify_signal_emitted(leader, "group_attack_coordinated")
	for follower in followers:
		assert_true(_call_node_method_bool(follower, "has_target"), "Followers should have assigned targets")

# Cleanup and State Tests
func test_combat_cleanup() -> void:
	var enemy: Node = create_test_enemy()
	_call_node_method(enemy, "apply_status_effect", ["poison", 2])
	_call_node_method(enemy, "setup_reaction", ["attack", _player_character])
	
	watch_signals(enemy)
	_call_node_method(enemy, "cleanup_combat_state")
	
	assert_false(_call_node_method_bool(enemy, "has_status_effects"), "Status effects should be cleared")
	assert_false(_call_node_method_bool(enemy, "has_reactions"), "Reactions should be cleared")
	verify_signal_emitted(enemy, "combat_cleanup_completed")

# Helper Methods
func _create_follower_group(size: int) -> Array[Node]:
	var followers: Array[Node] = []
	for i in range(size):
		var follower: Node = create_test_enemy()
		followers.append(follower)
	return followers

func _setup_combat_scenario() -> Dictionary:
	var enemy: Node = create_test_enemy()
	var target: Node = _player_character
	return {
		"enemy": enemy,
		"target": target,
		"arena": _combat_arena
	}

func _simulate_combat_round(enemy: Node, target: Node) -> void:
	_call_node_method(enemy, "start_turn")
	if _call_node_method_bool(enemy, "can_attack") and _call_node_method_bool(enemy, "is_in_range", [target]):
		_call_node_method(enemy, "attack", [target])
	elif _call_node_method_bool(enemy, "can_move"):
		_call_node_method(enemy, "move_to", [_get_property_safe(target, "position")])
	_call_node_method(enemy, "end_turn")