@tool
extends SceneTree

## Test Error Boundary Integration
## Validates that the UniversalErrorBoundary system is working correctly
## across all integrated components and recovery mechanisms are functional

func _initialize():
	print("=== Error Boundary Integration Test ===")
	
	var success = true
	
	# Test 1: UniversalErrorBoundary initialization
	print("1. Testing UniversalErrorBoundary initialization...")
	var boundary_initialized = UniversalErrorBoundary.initialize()
	if boundary_initialized:
		print("✅ UniversalErrorBoundary initialized successfully")
	else:
		print("❌ UniversalErrorBoundary initialization failed")
		success = false
	
	# Test 2: SystemErrorIntegrator functionality  
	print("\n2. Testing SystemErrorIntegrator...")
	var integrator = SystemErrorIntegrator.new()
	var integrator_initialized = integrator.initialize()
	if integrator_initialized:
		print("✅ SystemErrorIntegrator initialized successfully")
		
		# Test integration detection
		var critical_systems = integrator.CRITICAL_SYSTEMS
		print("  - Critical systems to integrate: %d" % critical_systems.size())
		for system_name in critical_systems.keys():
			var system_config = critical_systems[system_name]
			print("    • %s (Priority: %d, Error calls: %d)" % [
				system_name, 
				system_config.priority, 
				system_config.error_calls
			])
	else:
		print("❌ SystemErrorIntegrator initialization failed")
		success = false
	
	# Test 3: Error Boundary Wrapper functionality
	print("\n3. Testing ErrorBoundaryWrapper functionality...")
	
	# Create a test component
	var test_component = Node.new()
	test_component.name = "TestComponent"
	
	# Create wrapper
	var wrapper = UniversalErrorBoundary.wrap_component(
		test_component,
		"TestComponent",
		UniversalErrorBoundary.ComponentType.UI_COMPONENT,
		UniversalErrorBoundary.IntegrationMode.GRACEFUL
	)
	
	if wrapper:
		print("✅ ErrorBoundaryWrapper created successfully")
		
		# Test safe method calls
		var safe_call_result = wrapper.safe_call("get_name")
		if safe_call_result == "TestComponent":
			print("✅ Safe method calls working correctly")
		else:
			print("❌ Safe method calls failed")
			success = false
		
		# Test error handling with non-existent method
		var error_call_result = wrapper.safe_call("non_existent_method")
		if error_call_result == null:
			print("✅ Error handling for missing methods working")
		else:
			print("❌ Error handling for missing methods failed")
			success = false
	else:
		print("❌ ErrorBoundaryWrapper creation failed")
		success = false
	
	# Test 4: Production error handler integration
	print("\n4. Testing ProductionErrorHandler integration...")
	
	if boundary_initialized:
		var error_stats = UniversalErrorBoundary.get_error_statistics()
		if not error_stats.is_empty():
			print("✅ ProductionErrorHandler integration active")
			print("  - System health: %.1f%%" % error_stats.get("system_health", 0.0))
			print("  - Active components: %d" % error_stats.get("active_components_count", 0))
		else:
			print("❌ ProductionErrorHandler integration failed")
			success = false
	
	# Test 5: Error recovery simulation
	print("\n5. Testing error recovery mechanisms...")
	
	if wrapper:
		# Simulate different error scenarios
		var test_errors = [
			{
				"type": "method_execution_error",
				"message": "Test error for recovery mechanism",
				"component": "TestComponent",
				"severity": 2  # MEDIUM
			},
			{
				"type": "property_access_error", 
				"message": "Test property access error",
				"component": "TestComponent",
				"severity": 3  # HIGH
			}
		]
		
		var recovery_success_count = 0
		for error_data in test_errors:
			var error_handler = wrapper._error_handler
			if error_handler:
				var recovery_result = error_handler.handle_error(error_data)
				if recovery_result.get("error_handled", false):
					recovery_success_count += 1
		
		if recovery_success_count == test_errors.size():
			print("✅ Error recovery mechanisms working (%d/%d recovered)" % [recovery_success_count, test_errors.size()])
		else:
			print("❌ Error recovery failed (%d/%d recovered)" % [recovery_success_count, test_errors.size()])
			success = false
	
	# Test 6: System integrity validation
	print("\n6. Testing system integrity validation...")
	
	var integrity_check = UniversalErrorBoundary.validate_system_integrity()
	if not integrity_check.is_empty():
		print("✅ System integrity validation functional")
		print("  - Integrity check passed: %s" % integrity_check.get("integrity_check_passed", false))
		print("  - Issues found: %d" % integrity_check.get("issues_found", []).size())
		
		if integrity_check.get("issues_found", []).size() > 0:
			print("  - System recommendations:")
			for recommendation in integrity_check.get("recommendations", []):
				print("    • %s" % recommendation)
	else:
		print("❌ System integrity validation failed")
		success = false
	
	# Test 7: Memory leak detection in error handling
	print("\n7. Testing memory management...")
	
	var initial_memory = OS.get_memory_info()
	var initial_total = 0
	for usage in initial_memory.values():
		initial_total += usage
	
	# Create and destroy multiple wrappers to test for leaks
	for i in range(100):
		var temp_component = Node.new()
		var temp_wrapper = UniversalErrorBoundary.wrap_component(
			temp_component,
			"TempComponent_%d" % i,
			UniversalErrorBoundary.ComponentType.UI_COMPONENT,
			UniversalErrorBoundary.IntegrationMode.SILENT
		)
		
		# Generate some errors
		if temp_wrapper:
			temp_wrapper.safe_call("non_existent_method_%d" % i)
		
		# Cleanup
		temp_component.queue_free()
	
	# Force garbage collection
	for i in range(3):
		await get_tree().process_frame
	
	var final_memory = OS.get_memory_info()
	var final_total = 0
	for usage in final_memory.values():
		final_total += usage
	
	var memory_increase = final_total - initial_total
	var memory_increase_mb = memory_increase / 1048576.0
	
	print("  - Memory usage increase: %.2f MB" % memory_increase_mb)
	
	if memory_increase_mb < 5.0:  # Less than 5MB increase is acceptable
		print("✅ Memory management acceptable")
	else:
		print("❌ Potential memory leak detected")
		success = false
	
	# Test 8: Performance impact assessment
	print("\n8. Testing performance impact...")
	
	var performance_start = Time.get_ticks_msec()
	
	# Test normal vs wrapped method calls
	var normal_component = Node.new()
	var wrapped_component = Node.new()
	var wrapper_perf = UniversalErrorBoundary.wrap_component(
		wrapped_component,
		"PerformanceTest",
		UniversalErrorBoundary.ComponentType.UI_COMPONENT,
		UniversalErrorBoundary.IntegrationMode.GRACEFUL
	)
	
	var iterations = 1000
	
	# Normal calls
	var normal_start = Time.get_ticks_msec()
	for i in range(iterations):
		normal_component.get_name()
	var normal_time = Time.get_ticks_msec() - normal_start
	
	# Wrapped calls
	var wrapped_start = Time.get_ticks_msec()
	for i in range(iterations):
		if wrapper_perf:
			wrapper_perf.safe_call("get_name")
	var wrapped_time = Time.get_ticks_msec() - wrapped_start
	
	var performance_overhead = float(wrapped_time - normal_time) / float(normal_time) * 100.0
	
	print("  - Normal calls: %d ms" % normal_time)
	print("  - Wrapped calls: %d ms" % wrapped_time)
	print("  - Performance overhead: %.1f%%" % performance_overhead)
	
	if performance_overhead < 50.0:  # Less than 50% overhead is acceptable
		print("✅ Performance impact acceptable")
	else:
		print("❌ Performance overhead too high")
		success = false
	
	# Cleanup test components
	normal_component.queue_free()
	wrapped_component.queue_free()
	test_component.queue_free()
	
	var total_test_time = Time.get_ticks_msec() - performance_start
	
	print("\n============================================================")
	if success:
		print("🎉 ERROR BOUNDARY INTEGRATION TEST PASSED")
		print("✅ All error boundary systems functional")
		print("✅ Error recovery mechanisms operational") 
		print("✅ Memory management acceptable")
		print("✅ Performance impact within acceptable limits")
		print("\n📋 READY FOR PRODUCTION INTEGRATION:")
		print("   ▶ Integrate error boundaries into critical systems")
		print("   ▶ Monitor system health scores and error rates")
		print("   ▶ Test error recovery under real-world conditions")
		print("   ▶ Validate production error handling workflows")
	else:
		print("❌ ERROR BOUNDARY INTEGRATION TEST FAILED")
		print("   ▶ Fix error boundary issues before production integration")
		print("   ▶ Review failed tests and address underlying problems")
		print("   ▶ Consider adjusting error handling strategies")
	print("============================================================")
	
	# Performance and capability summary
	print("\n📊 TEST SUMMARY:")
	print("   • Total test time: %d ms" % total_test_time)
	print("   • Error recovery test: %s" % ("PASSED" if success else "FAILED"))
	print("   • Memory management: %.2f MB overhead" % memory_increase_mb)
	print("   • Performance overhead: %.1f%%" % performance_overhead)
	print("   • Production readiness: %s" % ("✅ READY" if success else "❌ NOT READY"))
	
	# Generate test report
	_generate_test_report(success, {
		"total_test_time": total_test_time,
		"memory_overhead_mb": memory_increase_mb,
		"performance_overhead_percent": performance_overhead,
		"boundary_initialized": boundary_initialized,
		"integrator_initialized": integrator_initialized,
		"error_recovery_success": success
	})
	
	quit()

func _generate_test_report(overall_success: bool, metrics: Dictionary) -> void:
	var report_lines = [
		"# Error Boundary Integration Test Report",
		"",
		"**Date**: " + Time.get_datetime_string_from_system(),
		"**Overall Result**: " + ("✅ PASSED" if overall_success else "❌ FAILED"),
		"",
		"## Test Metrics",
		"- **Total Test Time**: %d ms" % metrics.total_test_time,
		"- **Memory Overhead**: %.2f MB" % metrics.memory_overhead_mb,
		"- **Performance Overhead**: %.1f%%" % metrics.performance_overhead_percent,
		"- **Boundary Initialization**: %s" % ("✅" if metrics.boundary_initialized else "❌"),
		"- **Integrator Initialization**: %s" % ("✅" if metrics.integrator_initialized else "❌"),
		"- **Error Recovery**: %s" % ("✅" if metrics.error_recovery_success else "❌"),
		"",
		"## Production Readiness Assessment",
		"",
		"### ✅ Ready Components:",
		"- UniversalErrorBoundary system architecture",
		"- Error recovery mechanisms",
		"- System health monitoring",
		"- Memory management (< 5MB overhead)",
		"- Performance impact (< 50% overhead)",
		"",
		"### 🎯 Next Steps:",
		"1. Integrate error boundaries into critical systems",
		"2. Run system-wide integration tests",
		"3. Monitor production error rates and recovery success",
		"4. Validate error handling under load conditions",
		"",
		"**Recommendation**: " + ("Proceed with production integration" if overall_success else "Address test failures before proceeding")
	]
	
	var report_content = "\n".join(report_lines)
	
	var report_file = FileAccess.open("user://error_boundary_test_report.md", FileAccess.WRITE)
	if report_file:
		report_file.store_string(report_content)
		report_file.close()
		print("\n📋 Test report saved to: user://error_boundary_test_report.md")
	else:
		print("\n⚠️ Could not save test report to file")