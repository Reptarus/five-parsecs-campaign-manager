@tool
extends Node

## GUT Safety Autoload
##
## This script automatically runs at project startup to ensure
## GUT functions correctly by fixing common issues.

const GUT_COMPATIBILITY_PATH = "res://tests/fixtures/helpers/gut_compatibility.gd"
var GutCompatibility = null

# Constants
const SCENE_PATHS = [
	"res://addons/gut/gui/GutBottomPanel.tscn",
	"res://addons/gut/gui/OutputText.tscn",
	"res://addons/gut/gui/RunResults.tscn"
]
const SUSPICIOUS_SIZE = 100000 # 100KB max size

# Called when the node enters the scene tree for the first time
func _ready():
	# Only run in editor
	if not Engine.is_editor_hint():
		return
		
	print("GutSafety: Running startup checks...")
		
	# Check for corrupted GUT scenes
	_check_gut_scenes()
	
	# Fix UID files
	_clean_gut_uid_files()
	
	# Check autoload scripts
	_check_autoload_scripts()
	
	print("GutSafety: Startup checks completed")

func _run_safety_checks():
	print("GUT Safety: Running preventative checks...")
	
	# Check for corrupted scene files
	_check_gut_scenes()
	
	# Fix dictionary access issues in test files
	_fix_dictionary_access()
	
	# Add missing methods to test files
	_add_missing_methods()
	
	print("GUT Safety: Preventative maintenance complete.")

func _check_gut_scenes():
	for path in SCENE_PATHS:
		if not FileAccess.file_exists(path):
			print("GUT Safety: Scene file missing: " + path)
			continue
			
		var file = FileAccess.open(path, FileAccess.READ)
		if not file:
			print("GUT Safety: Failed to open scene file: " + path)
			continue
			
		var size = file.get_length()
		file.close()
		
		if size > SUSPICIOUS_SIZE:
			print("GUT Safety: Scene file too large (%.2f KB): %s" % [size / 1024.0, path])
			print("GUT Safety: Consider deleting it to let Godot recreate it")

func _fix_dictionary_access():
	var script_files = []
	GutCompatibility.find_scripts(script_files, "res://tests")
	
	var fixed_count = 0
	for script_path in script_files:
		if GutCompatibility.fix_type_safe_references(script_path):
			fixed_count += 1
	
	if fixed_count > 0:
		print("GUT Safety: Fixed dictionary access in %d test files" % fixed_count)

func _add_missing_methods():
	var test_scripts = []
	GutCompatibility.find_scripts(test_scripts, "res://tests")
	
	for script_path in test_scripts:
		if not FileAccess.file_exists(script_path):
			continue
			
		var file = FileAccess.open(script_path, FileAccess.READ)
		if not file:
			continue
			
		var content = file.get_as_text()
		file.close()
		
		# Check for missing vector2 and float methods
		if (content.contains("_call_node_method_vector2") or content.contains("_call_node_method_float")) and not content.contains("GutCompatibility"):
			# Add GutCompatibility import
			var import_line = "const GutCompatibility = preload(\"res://tests/fixtures/helpers/gut_compatibility.gd\")\n"
			
			var tool_index = content.find("@tool")
			if tool_index >= 0:
				var end_line = content.find("\n", tool_index)
				if end_line >= 0:
					content = content.substr(0, end_line + 1) + import_line + content.substr(end_line + 1)
			else:
				content = import_line + content
			
			# Replace method calls
			content = content.replace("_call_node_method_vector2(", "GutCompatibility._call_node_method_vector2(")
			content = content.replace("_call_node_method_float(", "GutCompatibility._call_node_method_float(")
			
			# Write fixed content
			file = FileAccess.open(script_path, FileAccess.WRITE)
			if file:
				file.store_string(content)
				file.close()
				print("GUT Safety: Added missing method references to " + script_path)

func _create_compatibility_layer():
	print("GUT Safety: Creating compatibility layer...")
	
	# Create necessary directories
	var dir_path = "res://tests/fixtures/helpers"
	if not DirAccess.dir_exists_absolute(dir_path):
		DirAccess.make_dir_recursive_absolute(dir_path)
	
	# Create compatibility file with basic implementation
	var file = FileAccess.open(GUT_COMPATIBILITY_PATH, FileAccess.WRITE)
	if file:
		file.store_string("""@tool
extends RefCounted

## GUT Plugin Compatibility Layer for Godot 4.4
##
## This script provides compatibility fixes for common issues that cause
## the GUT plugin to break when reloading the project in Godot 4.4.

## Vector2 method implementations that were missing
static func _call_node_method_vector2(obj: Object, method: String, args: Array = [], default: Vector2 = Vector2.ZERO) -> Vector2:
	if obj == null or not is_instance_valid(obj):
		push_warning("Invalid object for method " + method)
		return default
		
	if method.is_empty():
		push_warning("Invalid method name")
		return default
	
	if not obj.has_method(method):
		push_warning("Method '%s' not found in object" % method)
		return default
		
	var result = obj.callv(method, args)
	
	if result == null:
		return default
	if result is Vector2:
		return result
	if result is Array and result.size() >= 2:
		if (result[0] is float or result[0] is int) and (result[1] is float or result[1] is int):
			return Vector2(float(result[0]), float(result[1]))
	
	push_warning("Type mismatch: expected Vector2 but got " + str(result))
	return default

## Float method implementations that were missing
static func _call_node_method_float(obj: Object, method: String, args: Array = [], default: float = 0.0) -> float:
	if obj == null or not is_instance_valid(obj):
		push_warning("Invalid object for method " + method)
		return default
		
	if method.is_empty():
		push_warning("Invalid method name")
		return default
	
	if not obj.has_method(method):
		push_warning("Method '%s' not found in object" % method)
		return default
		
	var result = obj.callv(method, args)
	
	if result == null:
		return default
	if result is float:
		return result
	if result is int:
		return float(result)
	if result is String and result.is_valid_float():
		return result.to_float()
	
	push_warning("Type mismatch: expected float but got " + str(result))
	return default

## Safely creates a new instance of a class
static func safe_new(script_path: String):
	if not ResourceLoader.exists(script_path):
		push_error("Script not found: %s" % script_path)
		return null
		
	var script = load(script_path)
	if script == null:
		push_error("Failed to load script: %s" % script_path)
		return null
		
	if not script is GDScript:
		push_error("Resource is not a GDScript: %s" % script_path)
		return null
		
	return script.new()

## Ensures a directory exists, creating it if necessary
static func ensure_directory_exists(path: String) -> bool:
	if DirAccess.dir_exists_absolute(path):
		return true
	
	var error = DirAccess.make_dir_recursive_absolute(path)
	if error != OK:
		push_error("Failed to create directory: %s (error: %d)" % [path, error])
		return false
		
	return true

## Dictionary has key (safe replacemnt for .has())
static func dict_has_key(dict: Dictionary, key: Variant) -> bool:
	if dict == null:
		return false
	return key in dict

## Ensures a resource has a valid path
static func ensure_resource_path(resource: Resource) -> Resource:
	if resource == null or not is_instance_valid(resource):
		return resource
		
	if resource.resource_path.is_empty():
		# Create destination directory if needed
		ensure_directory_exists("res://tests/generated/")
		
		# Generate a unique path for testing
		var timestamp = Time.get_unix_time_from_system()
		var class_name_str = resource.get_class().to_lower()
		resource.resource_path = "res://tests/generated/%s_%d.tres" % [class_name_str, timestamp]
	
	return resource

## Checks if a scene file is potentially corrupted
static func check_scene_corruption(scene_path: String) -> bool:
	if not FileAccess.file_exists(scene_path):
		return false
		
	var file = FileAccess.open(scene_path, FileAccess.READ)
	if file == null:
		push_warning("Failed to open scene file: %s" % scene_path)
		return false
		
	var file_size = file.get_length()
	if file_size > 100000:  # 100KB is suspiciously large for most GUT scenes
		push_warning("Scene file is suspiciously large (%d bytes): %s" % [file_size, scene_path])
		return true
		
	# Look for NUL characters which indicate corruption
	var content = file.get_as_text()
	if content.find(char(0)) != -1:
		push_warning("Scene file contains NUL characters (likely corrupted): %s" % scene_path)
		return true
		
	return false

## Find scripts recursively
static func find_scripts(result: Array, path: String):
	var dir = DirAccess.open(path)
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if dir.current_is_dir() and not file_name.begins_with("."):
				find_scripts(result, path.path_join(file_name))
			elif file_name.ends_with(".gd"):
				result.append(path.path_join(file_name))
			file_name = dir.get_next()
""")
		file.close()
		print("GUT Safety: Created compatibility layer at " + GUT_COMPATIBILITY_PATH)
	else:
		push_error("GUT Safety: Failed to create compatibility file")

# Clean up .uid files in the GUT directory
func _clean_gut_uid_files():
	var dir = DirAccess.open("res://addons/gut")
	if not dir:
		print("GUT Safety: Failed to access GUT directory")
		return
		
	_clean_directory(dir, "res://addons/gut")
	
func _clean_directory(dir: DirAccess, path: String):
	dir.list_dir_begin()
	var file_name = dir.get_next()
	
	while file_name != "":
		if file_name.ends_with(".uid"):
			var full_path = path + "/" + file_name
			print("GUT Safety: Removing UID file: " + full_path)
			var err = DirAccess.remove_absolute(full_path)
			if err != OK:
				print("GUT Safety: Failed to remove UID file: " + full_path)
		elif dir.current_is_dir() and file_name != "." and file_name != "..":
			var subdir = DirAccess.open(path + "/" + file_name)
			if subdir:
				_clean_directory(subdir, path + "/" + file_name)
				
		file_name = dir.get_next()
		
	dir.list_dir_end()

# Add a function to check and fix autoload script compilation issues
func _check_autoload_scripts():
	print("GutSafety: Checking autoload scripts for compatibility issues...")
	
	var autoload_paths = [
		"res://src/core/character/Management/CharacterManager.gd",
		"res://src/core/battle/state/BattleStateMachine.gd"
	]
	
	for path in autoload_paths:
		if not FileAccess.file_exists(path):
			print("GutSafety: Autoload script not found: " + path)
			continue
			
		var file = FileAccess.open(path, FileAccess.READ)
		if not file:
			print("GutSafety: Failed to open autoload script: " + path)
			continue
			
		var content = file.get_as_text()
		file.close()
		
		# Check for common issues that cause compilation errors
		var fixed_content = _fix_autoload_script_issues(content, path)
		
		# If changes were made, write the fixed content
		if fixed_content != content:
			print("GutSafety: Fixed issues in autoload script: " + path)
			file = FileAccess.open(path, FileAccess.WRITE)
			if file:
				file.store_string(fixed_content)
				file.close()

# Fix common autoload script issues
func _fix_autoload_script_issues(content: String, path: String) -> String:
	var fixed_content = content
	
	# Replace Dictionary.has() with 'in' operator
	fixed_content = fixed_content.replace(".has(", " in ")
	
	# Add proper null checks
	if "is_instance_valid(" in fixed_content and not "if not is_instance_valid" in fixed_content:
		fixed_content = fixed_content.replace("is_instance_valid(", "if not is_instance_valid(")
	
	# Make sure all arrays are properly initialized
	if path.ends_with("CharacterManager.gd"):
		if "_active_characters = []" in fixed_content and not "func _init" in fixed_content:
			fixed_content = fixed_content.replace("_active_characters = []",
				"_active_characters = [] # Initialize to prevent null reference")
	
	return fixed_content