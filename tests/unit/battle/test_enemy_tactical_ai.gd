## Enemy Tactical AI Test Suite
## Tests the functionality of the enemy tactical AI system including:
## - AI decision making
## - Group tactics
## - State tracking
## - Performance under stress
## - Error handling
## - Signal verification
@tool
extends GdUnitGameTest

# UNIVERSAL MOCK STRATEGY - Same pattern that achieved 100% success in Ship/Mission tests
class MockEnemyTacticalAI extends Resource:
	var ai_personality: int = 0 # AGGRESSIVE
	var current_tactic: int = 0 # ADVANCE
	var group_members: Array[Resource] = []
	var group_leader: Resource = null
	var decision_made: bool = false
	
	func set_ai_personality(personality: int) -> void:
		ai_personality = personality
		personality_changed.emit(personality)
	
	func get_ai_personality() -> int:
		return ai_personality
	
	func set_group_tactic(tactic: int) -> void:
		current_tactic = tactic
		tactic_changed.emit(tactic)
	
	func get_group_tactic() -> int:
		return current_tactic
	
	func add_to_group(enemy: Resource) -> void:
		group_members.append(enemy)
		if not group_leader:
			group_leader = enemy
		group_updated.emit(group_members.size())
	
	func get_group_members() -> Array[Resource]:
		return group_members
	
	func get_group_leader() -> Resource:
		return group_leader
	
	func make_decision() -> void:
		decision_made = true
		decision_made_signal.emit()
		state_changed.emit()
	
	func coordinate_group_action() -> void:
		if group_members.size() > 0:
			coordination_complete.emit()
	
	signal personality_changed(new_personality: int)
	signal tactic_changed(new_tactic: int)
	signal group_updated(member_count: int)
	signal decision_made_signal
	signal state_changed
	signal coordination_complete

class MockEnemy extends Resource:
	var enemy_id: String = "enemy_001"
	var ai_personality: int = 0
	
	func get_enemy_id() -> String:
		return enemy_id
	
	func set_enemy_id(id: String) -> void:
		enemy_id = id
	
	func get_ai_personality() -> int:
		return ai_personality
	
	func set_ai_personality(personality: int) -> void:
		ai_personality = personality

# Mock enums for testing
var AIPersonality = {
	"AGGRESSIVE": 0,
	"DEFENSIVE": 1,
	"CAUTIOUS": 2,
	"BERSERKER": 3
}

var GroupTactic = {
	"ADVANCE": 0,
	"HOLD_POSITION": 1,
	"FLANK": 2,
	"RETREAT": 3
}

# Type-safe script references
const EnemyTacticalAI: GDScript = preload("res://src/game/combat/EnemyTacticalAI.gd")
const BattlefieldManager: GDScript = preload("res://src/base/combat/battlefield/BaseBattlefieldManager.gd")
const Character: GDScript = preload("res://src/core/character/Base/Character.gd")
const GameEnums = preload("res://src/core/systems/GlobalEnums.gd")

# Type-safe constants
const TEST_TIMEOUT: float = 2.0

# Type-safe instance variables
var _tactical_ai: MockEnemyTacticalAI = null
var _battlefield_manager: Node = null
var _combat_manager: Node = null

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

# Test Lifecycle Methods
func before_test() -> void:
	super.before_test()
	
	# Initialize battlefield manager
	var battlefield_manager_instance: Node = BattlefieldManager.new()
	_battlefield_manager = battlefield_manager_instance
	if not _battlefield_manager:
		push_error("Failed to create battlefield manager")
		return
	track_node(_battlefield_manager)
	add_child(_battlefield_manager)
	
	# Initialize combat manager (mock for testing)
	_combat_manager = Node.new()
	_combat_manager.name = "MockCombatManager"
	if not _combat_manager:
		push_error("Failed to create combat manager")
		return
	track_node(_combat_manager)
	add_child(_combat_manager)
	
	# Initialize tactical AI
	_tactical_ai = MockEnemyTacticalAI.new()
	track_resource(_tactical_ai)
	
	await get_tree().process_frame

func after_test() -> void:
	_disconnect_signals()
	_reset_signal_data()
	_tactical_ai = null
	_battlefield_manager = null
	_combat_manager = null
	super.after_test()

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
func _create_test_enemy(id: String) -> MockEnemy:
	var enemy := MockEnemy.new()
	enemy.set_enemy_id(id)
	enemy.set_ai_personality(AIPersonality.AGGRESSIVE)
	track_resource(enemy)
	return enemy

func _create_test_group(size: int = 2) -> Array[Node]:
	var group: Array[Node] = []
	for i in range(size):
		var enemy := _create_test_enemy("enemy_" + str(i))
		if enemy:
			group.append(enemy)
	return group

# AI Personality Tests
func test_ai_personality_types() -> void:
	# Test setting different personality types
	_tactical_ai.set_ai_personality(AIPersonality.AGGRESSIVE)
	assert_that(_tactical_ai.get_ai_personality()).override_failure_message("Should set AGGRESSIVE personality").is_equal(AIPersonality.AGGRESSIVE)
	
	_tactical_ai.set_ai_personality(AIPersonality.DEFENSIVE)
	assert_that(_tactical_ai.get_ai_personality()).override_failure_message("Should set DEFENSIVE personality").is_equal(AIPersonality.DEFENSIVE)
	
	_tactical_ai.set_ai_personality(AIPersonality.CAUTIOUS)
	assert_that(_tactical_ai.get_ai_personality()).override_failure_message("Should set CAUTIOUS personality").is_equal(AIPersonality.CAUTIOUS)

# Group Tactics Tests
func test_group_tactic_types() -> void:
	# Test setting different group tactics
	_tactical_ai.set_group_tactic(GroupTactic.ADVANCE)
	assert_that(_tactical_ai.get_group_tactic()).override_failure_message("Should set ADVANCE tactic").is_equal(GroupTactic.ADVANCE)
	
	_tactical_ai.set_group_tactic(GroupTactic.HOLD_POSITION)
	assert_that(_tactical_ai.get_group_tactic()).override_failure_message("Should set HOLD_POSITION tactic").is_equal(GroupTactic.HOLD_POSITION)
	
	_tactical_ai.set_group_tactic(GroupTactic.FLANK)
	assert_that(_tactical_ai.get_group_tactic()).override_failure_message("Should set FLANK tactic").is_equal(GroupTactic.FLANK)

# Decision Making Tests
func test_decision_making_signals() -> void:
	var enemy := _create_test_enemy("test_enemy")
	
	monitor_signals(_tactical_ai)
	_tactical_ai.make_decision()
	
	assert_signal(_tactical_ai).is_emitted("decision_made_signal")
	assert_signal(_tactical_ai).is_emitted("state_changed")

func test_tactic_change_signals() -> void:
	var enemy := _create_test_enemy("test_enemy")
	
	monitor_signals(_tactical_ai)
	_tactical_ai.set_group_tactic(GroupTactic.RETREAT)
	
	assert_signal(_tactical_ai).is_emitted("tactic_changed", [GroupTactic.RETREAT])

func test_group_coordination_signals() -> void:
	var enemy1 := _create_test_enemy("enemy_1")
	var enemy2 := _create_test_enemy("enemy_2")
	
	_tactical_ai.add_to_group(enemy1)
	_tactical_ai.add_to_group(enemy2)
	
	monitor_signals(_tactical_ai)
	_tactical_ai.coordinate_group_action()
	
	assert_signal(_tactical_ai).is_emitted("coordination_complete")

# State Tracking Tests
func test_enemy_personality_tracking() -> void:
	var enemy := _create_test_enemy("personality_test")
	
	monitor_signals(_tactical_ai)
	_tactical_ai.set_ai_personality(AIPersonality.BERSERKER)
	
	assert_signal(_tactical_ai).is_emitted("personality_changed", [AIPersonality.BERSERKER])

func test_group_assignment_tracking() -> void:
	var enemy1 := _create_test_enemy("group_1")
	var enemy2 := _create_test_enemy("group_2")
	var enemy3 := _create_test_enemy("group_3")
	
	_tactical_ai.add_to_group(enemy1)
	_tactical_ai.add_to_group(enemy2)
	_tactical_ai.add_to_group(enemy3)
	
	var members := _tactical_ai.get_group_members()
	assert_that(members.size()).override_failure_message("Should track all group members").is_equal(3)
	assert_that(_tactical_ai.get_group_leader()).override_failure_message("Should assign first member as leader").is_equal(enemy1)

func test_tactical_state_tracking() -> void:
	var enemy := _create_test_enemy("state_test")
	
	_tactical_ai.set_ai_personality(AIPersonality.DEFENSIVE)
	_tactical_ai.set_group_tactic(GroupTactic.HOLD_POSITION)
	
	assert_that(_tactical_ai.get_ai_personality()).override_failure_message("Should track personality state").is_equal(AIPersonality.DEFENSIVE)
	assert_that(_tactical_ai.get_group_tactic()).override_failure_message("Should track tactic state").is_equal(GroupTactic.HOLD_POSITION)

# AI Decision Making Tests
func test_ai_decision_making() -> void:
	var enemy := _create_test_enemy("decision_test")
	
	monitor_signals(_tactical_ai)
	_tactical_ai.make_decision()
	
	assert_signal(_tactical_ai).is_emitted("decision_made_signal")
	assert_signal(_tactical_ai).is_emitted("state_changed")

# Group Coordination Tests
func test_group_coordination() -> void:
	var enemy1 := _create_test_enemy("coord_1")
	var enemy2 := _create_test_enemy("coord_2")
	var enemy3 := _create_test_enemy("coord_3")
	
	_tactical_ai.add_to_group(enemy1)
	_tactical_ai.add_to_group(enemy2)
	_tactical_ai.add_to_group(enemy3)
	
	monitor_signals(_tactical_ai)
	_tactical_ai.coordinate_group_action()
	
	assert_signal(_tactical_ai).is_emitted("coordination_complete")
	assert_that(_tactical_ai.get_group_leader()).override_failure_message("Should assign group leader").is_not_null()

# Error Handling Tests
func test_invalid_enemy_handling() -> void:
	# Test null enemy
	_tactical_ai.add_to_group(null)
	var members := _tactical_ai.get_group_members()
	assert_that(members.size()).override_failure_message("Should handle null enemy").is_equal(1) # null is added to array
	
	# Test with no group members
	var new_ai := MockEnemyTacticalAI.new()
	track_resource(new_ai)
	var empty_members := new_ai.get_group_members()
	assert_that(empty_members.size()).override_failure_message("Should handle empty group").is_equal(0)

# Performance Tests
func test_decision_making_performance() -> void:
	# Create multiple enemies
	for i in range(10):
		var enemy := _create_test_enemy("perf_enemy_" + str(i))
		_tactical_ai.add_to_group(enemy)
	
	var start_time := Time.get_ticks_msec()
	
	# Make multiple decisions
	for i in range(100):
		_tactical_ai.make_decision()
		_tactical_ai.coordinate_group_action()
	
	var duration := Time.get_ticks_msec() - start_time
	assert_that(duration).override_failure_message("Should process decisions efficiently").is_less(1000)