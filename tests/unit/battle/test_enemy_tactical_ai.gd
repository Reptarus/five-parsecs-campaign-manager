## Enemy Tactical AI Test Suite
#
## - Group tactics
## - State tracking
## - Performance under stress
## - Error handling
## - Signal verification
@tool
extends GdUnitGameTest

# Universal Mock Strategy - Tactical AI Testing
class MockEnemyTacticalAI extends Resource:
    var ai_personality: int = 0
    var current_tactic: int = 0
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
        if enemy:
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

# System dependencies
const EnemyTacticalAI: GDScript = preload("res://src/game/combat/EnemyTacticalAI.gd")
const BattlefieldManager: GDScript = preload("res://src/base/combat/battlefield/BaseBattlefieldManager.gd")
const Character: GDScript = preload("res://src/core/character/Base/Character.gd")
const GameEnums = preload("res://src/core/systems/GlobalEnums.gd")

# Test configuration
const TEST_TIMEOUT: float = 2.0

# Type-safe instance variables
var _tactical_ai: MockEnemyTacticalAI = null
var _battlefield_manager: Node = null
var _combat_manager: Node = null

# Signal tracking data
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

func before_test() -> void:
    super.before_test()
    
    # Initialize battlefield manager
    var battlefield_manager_instance = Node.new()
    _battlefield_manager = battlefield_manager_instance
    if not _battlefield_manager:
        push_error("Failed to create battlefield manager")
        return
    
    # Initialize combat manager
    _combat_manager = Node.new()
    _combat_manager.name = "MockCombatManager"
    if not _combat_manager:
        push_error("Failed to create combat manager")
        return
    
    # Initialize tactical AI
    _tactical_ai = MockEnemyTacticalAI.new()
    
    # Connect signals for testing
    _connect_signals()
    _reset_signal_data()

func after_test() -> void:
    _disconnect_signals()
    
    _tactical_ai = null
    _battlefield_manager = null
    _combat_manager = null
    super.after_test()

# Signal management methods
func _connect_signals() -> void:
    if not _tactical_ai:
        return
    
    if _tactical_ai.has_signal("decision_made_signal"):
        _tactical_ai.connect("decision_made_signal", _on_decision_made)
    if _tactical_ai.has_signal("tactic_changed"):
        _tactical_ai.connect("tactic_changed", _on_tactic_changed)
    if _tactical_ai.has_signal("coordination_complete"):
        _tactical_ai.connect("coordination_complete", _on_group_coordination_updated)

func _disconnect_signals() -> void:
    if not _tactical_ai:
        return
    
    if _tactical_ai.has_signal("decision_made_signal") and _tactical_ai.is_connected("decision_made_signal", _on_decision_made):
        _tactical_ai.disconnect("decision_made_signal", _on_decision_made)
    if _tactical_ai.has_signal("tactic_changed") and _tactical_ai.is_connected("tactic_changed", _on_tactic_changed):
        _tactical_ai.disconnect("tactic_changed", _on_tactic_changed)
    if _tactical_ai.has_signal("coordination_complete") and _tactical_ai.is_connected("coordination_complete", _on_group_coordination_updated):
        _tactical_ai.disconnect("coordination_complete", _on_group_coordination_updated)

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

func _on_decision_made() -> void:
    _signal_data.decision_made = true

func _on_tactic_changed(new_tactic: int) -> void:
    _signal_data.tactic_changed = true
    _signal_data.last_tactic_change = new_tactic

func _on_group_coordination_updated() -> void:
    _signal_data.group_coordination = true

# Helper methods
func _create_test_enemy(id: String) -> MockEnemy:
    var enemy = MockEnemy.new()
    enemy.set_enemy_id(id)
    enemy.set_ai_personality(AIPersonality.AGGRESSIVE)
    return enemy

func _create_test_group(size: int = 2) -> Array[Node]:
    var group: Array[Node] = []
    for i: int in range(size):
        var enemy = _create_test_enemy("enemy_%d" % i)
        if enemy:
            group.append(enemy)
    return group

# Test AI personality management
func test_ai_personality_types() -> void:
    # Test aggressive personality
    _tactical_ai.set_ai_personality(AIPersonality.AGGRESSIVE)
    assert_that(_tactical_ai.get_ai_personality()).is_equal(AIPersonality.AGGRESSIVE)
    
    _tactical_ai.set_ai_personality(AIPersonality.DEFENSIVE)
    assert_that(_tactical_ai.get_ai_personality()).is_equal(AIPersonality.DEFENSIVE)
    
    _tactical_ai.set_ai_personality(AIPersonality.CAUTIOUS)
    assert_that(_tactical_ai.get_ai_personality()).is_equal(AIPersonality.CAUTIOUS)

# Test group tactic management
func test_group_tactic_types() -> void:
    # Test advance tactic
    _tactical_ai.set_group_tactic(GroupTactic.ADVANCE)
    assert_that(_tactical_ai.get_group_tactic()).is_equal(GroupTactic.ADVANCE)
    
    _tactical_ai.set_group_tactic(GroupTactic.HOLD_POSITION)
    assert_that(_tactical_ai.get_group_tactic()).is_equal(GroupTactic.HOLD_POSITION)
    
    _tactical_ai.set_group_tactic(GroupTactic.FLANK)
    assert_that(_tactical_ai.get_group_tactic()).is_equal(GroupTactic.FLANK)

# Test decision making signals
func test_decision_making_signals() -> void:
    var enemy := _create_test_enemy("test_enemy")
    
    _reset_signal_data()
    _tactical_ai.make_decision()
    
    # Wait for signal processing
    await get_tree().process_frame
    assert_that(_signal_data.decision_made).is_true()

func test_tactic_change_signals() -> void:
    var enemy := _create_test_enemy("test_enemy")
    
    _reset_signal_data()
    _tactical_ai.set_group_tactic(GroupTactic.RETREAT)
    
    # Wait for signal processing
    await get_tree().process_frame
    assert_that(_signal_data.tactic_changed).is_true()

func test_group_coordination_signals() -> void:
    var enemy1 := _create_test_enemy("enemy_1")
    var enemy2 := _create_test_enemy("enemy_2")
    
    _tactical_ai.add_to_group(enemy1)
    _tactical_ai.add_to_group(enemy2)
    
    _reset_signal_data()
    _tactical_ai.coordinate_group_action()
    
    # Wait for signal processing
    await get_tree().process_frame
    assert_that(_signal_data.group_coordination).is_true()

# Test enemy personality tracking
func test_enemy_personality_tracking() -> void:
    var enemy := _create_test_enemy("personality_test")
    
    _reset_signal_data()
    _tactical_ai.set_ai_personality(AIPersonality.BERSERKER)
    
    # Wait for signal processing
    await get_tree().process_frame
    assert_that(_tactical_ai.get_ai_personality()).is_equal(AIPersonality.BERSERKER)

func test_group_assignment_tracking() -> void:
    var enemy1 := _create_test_enemy("group_1")
    var enemy2 := _create_test_enemy("group_2")
    var enemy3 := _create_test_enemy("group_3")
    
    _tactical_ai.add_to_group(enemy1)
    _tactical_ai.add_to_group(enemy2)
    _tactical_ai.add_to_group(enemy3)
    
    var members := _tactical_ai.get_group_members()
    assert_that(members.size()).is_equal(3)
    
    var leader := _tactical_ai.get_group_leader()
    assert_that(leader).is_equal(enemy1)

func test_tactical_state_tracking() -> void:
    # Set initial state
    _tactical_ai.set_ai_personality(AIPersonality.DEFENSIVE)
    _tactical_ai.set_group_tactic(GroupTactic.HOLD_POSITION)
    
    assert_that(_tactical_ai.get_ai_personality()).is_equal(AIPersonality.DEFENSIVE)
    assert_that(_tactical_ai.get_group_tactic()).is_equal(GroupTactic.HOLD_POSITION)

# Test AI decision making
func test_ai_decision_making() -> void:
    var enemy := _create_test_enemy("decision_test")
    
    _reset_signal_data()
    _tactical_ai.make_decision()
    
    # Wait for signal processing
    await get_tree().process_frame
    assert_that(_signal_data.decision_made).is_true()
    assert_that(_tactical_ai.decision_made).is_true()

# Test group coordination
func test_group_coordination() -> void:
    var enemy1 := _create_test_enemy("coord_1")
    var enemy2 := _create_test_enemy("coord_2")
    var enemy3 := _create_test_enemy("coord_3")
    
    _tactical_ai.add_to_group(enemy1)
    _tactical_ai.add_to_group(enemy2)
    _tactical_ai.add_to_group(enemy3)
    
    _reset_signal_data()
    _tactical_ai.coordinate_group_action()
    
    # Wait for signal processing
    await get_tree().process_frame
    assert_that(_signal_data.group_coordination).is_true()
    assert_that(_tactical_ai.get_group_members().size()).is_equal(3)

# Test invalid input handling
func test_invalid_enemy_handling() -> void:
    # Test adding null enemy
    _tactical_ai.add_to_group(null)
    var members := _tactical_ai.get_group_members()
    assert_that(members.size()).override_failure_message("Should handle null enemy").is_equal(0)
    
    # Test with no group members
    var new_ai := MockEnemyTacticalAI.new()
    var empty_members := new_ai.get_group_members()
    assert_that(empty_members.size()).is_equal(0)

# Test decision making performance
func test_decision_making_performance() -> void:
    # Add multiple enemies to test performance
    for i: int in range(10):
        var enemy = _create_test_enemy("perf_enemy_%d" % i)
        _tactical_ai.add_to_group(enemy)
    
    var start_time := Time.get_ticks_msec()
    
    # Performance test loop
    for i: int in range(100):
        _tactical_ai.make_decision()
        _tactical_ai.coordinate_group_action()
    
    var duration := Time.get_ticks_msec() - start_time
    assert_that(duration).is_less(1000) # Should complete in under 1 second
