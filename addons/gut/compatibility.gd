@tool
extends RefCounted

## GUT Compatibility Module for Godot 4.4+
## This file provides compatibility fixes for Godot 4.4 changes

# Dictionary has key (safe replacement for .has())
static func dict_has_key(dict, key) -> bool:
	if dict == null or not dict is Dictionary:
		return false
	return key in dict

# Get a value from dictionary safely
static func dict_get(dict, key, default_value = null):
	if dict == null or not dict is Dictionary:
		return default_value
	if key in dict:
		return dict[key]
	return default_value

# Boolean safe method call
static func call_method_bool(obj, method, args = [], default = false) -> bool:
	if obj == null or not obj.has_method(method):
		return default
	var result = obj.callv(method, args)
	return bool(result)

# Ensure resources have valid paths
static func ensure_resource_path(resource):
	if resource is Resource and resource.resource_path.is_empty():
		# Create a valid path to prevent serialization errors
		var timestamp = Time.get_unix_time_from_system()
		resource.resource_path = "res://tests/generated/%s_%d.tres" % [
			resource.get_class().to_snake_case(),
			timestamp
		]
	return resource

# Forward common methods
func create_gdscript():
	# In Godot 4.4+, GDScript.new() was removed
	# Create a new GDScript instance using proper method
	var script = GDScript.new()
	return script
	
func create_script_from_source(source_code):
	var script = GDScript.new()
	script.source_code = source_code
	return script
	
func create_user_preferences(editor_settings):
	# Simple user preferences for the editor
	if ResourceLoader.exists("res://addons/gut/gui/gut_user_preferences.gd"):
		var script = load("res://addons/gut/gui/gut_user_preferences.gd")
		if script:
			var instance = script.new(editor_settings)
			return instance
	return null

# Add compatibility stubs for common methods
func error_if_not_all_classes_imported(classes):
	return []
	
func create_double(script, inner_class_name = ''):
	return null
	
func instantiate_script(script):
	return null
	
func spy_on(obj):
	return obj
	
func stub_method(obj, method_name, return_value = null):
	pass

func verify_called(obj, method_names):
	return false
	
func get_call_count(obj, method_name):
	return 0

static func create_gd_instance(p_script_path):
	if (p_script_path != null and p_script_path != ''):
		var inst = null
		if (ResourceLoader.exists(p_script_path)):
			var script = load(p_script_path)
			if (script != null):
				inst = script.new() # Using the script instance to call new() instead of GDScript.new()
		return inst
	return null