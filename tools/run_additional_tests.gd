@tool
extends EditorScript

## Additional Tests Runner
##
## This script runs tests specifically from the directories that might have been
## missed by GUT. Use this to verify that all test directories are being properly
## scanned and executed.
##
## Run this from the Editor -> Tools menu

func _run():
	print("\n=== RUNNING ADDITIONAL FIVE PARSECS TESTS ===")
	print("This will run tests from directories that might have been missed")
	
	var additional_dirs = [
		"res://tests/battle/",
		"res://tests/performance/",
		"res://tests/mobile/",
		"res://tests/diagnostic/"
	]
	
	var gut_command = "res://addons/gut/gut_cmdln.gd -ginclude_subdirs -glog=3"
	
	# Add directories to command
	for dir in additional_dirs:
		gut_command += " -gdir=" + dir
		print("Adding directory: " + dir)
	
	# Run the GUT command-line
	print("\nExecuting command: " + gut_command)
	
	# Use EditorInterface to run the test scene
	if Engine.has_singleton("EditorInterface"):
		var editor_interface = Engine.get_singleton("EditorInterface")
		editor_interface.play_custom_scene(gut_command)
		print("Tests started. Check the running game for results.")
	else:
		print("ERROR: This script must be run from the editor.")
	
	print("\n=== TEST RUN INITIATED ===")