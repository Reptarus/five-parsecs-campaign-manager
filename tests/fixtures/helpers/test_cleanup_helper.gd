@tool
extends RefCounted

## Test cleanup helper for managing temporary test files and resources
##
## This script provides utilities for cleaning up after tests,
## particularly focused on removing temporary files created during tests.

## Cleans up nodes in an array, ensuring they are safely freed
## Returns the number of nodes cleaned up
func cleanup_nodes(nodes: Array) -> int:
	# Check if the input is valid
	if not nodes is Array:
		push_warning("cleanup_nodes received a non-array input")
		return 0

	var count := 0
	
	# Clean up each node in the array
	for node in nodes:
		# Skip invalid nodes
		if node == null:
			continue
			
		# Check if the node is actually a Node instance before trying to queue_free it
		if node is Node:
			if is_instance_valid(node) and not node.is_queued_for_deletion():
				node.queue_free()
				count += 1
		elif node is RefCounted:
			# For reference-counted objects, just remove the reference
			# GDScript will handle garbage collection
			count += 1
		elif node is Resource:
			# For resources, just remove the reference
			# GDScript will handle garbage collection
			count += 1
		else:
			# For other non-Node objects, just log a warning
			push_warning("Cannot queue_free() non-Node object in cleanup_nodes: " + str(node))

	# Return the count of cleaned up nodes
	return count

## Safely clean up resources by releasing their paths
func cleanup_resources(resources: Array) -> void:
	for resource in resources:
		if resource is Resource:
			# Release the resource path to allow garbage collection
			if resource.resource_path and not resource.resource_path.is_empty():
				resource.take_over_path("")
				
			# Clear any properties that might hold references to other objects
			if resource.has_method("_cleanup_for_test"):
				resource._cleanup_for_test()
				
	# Explicitly null out the array to avoid holding references
	resources.clear()

## Cleans up temporary test files from the /tests/temp directory
## Returns the number of files cleaned up
## If keep_recent is true, files modified within the last hour are kept
func cleanup_temp_files(keep_recent: bool = true) -> int:
	# Get the temporary file directory
	var temp_dir := "res://tests/temp"
	
	# Create the directory if it doesn't exist
	var dir := DirAccess.open("res://")
	if not dir.dir_exists(temp_dir.trim_prefix("res://")):
		return 0 # No directory, so no files to clean up
	
	# Clean up all files in the directory
	return _cleanup_files_in_directory(temp_dir, "*", keep_recent)

## Cleans up files matching a specific pattern in the /tests/temp directory
## Returns the number of files cleaned up
func cleanup_files_by_pattern(pattern: String) -> int:
	# Get the temporary file directory
	var temp_dir := "res://tests/temp"
	
	# Create the directory if it doesn't exist
	var dir := DirAccess.open("res://")
	if not dir.dir_exists(temp_dir.trim_prefix("res://")):
		return 0 # No directory, so no files to clean up
	
	# Clean up files matching the pattern
	return _cleanup_files_in_directory(temp_dir, pattern)

## Cleans up files older than max_age_hours in the /tests/temp directory
## Returns the number of files cleaned up
func cleanup_old_files(max_age_hours: int) -> int:
	# Get the temporary file directory
	var temp_dir := "res://tests/temp"
	
	# Create the directory if it doesn't exist
	var dir := DirAccess.open("res://")
	if not dir.dir_exists(temp_dir.trim_prefix("res://")):
		return 0 # No directory, so no files to clean up
	
	# Get the current time
	var current_time := Time.get_unix_time_from_system()
	
	# Calculate the cutoff time
	var cutoff_time := current_time - (max_age_hours * 3600)
	
	# Clean up files older than the cutoff time
	return _cleanup_files_in_directory(temp_dir, "*", false, cutoff_time)

## Internal helper to clean up files in a directory
## Returns the number of files cleaned up
func _cleanup_files_in_directory(directory: String, pattern: String = "*", keep_recent: bool = false, cutoff_time: float = -1.0) -> int:
	var count := 0
	
	# Open the directory
	var dir := DirAccess.open(directory)
	if not dir:
		push_warning("Failed to open directory: " + directory)
		return 0
	
	# List all files in the directory
	dir.list_dir_begin()
	var file_name := dir.get_next()
	
	# Process each file
	while not file_name.is_empty():
		# Skip directories
		if not dir.current_is_dir():
			# Check if the file matches the pattern
			if file_name.match(pattern):
				var file_path := directory.path_join(file_name)
				
				# Check if we should keep recent files
				var should_delete := true
				
				if keep_recent or cutoff_time > 0:
					# Get file modification time
					var file_info := FileAccess.get_modified_time(file_path)
					
					if keep_recent and (Time.get_unix_time_from_system() - file_info < 3600):
						# File was modified within the last hour, keep it
						should_delete = false
					
					if cutoff_time > 0 and file_info >= cutoff_time:
						# File is newer than the cutoff time, keep it
						should_delete = false
				
				# Delete the file if necessary
				if should_delete:
					var error := dir.remove(file_name)
					if error == OK:
						count += 1
					else:
						push_warning("Failed to delete file: " + file_path)
		
		# Get the next file
		file_name = dir.get_next()
	
	# Close the directory
	dir.list_dir_end()
	
	# Return the count of cleaned up files
	return count

## Creates a helper script that can be used by tests
## Returns a GDScript resource that can be used to instance the helper
func create_helper_script(script_content: String, prefix: String = "helper") -> GDScript:
	# Ensure the temp directory exists
	var temp_dir := "res://tests/temp"
	var dir := DirAccess.open("res://")
	if not dir.dir_exists(temp_dir.trim_prefix("res://")):
		dir.make_dir(temp_dir.trim_prefix("res://"))
	
	# Generate a unique filename
	var timestamp := Time.get_unix_time_from_system()
	var random_part := randi() % 10000
	var filename := "%s_%d_%04d.gd" % [prefix, timestamp, random_part]
	var file_path := temp_dir.path_join(filename)
	
	# Create the script file
	var file := FileAccess.open(file_path, FileAccess.WRITE)
	if not file:
		push_error("Failed to create helper script file: " + file_path)
		return null
	
	# Write the script content
	file.store_string(script_content)
	file.close()
	
	# Load the script
	var script := load(file_path)
	if not script:
		push_error("Failed to load helper script: " + file_path)
		return null
	
	# Return the script
	return script