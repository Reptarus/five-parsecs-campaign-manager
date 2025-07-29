extends GdUnitTestSuite

## Integration Performance & Stress Testing Suite
## Tests UI-backend integration under stress conditions
## Validates memory usage, performance degradation, and error recovery

const UIBackendIntegrationValidator = preload("res://src/core/validation/UIBackendIntegrationValidator.gd")
const ValidationErrorBoundary = preload("res://src/core/validation/ValidationErrorBoundary.gd")
const IntegrationHealthMonitor = preload("res://src/core/monitoring/IntegrationHealthMonitor.gd")

## Test configuration
const STRESS_TEST_ITERATIONS = 100
const LARGE_CREW_SIZE = 8
const EXTENDED_CAMPAIGN_TURNS = 20
const PERFORMANCE_THRESHOLD_MS = 100
const MEMORY_LEAK_THRESHOLD_KB = 1024  # 1MB

## Test fixtures
var test_scene: Node
var health_monitor: IntegrationHealthMonitor
var performance_data: Dictionary = {}
var memory_snapshots: Array[Dictionary] = []
var stress_test_results: Array[Dictionary] = []

func before_test() -> void:
	"""Setup stress testing environment"""
	print("=== Integration Performance Test Setup ===")
	
	# Create test scene
	test_scene = Node.new()
	test_scene.name = "StressTestScene"
	add_child(test_scene)
	
	# Initialize health monitor
	health_monitor = IntegrationHealthMonitor.new()
	health_monitor.name = "TestHealthMonitor"
	test_scene.add_child(health_monitor)
	
	# Initialize performance tracking
	performance_data = {
		"operation_times": {},
		"memory_usage": {},
		"error_counts": {},
		"throughput_metrics": {}
	}
	
	# Take initial memory snapshot
	_take_memory_snapshot("initial")
	
	print("Integration Performance: Stress test setup complete")

func after_test() -> void:
	"""Cleanup after stress testing"""
	# Take final memory snapshot
	_take_memory_snapshot("final")
	
	# Generate performance report
	_generate_performance_report()
	
	if test_scene:
		test_scene.queue_free()
	
	print("Integration Performance: Stress test cleanup complete")

func _take_memory_snapshot(label: String) -> void:
	"""Take a memory usage snapshot"""
	var snapshot = {
		"label": label,
		"timestamp": Time.get_ticks_msec(),
		"static_memory": Performance.get_monitor(Performance.MEMORY_STATIC),
		"dynamic_memory": Performance.get_monitor(Performance.MEMORY_DYNAMIC),
		"static_max": Performance.get_monitor(Performance.MEMORY_STATIC_MAX),
		"dynamic_max": Performance.get_monitor(Performance.MEMORY_DYNAMIC_MAX)
	}
	memory_snapshots.append(snapshot)
	print("Memory snapshot [%s]: Static=%d KB, Dynamic=%d KB" % [
		label, 
		snapshot.static_memory / 1024, 
		snapshot.dynamic_memory / 1024
	])

func _generate_performance_report() -> String:
	"""Generate comprehensive performance report"""
	var report = "# Integration Performance & Stress Test Report\n\n"
	
	# Memory usage analysis
	report += "## Memory Usage Analysis\n"
	if memory_snapshots.size() >= 2:
		var initial = memory_snapshots[0]
		var final = memory_snapshots[-1]
		var static_delta = final.static_memory - initial.static_memory
		var dynamic_delta = final.dynamic_memory - initial.dynamic_memory
		
		report += "- Static Memory Change: %+d KB\n" % (static_delta / 1024)
		report += "- Dynamic Memory Change: %+d KB\n" % (dynamic_delta / 1024)
		report += "- Total Memory Change: %+d KB\n\n" % ((static_delta + dynamic_delta) / 1024)
	
	# Performance metrics
	report += "## Performance Metrics\n"
	for operation in performance_data.operation_times.keys():
		var times = performance_data.operation_times[operation]
		if times.size() > 0:
			var avg_time = _calculate_average(times)
			var max_time = times.max()
			var min_time = times.min()
			report += "- %s: Avg=%.1fms, Min=%dms, Max=%dms\n" % [operation, avg_time, min_time, max_time]
	
	report += "\n"
	
	# Error analysis
	report += "## Error Analysis\n"
	for error_type in performance_data.error_counts.keys():
		report += "- %s: %d occurrences\n" % [error_type, performance_data.error_counts[error_type]]
	
	print(report)
	return report

func _calculate_average(values: Array) -> float:
	"""Calculate average of numeric array"""
	if values.is_empty():
		return 0.0
	var sum = 0.0
	for value in values:
		sum += value
	return sum / values.size()

func _record_operation_time(operation: String, duration_ms: int) -> void:
	"""Record operation timing"""
	if not performance_data.operation_times.has(operation):
		performance_data.operation_times[operation] = []
	performance_data.operation_times[operation].append(duration_ms)

func _record_error(error_type: String) -> void:
	"""Record error occurrence"""
	if not performance_data.error_counts.has(error_type):
		performance_data.error_counts[error_type] = 0
	performance_data.error_counts[error_type] += 1

## PHASE 1: Backend System Stress Tests

func test_backend_system_load_stress():
	"""Test backend systems under high load conditions"""
	print("Starting backend system load stress test...")
	
	var operations_completed = 0
	var errors_encountered = 0
	var start_time = Time.get_ticks_msec()
	
	# Stress test backend system availability checking
	for i in range(STRESS_TEST_ITERATIONS):
		var iteration_start = Time.get_ticks_msec()
		
		var health_results = ValidationErrorBoundary.validate_integration_health([
			"SimpleCharacterCreator",
			"StartingEquipmentGenerator", 
			"ContactManager",
			"PlanetDataManager",
			"RivalBattleGenerator"
		])
		
		var iteration_duration = Time.get_ticks_msec() - iteration_start
		_record_operation_time("backend_health_check", iteration_duration)
		
		# Count successful operations
		for result in health_results:
			if result.success:
				operations_completed += 1
			else:
				errors_encountered += 1
				_record_error("backend_unavailable")
		
		# Brief pause to prevent overwhelming the system
		if i % 10 == 0:
			await get_tree().process_frame
			_take_memory_snapshot("stress_iteration_%d" % i)
	
	var total_duration = Time.get_ticks_msec() - start_time
	var operations_per_second = float(STRESS_TEST_ITERATIONS * 5) / (float(total_duration) / 1000.0)  # 5 systems per iteration
	
	# Performance validation
	var avg_operation_time = _calculate_average(performance_data.operation_times.get("backend_health_check", []))
	assert_that(avg_operation_time).is_less_than(PERFORMANCE_THRESHOLD_MS).override_failure_message(
		"Average backend health check time %.1fms exceeds threshold %dms" % [avg_operation_time, PERFORMANCE_THRESHOLD_MS]
	)
	
	# Error rate validation (should be low for available systems)
	var error_rate = float(errors_encountered) / float(operations_completed + errors_encountered)
	assert_that(error_rate).is_less_than(0.1).override_failure_message(
		"Error rate %.2f exceeds 10%%" % error_rate
	)
	
	print("✅ Backend system load stress test passed")
	print("  Operations completed: %d" % operations_completed)
	print("  Errors encountered: %d" % errors_encountered)
	print("  Operations per second: %.1f" % operations_per_second)
	print("  Average operation time: %.1fms" % avg_operation_time)

func test_crew_generation_stress():
	"""Test crew generation under stress conditions"""
	print("Starting crew generation stress test...")
	
	var successful_generations = 0
	var failed_generations = 0
	var total_characters_generated = 0
	
	# Test rapid crew generation cycles
	for i in range(50):  # 50 cycles of crew generation
		var cycle_start = Time.get_ticks_msec()
		
		var crew_result = ValidationErrorBoundary.safe_crew_generation(
			LARGE_CREW_SIZE,  # Generate large crews
			null,
			ValidationErrorBoundary.ValidationErrorMode.GRACEFUL
		)
		
		var cycle_duration = Time.get_ticks_msec() - cycle_start
		_record_operation_time("crew_generation_large", cycle_duration)
		
		if crew_result.success:
			successful_generations += 1
			if crew_result.fallback_data is Array:
				total_characters_generated += crew_result.fallback_data.size()
		else:
			failed_generations += 1
			_record_error("crew_generation_failed")
		
		# Memory check every 10 iterations
		if i % 10 == 0:
			await get_tree().process_frame
		
		# Performance degradation check
		if cycle_duration > PERFORMANCE_THRESHOLD_MS * 3:  # 3x threshold
			_record_error("performance_degradation")
	
	# Validate stress test results
	var success_rate = float(successful_generations) / float(successful_generations + failed_generations)
	assert_that(success_rate).is_greater_than(0.8).override_failure_message(
		"Crew generation success rate %.2f below 80%%" % success_rate
	)
	
	var avg_generation_time = _calculate_average(performance_data.operation_times.get("crew_generation_large", []))
	assert_that(avg_generation_time).is_less_than(PERFORMANCE_THRESHOLD_MS * 2).override_failure_message(
		"Average crew generation time %.1fms exceeds threshold %dms" % [avg_generation_time, PERFORMANCE_THRESHOLD_MS * 2]
	)
	
	print("✅ Crew generation stress test passed")
	print("  Successful generations: %d" % successful_generations)
	print("  Failed generations: %d" % failed_generations)
	print("  Total characters generated: %d" % total_characters_generated)
	print("  Average generation time: %.1fms" % avg_generation_time)

func test_equipment_generation_stress():
	"""Test equipment generation under stress conditions"""
	print("Starting equipment generation stress test...")
	
	var successful_generations = 0
	var failed_generations = 0
	var total_equipment_generated = 0
	
	# Create mock crew for equipment generation
	var mock_large_crew: Array = []
	for i in range(LARGE_CREW_SIZE):
		mock_large_crew.append({
			"character_name": "Stress Test Character %d" % (i + 1),
			"combat": 3,
			"toughness": 3,
			"tech": 2
		})
	
	# Test rapid equipment generation cycles
	for i in range(30):  # 30 cycles of equipment generation
		var cycle_start = Time.get_ticks_msec()
		
		var equipment_result = ValidationErrorBoundary.safe_equipment_generation(
			mock_large_crew,
			null,
			ValidationErrorBoundary.ValidationErrorMode.GRACEFUL
		)
		
		var cycle_duration = Time.get_ticks_msec() - cycle_start
		_record_operation_time("equipment_generation_large", cycle_duration)
		
		if equipment_result.success:
			successful_generations += 1
			if equipment_result.fallback_data is Dictionary:
				var equipment_data = equipment_result.fallback_data
				if equipment_data.has("equipment") and equipment_data.equipment is Array:
					total_equipment_generated += equipment_data.equipment.size()
		else:
			failed_generations += 1
			_record_error("equipment_generation_failed")
		
		# Memory check every 10 iterations
		if i % 10 == 0:
			await get_tree().process_frame
	
	# Validate stress test results
	var success_rate = float(successful_generations) / float(successful_generations + failed_generations)
	assert_that(success_rate).is_greater_than(0.8).override_failure_message(
		"Equipment generation success rate %.2f below 80%%" % success_rate
	)
	
	var avg_generation_time = _calculate_average(performance_data.operation_times.get("equipment_generation_large", []))
	assert_that(avg_generation_time).is_less_than(PERFORMANCE_THRESHOLD_MS * 3).override_failure_message(
		"Average equipment generation time %.1fms exceeds threshold %dms" % [avg_generation_time, PERFORMANCE_THRESHOLD_MS * 3]
	)
	
	print("✅ Equipment generation stress test passed")
	print("  Successful generations: %d" % successful_generations)
	print("  Failed generations: %d" % failed_generations)
	print("  Total equipment generated: %d" % total_equipment_generated)
	print("  Average generation time: %.1fms" % avg_generation_time)

## PHASE 2: Memory Leak Detection Tests

func test_memory_leak_detection():
	"""Test for memory leaks during repeated operations"""
	print("Starting memory leak detection test...")
	
	_take_memory_snapshot("leak_test_start")
	
	# Perform repeated operations that could cause memory leaks
	for cycle in range(20):
		print("  Memory leak test cycle %d/20" % (cycle + 1))
		
		# Create and destroy multiple components
		var temp_nodes: Array[Node] = []
		
		for i in range(10):
			# Create temporary components
			var temp_node = Node.new()
			temp_node.name = "TempNode_%d_%d" % [cycle, i]
			temp_nodes.append(temp_node)
			test_scene.add_child(temp_node)
			
			# Simulate backend integration validator usage
			var validation_results = UIBackendIntegrationValidator.validate_backend_system_health()
			
			# Simulate error boundary usage
			var error_result = ValidationErrorBoundary.safe_backend_call(
				temp_node,
				"nonexistent_method",
				[],
				null,
				1000,
				ValidationErrorBoundary.ValidationErrorMode.SILENT
			)
		
		# Clean up temporary nodes
		for node in temp_nodes:
			node.queue_free()
		
		# Force garbage collection
		await get_tree().process_frame
		await get_tree().process_frame
		
		# Take memory snapshot every 5 cycles
		if cycle % 5 == 0:
			_take_memory_snapshot("leak_test_cycle_%d" % cycle)
	
	_take_memory_snapshot("leak_test_end")
	
	# Analyze memory usage trend
	if memory_snapshots.size() >= 3:
		var start_snapshot = memory_snapshots[0]
		var end_snapshot = memory_snapshots[-1]
		
		var static_delta = end_snapshot.static_memory - start_snapshot.static_memory
		var dynamic_delta = end_snapshot.dynamic_memory - start_snapshot.dynamic_memory
		var total_delta = static_delta + dynamic_delta
		
		# Memory increase should be within acceptable threshold
		assert_that(total_delta / 1024).is_less_than(MEMORY_LEAK_THRESHOLD_KB).override_failure_message(
			"Memory increase %d KB exceeds leak threshold %d KB" % [total_delta / 1024, MEMORY_LEAK_THRESHOLD_KB]
		)
		
		print("✅ Memory leak detection test passed")
		print("  Static memory change: %+d KB" % (static_delta / 1024))
		print("  Dynamic memory change: %+d KB" % (dynamic_delta / 1024))
		print("  Total memory change: %+d KB" % (total_delta / 1024))
	else:
		print("⚠️ Insufficient memory snapshots for leak analysis")

func test_concurrent_operation_stress():
	"""Test concurrent backend operations"""
	print("Starting concurrent operation stress test...")
	
	var concurrent_operations: Array[Callable] = []
	var operation_results: Array = []
	var start_time = Time.get_ticks_msec()
	
	# Create multiple concurrent operations
	for i in range(10):
		# Each "concurrent" operation will be a deferred call
		var operation_callable = func():
			var op_start = Time.get_ticks_msec()
			
			# Simulate concurrent health checks
			var health_result = ValidationErrorBoundary.validate_integration_health()
			
			# Simulate concurrent crew generation
			var crew_result = ValidationErrorBoundary.safe_crew_generation(4)
			
			var op_duration = Time.get_ticks_msec() - op_start
			return {"duration": op_duration, "health_success": health_result.size() > 0, "crew_success": crew_result.success}
		
		concurrent_operations.append(operation_callable)
	
	# Execute operations with small delays to simulate concurrency
	for i in range(concurrent_operations.size()):
		var operation = concurrent_operations[i]
		
		# Start operation
		var result = operation.call()
		operation_results.append(result)
		_record_operation_time("concurrent_operation", result.duration)
		
		# Small delay to simulate concurrent access
		await get_tree().process_frame
	
	var total_duration = Time.get_ticks_msec() - start_time
	
	# Validate concurrent operation results
	var successful_operations = 0
	for result in operation_results:
		if result.health_success and result.crew_success:
			successful_operations += 1
	
	var success_rate = float(successful_operations) / float(operation_results.size())
	assert_that(success_rate).is_greater_than(0.8).override_failure_message(
		"Concurrent operation success rate %.2f below 80%%" % success_rate
	)
	
	var avg_concurrent_time = _calculate_average(performance_data.operation_times.get("concurrent_operation", []))
	assert_that(avg_concurrent_time).is_less_than(PERFORMANCE_THRESHOLD_MS * 4).override_failure_message(
		"Average concurrent operation time %.1fms exceeds threshold %dms" % [avg_concurrent_time, PERFORMANCE_THRESHOLD_MS * 4]
	)
	
	print("✅ Concurrent operation stress test passed")
	print("  Successful operations: %d/%d" % [successful_operations, operation_results.size()])
	print("  Total duration: %dms" % total_duration)
	print("  Average operation time: %.1fms" % avg_concurrent_time)

## PHASE 3: Extended Campaign Simulation

func test_extended_campaign_simulation():
	"""Test extended campaign with many turns for stability"""
	print("Starting extended campaign simulation (%d turns)..." % EXTENDED_CAMPAIGN_TURNS)
	
	_take_memory_snapshot("extended_campaign_start")
	
	var successful_turns = 0
	var failed_turns = 0
	var performance_degradation_detected = false
	
	# Simulate extended campaign
	for turn in range(1, EXTENDED_CAMPAIGN_TURNS + 1):
		var turn_start = Time.get_ticks_msec()
		
		print("  Simulating turn %d/%d..." % [turn, EXTENDED_CAMPAIGN_TURNS])
		
		# Simulate turn workflow with backend integration
		var turn_successful = true
		
		# Phase 1: World Phase Backend Operations
		var world_phase_start = Time.get_ticks_msec()
		var contact_results = ValidationErrorBoundary.validate_integration_health(["ContactManager", "PlanetDataManager"])
		var world_phase_duration = Time.get_ticks_msec() - world_phase_start
		_record_operation_time("world_phase_extended", world_phase_duration)
		
		if contact_results.is_empty():
			turn_successful = false
			_record_error("world_phase_failed")
		
		# Phase 2: Battle Phase Backend Operations
		var battle_phase_start = Time.get_ticks_msec()
		var rival_results = ValidationErrorBoundary.validate_integration_health(["RivalBattleGenerator"])
		var battle_phase_duration = Time.get_ticks_msec() - battle_phase_start
		_record_operation_time("battle_phase_extended", battle_phase_duration)
		
		if rival_results.is_empty():
			turn_successful = false
			_record_error("battle_phase_failed")
		
		var total_turn_duration = Time.get_ticks_msec() - turn_start
		_record_operation_time("complete_turn_extended", total_turn_duration)
		
		# Check for performance degradation
		if total_turn_duration > PERFORMANCE_THRESHOLD_MS * 5:  # 5x threshold for complete turn
			performance_degradation_detected = true
			_record_error("turn_performance_degradation")
		
		if turn_successful:
			successful_turns += 1
		else:
			failed_turns += 1
		
		# Memory check every 5 turns
		if turn % 5 == 0:
			await get_tree().process_frame
			_take_memory_snapshot("extended_campaign_turn_%d" % turn)
		
		# Brief pause between turns
		await get_tree().create_timer(0.01).timeout
	
	_take_memory_snapshot("extended_campaign_end")
	
	# Validate extended campaign results
	var turn_success_rate = float(successful_turns) / float(EXTENDED_CAMPAIGN_TURNS)
	assert_that(turn_success_rate).is_greater_than(0.9).override_failure_message(
		"Extended campaign turn success rate %.2f below 90%%" % turn_success_rate
	)
	
	var avg_turn_time = _calculate_average(performance_data.operation_times.get("complete_turn_extended", []))
	assert_that(avg_turn_time).is_less_than(PERFORMANCE_THRESHOLD_MS * 5).override_failure_message(
		"Average extended turn time %.1fms exceeds threshold %dms" % [avg_turn_time, PERFORMANCE_THRESHOLD_MS * 5]
	)
	
	# Check memory stability over extended run
	if memory_snapshots.size() >= 2:
		var campaign_start = memory_snapshots[0]
		var campaign_end = memory_snapshots[-1]
		var total_memory_delta = (campaign_end.static_memory + campaign_end.dynamic_memory) - (campaign_start.static_memory + campaign_start.dynamic_memory)
		
		# Memory growth should be reasonable for extended campaign
		assert_that(total_memory_delta / 1024).is_less_than(MEMORY_LEAK_THRESHOLD_KB * 2).override_failure_message(
			"Extended campaign memory growth %d KB exceeds threshold %d KB" % [total_memory_delta / 1024, MEMORY_LEAK_THRESHOLD_KB * 2]
		)
	
	print("✅ Extended campaign simulation test passed")
	print("  Successful turns: %d/%d" % [successful_turns, EXTENDED_CAMPAIGN_TURNS])
	print("  Failed turns: %d" % failed_turns)
	print("  Average turn time: %.1fms" % avg_turn_time)
	print("  Performance degradation detected: %s" % ("Yes" % "No")[!performance_degradation_detected])

## PHASE 4: Error Recovery and Resilience Tests

func test_error_recovery_resilience():
	"""Test system resilience and error recovery"""
	print("Starting error recovery resilience test...")
	
	var recovery_test_results: Array[Dictionary] = []
	
	# Test different error scenarios
	var error_scenarios = [
		{"name": "null_object_error", "target": null, "method": "test_method"},
		{"name": "missing_method_error", "target": Node.new(), "method": "nonexistent_method"},
		{"name": "timeout_simulation", "target": Node.new(), "method": "has_method"}  # This will work but we'll simulate timeout
	]
	
	for scenario in error_scenarios:
		print("  Testing error scenario: %s" % scenario.name)
		
		var scenario_start = Time.get_ticks_msec()
		
		# Test error boundary handling
		var error_result = ValidationErrorBoundary.safe_backend_call(
			scenario.target,
			scenario.method,
			[],
			"fallback_value",
			50,  # Short timeout to trigger timeout errors
			ValidationErrorBoundary.ValidationErrorMode.GRACEFUL
		)
		
		var scenario_duration = Time.get_ticks_msec() - scenario_start
		
		var test_result = {
			"scenario": scenario.name,
			"duration_ms": scenario_duration,
			"handled_gracefully": error_result != null,
			"fallback_used": error_result.fallback_data == "fallback_value",
			"error_logged": not error_result.success
		}
		
		recovery_test_results.append(test_result)
		_record_operation_time("error_recovery", scenario_duration)
		
		# Clean up scenario objects
		if scenario.target is Node and scenario.target != null:
			scenario.target.queue_free()
	
	# Validate error recovery results
	var graceful_handling_count = 0
	var fallback_usage_count = 0
	
	for result in recovery_test_results:
		if result.handled_gracefully:
			graceful_handling_count += 1
		if result.fallback_used:
			fallback_usage_count += 1
	
	# All error scenarios should be handled gracefully
	assert_that(graceful_handling_count).is_equal(error_scenarios.size()).override_failure_message(
		"Only %d/%d error scenarios handled gracefully" % [graceful_handling_count, error_scenarios.size()]
	)
	
	# Fallback values should be used when appropriate
	assert_that(fallback_usage_count).is_greater_than(0).override_failure_message(
		"No fallback values used in error scenarios"
	)
	
	var avg_recovery_time = _calculate_average(performance_data.operation_times.get("error_recovery", []))
	assert_that(avg_recovery_time).is_less_than(PERFORMANCE_THRESHOLD_MS).override_failure_message(
		"Average error recovery time %.1fms exceeds threshold %dms" % [avg_recovery_time, PERFORMANCE_THRESHOLD_MS]
	)
	
	print("✅ Error recovery resilience test passed")
	print("  Graceful handling: %d/%d scenarios" % [graceful_handling_count, error_scenarios.size()])
	print("  Fallback usage: %d scenarios" % fallback_usage_count)
	print("  Average recovery time: %.1fms" % avg_recovery_time)

## PHASE 5: Health Monitor Stress Testing

func test_health_monitor_stress():
	"""Test integration health monitor under stress"""
	print("Starting health monitor stress test...")
	
	# Enable rapid health monitoring
	health_monitor.set_check_interval(100)  # 100ms intervals
	health_monitor.set_monitoring_enabled(true)
	
	# Run stress test for 5 seconds
	var stress_start_time = Time.get_ticks_msec()
	var stress_duration_ms = 5000
	
	var health_change_count = 0
	var last_health_status = health_monitor.get_overall_health_status()
	
	# Monitor health changes during stress test
	while Time.get_ticks_msec() - stress_start_time < stress_duration_ms:
		# Simulate system load
		var temp_operations: Array[ValidationErrorBoundary.ValidationErrorResult] = ValidationErrorBoundary.validate_integration_health()
		
		# Check for health status changes
		var current_health = health_monitor.get_overall_health_status()
		if current_health != last_health_status:
			health_change_count += 1
			last_health_status = current_health
		
		await get_tree().create_timer(0.05).timeout  # 50ms intervals
	
	# Get final health summary
	var health_summary = health_monitor.get_health_summary()
	
	# Generate performance report
	var performance_report = health_monitor.get_performance_report()
	
	# Validate health monitor performance
	assert_that(health_summary.total_systems).is_greater_than(0).override_failure_message(
		"Health monitor not tracking any systems"
	)
	
	assert_that(health_summary.average_response_time).is_less_than(PERFORMANCE_THRESHOLD_MS * 2).override_failure_message(
		"Health monitor average response time %.1fms exceeds threshold %dms" % [health_summary.average_response_time, PERFORMANCE_THRESHOLD_MS * 2]
	)
	
	print("✅ Health monitor stress test passed")
	print("  Monitoring duration: %dms" % stress_duration_ms)
	print("  Health status changes: %d" % health_change_count)
	print("  Systems monitored: %d" % health_summary.total_systems)
	print("  Average response time: %.1fms" % health_summary.average_response_time)
	print("  Final health status: %s" % health_summary.overall_status)
	
	print("\nHealth Monitor Performance Report:")
	print(performance_report)

## PHASE 6: Comprehensive Stress Test Summary

func test_comprehensive_stress_summary():
	"""Run comprehensive stress test summary and validation"""
	print("Running comprehensive stress test summary...")
	
	# Run all stress tests in sequence (abbreviated versions)
	print("  Running abbreviated stress test suite...")
	
	# Quick backend stress test
	var quick_health_results = ValidationErrorBoundary.validate_integration_health()
	var backend_available = quick_health_results.filter(func(r): return r.success).size()
	
	# Quick memory test
	_take_memory_snapshot("comprehensive_start")
	for i in range(10):
		var temp_result = ValidationErrorBoundary.safe_crew_generation(4)
		await get_tree().process_frame
	_take_memory_snapshot("comprehensive_end")
	
	# Calculate overall performance metrics
	var total_operations = 0
	var total_errors = 0
	var total_duration_ms = 0
	
	for operation_type in performance_data.operation_times.keys():
		var times = performance_data.operation_times[operation_type]
		total_operations += times.size()
		for time in times:
			total_duration_ms += time
	
	for error_type in performance_data.error_counts.keys():
		total_errors += performance_data.error_counts[error_type]
	
	# Generate comprehensive report
	var comprehensive_report = _generate_performance_report()
	
	# Final validations
	var overall_success_rate = float(total_operations - total_errors) / float(max(1, total_operations))
	assert_that(overall_success_rate).is_greater_than(0.8).override_failure_message(
		"Overall stress test success rate %.2f below 80%%" % overall_success_rate
	)
	
	var avg_operation_time = float(total_duration_ms) / float(max(1, total_operations))
	assert_that(avg_operation_time).is_less_than(PERFORMANCE_THRESHOLD_MS * 3).override_failure_message(
		"Average operation time %.1fms exceeds threshold %dms" % [avg_operation_time, PERFORMANCE_THRESHOLD_MS * 3]
	)
	
	# Memory stability check
	if memory_snapshots.size() >= 2:
		var start_memory = memory_snapshots[0]
		var end_memory = memory_snapshots[-1]
		var memory_growth = (end_memory.static_memory + end_memory.dynamic_memory) - (start_memory.static_memory + start_memory.dynamic_memory)
		
		assert_that(memory_growth / 1024).is_less_than(MEMORY_LEAK_THRESHOLD_KB).override_failure_message(
			"Memory growth %d KB exceeds threshold %d KB" % [memory_growth / 1024, MEMORY_LEAK_THRESHOLD_KB]
		)
	
	print("✅ Comprehensive stress test summary passed")
	print("  Total operations: %d" % total_operations)
	print("  Total errors: %d" % total_errors)
	print("  Overall success rate: %.2f%%" % (overall_success_rate * 100))
	print("  Average operation time: %.1fms" % avg_operation_time)
	print("  Backend systems available: %d" % backend_available)
	
	print("\n" + comprehensive_report)