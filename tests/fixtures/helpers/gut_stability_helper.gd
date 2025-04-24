@tool
extends RefCounted
## GUT Stability Helper
##
## Preventative maintenance for GUT to avoid common issues
## Run this script regularly to keep GUT working properly

const EMPTY_SCRIPT_PATH = "res://addons/gut/temp/__empty.gd"

## Fixes common GUT issues that cause it to break on project reload
## Call this from a tool script or from the command line
static func fix_gut_stability() -> void:
	print("Fixing GUT stability issues...")
	
	# Ensure the empty script directory exists
	_ensure_empty_script_exists()
	
	# Clean up .uid files
	_clean_uid_files()
	
	# Fix scene files if they're too large (corrupted)
	_fix_large_scene_files()
	
	# Fix compatibility issues in key files
	_patch_compatibility_scripts()
	
	print("GUT stability fixes complete!")

## Creates the empty script used by the compatibility layer
static func _ensure_empty_script_exists() -> void:
	# Create the directory if it doesn't exist
	var dir = DirAccess.open("res://addons/gut")
	if dir:
		if not dir.dir_exists("temp"):
			dir.make_dir("temp")
	
	# Create the empty script file if needed
	var file_path = EMPTY_SCRIPT_PATH
	if not FileAccess.file_exists(file_path):
		var file = FileAccess.open(file_path, FileAccess.WRITE)
		if file:
			file.store_string("extends GDScript\n\n# This is an empty script file used by the compatibility layer\n# to replace GDScript.new() functionality in Godot 4.4\n")
			file.close()
			print("Created empty script at " + file_path)

## Deletes all .uid files in the GUT directory to avoid conflicts
static func _clean_uid_files() -> void:
	var deleted_count = 0
	var dir = DirAccess.open("res://addons/gut")
	if dir:
		_delete_uids_recursive(dir, "res://addons/gut", deleted_count)
	
	print("Deleted " + str(deleted_count) + " .uid files")

## Recursive function to delete .uid files
static func _delete_uids_recursive(dir: DirAccess, path: String, deleted_count: int) -> void:
	# Delete all .uid files in this directory
	dir.list_dir_begin()
	var file_name = dir.get_next()
	while file_name != "":
		if not dir.current_is_dir():
			if file_name.ends_with(".uid"):
				var full_path = path + "/" + file_name
				dir.remove(file_name)
				deleted_count += 1
		file_name = dir.get_next()
	dir.list_dir_end()
	
	# Process subdirectories
	dir.list_dir_begin()
	var dir_name = dir.get_next()
	while dir_name != "":
		if dir.current_is_dir() and dir_name != "." and dir_name != "..":
			var subdir = DirAccess.open(path + "/" + dir_name)
			if subdir:
				_delete_uids_recursive(subdir, path + "/" + dir_name, deleted_count)
		dir_name = dir.get_next()
	dir.list_dir_end()

## Checks and fixes potentially corrupted scene files
static func _fix_large_scene_files() -> void:
	var suspect_scenes = [
		"res://addons/gut/gui/GutBottomPanel.tscn",
		"res://addons/gut/gui/OutputText.tscn",
		"res://addons/gut/gui/RunResults.tscn"
	]
	
	for scene_path in suspect_scenes:
		if FileAccess.file_exists(scene_path):
			var file = FileAccess.open(scene_path, FileAccess.READ)
			if file:
				var size = file.get_length()
				file.close()
				
				# If file is suspiciously large, it might be corrupted
				if size > 100000: # 100KB
					print("Warning: Found potentially corrupted scene file: " + scene_path + " (" + str(size / 1000) + " KB)")
					print("You may need to reset this file or reinstall GUT")

## Patches key scripts to ensure compatibility with Godot 4.4
static func _patch_compatibility_scripts() -> void:
	var compatibility_script = "res://addons/gut/compatibility.gd"
	
	if FileAccess.file_exists(compatibility_script):
		var file = FileAccess.open(compatibility_script, FileAccess.READ)
		if file:
			var content = file.get_as_text()
			file.close()
			
			# Check if the create_gdscript method is missing
			if content.find("func create_gdscript") == -1:
				print("Patching compatibility script with create_gdscript method")
				
				# Find the end of the class to append the new methods
				var class_end = content.rfind("}")
				if class_end != -1:
					var new_methods = """
# Added to maintain compatibility with Godot 4.4
const EMPTY_SCRIPT_PATH = "res://addons/gut/temp/__empty.gd"

func create_gdscript() -> GDScript:
	return load(EMPTY_SCRIPT_PATH)

func create_script_from_source(source_code: String) -> GDScript:
	var script = create_gdscript()
	script.source_code = source_code
	script.reload()
	return script

func create_user_preferences(editor_settings):
	var script = load("res://addons/gut/gui/gut_user_preferences.gd")
	var instance = script.new()
	if instance.has_method("setup"):
		instance.setup(editor_settings)
	return instance
"""
					
					# Insert the new methods before the last closing brace
					content = content.substr(0, class_end) + new_methods + content.substr(class_end)
					
					# Write the updated content back to the file
					file = FileAccess.open(compatibility_script, FileAccess.WRITE)
					if file:
						file.store_string(content)
						file.close()
						print("Successfully patched compatibility script")
	else:
		print("Compatibility script not found at: " + compatibility_script)