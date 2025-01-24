@tool
extends "res://tests/fixtures/game_test.gd"

const TutorialStateMachine := preload("res://StateMachines/TutorialStateMachine.gd")

var tutorial_state_machine: TutorialStateMachine
var game_state: GameState

func before_each() -> void:
	super.before_each()
	game_state = create_test_game_state()
	add_child(game_state)
	
	tutorial_state_machine = TutorialStateMachine.new(game_state)
	add_child(tutorial_state_machine)
	track_test_node(tutorial_state_machine)

func after_each() -> void:
	super.after_each()

func test_initial_state() -> void:
	assert_not_null(tutorial_state_machine, "Tutorial state machine should be initialized")
	assert_eq(tutorial_state_machine.current_state, TutorialStateMachine.TutorialState.NONE,
		"Initial state should be NONE")

func test_state_transitions() -> void:
	tutorial_state_machine.transition_to(TutorialStateMachine.TutorialState.QUICK_START)
	assert_eq(tutorial_state_machine.current_state, TutorialStateMachine.TutorialState.QUICK_START,
		"State should transition to QUICK_START")
