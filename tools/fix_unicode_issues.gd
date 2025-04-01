@tool
extends SceneTree

## Unicode Issue Fixer
## Run this script with: godot -s tools/fix_unicode_issues.gd
##
## This fixes Unicode parsing issues by removing NUL characters
## and other problematic binary data from GDScript files

func _init():
	print("Starting Unicode issue fix...")
	
	# Process directories
	var directories = [
		"res://addons/gut/",
		"res://tests/",
		"res://src/" # Add src directory as well
	]
	
	var fixed_count = 0
	
	for directory in directories:
		fixed_count += process_directory(directory)
	
	print("Completed Unicode fix. Fixed " + str(fixed_count) + " files.")
	quit()

func process_directory(path: String) -> int:
	var dir = DirAccess.open(path)
	if dir == null:
		print("Failed to open directory: " + path)
		return 0
	
	var fixed_count = 0
	
	dir.list_dir_begin()
	var file_name = dir.get_next()
	
	while file_name != "":
		if file_name != "." and file_name != "..":
			var full_path = path + file_name
			
			if dir.current_is_dir():
				fixed_count += process_directory(full_path + "/")
			elif file_name.ends_with(".gd") or file_name.ends_with(".tscn") or file_name.ends_with(".tres"):
				if fix_unicode_in_file(full_path):
					fixed_count += 1
		
		file_name = dir.get_next()
	
	dir.list_dir_end()
	return fixed_count

func fix_unicode_in_file(file_path: String) -> bool:
	print("Checking: " + file_path)
	
	# Try to open in binary mode first to check for NUL bytes
	var file_bin = FileAccess.open(file_path, FileAccess.READ)
	if file_bin == null:
		print("  Failed to open file: " + file_path)
		return false
	
	# Read file content as raw bytes first
	var file_size = file_bin.get_length()
	file_bin.seek(0)
	var binary_content = file_bin.get_buffer(file_size)
	file_bin.close()
	
	# Check for NUL bytes in binary content
	var has_nul_bytes = false
	var nul_positions = []
	for i in range(binary_content.size()):
		if binary_content[i] == 0: # NUL byte
			has_nul_bytes = true
			nul_positions.append(i)
	
	if has_nul_bytes:
		var display_positions = nul_positions.slice(0, min(10, nul_positions.size()))
		var ellipsis = "..." if nul_positions.size() > 10 else ""
		print("  Found " + str(nul_positions.size()) + " NUL bytes at positions: " + str(display_positions) + ellipsis)
	
	# Now read as text and clean it up
	var file = FileAccess.open(file_path, FileAccess.READ)
	var content = file.get_as_text()
	file.close()
	
	# Check for NUL characters and other problematic content
	var original_length = content.length()
	
	# More thorough approach to remove NUL characters (Unicode 0)
	# 1. Try the unicode replacement
	content = content.replace("\u0000", "")
	
	# 2. Also try ASCII NUL
	content = content.replace(char(0), "")
	
	# Also remove other potentially problematic control characters
	for i in range(1, 32):
		if i != 9 and i != 10 and i != 13: # Skip tab, LF, CR
			var char_to_remove = char(i)
			content = content.replace(char_to_remove, "")
	
	var new_length = content.length()
	
	if new_length != original_length or has_nul_bytes:
		print("  Fixed Unicode issues in: " + file_path)
		print("  Removed " + str(original_length - new_length) + " problematic characters")
		
		# Save the cleaned file
		file = FileAccess.open(file_path, FileAccess.WRITE)
		if file == null:
			print("  Failed to write fixed file: " + file_path)
			return false
		
		file.store_string(content)
		file.close()
		return true
	
	return false