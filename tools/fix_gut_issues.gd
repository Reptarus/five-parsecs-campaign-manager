@tool
extends SceneTree

## Fixes common GUT issues in Godot 4.4
##
## This script automatically fixes dictionary access issues and other common problems
## that cause GUT tests to fail in Godot 4.4.

func _init():
	print("Running GUT compatibility fixer...")
	
	# Load compatibility script
	var compatibility_script = load("res://addons/gut/compatibility.gd")
	if not compatibility_script:
		print_error("Could not load compatibility script.")
		quit()
		return
	
	var compatibility = compatibility_script.new()
	
	# Step 1: Fix dictionary access issues in critical files
	fix_dictionary_access()
	
	# Step 2: Ensure empty script exists
	ensure_empty_script_exists()
	
	# Step 3: Clean UID files
	clean_uid_files()
	
	# Step 4: Fix compatibility issues
	if compatibility.has_method("fix_gut_errors"):
		compatibility.fix_gut_errors()
	
	print("GUT compatibility fixes completed successfully.")
	quit()

func fix_dictionary_access():
	print("Fixing dictionary access issues...")
	
	var critical_files = [
		"res://src/core/mission/generator/MissionGenerator.gd",
		"res://addons/gut/doubler.gd",
		"res://addons/gut/test_collector.gd",
		"res://addons/gut/method_maker.gd",
		"res://addons/gut/script_parser.gd",
		"res://addons/gut/utils.gd"
	]
	
	for file_path in critical_files:
		if not FileAccess.file_exists(file_path):
			print("Skipping %s - file not found." % file_path)
			continue
			
		var file = FileAccess.open(file_path, FileAccess.READ)
		if not file:
			print("Could not open %s for reading." % file_path)
			continue
			
		var content = file.get_as_text()
		file.close()
		
		# Replace dictionary.has() calls with "key" in dictionary
		var has_regex = RegEx.new()
		has_regex.compile("(\\w+)\\.has\\([\"']([^\"']+)[\"']\\)")
		var has_results = has_regex.search_all(content)
		
		if has_results.size() > 0:
			var offset = 0
			
			for match_result in has_results:
				var dict_name = match_result.get_string(1)
				var key_name = match_result.get_string(2)
				var old_text = match_result.get_string()
				var new_text = "\"%s\" in %s" % [key_name, dict_name]
				
				var start_pos = match_result.get_start() + offset
				var end_pos = match_result.get_end() + offset
				
				content = content.substr(0, start_pos) + new_text + content.substr(end_pos)
				offset += new_text.length() - old_text.length()
			
			var write_file = FileAccess.open(file_path, FileAccess.WRITE)
			if write_file:
				write_file.store_string(content)
				write_file.close()
				print("Fixed dictionary access in %s" % file_path)
			else:
				print("Could not write to %s" % file_path)
		else:
			print("No dictionary access issues found in %s" % file_path)

func ensure_empty_script_exists():
	print("Ensuring empty script exists...")
	
	var empty_script_path = "res://addons/gut/temp/__empty.gd"
	var empty_script_dir = "res://addons/gut/temp"
	
	# Create directory if needed
	if not DirAccess.dir_exists_absolute(empty_script_dir):
		DirAccess.make_dir_recursive_absolute(empty_script_dir)
	
	# Create file if needed
	if not FileAccess.file_exists(empty_script_path):
		var file = FileAccess.open(empty_script_path, FileAccess.WRITE)
		if file:
			file.store_string("extends GDScript\n\n# This is an empty script file used by the compatibility layer\n# to replace GDScript.new() functionality in Godot 4.4")
			file.close()
			print("Created empty script at %s" % empty_script_path)
		else:
			print_error("Could not create empty script at %s" % empty_script_path)
	else:
		print("Empty script already exists at %s" % empty_script_path)

func clean_uid_files():
	print("Cleaning UID files...")
	
	var uid_count = 0
	var dir = DirAccess.open("res://addons/gut")
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if file_name.ends_with(".uid"):
				if dir.remove(file_name) == OK:
					uid_count += 1
			file_name = dir.get_next()
		
		print("Removed %d UID files from addons/gut" % uid_count)
	else:
		print_error("Could not open addons/gut directory")

func print_error(message: String):
	print("[ERROR] " + message)