@tool
extends Node

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
var _gut: Node = null
var _parallel_runners: Array[Node] = []
var _pending_tests: Array[String] = []
var _active_test_count: int = 0
var _current_category: String = ""
var _category_results: Dictionary = {}
var _test_start_time: float = 0.0

# Lifecycle Methods
func _init() -> void:
	_test_start_time = Time.get_unix_time_from_system()

func _ready() -> void:
	_initialize_gut()
	_setup_test_environment()

func _exit_tree() -> void:
	_cleanup_parallel_runners()

# Test Suite Setup
func _initialize_gut() -> void:
	_gut = preload("res://addons/gut/gut.gd").new()
	if not _gut:
		push_error("Failed to create GUT instance")
		return
	
	add_child(_gut)
	_configure_gut()

func _configure_gut() -> void:
	if not _gut:
		return
	
	_gut.set_should_print_to_console(true)
	_gut.set_yield_between_tests(true)
	_gut.set_log_level(2) # Warning level
	_gut.set_include_subdirectories(true)

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
func run_tests(categories: Array[String] = []) -> void:
	print("Starting test suite...")
	
	if categories.is_empty():
		categories = TEST_CATEGORIES.keys()
	
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

func _run_category_parallel(category: String) -> void:
	_current_category = category
	print("\nRunning %s tests in parallel..." % category.capitalize())
	
	var test_files := _get_category_tests(category)
	if test_files.is_empty():
		push_warning("No test files found for category: %s" % category)
		return
	
	_pending_tests = test_files
	_active_test_count = 0
	
	# Create parallel runners
	for i in range(TEST_CONFIG.max_parallel_tests):
		var runner := _create_parallel_runner()
		if runner:
			_parallel_runners.append(runner)
			_assign_next_test(runner)
	
	# Wait for all tests to complete
	while _active_test_count > 0 or not _pending_tests.is_empty():
		await get_tree().process_frame

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
		
		_gut.add_script(test_file)
	
	if success:
		_gut.test_scripts()
		
		_category_results[category] = {
			"results": _gut.get_test_results(),
			"duration": (Time.get_ticks_msec() - category_start) / 1000.0
		}
	
	return success

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

func _on_parallel_test_finished(runner: Node) -> void:
	_active_test_count -= 1
	
	if not runner.has_method("get_test_results"):
		push_error("Runner missing get_test_results method")
		return
		
	var results: Dictionary = {}
	var raw_results: Variant = runner.call("get_test_results")
	if raw_results is Dictionary:
		results = raw_results
	
	if results.is_empty():
		push_warning("Empty test results received")
		return
		
	var elapsed: float = 0.0
	if results.has("elapsed"):
		elapsed = results.elapsed
	
	_category_results[_current_category] = {
		"results": results,
		"duration": elapsed
	}
	
	_assign_next_test(runner)