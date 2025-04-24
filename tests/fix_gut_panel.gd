@tool
extends EditorScript

## GUT Panel Fix Script
##
## This script helps reset and properly configure the GUT panel
## to show all elements as expected.

func _run():
	print("Fixing GUT Panel Configuration...")
	
	# Ensure temp directory exists
	var temp_dir = "user://gut_temp_directory"
	if not DirAccess.dir_exists_absolute(temp_dir):
		var err = DirAccess.make_dir_recursive_absolute(temp_dir)
		if err != OK:
			push_error("Failed to create temp directory: %s" % [temp_dir])
	
	# Delete any problematic settings files
	var files_to_delete = [
		temp_dir.path_join("gut_editor_config.json"),
		temp_dir.path_join("gut_editor_shortcuts.cfg")
	]
	
	for file_path in files_to_delete:
		if FileAccess.file_exists(file_path):
			var err = DirAccess.remove_absolute(file_path)
			if err == OK:
				print("Deleted: " + file_path)
			else:
				push_error("Failed to delete: " + file_path)
	
	# Create a fresh config file with default settings
	var config = {
		"dirs": [
			"res://tests/unit/",
			"res://tests/integration/",
			"res://tests/battle/",
			"res://tests/performance/",
			"res://tests/mobile/",
			"res://tests/diagnostic/"
		],
		"double_strategy": "partial",
		"include_subdirs": true,
		"log_level": 3,
		"opacity": 100,
		"prefix": "test_",
		"selected": "",
		"should_exit": false,
		"should_maximize": true,
		"suffix": ".gd",
		"inner_class": "",
		"hide_orphans": false,
		"should_exit_on_success": false,
		"hide_settings": false,
		"hide_result_tree": false,
		"hide_output_text": false
	}
	
	var config_path = temp_dir.path_join("gut_editor_config.json")
	var file = FileAccess.open(config_path, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(config, "  "))
		file.close()
		print("Created fresh config at: " + config_path)
	
	# Check for missing scripts
	var required_scripts = [
		"res://addons/gut/gui/GutBottomPanel.gd",
		"res://addons/gut/gui/editor_globals.gd",
		"res://addons/gut/gui/panel_controls.gd",
		"res://addons/gut/gui/gut_user_preferences.gd"
	]
	
	for script_path in required_scripts:
		if not FileAccess.file_exists(script_path):
			push_error("Missing required script: " + script_path)
	
	# Clean up any .uid files that might be causing issues
	var uid_dir = "res://addons/gut"
	var uid_count = 0
	_remove_uid_files(uid_dir, uid_count)
	print("Removed %d .uid files" % uid_count)
	
	print("Done! Please restart the editor and re-enable the GUT plugin.")
	print("If issues persist, follow these steps:")
	print("1. Disable the GUT plugin in Project Settings > Plugins")
	print("2. Restart Godot")
	print("3. Re-enable the GUT plugin")
	print("4. Click the 'GUT' button at the bottom panel to open the GUT interface")

func _remove_uid_files(dir_path: String, count: int) -> void:
	var dir = DirAccess.open(dir_path)
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		
		while file_name != "":
			if dir.current_is_dir() and file_name != "." and file_name != "..":
				# Recursively process subdirectories
				_remove_uid_files(dir_path.path_join(file_name), count)
			elif file_name.ends_with(".uid"):
				var full_path = dir_path.path_join(file_name)
				var err = dir.remove(file_name)
				if err == OK:
					count += 1
				else:
					push_error("Failed to delete: " + full_path)
			
			file_name = dir.get_next() 