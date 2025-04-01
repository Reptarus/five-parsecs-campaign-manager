@tool
extends RefCounted

## Test cleanup helper for managing temporary test files and resources
##
## This script provides utilities for cleaning up after tests,
## particularly focused on removing temporary files created during tests.

## Cleans up temporary test files from /tests/temp directory
##
## @param {bool} keep_recent - Whether to keep files created in the last hour
## @return {int} The number of files deleted
static func cleanup_temp_files(keep_recent: bool = true) -> int:
	var dir = DirAccess.open("res://tests/temp")
	if not dir:
		push_warning("Could not open temporary directory")
		return 0
	
	var count := 0
	var current_time := Time.get_unix_time_from_system()
	var one_hour := 3600 # seconds
	
	# Iterate through all files
	dir.list_dir_begin()
	var file_name = dir.get_next()
	while file_name != "":
		if not dir.current_is_dir():
			var delete_file := true
			
			if keep_recent:
				# Check file modification time
				var file_path = "res://tests/temp/" + file_name
				var file_modified = FileAccess.get_modified_time(file_path)
				
				# Keep files modified within the last hour
				if current_time - file_modified < one_hour:
					delete_file = false
			
			if delete_file:
				# Remove the file
				var err = dir.remove(file_name)
				if err == OK:
					count += 1
				else:
					push_warning("Failed to delete temporary file: %s (error: %d)" % [file_name, err])
		
		file_name = dir.get_next()
	
	dir.list_dir_end()
	return count

## Cleans up files matching a specific pattern
##
## @param {String} pattern - Glob pattern to match files against
## @return {int} The number of files deleted
static func cleanup_files_by_pattern(pattern: String) -> int:
	var dir = DirAccess.open("res://tests/temp")
	if not dir:
		push_warning("Could not open temporary directory")
		return 0
	
	var count := 0
	
	# Iterate through all files
	dir.list_dir_begin()
	var file_name = dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.match(pattern):
			# Remove the file
			var err = dir.remove(file_name)
			if err == OK:
				count += 1
			else:
				push_warning("Failed to delete temporary file: %s (error: %d)" % [file_name, err])
		
		file_name = dir.get_next()
	
	dir.list_dir_end()
	return count

## Cleans up files older than a specific age
##
## @param {int} max_age_hours - Maximum age of files to keep in hours
## @return {int} The number of files deleted
static func cleanup_old_files(max_age_hours: int) -> int:
	var dir = DirAccess.open("res://tests/temp")
	if not dir:
		push_warning("Could not open temporary directory")
		return 0
	
	var count := 0
	var current_time := Time.get_unix_time_from_system()
	var max_age_seconds := max_age_hours * 3600
	
	# Iterate through all files
	dir.list_dir_begin()
	var file_name = dir.get_next()
	while file_name != "":
		if not dir.current_is_dir():
			# Check file modification time
			var file_path = "res://tests/temp/" + file_name
			var file_modified = FileAccess.get_modified_time(file_path)
			
			# Delete files older than max_age_hours
			if current_time - file_modified > max_age_seconds:
				var err = dir.remove(file_name)
				if err == OK:
					count += 1
				else:
					push_warning("Failed to delete old file: %s (error: %d)" % [file_name, err])
		
		file_name = dir.get_next()
	
	dir.list_dir_end()
	return count

## Creates a helper script that can be used by tests
##
## @param {String} script_content - The GDScript source code
## @param {String} prefix - Optional prefix for the filename
## @return {GDScript} The loaded script resource
static func create_helper_script(script_content: String, prefix: String = "helper") -> GDScript:
	# First ensure the temp directory exists
	var dir = DirAccess.open("res://")
	if not dir:
		push_warning("Could not open root directory")
		return null
		
	var temp_path = "res://tests/temp"
	if not dir.dir_exists(temp_path):
		var err = dir.make_dir_recursive(temp_path)
		if err != OK:
			push_warning("Failed to create temp directory: %s (error: %d)" % [temp_path, err])
			return null
	
	# Generate a unique filename
	var timestamp = Time.get_unix_time_from_system()
	var random_id = randi() % 1000000
	var script_path = "res://tests/temp/%s_%d_%d.gd" % [prefix, timestamp, random_id]
	
	# Write the script to a file
	var file = FileAccess.open(script_path, FileAccess.WRITE)
	if not file:
		push_warning("Could not create script file: " + script_path)
		return null
		
	file.store_string(script_content)
	file.close()
	
	# Load and return the script
	var script = load(script_path)
	if not script:
		push_warning("Failed to load helper script: " + script_path)
		return null
		
	return script