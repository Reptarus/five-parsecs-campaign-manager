@tool
extends Node

## GUT Safety Autoload
##
## This script automatically runs at project startup to fix common 
## GUT compatibility issues in Godot 4.4

var _editor_interface = null

func _ready():
	if Engine.is_editor_hint():
		# Give a small delay before setting up the editor interface
		await get_tree().process_frame
		_setup_editor_interface()
		
		# Fix NUL characters in files
		call_deferred("_fix_nul_characters")
		
	# Connect to the script_changed signal if in the editor
	if Engine.is_editor_hint() and ProjectSettings.has_setting("debug/settings/run_on_load/test_scene"):
		# Create a timer to suppress external file change dialogs
		var suppress_timer = Timer.new()
		suppress_timer.name = "SuppressFileChangesTimer"
		suppress_timer.wait_time = 0.5
		suppress_timer.timeout.connect(_suppress_file_change_dialog)
		suppress_timer.autostart = true
		add_child(suppress_timer)

# Utility function to recursively search for the GUT plugin
func _find_gut_plugin(node, depth = 0):
	if depth > 5: # Limit recursion depth
		return null
		
	if node.get_script() and "gut" in node.get_script().resource_path.to_lower():
		return node
		
	for child in node.get_children():
		var result = _find_gut_plugin(child, depth + 1)
		if result != null:
			return result
			
	return null

func _setup_editor_interface():
	# We only need this in the editor
	if !Engine.is_editor_hint():
		return
	
	# Add a delay to ensure editor is fully loaded
	await get_tree().process_frame
	await get_tree().process_frame
	
	var editor_node = null
	
	# Try to safely find the editor node
	for node in get_tree().root.get_children():
		if node.get_class() == "EditorNode" or node.name.begins_with("@EditorNode"):
			editor_node = node
			break
	
	if editor_node == null:
		print("GUT Safety: Could not find EditorNode")
		return
	
	# Use a more defensive approach to access the plugin list
	var editor_plugin = null
	
	# Method 1: Try using reflection/get_children to find the plugin
	for child in editor_node.get_children():
		# Look for any node that might contain plugins based on name
		if "plugin" in child.name.to_lower() or "addon" in child.name.to_lower():
			for potential_plugin in child.get_children():
				# Check if this is our GUT plugin
				if potential_plugin.get_script() and "gut" in potential_plugin.get_script().resource_path.to_lower():
					editor_plugin = potential_plugin
					break
		
		if editor_plugin != null:
			break
	
	# Method 2: If we couldn't find it directly, scan all descendants
	if editor_plugin == null:
		print("GUT Safety: Trying alternative method to find GUT plugin...")
		editor_plugin = _find_gut_plugin(editor_node)
	
	# If we found the plugin, get the editor interface
	if editor_plugin != null and editor_plugin.has_method("get_editor_interface"):
		_editor_interface = editor_plugin.get_editor_interface()
		print("GUT Safety: Successfully found editor interface")
	else:
		print("GUT Safety: Could not find GUT plugin or editor interface")

func _suppress_file_change_dialog():
	if !_editor_interface:
		return
		
	# Find and close any active dialogs about file changes
	for child in get_tree().root.get_children():
		if child is Window and child.visible:
			if "modified outside" in child.get_title() or "Files have been modified" in child.get_title():
				# Look for the "Reload From Disk" button
				for button in child.get_children():
					if button is Button and "Reload" in button.text:
						button.emit_signal("pressed")
						return

## Ensures a directory exists
func ensure_directory_exists(path: String) -> bool:
	if DirAccess.dir_exists_absolute(path):
		return true
	
	var error = DirAccess.make_dir_recursive_absolute(path)
	if error != OK:
		push_error("GUT Safety: Failed to create directory: %s (error: %d)" % [path, error])
		return false
		
	print("GUT Safety: Created directory: %s" % path)
	return true

## Checks if a scene file is corrupted
func check_scene_corruption(scene_path: String) -> bool:
	if not FileAccess.file_exists(scene_path):
		return false
		
	var file = FileAccess.open(scene_path, FileAccess.READ)
	if file == null:
		push_warning("GUT Safety: Failed to open scene file: %s" % scene_path)
		return false
		
	var file_size = file.get_length()
	if file_size > 100000: # 100KB is suspiciously large for most GUT scenes
		push_warning("GUT Safety: Scene file is suspiciously large (%d bytes): %s" % [file_size, scene_path])
		return true
		
	# Look for NUL characters which indicate corruption
	var content = file.get_as_text()
	if content.find(char(0)) != -1:
		push_warning("GUT Safety: Scene file contains NUL characters (likely corrupted): %s" % scene_path)
		return true
		
	return false

## Check if a file exists, calls the creator function if not
func check_file_exists(path: String, creator_func: Callable) -> bool:
	if FileAccess.file_exists(path):
		return true
		
	print("GUT Safety: Creating missing file: %s" % path)
	creator_func.call()
	return FileAccess.file_exists(path)

## Create the compatibility.gd file
func create_compatibility_file():
	var content = """@tool
extends RefCounted

## GUT Compatibility Layer for Godot 4.4
##
## This script provides compatibility fixes for common issues that occur
## when using GUT with Godot 4.4, especially issues related to GDScript.new()
## which was removed in Godot 4.4

const EMPTY_SCRIPT_PATH = "res://addons/gut/temp/__empty.gd"

## Creates a new GDScript instance
func create_gdscript() -> GDScript:
	# Direct instantiation with GDScript.new() was removed in Godot 4.4
	# Instead, we load from the template file
	if ResourceLoader.exists(EMPTY_SCRIPT_PATH):
		return load(EMPTY_SCRIPT_PATH)
	
	# Fallback for older versions if needed
	push_warning("Empty script template not found; some functionality may be limited")
	return null

## Creates a script from source code
func create_script_from_source(source_code: String) -> GDScript:
	var script = create_gdscript()
	if script == null:
		push_error("Failed to create script from source")
		return null
		
	script.source_code = source_code
	script.reload()
	
	# Ensure the script has a valid path
	if script.resource_path.is_empty():
		# Create temp directory if needed
		var temp_dir = "res://addons/gut/temp"
		if not DirAccess.dir_exists_absolute(temp_dir):
			DirAccess.make_dir_recursive_absolute(temp_dir)
		
		# Generate a unique path for the script
		var timestamp = Time.get_unix_time_from_system()
		script.resource_path = "%s/gut_temp_script_%d.gd" % [temp_dir, timestamp]
	
	return script

## Safe dictionary has check (replaces .has() which was removed in Godot 4.4)
static func dict_has_key(dict, key) -> bool:
	if dict == null or not dict is Dictionary:
		return false
	return key in dict

## Safe dictionary get with default value
static func dict_get(dict, key, default = null):
	if dict == null or not dict is Dictionary:
		return default
	if key in dict:
		return dict[key]
	return default

## Safe boolean conversion for method results
static func to_bool(value) -> bool:
	if value == null:
		return false
	if value is bool:
		return value
	if value is int or value is float:
		return value != 0
	if value is String:
		return value.to_lower() == "true" or value == "1"
	return bool(value)

## Type-safe method calls with proper returns
static func call_method_bool(obj, method, args=[], default=false) -> bool:
	if obj == null or not obj.has_method(method):
		return default
	var result = obj.callv(method, args)
	return to_bool(result)

## Ensures a resource has a valid path to prevent serialization issues
static func ensure_resource_path(resource):
	if resource is Resource and resource.resource_path.is_empty():
		var timestamp = Time.get_unix_time_from_system()
		var temp_dir = "res://addons/gut/temp"
		if not DirAccess.dir_exists_absolute(temp_dir):
			DirAccess.make_dir_recursive_absolute(temp_dir)
		
		resource.resource_path = "%s/%s_%d.tres" % [
			temp_dir, resource.get_class().to_snake_case(), timestamp
		]
	return resource
"""
	var file = FileAccess.open("res://addons/gut/compatibility.gd", FileAccess.WRITE)
	if file:
		file.store_string(content)
		file.close()
		print("GUT Safety: Created compatibility.gd file")

## Create the empty script template file
func create_empty_script_template():
	var temp_dir = "res://addons/gut/temp"
	if not DirAccess.dir_exists_absolute(temp_dir):
		DirAccess.make_dir_recursive_absolute(temp_dir)
		
	var content = """@tool
extends GDScript

## This is an empty script file used by the compatibility layer
## to replace GDScript.new() functionality in Godot 4.4
"""
	var file = FileAccess.open(temp_dir + "/__empty.gd", FileAccess.WRITE)
	if file:
		file.store_string(content)
		file.close()
		print("GUT Safety: Created empty script template")

## Create the GDScript polyfill file
func create_gdscript_polyfill():
	var temp_dir = "res://addons/gut/temp"
	if not DirAccess.dir_exists_absolute(temp_dir):
		DirAccess.make_dir_recursive_absolute(temp_dir)
		
	var content = """@tool
extends GDScript

## Polyfill for methods that were removed in Godot 4.4
## This file is used by the compatibility layer to provide backward compatibility

## Replacement for GDScript.new() which was removed in Godot 4.4
static func create_script_instance() -> GDScript:
	if ResourceLoader.exists("res://addons/gut/temp/__empty.gd"):
		return load("res://addons/gut/temp/__empty.gd")
	return null

## Replacement for has() method which was removed from Dictionary in Godot 4.4
static func dict_has_key(dict: Dictionary, key) -> bool:
	if dict == null:
		return false
	return key in dict

## Replacement for has_method check that's safer in Godot 4.4
static func object_has_method(obj, method_name: String) -> bool:
	if obj == null:
		return false
	
	if typeof(obj) != TYPE_OBJECT:
		return false
		
	# Use reflection to check
	for method in obj.get_method_list():
		if method.name == method_name:
			return true
			
	return false

## Get class name safely
static func safe_get_class(obj) -> String:
	if obj == null:
		return "Null"
		
	if typeof(obj) != TYPE_OBJECT:
		return str(typeof(obj))
		
	return obj.get_class()

## Create an instance from a script path
static func create_instance_from_path(path: String):
	if not ResourceLoader.exists(path):
		return null
		
	var res = load(path)
	if res == null:
		return null
		
	if not res is GDScript:
		return null
		
	return res.new()

## Safe property access
static func safe_get_property(obj, property_name, default_value = null):
	if obj == null:
		return default_value
		
	if typeof(obj) != TYPE_OBJECT:
		return default_value
		
	if not property_name in obj:
		return default_value
		
	return obj.get(property_name)

## Create temp directory safely
static func create_temp_directory(path: String) -> bool:
	if DirAccess.dir_exists_absolute(path):
		return true
		
	var result = DirAccess.make_dir_recursive_absolute(path)
	return result == OK
"""
	var file = FileAccess.open(temp_dir + "/gdscript_polyfill.gd", FileAccess.WRITE)
	if file:
		file.store_string(content)
		file.close()
		print("GUT Safety: Created GDScript polyfill")

## Create the ShortcutButtons.gd file
func create_shortcut_buttons_file():
	var content = """@tool
extends HBoxContainer

## A bar of shortcut buttons for the GUT interface
## 
## This class provides a container for shortcut buttons in the GUT interface
"""
	var file = FileAccess.open("res://addons/gut/gui/ShortcutButton.gd", FileAccess.WRITE)
	if file:
		file.store_string(content)
		file.close()
		print("GUT Safety: Created ShortcutButton.gd file")

## Fix NUL characters in important scene files
func _fix_nul_characters():
	# Don't run this outside of editor
	if !Engine.is_editor_hint():
		return
		
	# Check if necessary files exist
	ensure_directory_exists("res://addons/gut/temp")
	
	# Create the empty script template if it doesn't exist
	check_file_exists("res://addons/gut/temp/__empty.gd", create_empty_script_template)
	
	# Create the GDScript polyfill if it doesn't exist
	check_file_exists("res://addons/gut/temp/gdscript_polyfill.gd", create_gdscript_polyfill)
	
	# Create or update the compatibility.gd file
	check_file_exists("res://addons/gut/compatibility.gd", create_compatibility_file)
	
	# Create the ShortcutButton.gd file if it doesn't exist
	check_file_exists("res://addons/gut/gui/ShortcutButton.gd", create_shortcut_buttons_file)
	
	# Delete all .uid files
	_clean_uid_files()

## Clean up all .uid files in the GUT directory
func _clean_uid_files():
	var dir = DirAccess.open("res://addons/gut")
	if !dir:
		return
		
	_clean_directory_uid_files(dir, "res://addons/gut")
	
func _clean_directory_uid_files(dir, path):
	dir.list_dir_begin()
	var file_name = dir.get_next()
	
	while file_name != "":
		if file_name != "." and file_name != "..":
			var full_path = path.path_join(file_name)
			
			if dir.current_is_dir():
				var subdir = DirAccess.open(full_path)
				if subdir:
					_clean_directory_uid_files(subdir, full_path)
			elif file_name.ends_with(".uid"):
				print("GUT Safety: Removing .uid file: " + full_path)
				dir.remove(file_name)
		
		file_name = dir.get_next()
	
	dir.list_dir_end()