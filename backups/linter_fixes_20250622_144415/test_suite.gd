@tool
extends GdUnitTestSuite

#
const TEST_CATEGORIES := {
    "unit": "res://tests/unit",
    "integration": "res://tests/integration",
    "performance": "res://tests/performance",
    "mobile": "res://tests/mobile"
}

#
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

#
func before() -> void:
    """Setup run once before all tests"""
    _setup_test_environment()
    _test_start_time = Time.get_unix_time_from_system()

func after() -> void:
    """Cleanup run once after all tests"""
    pass

func before_test() -> void:
    """Setup run before each test"""
    pass

func after_test() -> void:
    """Cleanup run after each test"""
    pass

#
func _setup_test_environment() -> void:
    # Set consistent performance settings
    Engine.physics_ticks_per_second = 60
    Engine.max_fps = 60
    get_tree().set_debug_collisions_hint(false)
    get_tree().set_debug_navigation_hint(false)
    
    # Disable audio for tests
    var master_bus = AudioServer.get_bus_index("Master")
    if master_bus >= 0:
        AudioServer.set_bus_mute(master_bus, true)

#
func test_run_all_categories() -> void:
    """Test method to run all test categories"""
    print("Starting test suite...")
    
    # Get all categories
    var categories: Array[String] = []
    for key in TEST_CATEGORIES.keys():
        categories.append(str(key))
    
    for category in categories:
        if not category in TEST_CATEGORIES:
            continue
        
        if TEST_CONFIG.parallel_tests:
            _run_category_parallel(category)
        else:
            _run_category(category)
    
    # Export results if configured
    if TEST_CONFIG.export_results:
        _export_results()

func test_run_unit_tests() -> void:
    """Test method to run only unit tests"""
    _run_category("unit")

func test_run_integration_tests() -> void:
    """Test method to run only integration tests"""
    _run_category("integration")

func test_run_performance_tests() -> void:
    """Test method to run only performance tests"""
    _run_category("performance")

func test_run_mobile_tests() -> void:
    """Test method to run only mobile tests"""
    _run_category("mobile")

func _run_category_parallel(category: String) -> void:
    _current_category = category
    print("\nRunning %s tests in parallel..." % category.capitalize())
    
    # Get test files for category
    var test_files = _get_category_tests(category)
    if test_files.is_empty():
        print("No tests found for category: %s" % category)
        return
    
    # Parallel test execution (simplified)
    for test_file: String in test_files:
        if FileAccess.file_exists(test_file):
            _run_test_file(test_file)

func _cleanup_test_runners() -> void:
    pass

func _assign_next_test() -> void:
    if _pending_tests.is_empty():
        return
    
    # Simplified test assignment - actual implementation would
    # assign tests to available runners
    var next_test = _pending_tests.pop_front()
    if FileAccess.file_exists(next_test):
        _run_test_file(next_test)

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
    
    return tests

func _run_category(category: String) -> bool:
    _current_category = category
    print("\nRunning %s tests..." % category.capitalize())
    
    # Get test files for category
    var test_files = _get_category_tests(category)
    if test_files.is_empty():
        print("No tests found for category: %s" % category)
        return false

    var category_start := Time.get_ticks_msec()
    var success = true
    
    for test_file: String in test_files:
        if not FileAccess.file_exists(test_file):
            print("Test file not found: %s" % test_file)
            success = false
            continue
        # Note: This is simplified - actual implementation would
        # integrate with gdunit4's test runner
        success = success and _run_test_file(test_file)
    
    if success:
        _category_results[category] = {
            "results": {"tests": 0, "passing": 0, "failing": 0, "errors": 0},
            "duration": (Time.get_ticks_msec() - category_start) / 1000.0,
        }
    
    return success

func _run_test_file(test_file: String) -> bool:
    # Simplified test file execution
    # Actual implementation would integrate with gdunit4's runner
    return true

func _print_results() -> void:
    print("\n=== Test Results ===")
    
    var total_tests := 0
    var total_passed := 0
    var total_failed := 0
    var total_errors := 0
    var total_duration := 0.0
    
    for category: String in _category_results:
        var result_data: Dictionary = _category_results[category]
        var results: Dictionary = result_data.get("results", {})
        var duration: float = result_data.get("duration", 0.0)
        
        if results.is_empty():
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
    # Create export directory if it doesn't exist
    var export_dir = DirAccess.open(TEST_CONFIG.export_path)
    if not export_dir:
        if DirAccess.make_dir_recursive_absolute(TEST_CONFIG.export_path) != OK:
            print("Failed to create export directory: %s" % TEST_CONFIG.export_path)
            return
    
    var timestamp: String = Time.get_datetime_string_from_system().replace(":", "-")
    var filename: String = "test_results_%s.%s" % [timestamp, TEST_CONFIG.export_format]
    var filepath: String = TEST_CONFIG.export_path.path_join(filename)
    
    var file = FileAccess.open(filepath, FileAccess.WRITE)
    if not file:
        print("Failed to create export file: %s" % filepath)
        return
    
    match TEST_CONFIG.export_format:
        "json":
            file.store_string(JSON.stringify(_category_results, "  "))
        "txt":
            for category: String in _category_results:
                var result_data: Dictionary = _category_results[category]
                var results: Dictionary = result_data.get("results", {})
                
                file.store_string("\n%s Tests:\n" % category.capitalize())
                file.store_string("  Total: %d\n" % results.get("tests", 0))
                file.store_string("  Passed: %d\n" % results.get("passing", 0))
                file.store_string("  Failed: %d\n" % results.get("failing", 0))
                file.store_string("  Errors: %d\n" % results.get("errors", 0))
                
                if results.get("failing", 0) > 0:
                    file.store_string("\n  Failed Tests:\n")
                    var failures = results.get("failures", [])
                    for failure in failures:
                        file.store_string("    - %s\n" % str(failure))
                
                if results.get("errors", 0) > 0:
                    file.store_string("\n  Errors:\n")
                    var errors = results.get("errors", [])
                    for error in errors:
                        file.store_string("    - %s\n" % str(error))
    
    file.close()
    print("\nTest results exported to: %s" % filepath)
