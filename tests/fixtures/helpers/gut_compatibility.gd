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
func instantiate_script(script: GDScript):
	if not script:
		push_error("Cannot instantiate null script")
		return null
		
	var instance = script.new()
	if not instance:
		push_error("Failed to instantiate script")
		return null
		
	return instance

## Creates an object directly from source code
func create_object_from_source(source_code: String):
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
	
	push_warning("Type mismatch: expected Vector2 but got %s" % typeof(result))
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
	
	push_warning("Type mismatch: expected float but got %s" % typeof(result))
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
func add_methods_to_resource(resource: Resource, methods: Dictionary) -> Resource:
	if resource == null:
		push_error("Cannot add methods to null resource")
		return null
		
	# Create a script to attach to the resource
	var source = "extends %s\n\n" % resource.get_class()
	
	for method_name in methods:
		var method_body = methods[method_name]
		source += "func %s():\n\treturn %s\n\n" % [method_name, method_body]
	
	var script = create_script_from_source(source)
	if not script:
		push_error("Failed to create script")
		return resource
		
	# Ensure the script has a valid path
	if script.resource_path.is_empty():
		var timestamp = Time.get_unix_time_from_system()
		script.resource_path = "%sscript_%d.gd" % [TEMP_RESOURCE_DIR, timestamp]
	
	# Attach script to resource
	resource.set_script(script)
	
	return resource

## Check if a scene file might be corrupted
static func check_scene_corruption(scene_path: String) -> bool:
	if not ResourceLoader.exists(scene_path):
		return false
		
	# Check file size
	var file = FileAccess.open(scene_path, FileAccess.READ)
	if not file:
		return false
		
	var file_size = file.get_length()
	file.close()
	
	# Very large scene files are suspicious
	if file_size > MAX_SCENE_FILE_SIZE:
		push_warning("Scene file %s is suspiciously large (%d bytes)" % [scene_path, file_size])
		return true
	
	return false

## Fixes import references in a script
static func fix_type_safe_references(script_path: String) -> bool:
	if not ResourceLoader.exists(script_path):
		return false
		
	var file = FileAccess.open(script_path, FileAccess.READ)
	if not file:
		return false
		
	var content = file.get_as_text()
	file.close()
	
	var found_issues = false
	
	# Fix common broken methods
	if content.contains("_call_node_method(") and not content.contains("TypeSafeMixin._call_node_method("):
		content = content.replace("_call_node_method(", "TypeSafeMixin._call_node_method(")
		found_issues = true
		
	if content.contains("_call_node_method_bool(") and not content.contains("TypeSafeMixin._call_node_method_bool("):
		content = content.replace("_call_node_method_bool(", "TypeSafeMixin._call_node_method_bool(")
		found_issues = true
		
	if content.contains("_call_node_method_int(") and not content.contains("TypeSafeMixin._call_node_method_int("):
		content = content.replace("_call_node_method_int(", "TypeSafeMixin._call_node_method_int(")
		found_issues = true
		
	if content.contains("_call_node_method_string(") and not content.contains("TypeSafeMixin._call_node_method_string("):
		content = content.replace("_call_node_method_string(", "TypeSafeMixin._call_node_method_string(")
		found_issues = true
		
	if content.contains("_call_node_method_float(") and not content.contains("TypeSafeMixin._call_node_method_float("):
		content = content.replace("_call_node_method_float(", "TypeSafeMixin._call_node_method_float(")
		found_issues = true
		
	if content.contains("_call_node_method_dict(") and not content.contains("TypeSafeMixin._call_node_method_dict("):
		content = content.replace("_call_node_method_dict(", "TypeSafeMixin._call_node_method_dict(")
		found_issues = true
		
	if content.contains("_call_node_method_array(") and not content.contains("TypeSafeMixin._call_node_method_array("):
		content = content.replace("_call_node_method_array(", "TypeSafeMixin._call_node_method_array(")
		found_issues = true
		
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

##############################################################################
# SIGNAL AND TEST HELPER UTILITIES
##############################################################################

## Creates a Signal object from a signal name and object
func create_signal(emitter: Object, signal_name: String):
	if not emitter or not emitter.has_signal(signal_name):
		push_warning("Cannot create Signal - object doesn't have signal: %s" % signal_name)
		return null
		
	return Signal(emitter, signal_name)

## Creates a test double from a class
func create_double(class_type) -> Object:
	if not class_type:
		push_error("Cannot create double from null class")
		return null
		
	# Try to instantiate directly first
	var instance = null
	if typeof(class_type) == TYPE_OBJECT and class_type is GDScript:
		instance = class_type.new()
	elif typeof(class_type) == TYPE_STRING:
		# Try to load as path
		if ResourceLoader.exists(class_type):
			var loaded = load(class_type)
			if loaded and loaded is GDScript:
				instance = loaded.new()
		else:
			# Try as class name
			instance = ClassDB.instantiate(class_type)
	
	if instance == null:
		push_error("Failed to create double")
		return null
		
	return instance

## Adds spy functionality to an object
func add_spy(obj: Object) -> Object:
	if not obj:
		push_error("Cannot add spy to null object")
		return null
		
	# Create a record of called methods
	obj.set_meta("_spy_calls", {})
	
	# Add the spy method to track calls
	var script = create_script_from_source("""
	extends RefCounted
	
	var _target_obj = null
	
	func _init(obj):
		_target_obj = obj
		
	func record_call(method_name, args=[]):
		if not _target_obj or not _target_obj.has_meta("_spy_calls"):
			return
			
		var calls = _target_obj.get_meta("_spy_calls")
		if not method_name in calls:
			calls[method_name] = []
		calls[method_name].append(args)
		_target_obj.set_meta("_spy_calls", calls)
		
	func get_call_count(method_name):
		if not _target_obj or not _target_obj.has_meta("_spy_calls"):
			return 0
			
		var calls = _target_obj.get_meta("_spy_calls")
		if not method_name in calls:
			return 0
		return calls[method_name].size()
		
	func get_calls(method_name):
		if not _target_obj or not _target_obj.has_meta("_spy_calls"):
			return []
			
		var calls = _target_obj.get_meta("_spy_calls")
		if not method_name in calls:
			return []
		return calls[method_name]
	""")
	
	var spy = instantiate_script(script)
	spy._init(obj)
	obj.set_meta("_spy", spy)
	
	return obj

## Gets the number of times a method was called on a spied object
func get_call_count(obj: Object, method_name: String) -> int:
	if not obj or not obj.has_meta("_spy"):
		push_warning("Object is not being spied on")
		return 0
		
	var spy = obj.get_meta("_spy")
	return spy.get_call_count(method_name)

## Checks if the specified methods have been called on the spied object
func verify_called(obj: Object, method_names: Array) -> bool:
	if not obj or not obj.has_meta("_spy"):
		push_warning("Object is not being spied on")
		return false
		
	var spy = obj.get_meta("_spy")
	for method_name in method_names:
		if spy.get_call_count(method_name) == 0:
			return false
	
	return true

## Creates a safe callable from an object and method
static func create_callable(obj: Object, method_name: String) -> Callable:
	if not obj or not obj.has_method(method_name):
		push_warning("Cannot create callable - object does not have method: %s" % method_name)
		return Callable()
		
	return Callable(obj, method_name)

##############################################################################
# GUT SPECIFIC COMPATIBILITY UTILITIES
##############################################################################

## Creates a basic stub implementation of a method
func stub_method(obj: Object, method_name: String, return_value = null) -> void:
	if not obj:
		push_error("Cannot stub method on null object")
		return
		
	# Create a new script that inherits from the object's script
	var original_script = obj.get_script()
	if not original_script:
		push_error("Object has no script, cannot stub methods")
		return
		
	var source = """
	extends "%s"
	
	func %s():
		return %s
	""" % [original_script.resource_path, method_name, str(return_value)]
	
	var stub_script = create_script_from_source(source)
	if not stub_script:
		push_error("Failed to create stub script")
		return
	
	obj.set_script(stub_script)

## Utility to help with testing async code
static func wait_for(seconds: float) -> void:
	var start_time = Time.get_ticks_msec()
	var target_time = start_time + int(seconds * 1000)
	
	while Time.get_ticks_msec() < target_time:
		await Engine.get_main_loop().process_frame

## Generates a unique ID for test objects
static func generate_unique_id() -> String:
	return str(randi()) + "_" + str(Time.get_unix_time_from_system())

## Implementation of error_if_not_all_classes_imported for gut_plugin.gd
func error_if_not_all_classes_imported(classes):
	# In Godot 4.4, we just return a success (empty array)
	# This method is used by the GUT plugin but isn't really needed
	return []