@tool
extends SceneTree

## Fixes all dictionary.has() calls in the entire codebase
##
## This script automatically fixes dictionary access issues by converting all
## dictionary.has() calls to use the "in" operator syntax for Godot 4.4 compatibility.

const DIRECTORIES_TO_FIX = [
	"res://addons/gut",
	"res://tests",
	"res://src",
	"res://tools"
]

func _init():
	print("Starting dictionary.has() fix process...")
	
	var total_fixed = 0
	var total_files = 0
	var total_changes = 0
	
	for directory in DIRECTORIES_TO_FIX:
		var dir_stats = process_directory(directory)
		total_fixed += dir_stats.fixed_files
		total_files += dir_stats.total_files
		total_changes += dir_stats.total_changes
	
	print("===== Fix Complete =====")
	print("Files processed: %d" % total_files)
	print("Files fixed: %d" % total_fixed)
	print("Total replacements: %d" % total_changes)
	
	quit()

func process_directory(directory_path: String, extensions := ["gd"]) -> Dictionary:
	var result = {
		"fixed_files": 0,
		"total_files": 0,
		"total_changes": 0
	}
	
	var dir = DirAccess.open(directory_path)
	if not dir:
		print("Failed to open directory: %s" % directory_path)
		return result
	
	dir.list_dir_begin()
	var file_name = dir.get_next()
	
	while file_name != "":
		var current_path = directory_path + "/" + file_name
		
		if dir.current_is_dir() and file_name != "." and file_name != "..":
			# Process subdirectory
			var subdir_stats = process_directory(current_path, extensions)
			result.fixed_files += subdir_stats.fixed_files
			result.total_files += subdir_stats.total_files
			result.total_changes += subdir_stats.total_changes
		elif not dir.current_is_dir():
			var ext = file_name.get_extension()
			if extensions.has(ext):
				result.total_files += 1
				var changes = fix_file(current_path)
				if changes > 0:
					result.fixed_files += 1
					result.total_changes += changes
					print("Fixed %d has() calls in %s" % [changes, current_path])
		
		file_name = dir.get_next()
	
	return result

func fix_file(file_path: String) -> int:
	if not FileAccess.file_exists(file_path):
		return 0
	
	var file = FileAccess.open(file_path, FileAccess.READ)
	if not file:
		return 0
	
	var content = file.get_as_text()
	file.close()
	
	# First pattern: dictionary.has("key")
	var pattern1 = "(\\w+)\\.has\\([\"']([^\"']+)[\"']\\)"
	var replacements1 = fix_pattern(content, pattern1, "\"%s\" in %s")
	
	# Second pattern: dictionary.has(variable_key)
	var pattern2 = "(\\w+)\\.has\\(([\\w\\.\\(\\)\\[\\]]+)\\)"
	var replacements2 = fix_pattern(content, pattern2, "%s in %s")
	
	# If changes were made, write the file
	var total_replacements = replacements1 + replacements2
	if total_replacements > 0:
		var write_file = FileAccess.open(file_path, FileAccess.WRITE)
		if write_file:
			write_file.store_string(content)
			write_file.close()
	
	return total_replacements

func fix_pattern(content: String, pattern: String, template: String) -> int:
	var regex = RegEx.new()
	regex.compile(pattern)
	var results = regex.search_all(content)
	
	var replacements = 0
	var offset = 0
	
	for match_result in results:
		var dict_name = match_result.get_string(1)
		var key_name = match_result.get_string(2)
		var old_text = match_result.get_string()
		
		# Skip special cases that shouldn't be converted
		if dict_name == "self" or dict_name == "object" or dict_name == "node" or dict_name == "OS":
			continue
		
		# Skip method calls that happen to match the pattern (common false positives)
		if dict_name in ["ResourceLoader", "ClassDB", "DirAccess", "FileAccess", "Engine", "ProjectSettings"]:
			continue
			
		var new_text = template % [key_name, dict_name]
		
		var start_pos = match_result.get_start() + offset
		var end_pos = match_result.get_end() + offset
		
		content = content.substr(0, start_pos) + new_text + content.substr(end_pos)
		offset += new_text.length() - old_text.length()
		replacements += 1
	
	return replacements