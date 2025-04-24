## Enemy AI Test Suite
## Tests the functionality of the enemy AI system including:
## - AI decision making
## - Group tactics
## - State tracking
## - Performance under stress
## - Error handling
## - Signal verification
@tool
extends GutTest

# Import required helpers
const TestCompatibilityHelper = preload("res://tests/fixtures/helpers/test_compatibility_helper.gd")
const GutCompatibility = preload("res://tests/fixtures/helpers/gut_compatibility.gd")

# Explicitly import TestEnums to access all the custom enum types
const LocalTestEnums = preload("res://tests/fixtures/base/test_helper.gd")

# Constants
const STABILIZE_TIME := 0.1
const TEST_TIMEOUT := 1.0

# Variables for scripts that might not exist - loaded dynamically in before_all
var EnemyNodeScript = null
var EnemyDataScript = null
var EnemyAIManagerScript = null
var EnemyTacticalAIScript = null
var BattlefieldManagerScript = null
var BaseCombatManagerScript = null
var GameEnums = null

# Type-safe instance variables
var _ai_manager: Node = null
var _tactical_ai: Node = null
var _battlefield_manager: Node = null
var _combat_manager: Node = null
var _test_units: Array = []
var _test_enemies: Array = []

# Test nodes to track for cleanup
var _tracked_test_nodes: Array = []

# Implementation of the track_test_node function
# This tracks nodes for proper cleanup in after_each
func track_test_node(node) -> void:
	if not is_instance_valid(node):
		push_warning("Cannot track invalid node")
		return
	
	if not (node in _tracked_test_nodes):
		_tracked_test_nodes.append(node)

# Implementation of the track_test_resource function
func track_test_resource(resource) -> void:
	if not resource:
		push_warning("Cannot track null resource")
		return
		
	# For GUT, we don't need to do anything special - resources are cleaned up by default

# TypeSafeMixin helper functions
class TypeSafeMixin:
	static func _call_node_method(obj: Object, method: String, args: Array = [], default_value = null):
		if not obj or not obj.has_method(method):
			return default_value
		if args.size() == 0:
			return obj.call(method)
		return obj.callv(method, args)
	
	static func _call_node_method_bool(obj: Object, method: String, args: Array = [], default_value: bool = false) -> bool:
		var result = _call_node_method(obj, method, args, default_value)
		if result is bool:
			return result
		return default_value
	
	static func _call_node_method_dict(obj: Object, method: String, args: Array = [], default_value: Dictionary = {}) -> Dictionary:
		var result = _call_node_method(obj, method, args, default_value)
		if result is Dictionary:
			return result
		return default_value

func before_all() -> void:
	# Dynamically load scripts to avoid errors if they don't exist
	GameEnums = load("res://src/core/systems/GlobalEnums.gd") if ResourceLoader.exists("res://src/core/systems/GlobalEnums.gd") else null
	
	# Load enemy scripts
	if ResourceLoader.exists("res://src/core/enemy/base/EnemyData.gd"):
		EnemyDataScript = load("res://src/core/enemy/base/EnemyData.gd")
	
	if ResourceLoader.exists("res://src/core/enemy/base/EnemyNode.gd"):
		EnemyNodeScript = load("res://src/core/enemy/base/EnemyNode.gd")
	
	# Load AI scripts
	EnemyAIManagerScript = load("res://src/core/managers/EnemyAIManager.gd") if ResourceLoader.exists("res://src/core/managers/EnemyAIManager.gd") else null
	EnemyTacticalAIScript = load("res://src/game/combat/EnemyTacticalAI.gd") if ResourceLoader.exists("res://src/game/combat/EnemyTacticalAI.gd") else null
	BattlefieldManagerScript = load("res://src/base/combat/battlefield/BaseBattlefieldManager.gd") if ResourceLoader.exists("res://src/base/combat/battlefield/BaseBattlefieldManager.gd") else null
	BaseCombatManagerScript = load("res://src/base/combat/BaseCombatManager.gd") if ResourceLoader.exists("res://src/base/combat/BaseCombatManager.gd") else null

func before_each() -> void:
	# Clear tracked nodes list
	_tracked_test_nodes.clear()
	
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
	await stabilize_engine(STABILIZE_TIME)

func after_each() -> void:
	# Clean up tracked test nodes
	for node in _tracked_test_nodes:
		if is_instance_valid(node) and not node.is_queued_for_deletion():
			node.queue_free()
	_tracked_test_nodes.clear()
	
	# Cleanup references
	_ai_manager = null
	_tactical_ai = null
	_battlefield_manager = null
	_combat_manager = null
	_test_units.clear()
	_test_enemies.clear()

# Base class helper function - stabilize the engine
func stabilize_engine(time: float = STABILIZE_TIME) -> void:
	await get_tree().create_timer(time).timeout

# Function to create a test enemy
func create_test_enemy(enemy_data: Resource = null) -> Node:
	# Create a basic enemy node
	var enemy_node = null
	
	# Try to create node from script
	if EnemyNodeScript != null:
		# Check if we can instantiate in a safe way
		enemy_node = EnemyNodeScript.new()
		
		if enemy_node and enemy_data:
			# Try different approaches to assign data
			if enemy_node.has_method("set_enemy_data"):
				enemy_node.set_enemy_data(enemy_data)
			elif enemy_node.has_method("initialize"):
				enemy_node.initialize(enemy_data)
			elif "enemy_data" in enemy_node:
				enemy_node.enemy_data = enemy_data
	else:
		# Fallback: create a simple Node
		push_warning("EnemyNodeScript unavailable, creating generic Node")
		enemy_node = Node.new()
		enemy_node.name = "GenericTestEnemy"
		
		# Add simple properties and methods for tests
		enemy_node.set("position", Vector2.ZERO)
		enemy_node.set("health", 100)
		enemy_node.set("is_player", false)
		enemy_node.set("action_points", 3)
		enemy_node.set("combat_state", 0)
		
		# Add methods
		enemy_node.set("set_position", func(pos): enemy_node.position = pos; return true)
		enemy_node.set("set_is_player", func(val): enemy_node.is_player = val; return true)
		enemy_node.set("set_action_points", func(points): enemy_node.action_points = points; return true)
		enemy_node.set("set_combat_state", func(state): enemy_node.combat_state = state; return true)
	
	# If we get a node, add it to scene and track it
	if enemy_node:
		add_child_autofree(enemy_node)
		
	# Track locally if needed for combat tests
	if enemy_node:
		_test_enemies.append(enemy_node)
		track_test_node(enemy_node)
	
	return enemy_node

# Function to create a test enemy resource
func create_test_enemy_resource(data: Dictionary = {}) -> Resource:
	var resource = null
	
	if EnemyDataScript != null:
		resource = EnemyDataScript.new()
		if resource:
			# Initialize the resource with data
			if resource.has_method("load"):
				resource.load(data)
			elif resource.has_method("initialize"):
				resource.initialize(data)
			else:
				# Fallback to manual property assignment
				for key in data:
					if resource.has_method("set_" + key):
						resource.call("set_" + key, data[key])
	
	# Track the resource if we successfully created it
	if resource:
		track_test_resource(resource)
		
	return resource

# AI Initialization Tests
func test_ai_initialization() -> void:
	assert_not_null(_ai_manager, "AI manager should be initialized")
	assert_not_null(_tactical_ai, "Tactical AI should be initialized")
	
	var is_active: bool = TypeSafeMixin._call_node_method_bool(_ai_manager, "is_active", [], false)
	assert_true(is_active, "AI should be active after initialization")

# Target Selection Tests
func test_target_selection() -> void:
	watch_signals(_ai_manager)
	
	# Create test units
	var enemy_unit := _create_test_unit(false)
	var player_unit := _create_test_unit(true)
	
	# Test target selection
	var target = TypeSafeMixin._call_node_method(_ai_manager, "select_target", [enemy_unit])
	assert_not_null(target, "Target should not be null")
	assert_true(target is Node, "Target should be a Node")
	assert_eq(target, player_unit, "Should select player unit as target")
	verify_signal_emitted(_ai_manager, "target_selected")

# Movement Decision Tests
func test_movement_decisions() -> void:
	watch_signals(_tactical_ai)
	
	var unit := _create_test_unit(false)
	TypeSafeMixin._call_node_method_bool(unit, "set_position", [Vector2(5, 5)])
	
	var move_decision = TypeSafeMixin._call_node_method_dict(_tactical_ai, "evaluate_movement", [unit], {})
	assert_not_null(move_decision, "Should generate movement decision")
	assert_true("position" in move_decision, "Decision should include target position")
	verify_signal_emitted(_tactical_ai, "movement_evaluated")

# Combat Behavior Tests
func test_combat_behavior() -> void:
	watch_signals(_ai_manager)
	
	var unit := _create_test_unit(false)
	TypeSafeMixin._call_node_method_bool(unit, "set_combat_state", [LocalTestEnums.UnitState.ENGAGED])
	
	var behavior = TypeSafeMixin._call_node_method_dict(_ai_manager, "evaluate_combat_behavior", [unit], {})
	assert_not_null(behavior, "Should generate combat behavior")
	assert_true("action" in behavior, "Behavior should include action")
	assert_true("priority" in behavior, "Behavior should include a priority")
	verify_signal_emitted(_ai_manager, "behavior_evaluated")

# Tactical Analysis Tests
func test_tactical_analysis() -> void:
	watch_signals(_tactical_ai)
	
	var unit := _create_test_unit(false)
	var analysis = TypeSafeMixin._call_node_method_dict(_tactical_ai, "analyze_tactical_situation", [unit], {})
	
	assert_not_null(analysis, "Should generate tactical analysis")
	assert_true("threat_level" in analysis, "Analysis should include threat level")
	assert_true("cover_positions" in analysis, "Analysis should include cover positions")
	verify_signal_emitted(_tactical_ai, "situation_analyzed")

# Performance Tests
func test_ai_performance() -> void:
	var units := _create_multiple_units(10)
	var start_time := Time.get_ticks_msec()
	
	for unit in units:
		TypeSafeMixin._call_node_method_dict(_ai_manager, "process_unit_ai", [unit], {})
	
	var duration := Time.get_ticks_msec() - start_time
	assert_true(duration < 1000, "AI processing should complete within 1 second")

# Error Handling Tests
func test_error_handling() -> void:
	watch_signals(_ai_manager)
	
	# Test null unit
	var result = TypeSafeMixin._call_node_method_dict(_ai_manager, "process_unit_ai", [null], {})
	assert_false("action" in result, "Should handle null unit gracefully")
	verify_signal_not_emitted(_ai_manager, "behavior_evaluated")
	
	# Test invalid state
	var unit := _create_test_unit(false)
	TypeSafeMixin._call_node_method_bool(unit, "set_combat_state", [-1])
	result = TypeSafeMixin._call_node_method_dict(_ai_manager, "process_unit_ai", [unit], {})
	assert_true("error" in result, "Should handle invalid state")

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

func _create_multiple_units(count: int) -> Array:
	var units: Array = []
	for i in range(count):
		var unit := _create_test_unit(false)
		if unit:
			units.append(unit)
	return units

# Verify that a signal was emitted
func verify_signal_emitted(obj: Object, signal_name: String) -> void:
	if has_method("assert_signal_emitted"):
		assert_signal_emitted(obj, signal_name)

# Verify that a signal was not emitted
func verify_signal_not_emitted(obj: Object, signal_name: String) -> void:
	if has_method("assert_signal_not_emitted"):
		assert_signal_not_emitted(obj, signal_name)
