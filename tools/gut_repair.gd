@tool
extends EditorScript

## GUT Repair Script
## This script fixes common issues with GUT in Godot 4.4
## Run it from the Editor -> Run Script menu

func _run():
	print("Starting GUT repair process...")
	
	# 1. Delete .uid files
	delete_uid_files()
	
	# 2. Fix corrupted scene files
	fix_scene_files()
	
	# 3. Create temp directory
	create_temp_directory()
	
	# 4. Create empty GDScript file
	create_empty_script()
	
	print("GUT repair completed! Please restart Godot and re-enable the GUT plugin.")

func delete_uid_files():
	print("Deleting .uid files...")
	var dir = DirAccess.open("res://addons/gut")
	if dir:
		_recursive_delete_uid_files(dir, "res://addons/gut")
	else:
		push_error("Could not open GUT directory")

func _recursive_delete_uid_files(dir, path):
	dir.list_dir_begin()
	var file_name = dir.get_next()
	
	while file_name != "":
		if file_name != "." and file_name != "..":
			var full_path = path.path_join(file_name)
			
			if dir.current_is_dir():
				var subdir = DirAccess.open(full_path)
				if subdir:
					_recursive_delete_uid_files(subdir, full_path)
			elif file_name.ends_with(".uid"):
				print("Deleting: " + full_path)
				DirAccess.remove_absolute(full_path)
		
		file_name = dir.get_next()
	
	dir.list_dir_end()

func fix_scene_files():
	print("Fixing corrupted scene files...")
	
	var problematic_files = [
		"res://addons/gut/gui/GutBottomPanel.tscn",
		"res://addons/gut/gui/OutputText.tscn",
		"res://addons/gut/gui/RunResults.tscn"
	]
	
	for file_path in problematic_files:
		var file_size = get_file_size(file_path)
		print("%s size: %d bytes" % [file_path, file_size])
		
		if file_size > 50000: # Likely corrupted if over 50KB
			print("Deleting corrupted file: " + file_path)
			DirAccess.remove_absolute(file_path)

func get_file_size(path):
	if FileAccess.file_exists(path):
		var file = FileAccess.open(path, FileAccess.READ)
		if file:
			var size = file.get_length()
			file.close()
			return size
	
	return 0

func create_temp_directory():
	print("Creating temp directory...")
	var temp_dir = "res://addons/gut/temp"
	if not DirAccess.dir_exists_absolute(temp_dir):
		var err = DirAccess.make_dir_recursive_absolute(temp_dir)
		if err != OK:
			push_error("Failed to create temp directory: %s" % [temp_dir])

func create_empty_script():
	print("Creating empty script file...")
	var empty_script_path = "res://addons/gut/temp/__empty.gd"
	
	if not FileAccess.file_exists(empty_script_path):
		var file = FileAccess.open(empty_script_path, FileAccess.WRITE)
		if file:
			file.store_string("extends GDScript\n\n# This is an empty script file used by the compatibility layer\n# to replace GDScript.new() functionality in Godot 4.4")
			file.close()
			print("Created empty script file: " + empty_script_path)
		else:
			push_error("Failed to create empty script file")
