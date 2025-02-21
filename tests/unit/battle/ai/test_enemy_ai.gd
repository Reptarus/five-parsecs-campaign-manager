@tool
extends FiveParsecsEnemyTest

var _ai_manager: Node
var _tactical_ai: Node
var _battlefield_manager: Node
var _combat_manager: Node

func before_each() -> void:
	await super.before_each()
	
	# Setup AI test environment
	_battlefield_manager = Node.new()
	_battlefield_manager.name = "BattlefieldManager"
	add_child_autofree(_battlefield_manager)
	
	_combat_manager = Node.new()
	_combat_manager.name = "CombatManager"
	add_child_autofree(_combat_manager)
	
	# Create AI managers
	_ai_manager = _safe_cast_to_node(EnemyAIManager.new(), "EnemyAIManager")
	add_child_autofree(_ai_manager)
	
	_tactical_ai = _safe_cast_to_node(EnemyTacticalAI.new(), "EnemyTacticalAI")
	_tactical_ai.battlefield_manager = _battlefield_manager
	_tactical_ai.combat_manager = _combat_manager
	add_child_autofree(_tactical_ai)
	
	await stabilize_engine(STABILIZE_TIME)

func after_each() -> void:
	_ai_manager = null
	_tactical_ai = null
	_battlefield_manager = null
	_combat_manager = null
	await super.after_each()

# Basic AI Tests
func test_ai_initialization() -> void:
	assert_not_null(_ai_manager, "AI manager should be initialized")
	assert_not_null(_tactical_ai, "Tactical AI should be initialized")
	assert_eq(_ai_manager.active_enemies.size(), 0, "No enemies should be registered initially")

# AI Manager Tests
func test_enemy_registration() -> void:
	var enemy = create_test_enemy()
	
	# Register enemy
	_ai_manager.register_enemy(enemy)
	assert_has(_ai_manager.active_enemies, enemy, "Enemy should be registered")
	
	# Unregister enemy
	_ai_manager.unregister_enemy(enemy)
	assert_does_not_have(_ai_manager.active_enemies, enemy, "Enemy should be unregistered")

func test_behavior_override() -> void:
	var enemy = create_test_enemy()
	var test_behavior = GameEnums.AIBehavior.AGGRESSIVE
	
	# Set behavior override
	watch_signals(_ai_manager)
	_ai_manager.set_behavior_override(enemy, test_behavior)
	
	assert_eq(_ai_manager.get_current_behavior(enemy), test_behavior, "Enemy should have overridden behavior")
	verify_signal_emitted(_ai_manager, "behavior_changed")
	
	# Clear behavior override
	_ai_manager.clear_behavior_override(enemy)
	assert_eq(_ai_manager.get_current_behavior(enemy), enemy.behavior, "Enemy should return to default behavior")

# Tactical AI Tests
func test_tactical_ai_initialization() -> void:
	var enemy = create_test_enemy()
	
	# Initialize AI for enemy
	watch_signals(_tactical_ai)
	_tactical_ai.initialize_enemy_ai(enemy)
	
	# Verify initialization
	assert_true(enemy in _tactical_ai._enemy_personalities, "Enemy should be registered with AI")
	assert_true(enemy in _tactical_ai._tactical_states, "Enemy should have tactical state")

func test_aggressive_decision() -> void:
	var enemy = create_test_enemy()
	_tactical_ai.initialize_enemy_ai(enemy, EnemyTacticalAI.AIPersonality.AGGRESSIVE)
	
	# Make decision
	watch_signals(_tactical_ai)
	var decision = _tactical_ai.make_tactical_decision(enemy)
	
	# Verify decision
	assert_not_null(decision, "Decision should be made")
	verify_signal_emitted(_tactical_ai, "decision_made")

func test_cautious_decision() -> void:
	var enemy = create_test_enemy()
	_tactical_ai.initialize_enemy_ai(enemy, EnemyTacticalAI.AIPersonality.CAUTIOUS)
	
	# Make decision
	watch_signals(_tactical_ai)
	var decision = _tactical_ai.make_tactical_decision(enemy)
	
	# Verify decision
	assert_not_null(decision, "Decision should be made")
	verify_signal_emitted(_tactical_ai, "decision_made")

# Group AI Tests
func test_group_coordination() -> void:
	var leader = create_test_enemy("ELITE")
	var followers = _create_follower_group(2)
	var group = [leader] + followers
	
	# Initialize AI for group
	for enemy in group:
		_tactical_ai.initialize_enemy_ai(enemy)
	
	# Make group decision
	watch_signals(_tactical_ai)
	var decision = _tactical_ai._make_group_decision(leader, group)
	
	# Verify group coordination
	assert_not_null(decision, "Group decision should be made")
	assert_true(decision.has("group_action"), "Decision should be marked as group action")
	verify_signal_emitted(_tactical_ai, "group_coordination_updated")

func test_threat_assessment() -> void:
	var enemy = create_test_enemy()
	var target = create_test_enemy("BOSS") # High threat target
	_tactical_ai.initialize_enemy_ai(enemy)
	
	# Update threat assessment
	_tactical_ai._update_threat_assessment(enemy)
	
	# Verify threat assessment
	var threats = _tactical_ai._threat_assessments.get(enemy, {})
	assert_not_null(threats, "Threat assessment should be created")
	assert_true(_tactical_ai._tactical_states[enemy].threat_level > 0, "Threat level should be calculated")

# Pathfinding Tests
func test_pathfinding() -> void:
	var enemy = create_test_enemy()
	var start_pos = Vector2(0, 0)
	var end_pos = Vector2(100, 100)
	
	enemy.position = start_pos
	var path = _tactical_ai.find_path(enemy, end_pos)
	
	assert_not_null(path, "Path should be generated")
	assert_true(path.size() > 0, "Path should contain points")
	assert_eq(path[path.size() - 1], end_pos, "Path should lead to target")

# Helper Methods
func _create_follower_group(size: int) -> Array:
	var followers = []
	for i in range(size):
		var follower = create_test_enemy()
		followers.append(follower)
	return followers