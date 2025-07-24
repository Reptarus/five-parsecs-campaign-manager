@tool
extends GdUnitGameTest

## FPCM_BattleManager Comprehensive Test Suite
##
## Tests the enterprise-grade battle manager for:
## - FSM state transitions validation
## - Battle initialization and cleanup
## - Signal emission verification
## - Error handling and recovery
## - Performance requirements (60 FPS target)

# Test subject
const FPCM_BattleManager: GDScript = preload("res://src/core/battle/FPCM_BattleManager.gd")
const FPCM_BattleState: GDScript = preload("res://src/core/battle/FPCM_BattleState.gd")

# Type-safe instance variables
var battle_manager: FPCM_BattleManager.new() = null
var test_mission_data: Resource = null
var test_crew_members: Array[Resource] = []
var test_enemy_forces: Array[Resource] = []

# Signal tracking
var phase_changed_signals: Array[Dictionary] = []
var battle_completed_signals: Array[Dictionary] = []
var error_signals: Array[Dictionary] = []

# Performance tracking
var performance_start_time: float = 0.0

func before_test() -> void:
	super.before_test()
	await get_tree().process_frame
	
	# Initialize battle manager
	battle_manager = FPCM_BattleManager.new()
	track_node(battle_manager)
	
	# Set up signal tracking
	_setup_signal_tracking()
	
	# Create test data
	_create_test_data()
	
	# Clear signal history
	phase_changed_signals.clear()
	battle_completed_signals.clear()
	error_signals.clear()

func after_test() -> void:
	# Cleanup
	if battle_manager:
		battle_manager.emergency_reset()
	
	battle_manager = null
	test_mission_data = null
	test_crew_members.clear()
	test_enemy_forces.clear()
	
	super.after_test()

## BASIC FUNCTIONALITY TESTS

func test_battle_manager_initialization() -> void:
	assert_that(battle_manager).is_not_null()
	assert_that(battle_manager.current_phase).is_equal(FPCM_BattleManager.BattlePhase.NONE)
	assert_that(battle_manager.is_active).is_false()
	assert_that(battle_manager.battle_state).is_not_null()

func test_battle_initialization_success() -> void:
	var success: bool = battle_manager.initialize_battle(test_mission_data, test_crew_members, test_enemy_forces)
	
	assert_that(success).is_true()
	assert_that(battle_manager.is_active).is_true()
	assert_that(battle_manager.current_phase).is_equal(FPCM_BattleManager.BattlePhase.PRE_BATTLE)
	assert_that(battle_manager.battle_state).is_not_null()
	assert_that(battle_manager.battle_state.crew_members.size()).is_equal(3)
	assert_that(battle_manager.battle_state.enemy_forces.size()).is_equal(2)

func test_battle_initialization_prevents_double_init() -> void:
	# Initialize first battle
	battle_manager.initialize_battle(test_mission_data, test_crew_members, test_enemy_forces)
	
	# Attempt second initialization should fail
	var second_success: bool = battle_manager.initialize_battle(test_mission_data, test_crew_members, test_enemy_forces)
	
	assert_that(second_success).is_false()
	assert_that(error_signals.size()).is_greater(0)
	assert_that(error_signals[0].error_code).is_equal("BATTLE_ALREADY_ACTIVE")

## FSM STATE TRANSITION TESTS

func test_valid_phase_transitions() -> void:
	battle_manager.initialize_battle(test_mission_data, test_crew_members, test_enemy_forces)
	
	# PRE_BATTLE -> TACTICAL_BATTLE
	var success1: bool = battle_manager.transition_to_phase(FPCM_BattleManager.BattlePhase.TACTICAL_BATTLE)
	assert_that(success1).is_true()
	assert_that(battle_manager.current_phase).is_equal(FPCM_BattleManager.BattlePhase.TACTICAL_BATTLE)
	
	# TACTICAL_BATTLE -> BATTLE_RESOLUTION
	var success2: bool = battle_manager.transition_to_phase(FPCM_BattleManager.BattlePhase.BATTLE_RESOLUTION)
	assert_that(success2).is_true()
	assert_that(battle_manager.current_phase).is_equal(FPCM_BattleManager.BattlePhase.BATTLE_RESOLUTION)
	
	# BATTLE_RESOLUTION -> POST_BATTLE
	var success3: bool = battle_manager.transition_to_phase(FPCM_BattleManager.BattlePhase.POST_BATTLE)
	assert_that(success3).is_true()
	assert_that(battle_manager.current_phase).is_equal(FPCM_BattleManager.BattlePhase.POST_BATTLE)
	
	# POST_BATTLE -> BATTLE_COMPLETE
	var success4: bool = battle_manager.transition_to_phase(FPCM_BattleManager.BattlePhase.BATTLE_COMPLETE)
	assert_that(success4).is_true()
	assert_that(battle_manager.current_phase).is_equal(FPCM_BattleManager.BattlePhase.BATTLE_COMPLETE)

func test_invalid_phase_transitions() -> void:
	battle_manager.initialize_battle(test_mission_data, test_crew_members, test_enemy_forces)
	
	# PRE_BATTLE -> POST_BATTLE (invalid skip)
	var success: bool = battle_manager.transition_to_phase(FPCM_BattleManager.BattlePhase.POST_BATTLE)
	
	assert_that(success).is_false()
	assert_that(error_signals.size()).is_greater(0)
	assert_that(error_signals.back().error_code).is_equal("INVALID_TRANSITION")
	assert_that(battle_manager.current_phase).is_equal(FPCM_BattleManager.BattlePhase.PRE_BATTLE) # Should remain unchanged

func test_phase_auto_advance() -> void:
	battle_manager.initialize_battle(test_mission_data, test_crew_members, test_enemy_forces)
	battle_manager.auto_advance = true
	
	var initial_phase = battle_manager.current_phase
	var success: bool = battle_manager.advance_phase()
	
	assert_that(success).is_true()
	assert_that(battle_manager.current_phase).is_not_equal(initial_phase)

func test_complete_battle_flow() -> void:
	# Full battle flow using advance_phase()
	battle_manager.initialize_battle(test_mission_data, test_crew_members, test_enemy_forces)
	
	# Track all phases
	var phases_visited: Array[FPCM_BattleManager.BattlePhase] = [battle_manager.current_phase]
	
	while battle_manager.current_phase != FPCM_BattleManager.BattlePhase.NONE and battle_manager.is_active:
		var success: bool = battle_manager.advance_phase()
		if success:
			phases_visited.append(battle_manager.current_phase)
		else:
			break
	
	# Verify complete flow
	assert_that(phases_visited.size()).is_greater_equal(5) # At least 5 phases
	assert_that(phases_visited[0]).is_equal(FPCM_BattleManager.BattlePhase.PRE_BATTLE)
	assert_that(phases_visited.back()).is_equal(FPCM_BattleManager.BattlePhase.NONE)
	assert_that(battle_manager.is_active).is_false()

## SIGNAL EMISSION TESTS

func test_phase_changed_signal_emission() -> void:
	battle_manager.initialize_battle(test_mission_data, test_crew_members, test_enemy_forces)
	
	var initial_count = phase_changed_signals.size()
	battle_manager.transition_to_phase(FPCM_BattleManager.BattlePhase.BATTLE_RESOLUTION)
	
	assert_that(phase_changed_signals.size()).is_equal(initial_count + 1)
	var signal_data = phase_changed_signals.back()
	assert_that(signal_data.old_phase).is_equal(FPCM_BattleManager.BattlePhase.PRE_BATTLE)
	assert_that(signal_data.new_phase).is_equal(FPCM_BattleManager.BattlePhase.BATTLE_RESOLUTION)

func test_battle_completion_signal() -> void:
	# Complete full battle
	battle_manager.initialize_battle(test_mission_data, test_crew_members, test_enemy_forces)
	_advance_to_completion()
	
	assert_that(battle_completed_signals.size()).is_greater(0)
	var completion_data = battle_completed_signals.back()
	assert_that(completion_data.result).is_not_null()

func test_ui_transition_signals() -> void:
	var ui_transitions: Array[Dictionary] = []
	battle_manager.ui_transition_requested.connect(func(target_ui: String, data: Dictionary): ui_transitions.append({"ui": target_ui, "data": data}))
	
	battle_manager.initialize_battle(test_mission_data, test_crew_members, test_enemy_forces)
	battle_manager.transition_to_phase(FPCM_BattleManager.BattlePhase.TACTICAL_BATTLE)
	
	assert_that(ui_transitions.size()).is_greater(0)
	assert_that(ui_transitions.any(func(t): return t.ui == "TacticalBattleUI")).is_true()

## ERROR HANDLING TESTS

func test_error_handling_invalid_data() -> void:
	# Test with null mission data
	var success: bool = battle_manager.initialize_battle(null, test_crew_members, test_enemy_forces)
	
	# Should handle gracefully - mission_data can be null in some scenarios
	assert_that(success).is_true()

func test_error_handling_empty_crew() -> void:
	var empty_crew: Array[Resource] = []
	var success: bool = battle_manager.initialize_battle(test_mission_data, empty_crew, test_enemy_forces)
	
	# Should still initialize but with empty crew
	assert_that(success).is_true()
	assert_that(battle_manager.battle_state.crew_members.size()).is_equal(0)

func test_emergency_reset() -> void:
	# Set up active battle
	battle_manager.initialize_battle(test_mission_data, test_crew_members, test_enemy_forces)
	battle_manager.transition_to_phase(FPCM_BattleManager.BattlePhase.TACTICAL_BATTLE)
	
	# Trigger emergency reset
	battle_manager.emergency_reset()
	
	assert_that(battle_manager.is_active).is_false()
	assert_that(battle_manager.current_phase).is_equal(FPCM_BattleManager.BattlePhase.NONE)
	assert_that(battle_manager.battle_state).is_null()
	assert_that(error_signals.size()).is_greater(0)
	assert_that(error_signals.back().error_code).is_equal("EMERGENCY_RESET")

## PERFORMANCE TESTS

func test_performance_battle_initialization() -> void:
	var start_time: float = Time.get_ticks_msec()
	
	battle_manager.initialize_battle(test_mission_data, test_crew_members, test_enemy_forces)
	
	var elapsed: float = Time.get_ticks_msec() - start_time
	assert_that(elapsed).is_less(50.0) # Should initialize in less than 50ms

func test_performance_phase_transitions() -> void:
	battle_manager.initialize_battle(test_mission_data, test_crew_members, test_enemy_forces)
	
	var start_time: float = Time.get_ticks_msec()
	
	# Perform multiple transitions
	for i in range(10):
		battle_manager.advance_phase()
		if not battle_manager.is_active:
			battle_manager.initialize_battle(test_mission_data, test_crew_members, test_enemy_forces)
	
	var elapsed: float = Time.get_ticks_msec() - start_time
	var avg_per_transition: float = elapsed / 10.0
	assert_that(avg_per_transition).is_less(16.67) # Target: 60 FPS = 16.67ms per frame

func test_performance_memory_usage() -> void:
	# Test for memory leaks during battle lifecycle
	var initial_objects = Performance.get_monitor(Performance.OBJECT_COUNT)
	
	# Run multiple battle cycles
	for i in range(5):
		battle_manager.initialize_battle(test_mission_data, test_crew_members, test_enemy_forces)
		_advance_to_completion()
		await get_tree().process_frame
	
	var final_objects = Performance.get_monitor(Performance.OBJECT_COUNT)
	var object_increase = final_objects - initial_objects
	
	# Should not leak significant objects (allow some variance)
	assert_that(object_increase).is_less(100)

## UI COMPONENT MANAGEMENT TESTS

func test_ui_component_registration() -> void:
	var mock_ui = Control.new()
	track_node(mock_ui)
	
	battle_manager.register_ui_component("TestUI", mock_ui)
	
	assert_that(battle_manager.active_ui_components.has("TestUI")).is_true()
	assert_that(battle_manager.active_ui_components["TestUI"]).is_equal(mock_ui)

func test_ui_component_unregistration() -> void:
	var mock_ui = Control.new()
	track_node(mock_ui)
	
	battle_manager.register_ui_component("TestUI", mock_ui)
	battle_manager.unregister_ui_component("TestUI")
	
	assert_that(battle_manager.active_ui_components.has("TestUI")).is_false()

func test_ui_signal_connection() -> void:
	var mock_ui = Control.new()
	mock_ui.add_user_signal("phase_completed")
	track_node(mock_ui)
	
	battle_manager.register_ui_component("TestUI", mock_ui)
	
	# Trigger phase completion from UI
	battle_manager.initialize_battle(test_mission_data, test_crew_members, test_enemy_forces)
	var initial_phase = battle_manager.current_phase
	
	mock_ui.phase_completed.emit()
	await get_tree().process_frame
	
	# Should advance phase when auto_advance is enabled
	if battle_manager.auto_advance:
		assert_that(battle_manager.current_phase).is_not_equal(initial_phase)

## INTEGRATION TESTS

func test_dice_system_integration() -> void:
	# Test that dice system integration works
	battle_manager.initialize_battle(test_mission_data, test_crew_members, test_enemy_forces)
	
	var dice_requests: Array[Dictionary] = []
	battle_manager.dice_roll_requested.connect(func(pattern, context): dice_requests.append({"pattern": pattern, "context": context}))
	
	# Request a dice roll
	var result = battle_manager.request_dice_roll(1, "Test Roll") # Assuming DicePattern enum value 1
	
	assert_that(dice_requests.size()).is_greater(0)
	assert_that(dice_requests[0].context).is_equal("Test Roll")

func test_battle_events_integration() -> void:
	battle_manager.initialize_battle(test_mission_data, test_crew_members, test_enemy_forces)
	
	var battle_events: Array = []
	battle_manager.battle_event_activated.connect(func(event): battle_events.append(event))
	
	# Transition to tactical battle to trigger battle events
	battle_manager.transition_to_phase(FPCM_BattleManager.BattlePhase.TACTICAL_BATTLE)
	
	# Battle events system should be initialized
	assert_that(battle_manager.battle_events_system).is_not_null()

func test_story_system_integration() -> void:
	var story_events: Array[Dictionary] = []
	battle_manager.story_event_triggered.connect(func(event_id, context): story_events.append({"event_id": event_id, "context": context}))
	
	# Story events can be triggered during battle
	battle_manager.story_event_triggered.emit("test_event", {"test": true})
	
	assert_that(story_events.size()).is_equal(1)

## HELPER METHODS

func _setup_signal_tracking() -> void:
	battle_manager.phase_changed.connect(_on_phase_changed)
	battle_manager.battle_completed.connect(_on_battle_completed)
	battle_manager.battle_error.connect(_on_battle_error)

func _on_phase_changed(old_phase: FPCM_BattleManager.BattlePhase, new_phase: FPCM_BattleManager.BattlePhase) -> void:
	phase_changed_signals.append({"old_phase": old_phase, "new_phase": new_phase})

func _on_battle_completed(result: FPCM_BattleManager.BattleResult) -> void:
	battle_completed_signals.append({"result": result})

func _on_battle_error(error_code: String, context: Dictionary) -> void:
	error_signals.append({"error_code": error_code, "context": context})

func _create_test_data() -> void:
	# Create test mission data
	test_mission_data = Resource.new()
	test_mission_data.set_meta("name", "Test Mission")
	test_mission_data.set_meta("type", "patrol")
	
	# Create test crew members
	test_crew_members.clear()
	for i in range(3):
		var crew_member = Resource.new()
		crew_member.set_meta("id", "crew_" + str(i))
		crew_member.set_meta("name", "Crew Member " + str(i))
		crew_member.set_meta("combat", 3)
		crew_member.set_meta("toughness", 4)
		test_crew_members.append(crew_member)
	
	# Create test enemy forces
	test_enemy_forces.clear()
	for i in range(2):
		var enemy = Resource.new()
		enemy.set_meta("id", "enemy_" + str(i))
		enemy.set_meta("name", "Enemy " + str(i))
		enemy.set_meta("combat", 2)
		enemy.set_meta("toughness", 3)
		test_enemy_forces.append(enemy)

func _advance_to_completion() -> void:
	# Helper to advance battle to completion
	var max_iterations = 10
	var iterations = 0
	
	while battle_manager.is_active and iterations < max_iterations:
		var success = battle_manager.advance_phase()
		if not success:
			break
		iterations += 1
		await get_tree().process_frame
	
	if iterations >= max_iterations:
		push_warning("Battle did not complete within expected iterations")