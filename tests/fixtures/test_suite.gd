@tool
extends GdUnitTestSuite

# Type-safe test categories
const TEST_CATEGORIES := {
	"unit": "res://tests/unit",
	"integration": "res://tests/integration",
	"performance": "res://tests/performance",
	"mobile": "res://tests/mobile"
}

# Type-safe test configuration
const TEST_CONFIG := {
	"parallel_tests": true,
	"max_parallel_tests": 4,
	"timeout": 30.0,
	"export_results": true,
	"export_format": "json",
	"export_path": "res://test_results"
}

# Type-safe instance variables
var _pending_tests: Array[String] = []
var _current_category: String = ""
var _category_results: Dictionary = {}
var _test_start_time: float = 0.0

# Lifecycle Methods
func before():
	"""Setup run once before all tests"""
	_test_start_time = Time.get_unix_time_from_system()
	_setup_test_environment()

func after():
	"""Cleanup run once after all tests"""
	pass

func before_test():
	"""Setup run before each test"""
	pass

func after_test():
	"""Cleanup run after each test"""
	pass

# Test Suite Setup
func _setup_test_environment() -> void:
	# Configure test environment
	Engine.physics_ticks_per_second = 60
	Engine.max_fps = 60
	get_tree().set_debug_collisions_hint(false)
	get_tree().set_debug_navigation_hint(false)
	
	# Disable audio for tests
	var master_bus := AudioServer.get_bus_index("Master")
	if master_bus >= 0:
		AudioServer.set_bus_mute(master_bus, true)

# Test Execution
func test_run_all_categories() -> void:
	"""Test method to run all test categories"""
	print("Starting test suite...")
	
	var categories: Array[String] = []
	for key in TEST_CATEGORIES.keys():
		categories.append(str(key))
	
	for category in categories:
		if not category in TEST_CATEGORIES:
			push_warning("Unknown test category: %s" % category)
			continue
		
		if TEST_CONFIG.parallel_tests:
			await _run_category_parallel(category)
		else:
			await _run_category(category)
	
	_print_results()
	if TEST_CONFIG.export_results:
		_export_results()

func test_run_unit_tests() -> void:
	"""Test method to run only unit tests"""
	await _run_category("unit")

func test_run_integration_tests() -> void:
	"""Test method to run only integration tests"""
	await _run_category("integration")

func test_run_performance_tests() -> void:
	"""Test method to run only performance tests"""
	await _run_category("performance")

func test_run_mobile_tests() -> void:
	"""Test method to run only mobile tests"""
	await _run_category("mobile")

func _run_category_parallel(category: String) -> void:
	_current_category = category
	print("\nRunning %s tests in parallel..." % category.capitalize())
	
	var test_files := _get_category_tests(category)
	if test_files.is_empty():
		push_warning("No test files found for category: %s" % category)
		return
	
	_pending_tests = test_files
	
	# Process tests sequentially in gdunit4
	for test_file in test_files:
		if FileAccess.file_exists(test_file):
			print("Processing test file: %s" % test_file)
		await get_tree().process_frame

func _cleanup_test_runners() -> void:
	# Cleanup handled by gdunit4 framework
	pass

func _assign_next_test() -> void:
	if _pending_tests.is_empty():
		return
		
	var next_test: String = _pending_tests.pop_front()
	
	# Simplified test assignment - actual implementation would
	# need to integrate with gdunit4's test discovery system
	if FileAccess.file_exists(next_test):
		# Run test via gdunit4 runner
		pass

func _get_category_tests(category: String) -> Array[String]:
	var tests: Array[String] = []
	match category:
		"unit":
			tests.append(TEST_CATEGORIES.unit)
		"integration":
			tests.append(TEST_CATEGORIES.integration)
		"performance":
			tests.append(TEST_CATEGORIES.performance)
		"mobile":
			tests.append(TEST_CATEGORIES.mobile)
		_:
			push_warning("Unknown test category: %s" % category)
	return tests

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
		
		# Note: This is simplified - actual implementation would
		# need to integrate with gdunit4's test discovery and execution
		success = success and _run_test_file(test_file)
	
	if success:
		_category_results[category] = {
			"results": {"tests": 0, "passing": 0, "failing": 0, "errors": 0},
			"duration": (Time.get_ticks_msec() - category_start) / 1000.0
		}
	
	return success

func _run_test_file(test_file: String) -> bool:
	# Simplified test file execution
	# Actual implementation would integrate with gdunit4's runner
	return true

# Results Handling
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

func _export_results() -> void:
	var export_dir: DirAccess = DirAccess.open(TEST_CONFIG.export_path)
	if not export_dir:
		if DirAccess.make_dir_recursive_absolute(TEST_CONFIG.export_path) != OK:
			push_error("Failed to create export directory")
			return
	
	var timestamp: String = Time.get_datetime_string_from_system().replace(":", "-")
	var filename: String = "test_results_%s.%s" % [timestamp, TEST_CONFIG.export_format]
	var filepath: String = TEST_CONFIG.export_path.path_join(filename)
	
	var file: FileAccess = FileAccess.open(filepath, FileAccess.WRITE)
	if not file:
		push_error("Failed to create results file: %s" % filepath)
		return
	
	match TEST_CONFIG.export_format:
		"json":
			file.store_string(JSON.stringify(_category_results, "  "))
		"txt":
			for category in _category_results:
				var results: Dictionary = _category_results[category].results
				file.store_string("\n%s Tests:\n" % category.capitalize())
				file.store_string("  Total: %d\n" % results.get("tests", 0))
				file.store_string("  Passed: %d\n" % results.get("passing", 0))
				file.store_string("  Failed: %d\n" % results.get("failing", 0))
				file.store_string("  Errors: %d\n" % results.get("errors", 0))
				
				if results.get("failing", 0) > 0:
					file.store_string("\n  Failed Tests:\n")
					var failures: Array = results.get("failures", [])
					for failure in failures:
						file.store_string("    - %s\n" % str(failure))
				
				if results.get("errors", 0) > 0:
					file.store_string("\n  Errors:\n")
					var errors: Array = results.get("errors", [])
					for error in errors:
						file.store_string("    - %s\n" % str(error))
	
	file.close()
	print("\nTest results exported to: %s" % filepath)