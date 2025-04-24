## Enemy Tactical AI Test Suite
## Tests the functionality of the enemy tactical AI system including:
## - AI decision making
## - Group tactics
## - State tracking
## - Performance under stress
## - Error handling
## - Signal verification
@tool
extends "res://tests/fixtures/base/game_test.gd"

# Load scripts safely - handles missing files gracefully
const Compatibility = preload("res://tests/fixtures/helpers/test_compatibility_helper.gd")
var EnemyTacticalAIScript = load("res://src/game/combat/EnemyTacticalAI.gd") if ResourceLoader.exists("res://src/game/combat/EnemyTacticalAI.gd") else null
var BattlefieldManagerScript = load("res://src/base/combat/battlefield/BaseBattlefieldManager.gd") if ResourceLoader.exists("res://src/base/combat/battlefield/BaseBattlefieldManager.gd") else null
var CombatManagerScript = load("res://src/base/combat/BaseCombatManager.gd") if ResourceLoader.exists("res://src/base/combat/BaseCombatManager.gd") else null

# Type-safe script references
const EnemyTacticalAI: GDScript = preload("res://src/game/combat/EnemyTacticalAI.gd")
const BattlefieldManager: GDScript = preload("res://src/base/combat/battlefield/BaseBattlefieldManager.gd")
const Character: GDScript = preload("res://src/core/character/Base/Character.gd")

# Type-safe constants
const TEST_TIMEOUT: float = 2.0

# Type-safe instance variables
var _tactical_ai: Node = null
var _battlefield: Node = null
var _combat_manager: Node = null
var _test_units: Array = []

# Signal tracking
var _signal_data: Dictionary = {
	"decision_made": false,
	"tactic_changed": false,
	"group_coordination": false,
	"last_decision_enemy": null,
	"last_decision_action": {},
	"last_tactic_enemy": null,
	"last_tactic_change": - 1,
	"last_coordinated_group": [],
	"last_group_leader": null
}

# Use explicit preloads instead of global class names
const TestEnums = preload("res://tests/fixtures/base/test_helper.gd")

# Test Lifecycle Methods
func before_each() -> void:
	await super.before_each()
	
	# Initialize battlefield manager directly without TypeSafeMixin
	if not BattlefieldManager:
		push_error("BattlefieldManager script is null")
		return
		
	_battlefield = BattlefieldManager.new()
	if not _battlefield:
		push_error("Failed to create battlefield manager")
		return
	add_child_autofree(_battlefield)
	track_test_node(_battlefield)
	
	# Initialize combat manager
	_combat_manager = CombatManagerScript.new()
	if not _combat_manager:
		push_error("Failed to create combat manager")
		return
	add_child_autofree(_combat_manager)
	track_test_node(_combat_manager)
	
	# Initialize tactical AI directly without TypeSafeMixin
	if not EnemyTacticalAI:
		push_error("EnemyTacticalAI script is null")
		return
		
	_tactical_ai = EnemyTacticalAI.new()
	if not _tactical_ai:
		push_error("Failed to create tactical AI")
		return
		
	# Call initialize directly instead of using TypeSafeMixin
	if _tactical_ai.has_method("initialize"):
		_tactical_ai.initialize(_battlefield, _combat_manager)
	else:
		push_error("Tactical AI doesn't have initialize method")
		return
		
	add_child_autofree(_tactical_ai)
	track_test_node(_tactical_ai)
	
	_connect_signals()
	_reset_signal_data()
	watch_signals(_tactical_ai)
	await stabilize_engine(STABILIZE_TIME)

func after_each() -> void:
	_disconnect_signals()
	_reset_signal_data()
	_tactical_ai = null
	_battlefield = null
	_combat_manager = null
	await super.after_each()

# Signal Methods
func _connect_signals() -> void:
	if not _tactical_ai:
		return
		
	if _tactical_ai.has_signal("decision_made"):
		_tactical_ai.connect("decision_made", _on_decision_made)
	if _tactical_ai.has_signal("tactic_changed"):
		_tactical_ai.connect("tactic_changed", _on_tactic_changed)
	if _tactical_ai.has_signal("group_coordination_updated"):
		_tactical_ai.connect("group_coordination_updated", _on_group_coordination_updated)

func _disconnect_signals() -> void:
	if not _tactical_ai:
		return
		
	if _tactical_ai.has_signal("decision_made") and _tactical_ai.is_connected("decision_made", _on_decision_made):
		_tactical_ai.disconnect("decision_made", _on_decision_made)
	if _tactical_ai.has_signal("tactic_changed") and _tactical_ai.is_connected("tactic_changed", _on_tactic_changed):
		_tactical_ai.disconnect("tactic_changed", _on_tactic_changed)
	if _tactical_ai.has_signal("group_coordination_updated") and _tactical_ai.is_connected("group_coordination_updated", _on_group_coordination_updated):
		_tactical_ai.disconnect("group_coordination_updated", _on_group_coordination_updated)

func _reset_signal_data() -> void:
	_signal_data = {
		"decision_made": false,
		"tactic_changed": false,
		"group_coordination": false,
		"last_decision_enemy": null,
		"last_decision_action": {},
		"last_tactic_enemy": null,
		"last_tactic_change": - 1,
		"last_coordinated_group": [],
		"last_group_leader": null
	}

func _on_decision_made(enemy: Node, action: Dictionary) -> void:
	_signal_data.decision_made = true
	_signal_data.last_decision_enemy = enemy
	_signal_data.last_decision_action = action

func _on_tactic_changed(enemy: Node, new_tactic: int) -> void:
	_signal_data.tactic_changed = true
	_signal_data.last_tactic_enemy = enemy
	_signal_data.last_tactic_change = new_tactic

func _on_group_coordination_updated(group: Array, leader: Node) -> void:
	_signal_data.group_coordination = true
	_signal_data.last_coordinated_group = group
	_signal_data.last_group_leader = leader

# Helper Methods
func _create_test_enemy(personality: int = TestEnums.AIPersonality.AGGRESSIVE) -> Node:
	if not Character:
		push_error("Character script is null")
		return null
		
	# Try to create a Character instance
	var enemy = null
	
	# First try instantiating as a class
	if typeof(Character) == TYPE_OBJECT and Character.has_method("new"):
		var character_instance = Character.new()
		
		# Check if it's a Node or Resource
		if character_instance is Node:
			enemy = character_instance
		elif character_instance is Resource:
			# Create a Node wrapper for the Resource
			enemy = Node2D.new()
			enemy.name = "EnemyWrapper"
			enemy.set_meta("character_data", character_instance)
			
			# Add forwarding methods if needed
			if character_instance.has_method("initialize"):
				enemy.set("initialize", func():
					var data = enemy.get_meta("character_data")
					if data and data.has_method("initialize"):
						return data.initialize()
					return false
				)
	
	# If we still don't have an enemy, try loading as a scene
	if enemy == null:
		var character_scene_path = "res://src/core/character/Base/Character.tscn"
		if ResourceLoader.exists(character_scene_path):
			var scene = load(character_scene_path)
			if scene and scene is PackedScene:
				enemy = scene.instantiate()
	
	# If all else fails, create a basic Node2D
	if enemy == null:
		push_warning("Could not create Character instance, using a basic Node2D instead")
		enemy = Node2D.new()
		enemy.name = "MockEnemy"
	
	# Make sure it has a name
	enemy.name = "Enemy_" + str(randi())
	
	# Initialize if possible
	if enemy.has_method("initialize"):
		enemy.initialize()
	
	# Set the personality in the AI system
	if _tactical_ai and _tactical_ai.has_method("set_enemy_personality"):
		_tactical_ai.set_enemy_personality(enemy, personality)
	
	add_child_autofree(enemy)
	track_test_node(enemy)
	return enemy

func _create_test_group(size: int = 3) -> Array[Node]:
	var group: Array[Node] = []
	
	# Try to create the requested number of enemies
	for i in range(size):
		var enemy = _create_test_enemy()
		if enemy:
			group.append(enemy)
	
	# Log warning if group is smaller than requested
	if group.size() < size:
		push_warning("Created group with " + str(group.size()) + " enemies, requested " + str(size))
	
	return group

# AI Personality Tests
func test_ai_personality_types() -> void:
	assert_has(TestEnums.AIPersonality, "AGGRESSIVE", "Should have aggressive personality")
	assert_has(TestEnums.AIPersonality, "CAUTIOUS", "Should have cautious personality")
	assert_has(TestEnums.AIPersonality, "TACTICAL", "Should have tactical personality")
	assert_has(TestEnums.AIPersonality, "PROTECTIVE", "Should have protective personality")
	assert_has(TestEnums.AIPersonality, "UNPREDICTABLE", "Should have unpredictable personality")

# Group Tactics Tests
func test_group_tactic_types() -> void:
	assert_has(TestEnums.GroupTactic, "COORDINATED_ATTACK", "Should have coordinated attack tactic")
	assert_has(TestEnums.GroupTactic, "DEFENSIVE_FORMATION", "Should have defensive formation tactic")
	assert_has(TestEnums.GroupTactic, "FLANKING_MANEUVER", "Should have flanking maneuver tactic")
	assert_has(TestEnums.GroupTactic, "SUPPRESSION_PATTERN", "Should have suppression pattern tactic")

# Decision Making Tests
func test_decision_making_signals() -> void:
	var test_enemy := _create_test_enemy()
	var test_action := {"type": GameEnums.UnitAction.MOVE, "target": Vector2(1, 1)}
	
	_reset_signal_data()
	TypeSafeMixin._call_node_method_bool(_tactical_ai, "emit_signal", ["decision_made", test_enemy, test_action])
	
	assert_true(_signal_data.decision_made, "Should emit decision_made signal")
	assert_eq(_signal_data.last_decision_enemy, test_enemy, "Should emit correct enemy")
	assert_eq(_signal_data.last_decision_action, test_action, "Should emit correct action")

func test_tactic_change_signals() -> void:
	var test_enemy := _create_test_enemy()
	var test_tactic := GameEnums.CombatTactic.AGGRESSIVE
	
	_reset_signal_data()
	TypeSafeMixin._call_node_method_bool(_tactical_ai, "emit_signal", ["tactic_changed", test_enemy, test_tactic])
	
	assert_true(_signal_data.tactic_changed, "Should emit tactic_changed signal")
	assert_eq(_signal_data.last_tactic_enemy, test_enemy, "Should emit correct enemy")
	assert_eq(_signal_data.last_tactic_change, test_tactic, "Should emit correct tactic")

func test_group_coordination_signals() -> void:
	var test_group := _create_test_group(3) # Create at least 3 enemies to ensure we have enough
	
	# Skip test if the group couldn't be created correctly
	if test_group.is_empty():
		push_error("Could not create test group for coordination signals test")
		return
		
	var test_leader = test_group[0] if test_group.size() > 0 else null
	
	# Skip if no leader could be assigned
	if test_leader == null:
		push_error("No leader available for coordination test")
		return
	
	_reset_signal_data()
	TypeSafeMixin._call_node_method_bool(_tactical_ai, "emit_signal", ["group_coordination_updated", test_group, test_leader])
	
	assert_true(_signal_data.group_coordination, "Should emit group_coordination_updated signal")
	assert_eq(_signal_data.last_coordinated_group, test_group, "Should emit correct group")
	assert_eq(_signal_data.last_group_leader, test_leader, "Should emit correct leader")

# State Tracking Tests
func test_enemy_personality_tracking() -> void:
	var test_enemy := _create_test_enemy()
	var personality: int = TestEnums.AIPersonality.AGGRESSIVE
	
	TypeSafeMixin._call_node_method_bool(_tactical_ai, "set_enemy_personality", [test_enemy, personality])
	var tracked_personality: int = TypeSafeMixin._call_node_method_int(_tactical_ai, "get_enemy_personality", [test_enemy])
	assert_eq(tracked_personality, personality, "Should track enemy personality")

func test_group_assignment_tracking() -> void:
	var test_enemy := _create_test_enemy()
	var test_group := _create_test_group()
	
	TypeSafeMixin._call_node_method_bool(_tactical_ai, "assign_to_group", [test_enemy, test_group])
	var assigned_group: Array = TypeSafeMixin._call_node_method_array(_tactical_ai, "get_enemy_group", [test_enemy])
	assert_eq(assigned_group, test_group, "Should track group assignments")

func test_tactical_state_tracking() -> void:
	var test_enemy := _create_test_enemy()
	var tactical_state := {
		"current_tactic": GameEnums.CombatTactic.AGGRESSIVE,
		"last_position": Vector2(1, 1),
		"target": null
	}
	
	TypeSafeMixin._call_node_method_bool(_tactical_ai, "set_tactical_state", [test_enemy, tactical_state])
	var tracked_state: Dictionary = TypeSafeMixin._call_node_method_dict(_tactical_ai, "get_tactical_state", [test_enemy])
	assert_eq(tracked_state, tactical_state, "Should track tactical states")

# AI Decision Making Tests
func test_ai_decision_making() -> void:
	var test_enemy := _create_test_enemy()
	_reset_signal_data()
	
	TypeSafeMixin._call_node_method_bool(_tactical_ai, "make_decision", [test_enemy])
	
	assert_true(_signal_data.decision_made, "Should emit decision after making decision")
	assert_eq(_signal_data.last_decision_enemy, test_enemy, "Decision should be for correct enemy")
	assert_not_null(_signal_data.last_decision_action, "Should have valid decision action")

# Group Coordination Tests
func test_group_coordination() -> void:
	var test_group := _create_test_group(3)
	_reset_signal_data()
	
	TypeSafeMixin._call_node_method_bool(_tactical_ai, "coordinate_group", [test_group])
	
	assert_true(_signal_data.group_coordination, "Should emit coordination signal")
	assert_eq(_signal_data.last_coordinated_group.size(), test_group.size(), "Should coordinate entire group")
	assert_not_null(_signal_data.last_group_leader, "Should assign group leader")

# Error Handling Tests
func test_invalid_enemy_handling() -> void:
	var result: Dictionary = TypeSafeMixin._call_node_method_dict(_tactical_ai, "make_decision", [null])
	assert_true(result.has("error"), "Should handle null enemy")
	
	var invalid_enemy := Node.new()
	add_child_autofree(invalid_enemy)
	track_test_node(invalid_enemy)
	result = TypeSafeMixin._call_node_method_dict(_tactical_ai, "make_decision", [invalid_enemy])
	assert_true(result.has("error"), "Should handle invalid enemy type")

# Performance Tests
func test_decision_making_performance() -> void:
	var enemies := _create_test_group(10)
	var start_time := Time.get_ticks_msec()
	
	for enemy in enemies:
		TypeSafeMixin._call_node_method_dict(_tactical_ai, "make_decision", [enemy])
	
	var duration := Time.get_ticks_msec() - start_time
	assert_true(duration < TEST_TIMEOUT * 1000, "Should make decisions efficiently")
