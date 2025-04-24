@tool
extends EditorScript

## IDE Test Runner
##
## Bypasses the GUT panel to run tests directly from the IDE
## Use with Editor > Run File or with the GUT extension

const GutScene: PackedScene = preload("res://tests/GutTestScene.tscn")
const GutConfig: GDScript = preload("res://tests/config/gut_config.gd")

var _gut: Node
var _start_time: int
var _test_paths: Dictionary = {}
var _specific_test: String = ""
var _specific_test_func: String = ""

func _init():
	print("\n=== Five Parsecs IDE Test Runner ===")
	# Check for command line arguments
	_parse_arguments()
	print("Command-line arguments parsed:")
	print("- Specific test file: ", _specific_test if not _specific_test.is_empty() else "None")
	print("- Specific test function: ", _specific_test_func if not _specific_test_func.is_empty() else "None")

func _parse_arguments():
	var arguments = OS.get_cmdline_args()
	for i in range(arguments.size()):
		var arg = arguments[i]
		if arg == "--test-file":
			if i + 1 < arguments.size():
				_specific_test = arguments[i + 1]
		elif arg == "--test-func":
			if i + 1 < arguments.size():
				_specific_test_func = arguments[i + 1]

func _run():
	print("\n--- Starting test execution ---")
	_start_time = Time.get_ticks_msec()
	
	# Initialize GUT using existing scene
	print("Loading GUT scene...")
	var test_scene = GutScene.instantiate() as Control
	if not test_scene:
		print("ERROR: Failed to instantiate GUT scene!")
		return
		
	_gut = test_scene.get_node("Gut")
	if not _gut:
		print("ERROR: Could not find Gut node in the test scene!")
		return
		
	print("Configuring test environment...")
	# Configure test environment
	GutConfig.configure_test_dependencies(_gut)
	
	# Add test directories
	_test_paths = GutConfig.get_test_paths()
	
	print("Preparing tests to run...")
	# Run specific test or all tests
	if _specific_test.is_empty():
		# Add all test directories
		for dir in _test_paths.test_dirs.values():
			print("Adding test directory: " + dir)
			_gut.add_directory(dir)
		print("Running all tests...")
	else:
		# Run specific test
		if _specific_test_func.is_empty():
			print("Running specific test script: " + _specific_test)
			_gut.add_script(_specific_test)
		else:
			print("Running specific test function: " + _specific_test + " -> " + _specific_test_func)
			_gut.add_script(_specific_test)
			_gut.set_unit_test_name(_specific_test_func)
	
	print("Connecting to GUT signals...")
	# Connect signals
	if _gut.is_connected("tests_finished", _on_tests_finished):
		_gut.disconnect("tests_finished", _on_tests_finished)
	_gut.connect("tests_finished", _on_tests_finished)
	
	print("Adding test scene to tree...")
	# Add scene to tree and run tests
	EditorInterface.get_editor_main_screen().add_child(test_scene)
	
	print("Starting test execution...")
	_gut.test_scripts()

func _on_tests_finished():
	var end_time = Time.get_ticks_msec()
	var duration = (end_time - _start_time) / 1000.0
	
	print("Test run complete in %.2f seconds!" % duration)
	print("Tests passed: %d" % _gut.get_pass_count())
	print("Tests failed: %d" % _gut.get_fail_count())
	print("Tests pending: %d" % _gut.get_pending_count())
	
	# Generate summary for failed tests
	if _gut.get_fail_count() > 0:
		print("\nFailed tests:")
		var failed_tests = []
		for test_script in _gut._test_collector.get_failed_tests():
			failed_tests.append("- " + test_script)
		print("\n".join(failed_tests))
	
	# Show completion message
	if _gut.get_fail_count() == 0:
		print("\n✅ All tests passed!")
	else:
		print("\n❌ Some tests failed, check the output for details.")