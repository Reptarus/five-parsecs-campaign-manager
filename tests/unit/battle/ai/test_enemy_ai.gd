## Enemy AI Test Suite
## Tests the functionality of the enemy AI system including:
## - AI decision making
## - Group tactics
## - State tracking
## - Performance under stress
## - Error handling
## - Signal verification
@tool
extends "res://tests/fixtures/specialized/enemy_test.gd"
# Use explicit preloads instead of global class names

# Explicitly import TestEnums to access all the custom enum types
const LocalTestEnums = preload("res://tests/fixtures/base/test_helper.gd")

# Load scripts safely - handles missing files gracefully
var EnemyAIManagerScript = load("res://src/core/managers/EnemyAIManager.gd") if ResourceLoader.exists("res://src/core/managers/EnemyAIManager.gd") else null
var EnemyTacticalAIScript = load("res://src/game/combat/EnemyTacticalAI.gd") if ResourceLoader.exists("res://src/game/combat/EnemyTacticalAI.gd") else null
var BattlefieldManagerScript = load("res://src/base/combat/battlefield/BaseBattlefieldManager.gd") if ResourceLoader.exists("res://src/base/combat/battlefield/BaseBattlefieldManager.gd") else null
var BaseCombatManagerScript = load("res://src/base/combat/BaseCombatManager.gd") if ResourceLoader.exists("res://src/base/combat/BaseCombatManager.gd") else null

# Type-safe constants
const TEST_TIMEOUT := 1.0
const STABILIZE_TIMEOUT := 0.1

# Type-safe instance variables
var _ai_manager: Node = null
var _tactical_ai: Node = null
var _battlefield_manager: Node = null
var _combat_manager: Node = null
var _test_units: Array[Node] = []

# Test Lifecycle Methods
func before_each() -> void:
	await super.before_each()
	
	# Setup AI test environment
	if not BattlefieldManagerScript:
		push_error("BattlefieldManager script is null")
		return
		
	_battlefield_manager = BattlefieldManagerScript.new()
	if not _battlefield_manager:
		push_error("Failed to create battlefield manager")
		return
	add_child_autofree(_battlefield_manager)
	track_test_node(_battlefield_manager)
	
	if not BaseCombatManagerScript:
		push_error("BaseCombatManager script is null")
		return
		
	_combat_manager = BaseCombatManagerScript.new()
	if not _combat_manager:
		push_error("Failed to create combat manager")
		return
	add_child_autofree(_combat_manager)
	track_test_node(_combat_manager)
	
	if not EnemyAIManagerScript:
		push_error("EnemyAIManager script is null")
		return
		
	var ai_obj = EnemyAIManagerScript.new()
	if not ai_obj:
		push_error("Failed to create AI manager")
		return
	
	# Handle type mismatch for Node vs Resource
	if ai_obj is Node:
		_ai_manager = ai_obj
	else:
		# Create a Node wrapper for non-Node AI manager
		_ai_manager = Node.new()
		_ai_manager.name = "EnemyAIManagerWrapper"
		_ai_manager.set_meta("ai_controller", ai_obj)
		# Define forwarding functions if needed
	
	# Use direct method call instead of TypeSafeMixin for critical initialization
	if _ai_manager.has_method("initialize"):
		_ai_manager.initialize(_battlefield_manager, _combat_manager)
	else:
		push_error("AI manager doesn't have initialize method")
		return
		
	add_child_autofree(_ai_manager)
	track_test_node(_ai_manager)
	
	if not EnemyTacticalAIScript:
		push_error("EnemyTacticalAI script is null")
		return
		
	var tactical_obj = EnemyTacticalAIScript.new()
	if not tactical_obj:
		push_error("Failed to create tactical AI")
		return
		
	# Handle type mismatch for Node vs Resource
	if tactical_obj is Node:
		_tactical_ai = tactical_obj
	else:
		# Create a Node wrapper for non-Node tactical AI
		_tactical_ai = Node.new()
		_tactical_ai.name = "EnemyTacticalAIWrapper"
		_tactical_ai.set_meta("tactical_controller", tactical_obj)
		# Define forwarding functions if needed
		
	# Use direct method call for tactical AI initialization
	if _tactical_ai.has_method("initialize"):
		_tactical_ai.initialize(_ai_manager)
	else:
		push_error("Tactical AI doesn't have initialize method")
		return
		
	add_child_autofree(_tactical_ai)
	track_test_node(_tactical_ai)
	
	watch_signals(_ai_manager)
	watch_signals(_tactical_ai)
	await stabilize_engine(STABILIZE_TIMEOUT)

func after_each() -> void:
	# Clean up test units
	for unit in _test_units:
		if is_instance_valid(unit) and unit.is_inside_tree():
			unit.queue_free()
	
	_test_units.clear()
	_ai_manager = null
	_tactical_ai = null
	_battlefield_manager = null
	_combat_manager = null
	await super.after_each()

# AI Initialization Tests
func test_ai_initialization() -> void:
	assert_not_null(_ai_manager, "AI manager should be initialized")
	assert_not_null(_tactical_ai, "Tactical AI should be initialized")
	
	var is_active: bool = Compatibility.safe_call_method(_ai_manager, "is_active", [], false)
	assert_true(is_active, "AI should be active after initialization")

# Target Selection Tests
func test_target_selection() -> void:
	watch_signals(_ai_manager)
	
	# Create test units
	var enemy_unit := _create_test_unit(false)
	var player_unit := _create_test_unit(true)
	
	# Test target selection
	var target = Compatibility.safe_call_method(_ai_manager, "select_target", [enemy_unit], null)
	assert_not_null(target, "Target should not be null")
	assert_true(target is Node, "Target should be a Node")
	assert_eq(target, player_unit, "Should select player unit as target")
	verify_signal_emitted(_ai_manager, "target_selected")

# Movement Decision Tests
func test_movement_decisions() -> void:
	watch_signals(_tactical_ai)
	
	var unit := _create_test_unit(false)
	Compatibility.safe_call_method(unit, "set_position", [Vector2(5, 5)])
	
	var move_decision = Compatibility.safe_call_method(_tactical_ai, "evaluate_movement", [unit], {})
	assert_not_null(move_decision, "Should generate movement decision")
	assert_true("position" in move_decision, "Decision should include target position")
	verify_signal_emitted(_tactical_ai, "movement_evaluated")

# Combat Behavior Tests
func test_combat_behavior() -> void:
	watch_signals(_ai_manager)
	
	var unit := _create_test_unit(false)
	Compatibility.safe_call_method(unit, "set_combat_state", [LocalTestEnums.UnitState.ENGAGED])
	
	var behavior = Compatibility.safe_call_method(_ai_manager, "evaluate_combat_behavior", [unit], {})
	assert_not_null(behavior, "Should generate combat behavior")
	assert_true("action" in behavior, "Behavior should include action")
	assert_true("priority" in behavior, "Behavior should include a priority")
	verify_signal_emitted(_ai_manager, "behavior_evaluated")

# Tactical Analysis Tests
func test_tactical_analysis() -> void:
	watch_signals(_tactical_ai)
	
	var unit := _create_test_unit(false)
	var analysis = Compatibility.safe_call_method(_tactical_ai, "analyze_tactical_situation", [unit], {})
	
	assert_not_null(analysis, "Should generate tactical analysis")
	assert_true("threat_level" in analysis, "Analysis should include threat level")
	assert_true("cover_positions" in analysis, "Analysis should include cover positions")
	verify_signal_emitted(_tactical_ai, "situation_analyzed")

# Performance Tests
func test_ai_performance() -> void:
	var units := _create_multiple_units(10)
	var start_time := Time.get_ticks_msec()
	
	for unit in units:
		Compatibility.safe_call_method(_ai_manager, "process_unit_ai", [unit], {})
	
	var duration := Time.get_ticks_msec() - start_time
	assert_true(duration < 1000, "AI processing should complete within 1 second")

# Error Handling Tests
func test_error_handling() -> void:
	watch_signals(_ai_manager)
	
	# Test null unit
	var result = Compatibility.safe_call_method(_ai_manager, "process_unit_ai", [null], {})
	assert_false("action" in result, "Should handle null unit gracefully")
	verify_signal_not_emitted(_ai_manager, "behavior_evaluated")
	
	# Test invalid state
	var unit := _create_test_unit(false)
	Compatibility.safe_call_method(unit, "set_combat_state", [-1])
	result = Compatibility.safe_call_method(_ai_manager, "process_unit_ai", [unit], {})
	assert_true("error" in result, "Should handle invalid state")

# Helper Methods
func _create_test_unit(is_player: bool) -> Node:
	var unit := create_test_enemy()
	if not unit:
		return null
		
	# Setup properties
	Compatibility.safe_call_method(unit, "set_position", [Vector2(randi() % 100, randi() % 100)])
	Compatibility.safe_call_method(unit, "set_is_player", [is_player])
	Compatibility.safe_call_method(unit, "set_action_points", [3])
	
	_test_units.append(unit)
	return unit

func _create_multiple_units(count: int) -> Array[Node]:
	var units: Array[Node] = []
	for i in range(count):
		var unit := _create_test_unit(false)
		if unit:
			units.append(unit)
	return units
