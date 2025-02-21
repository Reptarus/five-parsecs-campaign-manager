@tool
extends EditorScript

const GutRunner := preload("res://addons/gut/gut_cmdln.gd")
const TEST_DIRS := [
	"res://tests/unit",
	"res://tests/integration",
	"res://tests/performance",
	"res://tests/mobile"
]

const REPORT_TEMPLATE := """# Test Run Report
Generated:{datetime}

## Summary
- Total Tests:{total_tests}
- Passed:{passed_tests}
- Failed:{failed_tests}
- Errors:{error_tests}
- Pending:{pending_tests}
- Coverage:{coverage}%

## Performance
- Total Duration:{duration}s
- Average Test Time:{avg_test_time}ms
- Peak Memory:{peak_memory}MB

## Failures
{failures}

## Errors
{errors}

## Performance Issues
{performance_issues}

## Recommendations
{recommendations}
"""

var _gut: GutRunner
var _start_time: int
var _peak_memory: int
var _test_results := {}

func _run() -> void:
	print("Starting test run...")
	_start_time = Time.get_ticks_msec()
	_peak_memory = Performance.get_monitor(Performance.MEMORY_STATIC)
	
	# Initialize GUT
	_gut = await GutRunner.new()
	_gut.set_should_exit(true)
	_gut.set_should_maximize(true)
	_gut.set_include_subdirectories(true)
	_gut.set_unit_test_name("*test_*.gd")
	
	# Add test directories
	for dir in TEST_DIRS:
		_gut.add_directory(dir)
	
	# Connect signals
	_gut.connect("tests_finished", _on_tests_finished)
	_gut.connect("test_finished", _on_test_finished)
	
	# Run tests
	_gut.test_scripts()

func _on_test_finished(script: GDScript, test_name: String, passed: bool) -> void:
	var result = {
		"passed": passed,
		"duration": _gut.get_test_time(),
		"memory": Performance.get_monitor(Performance.MEMORY_STATIC)
	}
	
	_test_results[script.resource_path + "::" + test_name] = result
	_peak_memory = max(_peak_memory, result.memory)

func _on_tests_finished() -> void:
	var end_time = Time.get_ticks_msec()
	var duration = (end_time - _start_time) / 1000.0
	
	# Generate report
	var report = _generate_report(duration)
	
	# Save report
	var file = FileAccess.open("res://tests/reports/test_run_%d.md" % Time.get_unix_time_from_system(), FileAccess.WRITE)
	if file:
		file.store_string(report)
		file.close()
	
	print("Test run complete! Report saved.")
	
	# Exit editor if running from command line
	if Engine.is_editor_hint():
		EditorInterface.get_editor_main_screen().get_tree().quit()

func _generate_report(duration: float) -> String:
	var total_tests := _test_results.size()
	var passed_tests := 0
	var failed_tests := 0
	var error_tests := 0
	var pending_tests := 0
	
	var failures := []
	var errors := []
	var performance_issues := []
	
	for test_path in _test_results:
		var result = _test_results[test_path]
		
		if result.passed:
			passed_tests += 1
		else:
			failed_tests += 1
			failures.append("- " + test_path)
		
		# Check for performance issues
		if result.duration > 1000: # More than 1 second
			performance_issues.append("- %s took %.2fs" % [test_path, result.duration / 1000.0])
	
	# Calculate metrics
	var coverage = (passed_tests / float(total_tests)) * 100 if total_tests > 0 else 0
	var avg_test_time = duration * 1000 / total_tests if total_tests > 0 else 0
	
	# Generate recommendations
	var recommendations = []
	if failed_tests > 0:
		recommendations.append("- Fix failing tests first")
	if performance_issues.size() > 0:
		recommendations.append("- Optimize slow tests")
	if coverage < 80:
		recommendations.append("- Increase test coverage")
	
	# Format report
	return REPORT_TEMPLATE.format({
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