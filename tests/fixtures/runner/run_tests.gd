@tool
extends Node

const TEST_CATEGORIES: Dictionary = {
	"unit": "res://tests/unit",
	"integration": "res://tests/integration",
	"performance": "res://tests/performance",
	"mobile": "res://tests/mobile"
}

# Type-safe component references
var _start_time: int = 0
var _category_results: Dictionary = {}
var _tests_completed: int = 0
var _total_tests: int = 0

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
	print("Running tests sequentially...")
	
	for category in categories:
		if TEST_CATEGORIES.has(category):
			print("\nRunning %s tests..." % category)
			var directory: String = TEST_CATEGORIES[category]
			var category_start: int = Time.get_ticks_msec()
			
			# Simple test execution - just print the category
			print("Would run tests in: %s" % directory)
			
			_category_results[category] = {
				"results": "completed",
				"duration": (Time.get_ticks_msec() - category_start) / 1000.0
			}
	
	_print_results()
	_export_results()

func _run_tests_parallel(categories: Array[String]) -> void:
	print("Running tests in parallel...")
	_total_tests = categories.size()
	
	for category in categories:
		if TEST_CATEGORIES.has(category):
			print("Would run %s tests in parallel" % category)
			_category_results[category] = {
				"results": "completed",
				"duration": 0.0
			}
	
	_print_results()
	_export_results()

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
	
	for category in _category_results:
		var duration: float = _category_results[category]["duration"]
		
		print("\n%s Tests:" % category.capitalize())
		print("  Duration: %.2f seconds" % duration)
		print("  Status: %s" % _category_results[category]["results"])

func _export_results() -> void:
	var timestamp: String = Time.get_datetime_string_from_system().replace(":", "-")
	var report_path: String = "res://tests/reports/test_report_%s.txt" % timestamp
	
	var report: FileAccess = FileAccess.open(report_path, FileAccess.WRITE)
	if report:
		report.store_string("Test Report - %s\n\n" % timestamp)
		
		for category in _category_results:
			var duration: float = _category_results[category]["duration"]
			
			report.store_string("%s Tests:\n" % category.capitalize())
			report.store_string("  Duration: %.2f seconds\n" % duration)
			report.store_string("  Status: %s\n\n" % _category_results[category]["results"])
		
		report.close()
