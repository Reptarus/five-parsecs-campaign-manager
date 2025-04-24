@tool
extends RefCounted

# Import the main compatibility helper
const TestCompatibilityHelper = preload("res://tests/fixtures/helpers/test_compatibility_helper.gd")

## Helper class for Godot 4.4 compatibility in tests
## This provides simpler aliases for common compatibility methods

## Safely check if an object has a property
## Use this instead of obj.has("property")
static func has_property(obj, property_name: String) -> bool:
	return TestCompatibilityHelper.property_exists(obj, property_name)

## Safely check if a dictionary has a key
## Use this instead of dict.has(key)
static func dict_has_key(dict: Dictionary, key) -> bool:
	return key in dict

## Safely check if an object has a method
## Use this instead of obj.has_method if unsure about object type
static func has_method_safe(obj, method_name: String) -> bool:
	return TestCompatibilityHelper.has_method_safe(obj, method_name)

## Safely get a property value with default
## Use this instead of direct property access when property might not exist
static func get_property(obj, property_name: String, default_value = null):
	if not has_property(obj, property_name):
		return default_value
	return obj.get(property_name)

## Safely call a method that might not exist
## Works with getters/setters too
static func call_method(obj, method_name: String, args: Array = []):
	return TestCompatibilityHelper.call_method(obj, method_name, args)

## Add has_property method to a Resource
## Use this to patch Resources that use the has method
static func patch_resource(resource: Resource) -> Resource:
	if resource == null:
		return null
		
	# Check if resource already has a has method
	if resource.has_method("has"):
		return resource
		
	# Create a new script extending the original
	var original_script = resource.get_script()
	if not original_script:
		return resource
		
	var script_text = """
extends "%s"

# Add has method for compatibility with Godot 4.4
func has(property_name: String) -> bool:
	# Check using property list first
	for prop in get_property_list():
		if prop.name == property_name:
			return true
			
	# Try direct property access
	if property_name in self:
		return true
	
	# Try getter methods for common patterns
	if has_method("get_" + property_name):
		return true
		
	if has_method("is_" + property_name):
		return true
	
	return false
""" % original_script.resource_path
	
	# Create temp directory if needed
	if not TestCompatibilityHelper.ensure_temp_directory():
		push_warning("Could not create temp directory for script")
		return resource
		
	# Write the script to a file
	var script_path = "res://tests/temp/resource_patch_%d.gd" % Time.get_unix_time_from_system()
	if TestCompatibilityHelper.write_gdscript_to_file(script_path, script_text):
		var patched_script = load(script_path)
		if patched_script:
			# Save properties if possible
			var props = {}
			for prop in resource.get_property_list():
				if prop.usage & PROPERTY_USAGE_SCRIPT_VARIABLE:
					props[prop.name] = resource.get(prop.name)
			
			# Apply the patched script
			resource.set_script(patched_script)
			
			# Restore properties
			for prop_name in props:
				resource.set(prop_name, props[prop_name])
		else:
			push_warning("Could not load patched script")
	else:
		push_warning("Could not write script to file")
	
	return resource