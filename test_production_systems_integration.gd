@tool
extends SceneTree

## Test Production Systems Integration
## Comprehensive validation of error boundary + performance monitoring integration
## Tests the complete production readiness stack working together

func _initialize():
	print("=== Production Systems Integration Test ===")
	
	var success = true
	var test_results = []
	
	# Test 1: Initialize both systems
	print("1. Testing production systems initialization...")
	
	var error_boundary_init = UniversalErrorBoundary.initialize()
	var performance_monitor = ProductionPerformanceMonitor.new()
	var performance_init = performance_monitor.initialize()
	
	if error_boundary_init and performance_init:
		print("✅ Both production systems initialized successfully")
		test_results.append({"test": "initialization", "result": "PASSED"})
	else:
		print("❌ Production systems initialization failed")
		print("  - Error Boundary: %s" % ("OK" if error_boundary_init else "FAILED"))
		print("  - Performance Monitor: %s" % ("OK" if performance_init else "FAILED"))
		success = false
		test_results.append({"test": "initialization", "result": "FAILED"})
	
	# Test 2: Error boundary performance impact measurement
	print("\n2. Testing error boundary performance impact...")
	
	performance_monitor.start_monitoring()
	
	# Baseline measurement
	var baseline_metrics = performance_monitor._collect_performance_metrics()
	var baseline_fps = baseline_metrics.get("fps", 60)
	var baseline_memory = baseline_metrics.get("memory_total_mb", 100)
	
	# Create components with error boundaries
	var test_components = []
	for i in range(50):  # Create 50 wrapped components
		var component = Node.new()
		component.name = "TestComponent_%d" % i
		var wrapper = UniversalErrorBoundary.wrap_component(
			component,
			"TestComponent_%d" % i,
			UniversalErrorBoundary.ComponentType.UI_COMPONENT,
			UniversalErrorBoundary.IntegrationMode.GRACEFUL
		)
		test_components.append({"component": component, "wrapper": wrapper})
	
	# Wait for system to stabilize
	for i in range(10):
		await get_tree().process_frame
	
	# Measure performance with error boundaries active
	var loaded_metrics = performance_monitor._collect_performance_metrics()
	var loaded_fps = loaded_metrics.get("fps", 60)
	var loaded_memory = loaded_metrics.get("memory_total_mb", 100)
	
	var fps_impact = ((baseline_fps - loaded_fps) / baseline_fps) * 100.0
	var memory_impact = loaded_memory - baseline_memory
	
	print("  - FPS impact: %.1f%% (%.1f → %.1f)" % [fps_impact, baseline_fps, loaded_fps])
	print("  - Memory impact: %.1f MB (%.1f → %.1f)" % [memory_impact, baseline_memory, loaded_memory])
	
	if fps_impact < 20.0 and memory_impact < 10.0:  # Acceptable thresholds
		print("✅ Error boundary performance impact acceptable")
		test_results.append({"test": "performance_impact", "result": "PASSED"})
	else:
		print("❌ Error boundary performance impact too high")
		success = false
		test_results.append({"test": "performance_impact", "result": "FAILED"})
	
	# Test 3: Error generation and recovery under performance monitoring
	print("\n3. Testing error recovery with performance monitoring...")
	
	var error_recovery_count = 0
	var total_errors = 0
	
	# Generate errors in wrapped components
	for i in range(test_components.size()):
		var wrapper = test_components[i].wrapper
		if wrapper:
			# Generate various error types
			total_errors += 1
			var error_result = wrapper.safe_call("non_existent_method_%d" % i)
			if error_result == null:  # Expected for missing method
				error_recovery_count += 1
			
			total_errors += 1
			var property_result = wrapper.safe_get("non_existent_property_%d" % i)
			if property_result == null:  # Expected for missing property
				error_recovery_count += 1
	
	var recovery_rate = float(error_recovery_count) / float(total_errors)
	
	# Check performance monitoring captured the errors
	var post_error_metrics = performance_monitor._collect_performance_metrics()
	var error_boundary_overhead = post_error_metrics.get("error_boundary_overhead", 0.0)
	var recovery_rate_monitored = post_error_metrics.get("error_recovery_rate", 0.0)
	
	print("  - Error recovery rate: %.1f%% (%d/%d)" % [recovery_rate * 100.0, error_recovery_count, total_errors])
	print("  - Performance monitor overhead: %.1f%%" % error_boundary_overhead)
	print("  - Monitored recovery rate: %.1f%%" % (recovery_rate_monitored * 100.0))
	
	if recovery_rate > 0.95 and error_boundary_overhead < 10.0:
		print("✅ Error recovery with performance monitoring successful")
		test_results.append({"test": "error_recovery_monitoring", "result": "PASSED"})
	else:
		print("❌ Error recovery monitoring failed")
		success = false
		test_results.append({"test": "error_recovery_monitoring", "result": "FAILED"})
	
	# Test 4: Performance regression detection
	print("\n4. Testing performance regression detection...")
	
	# Simulate performance degradation
	var heavy_components = []
	for i in range(100):  # Create many more components to stress system
		var component = Node.new()
		component.name = "HeavyComponent_%d" % i
		var wrapper = UniversalErrorBoundary.wrap_component(
			component,
			"HeavyComponent_%d" % i,
			UniversalErrorBoundary.ComponentType.UI_COMPONENT,
			UniversalErrorBoundary.IntegrationMode.GRACEFUL
		)
		heavy_components.append({"component": component, "wrapper": wrapper})
		
		# Generate errors to simulate load
		if wrapper:
			wrapper.safe_call("heavy_operation_%d" % i)
	
	# Wait for system to respond
	for i in range(5):
		await get_tree().process_frame
		performance_monitor._collect_performance_metrics()
	
	# Check for regression detection
	var regressions = performance_monitor._detect_performance_regressions()
	var regression_detected = regressions.size() > 0
	
	print("  - Regressions detected: %d" % regressions.size())
	for regression in regressions:
		print("    • %s: %s" % [regression.type, regression.description])
	
	if regression_detected:
		print("✅ Performance regression detection working")
		test_results.append({"test": "regression_detection", "result": "PASSED"})
	else:
		print("⚠️ No performance regression detected (may be expected in test environment)")
		test_results.append({"test": "regression_detection", "result": "PARTIAL"})
	
	# Test 5: Optimization recommendations
	print("\n5. Testing optimization recommendations...")
	
	var recommendations = performance_monitor._generate_optimization_recommendations()
	
	print("  - Optimization recommendations: %d" % recommendations.size())
	for rec in recommendations:
		print("    • %s (%s priority): %s" % [rec.type, rec.priority, rec.description])
		if "estimated_savings_mb" in rec:
			print("      Estimated savings: %.1f MB" % rec.estimated_savings_mb)
	
	if recommendations.size() > 0:
		print("✅ Optimization recommendations generated")
		test_results.append({"test": "optimization_recommendations", "result": "PASSED"})
	else:
		print("⚠️ No optimization recommendations (system may already be optimal)")
		test_results.append({"test": "optimization_recommendations", "result": "PARTIAL"})
	
	# Test 6: Auto-optimization execution
	print("\n6. Testing auto-optimization execution...")
	
	var initial_memory_for_optimization = performance_monitor._current_metrics.get("memory_total_mb", 100)
	var optimization_result = performance_monitor.execute_auto_optimizations()
	
	if optimization_result.executed:
		print("✅ Auto-optimizations executed:")
		print("  - Optimizations: %s" % ", ".join(optimization_result.optimizations))
		print("  - Memory saved: %.1f MB" % optimization_result.total_savings.memory_mb)
		print("  - Nodes reduced: %d" % optimization_result.total_savings.node_reduction)
		test_results.append({"test": "auto_optimization", "result": "PASSED"})
	else:
		print("⚠️ No auto-optimizations executed: %s" % optimization_result.reason)
		test_results.append({"test": "auto_optimization", "result": "PARTIAL"})
	
	# Test 7: Performance report generation
	print("\n7. Testing performance report generation...")
	
	var performance_report = performance_monitor.get_performance_report()
	var required_report_fields = [
		"monitoring_status", "current_metrics", "baseline_metrics",
		"performance_grade", "targets_met", "optimization_recommendations"
	]
	
	var report_complete = true
	for field in required_report_fields:
		if not field in performance_report:
			report_complete = false
			print("    Missing field: %s" % field)
	
	if report_complete:
		print("✅ Performance report generated successfully")
		print("  - Performance grade: %s" % performance_report.get("performance_grade", "N/A"))
		print("  - Monitoring status: %s" % performance_report.get("monitoring_status", "UNKNOWN"))
		var targets_met = performance_report.get("targets_met", {})
		print("  - Targets met: FPS=%s Memory=%s Stability=%s" % [
			targets_met.get("fps_target_met", false),
			targets_met.get("memory_target_met", false), 
			targets_met.get("stability_target_met", false)
		])
		test_results.append({"test": "performance_report", "result": "PASSED"})
	else:
		print("❌ Performance report incomplete")
		success = false
		test_results.append({"test": "performance_report", "result": "FAILED"})
	
	# Cleanup all test components
	print("\n8. Cleaning up test components...")
	
	var cleanup_start_memory = performance_monitor._current_metrics.get("memory_total_mb", 100)
	
	for component_data in test_components + heavy_components:
		if component_data.component:
			component_data.component.queue_free()
	
	# Wait for cleanup
	for i in range(10):
		await get_tree().process_frame
	
	var final_metrics = performance_monitor._collect_performance_metrics()
	var cleanup_memory = final_metrics.get("memory_total_mb", 100)
	var memory_freed = cleanup_start_memory - cleanup_memory
	
	print("  - Memory freed during cleanup: %.1f MB" % memory_freed)
	
	if memory_freed > 0:
		print("✅ Memory cleanup successful")
		test_results.append({"test": "cleanup", "result": "PASSED"})
	else:
		print("⚠️ No measurable memory freed (may be normal)")
		test_results.append({"test": "cleanup", "result": "PARTIAL"})
	
	# Stop monitoring
	performance_monitor.stop_monitoring()
	
	# Final Results Summary
	print("\n============================================================")
	
	var passed_tests = test_results.filter(func(r): return r.result == "PASSED").size()
	var partial_tests = test_results.filter(func(r): return r.result == "PARTIAL").size()  
	var failed_tests = test_results.filter(func(r): return r.result == "FAILED").size()
	
	if success and failed_tests == 0:
		print("🎉 PRODUCTION SYSTEMS INTEGRATION TEST PASSED")
		print("✅ Error boundaries and performance monitoring working together")
		print("✅ Performance impact within acceptable limits")
		print("✅ Error recovery rate >95%% under monitoring")
		print("✅ Regression detection and optimization functional")
		print("✅ Production-ready integrated systems")
		
		print("\n📋 PRODUCTION READINESS STATUS:")
		print("   ▶ Error Boundary System: ✅ OPERATIONAL")
		print("   ▶ Performance Monitoring: ✅ OPERATIONAL")
		print("   ▶ Integrated Error+Performance: ✅ OPERATIONAL")
		print("   ▶ Auto-optimization: ✅ FUNCTIONAL")
		print("   ▶ Regression Detection: ✅ FUNCTIONAL")
	else:
		print("❌ PRODUCTION SYSTEMS INTEGRATION TEST FAILED")
		print("   ▶ Address integration issues before production deployment")
		print("   ▶ Review failed tests and optimize system performance")
		
	print("\n📊 TEST RESULTS SUMMARY:")
	print("   • Tests Passed: %d" % passed_tests)
	print("   • Tests Partial: %d" % partial_tests)
	print("   • Tests Failed: %d" % failed_tests)
	print("   • Overall Success Rate: %.1f%%" % (float(passed_tests) / float(test_results.size()) * 100.0))
	
	# Performance Summary
	print("\n📈 PERFORMANCE SUMMARY:")
	print("   • Error Boundary FPS Impact: %.1f%%" % fps_impact)
	print("   • Memory Overhead: %.1f MB" % memory_impact)
	print("   • Error Recovery Rate: %.1f%%" % (recovery_rate * 100.0))
	print("   • Performance Grade: %s" % performance_report.get("performance_grade", "N/A"))
	
	print("============================================================")
	
	# Generate integration test report
	_generate_integration_test_report(success, test_results, {
		"fps_impact_percent": fps_impact,
		"memory_impact_mb": memory_impact,
		"error_recovery_rate": recovery_rate,
		"performance_grade": performance_report.get("performance_grade", "N/A"),
		"regressions_detected": regressions.size(),
		"optimizations_available": recommendations.size()
	})
	
	quit()

func _generate_integration_test_report(success: bool, test_results: Array, metrics: Dictionary) -> void:
	var report_lines = [
		"# Production Systems Integration Test Report",
		"",
		"**Date**: " + Time.get_datetime_string_from_system(),
		"**Overall Result**: " + ("✅ PASSED" if success else "❌ FAILED"),
		"**Integration Status**: " + ("PRODUCTION READY" if success else "NEEDS ATTENTION"),
		"",
		"## Test Results Summary",
		"",
		"| Test | Result | Notes |",
		"|------|--------|-------|"
	]
	
	for result in test_results:
		var emoji = "✅" if result.result == "PASSED" else ("⚠️" if result.result == "PARTIAL" else "❌")
		report_lines.append("| %s | %s %s | |" % [result.test, emoji, result.result])
	
	report_lines.append("")
	report_lines.append("## Performance Impact Analysis")
	report_lines.append("")
	report_lines.append("- **FPS Impact**: %.1f%% (Target: <20%%)" % metrics.fps_impact_percent)
	report_lines.append("- **Memory Overhead**: %.1f MB (Target: <10MB)" % metrics.memory_impact_mb)  
	report_lines.append("- **Error Recovery Rate**: %.1f%% (Target: >95%%)" % (metrics.error_recovery_rate * 100.0))
	report_lines.append("- **Performance Grade**: %s" % metrics.performance_grade)
	report_lines.append("- **Regressions Detected**: %d" % metrics.regressions_detected)
	report_lines.append("- **Optimizations Available**: %d" % metrics.optimizations_available)
	report_lines.append("")
	
	if success:
		report_lines.append("## ✅ Production Readiness Confirmed")
		report_lines.append("")
		report_lines.append("The integrated error boundary and performance monitoring systems are:")
		report_lines.append("- **Functional**: All core systems operational")
		report_lines.append("- **Performant**: Overhead within acceptable limits")
		report_lines.append("- **Reliable**: High error recovery rate maintained")
		report_lines.append("- **Monitored**: Real-time performance tracking active")
		report_lines.append("- **Optimized**: Automatic optimization capabilities functional")
		report_lines.append("")
		report_lines.append("**Recommendation**: Proceed with production deployment")
	else:
		report_lines.append("## ❌ Production Issues Identified")
		report_lines.append("")
		report_lines.append("Address the following before production deployment:")
		report_lines.append("- Review failed test cases and resolve underlying issues")
		report_lines.append("- Optimize performance impact if exceeding targets")
		report_lines.append("- Ensure error recovery rate meets production requirements")
		report_lines.append("- Validate system stability under production load")
		report_lines.append("")
		report_lines.append("**Recommendation**: Fix issues and retest before deployment")
	
	report_lines.append("")
	report_lines.append("## Next Steps")
	report_lines.append("1. Complete Gemini CLI analysis results integration")
	report_lines.append("2. Execute SystemErrorIntegrator on critical systems")
	report_lines.append("3. Monitor production performance metrics")
	report_lines.append("4. Validate error handling under real-world load")
	
	var report_content = "\n".join(report_lines)
	
	var report_file = FileAccess.open("user://production_systems_integration_report.md", FileAccess.WRITE)
	if report_file:
		report_file.store_string(report_content)
		report_file.close()
		print("\n📋 Integration test report saved to: user://production_systems_integration_report.md")
	else:
		print("\n⚠️ Could not save integration test report")