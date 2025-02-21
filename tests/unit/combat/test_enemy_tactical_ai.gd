@tool
extends GameTest

## Test class for EnemyTacticalAI functionality
##
## Tests the AI decision making, group tactics, and state tracking for enemy units
## including personality types, group coordination, and tactical state management.

const TestedClass = preload("res://src/core/battle/EnemyTacticalAI.gd")
const BattlefieldManager = preload("res://src/core/battle/BattlefieldManager.gd")
const FiveParsecsCharacter = preload("res://src/core/character/Base/Character.gd")

var _instance: TestedClass
var _battlefield_manager: BattlefieldManager
var _mock_combat_manager: Node

# Signal tracking
var decision_made_signal_emitted := false
var tactic_changed_signal_emitted := false
var group_coordination_signal_emitted := false
var last_decision_enemy: Node = null
var last_decision_action: Dictionary = {}
var last_tactic_enemy: Node = null
var last_tactic_change: int = -1
var last_coordinated_group: Array = []
var last_group_leader: Node = null

func before_each() -> void:
	await super.before_each()
	
	# Create mock battlefield manager
	_battlefield_manager = BattlefieldManager.new()
	add_child_autofree(_battlefield_manager)
	track_test_node(_battlefield_manager)
	
	# Create mock combat manager
	_mock_combat_manager = Node.new()
	add_child_autofree(_mock_combat_manager)
	track_test_node(_mock_combat_manager)
	
	# Create instance with dependencies
	_instance = TestedClass.new()
	if _instance:
		_instance.set("battlefield_manager", _battlefield_manager)
		_instance.set("combat_manager", _mock_combat_manager)
	add_child_autofree(_instance)
	track_test_node(_instance)
	
	_connect_signals()
	_reset_signals()

func after_each() -> void:
	_disconnect_signals()
	_reset_signals()
	_instance = null
	_battlefield_manager = null
	_mock_combat_manager = null
	await super.after_each()

## Signal Methods
func _connect_signals() -> void:
	if not _instance:
		return
		
	if _instance.has_signal("decision_made"):
		_instance.connect("decision_made", _on_decision_made)
	if _instance.has_signal("tactic_changed"):
		_instance.connect("tactic_changed", _on_tactic_changed)
	if _instance.has_signal("group_coordination_updated"):
		_instance.connect("group_coordination_updated", _on_group_coordination_updated)

func _disconnect_signals() -> void:
	if not _instance:
		return
		
	if _instance.has_signal("decision_made") and _instance.is_connected("decision_made", _on_decision_made):
		_instance.disconnect("decision_made", _on_decision_made)
	if _instance.has_signal("tactic_changed") and _instance.is_connected("tactic_changed", _on_tactic_changed):
		_instance.disconnect("tactic_changed", _on_tactic_changed)
	if _instance.has_signal("group_coordination_updated") and _instance.is_connected("group_coordination_updated", _on_group_coordination_updated):
		_instance.disconnect("group_coordination_updated", _on_group_coordination_updated)

func _reset_signals() -> void:
	decision_made_signal_emitted = false
	tactic_changed_signal_emitted = false
	group_coordination_signal_emitted = false
	last_decision_enemy = null
	last_decision_action = {}
	last_tactic_enemy = null
	last_tactic_change = -1
	last_coordinated_group = []
	last_group_leader = null

func _on_decision_made(enemy: Node, action: Dictionary) -> void:
	decision_made_signal_emitted = true
	last_decision_enemy = enemy
	last_decision_action = action

func _on_tactic_changed(enemy: Node, new_tactic: int) -> void:
	tactic_changed_signal_emitted = true
	last_tactic_enemy = enemy
	last_tactic_change = new_tactic

func _on_group_coordination_updated(group: Array, leader: Node) -> void:
	group_coordination_signal_emitted = true
	last_coordinated_group = group
	last_group_leader = leader

## Safe Property Access Methods
func _get_instance_property(property: String, default_value = null) -> Variant:
	if not _instance:
		push_error("Trying to access property '%s' on null instance" % property)
		return default_value
	if not property in _instance:
		push_error("Instance missing required property: %s" % property)
		return default_value
	return _instance.get(property)

func _set_instance_property(property: String, value: Variant) -> void:
	if not _instance:
		push_error("Trying to set property '%s' on null instance" % property)
		return
	if not property in _instance:
		push_error("Instance missing required property: %s" % property)
		return
	_instance.set(property, value)

func _get_enemy_personality(enemy: Node) -> int:
	var personalities = _get_instance_property("_enemy_personalities", {})
	if not enemy in personalities:
		push_error("No personality found for enemy")
		return -1
	return personalities[enemy]

func _get_enemy_group(enemy: Node) -> Array:
	var assignments = _get_instance_property("_group_assignments", {})
	if not enemy in assignments:
		push_error("No group assignment found for enemy")
		return []
	return assignments[enemy]

func _get_enemy_tactical_state(enemy: Node) -> Dictionary:
	var states = _get_instance_property("_tactical_states", {})
	if not enemy in states:
		push_error("No tactical state found for enemy")
		return {}
	return states[enemy]

# Helper Methods
func _create_test_enemy(personality: int = TestedClass.AIPersonality.AGGRESSIVE) -> Node:
	var enemy = FiveParsecsCharacter.new()
	add_child_autofree(enemy)
	track_test_node(enemy)
	
	if "initialize" in enemy:
		enemy.initialize()
	
	var personalities = _get_instance_property("_enemy_personalities", {})
	personalities[enemy] = personality
	return enemy

func _create_test_group(size: int = 2) -> Array[Node]:
	var group: Array[Node] = []
	for i in range(size):
		group.append(_create_test_enemy())
	return group

# AI Personality Tests
func test_ai_personality_types() -> void:
	if not "AIPersonality" in TestedClass:
		push_error("TestedClass missing AIPersonality enum")
		return
		
	assert_has(TestedClass.AIPersonality, "AGGRESSIVE", "Should have aggressive personality")
	assert_has(TestedClass.AIPersonality, "CAUTIOUS", "Should have cautious personality")
	assert_has(TestedClass.AIPersonality, "TACTICAL", "Should have tactical personality")
	assert_has(TestedClass.AIPersonality, "PROTECTIVE", "Should have protective personality")
	assert_has(TestedClass.AIPersonality, "UNPREDICTABLE", "Should have unpredictable personality")

# Group Tactics Tests
func test_group_tactic_types() -> void:
	if not "GroupTactic" in TestedClass:
		push_error("TestedClass missing GroupTactic enum")
		return
		
	assert_has(TestedClass.GroupTactic, "COORDINATED_ATTACK", "Should have coordinated attack tactic")
	assert_has(TestedClass.GroupTactic, "DEFENSIVE_FORMATION", "Should have defensive formation tactic")
	assert_has(TestedClass.GroupTactic, "FLANKING_MANEUVER", "Should have flanking maneuver tactic")
	assert_has(TestedClass.GroupTactic, "SUPPRESSION_PATTERN", "Should have suppression pattern tactic")

# Decision Making Tests
func test_decision_making_signals() -> void:
	var test_enemy = _create_test_enemy()
	var test_action = {"type": GameEnums.UnitAction.MOVE, "target": Vector2(1, 1)}
	
	_reset_signals()
	if "decision_made" in _instance:
		_instance.emit_signal("decision_made", test_enemy, test_action)
	
	assert_true(decision_made_signal_emitted, "Should emit decision_made signal")
	assert_eq(last_decision_enemy, test_enemy, "Should emit correct enemy")
	assert_eq(last_decision_action, test_action, "Should emit correct action")

func test_tactic_change_signals() -> void:
	var test_enemy = _create_test_enemy()
	var test_tactic = GameEnums.CombatTactic.AGGRESSIVE
	
	_reset_signals()
	if "tactic_changed" in _instance:
		_instance.emit_signal("tactic_changed", test_enemy, test_tactic)
	
	assert_true(tactic_changed_signal_emitted, "Should emit tactic_changed signal")
	assert_eq(last_tactic_enemy, test_enemy, "Should emit correct enemy")
	assert_eq(last_tactic_change, test_tactic, "Should emit correct tactic")

func test_group_coordination_signals() -> void:
	var test_group = _create_test_group()
	var test_leader = test_group[0]
	
	_reset_signals()
	if "group_coordination_updated" in _instance:
		_instance.emit_signal("group_coordination_updated", test_group, test_leader)
	
	assert_true(group_coordination_signal_emitted, "Should emit group_coordination_updated signal")
	assert_eq(last_coordinated_group, test_group, "Should emit correct group")
	assert_eq(last_group_leader, test_leader, "Should emit correct leader")

# State Tracking Tests
func test_enemy_personality_tracking() -> void:
	var test_enemy = _create_test_enemy()
	var personality = TestedClass.AIPersonality.AGGRESSIVE
	
	# Test setting personality
	var personalities = _get_instance_property("_enemy_personalities", {})
	personalities[test_enemy] = personality
	
	assert_eq(_get_enemy_personality(test_enemy), personality, "Should track enemy personality")

func test_group_assignment_tracking() -> void:
	var test_enemy = _create_test_enemy()
	var test_group = _create_test_group()
	
	# Test setting group assignment
	var assignments = _get_instance_property("_group_assignments", {})
	assignments[test_enemy] = test_group
	
	assert_eq(_get_enemy_group(test_enemy), test_group, "Should track group assignments")

func test_tactical_state_tracking() -> void:
	var test_enemy = _create_test_enemy()
	var tactical_state = {
		"current_tactic": GameEnums.CombatTactic.AGGRESSIVE,
		"last_position": Vector2(1, 1),
		"target": null
	}
	
	# Test setting tactical state
	var states = _get_instance_property("_tactical_states", {})
	states[test_enemy] = tactical_state
	
	assert_eq(_get_enemy_tactical_state(test_enemy), tactical_state, "Should track tactical states")

# AI Decision Making Tests
func test_ai_decision_making() -> void:
	var test_enemy = _create_test_enemy()
	_reset_signals()
	
	if "make_decision" in _instance:
		_instance.make_decision(test_enemy)
	
	assert_true(decision_made_signal_emitted, "Should emit decision after making decision")
	assert_eq(last_decision_enemy, test_enemy, "Decision should be for correct enemy")
	assert_not_null(last_decision_action, "Should have valid decision action")

# Group Coordination Tests
func test_group_coordination() -> void:
	var test_group = _create_test_group(3)
	_reset_signals()
	
	if "coordinate_group" in _instance:
		_instance.coordinate_group(test_group)
	
	assert_true(group_coordination_signal_emitted, "Should emit coordination signal")
	assert_eq(last_coordinated_group.size(), test_group.size(), "Should coordinate entire group")
	assert_not_null(last_group_leader, "Should assign group leader")

# Tactical State Management Tests
func test_tactical_state_updates() -> void:
	var test_enemy = _create_test_enemy()
	var initial_state = _get_enemy_tactical_state(test_enemy)
	
	if "update_tactical_state" in _instance:
		_instance.update_tactical_state(test_enemy, Vector2(2, 2))
	
	var updated_state = _get_enemy_tactical_state(test_enemy)
	assert_ne(updated_state, initial_state, "Tactical state should be updated")
	assert_eq(updated_state.get("last_position"), Vector2(2, 2), "Should update position in state")