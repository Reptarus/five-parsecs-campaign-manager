@tool
extends "res://tests/test_base.gd"

const TutorialStateMachine := preload("res://StateMachines/TutorialStateMachine.gd")
const TestHelper := preload("res://tests/fixtures/test_helper.gd")

var tutorial_state_machine: Node
var game_state: Node

func before_each() -> void:
	super.before_each()
	game_state = TestHelper.setup_test_game_state()
	tutorial_state_machine = TutorialStateMachine.new(game_state)
	add_child(tutorial_state_machine)

func after_each() -> void:
	super.after_each()
	tutorial_state_machine = null
	game_state = null

func test_initial_state() -> void:
	assert_not_null(tutorial_state_machine, "Tutorial state machine should be initialized")
	assert_eq(tutorial_state_machine.current_state, TutorialStateMachine.TutorialState.NONE,
		"Initial state should be NONE")

func test_state_transitions() -> void:
	tutorial_state_machine.transition_to(TutorialStateMachine.TutorialState.QUICK_START)
	assert_eq(tutorial_state_machine.current_state, TutorialStateMachine.TutorialState.QUICK_START,
		"State should transition to QUICK_START")