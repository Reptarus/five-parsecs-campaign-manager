@tool
extends EditorScript

# Remove the missing file dependencies
var _gut: Node
var _start_time: int
var _peak_memory: int
var _test_results := {}

func _run() -> void:
	print("Starting test run...")
	_start_time = Time.get_ticks_msec()
	_peak_memory = Performance.get_monitor(Performance.MEMORY_STATIC)
	
	# Simple test runner without GUT dependencies
	print("Test runner placeholder - implement actual test execution")
	_on_tests_finished()

func _on_test_finished(script: GDScript, test_name: String, passed: bool) -> void:
	var result := {
		"passed": passed,
		"duration": 0, # Would be actual test time
		"memory": Performance.get_monitor(Performance.MEMORY_STATIC)
	}
	
	_test_results[script.resource_path + "::" + test_name] = result
	_peak_memory = max(_peak_memory, result.memory)

func _on_tests_finished() -> void:
	var end_time := Time.get_ticks_msec()
	var duration := (end_time - _start_time) / 1000.0
	
	# Generate report
	var report := _generate_report(duration)
	
	# Create reports directory if it doesn't exist
	var dir := DirAccess.open("res://tests")
	if dir and not dir.dir_exists("reports"):
		dir.make_dir("reports")
	
	# Save report
	var file := FileAccess.open("res://tests/reports/test_run_%d.md" % Time.get_unix_time_from_system(), FileAccess.WRITE)
	if file:
		file.store_string(report)
		file.close()
	
	print("Test run complete! Report saved.")
	
	# Exit editor if running from command line
	if OS.has_feature("editor"):
		get_editor_interface().get_editor_main_screen().get_tree().quit()

func _generate_report(duration: float) -> String:
	var total_tests := _test_results.size()
	var passed_tests := 0
	var failed_tests := 0
	var error_tests := 0
	var pending_tests := 0
	
	var failures: Array[String] = []
	var errors: Array[String] = []
	var performance_issues: Array[String] = []
	
	for test_path in _test_results:
		var result: Dictionary = _test_results[test_path]
		
		if result.passed:
			passed_tests += 1
		else:
			failed_tests += 1
			failures.append("- " + test_path)
		
		# Check for performance issues
		if result.duration > 1000: # More than 1 second
			performance_issues.append("- %s took %.2fs" % [test_path, result.duration / 1000.0])
	
	# Calculate metrics
	var coverage := (passed_tests / float(total_tests)) * 100 if total_tests > 0 else 0.0
	var avg_test_time := duration * 1000 / total_tests if total_tests > 0 else 0.0
	
	# Generate recommendations
	var recommendations: Array[String] = []
	if failed_tests > 0:
		recommendations.append("- Fix failing tests first")
	if performance_issues.size() > 0:
		recommendations.append("- Optimize slow tests")
	if coverage < 80:
		recommendations.append("- Increase test coverage")
	
	# Format report
	return """# Test Run Report
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
		"recommendations": "\n".join(recommendations) if recommendations else "None"
	})