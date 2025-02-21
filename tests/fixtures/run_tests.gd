@tool
extends Node

const TEST_CATEGORIES: Dictionary = {
	"unit": "res://tests/unit",
	"integration": "res://tests/integration",
	"performance": "res://tests/performance",
	"mobile": "res://tests/mobile"
}

const GutRunnerScript: GDScript = preload("res://addons/gut/gut.gd")
const GutUtilsScript: GDScript = preload("res://addons/gut/utils.gd")

# Type-safe component references
var gut: Node = null
var _utils: Node = null
var _start_time: int = 0
var _category_results: Dictionary = {}
var _parallel_runners: Array[Node] = []
var _tests_completed: int = 0
var _total_tests: int = 0

func _init() -> void:
	_utils = Node.new()
	if not _utils:
		push_error("Failed to create utils instance")
		return
		
	_utils.set_script(GutUtilsScript)
	if not _utils.get_script() == GutUtilsScript:
		push_error("Failed to set GutUtils script")
		return
	add_child(_utils)

func _ready() -> void:
	# Wait one frame to ensure proper initialization
	await get_tree().process_frame
	
	_start_time = Time.get_ticks_msec()
	
	# Parse command line arguments with type safety
	var args: PackedStringArray = OS.get_cmdline_args()
	var categories: Array[String] = _parse_categories(args)
	var parallel: bool = "--parallel" in args
	
	if parallel:
		_run_tests_parallel(categories)
	else:
		_run_tests_sequential(categories)

# Type-safe test running methods
func _run_tests_sequential(categories: Array[String]) -> void:
	gut = Node.new()
	if not gut:
		push_error("Failed to create GutRunner instance")
		return
		
	gut.set_script(GutRunnerScript)
	if not gut.get_script() == GutRunnerScript:
		push_error("Failed to set GutRunner script")
		return
	add_child(gut)
	_configure_gut(gut)
	
	for category in categories:
		if TEST_CATEGORIES.has(category):
			print("\nRunning %s tests..." % category)
			var directory: String = TEST_CATEGORIES[category]
			_call_node_method(gut, "add_directory", [directory])
			var category_start: int = Time.get_ticks_msec()
			await _call_node_method(gut, "test_scripts")
			_category_results[category] = {
				"results": _call_node_method(gut, "get_test_results"),
				"duration": (Time.get_ticks_msec() - category_start) / 1000.0
			}
	
	_print_results()
	_export_results()

func _run_tests_parallel(categories: Array[String]) -> void:
	_total_tests = categories.size()
	
	for category in categories:
		if TEST_CATEGORIES.has(category):
			var runner: Node = Node.new()
			if not runner:
				push_error("Failed to create GutRunner instance for %s" % category)
				continue
				
			runner.set_script(GutRunnerScript)
			if not runner.get_script() == GutRunnerScript:
				push_error("Failed to set GutRunner script for %s" % category)
				continue
			add_child(runner)
			_configure_gut(runner)
			
			var directory: String = TEST_CATEGORIES[category]
			_call_node_method(runner, "add_directory", [directory])
			
			# Connect signals with type safety
			if runner.has_signal("tests_finished"):
				var err := runner.connect("tests_finished", _on_category_completed.bind(category, runner))
				if err != OK:
					push_error("Failed to connect tests_finished signal for %s" % category)
					continue
			
			_parallel_runners.append(runner)
	
	# Start all runners
	for runner in _parallel_runners:
		_call_node_method(runner, "test_scripts")

# Type-safe signal handling
func _on_category_completed(category: String, runner: Node) -> void:
	if not category or not runner:
		push_error("Invalid category or runner in _on_category_completed")
		return
	
	_category_results[category] = {
		"results": _call_node_method(runner, "get_test_results"),
		"duration": 0.0 # Duration will be calculated in _print_results
	}
	
	_tests_completed += 1
	if _tests_completed == _total_tests:
		_print_results()
		_export_results()
		get_tree().quit()

# Type-safe configuration
func _configure_gut(runner: Node) -> void:
	if not runner:
		push_error("Attempting to configure null runner")
		return
	
	# Basic settings with type-safe method calls
	_call_node_method(runner, "set_should_print_to_console", [true])
	_call_node_method(runner, "set_log_level", [2]) # Detailed logging
	_call_node_method(runner, "set_yield_between_tests", [true])
	
	# Appearance settings
	_call_node_method(runner, "set_font_size", [16])
	_call_node_method(runner, "set_opacity", [100])
	
	# Test settings
	_call_node_method(runner, "set_include_subdirectories", [true])
	_call_node_method(runner, "set_prefix", ["test_"])
	_call_node_method(runner, "set_suffix", [".gd"])

# Type-safe argument parsing
func _parse_categories(args: PackedStringArray) -> Array[String]:
	var categories: Array[String] = []
	var found_category: bool = false
	
	for arg in args:
		if arg.begins_with("--category="):
			found_category = true
			var category: String = arg.split("=")[1]
			if TEST_CATEGORIES.has(category):
				categories.append(category)
	
	# If no categories specified, run all
	if not found_category:
		categories.append_array(TEST_CATEGORIES.keys())
	
	return categories

# Type-safe results handling
func _print_results() -> void:
	var total_duration: float = (Time.get_ticks_msec() - _start_time) / 1000.0
	
	print("\n=== Test Results ===")
	print("Time: %.2f seconds" % total_duration)
	print("\nResults by Category:")
	
	var total_tests: int = 0
	var total_passed: int = 0
	var total_failed: int = 0
	var total_errors: int = 0
	
	for category in _category_results:
		var results: Object = _category_results[category]["results"]
		var duration: float = _category_results[category]["duration"]
		
		if not results:
			push_warning("Missing results for category: %s" % category)
			continue
		
		var test_count: int = _call_node_method_int(results, "get_test_count")
		var pass_count: int = _call_node_method_int(results, "get_pass_count")
		var fail_count: int = _call_node_method_int(results, "get_fail_count")
		var error_count: int = _call_node_method_int(results, "get_error_count")
		
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
	
	print("\nOverall Results:")
	print("  Total Tests: %d" % total_tests)
	print("  Total Passed: %d" % total_passed)
	print("  Total Failed: %d" % total_failed)
	print("  Total Errors: %d" % total_errors)
	print("  Success Rate: %.1f%%" % (float(total_passed) / total_tests * 100 if total_tests > 0 else 0.0))

func _export_results() -> void:
	var should_export: bool = false
	
	for category in _category_results:
		var results: Object = _category_results[category]["results"]
		if not results:
			continue
		
		var fail_count: int = _call_node_method_int(results, "get_fail_count")
		var error_count: int = _call_node_method_int(results, "get_error_count")
		
		if fail_count > 0 or error_count > 0:
			should_export = true
			break
	
	if should_export:
		var timestamp: String = Time.get_datetime_string_from_system().replace(":", "-")
		var report_path: String = "res://tests/reports/test_report_%s.txt" % timestamp
		
		var report: FileAccess = FileAccess.open(report_path, FileAccess.WRITE)
		if report:
			report.store_string("Test Report - %s\n\n" % timestamp)
			
			for category in _category_results:
				var results: Object = _category_results[category]["results"]
				if not results:
					continue
					
				var duration: float = _category_results[category]["duration"]
				var test_count: int = _call_node_method_int(results, "get_test_count")
				var pass_count: int = _call_node_method_int(results, "get_pass_count")
				var fail_count: int = _call_node_method_int(results, "get_fail_count")
				var error_count: int = _call_node_method_int(results, "get_error_count")
				
				report.store_string("%s Tests:\n" % category.capitalize())
				report.store_string("  Duration: %.2f seconds\n" % duration)
				report.store_string("  Total: %d\n" % test_count)
				report.store_string("  Passed: %d\n" % pass_count)
				report.store_string("  Failed: %d\n" % fail_count)
				report.store_string("  Errors: %d\n\n" % error_count)
				
				# Store failure details with type safety
				if fail_count > 0:
					report.store_string("  Failed Tests:\n")
					var failures: Array = _call_node_method_array(results, "get_failures")
					for failure in failures:
						report.store_string("    - %s\n" % str(failure))
				
				# Store error details with type safety
				if error_count > 0:
					report.store_string("  Errors:\n")
					var errors: Array = _call_node_method_array(results, "get_errors")
					for error in errors:
						report.store_string("    - %s\n" % str(error))
			
			report.close()

# Type-safe method calls
func _call_node_method(node: Node, method: String, args: Array = []) -> Variant:
	if not node:
		push_error("Attempting to call method '%s' on null node" % method)
		return null
	if not node.has_method(method):
		push_error("Node missing required method: %s" % method)
		return null
	return node.callv(method, args)

func _call_node_method_int(node: Node, method: String, args: Array = [], default_value: int = 0) -> int:
	var result: Variant = _call_node_method(node, method, args)
	if not result is int:
		push_warning("Method '%s' did not return an int" % method)
		return default_value
	return result

func _call_node_method_array(node: Node, method: String, args: Array = [], default_value: Array = []) -> Array:
	var result: Variant = _call_node_method(node, method, args)
	if not result is Array:
		push_warning("Method '%s' did not return an Array" % method)
		return default_value
	return result
