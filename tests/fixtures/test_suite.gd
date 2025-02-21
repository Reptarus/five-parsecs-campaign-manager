@tool
extends Node
class_name TestRunner # Changed from TestSuite to avoid conflict with test.gd

# Use a different name to avoid shadowing
const GutRunnerScript: GDScript = preload("res://addons/gut/gut.gd")
const GutUtilsScript: GDScript = preload("res://addons/gut/utils.gd")

# Test Categories with type hints
const TEST_CATEGORIES: Dictionary = {
	"unit": "res://tests/unit",
	"integration": "res://tests/integration",
	"performance": "res://tests/performance",
	"mobile": "res://tests/mobile"
}

# Test configuration constants
const DEFAULT_LOG_LEVEL: int = 2
const DEFAULT_FONT_SIZE: int = 16
const DEFAULT_OPACITY: int = 100
const REPORT_DIR: String = "res://tests/reports"
const PARALLEL_TIMEOUT: float = 30.0
const MAX_PARALLEL_RUNNERS: int = 4

# Test Runner Configuration
var _gut: Node = null
var _current_category: String = ""
var _category_results: Dictionary = {}
var _parallel_runners: Array[Node] = []
var _pending_tests: Array[String] = []
var _active_test_count: int = 0
var _test_start_time: float = 0.0

# Signals - connect to these in _ready to avoid unused signal warning
signal tests_completed(success: bool)
signal category_completed(category: String, success: bool)

func _ready() -> void:
	# Connect signals to internal handlers to avoid unused signal warnings
	var err1 := tests_completed.connect(_on_tests_completed)
	var err2 := category_completed.connect(_on_category_completed)
	
	if err1 != OK or err2 != OK:
		push_error("Failed to connect test signals")
		return
	
	_test_start_time = Time.get_unix_time_from_system()
	
	if not _initialize_gut():
		push_error("Failed to initialize GUT. Aborting test execution.")
		return
		
	if not _ensure_report_directory():
		push_error("Failed to create report directory. Reports will not be saved.")
	
	# Parse command line arguments
	var args := OS.get_cmdline_args()
	var categories := _parse_categories(args)
	
	# Run tests based on configuration
	if _should_run_parallel(args):
		_run_tests_parallel.call_deferred(categories)
	else:
		_run_tests_sequential.call_deferred(categories)

func _on_tests_completed(success: bool) -> void:
	print("All tests completed with success: %s" % success)

func _on_category_completed(category: String, success: bool) -> void:
	print("Category %s completed with success: %s" % [category, success])

func _initialize_gut() -> bool:
	_gut = Node.new()
	if not _gut:
		push_error("Failed to create GUT instance")
		return false
		
	_gut.set_script(GutRunnerScript)
	if not _gut.get_script() == GutRunnerScript:
		push_error("Failed to set GutRunner script")
		return false
		
	add_child(_gut)
	
	# Configure GUT with proper method calls
	if _gut.has_method("set_should_print_to_console"):
		_gut.call("set_should_print_to_console", true)
	if _gut.has_method("set_log_level"):
		_gut.call("set_log_level", DEFAULT_LOG_LEVEL)
	if _gut.has_method("set_yield_between_tests"):
		_gut.call("set_yield_between_tests", true)
	if _gut.has_method("set_include_subdirectories"):
		_gut.call("set_include_subdirectories", true)
	if _gut.has_method("set_font"):
		_gut.call("set_font", "CourierPrime")
	if _gut.has_method("set_font_size"):
		_gut.call("set_font_size", DEFAULT_FONT_SIZE)
	if _gut.has_method("set_opacity"):
		_gut.call("set_opacity", DEFAULT_OPACITY)
	
	return true

func _ensure_report_directory() -> bool:
	var dir := DirAccess.open("res://")
	if not dir:
		push_error("Failed to access root directory")
		return false
		
	if not dir.dir_exists(REPORT_DIR):
		var err := dir.make_dir_recursive(REPORT_DIR)
		if err != OK:
			push_error("Failed to create report directory: %s" % error_string(err))
			return false
	return true

func _parse_categories(args: PackedStringArray) -> Array[String]:
	var categories: Array[String] = []
	
	for arg in args:
		if arg.begins_with("--category="):
			var category: String = arg.split("=")[1]
			if _is_valid_category(category):
				categories.append(category)
			else:
				push_warning("Invalid test category: %s" % category)
	
	# If no valid categories specified, run all
	if categories.is_empty():
		categories = ["unit", "integration", "performance", "mobile"]
	
	return categories

func _is_valid_category(category: String) -> bool:
	return category in ["unit", "integration", "performance", "mobile"]

func _should_run_parallel(args: PackedStringArray) -> bool:
	return "--parallel" in args

func _run_tests_sequential(categories: Array[String]) -> void:
	print("\nRunning tests sequentially...")
	
	var overall_success := true
	for category in categories:
		var success := _run_category(category)
		overall_success = overall_success and success
		category_completed.emit(category, success)
	
	_print_results()
	tests_completed.emit(overall_success)

func _run_tests_parallel(categories: Array[String]) -> void:
	print("\nRunning tests in parallel...")
	
	# Initialize test queue
	_pending_tests.clear()
	_active_test_count = 0
	for category in categories:
		_pending_tests.append_array(_get_category_tests(category))
	
	# Create parallel runners
	var num_runners := mini(OS.get_processor_count(), MAX_PARALLEL_RUNNERS)
	for i in range(num_runners):
		var runner := _create_parallel_runner()
		if runner:
			_parallel_runners.append(runner)
	
	if _parallel_runners.is_empty():
		push_error("Failed to create any parallel test runners. Falling back to sequential execution.")
		_run_tests_sequential.call_deferred(categories)
		return
	
	# Start parallel execution
	print("Starting %d parallel test runners..." % num_runners)
	for runner in _parallel_runners:
		_assign_next_test(runner)
	
	# Wait for completion with timeout
	var timeout := Time.get_unix_time_from_system() + PARALLEL_TIMEOUT
	while _active_test_count > 0 and Time.get_unix_time_from_system() < timeout:
		await get_tree().process_frame
	
	var success := _active_test_count == 0
	if not success:
		push_error("Parallel test execution timed out after %.1f seconds" % PARALLEL_TIMEOUT)
	
	_cleanup_parallel_runners()
	_print_results()
	tests_completed.emit(success)

func _create_parallel_runner() -> Node:
	var runner := _gut.duplicate()
	if not runner:
		push_error("Failed to create parallel test runner")
		return null
		
	var err := runner.connect("test_script_finished", _on_parallel_test_finished.bind(runner))
	if err != OK:
		push_error("Failed to connect test_script_finished signal")
		return null
		
	add_child(runner)
	return runner

func _cleanup_parallel_runners() -> void:
	for runner in _parallel_runners:
		if is_instance_valid(runner):
			runner.queue_free()
	_parallel_runners.clear()

func _assign_next_test(runner: Node) -> void:
	if _pending_tests.is_empty() or not runner:
		return
		
	if not runner.has_method("add_script") or not runner.has_method("test_scripts"):
		push_error("Runner missing required methods")
		return
		
	var next_test: String = _pending_tests.pop_front()
	_active_test_count += 1
	runner.call("add_script", next_test)
	runner.call("test_scripts")

func _on_parallel_test_finished(runner: Node) -> void:
	_active_test_count -= 1
	
	if not runner.has_method("get_test_results"):
		push_error("Runner missing get_test_results method")
		return
		
	var results: Dictionary = {}
	var raw_results = runner.call("get_test_results")
	if raw_results is Dictionary:
		results = raw_results
	
	if results.is_empty():
		push_warning("Empty test results received")
		return
		
	var elapsed: float = 0.0
	if results.has("elapsed"):
		elapsed = results.elapsed as float
	
	_category_results[_current_category] = {
		"results": results,
		"duration": elapsed
	}
	
	_assign_next_test(runner)

func _get_category_tests(category: String) -> Array[String]:
	match category:
		"unit":
			return [TEST_CATEGORIES["unit"]]
		"integration":
			return [TEST_CATEGORIES["integration"]]
		"performance":
			return [TEST_CATEGORIES["performance"]]
		"mobile":
			return [TEST_CATEGORIES["mobile"]]
		_:
			push_warning("Unknown test category: %s" % category)
			return []

func _run_category(category: String) -> bool:
	_current_category = category
	print("\nRunning %s tests..." % category.capitalize())
	
	var test_files := _get_category_tests(category)
	if test_files.is_empty():
		push_warning("No test files found for category: %s" % category)
		return false
	
	var category_start := Time.get_ticks_msec()
	var success := true
	
	for test_file in test_files:
		if not FileAccess.file_exists(test_file):
			push_error("Test file not found: %s" % test_file)
			success = false
			continue
		
		_gut.add_script(test_file)
	
	if success:
		_gut.test_scripts()
		
		_category_results[category] = {
			"results": _gut.get_test_results(),
			"duration": (Time.get_ticks_msec() - category_start) / 1000.0
		}
	
	return success

func _print_results() -> void:
	print("\n=== Test Results ===")
	
	var total_tests := 0
	var total_passed := 0
	var total_failed := 0
	var total_errors := 0
	var total_duration := 0.0
	
	for category in _category_results:
		var result_data: Dictionary = _category_results[category]
		var results: Dictionary = result_data.get("results", {})
		var duration: float = result_data.get("duration", 0.0)
		
		if results.is_empty():
			push_warning("Missing test results for category: %s" % category)
			continue
		
		var test_count := results.get("tests", 0) as int
		var pass_count := results.get("passing", 0) as int
		var fail_count := results.get("failing", 0) as int
		var error_count := results.get("errors", 0) as int
		
		print("\n%s Tests:" % category.capitalize())
		print("  Duration: %.2f seconds" % duration)
		print("  Total: %d" % test_count)
		print("  Passed: %d" % pass_count)
		print("  Failed: %d" % fail_count)
		print("  Errors: %d" % error_count)
		
		total_tests += test_count
		total_passed += pass_count
		total_failed += fail_count
		total_errors += error_count
		total_duration += duration
	
	var total_time := Time.get_unix_time_from_system() - _test_start_time
	print("\nOverall Results:")
	print("  Total Time: %.2f seconds" % total_time)
	print("  Test Duration: %.2f seconds" % total_duration)
	print("  Total Tests: %d" % total_tests)
	print("  Total Passed: %d" % total_passed)
	print("  Total Failed: %d" % total_failed)
	print("  Total Errors: %d" % total_errors)
	print("  Success Rate: %.1f%%" % (float(total_passed) / total_tests * 100 if total_tests > 0 else 0.0))
	
	# Export results if there were failures or if explicitly requested
	if total_failed > 0 or total_errors > 0 or "--export-results" in OS.get_cmdline_args():
		_export_results()

func _export_results() -> void:
	var timestamp := Time.get_datetime_string_from_system().replace(":", "-")
	var report_path := "%s/test_report_%s.txt" % [REPORT_DIR, timestamp]
	
	var report := FileAccess.open(report_path, FileAccess.WRITE)
	if not report:
		push_error("Failed to create test report file")
		return
		
	report.store_string("Test Report - %s\n\n" % timestamp)
	report.store_string("Test Environment:\n")
	report.store_string("  OS: %s\n" % OS.get_name())
	report.store_string("  CPU Cores: %d\n" % OS.get_processor_count())
	report.store_string("  Engine Version: %s\n\n" % Engine.get_version_info().string)
	
	for category in _category_results:
		var result_data: Dictionary = _category_results[category]
		var results: Dictionary = result_data.get("results", {})
		var duration: float = result_data.get("duration", 0.0)
		
		if results.is_empty():
			continue
		
		var test_count := results.get("tests", 0) as int
		var pass_count := results.get("passing", 0) as int
		var fail_count := results.get("failing", 0) as int
		var error_count := results.get("errors", 0) as int
		
		report.store_string("%s Tests:\n" % category.capitalize())
		report.store_string("  Duration: %.2f seconds\n" % duration)
		report.store_string("  Total: %d\n" % test_count)
		report.store_string("  Passed: %d\n" % pass_count)
		report.store_string("  Failed: %d\n" % fail_count)
		report.store_string("  Errors: %d\n\n" % error_count)
		
		# Store failure details
		if fail_count > 0:
			report.store_string("  Failed Tests:\n")
			var failures: Array = results.get("failures", [])
			for failure in failures:
				report.store_string("    - %s\n" % str(failure))
			report.store_string("\n")
		
		# Store error details
		if error_count > 0:
			report.store_string("  Errors:\n")
			var errors: Array = results.get("errors", [])
			for error in errors:
				report.store_string("    - %s\n" % str(error))
			report.store_string("\n")
	
	report.close()
	print("\nTest report exported to: %s" % report_path)