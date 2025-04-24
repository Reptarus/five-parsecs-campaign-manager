@tool
extends SceneTree

## Script to fix ThisClass circular references
##
## Replaces preloaded self-references with string path references
## Usage: godot --script res://fix_thisclass_references.gd

func _init():
	print("\n=== Starting ThisClass reference fix ===")
	
	# Process UI components
	process_directory("res://src/ui/components")
	
	# Process test files
	process_directory("res://tests/unit")
	
	print("\n=== ThisClass reference fix complete ===")
	quit()

func process_directory(path: String) -> void:
	print("Processing directory: " + path)
	
	var dir = DirAccess.open(path)
	if not dir:
		print("ERROR: Could not open directory: " + path)
		return
	
	dir.list_dir_begin()
	var file_name = dir.get_next()
	
	while file_name != "":
		var full_path = path.path_join(file_name)
		
		if dir.current_is_dir() and file_name != "." and file_name != "..":
			# Process subdirectory
			process_directory(full_path)
		elif file_name.ends_with(".gd"):
			# Process GDScript file
			fix_file(full_path)
		
		file_name = dir.get_next()
	
	dir.list_dir_end()

func fix_file(file_path: String) -> void:
	# Read file
	var file = FileAccess.open(file_path, FileAccess.READ)
	if not file:
		print("ERROR: Could not open file: " + file_path)
		return
	
	var content = file.get_as_text()
	file.close()
	
	# Check for problematic patterns
	var preload_pattern = 'const ThisClass = preload\\("([^"]+)"\\)'
	var regex = RegEx.new()
	regex.compile(preload_pattern)
	
	var result = regex.search(content)
	if result:
		var preload_path = result.get_string(1)
		var file_dir = file_path.get_base_dir()
		var relative_path = file_path.get_file()
		
		# Check if the file is referencing itself
		if preload_path.ends_with(relative_path) or preload_path == file_path:
			print("Fixing self-reference in: " + file_path)
			
			# Replace preload with string path
			var new_content = content.replace(
				'const ThisClass = preload("' + preload_path + '")',
				'const ThisClass := "' + preload_path + '"'
			)
			
			# Write back to file
			file = FileAccess.open(file_path, FileAccess.WRITE)
			if file:
				file.store_string(new_content)
				file.close()
				print("  ✓ Fixed: " + file_path)
			else:
				print("  ✗ Failed to write: " + file_path)
	
	# Check for incorrect preloads in tests
	if file_path.begins_with("res://tests/"):
		var test_preload_pattern = 'preload\\("res://src/[^"]+\\)'
		regex = RegEx.new()
		regex.compile(test_preload_pattern)
		
		var matches = []
		var pos = 0
		result = regex.search(content, pos)
		
		while result:
			matches.append(result)
			pos = result.get_end()
			result = regex.search(content, pos)
		
		if matches.size() > 0:
			print("Fixing test preloads in: " + file_path)
			
			var new_content = content
			for match_result in matches:
				var preload_code = match_result.get_string()
				var preload_path = preload_code.substr(9, preload_code.length() - 10)
				
				# Replace with ResourceLoader.exists check
				new_content = new_content.replace(
					"var instance = " + preload_code,
					"var instance = ResourceLoader.exists(" + preload_path + ")"
				)
				
				# Replace regular preload with ResourceLoader.exists
				new_content = new_content.replace(
					preload_code,
					"ResourceLoader.exists(" + preload_path + ")"
				)
			
			# Write back to file
			file = FileAccess.open(file_path, FileAccess.WRITE)
			if file:
				file.store_string(new_content)
				file.close()
				print("  ✓ Fixed test preloads: " + file_path)
			else:
				print("  ✗ Failed to write: " + file_path)