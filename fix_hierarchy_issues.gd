@tool
extends SceneTree

## Script to fix hierarchy issues in the codebase
##
## This script addresses Container inheritance issues in responsive UI components
## and other hierarchy-related problems that can cause debugger breaks
## Usage: godot --script res://fix_hierarchy_issues.gd

func _init():
	print("\n=== Starting hierarchy issue fix ===")
	
	# Fix class constants to use string paths instead of preloads
	fix_class_constants()
	
	# Clean up test resources
	clean_test_resources()
	
	# Fix class inheritance issues
	fix_component_hierarchy()
	
	print("\n=== Hierarchy issue fix complete ===")
	quit()

func fix_class_constants() -> void:
	print("Fixing class constants in UI components...")
	
	var directories = [
		"res://src/ui/components/base",
		"res://src/ui/components/logbook",
		"res://src/ui/components/character",
		"res://src/ui/components/mission",
		"res://src/ui/components/combat"
	]
	
	for dir_path in directories:
		var dir = DirAccess.open(dir_path)
		if not dir:
			print("Could not open directory: " + dir_path)
			continue
		
		dir.list_dir_begin()
		var file_name = dir.get_next()
		
		while file_name != "":
			if file_name.ends_with(".gd"):
				var file_path = dir_path.path_join(file_name)
				_fix_class_references(file_path)
			
			file_name = dir.get_next()
		
		dir.list_dir_end()

func _fix_class_references(file_path: String) -> void:
	var file = FileAccess.open(file_path, FileAccess.READ)
	if not file:
		print("Could not open file: " + file_path)
		return
	
	var content = file.get_as_text()
	file.close()
	
	var self_class_name = file_path.get_file().get_basename().capitalize() + "Class"
	var original_path = file_path.get_file()
	
	# Check for preloaded self references
	var class_name_regex = RegEx.new()
	class_name_regex.compile('const\\s+([A-Za-z0-9_]+)\\s*=\\s*preload\\(["\'](' + file_path + ')["\']\\)')
	
	var match_result = class_name_regex.search(content)
	if match_result:
		print("Found self-reference in " + file_path)
		var const_name = match_result.get_string(1)
		var preload_path = match_result.get_string(2)
		
		# Replace with string path
		var new_content = content.replace(
			'const ' + const_name + ' = preload("' + preload_path + '")',
			'const ' + const_name + ' := "' + preload_path + '" # Use string path instead of preload'
		)
		
		# Write back to file
		file = FileAccess.open(file_path, FileAccess.WRITE)
		if file:
			file.store_string(new_content)
			file.close()
			print("  ✓ Fixed: " + file_path)
		else:
			print("  ✗ Failed to write: " + file_path)
	else:
		# Check if we need to add a self-reference constant
		if not content.contains(self_class_name) and not content.contains("const ThisClass") and not content.contains("class_name"):
			var class_line = 'const ' + self_class_name + ' := "' + file_path + '" # Class reference as string path\n'
			
			# Find a good position to insert
			var insert_pos = content.find("\n\n", content.find("extends"))
			if insert_pos != -1:
				var new_content = content.substr(0, insert_pos + 1) + class_line + content.substr(insert_pos + 1)
				
				# Write back to file
				file = FileAccess.open(file_path, FileAccess.WRITE)
				if file:
					file.store_string(new_content)
					file.close()
					print("  ✓ Added class reference to: " + file_path)
				else:
					print("  ✗ Failed to write: " + file_path)

func clean_test_resources() -> void:
	print("Cleaning test resources...")
	
	# Remove temporary GUT files
	var temp_dir = "res://addons/gut/temp"
	var dir = DirAccess.open(temp_dir)
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		
		while file_name != "":
			if not dir.current_is_dir() and file_name.ends_with(".gd") and file_name.contains("gut_temp_script"):
				var full_path = temp_dir.path_join(file_name)
				dir.remove(file_name)
				print("  ✓ Removed temporary script: " + file_name)
			
			file_name = dir.get_next()
		
		dir.list_dir_end()
	
	# Remove .uid files in tests directory
	_remove_uid_files("res://tests")

func _remove_uid_files(path: String) -> void:
	var dir = DirAccess.open(path)
	if not dir:
		return
	
	dir.list_dir_begin()
	var file_name = dir.get_next()
	
	while file_name != "":
		var full_path = path.path_join(file_name)
		
		if dir.current_is_dir() and file_name != "." and file_name != "..":
			_remove_uid_files(full_path)
		elif file_name.ends_with(".uid"):
			dir.remove(file_name)
			print("  ✓ Removed UID file: " + full_path)
		
		file_name = dir.get_next()
	
	dir.list_dir_end()

func fix_component_hierarchy() -> void:
	print("Fixing component hierarchy issues...")
	
	# List of potentially problematic components
	var components = [
		"res://src/ui/components/logbook/logbook.gd",
		"res://src/ui/components/base/CampaignResponsiveLayout.gd"
	]
	
	for component_path in components:
		var file = FileAccess.open(component_path, FileAccess.READ)
		if not file:
			print("Could not open file: " + component_path)
			continue
		
		var content = file.get_as_text()
		file.close()
		
		# Check for extends with a Container-derived class
		if content.contains('extends "res://src/ui/components/base/ResponsiveContainer.gd"') or \
		   content.contains('extends "res://src/ui/components/base/CampaignResponsiveLayout.gd"'):
			var component_class_name = component_path.get_file().get_basename().capitalize() + "Class"
			if not content.contains(component_class_name):
				var class_line = 'const ' + component_class_name + ' := "' + component_path + '" # Class reference as string path\n'
				
				# Find a good position to insert
				var insert_pos = content.find("\n\n", content.find("extends"))
				if insert_pos != -1:
					var new_content = content.substr(0, insert_pos + 1) + class_line + content.substr(insert_pos + 1)
					
					# Write back to file
					file = FileAccess.open(component_path, FileAccess.WRITE)
					if file:
						file.store_string(new_content)
						file.close()
						print("  ✓ Added class reference to: " + component_path)
					else:
						print("  ✗ Failed to write: " + component_path)
			else:
				print("  ℹ Already has class reference: " + component_path)