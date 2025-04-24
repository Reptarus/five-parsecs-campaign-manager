@tool
extends EditorScript

## Patch and Run Tests
##
## This script runs the fixed test versions to avoid the "Invalid base object for 'in'" error
##
## Run this from the Editor -> Tools menu

func _run():
	print("\n=== RUNNING FIXED TESTS ===")
	
	# Run the fixed tests
	var fixed_tests = [
		"res://tests/unit/test_test_runner.gd",
		"res://tests/unit/test_simple_fix.gd"
	]
	
	var tests_arg = ""
	for test in fixed_tests:
		if FileAccess.file_exists(test):
			tests_arg += " -gtest=" + test
			print("Added test: " + test)
		else:
			print("Warning: Test file not found: " + test)
	
	# Construct the GUT command
	var gut_command = "res://addons/gut/gut_cmdln.gd -glog=3" + tests_arg
	
	# Run the tests
	print("\nExecuting: " + gut_command)
	get_editor_interface().play_custom_scene(gut_command)
	print("Tests started. Check the running game for results.")
	
	print("\n=== TEST RUN INITIATED ===")