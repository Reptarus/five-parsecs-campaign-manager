@tool
extends EditorScript

## Script to copy gutconfig.json to the GUT temp directory
## Run this script from the Editor menu: Project -> Tools -> Run EditorScript

func _run():
	print("\n=== GUT Configuration Helper ===")
	
	# Get the temporary directory path used by GUT
	var EditorGlobals = load("res://addons/gut/gui/editor_globals.gd")
	if not EditorGlobals:
		push_error("Could not load editor_globals.gd")
		return
	
	var temp_directory = EditorGlobals.temp_directory
	var target_path = EditorGlobals.editor_run_gut_config_path
	
	print("GUT temp directory: " + temp_directory)
	print("GUT config target: " + target_path)
	
	# Create the temp directory if it doesn't exist
	DirAccess.make_dir_recursive_absolute(temp_directory)
	
	# Source files (try both with and without the dot)
	var source_files = [
		"res://.gutconfig.json",
		"res://gutconfig.json"
	]
	
	var file_content = ""
	
	# Try to read from source files
	for source_file in source_files:
		if FileAccess.file_exists(source_file):
			var f = FileAccess.open(source_file, FileAccess.READ)
			if f:
				file_content = f.get_as_text()
				print("Read configuration from: " + source_file)
				break
	
	if file_content.is_empty():
		push_error("Could not read gutconfig.json files")
		return
	
	# Write to target file
	var f = FileAccess.open(target_path, FileAccess.WRITE)
	if f:
		f.store_string(file_content)
		print("Successfully copied config to: " + target_path)
		print("GUT should now recognize your test directories!")
	else:
		push_error("Failed to write to: " + target_path + " Error: " + str(FileAccess.get_open_error()))
	
	print("=== Configuration complete ===\n")