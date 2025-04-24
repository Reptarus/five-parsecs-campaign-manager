@tool
extends EditorScript

## Single Test Runner
##
## This script runs just a single test file to help isolate and diagnose GUT issues.
## It bypasses the problematic mission generator that's causing errors.
##
## Run this from the Editor -> Tools menu

func _run():
	print("\n=== RUNNING SINGLE TEST ===")
	
	# Use GUT command line runner with just a single test
	var gut_command = "res://addons/gut/gut_cmdln.gd "
	gut_command += "-gtest=res://tests/unit/test_test_runner.gd "
	gut_command += "-glog=3 "
	gut_command += "-gquit_on_success "
	
	# Run the test
	print("Executing: " + gut_command)
	get_editor_interface().play_custom_scene(gut_command)
	print("Test started. Check the running game for results.")
	
	print("\n=== TEST RUN INITIATED ===")
	
	# This will help identify if the issue is with a specific test 