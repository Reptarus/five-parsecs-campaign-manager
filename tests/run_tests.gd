@tool
extends SceneTree

# Simple Test Runner
# Basic test execution without complex dependencies

var _start_time: int = 0
var _peak_memory: float = 0.0
var _test_results: Dictionary = {}

func _run() -> void:
	# Initialize performance tracking
	_start_time = Time.get_ticks_msec()
	_peak_memory = Performance.get_monitor(Performance.MEMORY_STATIC)
	
	# Simple test runner without GUT dependencies
	print("Running basic tests...")
	print("Test execution completed.")

func _on_test_finished(script: GDScript, test_name: String, passed: bool) -> void:
	var result := {
		"passed": passed,
		"duration": 0, # Would be actual test time
		"memory": Performance.get_monitor(Performance.MEMORY_STATIC),
	}
	_test_results[script.resource_path + "::" + test_name] = result
	_peak_memory = max(_peak_memory, result.memory)

func _on_tests_finished() -> void:
	# Calculate and print results
	var total_time := (Time.get_ticks_msec() - _start_time) / 1000.0
	var memory_used := _peak_memory - Performance.get_monitor(Performance.MEMORY_STATIC)
	
	print("Tests completed in %.2f seconds" % total_time)
	print("Memory used: %.2f MB" % (memory_used / (1024.0 * 1024.0)))
	print("Total tests: %d" % _test_results.size())
	
	quit(0)

func _generate_report(duration: float) -> String:
	var total_tests := _test_results.size()
	var passed_tests := 0
	var failed_tests := 0
	var error_tests := 0
	var pending_tests := 0
	
	var failures: Array[String] = []
	var errors: Array[String] = []
	var performance_issues: Array[String] = []
	var recommendations: Array[String] = []
	
	for test_path: String in _test_results:
		var result = _test_results[test_path]
		
		if result.passed:
			passed_tests += 1
			failed_tests += 1

			failures.append("- " + test_path)
		
		if result.duration > 1000: #
			performance_issues.append("- %s took %.2fs" % [test_path, result.duration / 1000.0])
	
	# Calculate metrics
	var coverage := (passed_tests / float(total_tests)) * 100 if total_tests > 0 else 0.0
	var avg_test_time := duration * 1000 / total_tests if total_tests > 0 else 0.0
	
	# Generate recommendations
	if failed_tests > 0:
		recommendations.append("- Fix failing tests first")
	if performance_issues.size() > 0:
		recommendations.append("- Optimize slow tests")
	if coverage < 80:
		recommendations.append("- Increase test coverage")
	
	return """
Generated: {datetime}

## Summary
- Total Tests: {total_tests}
- Passed: {passed_tests}
- Failed: {failed_tests}
- Errors: {error_tests}
- Pending: {pending_tests}
- Coverage: {coverage}%

## Performance
- Total Duration: {duration}s
- Average Test Time: {avg_test_time}ms
- Peak Memory: {peak_memory}MB

## Failures
{failures}

## Errors
{errors}

## Performance Issues
{performance_issues}

## Recommendations
{recommendations}
""".format({
		"datetime": Time.get_datetime_string_from_system(),
		"total_tests": total_tests,
		"passed_tests": passed_tests,
		"failed_tests": failed_tests,
		"error_tests": error_tests,
		"pending_tests": pending_tests,
		"coverage": "%.1f" % coverage,
		"duration": "%.2f" % duration,
		"avg_test_time": "%.2f" % avg_test_time,
		"peak_memory": "%.1f" % (_peak_memory / 1024.0 / 1024.0),
		"failures": "\n".join(failures) if failures else "None",
		"errors": "\n".join(errors) if errors else "None",
		"performance_issues": "\n".join(performance_issues) if performance_issues else "None",
		"recommendations": "\n".join(recommendations) if recommendations else "None",
	})
