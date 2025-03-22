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

# Type-safe script references
const EnemyAIManager: GDScript = preload("res://src/core/managers/EnemyAIManager.gd")
const EnemyTacticalAI: GDScript = preload("res://src/game/combat/EnemyTacticalAI.gd")
const BattlefieldManager: GDScript = preload("res://src/base/combat/battlefield/BaseBattlefieldManager.gd")
const BaseCombatManager: GDScript = preload("res://src/base/combat/BaseCombatManager.gd")

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
	_battlefield_manager = BattlefieldManager.new()
	if not _battlefield_manager:
		push_error("Failed to create battlefield manager")
		return
	add_child_autofree(_battlefield_manager)
	track_test_node(_battlefield_manager)
	
	_combat_manager = BaseCombatManager.new()
	if not _combat_manager:
		push_error("Failed to create combat manager")
		return
	add_child_autofree(_combat_manager)
	track_test_node(_combat_manager)
	
	_ai_manager = EnemyAIManager.new()
	if not _ai_manager:
		push_error("Failed to create AI manager")
		return
	TypeSafeMixin._call_node_method_bool(_ai_manager, "initialize", [_battlefield_manager, _combat_manager])
	add_child_autofree(_ai_manager)
	track_test_node(_ai_manager)
	
	_tactical_ai = EnemyTacticalAI.new()
	if not _tactical_ai:
		push_error("Failed to create tactical AI")
		return
	TypeSafeMixin._call_node_method_bool(_tactical_ai, "initialize", [_ai_manager])
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
	
	var is_active: bool = TypeSafeMixin._call_node_method_bool(_ai_manager, "is_active", [])
	assert_true(is_active, "AI should be active after initialization")

# Target Selection Tests
func test_target_selection() -> void:
	watch_signals(_ai_manager)
	
	# Create test units
	var enemy_unit := _create_test_unit(false)
	var player_unit := _create_test_unit(true)
	
	# Test target selection
	var target: Node = TypeSafeMixin._safe_cast_to_node(TypeSafeMixin._call_node_method(_ai_manager, "select_target", [enemy_unit]))
	assert_eq(target, player_unit, "Should select player unit as target")
	verify_signal_emitted(_ai_manager, "target_selected")

# Movement Decision Tests
func test_movement_decisions() -> void:
	watch_signals(_tactical_ai)
	
	var unit := _create_test_unit(false)
	var current_pos := Vector2(5, 5)
	TypeSafeMixin._call_node_method_bool(unit, "set_position", [current_pos])
	
	var move_decision: Dictionary = TypeSafeMixin._call_node_method_dict(_tactical_ai, "evaluate_movement", [unit])
	assert_not_null(move_decision, "Should generate movement decision")
	assert_true(move_decision.has("position"), "Decision should include target position")
	verify_signal_emitted(_tactical_ai, "movement_evaluated")

# Combat Behavior Tests
func test_combat_behavior() -> void:
	watch_signals(_ai_manager)
	
	var unit := _create_test_unit(false)
	TypeSafeMixin._call_node_method_bool(unit, "set_combat_state", [LocalTestEnums.UnitState.ENGAGED])
	
	var behavior: Dictionary = TypeSafeMixin._call_node_method_dict(_ai_manager, "evaluate_combat_behavior", [unit])
	assert_not_null(behavior, "Should generate combat behavior")
	assert_true(behavior.has("action"), "Behavior should include action")
	assert_true(behavior.has("priority"), "Behavior should include a priority")
	verify_signal_emitted(_ai_manager, "behavior_evaluated")

# Tactical Analysis Tests
func test_tactical_analysis() -> void:
	watch_signals(_tactical_ai)
	
	var unit := _create_test_unit(false)
	var analysis: Dictionary = TypeSafeMixin._call_node_method_dict(_tactical_ai, "analyze_tactical_situation", [unit])
	
	assert_not_null(analysis, "Should generate tactical analysis")
	assert_true(analysis.has("threat_level"), "Analysis should include threat level")
	assert_true(analysis.has("cover_positions"), "Analysis should include cover positions")
	verify_signal_emitted(_tactical_ai, "situation_analyzed")

# Performance Tests
func test_ai_performance() -> void:
	var units := _create_multiple_units(10)
	var start_time := Time.get_ticks_msec()
	
	for unit in units:
		TypeSafeMixin._call_node_method_dict(_ai_manager, "process_unit_ai", [unit])
	
	var duration := Time.get_ticks_msec() - start_time
	assert_true(duration < 1000, "AI processing should complete within 1 second")

# Error Handling Tests
func test_error_handling() -> void:
	watch_signals(_ai_manager)
	
	# Test null unit
	var result: Dictionary = TypeSafeMixin._call_node_method_dict(_ai_manager, "process_unit_ai", [null])
	assert_false(result.has("action"), "Should handle null unit gracefully")
	verify_signal_not_emitted(_ai_manager, "behavior_evaluated")
	
	# Test invalid state
	var unit := _create_test_unit(false)
	TypeSafeMixin._call_node_method_bool(unit, "set_combat_state", [-1])
	result = TypeSafeMixin._call_node_method_dict(_ai_manager, "process_unit_ai", [unit])
	assert_true(result.has("error"), "Should handle invalid state")

# Helper Methods
func _create_test_unit(is_player: bool) -> Node:
	var unit := create_test_enemy()
	if not unit:
		return null
		
	# Setup properties
	TypeSafeMixin._call_node_method_bool(unit, "set_position", [Vector2(randi() % 100, randi() % 100)])
	TypeSafeMixin._call_node_method_bool(unit, "set_is_player", [is_player])
	TypeSafeMixin._call_node_method_bool(unit, "set_action_points", [3])
	
	_test_units.append(unit)
	return unit

func _create_multiple_units(count: int) -> Array[Node]:
	var units: Array[Node] = []
	for i in range(count):
		var unit := _create_test_unit(false)
		if unit:
			units.append(unit)
	return units
