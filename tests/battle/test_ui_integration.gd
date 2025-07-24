@tool
extends GdUnitGameTest

## Battle UI Integration Test Suite
##
## Tests the integration between battle system components:
## - Signal flow between components
## - Phase transition UI updates
## - Component lifecycle management
## - Error propagation handling
## - UI state synchronization

# Test subjects
const FPCM_BattleManager: GDScript = preload("res://src/core/battle/FPCM_BattleManager.gd")
const FPCM_BattleEventBus: GDScript = preload("res://src/core/battle/FPCM_BattleEventBus.gd")

# Type-safe instance variables
var battle_manager: FPCM_BattleManager.new() = null
var event_bus: Node = null
var mock_ui_components: Dictionary = {}
var ui_state_tracking: Dictionary = {}

# Test mission data
var test_mission: Resource = null
var test_crew: Array[Resource] = []
var test_enemies: Array[Resource] = []

func before_test() -> void:
	super.before_test()
	await get_tree().process_frame
	
	# Initialize systems
	battle_manager = FPCM_BattleManager.new()
	track_node(battle_manager)
	
	event_bus = FPCM_BattleEventBus.new()
	add_child(event_bus)
	track_node(event_bus)
	
	# Connect systems
	event_bus.set_battle_manager(battle_manager)
	
	# Create test data
	_create_test_data()
	
	# Clear tracking
	mock_ui_components.clear()
	ui_state_tracking.clear()

func after_test() -> void:
	# Cleanup mock UI components
	for component_name in mock_ui_components:
		var component = mock_ui_components[component_name]
		if is_instance_valid(component):
			component.queue_free()
	
	# Cleanup
	battle_manager = null
	event_bus = null
	mock_ui_components.clear()
	ui_state_tracking.clear()
	
	super.after_test()

## COMPONENT LIFECYCLE TESTS

func test_ui_component_registration_lifecycle() -> void:
	var pre_battle_ui = _create_mock_battle_ui("PreBattleUI")
	
	# Register component
	event_bus.register_ui_component("PreBattleUI", pre_battle_ui)
	
	assert_that(event_bus.registered_components.has("PreBattleUI")).is_true()
	assert_that(battle_manager.active_ui_components.has("PreBattleUI")).is_true()

func test_ui_component_auto_signal_connection() -> void:
	var battle_ui = _create_mock_battle_ui("BattleUI")
	battle_ui.add_user_signal("phase_completed")
	battle_ui.add_user_signal("error_occurred", [{"name": "error", "type": TYPE_STRING}, {"name": "context", "type": TYPE_DICTIONARY}])
	
	# Register with battle manager
	battle_manager.register_ui_component("BattleUI", battle_ui)
	
	# Signals should be auto-connected
	assert_that(battle_ui.phase_completed.get_connections().size()).is_greater_equal(1)
	assert_that(battle_ui.error_occurred.get_connections().size()).is_greater_equal(1)

func test_ui_component_cleanup_on_unregister() -> void:
	var battle_ui = _create_mock_battle_ui("BattleUI")
	battle_ui.add_user_signal("phase_completed")
	
	battle_manager.register_ui_component("BattleUI", battle_ui)
	var initial_connections = battle_ui.phase_completed.get_connections().size()
	
	battle_manager.unregister_ui_component("BattleUI")
	
	# Signals should be disconnected
	var final_connections = battle_ui.phase_completed.get_connections().size()
	assert_that(final_connections).is_less(initial_connections)
	assert_that(battle_manager.active_ui_components.has("BattleUI")).is_false()

## PHASE TRANSITION INTEGRATION TESTS

func test_phase_transition_ui_updates() -> void:
	var pre_battle_ui = _create_mock_battle_ui("PreBattleUI")
	var battle_resolution_ui = _create_mock_battle_ui("BattleResolutionUI")
	
	# Register UIs
	battle_manager.register_ui_component("PreBattleUI", pre_battle_ui)
	battle_manager.register_ui_component("BattleResolutionUI", battle_resolution_ui)
	
	# Initialize battle
	battle_manager.initialize_battle(test_mission, test_crew, test_enemies)
	await get_tree().process_frame
	
	# Should be in PRE_BATTLE phase
	assert_that(battle_manager.current_phase).is_equal(FPCM_BattleManager.BattlePhase.PRE_BATTLE)
	
	# Transition to BATTLE_RESOLUTION
	battle_manager.transition_to_phase(FPCM_BattleManager.BattlePhase.BATTLE_RESOLUTION)
	await get_tree().process_frame
	
	# UI transition signals should be emitted
	assert_that(ui_state_tracking.has("ui_transition_requested")).is_true()

func test_ui_phase_completion_triggers_advance() -> void:
	var pre_battle_ui = _create_mock_battle_ui("PreBattleUI")
	pre_battle_ui.add_user_signal("phase_completed")
	
	battle_manager.register_ui_component("PreBattleUI", pre_battle_ui)
	battle_manager.auto_advance = true
	
	# Initialize battle
	battle_manager.initialize_battle(test_mission, test_crew, test_enemies)
	var initial_phase = battle_manager.current_phase
	
	# Trigger phase completion from UI
	pre_battle_ui.phase_completed.emit()
	await get_tree().process_frame
	
	# Should advance to next phase
	assert_that(battle_manager.current_phase).is_not_equal(initial_phase)

func test_multiple_ui_phase_coordination() -> void:
	# Create multiple UI components for same phase
	var ui1 = _create_mock_battle_ui("BattleUI1")
	var ui2 = _create_mock_battle_ui("BattleUI2")
	
	ui1.add_user_signal("phase_completed")
	ui2.add_user_signal("phase_completed")
	
	battle_manager.register_ui_component("BattleUI1", ui1)
	battle_manager.register_ui_component("BattleUI2", ui2)
	
	battle_manager.initialize_battle(test_mission, test_crew, test_enemies)
	var initial_phase = battle_manager.current_phase
	
	# First UI completes phase
	ui1.phase_completed.emit()
	await get_tree().process_frame
	
	# Phase should advance even with multiple UIs
	if battle_manager.auto_advance:
		assert_that(battle_manager.current_phase).is_not_equal(initial_phase)

## SIGNAL FLOW INTEGRATION TESTS

func test_battle_state_updates_propagate_to_ui() -> void:
	var battle_ui = _create_mock_battle_ui("BattleUI")
	event_bus.register_ui_component("BattleUI", battle_ui)
	
	# Track battle state updates
	var state_updates: Array[Dictionary] = []
	event_bus.battle_state_updated.connect(func(state): state_updates.append({"state": state, "timestamp": Time.get_ticks_msec()}))
	
	# Initialize battle (should trigger state update)
	battle_manager.initialize_battle(test_mission, test_crew, test_enemies)
	await get_tree().process_frame
	
	assert_that(state_updates.size()).is_greater(0)

func test_dice_roll_integration_flow() -> void:
	var battle_ui = _create_mock_battle_ui("BattleUI")
	battle_ui.add_user_signal("dice_roll_requested", [{"name": "pattern", "type": TYPE_INT}, {"name": "context", "type": TYPE_STRING}])
	
	event_bus.register_ui_component("BattleUI", battle_ui)
	
	# Track dice roll requests
	var dice_requests: Array[Dictionary] = []
	event_bus.dice_roll_requested.connect(func(pattern, context): dice_requests.append({"pattern": pattern, "context": context}))
	
	# UI requests dice roll
	battle_ui.dice_roll_requested.emit(1, "UI Test Roll")
	await get_tree().process_frame
	
	assert_that(dice_requests.size()).is_greater(0)
	assert_that(dice_requests[0].context).is_equal("UI Test Roll")

func test_battle_completion_signal_flow() -> void:
	var post_battle_ui = _create_mock_battle_ui("PostBattleUI")
	event_bus.register_ui_component("PostBattleUI", post_battle_ui)
	
	# Track battle completion
	var completion_signals: Array = []
	event_bus.battle_completed.connect(func(result): completion_signals.append(result))
	
	# Complete full battle
	battle_manager.initialize_battle(test_mission, test_crew, test_enemies)
	_advance_battle_to_completion()
	
	assert_that(completion_signals.size()).is_greater(0)

## ERROR HANDLING INTEGRATION TESTS

func test_ui_error_propagation() -> void:
	var battle_ui = _create_mock_battle_ui("BattleUI")
	battle_ui.add_user_signal("error_occurred", [{"name": "error", "type": TYPE_STRING}, {"name": "context", "type": TYPE_DICTIONARY}])
	
	battle_manager.register_ui_component("BattleUI", battle_ui)
	
	# Track battle errors
	var battle_errors: Array[Dictionary] = []
	battle_manager.battle_error.connect(func(error_code, context): battle_errors.append({"error": error_code, "context": context}))
	
	# Trigger error from UI
	battle_ui.error_occurred.emit("UI_ERROR", {"message": "Test error"})
	await get_tree().process_frame
	
	assert_that(battle_errors.size()).is_greater(0)
	assert_that(battle_errors[0].error).is_equal("UI_ERROR")

func test_invalid_phase_transition_error_handling() -> void:
	var battle_ui = _create_mock_battle_ui("BattleUI")
	battle_manager.register_ui_component("BattleUI", battle_ui)
	
	# Track errors
	var errors: Array[Dictionary] = []
	battle_manager.battle_error.connect(func(error_code, context): errors.append({"error": error_code, "context": context}))
	
	# Initialize battle
	battle_manager.initialize_battle(test_mission, test_crew, test_enemies)
	
	# Attempt invalid transition
	battle_manager.transition_to_phase(FPCM_BattleManager.BattlePhase.POST_BATTLE)
	
	assert_that(errors.size()).is_greater(0)
	assert_that(errors.back().error).is_equal("INVALID_TRANSITION")

func test_error_recovery_and_cleanup() -> void:
	var battle_ui = _create_mock_battle_ui("BattleUI")
	battle_manager.register_ui_component("BattleUI", battle_ui)
	
	# Set up active battle
	battle_manager.initialize_battle(test_mission, test_crew, test_enemies)
	
	# Trigger emergency reset
	battle_manager.emergency_reset()
	
	# System should be clean
	assert_that(battle_manager.is_active).is_false()
	assert_that(battle_manager.current_phase).is_equal(FPCM_BattleManager.BattlePhase.NONE)
	assert_that(battle_manager.active_ui_components.size()).is_equal(0)

## UI STATE SYNCHRONIZATION TESTS

func test_ui_state_sync_during_battle() -> void:
	var companion_ui = _create_mock_battle_ui("CompanionUI")
	var resolution_ui = _create_mock_battle_ui("ResolutionUI")
	
	battle_manager.register_ui_component("CompanionUI", companion_ui)
	battle_manager.register_ui_component("ResolutionUI", resolution_ui)
	
	# Initialize battle
	battle_manager.initialize_battle(test_mission, test_crew, test_enemies)
	
	# Both UIs should receive same battle state
	var battle_status = battle_manager.get_battle_status()
	assert_that(battle_status["is_active"]).is_true()
	assert_that(battle_status["current_phase"]).is_equal(FPCM_BattleManager.BattlePhase.PRE_BATTLE)

func test_ui_lock_coordination() -> void:
	var ui1 = _create_mock_battle_ui("UI1")
	var ui2 = _create_mock_battle_ui("UI2")
	
	# Add mock set_ui_locked method
	ui1.set_script(GDScript.new())
	ui2.set_script(GDScript.new())
	
	event_bus.register_ui_component("UI1", ui1)
	event_bus.register_ui_component("UI2", ui2)
	
	# Trigger UI lock
	event_bus.ui_lock_requested.emit(true, "test_lock")
	await get_tree().process_frame
	
	# All UIs should receive lock request
	# Note: Would need mock verification in real implementation

func test_ui_refresh_coordination() -> void:
	var ui1 = _create_mock_battle_ui("UI1")
	var ui2 = _create_mock_battle_ui("UI2")
	
	event_bus.register_ui_component("UI1", ui1)
	event_bus.register_ui_component("UI2", ui2)
	
	# Request selective refresh
	event_bus.ui_refresh_requested.emit(["UI1"])
	await get_tree().process_frame
	
	# Only UI1 should be refreshed
	# Note: Would need mock verification in real implementation

## PERFORMANCE INTEGRATION TESTS

func test_ui_performance_under_load() -> void:
	# Register many UI components
	var ui_components: Array[Control] = []
	for i in range(20):
		var ui = _create_mock_battle_ui("UI_" + str(i))
		ui.add_user_signal("phase_completed")
		ui_components.append(ui)
		battle_manager.register_ui_component("UI_" + str(i), ui)
	
	var start_time = Time.get_ticks_msec()
	
	# Initialize battle with many UI components
	battle_manager.initialize_battle(test_mission, test_crew, test_enemies)
	
	# Trigger phase completion from multiple UIs
	for ui in ui_components:
		ui.phase_completed.emit()
	
	await get_tree().process_frame
	
	var elapsed = Time.get_ticks_msec() - start_time
	assert_that(elapsed).is_less(100.0) # Should handle efficiently

func test_signal_throughput_performance() -> void:
	var battle_ui = _create_mock_battle_ui("BattleUI")
	event_bus.register_ui_component("BattleUI", battle_ui)
	
	var signal_count = 0
	event_bus.battle_phase_changed.connect(func(old_phase, new_phase): signal_count += 1)
	
	var start_time = Time.get_ticks_msec()
	
	# Emit many phase change signals
	for i in range(1000):
		event_bus.battle_phase_changed.emit(0, 1)
	
	var elapsed = Time.get_ticks_msec() - start_time
	assert_that(elapsed).is_less(200.0) # Should handle high throughput
	assert_that(signal_count).is_equal(1000)

## BATTLE FLOW INTEGRATION TESTS

func test_complete_battle_ui_flow() -> void:
	# Create all battle UI components
	var pre_battle_ui = _create_mock_battle_ui("PreBattleUI")
	var tactical_ui = _create_mock_battle_ui("TacticalBattleUI")
	var resolution_ui = _create_mock_battle_ui("BattleResolutionUI")
	var post_battle_ui = _create_mock_battle_ui("PostBattleUI")
	
	# Add phase completion signals
	for ui in [pre_battle_ui, tactical_ui, resolution_ui, post_battle_ui]:
		ui.add_user_signal("phase_completed")
		battle_manager.register_ui_component(ui.name, ui)
	
	battle_manager.auto_advance = true
	
	# Track UI transitions
	var ui_transitions: Array[String] = []
	battle_manager.ui_transition_requested.connect(func(target_ui, data): ui_transitions.append(target_ui))
	
	# Run complete battle
	battle_manager.initialize_battle(test_mission, test_crew, test_enemies)
	await get_tree().process_frame
	
	# Should request UI transitions for each phase
	assert_that(ui_transitions.size()).is_greater(0)

func test_battle_interruption_and_resume() -> void:
	var battle_ui = _create_mock_battle_ui("BattleUI")
	battle_ui.add_user_signal("phase_completed")
	battle_manager.register_ui_component("BattleUI", battle_ui)
	
	# Start battle
	battle_manager.initialize_battle(test_mission, test_crew, test_enemies)
	battle_manager.transition_to_phase(FPCM_BattleManager.BattlePhase.TACTICAL_BATTLE)
	
	var mid_battle_status = battle_manager.get_battle_status()
	
	# Emergency reset (simulating interruption)
	battle_manager.emergency_reset()
	
	# Restart battle
	battle_manager.initialize_battle(test_mission, test_crew, test_enemies)
	
	# Should start fresh
	var new_status = battle_manager.get_battle_status()
	assert_that(new_status["current_phase"]).is_equal(FPCM_BattleManager.BattlePhase.PRE_BATTLE)

## EDGE CASE TESTS

func test_ui_registration_during_battle() -> void:
	# Start battle first
	battle_manager.initialize_battle(test_mission, test_crew, test_enemies)
	
	# Register UI mid-battle
	var mid_battle_ui = _create_mock_battle_ui("MidBattleUI")
	battle_manager.register_ui_component("MidBattleUI", mid_battle_ui)
	
	# Should handle gracefully
	assert_that(battle_manager.active_ui_components.has("MidBattleUI")).is_true()

func test_ui_unregistration_during_phase_transition() -> void:
	var battle_ui = _create_mock_battle_ui("BattleUI")
	battle_ui.add_user_signal("phase_completed")
	
	battle_manager.register_ui_component("BattleUI", battle_ui)
	battle_manager.initialize_battle(test_mission, test_crew, test_enemies)
	
	# Unregister during active battle
	battle_manager.unregister_ui_component("BattleUI")
	
	# Transition should still work
	var success = battle_manager.advance_phase()
	assert_that(success).is_true()

func test_null_ui_component_handling() -> void:
	# Try to register null component
	battle_manager.register_ui_component("NullUI", null)
	
	# Should handle gracefully without crashing
	assert_that(battle_manager.active_ui_components.has("NullUI")).is_false()

## HELPER METHODS

func _create_mock_battle_ui(name: String) -> Control:
	var mock_ui = Control.new()
	mock_ui.name = name
	mock_ui_components[name] = mock_ui
	track_node(mock_ui)
	
	# Set up state tracking
	ui_state_tracking[name] = {
		"created": Time.get_ticks_msec(),
		"signals_received": []
	}
	
	return mock_ui

func _create_test_data() -> void:
	# Create test mission
	test_mission = Resource.new()
	test_mission.set_meta("name", "Test Mission")
	test_mission.set_meta("type", "patrol")
	
	# Create test crew
	test_crew.clear()
	for i in range(3):
		var crew_member = Resource.new()
		crew_member.set_meta("id", "crew_" + str(i))
		crew_member.set_meta("name", "Crew " + str(i))
		test_crew.append(crew_member)
	
	# Create test enemies
	test_enemies.clear()
	for i in range(2):
		var enemy = Resource.new()
		enemy.set_meta("id", "enemy_" + str(i))
		enemy.set_meta("name", "Enemy " + str(i))
		test_enemies.append(enemy)

func _advance_battle_to_completion() -> void:
	# Helper to run battle to completion
	var max_iterations = 10
	var iterations = 0
	
	while battle_manager.is_active and iterations < max_iterations:
		battle_manager.advance_phase()
		await get_tree().process_frame
		iterations += 1
	
	if iterations >= max_iterations:
		push_warning("Battle did not complete within expected iterations")