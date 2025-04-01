@tool
extends RefCounted

## GUT Plugin Compatibility Layer for Godot 4.4
##
## This script provides compatibility fixes for common issues that cause
## the GUT plugin to break when reloading the project in Godot 4.4.
## 
## It includes:
## 1. Missing method implementations
## 2. Dictionary access safety patterns 
## 3. Resource path safety
## 4. Scene file corruption detection
## 5. Script loading helpers
## 6. Dynamic GDScript creation and manipulation

const TEMP_RESOURCE_DIR := "res://tests/generated/"
const MAX_SCENE_FILE_SIZE := 100000 # 100KB is suspiciously large for most GUT scenes

##############################################################################
# DYNAMIC SCRIPT CREATION METHODS
# These replace functionality from the missing compatibility.gd file
##############################################################################

## Creates a new GDScript instance
func create_script() -> GDScript:
	var script = GDScript.new()
	if not script:
		push_error("Failed to create new GDScript instance")
		return null
	return script

## Creates a new GDScript with the specified source code
func create_script_from_source(source_code: String) -> GDScript:
	var script = create_script()
	if not script:
		return null
		
	script.source_code = source_code
	var err = script.reload()
	if err != OK:
		push_error("Failed to reload script with source code: %s" % err)
		return null
		
	return script

## Creates a new object from a script
func instantiate_script(script: GDScript) -> Variant:
	if not script:
		push_error("Cannot instantiate null script")
		return null
		
	var instance = script.new()
	if not instance:
		push_error("Failed to instantiate script")
		return null
		
	return instance

## Creates an object directly from source code
func create_object_from_source(source_code: String) -> Variant:
	var script = create_script_from_source(source_code)
	if not script:
		return null
		
	return instantiate_script(script)

##############################################################################
# EXISTING TYPE-SAFE METHODS
##############################################################################

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
	
	push_warning("Type mismatch: expected Vector2 but got %s" % typeof_as_string(result))
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
	
	push_warning("Type mismatch: expected float but got %s" % typeof_as_string(result))
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
		
	# Try to instantiate the script
	var instance = script.new()
	if instance == null:
		push_error("Failed to create instance of: %s" % script_path)
		return null
		
	return instance

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

## Safely get a value from a dictionary with a default
static func dict_get(dict: Dictionary, key: Variant, default_value: Variant = null) -> Variant:
	if dict == null:
		return default_value
	if key in dict:
		return dict[key]
	return default_value

## Ensures a resource has a valid path
static func ensure_resource_path(resource: Resource) -> Resource:
	if resource == null or not is_instance_valid(resource):
		return resource
		
	if resource.resource_path.is_empty():
		# Create destination directory if needed
		ensure_directory_exists(TEMP_RESOURCE_DIR)
		
		# Generate a unique path for testing
		var timestamp = Time.get_unix_time_from_system()
		var class_name_str = resource.get_class().to_lower()
		resource.resource_path = "%s%s_%d.tres" % [TEMP_RESOURCE_DIR, class_name_str, timestamp]
	
	return resource

## Adds required methods to a resource for testing
static func add_methods_to_resource(resource: Resource, methods: Dictionary) -> Resource:
	if resource == null:
		push_error("Cannot add methods to null resource")
		return null
		
	# Create a script to attach to the resource
	var source = "extends %s\n\n" % resource.get_class()
	
	for method_name in methods:
		source += "func %s():\n" % method_name
		source += "\t%s\n\n" % methods[method_name].replace("\n", "\n\t")
	
	var script = GDScript.new()
	script.source_code = source
	var err = script.reload()
	if err != OK:
		push_error("Failed to create script for resource: %s" % err)
		return resource
		
	# Apply the script and ensure resource path
	resource.set_script(script)
	return ensure_resource_path(resource)

## Checks if a scene file is potentially corrupted
static func check_scene_corruption(scene_path: String) -> bool:
	if not FileAccess.file_exists(scene_path):
		return false
		
	var file = FileAccess.open(scene_path, FileAccess.READ)
	if file == null:
		push_warning("Failed to open scene file: %s" % scene_path)
		return false
		
	var file_size = file.get_length()
	if file_size > MAX_SCENE_FILE_SIZE:
		push_warning("Scene file is suspiciously large (%d bytes): %s" % [file_size, scene_path])
		return true
		
	# Look for NUL characters which indicate corruption
	var content = file.get_as_text()
	if content.find(char(0)) != -1:
		push_warning("Scene file contains NUL characters (likely corrupted): %s" % scene_path)
		return true
		
	return false

## Convert a value to a specific type with error handling
static func typeof_as_string(value: Variant) -> String:
	var type_id = typeof(value)
	match type_id:
		TYPE_NIL: return "null"
		TYPE_BOOL: return "bool"
		TYPE_INT: return "int"
		TYPE_FLOAT: return "float"
		TYPE_STRING: return "String"
		TYPE_VECTOR2: return "Vector2"
		TYPE_VECTOR3: return "Vector3"
		TYPE_RECT2: return "Rect2"
		TYPE_TRANSFORM2D: return "Transform2D"
		TYPE_PLANE: return "Plane"
		TYPE_QUATERNION: return "Quaternion"
		TYPE_AABB: return "AABB"
		TYPE_BASIS: return "Basis"
		TYPE_TRANSFORM3D: return "Transform3D"
		TYPE_COLOR: return "Color"
		TYPE_NODE_PATH: return "NodePath"
		TYPE_RID: return "RID"
		TYPE_OBJECT:
			if value:
				return value.get_class()
			return "Object (null)"
		TYPE_DICTIONARY: return "Dictionary"
		TYPE_ARRAY: return "Array"
		TYPE_PACKED_BYTE_ARRAY: return "PackedByteArray"
		TYPE_PACKED_INT32_ARRAY: return "PackedInt32Array"
		TYPE_PACKED_INT64_ARRAY: return "PackedInt64Array"
		TYPE_PACKED_FLOAT32_ARRAY: return "PackedFloat32Array"
		TYPE_PACKED_FLOAT64_ARRAY: return "PackedFloat64Array"
		TYPE_PACKED_STRING_ARRAY: return "PackedStringArray"
		TYPE_PACKED_VECTOR2_ARRAY: return "PackedVector2Array"
		TYPE_PACKED_VECTOR3_ARRAY: return "PackedVector3Array"
		TYPE_PACKED_COLOR_ARRAY: return "PackedColorArray"
		TYPE_SIGNAL: return "Signal"
		TYPE_CALLABLE: return "Callable"
		TYPE_STRING_NAME: return "StringName"
	return "Unknown type (%d)" % type_id

## Fixes references to type safe helper functions in a script
static func fix_type_safe_references(script_path: String) -> bool:
	if not FileAccess.file_exists(script_path):
		push_error("Script not found: %s" % script_path)
		return false
		
	var file = FileAccess.open(script_path, FileAccess.READ)
	if file == null:
		push_error("Failed to open script file: %s" % script_path)
		return false
		
	var content = file.get_as_text()
	file.close()
	
	# Look for missing method calls and replace them
	var found_issues = false
	
	if content.contains("_call_node_method_vector2(") and not content.contains("GutCompatibility._call_node_method_vector2("):
		content = content.replace("_call_node_method_vector2(", "GutCompatibility._call_node_method_vector2(")
		found_issues = true
		
	if content.contains("_call_node_method_float(") and not content.contains("GutCompatibility._call_node_method_float("):
		content = content.replace("_call_node_method_float(", "GutCompatibility._call_node_method_float(")
		found_issues = true
		
	if content.contains("Dictionary.has(") or content.contains(".has("):
		content = content.replace("Dictionary.has(", "GutCompatibility.dict_has_key(")
		content = content.replace(".has(", ".get(")
		found_issues = true
	
	if found_issues:
		# Add import if needed
		if not content.contains("GutCompatibility"):
			var import_line = "const GutCompatibility = preload(\"res://tests/fixtures/helpers/gut_compatibility.gd\")\n"
			var tool_index = content.find("@tool")
			if tool_index >= 0:
				var end_line = content.find("\n", tool_index)
				if end_line >= 0:
					content = content.substr(0, end_line + 1) + import_line + content.substr(end_line + 1)
			else:
				content = import_line + content
		
		# Write fixed content
		file = FileAccess.open(script_path, FileAccess.WRITE)
		if file == null:
			push_error("Failed to open script file for writing: %s" % script_path)
			return false
			
		file.store_string(content)
		file.close()
		push_warning("Fixed script references in: %s" % script_path)
	
	return true

## Script to add GutCompatibility references for autoloading
static func generate_patch_script() -> String:
	return """
	@tool
	extends EditorScript

	func _run():
		print("Patching GUT compatibility issues...")
		
		# Check for problematic scene files
		var gut_dir = "res://addons/gut"
		var output_text_path = gut_dir + "/gui/OutputText.tscn"
		var run_results_path = gut_dir + "/gui/RunResults.tscn"
		
		if FileAccess.file_exists(output_text_path):
			var file_size = FileAccess.open(output_text_path, FileAccess.READ).get_length()
			if file_size > 100000:  # 100KB is suspiciously large
				print("WARNING: OutputText.tscn is likely corrupted (%d bytes)" % file_size)
				print("Consider deleting it and letting Godot rebuild it")
		
		# Create GutCompatibility directory if needed
		if not DirAccess.dir_exists_absolute("res://tests/fixtures/helpers"):
			DirAccess.make_dir_recursive_absolute("res://tests/fixtures/helpers")
		
		# Find scripts with missing method references
		var script_files = []
		find_scripts(script_files, "res://tests")
		
		var fixed_count = 0
		for script_path in script_files:
			var file = FileAccess.open(script_path, FileAccess.READ)
			if file:
				var content = file.get_as_text()
				file.close()
				
				if content.contains("_call_node_method_vector2(") or content.contains("_call_node_method_float(") or content.contains(".has("):
					if fix_script(script_path):
						fixed_count += 1
		
		print("Fixed %d scripts with compatibility issues" % fixed_count)
		print("Patching complete!")
	
	func find_scripts(result: Array, path: String):
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
	
	func fix_script(script_path: String) -> bool:
		var file = FileAccess.open(script_path, FileAccess.READ)
		if not file:
			return false
			
		var content = file.get_as_text()
		file.close()
		
		var found_issues = false
		
		if content.contains("_call_node_method_vector2(") and not content.contains("GutCompatibility._call_node_method_vector2("):
			content = content.replace("_call_node_method_vector2(", "GutCompatibility._call_node_method_vector2(")
			found_issues = true
			
		if content.contains("_call_node_method_float(") and not content.contains("GutCompatibility._call_node_method_float("):
			content = content.replace("_call_node_method_float(", "GutCompatibility._call_node_method_float(")
			found_issues = true
			
		if content.contains("Dictionary.has(") or content.contains(".has("):
			content = content.replace("Dictionary.has(", "GutCompatibility.dict_has_key(")
			content = content.replace(".has(", ".get(")
			found_issues = true
		
		if found_issues:
			# Add import if needed
			if not content.contains("GutCompatibility"):
				var import_line = "const GutCompatibility = preload(\"res://tests/fixtures/helpers/gut_compatibility.gd\")\n"
				var tool_index = content.find("@tool")
				if tool_index >= 0:
					var end_line = content.find("\n", tool_index)
					if end_line >= 0:
						content = content.substr(0, end_line + 1) + import_line + content.substr(end_line + 1)
				else:
					content = import_line + content
			
			# Write fixed content
			file = FileAccess.open(script_path, FileAccess.WRITE)
			if not file:
				return false
				
			file.store_string(content)
			file.close()
			print("Fixed script references in: %s" % script_path)
			return true
		
		return false
	"""

## Patches all known GUT-breaking issues
static func patch_all_issues() -> bool:
	print("Running GUT compatibility patching...")
	
	# Create necessary directories
	ensure_directory_exists(TEMP_RESOURCE_DIR)
	
	# Check for common scene corruption issues
	var gut_scenes = [
		"res://addons/gut/gui/OutputText.tscn",
		"res://addons/gut/gui/RunResults.tscn",
		"res://addons/gut/gui/GutBottomPanel.tscn"
	]
	
	var corrupted_scenes = []
	for scene_path in gut_scenes:
		if check_scene_corruption(scene_path):
			corrupted_scenes.append(scene_path)
	
	if not corrupted_scenes.is_empty():
		push_warning("Potentially corrupted scene files detected: %s" % corrupted_scenes)
		push_warning("Consider deleting these files and letting Godot rebuild them.")
	
	# Find and fix scripts with compatibility issues
	var script_files = []
	find_scripts(script_files, "res://tests")
	
	var fixed_count = 0
	for script_path in script_files:
		if fix_type_safe_references(script_path):
			fixed_count += 1
	
	print("Fixed %d scripts with compatibility issues" % fixed_count)
	print("Patching complete!")
	return true

## Recursively find scripts with a given criteria
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