extends "res://addons/gut/test.gd"

const TutorialStateMachine := preload("res://StateMachines/TutorialStateMachine.gd")
const FiveParsecsGameState := preload("res://src/data/resources/GameState/GameState.gd")
const GlobalEnums := preload("res://src/core/systems/GlobalEnums.gd")

var tutorial_state_machine: TutorialStateMachine
var game_state: FiveParsecsGameState

func before_each() -> void:
	game_state = FiveParsecsGameState.new()
	tutorial_state_machine = TutorialStateMachine.new(game_state)
	add_child(tutorial_state_machine)

func after_each() -> void:
	if is_instance_valid(tutorial_state_machine):
		tutorial_state_machine.queue_free()
	game_state = null

func test_initial_state() -> void:
	assert_eq(tutorial_state_machine.current_state, TutorialStateMachine.TutorialState.NONE,
		"Initial state should be NONE")
	assert_eq(tutorial_state_machine.current_track, TutorialStateMachine.TutorialTrack.NONE,
		"Initial track should be NONE")
	assert_false(game_state.is_tutorial_active, "Tutorial should not be active initially")

func test_quick_start_tutorial() -> void:
	var state_changes := []
	var completed_tracks := []
	
	tutorial_state_machine.state_changed.connect(
		func(new_state: int): state_changes.append(new_state)
	)
	tutorial_state_machine.tutorial_completed.connect(
		func(track: int): completed_tracks.append(track)
	)
	
	tutorial_state_machine.start_tutorial(TutorialStateMachine.TutorialTrack.QUICK_START)
	
	assert_eq(tutorial_state_machine.current_state, TutorialStateMachine.TutorialState.QUICK_START,
		"Should transition to QUICK_START state")
	assert_eq(tutorial_state_machine.current_track, TutorialStateMachine.TutorialTrack.QUICK_START,
		"Should be on QUICK_START track")
	assert_true(game_state.is_tutorial_active, "Tutorial should be active")
	
	tutorial_state_machine.transition_to(TutorialStateMachine.TutorialState.COMPLETED)
	
	assert_eq(tutorial_state_machine.current_state, TutorialStateMachine.TutorialState.COMPLETED,
		"Should transition to COMPLETED state")
	assert_eq(tutorial_state_machine.current_track, TutorialStateMachine.TutorialTrack.NONE,
		"Track should be NONE after completion")
	assert_false(game_state.is_tutorial_active, "Tutorial should not be active after completion")
	
	assert_eq(state_changes.size(), 2, "Should emit two state changes")
	assert_eq(completed_tracks.size(), 1, "Should emit one track completion")

func test_advanced_tutorial() -> void:
	tutorial_state_machine.start_tutorial(TutorialStateMachine.TutorialTrack.ADVANCED)
	
	assert_eq(tutorial_state_machine.current_state, TutorialStateMachine.TutorialState.ADVANCED,
		"Should transition to ADVANCED state")
	assert_eq(tutorial_state_machine.current_track, TutorialStateMachine.TutorialTrack.ADVANCED,
		"Should be on ADVANCED track")
	assert_true(game_state.is_tutorial_active, "Tutorial should be active")

func test_battle_tutorial() -> void:
	tutorial_state_machine.start_tutorial(TutorialStateMachine.TutorialTrack.BATTLE)
	
	assert_eq(tutorial_state_machine.current_state, TutorialStateMachine.TutorialState.BATTLE_TUTORIAL,
		"Should transition to BATTLE_TUTORIAL state")
	assert_eq(tutorial_state_machine.current_track, TutorialStateMachine.TutorialTrack.BATTLE,
		"Should be on BATTLE track")
	assert_true(game_state.is_tutorial_active, "Tutorial should be active")

func test_invalid_transitions() -> void:
	# Try to complete tutorial without starting one
	tutorial_state_machine.transition_to(TutorialStateMachine.TutorialState.COMPLETED)
	assert_eq(tutorial_state_machine.current_state, TutorialStateMachine.TutorialState.COMPLETED,
		"Should allow transition to COMPLETED")
	assert_eq(tutorial_state_machine.current_track, TutorialStateMachine.TutorialTrack.NONE,
		"Track should remain NONE")
	
	# Try to transition to the same state
	var state_changes := []
	tutorial_state_machine.state_changed.connect(
		func(new_state: int): state_changes.append(new_state)
	)
	
	tutorial_state_machine.transition_to(TutorialStateMachine.TutorialState.COMPLETED)
	assert_eq(state_changes.size(), 0, "Should not emit state change for same state")

func test_cleanup() -> void:
	var initial_memory := OS.get_static_memory_usage()
	
	for i in range(10):
		tutorial_state_machine.start_tutorial(TutorialStateMachine.TutorialTrack.QUICK_START)
		tutorial_state_machine.transition_to(TutorialStateMachine.TutorialState.COMPLETED)
	
	OS.delay_msec(100) # Allow for cleanup
	
	var final_memory := OS.get_static_memory_usage()
	assert_lt(abs(final_memory - initial_memory), 1024 * 1024,
		"Tutorial system memory should be properly cleaned up")

func test_mission_setup() -> void:
	tutorial_state_machine.start_tutorial(TutorialStateMachine.TutorialTrack.QUICK_START)
	
	# Verify mission is set up with correct objectives
	var mission = game_state.get_current_mission()
	assert_not_null(mission, "Mission should be created")
	assert_eq(mission.mission_type, GlobalEnums.MissionType.TUTORIAL,
		"Mission should be tutorial type")
	assert_eq(mission.difficulty, GlobalEnums.DifficultyMode.NORMAL,
		"Mission should be normal difficulty")
	
	var objectives = mission.objectives
	assert_eq(objectives.size(), 1, "Quick start should have one objective")
	assert_eq(objectives[0].type, GlobalEnums.MissionObjective.PATROL,
		"Quick start should have patrol objective")

func test_tutorial_interruption() -> void:
	tutorial_state_machine.start_tutorial(TutorialStateMachine.TutorialTrack.QUICK_START)
	
	# Interrupt with a different tutorial
	tutorial_state_machine.start_tutorial(TutorialStateMachine.TutorialTrack.ADVANCED)
	
	assert_eq(tutorial_state_machine.current_state, TutorialStateMachine.TutorialState.ADVANCED,
		"Should transition to new tutorial state")
	assert_eq(tutorial_state_machine.current_track, TutorialStateMachine.TutorialTrack.ADVANCED,
		"Should be on new tutorial track")