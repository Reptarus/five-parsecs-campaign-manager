@tool
extends GdUnitGameTest

## Battle System Performance Validation Test Suite
##
## Tests the 60 FPS performance requirements:
## - Battle manager operations under load
## - UI component performance scaling
## - Memory usage and leak detection
## - Frame timing consistency
## - Performance optimization validation

# Test subjects
const FPCM_BattleManager: GDScript = preload("res://src/core/battle/FPCM_BattleManager.gd")
const FPCM_BattleState: GDScript = preload("res://src/core/battle/FPCM_BattleState.gd")
const FPCM_BattleEventBus: GDScript = preload("res://src/core/battle/FPCM_BattleEventBus.gd")
const FPCM_BattlePerformanceOptimizer: GDScript = preload("res://src/core/battle/FPCM_BattlePerformanceOptimizer.gd")

# Performance constants
const TARGET_FPS: float = 60.0
const TARGET_FRAME_TIME: float = 16.67 # milliseconds (1000/60)
const ACCEPTABLE_FPS_DROP: float = 5.0 # Allow 5 FPS below target
const MAX_MEMORY_INCREASE: int = 50 * 1024 * 1024 # 50MB

# Type-safe instance variables
var battle_manager: FPCM_BattleManager.new() = null
var event_bus: Node = null
var performance_optimizer: FPCM_BattlePerformanceOptimizer.new() = null
var mock_ui_components: Array[Control] = []

# Performance tracking
var frame_times: Array[float] = []
var memory_snapshots: Array[int] = []
var fps_measurements: Array[float] = []

func before_test() -> void:
	super.before_test()
	await get_tree().process_frame
	
	# Initialize systems
	battle_manager = FPCM_BattleManager.new()
	track_node(battle_manager)
	
	event_bus = FPCM_BattleEventBus.new()
	add_child(event_bus)
	track_node(event_bus)
	
	performance_optimizer = FPCM_BattlePerformanceOptimizer.new()
	track_node(performance_optimizer)
	
	# Connect systems
	event_bus.set_battle_manager(battle_manager)
	
	# Clear tracking data
	frame_times.clear()
	memory_snapshots.clear()
	fps_measurements.clear()
	mock_ui_components.clear()
	
	# Start performance monitoring
	_start_performance_monitoring()

func after_test() -> void:
	# Cleanup
	for component in mock_ui_components:
		if is_instance_valid(component):
			component.queue_free()
	
	battle_manager = null
	event_bus = null
	performance_optimizer = null
	mock_ui_components.clear()
	
	super.after_test()

## BASIC PERFORMANCE TESTS

func test_battle_initialization_performance() -> void:
	var test_mission = _create_test_mission()
	var test_crew = _create_test_crew(6) # Standard crew size
	var test_enemies = _create_test_enemies(8) # Large enemy force
	
	var start_time = Time.get_ticks_msec()
	
	var success = battle_manager.initialize_battle(test_mission, test_crew, test_enemies)
	
	var elapsed = Time.get_ticks_msec() - start_time
	
	assert_that(success).is_true()
	assert_that(elapsed).is_less(TARGET_FRAME_TIME) # Should complete within one frame
	print("Battle initialization time: %f ms" % elapsed)

func test_phase_transition_performance() -> void:
	var test_mission = _create_test_mission()
	var test_crew = _create_test_crew(4)
	var test_enemies = _create_test_enemies(4)
	
	battle_manager.initialize_battle(test_mission, test_crew, test_enemies)
	
	var transition_times: Array[float] = []
	
	# Test each possible transition
	var phases = [
		FPCM_BattleManager.BattlePhase.TACTICAL_BATTLE,
		FPCM_BattleManager.BattlePhase.BATTLE_RESOLUTION,
		FPCM_BattleManager.BattlePhase.POST_BATTLE,
		FPCM_BattleManager.BattlePhase.BATTLE_COMPLETE
	]
	
	for phase in phases:
		var start_time = Time.get_ticks_msec()
		
		battle_manager.transition_to_phase(phase)
		
		var elapsed = Time.get_ticks_msec() - start_time
		transition_times.append(elapsed)
	
	# All transitions should be fast
	for transition_time in transition_times:
		assert_that(transition_time).is_less(TARGET_FRAME_TIME)
	
	var avg_time = transition_times.reduce(func(a, b): return a + b, 0.0) / transition_times.size()
	print("Average phase transition time: %f ms" % avg_time)

func test_battle_state_performance() -> void:
	var battle_state = FPCM_BattleState.new()
	track_node(battle_state)
	
	var test_mission = _create_test_mission()
	var test_crew = _create_test_crew(8) # Large crew
	var test_enemies = _create_test_enemies(12) # Large enemy force
	
	var start_time = Time.get_ticks_msec()
	
	battle_state.initialize_with_mission(test_mission, test_crew, test_enemies)
	
	var elapsed = Time.get_ticks_msec() - start_time
	
	assert_that(elapsed).is_less(TARGET_FRAME_TIME)
	print("Battle state initialization time: %f ms" % elapsed)

## UI COMPONENT PERFORMANCE TESTS

func test_ui_component_registration_performance() -> void:
	var start_time = Time.get_ticks_msec()
	
	# Register many UI components
	for i in range(50):
		var ui_component = _create_mock_ui_component("UI_" + str(i))
		battle_manager.register_ui_component("UI_" + str(i), ui_component)
	
	var elapsed = Time.get_ticks_msec() - start_time
	
	assert_that(elapsed).is_less(TARGET_FRAME_TIME * 2) # Allow 2 frames for many components
	assert_that(battle_manager.active_ui_components.size()).is_equal(50)
	print("UI component registration time: %f ms" % elapsed)

func test_ui_signal_emission_performance() -> void:
	# Register UI components with signal tracking
	var signal_count = 0
	for i in range(20):
		var ui_component = _create_mock_ui_component("UI_" + str(i))
		ui_component.add_user_signal("phase_completed")
		battle_manager.register_ui_component("UI_" + str(i), ui_component)
		ui_component.phase_completed.connect(func(): signal_count += 1)
	
	var start_time = Time.get_ticks_msec()
	
	# Emit signals from all components
	for i in range(20):
		var ui_component = mock_ui_components[i]
		ui_component.phase_completed.emit()
	
	await get_tree().process_frame
	
	var elapsed = Time.get_ticks_msec() - start_time
	
	assert_that(elapsed).is_less(TARGET_FRAME_TIME)
	assert_that(signal_count).is_equal(20)
	print("UI signal emission time: %f ms" % elapsed)

func test_event_bus_performance_under_load() -> void:
	# Register many components with event bus
	for i in range(30):
		var ui_component = _create_mock_ui_component("EventBusUI_" + str(i))
		event_bus.register_ui_component("EventBusUI_" + str(i), ui_component)
	
	var start_time = Time.get_ticks_msec()
	
	# Emit many signals through event bus
	for i in range(100):
		event_bus.battle_phase_changed.emit(0, 1)
		event_bus.battle_state_updated.emit(null)
		event_bus.dice_roll_completed.emit(null)
	
	await get_tree().process_frame
	
	var elapsed = Time.get_ticks_msec() - start_time
	
	assert_that(elapsed).is_less(TARGET_FRAME_TIME * 3) # Allow 3 frames for heavy load
	print("Event bus heavy load time: %f ms" % elapsed)

## PERFORMANCE OPTIMIZER TESTS

func test_performance_optimizer_functionality() -> void:
	# Register components with optimizer
	for i in range(10):
		var ui_component = _create_mock_ui_component("OptimizeUI_" + str(i))
		performance_optimizer.register_component("OptimizeUI_" + str(i), ui_component)
	
	var start_time = Time.get_ticks_msec()
	
	# Run performance check
	performance_optimizer.check_and_optimize_performance()
	
	var elapsed = Time.get_ticks_msec() - start_time
	
	assert_that(elapsed).is_less(TARGET_FRAME_TIME)
	print("Performance optimization time: %f ms" % elapsed)

func test_performance_level_switching() -> void:
	var start_time = Time.get_ticks_msec()
	
	# Test all performance levels
	var levels = [
		FPCM_BattlePerformanceOptimizer.PerformanceLevel.ULTRA,
		FPCM_BattlePerformanceOptimizer.PerformanceLevel.HIGH,
		FPCM_BattlePerformanceOptimizer.PerformanceLevel.MEDIUM,
		FPCM_BattlePerformanceOptimizer.PerformanceLevel.LOW,
		FPCM_BattlePerformanceOptimizer.PerformanceLevel.POTATO
	]
	
	for level in levels:
		performance_optimizer.set_performance_level(level)
	
	var elapsed = Time.get_ticks_msec() - start_time
	
	assert_that(elapsed).is_less(TARGET_FRAME_TIME)
	print("Performance level switching time: %f ms" % elapsed)

func test_emergency_performance_recovery() -> void:
	# Register many components
	for i in range(20):
		var ui_component = _create_mock_ui_component("EmergencyUI_" + str(i))
		performance_optimizer.register_component("EmergencyUI_" + str(i), ui_component)
	
	var start_time = Time.get_ticks_msec()
	
	# Trigger emergency recovery
	performance_optimizer.emergency_performance_recovery()
	
	var elapsed = Time.get_ticks_msec() - start_time
	
	assert_that(elapsed).is_less(TARGET_FRAME_TIME)
	assert_that(performance_optimizer.current_level).is_equal(FPCM_BattlePerformanceOptimizer.PerformanceLevel.POTATO)
	print("Emergency recovery time: %f ms" % elapsed)

## MEMORY PERFORMANCE TESTS

func test_memory_usage_during_battle() -> void:
	var initial_memory = Performance.get_monitor(Performance.OBJECT_COUNT)
	
	# Run complete battle cycle
	var test_mission = _create_test_mission()
	var test_crew = _create_test_crew(6)
	var test_enemies = _create_test_enemies(6)
	
	battle_manager.initialize_battle(test_mission, test_crew, test_enemies)
	
	# Register UI components
	for i in range(10):
		var ui_component = _create_mock_ui_component("MemoryUI_" + str(i))
		battle_manager.register_ui_component("MemoryUI_" + str(i), ui_component)
	
	# Run through all phases
	while battle_manager.is_active:
		battle_manager.advance_phase()
		await get_tree().process_frame
	
	# Emergency reset to clean up
	battle_manager.emergency_reset()
	await get_tree().process_frame
	
	var final_memory = Performance.get_monitor(Performance.OBJECT_COUNT)
	var memory_increase = final_memory - initial_memory
	
	# Should not leak significant memory
	assert_that(memory_increase).is_less(200) # Allow some variance
	print("Memory increase during battle: %d objects" % memory_increase)

func test_memory_leak_prevention() -> void:
	var initial_memory = OS.get_static_memory_usage_by_type()
	
	# Create and destroy many battle managers
	for cycle in range(10):
		var temp_manager = FPCM_BattleManager.new()
		var temp_mission = _create_test_mission()
		var temp_crew = _create_test_crew(4)
		var temp_enemies = _create_test_enemies(4)
		
		temp_manager.initialize_battle(temp_mission, temp_crew, temp_enemies)
		temp_manager.advance_phase()
		temp_manager.emergency_reset()
		
		temp_manager = null
		temp_mission = null
		temp_crew.clear()
		temp_enemies.clear()
		
		await get_tree().process_frame
	
	var final_memory = OS.get_static_memory_usage_by_type()
	var memory_increase = final_memory - initial_memory
	
	assert_that(memory_increase).is_less(MAX_MEMORY_INCREASE)
	print("Memory leak test - increase: %d bytes" % memory_increase)

## STRESS TESTS

func test_high_frequency_operations() -> void:
	var test_mission = _create_test_mission()
	var test_crew = _create_test_crew(4)
	var test_enemies = _create_test_enemies(4)
	
	battle_manager.initialize_battle(test_mission, test_crew, test_enemies)
	
	var start_time = Time.get_ticks_msec()
	var operation_count = 0
	
	# Perform rapid operations for one frame duration
	var frame_start = Time.get_ticks_msec()
	while Time.get_ticks_msec() - frame_start < TARGET_FRAME_TIME:
		# Rapid state queries
		battle_manager.get_battle_status()
		battle_manager.get_performance_stats()
		operation_count += 2
	
	var elapsed = Time.get_ticks_msec() - start_time
	var operations_per_ms = operation_count / elapsed
	
	assert_that(operations_per_ms).is_greater(10.0) # Should handle many ops per ms
	print("High frequency operations: %d ops in %f ms (%f ops/ms)" % [operation_count, elapsed, operations_per_ms])

func test_concurrent_ui_updates() -> void:
	# Create many UI components
	var ui_count = 25
	for i in range(ui_count):
		var ui_component = _create_mock_ui_component("ConcurrentUI_" + str(i))
		ui_component.add_user_signal("ui_update")
		battle_manager.register_ui_component("ConcurrentUI_" + str(i), ui_component)
	
	var start_time = Time.get_ticks_msec()
	
	# Trigger concurrent updates
	for i in range(ui_count):
		var ui_component = mock_ui_components[i]
		ui_component.ui_update.emit()
	
	# Process frame
	await get_tree().process_frame
	
	var elapsed = Time.get_ticks_msec() - start_time
	
	assert_that(elapsed).is_less(TARGET_FRAME_TIME * 2) # Allow 2 frames for many updates
	print("Concurrent UI updates time: %f ms" % elapsed)

func test_large_battlefield_performance() -> void:
	var battle_state = FPCM_BattleState.new()
	track_node(battle_state)
	
	# Create large battlefield
	battle_state.battlefield_size = Vector2i(50, 50)
	
	var test_mission = _create_test_mission()
	var test_crew = _create_test_crew(20) # Large crew
	var test_enemies = _create_test_enemies(30) # Large enemy force
	
	var start_time = Time.get_ticks_msec()
	
	battle_state.initialize_with_mission(test_mission, test_crew, test_enemies)
	
	# Perform many position updates
	var unit_ids = battle_state.unit_positions.keys()
	for i in range(1000):
		var unit_id = unit_ids[i % unit_ids.size()]
		var pos = Vector2i(i % 50, (i / 50) % 50)
		battle_state.update_unit_position(unit_id, pos)
	
	var elapsed = Time.get_ticks_msec() - start_time
	
	assert_that(elapsed).is_less(TARGET_FRAME_TIME * 10) # Allow multiple frames for large operations
	print("Large battlefield operations time: %f ms" % elapsed)

## FRAME TIMING TESTS

func test_consistent_frame_timing() -> void:
	var test_mission = _create_test_mission()
	var test_crew = _create_test_crew(6)
	var test_enemies = _create_test_enemies(6)
	
	battle_manager.initialize_battle(test_mission, test_crew, test_enemies)
	
	# Register moderate number of UI components
	for i in range(15):
		var ui_component = _create_mock_ui_component("TimingUI_" + str(i))
		battle_manager.register_ui_component("TimingUI_" + str(i), ui_component)
	
	var frame_times: Array[float] = []
	var measurement_frames = 30 # Measure for 30 frames
	
	for frame in range(measurement_frames):
		var frame_start = Time.get_ticks_msec()
		
		# Simulate frame operations
		battle_manager.get_battle_status()
		event_bus._check_performance()
		performance_optimizer.check_and_optimize_performance()
		
		await get_tree().process_frame
		
		var frame_time = Time.get_ticks_msec() - frame_start
		frame_times.append(frame_time)
	
	# Analyze frame timing consistency
	var avg_frame_time = frame_times.reduce(func(a, b): return a + b, 0.0) / frame_times.size()
	var max_frame_time = frame_times.max()
	var frame_time_variance = _calculate_variance(frame_times, avg_frame_time)
	
	assert_that(avg_frame_time).is_less(TARGET_FRAME_TIME)
	assert_that(max_frame_time).is_less(TARGET_FRAME_TIME * 2) # Allow occasional spikes
	assert_that(frame_time_variance).is_less(10.0) # Low variance for consistency
	
	print("Frame timing - Avg: %f ms, Max: %f ms, Variance: %f" % [avg_frame_time, max_frame_time, frame_time_variance])

func test_fps_stability_during_battle() -> void:
	var test_mission = _create_test_mission()
	var test_crew = _create_test_crew(4)
	var test_enemies = _create_test_enemies(4)
	
	battle_manager.initialize_battle(test_mission, test_crew, test_enemies)
	
	var fps_samples: Array[float] = []
	var sample_count = 20
	
	# Measure FPS during battle operations
	for sample in range(sample_count):
		# Perform battle operations
		battle_manager.advance_phase()
		if not battle_manager.is_active:
			battle_manager.initialize_battle(test_mission, test_crew, test_enemies)
		
		# Wait a bit and measure FPS
		await get_tree().process_frame
		await get_tree().process_frame
		
		var current_fps = Engine.get_frames_per_second()
		fps_samples.append(current_fps)
	
	var avg_fps = fps_samples.reduce(func(a, b): return a + b, 0.0) / fps_samples.size()
	var min_fps = fps_samples.min()
	
	assert_that(avg_fps).is_greater(TARGET_FPS - ACCEPTABLE_FPS_DROP)
	assert_that(min_fps).is_greater(TARGET_FPS - ACCEPTABLE_FPS_DROP * 2) # Allow bigger drops for min
	
	print("FPS stability - Avg: %f, Min: %f" % [avg_fps, min_fps])

## PERFORMANCE REGRESSION TESTS

func test_performance_metrics_collection() -> void:
	var metrics_start = Time.get_ticks_msec()
	
	var metrics = performance_optimizer.get_performance_metrics()
	
	var metrics_time = Time.get_ticks_msec() - metrics_start
	
	# Metrics collection should be very fast
	assert_that(metrics_time).is_less(5.0) # Should take less than 5ms
	
	# Verify metrics structure
	assert_that(metrics.has("current_fps")).is_true()
	assert_that(metrics.has("average_fps")).is_true()
	assert_that(metrics.has("current_memory")).is_true()
	assert_that(metrics.has("performance_level")).is_true()
	
	print("Performance metrics collection time: %f ms" % metrics_time)

func test_optimization_recommendations_performance() -> void:
	var start_time = Time.get_ticks_msec()
	
	var recommendations = performance_optimizer.get_optimization_recommendations()
	
	var elapsed = Time.get_ticks_msec() - start_time
	
	assert_that(elapsed).is_less(10.0) # Should be very fast
	assert_that(recommendations).is_not_null()
	
	print("Optimization recommendations time: %f ms" % elapsed)

## HELPER METHODS

func _start_performance_monitoring() -> void:
	# Initialize performance tracking
	frame_times.clear()
	memory_snapshots.clear()
	fps_measurements.clear()

func _create_test_mission() -> Resource:
	var mission = Resource.new()
	mission.set_meta("name", "Performance Test Mission")
	mission.set_meta("type", "stress_test")
	return mission

func _create_test_crew(size: int) -> Array[Resource]:
	var crew: Array[Resource] = []
	for i in range(size):
		var crew_member = Resource.new()
		crew_member.set_meta("id", "crew_" + str(i))
		crew_member.set_meta("name", "Crew " + str(i))
		crew_member.set_meta("health", 3)
		crew.append(crew_member)
	return crew

func _create_test_enemies(size: int) -> Array[Resource]:
	var enemies: Array[Resource] = []
	for i in range(size):
		var enemy = Resource.new()
		enemy.set_meta("id", "enemy_" + str(i))
		enemy.set_meta("name", "Enemy " + str(i))
		enemy.set_meta("health", 2)
		enemies.append(enemy)
	return enemies

func _create_mock_ui_component(name: String) -> Control:
	var ui_component = Control.new()
	ui_component.name = name
	mock_ui_components.append(ui_component)
	track_node(ui_component)
	return ui_component

func _calculate_variance(values: Array[float], mean: float) -> float:
	var sum_squared_diff = 0.0
	for value in values:
		var diff = value - mean
		sum_squared_diff += diff * diff
	return sum_squared_diff / values.size()