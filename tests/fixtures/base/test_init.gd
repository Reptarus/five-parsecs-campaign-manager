@tool
extends Node

## Base Test Initialization
##
## Extend your test classes from this script instead of directly from "res://addons/gut/test.gd"
## to automatically get Godot 4.4+ compatibility helpers.
##
## Example usage:
## ```
## extends "res://tests/fixtures/base/test_init.gd"
##
## func test_something():
##    # Now you can safely use property_exists
##    assert_true(property_exists(my_object, "some_property"))
## ```

# Script paths - will be loaded dynamically
const PROPERTY_EXISTS_PATCH_PATH = "res://tests/fixtures/helpers/property_exists_patch.gd"
const TEST_COMPATIBILITY_HELPER_PATH = "res://tests/fixtures/helpers/test_compatibility_helper.gd"

# Dynamically loaded references
var _property_exists_patch = null
var _test_compatibility_helper = null

# Property existence checker that works with Godot 4.4+
func property_exists(obj, property_name: String) -> bool:
	# Use singleton if available
	if Engine.has_singleton("PropertyExistsPatch"):
		return Engine.get_singleton("PropertyExistsPatch").property_exists(obj, property_name)
	
	# Use dynamically loaded instance if available
	if _property_exists_patch != null:
		return _property_exists_patch.property_exists(obj, property_name)
	
	# Fallback to direct implementation if neither is available
	if obj == null:
		return false
		
	# For dictionaries
	if obj is Dictionary:
		return property_name in obj
		
	# For resources
	if obj is Resource:
		for prop in obj.get_property_list():
			if prop.name == property_name:
				return true
	
	# Use Godot 4.4+ direct syntax as fallback
	return property_name in obj

# Called when the test is first loaded
func _init() -> void:
	# Load dependencies
	_load_dependencies()
	
	# Apply patch methods to this test class
	_apply_compatibility_methods()

# Dynamically load dependencies to avoid linter errors
func _load_dependencies() -> void:
	# Load PropertyExistsPatch
	if ResourceLoader.exists(PROPERTY_EXISTS_PATCH_PATH):
		_property_exists_patch = load(PROPERTY_EXISTS_PATCH_PATH)
	
	# Load TestCompatibilityHelper
	if ResourceLoader.exists(TEST_COMPATIBILITY_HELPER_PATH):
		_test_compatibility_helper = load(TEST_COMPATIBILITY_HELPER_PATH)

# Applies compatible methods to this test instance
func _apply_compatibility_methods() -> void:
	# Make sure we have the property_exists method
	if not has_method("property_exists"):
		# We already defined it above, but this ensures subclasses have it too
		if Engine.has_singleton("PropertyExistsPatch"):
			Engine.get_singleton("PropertyExistsPatch").apply_to_test_class(self)
		elif _property_exists_patch != null:
			_property_exists_patch.apply_to_test_class(self)

# Object patching for fixing Resources
func patch_object(obj: Object) -> Object:
	if Engine.has_singleton("PropertyExistsPatch"):
		return Engine.get_singleton("PropertyExistsPatch").patch_object(obj)
	elif _property_exists_patch != null:
		return _property_exists_patch.patch_object(obj)
	return obj

# Safe helper for dictionary existence checks
func dict_has_key(dict: Dictionary, key) -> bool:
	if dict == null:
		return false
	return key in dict

# Use this instead of direct property access when property might not exist
func get_property(obj, property_name: String, default_value = null):
	if not property_exists(obj, property_name):
		return default_value
	return obj.get(property_name)

# Safely call a method that might not exist
func call_method(obj, method_name: String, args: Array = []):
	if _test_compatibility_helper != null:
		return _test_compatibility_helper.call_method(obj, method_name, args)
	
	# Fallback implementation
	if obj == null or not obj.has_method(method_name):
		return null
	return obj.callv(method_name, args)

# Helper method for safely setting object properties
func set_property(obj, property_name: String, value) -> bool:
	if obj == null:
		return false
		
	if not property_exists(obj, property_name):
		return false
		
	obj.set(property_name, value)
	return true