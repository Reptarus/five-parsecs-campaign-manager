@tool
extends FiveParsecsEnemyTest

# Type-safe instance variables
var _ai_manager: Node = null
var _tactical_ai: Node = null
var _battlefield_manager: Node = null
var _combat_manager: Node = null

func before_each() -> void:
	await super.before_each()
	
	# Setup AI test environment
	_battlefield_manager = Node.new()
	if not _battlefield_manager:
		push_error("Failed to create battlefield manager")
		return
	_battlefield_manager.name = "BattlefieldManager"
	add_child_autofree(_battlefield_manager)
	track_test_node(_battlefield_manager)
	
	_combat_manager = Node.new()
	if not _combat_manager:
		push_error("Failed to create combat manager")
		return
	_combat_manager.name = "CombatManager"
	add_child_autofree(_combat_manager)
	track_test_node(_combat_manager)
	
	# Create AI managers
	_ai_manager = TypeSafeMixin._safe_cast_node(EnemyAIManager.new())
	if not _ai_manager:
		push_error("Failed to create AI manager")
		return
	add_child_autofree(_ai_manager)
	track_test_node(_ai_manager)
	
	_tactical_ai = TypeSafeMixin._safe_cast_node(EnemyTacticalAI.new())
	if not _tactical_ai:
		push_error("Failed to create tactical AI")
		return
	TypeSafeMixin._safe_method_call_bool(_tactical_ai, "set_battlefield_manager", [_battlefield_manager])
	TypeSafeMixin._safe_method_call_bool(_tactical_ai, "set_combat_manager", [_combat_manager])
	add_child_autofree(_tactical_ai)
	track_test_node(_tactical_ai)
	
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
	
	var active_enemies: Array = TypeSafeMixin._safe_method_call_array(_ai_manager, "get_active_enemies", [])
	assert_eq(active_enemies.size(), 0, "No enemies should be registered initially")

# AI Manager Tests
func test_enemy_registration() -> void:
	var enemy: Node = create_test_enemy()
	if not enemy:
		push_error("Failed to create test enemy")
		return
	
	# Register enemy
	TypeSafeMixin._safe_method_call_bool(_ai_manager, "register_enemy", [enemy])
	var active_enemies: Array = TypeSafeMixin._safe_method_call_array(_ai_manager, "get_active_enemies", [])
	assert_has(active_enemies, enemy, "Enemy should be registered")
	
	# Unregister enemy
	TypeSafeMixin._safe_method_call_bool(_ai_manager, "unregister_enemy", [enemy])
	active_enemies = TypeSafeMixin._safe_method_call_array(_ai_manager, "get_active_enemies", [])
	assert_does_not_have(active_enemies, enemy, "Enemy should be unregistered")

func test_behavior_override() -> void:
	var enemy: Node = create_test_enemy()
	if not enemy:
		push_error("Failed to create test enemy")
		return
	
	var test_behavior: int = GameEnums.AIBehavior.AGGRESSIVE
	
	# Set behavior override
	_signal_watcher.watch_signals(_ai_manager)
	TypeSafeMixin._safe_method_call_bool(_ai_manager, "set_behavior_override", [enemy, test_behavior])
	
	var current_behavior: int = TypeSafeMixin._safe_method_call_int(_ai_manager, "get_current_behavior", [enemy])
	assert_eq(current_behavior, test_behavior, "Enemy should have overridden behavior")
	verify_signal_emitted(_ai_manager, "behavior_changed")
	
	# Clear behavior override
	TypeSafeMixin._safe_method_call_bool(_ai_manager, "clear_behavior_override", [enemy])
	current_behavior = TypeSafeMixin._safe_method_call_int(_ai_manager, "get_current_behavior", [enemy])
	var enemy_behavior: int = TypeSafeMixin._safe_method_call_int(enemy, "get_behavior", [])
	assert_eq(current_behavior, enemy_behavior, "Enemy should return to default behavior")

# Tactical AI Tests
func test_tactical_ai_initialization() -> void:
	var enemy: Node = create_test_enemy()
	if not enemy:
		push_error("Failed to create test enemy")
		return
	
	# Initialize AI for enemy
	_signal_watcher.watch_signals(_tactical_ai)
	TypeSafeMixin._safe_method_call_bool(_tactical_ai, "initialize_enemy_ai", [enemy])
	
	# Verify initialization
	var personalities: Dictionary = TypeSafeMixin._safe_method_call_dict(_tactical_ai, "get_enemy_personalities", [])
	var tactical_states: Dictionary = TypeSafeMixin._safe_method_call_dict(_tactical_ai, "get_tactical_states", [])
	
	assert_true(enemy in personalities, "Enemy should be registered with AI")
	assert_true(enemy in tactical_states, "Enemy should have tactical state")

func test_aggressive_decision() -> void:
	var enemy: Node = create_test_enemy()
	if not enemy:
		push_error("Failed to create test enemy")
		return
	
	TypeSafeMixin._safe_method_call_bool(_tactical_ai, "initialize_enemy_ai", [enemy, EnemyTacticalAI.AIPersonality.AGGRESSIVE])
	
	# Make decision
	_signal_watcher.watch_signals(_tactical_ai)
	var decision: Dictionary = TypeSafeMixin._safe_method_call_dict(_tactical_ai, "make_tactical_decision", [enemy])
	
	# Verify decision
	assert_not_null(decision, "Decision should be made")
	verify_signal_emitted(_tactical_ai, "decision_made")

func test_cautious_decision() -> void:
	var enemy: Node = create_test_enemy()
	if not enemy:
		push_error("Failed to create test enemy")
		return
	
	TypeSafeMixin._safe_method_call_bool(_tactical_ai, "initialize_enemy_ai", [enemy, EnemyTacticalAI.AIPersonality.CAUTIOUS])
	
	# Make decision
	_signal_watcher.watch_signals(_tactical_ai)
	var decision: Dictionary = TypeSafeMixin._safe_method_call_dict(_tactical_ai, "make_tactical_decision", [enemy])
	
	# Verify decision
	assert_not_null(decision, "Decision should be made")
	verify_signal_emitted(_tactical_ai, "decision_made")

# Group AI Tests
func test_group_coordination() -> void:
	var leader: Node = create_test_enemy("ELITE")
	if not leader:
		push_error("Failed to create leader enemy")
		return
	
	var followers: Array[Node] = _create_follower_group(2)
	var group: Array[Node] = [leader] + followers
	
	# Initialize AI for group
	for enemy in group:
		if not enemy:
			push_error("Invalid enemy in group")
			continue
		TypeSafeMixin._safe_method_call_bool(_tactical_ai, "initialize_enemy_ai", [enemy])
	
	# Make group decision
	_signal_watcher.watch_signals(_tactical_ai)
	var decision: Dictionary = TypeSafeMixin._safe_method_call_dict(_tactical_ai, "_make_group_decision", [leader, group])
	
	# Verify group coordination
	assert_not_null(decision, "Group decision should be made")
	assert_true(decision.has("group_action"), "Decision should be marked as group action")
	verify_signal_emitted(_tactical_ai, "group_coordination_updated")

func test_threat_assessment() -> void:
	var enemy: Node = create_test_enemy()
	if not enemy:
		push_error("Failed to create test enemy")
		return
	
	var target: Node = create_test_enemy("BOSS") # High threat target
	if not target:
		push_error("Failed to create target enemy")
		return
	
	TypeSafeMixin._safe_method_call_bool(_tactical_ai, "initialize_enemy_ai", [enemy])
	
	# Update threat assessment
	TypeSafeMixin._safe_method_call_bool(_tactical_ai, "_update_threat_assessment", [enemy])
	
	# Verify threat assessment
	var threat_assessments: Dictionary = TypeSafeMixin._safe_method_call_dict(_tactical_ai, "get_threat_assessments", [])
	var tactical_states: Dictionary = TypeSafeMixin._safe_method_call_dict(_tactical_ai, "get_tactical_states", [])
	
	assert_not_null(threat_assessments.get(enemy, null), "Threat assessment should be created")
	var threat_level: float = TypeSafeMixin._safe_method_call_float(tactical_states[enemy], "get_threat_level", [])
	assert_true(threat_level > 0, "Threat level should be calculated")

# Pathfinding Tests
func test_pathfinding() -> void:
	var enemy: Node = create_test_enemy()
	if not enemy:
		push_error("Failed to create test enemy")
		return
	
	var start_pos := Vector2(0, 0)
	var end_pos := Vector2(100, 100)
	
	TypeSafeMixin._safe_method_call_bool(enemy, "set_position", [start_pos])
	var path: Array = TypeSafeMixin._safe_method_call_array(_tactical_ai, "find_path", [enemy, end_pos])
	
	assert_not_null(path, "Path should be generated")
	assert_true(path.size() > 0, "Path should contain points")
	assert_eq(path[path.size() - 1], end_pos, "Path should lead to target")

# Helper Methods
func _create_follower_group(size: int) -> Array[Node]:
	var followers: Array[Node] = []
	for i in range(size):
		var follower: Node = create_test_enemy()
		if not follower:
			push_error("Failed to create follower enemy %d" % i)
			continue
		followers.append(follower)
	return followers
