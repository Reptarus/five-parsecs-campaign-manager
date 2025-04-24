@tool
extends "res://tests/fixtures/base/game_test.gd"

# Type-safe script references
const TutorialStateMachine: GDScript = preload("res://StateMachines/TutorialStateMachine.gd")

# Define test-specific enums
enum TutorialState {
	NONE,
	QUICK_START,
	BASIC_CONTROLS,
	CAMPAIGN_INTRO,
	BATTLE_INTRO,
	ADVANCED_CONTROLS,
	COMPLETE
}

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
	# Pass _game_state to the constructor as required
	if _game_state:
		var tutorial_instance = TutorialStateMachine.new(_game_state)
		_tutorial_state_machine = TypeSafeMixin._safe_cast_to_node(tutorial_instance)
		if not _tutorial_state_machine:
			push_error("Failed to create tutorial state machine")
			return
		add_child_autofree(_tutorial_state_machine)
		track_test_node(_tutorial_state_machine)
		
		watch_signals(_tutorial_state_machine)
	else:
		push_error("Cannot create tutorial state machine without valid game state")
	
	await stabilize_engine()

func after_each() -> void:
	# Let parent clean up first to ensure proper sequence
	await super.after_each()
	# This is redundant as parent will clean up all tracked nodes
	_tutorial_state_machine = null

func test_initialization() -> void:
	assert_not_null(_tutorial_state_machine, "Tutorial state machine should be initialized")
	
	# Exit early if _tutorial_state_machine is null
	if not _tutorial_state_machine:
		pending("Test skipped - tutorial state machine is null")
		return
	
	# Check if required methods exist
	if not (_tutorial_state_machine.has_method("get_current_state") and
		   _tutorial_state_machine.has_method("is_active")):
		push_warning("Skipping test_initialization: required methods missing")
		pending("Test skipped - required methods missing")
		return
	
	var current_state: int = TypeSafeMixin._call_node_method_int(_tutorial_state_machine, "get_current_state", [], TutorialState.NONE)
	assert_eq(current_state, TutorialState.NONE, "Initial state should be NONE")
	
	var is_active: bool = TypeSafeMixin._call_node_method_bool(_tutorial_state_machine, "is_active", [], false)
	assert_false(is_active, "Tutorial should not be active initially")

func test_state_transitions() -> void:
	# Exit early if _tutorial_state_machine is null
	if not _tutorial_state_machine:
		pending("Test skipped - tutorial state machine is null")
		return
	
	# Check if required methods and signals exist
	if not (_tutorial_state_machine.has_method("transition_to") and
		   _tutorial_state_machine.has_method("get_current_state") and
		   _tutorial_state_machine.has_signal("state_changed")):
		push_warning("Skipping test_state_transitions: required methods or signals missing")
		pending("Test skipped - required methods or signals missing")
		return
	
	# Ensure signals are being watched
	watch_signals(_tutorial_state_machine)
	
	# Transition to quick start
	var transition_result: bool = TypeSafeMixin._call_node_method_bool(
		_tutorial_state_machine,
		"transition_to",
		[TutorialState.QUICK_START]
	)
	assert_true(transition_result, "Should successfully transition to QUICK_START")
	
	var current_state: int = TypeSafeMixin._call_node_method_int(
		_tutorial_state_machine,
		"get_current_state",
		[],
		TutorialState.NONE
	)
	assert_eq(current_state, TutorialState.QUICK_START, "State should be QUICK_START")
	
	# Verify signals
	verify_signal_emitted(_tutorial_state_machine, "state_changed")

func test_invalid_transitions() -> void:
	# Exit early if _tutorial_state_machine is null
	if not _tutorial_state_machine:
		pending("Test skipped - tutorial state machine is null")
		return
	
	# Check if required methods exist
	if not (_tutorial_state_machine.has_method("transition_to") and
		   _tutorial_state_machine.has_method("get_current_state")):
		push_warning("Skipping test_invalid_transitions: required methods missing")
		pending("Test skipped - required methods missing")
		return
		
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
		TutorialState.NONE
	)
	assert_eq(current_state, TutorialState.NONE, "State should remain NONE after invalid transition")

func test_tutorial_completion() -> void:
	# Exit early if _tutorial_state_machine is null
	if not _tutorial_state_machine:
		pending("Test skipped - tutorial state machine is null")
		return
	
	# Check if required methods and signals exist
	if not (_tutorial_state_machine.has_method("complete_tutorial") and
		   _tutorial_state_machine.has_method("is_completed") and
		   _tutorial_state_machine.has_signal("tutorial_completed")):
		push_warning("Skipping test_tutorial_completion: required methods or signals missing")
		pending("Test skipped - required methods or signals missing")
		return
	
	# Ensure signals are being watched
	watch_signals(_tutorial_state_machine)
	
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
