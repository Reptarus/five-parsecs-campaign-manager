extends Node

const TEST_CATEGORIES := {
	"unit": "res://tests/unit",
	"integration": "res://tests/integration",
	"performance": "res://tests/performance",
	"mobile": "res://tests/mobile"
}

const GutRunner := preload("res://addons/gut/gut.gd")

var gut = null
var _start_time: int
var _category_results := {}
var _parallel_runners := []
var _tests_completed := 0
var _total_tests := 0

func _ready() -> void:
	_start_time = Time.get_ticks_msec()
	
	# Parse command line arguments
	var args := OS.get_cmdline_args()
	var categories := _parse_categories(args)
	var parallel := "--parallel" in args
	
	if parallel:
		_run_tests_parallel(categories)
	else:
		_run_tests_sequential(categories)

func _run_tests_sequential(categories: Array) -> void:
	gut = GutRunner.new()
	add_child(gut)
	_configure_gut(gut)
	
	for category in categories:
		if TEST_CATEGORIES.has(category):
			print("\nRunning %s tests..." % category)
			gut.add_directory(TEST_CATEGORIES[category])
			var category_start := Time.get_ticks_msec()
			gut.test_scripts()
			_category_results[category] = {
				"results": gut.get_test_results(),
				"duration": (Time.get_ticks_msec() - category_start) / 1000.0
			}
	
	_print_results()
	_export_results()

func _run_tests_parallel(categories: Array) -> void:
	_total_tests = categories.size()
	
	for category in categories:
		if TEST_CATEGORIES.has(category):
			var runner: Node = GutRunner.new()
			add_child(runner)
			_configure_gut(runner)
			runner.add_directory(TEST_CATEGORIES[category])
			
			# Connect signals
			runner.connect("tests_finished", _on_category_completed.bind(category, runner))
			
			_parallel_runners.append(runner)
	
	# Start all runners
	for runner in _parallel_runners:
		runner.test_scripts()

func _on_category_completed(category: String, runner: Node) -> void:
	_category_results[category] = {
		"results": runner.get_test_results(),
		"duration": 0.0 # Duration will be calculated in _print_results
	}
	
	_tests_completed += 1
	if _tests_completed == _total_tests:
		_print_results()
		_export_results()
		get_tree().quit()

func _configure_gut(runner: Node) -> void:
	# Basic settings
	runner.set_should_print_to_console(true)
	runner.set_log_level(2) # Detailed logging
	runner.set_yield_between_tests(true)
	
	# Appearance settings
	runner.set_font("CourierPrime")
	runner.set_font_size(16)
	runner.set_opacity(100)
	
	# Test settings
	runner.set_include_subdirectories(true)
	runner.set_prefix("test_")
	runner.set_suffix(".gd")

func _parse_categories(args: Array) -> Array:
	var categories := []
	var found_category := false
	
	for arg in args:
		if arg.begins_with("--category="):
			found_category = true
			categories.append(arg.split("=")[1])
	
	# If no categories specified, run all
	if not found_category:
		categories = TEST_CATEGORIES.keys()
	
	return categories

func _print_results() -> void:
	var total_duration := (Time.get_ticks_msec() - _start_time) / 1000.0
	
	print("\n=== Test Results ===")
	print("Time: %.2f seconds" % total_duration)
	print("\nResults by Category:")
	
	var total_tests := 0
	var total_passed := 0
	var total_failed := 0
	var total_errors := 0
	
	for category in _category_results:
		var results = _category_results[category]["results"]
		var duration = _category_results[category]["duration"]
		
		print("\n%s Tests:" % category.capitalize())
		print("  Duration: %.2f seconds" % duration)
		print("  Total: %d" % results.get_test_count())
		print("  Passed: %d" % results.get_pass_count())
		print("  Failed: %d" % results.get_fail_count())
		print("  Errors: %d" % results.get_error_count())
		
		total_tests += results.get_test_count()
		total_passed += results.get_pass_count()
		total_failed += results.get_fail_count()
		total_errors += results.get_error_count()
	
	print("\nOverall Results:")
	print("  Total Tests: %d" % total_tests)
	print("  Total Passed: %d" % total_passed)
	print("  Total Failed: %d" % total_failed)
	print("  Total Errors: %d" % total_errors)
	print("  Success Rate: %.1f%%" % (float(total_passed) / total_tests * 100 if total_tests > 0 else 0.0))

func _export_results() -> void:
	var should_export := false
	
	for category in _category_results:
		var results = _category_results[category]["results"]
		if results.get_fail_count() > 0 or results.get_error_count() > 0:
			should_export = true
			break
	
	if should_export:
		var timestamp := Time.get_datetime_string_from_system().replace(":", "-")
		var report_path := "res://tests/reports/test_report_%s.txt" % timestamp
		
		var report := FileAccess.open(report_path, FileAccess.WRITE)
		if report:
			report.store_string("Test Report - %s\n\n" % timestamp)
			
			for category in _category_results:
				var results = _category_results[category]["results"]
				var duration = _category_results[category]["duration"]
				
				report.store_string("%s Tests:\n" % category.capitalize())
				report.store_string("  Duration: %.2f seconds\n" % duration)
				report.store_string("  Total: %d\n" % results.get_test_count())
				report.store_string("  Passed: %d\n" % results.get_pass_count())
				report.store_string("  Failed: %d\n" % results.get_fail_count())
				report.store_string("  Errors: %d\n\n" % results.get_error_count())
				
				# Store failure details
				if results.get_fail_count() > 0:
					report.store_string("  Failed Tests:\n")
					for failure in results.get_failures():
						report.store_string("    - %s\n" % failure)
				
				# Store error details
				if results.get_error_count() > 0:
					report.store_string("  Errors:\n")
					for error in results.get_errors():
						report.store_string("    - %s\n" % error)
			
			report.close()
