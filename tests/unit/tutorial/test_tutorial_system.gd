@tool
extends "res://tests/fixtures/base/game_test.gd"

# Type-safe script references
const TutorialStateMachine: GDScript = preload("res://StateMachines/TutorialStateMachine.gd")

# Type-safe constants
const TEST_TIMEOUT: float = 2.0

# Type-safe instance variables
var _tutorial_state_machine: Node = null

func before_each() -> void:
	await super.before_each()
	
	# Initialize game state
	_game_state = create_test_game_state()
	if not _game_state:
		push_error("Failed to create game state")
		return
	add_child_autofree(_game_state)
	track_test_node(_game_state)
	
	# Initialize tutorial state machine
	var tutorial_instance: Node = TutorialStateMachine.new()
	_tutorial_state_machine = TypeSafeMixin._safe_cast_to_node(tutorial_instance)
	if not _tutorial_state_machine:
		push_error("Failed to create tutorial state machine")
		return
	TypeSafeMixin._call_node_method_bool(_tutorial_state_machine, "initialize", [_game_state])
	add_child_autofree(_tutorial_state_machine)
	track_test_node(_tutorial_state_machine)
	
	watch_signals(_tutorial_state_machine)
	await stabilize_engine()

func after_each() -> void:
	_tutorial_state_machine = null
	await super.after_each()

func test_initialization() -> void:
	assert_not_null(_tutorial_state_machine, "Tutorial state machine should be initialized")
	
	var current_state: int = TypeSafeMixin._call_node_method_int(_tutorial_state_machine, "get_current_state", [], GameEnums.TutorialState.NONE)
	assert_eq(current_state, GameEnums.TutorialState.NONE, "Initial state should be NONE")
	
	var is_active: bool = TypeSafeMixin._call_node_method_bool(_tutorial_state_machine, "is_active", [], false)
	assert_false(is_active, "Tutorial should not be active initially")

func test_state_transitions() -> void:
	# Transition to quick start
	var transition_result: bool = TypeSafeMixin._call_node_method_bool(
		_tutorial_state_machine,
		"transition_to",
		[GameEnums.TutorialState.QUICK_START]
	)
	assert_true(transition_result, "Should successfully transition to QUICK_START")
	
	var current_state: int = TypeSafeMixin._call_node_method_int(
		_tutorial_state_machine,
		"get_current_state",
		[],
		GameEnums.TutorialState.NONE
	)
	assert_eq(current_state, GameEnums.TutorialState.QUICK_START, "State should be QUICK_START")
	
	# Verify signals
	verify_signal_emitted(_tutorial_state_machine, "state_changed")

func test_invalid_transitions() -> void:
	# Try to transition to invalid state
	var invalid_transition: bool = TypeSafeMixin._call_node_method_bool(
		_tutorial_state_machine,
		"transition_to",
		[-1] # Invalid state
	)
	assert_false(invalid_transition, "Should reject invalid state transition")
	
	var current_state: int = TypeSafeMixin._call_node_method_int(
		_tutorial_state_machine,
		"get_current_state",
		[],
		GameEnums.TutorialState.NONE
	)
	assert_eq(current_state, GameEnums.TutorialState.NONE, "State should remain NONE after invalid transition")

func test_tutorial_completion() -> void:
	# Complete tutorial
	var completion_result: bool = TypeSafeMixin._call_node_method_bool(
		_tutorial_state_machine,
		"complete_tutorial",
		[]
	)
	assert_true(completion_result, "Should successfully complete tutorial")
	
	var is_completed: bool = TypeSafeMixin._call_node_method_bool(
		_tutorial_state_machine,
		"is_completed",
		[],
		false
	)
	assert_true(is_completed, "Tutorial should be marked as completed")
	
	# Verify signals
	verify_signal_emitted(_tutorial_state_machine, "tutorial_completed")
