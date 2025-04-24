@tool
extends SceneTree

## Comprehensive Five Parsecs Test Runner
##
## Runs all tests in the project with improved resource management
## This script can be run from the command line with:
## godot --headless --script tests/run_all_tests.gd
## It will automatically exit after tests complete

# Constants for configuration
const CONFIG_PATH := "res://tests/config/gutconfig.json"
const REPORT_PATH := "res://tests/reports/all_tests_report.txt"
const LOG_PATH := "res://tests/logs/all_tests.log"

# The directories to test - keep this comprehensive
const TEST_DIRECTORIES = [
	"res://tests/unit/",
	"res://tests/integration/",
	"res://tests/battle/",
	"res://tests/performance/",
	"res://tests/mobile/",
	"res://tests/diagnostic/"
]

var _gut = null
var _tests_completed = 0
var _tests_passed = 0
var _tests_failed = 0
var _tests_pending = 0

var _started_at: int = 0
var _ended_at: int = 0
var _resource_cleaner = null

func _init():
	_started_at = Time.get_ticks_msec()
	print("\n======== FIVE PARSECS CAMPAIGN MANAGER TESTS ========")
	print("Started at: " + Time.get_datetime_string_from_system())
	print("====================================================\n")
	
	# Initialize logging
	_setup_logging()
	
	# Initialize resource cleaner
	_init_resource_cleaner()
	
	# Apply Godot 4.4+ compatibility patches
	_apply_compatibility_patches()
	
	# Initialize and configure GUT
	_init_gut()
	
	# Run the tests
	_gut.test_scripts()
	
	# Adding a timer since we can't use signals with SceneTree
	_wait_for_tests_to_complete()

# Apply Godot 4.4+ compatibility patches for property_exists
func _apply_compatibility_patches() -> void:
	print("Applying Godot 4.4+ compatibility patches...")
	
	# Load property_exists patches if available
	var patch_script_path = "res://tests/fixtures/helpers/property_exists_patch.gd"
	if ResourceLoader.exists(patch_script_path):
		var PropertyExistsPatch = load(patch_script_path)
		Engine.register_singleton("PropertyExistsPatch", PropertyExistsPatch)
		print("- Registered PropertyExistsPatch singleton")
		
		# Patch the Resource class to have a has() method
		var resource_script = GDScript.new()
		resource_script.source_code = """
@tool
extends Resource

func has(property_name: String) -> bool:
	# Check if property exists in property list
	for prop in get_property_list():
		if prop.name == property_name:
			return true
			
	# Fallback to direct property access for Godot 4.4+
	return property_name in self
"""
		resource_script.reload()
		Engine.set_meta("resource_has_patch", resource_script)
		print("- Added Resource.has() method for compatibility")
	else:
		print("- WARNING: PropertyExistsPatch not found, tests may fail on Godot 4.4+")

func _wait_for_tests_to_complete():
	# Keep processing frames until tests complete
	print("Waiting for tests to complete...")
	
	# This loop will continue until all tests are done
	var start_time = Time.get_ticks_msec()
	var timeout = 60 * 1000 # 60 second timeout
	
	while (Time.get_ticks_msec() - start_time) < timeout:
		# Process a frame
		await Engine.get_main_loop().process_frame
		
		# Check if GUT has completed all tests
		if _gut.is_passing() != null: # Test completion is determined
			_tests_completed = _gut.get_test_count()
			_tests_passed = _gut.get_pass_count()
			_tests_failed = _gut.get_fail_count()
			_tests_pending = _gut.get_pending_count()
			_ended_at = Time.get_ticks_msec()
			
			# Tests are done
			_process_results()
			_cleanup_resources()
			
			# Delay to allow for cleanup
			await Engine.get_main_loop().process_frame
			await Engine.get_main_loop().process_frame
			await Engine.get_main_loop().process_frame
			
			if OS.has_feature("headless") or not OS.has_feature("editor"):
				quit()
			return
	
	# If we reach here, tests timed out
	print("ERROR: Tests timed out after 60 seconds")
	if OS.has_feature("headless") or not OS.has_feature("editor"):
		quit(1)

func _setup_logging():
	# Ensure logs directory exists
	var dir = DirAccess.open("res://tests")
	if dir and not dir.dir_exists("logs"):
		dir.make_dir("logs")
	
	# Redirect output to log file if running headless
	if OS.has_feature("headless"):
		var file = FileAccess.open(LOG_PATH, FileAccess.WRITE)
		if file:
			print("Logging to: " + LOG_PATH)
			# Here we'd set up logging, but Godot doesn't expose stdout redirection API

func _init_resource_cleaner():
	var cleaner_script = load("res://tests/cleanup_resources.gd")
	if cleaner_script:
		_resource_cleaner = cleaner_script.new()
		print("Resource cleaner initialized")
	else:
		print("WARNING: Could not load resource cleaner script")

func _init_gut():
	# Load the gut scene
	var gut_gd = load("res://addons/gut/gut.gd")
	_gut = gut_gd.new()
	get_root().add_child(_gut)
	
	# Configure GUT from config file if it exists
	var config = {}
	if FileAccess.file_exists(CONFIG_PATH):
		var file = FileAccess.open(CONFIG_PATH, FileAccess.READ)
		var json = JSON.new()
		var error = json.parse(file.get_as_text())
		if error == OK:
			config = json.get_data()
	else:
		print("Config file not found. Using default settings.")
	
	# Apply configuration
	_apply_gut_config(config)

func _apply_gut_config(config):
	# Set default values using correct property names for GUT 9.3.1
	_gut.log_level = 3
	_gut.include_subdirectories = true
	# GUT 9.3.1 uses these names instead
	_gut.prefix = "test_"
	_gut.suffix = ".gd"
	_gut.export_path = REPORT_PATH
	
	# Override with config values if available
	if config.has("log_level"):
		_gut.log_level = config.log_level
	if config.has("font_name"):
		_gut.font_name = config.font_name
	if config.has("font_size"):
		_gut.font_size = config.font_size
	if config.has("should_maximize"):
		_gut.should_maximize = config.should_maximize
	
	# Add test directories
	for dir in TEST_DIRECTORIES:
		_gut.add_directory(dir)
		print("Added test directory: " + dir)

func _process_results():
	var duration = (_ended_at - _started_at) / 1000.0
	print("\n====================================================")
	print("RESULTS:")
	print("----------------------------------------------------")
	print("Tests completed: " + str(_tests_completed))
	print("Tests passed:    " + str(_tests_passed))
	print("Tests failed:    " + str(_tests_failed))
	print("Tests pending:   " + str(_tests_pending))
	print("Time taken:      " + str(duration) + " seconds")
	print("----------------------------------------------------")
	
	if _tests_failed == 0:
		print("\n✅ ALL TESTS PASSED!")
	else:
		print("\n❌ SOME TESTS FAILED!")
	
	print("====================================================\n")

func _cleanup_resources():
	print("\nCleaning up resources...\n")
	
	# Use the dedicated resource cleaner if available
	if _resource_cleaner:
		_resource_cleaner.cleanup()
	else:
		print("WARNING: Resource cleaner not available, using basic cleanup")
		# Basic cleanup as fallback
		for resource_path in ["res://src/core/migration/WorldDataMigration.gd",
							"res://src/core/enemy/EnemyData.gd",
							"res://src/core/enemy/base/EnemyData.gd",
							"res://src/core/state/GameState.gd"]:
			if ResourceLoader.exists(resource_path):
				ResourceLoader.load("res://") # Trick to flush resource cache
				print("Cleaned up: " + resource_path)
			
	# Create report file
	var report = FileAccess.open(REPORT_PATH, FileAccess.WRITE)
	if report:
		report.store_string(_generate_report())
		report.close()
		print("Report generated: " + REPORT_PATH)

func _generate_report() -> String:
	var duration = (_ended_at - _started_at) / 1000.0
	var success_rate = (float(_tests_passed) / _tests_completed) * 100 if _tests_completed > 0 else 0
	
	return """# Five Parsecs Campaign Manager Test Report
Generated: {datetime}

## Test Results
- Tests Completed: {completed}
- Tests Passed: {passed}
- Tests Failed: {failed}
- Tests Pending: {pending}

## Performance
- Duration: {duration} seconds
- Success Rate: {success_rate}%

## Summary
{summary}

## Next Steps
{next_steps}
""".format({
		"datetime": Time.get_datetime_string_from_system(),
		"completed": _tests_completed,
		"passed": _tests_passed,
		"failed": _tests_failed,
		"pending": _tests_pending,
		"duration": duration,
		"success_rate": success_rate,
		"summary": "All tests passed successfully!" if _tests_failed == 0 else "Some tests failed. See logs for details.",
		"next_steps": "Continue with development." if _tests_failed == 0 else "Fix failing tests before proceeding."
	})