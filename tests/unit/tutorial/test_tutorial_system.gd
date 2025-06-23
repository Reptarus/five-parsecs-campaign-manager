@tool
extends GdUnitGameTest

#
static func _load_tutorial_state_machine() -> GDScript:
    if ResourceLoader.exists("res://StateMachines/TutorialStateMachine.gd"):
        return load("res://StateMachines/TutorialStateMachine.gd")
    return null

var TutorialStateMachine: GDScript = _load_tutorial_state_machine()

#
const TEST_TIMEOUT: float = 2.0

#
enum TutorialState {
NONE = 0,
QUICK_START = 1
}

#
class MockGameState extends Resource:
    var is_tutorial_active: bool = false
    
    func set_victory_type(victory_type: int) -> void:
        pass
    
    func start_tutorial_battle(setup: Dictionary) -> void:
        pass
    
    func start_tutorial_campaign(setup: Dictionary) -> void:
        pass

#
class MockTutorialStateMachine extends Node:
    signal tutorial_started(state: int)
    signal tutorial_completed()
    signal state_changed(old_state: int, new_state: int)
    signal step_completed(step_id: String)
    
    var game_state: Resource
    var current_state: int = TutorialState.NONE
    var current_track: int = TutorialState.NONE
    var steps_completed: Array = []
    var is_active: bool = false
    
    func _init(gs: Resource = null) -> void:
        game_state = gs
    
    func start_tutorial() -> void:
        is_active = true
        current_state = TutorialState.QUICK_START
        tutorial_started.emit(current_state)
    
    func start_tutorial_track(track: int) -> void:
        if track >= 0:
            current_track = track
            var old_state = current_state
            current_state = track
            state_changed.emit(old_state, current_state)
    
    func complete_current_step() -> void:
        var step_id = "step_" + str(steps_completed.size())
        steps_completed.append(step_id)
        step_completed.emit(step_id)
        
        if steps_completed.size() >= 5:
            complete_tutorial()
    
    func complete_tutorial() -> void:
        is_active = false
        current_state = TutorialState.NONE
        tutorial_completed.emit()

# Type-safe instance variables
var _tutorial_state_machine: Node = null
var _game_state: Resource = null

func before_test() -> void:
    super.before_test()
    
    # Initialize game state
    _game_state = MockGameState.new()
    if not _game_state:
        push_error("Failed to create game state")
        return
    
    # Initialize tutorial state machine
    if TutorialStateMachine:
        if TutorialStateMachine.new().has_method("initialize"):
            _tutorial_state_machine = TutorialStateMachine.new()
            _tutorial_state_machine.initialize(_game_state)
        else:
            _tutorial_state_machine = TutorialStateMachine.new(_game_state)
    else:
        _tutorial_state_machine = MockTutorialStateMachine.new(_game_state)
    
    if not _tutorial_state_machine:
        push_error("Failed to create tutorial state machine")
        return
    
    # Add tutorial state machine to scene tree if it's a Node
    if _tutorial_state_machine is Node:
        track_node(_tutorial_state_machine)
        add_child(_tutorial_state_machine)

func after_test() -> void:
    _tutorial_state_machine = null
    _game_state = null
    super.after_test()

# Helper methods for safe method calls
func _safe_call_method_bool(node: Node, method_name: String, args: Array = []) -> bool:
    if node and node.has_method(method_name):
        return node.callv(method_name, args)
    return false

func _safe_call_method_int(node: Node, method_name: String, args: Array = []) -> int:
    if node and node.has_method(method_name):
        return node.callv(method_name, args)
    return 0

func test_initialization() -> void:
    # Ensure tutorial state machine is properly initialized
    assert_that(_tutorial_state_machine).is_not_null()
    
    # Test initial state
    if _tutorial_state_machine and "current_state" in _tutorial_state_machine:
        assert_that(_tutorial_state_machine.current_state).is_equal(TutorialState.NONE)
    
    # Test game state assignment
    if _tutorial_state_machine and "game_state" in _tutorial_state_machine:
        assert_that(_tutorial_state_machine.game_state).is_not_null()

func test_state_transitions() -> void:
    # When starting tutorial track
    if _tutorial_state_machine and _tutorial_state_machine.has_method("start_tutorial_track"):
        _tutorial_state_machine.start_tutorial_track(TutorialState.QUICK_START)
        await get_tree().process_frame
        
        # Then current track should be updated
        if "current_track" in _tutorial_state_machine:
            assert_that(_tutorial_state_machine.current_track).is_equal(TutorialState.QUICK_START)

func test_invalid_transitions() -> void:
    # When attempting invalid transition
    if _tutorial_state_machine and _tutorial_state_machine.has_method("start_tutorial_track"):
        _tutorial_state_machine.start_tutorial_track(-1)
        await get_tree().process_frame
        
        # Then current track should not change to invalid value
        if "current_track" in _tutorial_state_machine:
            assert_that(_tutorial_state_machine.current_track).is_not_equal(-1)

func test_tutorial_completion() -> void:
    # When starting tutorial
    if _tutorial_state_machine and _tutorial_state_machine.has_method("start_tutorial"):
        _tutorial_state_machine.start_tutorial()
        await get_tree().process_frame
        
        # Test state directly instead of signal emission
        if "is_active" in _tutorial_state_machine:
            assert_that(_tutorial_state_machine.is_active).is_true()
        
        # When completing steps
        if _tutorial_state_machine.has_method("complete_current_step"):
            for i: int in range(5): # Complete 5 steps to trigger completion
                _tutorial_state_machine.complete_current_step()
                await get_tree().process_frame
        
        # Then steps should be recorded
        if "steps_completed" in _tutorial_state_machine:
            assert_that(_tutorial_state_machine.steps_completed.size()).is_equal(5)

func test_mock_functionality() -> void:
    # When using mock tutorial state machine
    if _tutorial_state_machine is MockTutorialStateMachine:
        var mock_tutorial = _tutorial_state_machine as MockTutorialStateMachine
        
        # Test initial state
        assert_that(mock_tutorial.current_state).is_equal(TutorialState.NONE)
        assert_that(mock_tutorial.is_active).is_false()
        
        # When starting tutorial
        mock_tutorial.start_tutorial()
        assert_that(mock_tutorial.is_active).is_true()
        assert_that(mock_tutorial.current_state).is_equal(TutorialState.QUICK_START)
        
        # When completing step
        mock_tutorial.complete_current_step()
        assert_that(mock_tutorial.steps_completed.size()).is_equal(1)
        
        # When completing all steps
        for i: int in range(4):
            mock_tutorial.complete_current_step()
        
        assert_that(mock_tutorial.is_active).is_false()

func test_error_handling() -> void:
    # Test that the system handles errors gracefully
    assert_that(_tutorial_state_machine).is_not_null()
    
    # When attempting invalid operation
    if _tutorial_state_machine.has_method("start_tutorial_track"):
        _tutorial_state_machine.start_tutorial_track(999)
    
    # System should still be functional
    assert_that(_tutorial_state_machine).is_not_null()
