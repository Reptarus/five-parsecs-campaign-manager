@tool
extends Node

# Test Categories
const UNIT_TESTS := [
	"res://tests/unit/test_campaign_state.gd",
	"res://tests/unit/test_character_manager.gd",
	"res://tests/unit/test_mission_generator.gd",
	"res://tests/unit/test_mission_template.gd",
	"res://tests/unit/test_position_validator.gd",
	"res://tests/unit/test_ship_components.gd",
	"res://tests/unit/test_terrain_system.gd"
]

const INTEGRATION_TESTS := [
	"res://tests/integration/test_campaign_manager.gd",
	"res://tests/integration/test_campaign_phase_manager.gd",
	"res://tests/integration/test_mission_events.gd",
	"res://tests/integration/test_game_flow.gd",
	"res://tests/integration/test_terrain_layout_generator.gd"
]

const PERFORMANCE_TESTS := [
	"res://tests/performance/test_performance.gd",
	"res://tests/performance/test_table_processor.gd"
]

const MOBILE_TESTS := [
	"res://tests/mobile/test_ui.gd"
]

# Test Runner Configuration
var gut = null
var _current_category := ""
var _category_results := {}

func _ready() -> void:
	gut = load("res://addons/gut/gut.gd").new()
	add_child(gut)
	_configure_gut()
	
	# Parse command line arguments
	var args := OS.get_cmdline_args()
	var categories := _parse_categories(args)
	
	# Run tests
	for category in categories:
		_run_category(category)
	
	# Print results
	_print_results()

func _configure_gut() -> void:
	gut.set_should_print_to_console(true)
	gut.set_log_level(2)
	gut.set_yield_between_tests(true)
	gut.set_include_subdirectories(true)
	
	gut.set_font("CourierPrime")
	gut.set_font_size(16)
	gut.set_opacity(100)

func _parse_categories(args: Array) -> Array:
	var categories := []
	var found_category := false
	
	for arg in args:
		if arg.begins_with("--category="):
			found_category = true
			categories.append(arg.split("=")[1])
	
	# If no categories specified, run all
	if not found_category:
		categories = ["unit", "integration", "performance", "mobile"]
	
	return categories

func _run_category(category: String) -> void:
	_current_category = category
	print("\nRunning %s tests..." % category.capitalize())
	
	var test_files: Array
	match category:
		"unit":
			test_files = UNIT_TESTS
		"integration":
			test_files = INTEGRATION_TESTS
		"performance":
			test_files = PERFORMANCE_TESTS
		"mobile":
			test_files = MOBILE_TESTS
	
	var category_start := Time.get_ticks_msec()
	
	for test_file in test_files:
		gut.add_script(test_file)
	
	gut.test_scripts()
	
	_category_results[category] = {
		"results": gut.get_test_results(),
		"duration": (Time.get_ticks_msec() - category_start) / 1000.0
	}

func _print_results() -> void:
	print("\n=== Test Results ===")
	
	var total_tests := 0
	var total_passed := 0
	var total_failed := 0
	var total_errors := 0
	var total_duration := 0.0
	
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
		total_duration += duration
	
	print("\nOverall Results:")
	print("  Total Duration: %.2f seconds" % total_duration)
	print("  Total Tests: %d" % total_tests)
	print("  Total Passed: %d" % total_passed)
	print("  Total Failed: %d" % total_failed)
	print("  Total Errors: %d" % total_errors)
	print("  Success Rate: %.1f%%" % (float(total_passed) / total_tests * 100 if total_tests > 0 else 0.0))
	
	# Export results if there were failures
	if total_failed > 0 or total_errors > 0:
		_export_results()

func _export_results() -> void:
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
		print("\nTest report exported to: %s" % report_path)