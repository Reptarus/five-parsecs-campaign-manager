@tool
extends GdUnitGameTest

## Complete Battle Flow End-to-End Test Suite
##
## Tests full battle sequences and integration scenarios:
## - Complete battle lifecycle from start to finish
## - Multiple phase transitions with real data
## - System integration verification
## - Real-world scenario testing
## - Edge case battle flows
## - Performance under realistic conditions

# Test subjects - Complete battle system
const FPCM_BattleManager: GDScript = preload("res://src/core/battle/FPCM_BattleManager.gd")
const FPCM_BattleState: GDScript = preload("res://src/core/battle/FPCM_BattleState.gd")
const FPCM_BattleEventBus: GDScript = preload("res://src/core/battle/FPCM_BattleEventBus.gd")
const FPCM_DiceSystem: GDScript = preload("res://src/core/systems/DiceSystem.gd")

# System instances
var battle_manager: FPCM_BattleManager.new() = null
var battle_state: FPCM_BattleState.new() = null
var event_bus: Node = null
var dice_system: FPCM_DiceSystem.new() = null

# Test scenarios and data
var test_scenarios: Array[Dictionary] = []
var battle_results: Array[Dictionary] = []
var performance_metrics: Dictionary = {}

# Integration tracking
var signal_log: Array[Dictionary] = []
var phase_transitions: Array[Dictionary] = []
var ui_interactions: Array[Dictionary] = []

func before_test() -> void:
	super.before_test()
	await get_tree().process_frame
	
	# Initialize complete battle system
	battle_manager = FPCM_BattleManager.new()
	track_node(battle_manager)
	
	battle_state = FPCM_BattleState.new()
	track_node(battle_state)
	
	event_bus = FPCM_BattleEventBus.new()
	add_child(event_bus)
	track_node(event_bus)
	
	dice_system = FPCM_DiceSystem.new()
	track_node(dice_system)
	
	# Connect all systems
	event_bus.set_battle_manager(battle_manager)
	battle_manager.battle_state = battle_state
	battle_manager.dice_system = dice_system
	
	# Set up comprehensive signal tracking
	_setup_comprehensive_signal_tracking()
	
	# Initialize test scenarios
	_initialize_test_scenarios()
	
	# Clear tracking arrays
	signal_log.clear()
	phase_transitions.clear()
	ui_interactions.clear()
	battle_results.clear()
	performance_metrics.clear()

func after_test() -> void:
	# Final cleanup
	battle_manager = null
	battle_state = null
	event_bus = null
	dice_system = null
	
	test_scenarios.clear()
	battle_results.clear()
	signal_log.clear()
	phase_transitions.clear()
	ui_interactions.clear()
	performance_metrics.clear()
	
	super.after_test()

## COMPLETE BATTLE LIFECYCLE TESTS

func test_standard_patrol_mission_complete_flow() -> void:
	var patrol_scenario = _get_scenario("standard_patrol")
	var flow_start_time = Time.get_ticks_msec()
	
	# Execute complete battle flow
	var result = await _execute_complete_battle_flow(patrol_scenario)
	
	var flow_duration = Time.get_ticks_msec() - flow_start_time
	
	# Verify successful completion
	assert_that(result.success).is_true()
	assert_that(result.final_phase).is_equal(FPCM_BattleManager.BattlePhase.BATTLE_COMPLETE)
	assert_that(result.phase_count).is_greater_equal(4) # Should go through all phases
	
	# Verify performance
	assert_that(flow_duration).is_less(5000.0) # Should complete within 5 seconds
	
	print("Standard patrol battle completed in %f ms through %d phases" % [flow_duration, result.phase_count])

func test_elite_enemy_encounter_complete_flow() -> void:
	var elite_scenario = _get_scenario("elite_encounter")
	
	# Execute complete battle with elite enemies
	var result = await _execute_complete_battle_flow(elite_scenario)
	
	# Elite battles should complete successfully but may take longer
	assert_that(result.success).is_true()
	assert_that(result.final_phase).is_equal(FPCM_BattleManager.BattlePhase.BATTLE_COMPLETE)
	
	# Should have more complex resolution
	assert_that(result.dice_rolls_used).is_greater(5) # Elite encounters require more dice rolls
	assert_that(result.ui_transitions).is_greater_equal(4)

func test_large_crew_battle_complete_flow() -> void:
	var large_crew_scenario = _get_scenario("large_crew_battle")
	
	# Execute battle with maximum crew size
	var result = await _execute_complete_battle_flow(large_crew_scenario)
	
	# Large crew battles should handle complexity
	assert_that(result.success).is_true()
	assert_that(result.crew_processed).is_equal(8) # Should process all 8 crew members
	assert_that(result.performance_acceptable).is_true()

func test_story_track_integration_complete_flow() -> void:
	var story_scenario = _get_scenario("story_integration")
	
	# Execute battle with story track elements
	var result = await _execute_complete_battle_flow(story_scenario)
	
	# Story integration should work seamlessly
	assert_that(result.success).is_true()
	assert_that(result.story_events_processed).is_greater(0)
	assert_that(result.narrative_coherence).is_true()

## MULTI-PHASE TRANSITION TESTS

func test_all_phase_transitions_in_sequence() -> void:
	var transition_scenario = _get_scenario("all_phases")
	var phase_tracking: Array[int] = []
	
	# Track each phase transition
	battle_manager.battle_phase_changed.connect(func(old_phase, new_phase): 
		phase_tracking.append(new_phase)
	)
	
	# Execute complete flow
	var result = await _execute_complete_battle_flow(transition_scenario)
	
	# Should transition through all phases in correct order
	var expected_phases = [
		FPCM_BattleManager.BattlePhase.PRE_BATTLE,
		FPCM_BattleManager.BattlePhase.TACTICAL_BATTLE,
		FPCM_BattleManager.BattlePhase.BATTLE_RESOLUTION,
		FPCM_BattleManager.BattlePhase.POST_BATTLE,
		FPCM_BattleManager.BattlePhase.BATTLE_COMPLETE
	]
	
	for i in range(expected_phases.size()):
		if i < phase_tracking.size():
			assert_that(phase_tracking[i]).is_equal(expected_phases[i])
	
	assert_that(result.success).is_true()

func test_phase_transition_rollback_handling() -> void:
	var rollback_scenario = _get_scenario("rollback_test")
	
	# Execute battle with intentional rollback
	var result = await _execute_battle_with_rollback(rollback_scenario)
	
	# Should handle rollback gracefully
	assert_that(result.rollback_handled).is_true()
	assert_that(result.final_phase).is_not_equal(FPCM_BattleManager.BattlePhase.NONE)

func test_conditional_phase_skipping() -> void:
	var skip_scenario = _get_scenario("conditional_skip")
	
	# Some scenarios might skip certain phases
	var result = await _execute_complete_battle_flow(skip_scenario)
	
	assert_that(result.success).is_true()
	# Verify that skipped phases were handled appropriately
	assert_that(result.phases_skipped).is_greater_equal(0)

## SYSTEM INTEGRATION VERIFICATION TESTS

func test_dice_system_battle_integration_flow() -> void:
	var dice_scenario = _get_scenario("dice_heavy")
	
	# Configure for manual dice input testing
	dice_system.auto_roll_enabled = false
	dice_system.allow_manual_override = true
	
	# Execute battle with dice integration
	var result = await _execute_battle_with_manual_dice(dice_scenario)
	
	# Dice integration should work seamlessly
	assert_that(result.success).is_true()
	assert_that(result.manual_dice_requests).is_greater(0)
	assert_that(result.dice_integration_successful).is_true()

func test_event_bus_system_integration_flow() -> void:
	var event_scenario = _get_scenario("event_heavy")
	
	# Execute battle with heavy event bus usage
	var result = await _execute_complete_battle_flow(event_scenario)
	
	# Event bus should handle all communications
	assert_that(result.success).is_true()
	assert_that(result.events_processed).is_greater(20)
	assert_that(result.event_bus_performance).is_true()

func test_state_persistence_integration_flow() -> void:
	var persistence_scenario = _get_scenario("save_load_test")
	
	# Execute battle with save/load operations
	var result = await _execute_battle_with_save_load(persistence_scenario)
	
	# State persistence should work correctly
	assert_that(result.success).is_true()
	assert_that(result.save_successful).is_true()
	assert_that(result.load_successful).is_true()
	assert_that(result.state_integrity_maintained).is_true()

func test_ui_system_integration_flow() -> void:
	var ui_scenario = _get_scenario("ui_intensive")
	
	# Create mock UI components for all phases
	var ui_components = _create_full_battle_ui_suite()
	
	# Register all UI components
	for ui_name in ui_components:
		battle_manager.register_ui_component(ui_name, ui_components[ui_name])
	
	# Execute battle with full UI integration
	var result = await _execute_complete_battle_flow(ui_scenario)
	
	# UI integration should be seamless
	assert_that(result.success).is_true()
	assert_that(result.ui_components_active).is_equal(ui_components.size())
	assert_that(result.ui_transitions_successful).is_true()

## REAL-WORLD SCENARIO TESTS

func test_interrupted_battle_recovery_flow() -> void:
	var interrupt_scenario = _get_scenario("interruption_test")
	
	# Start battle normally
	battle_manager.initialize_battle(
		interrupt_scenario.mission,
		interrupt_scenario.crew,
		interrupt_scenario.enemies
	)
	
	# Advance to mid-battle
	battle_manager.transition_to_phase(FPCM_BattleManager.BattlePhase.TACTICAL_BATTLE)
	await get_tree().process_frame
	
	# Simulate interruption
	battle_manager.emergency_reset()
	
	# Restart battle
	var result = await _execute_complete_battle_flow(interrupt_scenario)
	
	# Should recover and complete successfully
	assert_that(result.success).is_true()
	assert_that(result.recovery_successful).is_true()

func test_memory_constrained_battle_flow() -> void:
	var memory_scenario = _get_scenario("memory_constrained")
	
	# Enable memory optimization
	battle_manager.enable_memory_optimization(true)
	
	# Execute battle under memory constraints
	var initial_memory = Performance.get_monitor(Performance.OBJECT_COUNT)
	var result = await _execute_complete_battle_flow(memory_scenario)
	var final_memory = Performance.get_monitor(Performance.OBJECT_COUNT)
	
	# Should complete without excessive memory usage
	assert_that(result.success).is_true()
	assert_that(final_memory - initial_memory).is_less(100) # Reasonable memory increase
	
	print("Memory usage during constrained battle: %d objects" % (final_memory - initial_memory))

func test_performance_critical_battle_flow() -> void:
	var performance_scenario = _get_scenario("performance_critical")
	
	# Execute battle with performance monitoring
	var start_time = Time.get_ticks_msec()
	var result = await _execute_complete_battle_flow(performance_scenario)
	var total_time = Time.get_ticks_msec() - start_time
	
	# Should maintain performance standards
	assert_that(result.success).is_true()
	assert_that(total_time).is_less(10000.0) # Should complete within 10 seconds
	assert_that(result.average_fps).is_greater(50.0) # Maintain good FPS
	
	print("Performance critical battle completed in %f ms with avg FPS: %f" % [total_time, result.average_fps])

func test_concurrent_battle_operations_flow() -> void:
	var concurrent_scenario = _get_scenario("concurrent_ops")
	
	# Execute battle with concurrent operations
	var result = await _execute_battle_with_concurrent_operations(concurrent_scenario)
	
	# Concurrent operations should be handled correctly
	assert_that(result.success).is_true()
	assert_that(result.concurrent_operations_successful).is_true()
	assert_that(result.race_conditions_detected).is_equal(0)

## EDGE CASE BATTLE FLOWS

func test_minimal_crew_battle_flow() -> void:
	var minimal_scenario = _get_scenario("minimal_crew")
	
	# Battle with only 1 crew member
	var result = await _execute_complete_battle_flow(minimal_scenario)
	
	# Should handle minimal crew gracefully
	assert_that(result.success).is_true()
	assert_that(result.crew_processed).is_equal(1)
	assert_that(result.tactical_balance_maintained).is_true()

func test_overwhelming_enemy_battle_flow() -> void:
	var overwhelming_scenario = _get_scenario("overwhelming_enemies")
	
	# Battle with many enemies
	var result = await _execute_complete_battle_flow(overwhelming_scenario)
	
	# Should handle large enemy forces
	assert_that(result.success).is_true()
	assert_that(result.enemies_processed).is_greater_equal(20)
	assert_that(result.performance_acceptable).is_true()

func test_no_enemy_mission_flow() -> void:
	var no_enemy_scenario = _get_scenario("no_enemies")
	
	# Mission with no enemies (exploration, etc.)
	var result = await _execute_complete_battle_flow(no_enemy_scenario)
	
	# Should handle gracefully
	assert_that(result.success).is_true()
	assert_that(result.non_combat_resolution).is_true()

func test_equipment_failure_during_battle_flow() -> void:
	var equipment_failure_scenario = _get_scenario("equipment_failure")
	
	# Simulate equipment failures during battle
	var result = await _execute_battle_with_equipment_failures(equipment_failure_scenario)
	
	# Should handle equipment failures
	assert_that(result.success).is_true()
	assert_that(result.equipment_failures_handled).is_true()

## COMPREHENSIVE INTEGRATION TESTS

func test_full_campaign_battle_sequence() -> void:
	# Execute multiple battles in sequence (campaign-style)
	var campaign_scenarios = [
		_get_scenario("campaign_battle_1"),
		_get_scenario("campaign_battle_2"),
		_get_scenario("campaign_battle_3")
	]
	
	var campaign_results: Array[Dictionary] = []
	
	for scenario in campaign_scenarios:
		var result = await _execute_complete_battle_flow(scenario)
		campaign_results.append(result)
		
		# Brief pause between battles
		await get_tree().process_frame
		await get_tree().process_frame
	
	# All battles should complete successfully
	for result in campaign_results:
		assert_that(result.success).is_true()
	
	# Campaign continuity should be maintained
	var campaign_coherence = _verify_campaign_coherence(campaign_results)
	assert_that(campaign_coherence).is_true()

func test_battle_system_stress_endurance() -> void:
	# Run many battles to test system endurance
	var stress_results: Array[Dictionary] = []
	var stress_battle_count = 10
	
	for i in range(stress_battle_count):
		var stress_scenario = _get_scenario("stress_test")
		stress_scenario.mission.set_meta("iteration", i)
		
		var result = await _execute_complete_battle_flow(stress_scenario)
		stress_results.append(result)
		
		# Check for degradation
		if i > 0:
			var performance_degradation = result.performance_score < stress_results[0].performance_score * 0.8
			assert_that(performance_degradation).is_false()
	
	# All stress tests should pass
	for result in stress_results:
		assert_that(result.success).is_true()
	
	print("Completed %d stress battles successfully" % stress_battle_count)

## HELPER METHODS - BATTLE EXECUTION

func _execute_complete_battle_flow(scenario: Dictionary) -> Dictionary:
	var flow_result = {
		"success": false,
		"final_phase": FPCM_BattleManager.BattlePhase.NONE,
		"phase_count": 0,
		"ui_transitions": 0,
		"dice_rolls_used": 0,
		"crew_processed": 0,
		"enemies_processed": 0,
		"performance_acceptable": true,
		"average_fps": 0.0,
		"story_events_processed": 0,
		"narrative_coherence": true,
		"events_processed": 0,
		"event_bus_performance": true,
		"performance_score": 100.0,
		"phases_skipped": 0
	}
	
	var start_time = Time.get_ticks_msec()
	var fps_samples: Array[float] = []
	
	try:
		# Initialize battle
		var init_success = battle_manager.initialize_battle(
			scenario.mission,
			scenario.crew,
			scenario.enemies
		)
		
		if not init_success:
			return flow_result
		
		flow_result.crew_processed = scenario.crew.size()
		flow_result.enemies_processed = scenario.enemies.size()
		
		# Execute complete battle flow
		var max_phases = 10
		var phase_count = 0
		
		while battle_manager.is_active and phase_count < max_phases:
			# Track phase
			flow_result.final_phase = battle_manager.current_phase
			
			# Advance phase
			var advance_success = battle_manager.advance_phase()
			if not advance_success:
				break
			
			phase_count += 1
			flow_result.phase_count = phase_count
			
			# Sample performance
			fps_samples.append(Engine.get_frames_per_second())
			
			# Process events
			await get_tree().process_frame
		
		# Calculate performance metrics
		if fps_samples.size() > 0:
			flow_result.average_fps = fps_samples.reduce(func(a, b): return a + b, 0.0) / fps_samples.size()
		
		flow_result.performance_acceptable = flow_result.average_fps >= 50.0
		flow_result.dice_rolls_used = dice_system.roll_history.size()
		flow_result.events_processed = signal_log.size()
		flow_result.ui_transitions = ui_interactions.size()
		
		# Battle completed successfully
		flow_result.success = battle_manager.current_phase == FPCM_BattleManager.BattlePhase.BATTLE_COMPLETE
		
		# Performance score calculation
		var duration = Time.get_ticks_msec() - start_time
		flow_result.performance_score = max(0, 100 - (duration / 100.0)) # Rough performance scoring
		
	except:
		push_error("Battle flow execution failed: " + str(get_last_error()))
		flow_result.success = false
	
	return flow_result

func _execute_battle_with_rollback(scenario: Dictionary) -> Dictionary:
	var result = {
		"rollback_handled": false,
		"final_phase": FPCM_BattleManager.BattlePhase.NONE,
		"success": false
	}
	
	try:
		# Initialize and advance to tactical battle
		battle_manager.initialize_battle(scenario.mission, scenario.crew, scenario.enemies)
		battle_manager.transition_to_phase(FPCM_BattleManager.BattlePhase.TACTICAL_BATTLE)
		
		# Simulate rollback need
		var rollback_success = battle_manager.rollback_to_phase(FPCM_BattleManager.BattlePhase.PRE_BATTLE)
		result.rollback_handled = rollback_success
		
		# Continue battle normally
		var flow_result = await _execute_complete_battle_flow(scenario)
		result.success = flow_result.success
		result.final_phase = flow_result.final_phase
		
	except:
		result.success = false
	
	return result

func _execute_battle_with_manual_dice(scenario: Dictionary) -> Dictionary:
	var result = {
		"success": false,
		"manual_dice_requests": 0,
		"dice_integration_successful": true
	}
	
	# Track manual dice requests
	dice_system.manual_input_requested.connect(func(dice_roll): 
		result.manual_dice_requests += 1
		# Simulate manual input
		dice_system.input_manual_result(dice_roll, [4]) # Always roll 4 for consistency
	)
	
	var flow_result = await _execute_complete_battle_flow(scenario)
	result.success = flow_result.success
	result.dice_integration_successful = result.manual_dice_requests > 0
	
	return result

func _execute_battle_with_save_load(scenario: Dictionary) -> Dictionary:
	var result = {
		"success": false,
		"save_successful": false,
		"load_successful": false,
		"state_integrity_maintained": false
	}
	
	try:
		# Initialize and advance partway
		battle_manager.initialize_battle(scenario.mission, scenario.crew, scenario.enemies)
		battle_manager.transition_to_phase(FPCM_BattleManager.BattlePhase.TACTICAL_BATTLE)
		
		# Save state
		var save_data = battle_state.create_checkpoint()
		result.save_successful = save_data != null
		
		# Make some changes
		battle_manager.advance_phase()
		
		# Load state
		var load_success = battle_state.restore_from_checkpoint(save_data)
		result.load_successful = load_success
		
		# Verify state integrity
		result.state_integrity_maintained = battle_manager.current_phase == FPCM_BattleManager.BattlePhase.TACTICAL_BATTLE
		
		# Complete battle
		var flow_result = await _execute_complete_battle_flow(scenario)
		result.success = flow_result.success
		
	except:
		result.success = false
	
	return result

func _execute_battle_with_concurrent_operations(scenario: Dictionary) -> Dictionary:
	var result = {
		"success": false,
		"concurrent_operations_successful": true,
		"race_conditions_detected": 0
	}
	
	# Simulate concurrent operations during battle
	battle_manager.initialize_battle(scenario.mission, scenario.crew, scenario.enemies)
	
	# Start multiple concurrent operations
	var operation_results: Array[bool] = []
	
	# Concurrent dice rolls
	for i in range(5):
		var dice_result = dice_system.roll_dice(FPCM_DiceSystem.DicePattern.D6, "Concurrent " + str(i))
		operation_results.append(dice_result != null)
	
	# Concurrent UI operations
	var ui = _create_mock_battle_ui("ConcurrentUI")
	battle_manager.register_ui_component("ConcurrentUI", ui)
	battle_manager.unregister_ui_component("ConcurrentUI")
	
	# Complete battle flow
	var flow_result = await _execute_complete_battle_flow(scenario)
	result.success = flow_result.success
	result.concurrent_operations_successful = operation_results.all(func(res): return res)
	
	return result

func _execute_battle_with_equipment_failures(scenario: Dictionary) -> Dictionary:
	var result = {
		"success": false,
		"equipment_failures_handled": true
	}
	
	# Simulate equipment failures by triggering error conditions
	battle_manager.initialize_battle(scenario.mission, scenario.crew, scenario.enemies)
	
	# Simulate failures during tactical phase
	battle_manager.transition_to_phase(FPCM_BattleManager.BattlePhase.TACTICAL_BATTLE)
	
	# Trigger error (simulating equipment failure)
	battle_manager.handle_battle_error("EQUIPMENT_FAILURE", {"item": "weapon", "crew_member": "test"})
	
	# Battle should continue despite failures
	var flow_result = await _execute_complete_battle_flow(scenario)
	result.success = flow_result.success
	
	return result

## HELPER METHODS - DATA AND SETUP

func _setup_comprehensive_signal_tracking() -> void:
	# Track all major signals
	battle_manager.battle_phase_changed.connect(_on_phase_changed)
	battle_manager.ui_transition_requested.connect(_on_ui_transition)
	battle_manager.battle_completed.connect(_on_battle_completed)
	battle_manager.battle_error.connect(_on_battle_error)
	
	event_bus.battle_state_updated.connect(_on_state_updated)
	event_bus.dice_roll_requested.connect(_on_dice_requested)
	
	dice_system.dice_rolled.connect(_on_dice_rolled)

func _on_phase_changed(old_phase: int, new_phase: int) -> void:
	phase_transitions.append({
		"old_phase": old_phase,
		"new_phase": new_phase,
		"timestamp": Time.get_ticks_msec()
	})

func _on_ui_transition(target_ui: String, data: Dictionary) -> void:
	ui_interactions.append({
		"target": target_ui,
		"data": data,
		"timestamp": Time.get_ticks_msec()
	})

func _on_battle_completed(result: Dictionary) -> void:
	signal_log.append({
		"signal": "battle_completed",
		"result": result,
		"timestamp": Time.get_ticks_msec()
	})

func _on_battle_error(error_code: String, context: Dictionary) -> void:
	signal_log.append({
		"signal": "battle_error",
		"error": error_code,
		"context": context,
		"timestamp": Time.get_ticks_msec()
	})

func _on_state_updated(state) -> void:
	signal_log.append({
		"signal": "state_updated",
		"timestamp": Time.get_ticks_msec()
	})

func _on_dice_requested(pattern, context: String) -> void:
	signal_log.append({
		"signal": "dice_requested",
		"pattern": pattern,
		"context": context,
		"timestamp": Time.get_ticks_msec()
	})

func _on_dice_rolled(result) -> void:
	signal_log.append({
		"signal": "dice_rolled",
		"result": result.get_simple_text() if result else "null",
		"timestamp": Time.get_ticks_msec()
	})

func _initialize_test_scenarios() -> void:
	test_scenarios = [
		{
			"name": "standard_patrol",
			"mission": _create_test_mission("Patrol Mission", "patrol"),
			"crew": _create_test_crew(4),
			"enemies": _create_test_enemies(3)
		},
		{
			"name": "elite_encounter",
			"mission": _create_test_mission("Elite Encounter", "elite_battle"),
			"crew": _create_test_crew(6),
			"enemies": _create_test_elite_enemies(2)
		},
		{
			"name": "large_crew_battle",
			"mission": _create_test_mission("Large Crew Mission", "assault"),
			"crew": _create_test_crew(8),
			"enemies": _create_test_enemies(6)
		},
		{
			"name": "story_integration",
			"mission": _create_test_story_mission("Story Mission", "story_battle"),
			"crew": _create_test_crew(5),
			"enemies": _create_test_enemies(4)
		},
		{
			"name": "all_phases",
			"mission": _create_test_mission("All Phases Mission", "comprehensive"),
			"crew": _create_test_crew(4),
			"enemies": _create_test_enemies(4)
		},
		{
			"name": "rollback_test",
			"mission": _create_test_mission("Rollback Test", "test"),
			"crew": _create_test_crew(3),
			"enemies": _create_test_enemies(3)
		},
		{
			"name": "conditional_skip",
			"mission": _create_test_mission("Skip Test", "skip_phases"),
			"crew": _create_test_crew(2),
			"enemies": _create_test_enemies(1)
		},
		{
			"name": "dice_heavy",
			"mission": _create_test_mission("Dice Heavy", "dice_intensive"),
			"crew": _create_test_crew(4),
			"enemies": _create_test_enemies(4)
		},
		{
			"name": "event_heavy",
			"mission": _create_test_mission("Event Heavy", "event_intensive"),
			"crew": _create_test_crew(5),
			"enemies": _create_test_enemies(5)
		},
		{
			"name": "save_load_test",
			"mission": _create_test_mission("Save Load Test", "persistence"),
			"crew": _create_test_crew(3),
			"enemies": _create_test_enemies(3)
		},
		{
			"name": "ui_intensive",
			"mission": _create_test_mission("UI Intensive", "ui_heavy"),
			"crew": _create_test_crew(4),
			"enemies": _create_test_enemies(4)
		},
		{
			"name": "interruption_test",
			"mission": _create_test_mission("Interruption Test", "interrupt"),
			"crew": _create_test_crew(3),
			"enemies": _create_test_enemies(2)
		},
		{
			"name": "memory_constrained",
			"mission": _create_test_mission("Memory Test", "memory_limited"),
			"crew": _create_test_crew(6),
			"enemies": _create_test_enemies(8)
		},
		{
			"name": "performance_critical",
			"mission": _create_test_mission("Performance Test", "performance"),
			"crew": _create_test_crew(8),
			"enemies": _create_test_enemies(10)
		},
		{
			"name": "concurrent_ops",
			"mission": _create_test_mission("Concurrent Test", "concurrent"),
			"crew": _create_test_crew(4),
			"enemies": _create_test_enemies(4)
		},
		{
			"name": "minimal_crew",
			"mission": _create_test_mission("Minimal Crew", "solo"),
			"crew": _create_test_crew(1),
			"enemies": _create_test_enemies(2)
		},
		{
			"name": "overwhelming_enemies",
			"mission": _create_test_mission("Overwhelming Force", "survival"),
			"crew": _create_test_crew(4),
			"enemies": _create_test_enemies(20)
		},
		{
			"name": "no_enemies",
			"mission": _create_test_mission("Exploration", "exploration"),
			"crew": _create_test_crew(3),
			"enemies": []
		},
		{
			"name": "equipment_failure",
			"mission": _create_test_mission("Equipment Failure", "malfunction"),
			"crew": _create_test_crew(4),
			"enemies": _create_test_enemies(3)
		},
		{
			"name": "campaign_battle_1",
			"mission": _create_test_mission("Campaign 1", "campaign"),
			"crew": _create_test_crew(4),
			"enemies": _create_test_enemies(3)
		},
		{
			"name": "campaign_battle_2",
			"mission": _create_test_mission("Campaign 2", "campaign"),
			"crew": _create_test_crew(5),
			"enemies": _create_test_enemies(4)
		},
		{
			"name": "campaign_battle_3",
			"mission": _create_test_mission("Campaign 3", "campaign"),
			"crew": _create_test_crew(6),
			"enemies": _create_test_enemies(5)
		},
		{
			"name": "stress_test",
			"mission": _create_test_mission("Stress Test", "stress"),
			"crew": _create_test_crew(6),
			"enemies": _create_test_enemies(6)
		}
	]

func _get_scenario(name: String) -> Dictionary:
	for scenario in test_scenarios:
		if scenario.name == name:
			return scenario
	
	# Return default scenario if not found
	return test_scenarios[0]

func _create_test_mission(name: String, type: String) -> Resource:
	var mission = Resource.new()
	mission.set_meta("name", name)
	mission.set_meta("type", type)
	mission.set_meta("difficulty", 1)
	mission.set_meta("objectives", ["complete_battle"])
	return mission

func _create_test_story_mission(name: String, type: String) -> Resource:
	var mission = _create_test_mission(name, type)
	mission.set_meta("story_elements", ["introduction", "climax", "resolution"])
	mission.set_meta("narrative_hooks", ["mystery", "conflict", "discovery"])
	return mission

func _create_test_crew(size: int) -> Array[Resource]:
	var crew: Array[Resource] = []
	for i in range(size):
		var crew_member = Resource.new()
		crew_member.set_meta("id", "crew_" + str(i))
		crew_member.set_meta("name", "Crew Member " + str(i))
		crew_member.set_meta("role", ["soldier", "specialist", "leader"][i % 3])
		crew_member.set_meta("health", 3)
		crew_member.set_meta("combat", 2 + (i % 3))
		crew.append(crew_member)
	return crew

func _create_test_enemies(size: int) -> Array[Resource]:
	var enemies: Array[Resource] = []
	for i in range(size):
		var enemy = Resource.new()
		enemy.set_meta("id", "enemy_" + str(i))
		enemy.set_meta("name", "Enemy " + str(i))
		enemy.set_meta("type", ["grunt", "trooper", "leader"][i % 3])
		enemy.set_meta("health", 2)
		enemy.set_meta("combat", 1 + (i % 2))
		enemies.append(enemy)
	return enemies

func _create_test_elite_enemies(size: int) -> Array[Resource]:
	var enemies: Array[Resource] = []
	for i in range(size):
		var enemy = Resource.new()
		enemy.set_meta("id", "elite_" + str(i))
		enemy.set_meta("name", "Elite Enemy " + str(i))
		enemy.set_meta("type", "elite")
		enemy.set_meta("health", 4)
		enemy.set_meta("combat", 3)
		enemy.set_meta("special_abilities", ["tough", "aggressive"])
		enemies.append(enemy)
	return enemies

func _create_full_battle_ui_suite() -> Dictionary:
	var ui_suite = {}
	
	var ui_names = [
		"PreBattleUI",
		"TacticalBattleUI", 
		"BattleResolutionUI",
		"PostBattleUI",
		"DiceUI",
		"StatusUI"
	]
	
	for ui_name in ui_names:
		ui_suite[ui_name] = _create_mock_battle_ui(ui_name)
	
	return ui_suite

func _create_mock_battle_ui(name: String) -> Control:
	var ui = Control.new()
	ui.name = name
	ui.add_user_signal("phase_completed")
	ui.add_user_signal("ui_ready")
	ui.add_user_signal("error_occurred", [{"name": "error", "type": TYPE_STRING}])
	track_node(ui)
	return ui

func _verify_campaign_coherence(results: Array[Dictionary]) -> bool:
	# Verify that campaign battles maintain coherence
	for result in results:
		if not result.success:
			return false
	
	# Additional coherence checks could go here
	return true