@tool
extends RefCounted

## GUT Plugin Compatibility Layer for Godot 4.4
##
## This script provides compatibility fixes for common issues that cause
## the GUT plugin to break when reloading the project in Godot 4.4.

## Creates a GDScript instance
##
## In Godot 4.4, GDScript.new() was removed. This function provides a compatible way to
## create GDScript objects.
static func create_gdscript() -> GDScript:
	# We can't use GDScript.new() directly anymore in Godot 4.4
	# Instead, we create an "empty" script object this way - loading a minimal GDScript
	var script = load("res://addons/gut/temp/__empty.gd")
	if script == null:
		# Create and save a minimal empty script if it doesn't exist
		var dir = DirAccess.open("res://addons/gut/temp")
		if dir == null or not DirAccess.dir_exists_absolute("res://addons/gut/temp"):
			DirAccess.make_dir_recursive_absolute("res://addons/gut/temp")
			
		var file = FileAccess.open("res://addons/gut/temp/__empty.gd", FileAccess.WRITE)
		if file:
			file.store_string("extends RefCounted\n")
			file = null
			script = load("res://addons/gut/temp/__empty.gd")
		
	return script

## Create a script from source code
##
## Compatible way to create scripts from source code
static func create_script_from_source(source_code: String, resource_path: String = "") -> GDScript:
	var script = create_gdscript()
	script.source_code = source_code
	
	# Ensure valid resource path
	if resource_path.is_empty():
		var timestamp = Time.get_unix_time_from_system()
		resource_path = "res://addons/gut/temp/dynamic_script_%d.gd" % timestamp
	
	script.resource_path = resource_path
	
	# Make sure temp directory exists
	ensure_temp_directory()
	
	# Reload to compile the script
	script.reload()
	return script

## Ensure GUT temp directory exists
##
## Creates the temp directory if it doesn't exist
static func ensure_temp_directory() -> bool:
	var temp_dir = "res://addons/gut/temp"
	if DirAccess.dir_exists_absolute(temp_dir):
		return true
	
	var err = DirAccess.make_dir_recursive_absolute(temp_dir)
	return err == OK

## Dictionary has key (safe replacement for .has())
##
## In Godot 4.4, dictionary.has() is deprecated in favor of the 'in' operator
static func dict_has_key(dict: Dictionary, key: Variant) -> bool:
	if dict == null:
		return false
	return key in dict

## Safely get a value from a dictionary
static func dict_get(dict: Dictionary, key: Variant, default: Variant = null) -> Variant:
	if dict == null:
		return default
	if key in dict:
		return dict[key]
	return default

## Safely check if an object has a property
static func has_property(obj: Object, property: String) -> bool:
	if obj == null or not is_instance_valid(obj):
		return false
	return obj.has(property)

## Safely check if an object has a method
static func object_has_method(obj: Object, method_name: StringName) -> bool:
	if obj == null or not is_instance_valid(obj):
		return false
	return obj.has_method(method_name)

## Safely call a method on an object
static func safe_call(obj: Object, method: String, args: Array = []) -> Variant:
	if obj == null or not is_instance_valid(obj):
		return null
	if not obj.has_method(method):
		return null
	return obj.callv(method, args)

## Create a user preferences object safely
static func create_user_preferences(editor_settings: EditorSettings = null) -> Object:
	var GutUserPreferences = load("res://addons/gut/gui/gut_user_preferences.gd")
	if GutUserPreferences == null:
		push_error("Could not load user preferences script")
		return null
	
	return GutUserPreferences.new(editor_settings)

## Fix RichTextLabel in UI control
static func fix_output_text_control(control: Control) -> RichTextLabel:
	if control == null or not is_instance_valid(control):
		push_warning("Invalid output text control")
		return null
	
	# Try various ways to get the rich text control
	if control.has_method("get_rich_text_edit"):
		var result = control.get_rich_text_edit()
		if result != null and is_instance_valid(result):
			return result
	
	if control.has_node("RichTextLabel"):
		var result = control.get_node("RichTextLabel")
		if result != null and is_instance_valid(result):
			return result
			
	# Create a new RichTextLabel as fallback
	var text_edit = RichTextLabel.new()
	text_edit.name = "RichTextLabel"
	control.add_child(text_edit)
	
	return text_edit