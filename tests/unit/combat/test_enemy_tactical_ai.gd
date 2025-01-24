@tool
extends "res://tests/fixtures/base_test.gd"

const TestedClass = preload("res://src/core/battle/EnemyTacticalAI.gd")
const BattlefieldManager = preload("res://src/core/battle/BattlefieldManager.gd")
const Character = preload("res://src/core/character/Base/Character.gd")

var _instance: TestedClass
var _battlefield_manager: BattlefieldManager
var _mock_combat_manager: Node

func before_each() -> void:
	await super.before_each()
	
	# Create mock battlefield manager
	_battlefield_manager = BattlefieldManager.new()
	add_child(_battlefield_manager)
	track_test_node(_battlefield_manager)
	
	# Create mock combat manager
	_mock_combat_manager = Node.new()
	add_child(_mock_combat_manager)
	track_test_node(_mock_combat_manager)
	
	# Create instance with dependencies
	_instance = TestedClass.new()
	_instance.battlefield_manager = _battlefield_manager
	_instance.combat_manager = _mock_combat_manager
	add_child(_instance)
	track_test_node(_instance)

func after_each() -> void:
	await super.after_each()
	_instance = null
	_battlefield_manager = null
	_mock_combat_manager = null

# AI Personality Tests
func test_ai_personality_types() -> void:
	assert_has(TestedClass.AIPersonality, "AGGRESSIVE", "Should have aggressive personality")
	assert_has(TestedClass.AIPersonality, "CAUTIOUS", "Should have cautious personality")
	assert_has(TestedClass.AIPersonality, "TACTICAL", "Should have tactical personality")
	assert_has(TestedClass.AIPersonality, "PROTECTIVE", "Should have protective personality")
	assert_has(TestedClass.AIPersonality, "UNPREDICTABLE", "Should have unpredictable personality")

# Group Tactics Tests
func test_group_tactic_types() -> void:
	assert_has(TestedClass.GroupTactic, "COORDINATED_ATTACK", "Should have coordinated attack tactic")
	assert_has(TestedClass.GroupTactic, "DEFENSIVE_FORMATION", "Should have defensive formation tactic")
	assert_has(TestedClass.GroupTactic, "FLANKING_MANEUVER", "Should have flanking maneuver tactic")
	assert_has(TestedClass.GroupTactic, "SUPPRESSION_PATTERN", "Should have suppression pattern tactic")

# Decision Making Tests
func test_decision_making_signals() -> void:
	var signal_emitted = false
	var test_enemy = Character.new()
	var test_action = {"type": GameEnums.UnitAction.MOVE, "target": Vector2(1, 1)}
	
	_instance.decision_made.connect(func(enemy, action):
		signal_emitted = true
		assert_eq(enemy, test_enemy, "Should emit correct enemy")
		assert_eq(action, test_action, "Should emit correct action"))
	
	_instance.emit_signal("decision_made", test_enemy, test_action)
	assert_true(signal_emitted, "Should emit decision_made signal")

func test_tactic_change_signals() -> void:
	var signal_emitted = false
	var test_enemy = Character.new()
	var test_tactic = GameEnums.CombatTactic.AGGRESSIVE
	
	_instance.tactic_changed.connect(func(enemy, new_tactic):
		signal_emitted = true
		assert_eq(enemy, test_enemy, "Should emit correct enemy")
		assert_eq(new_tactic, test_tactic, "Should emit correct tactic"))
	
	_instance.emit_signal("tactic_changed", test_enemy, test_tactic)
	assert_true(signal_emitted, "Should emit tactic_changed signal")

func test_group_coordination_signals() -> void:
	var signal_emitted = false
	var test_group = [Character.new(), Character.new()]
	var test_leader = test_group[0]
	
	_instance.group_coordination_updated.connect(func(group, leader):
		signal_emitted = true
		assert_eq(group, test_group, "Should emit correct group")
		assert_eq(leader, test_leader, "Should emit correct leader"))
	
	_instance.emit_signal("group_coordination_updated", test_group, test_leader)
	assert_true(signal_emitted, "Should emit group_coordination_updated signal")

# State Tracking Tests
func test_enemy_personality_tracking() -> void:
	var test_enemy = Character.new()
	var personality = TestedClass.AIPersonality.AGGRESSIVE
	
	# Test setting personality
	_instance._enemy_personalities[test_enemy] = personality
	assert_eq(_instance._enemy_personalities[test_enemy], personality,
		"Should track enemy personality")

func test_group_assignment_tracking() -> void:
	var test_enemy = Character.new()
	var test_group = [test_enemy, Character.new()]
	
	# Test setting group assignment
	_instance._group_assignments[test_enemy] = test_group
	assert_eq(_instance._group_assignments[test_enemy], test_group,
		"Should track group assignments")

func test_tactical_state_tracking() -> void:
	var test_enemy = Character.new()
	var tactical_state = {
		"current_tactic": GameEnums.CombatTactic.AGGRESSIVE,
		"last_position": Vector2(1, 1),
		"target": null
	}
	
	# Test setting tactical state
	_instance._tactical_states[test_enemy] = tactical_state
	assert_eq(_instance._tactical_states[test_enemy], tactical_state,
		"Should track tactical states")