@tool
extends RefCounted

## Property Exists Patch
## 
## This script provides a standard implementation of property_exists
## that works with Godot 4.4+ and solves the "in" operator issues.
##
## Usage:
## 1. Add to autoload: PropertyExistsPatch
## 2. Replace direct property access checks like this:
##    if obj.has("property") -> if PropertyExistsPatch.property_exists(obj, "property")
##    if "property" in obj -> if PropertyExistsPatch.property_exists(obj, "property")

## Safe property existence check that works across all object types
static func property_exists(obj, property_name: String) -> bool:
	if obj == null:
		return false
	
	# Handle dictionary-like objects
	if obj is Dictionary:
		return property_name in obj
	
	# Handle Resource objects
	if obj is Resource:
		# First check if the property is in the property list
		for prop in obj.get_property_list():
			if prop.name == property_name:
				return true
		
		# Try direct access with get()
		var result = obj.get(property_name)
		return result != null
	
	# Handle Node objects
	if obj is Node:
		if obj.has_method("has_property"):
			return obj.has_property(property_name)
		# Direct property access
		var value = obj.get(property_name)
		return value != null
	
	# Handle other Objects with has method
	if obj.has_method("has"):
		return obj.has(property_name)
	
	# Use direct "in" operator for Godot 4.4+
	return property_name in obj

## Function to automatically patch objects with the has() method
static func patch_object(obj) -> void:
	if obj == null or not obj is Object:
		return
		
	if obj is Resource and not obj.has_method("has"):
		# Create a script that extends the current one
		var current_script = obj.get_script()
		if current_script:
			var script_text = """
extends "%s"

# Add has method for compatibility
func has(property_name: String) -> bool:
	# Check using property list
	for prop in get_property_list():
		if prop.name == property_name:
			return true
			
	# Use direct property access for Godot 4.4+
	return property_name in self
""" % current_script.resource_path
			
			var script = GDScript.new()
			script.source_code = script_text
			script.reload()
			
			# Save properties to restore after script change
			var props = {}
			for prop in obj.get_property_list():
				if prop.usage & PROPERTY_USAGE_SCRIPT_VARIABLE:
					props[prop.name] = obj.get(prop.name)
					
			# Apply the new script
			obj.set_script(script)
			
			# Restore properties
			for prop_name in props:
				obj.set(prop_name, props[prop_name])

## Apply property_exists to all resources in a test class
static func apply_to_test_class(test_class) -> void:
	if not test_class or not test_class is Object:
		return
		
	# Add a function to the test class for easy access
	if not test_class.has_method("property_exists"):
		# Create a reference to the static method
		var prop_exists_func = property_exists
		# Pass function as a callable
		test_class.set("property_exists", func(obj, property_name):
			return prop_exists_func.call(obj, property_name))
