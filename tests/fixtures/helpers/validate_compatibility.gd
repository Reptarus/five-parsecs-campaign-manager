@tool
extends EditorScript

const Compatibility = preload("res://tests/fixtures/helpers/test_compatibility_helper.gd")

## Test script to validate the compatibility helper functions
## This will help ensure that our fixes work correctly

func _run():
	print("Validating compatibility helper functions...")
	
	# Test ensure_resource_path with one argument
	var resource1 = Resource.new()
	resource1 = Compatibility.ensure_resource_path(resource1)
	print("Resource path with default prefix: ", resource1.resource_path)
	assert(not resource1.resource_path.is_empty(), "Resource path should not be empty")
	
	# Test ensure_resource_path with two arguments
	var resource2 = Resource.new()
	resource2 = Compatibility.ensure_resource_path(resource2, "test_prefix")
	print("Resource path with custom prefix: ", resource2.resource_path)
	assert(resource2.resource_path.contains("test_prefix"), "Resource path should contain the custom prefix")
	
	# Test safe_call_method for existing method
	var obj = RefCounted.new()
	var result1 = Compatibility.safe_call_method(obj, "get_script", [], null)
	print("Safe call to existing method: ", result1)
	
	# Test safe_call_method for non-existing method with fallback
	var dict_obj = {"property": "value"}
	var result2 = Compatibility.safe_call_method(dict_obj, "get_property", [], "default")
	print("Safe call to non-existing method with fallback to property: ", result2)
	
	# Test safe_call_method for is_x method fallback
	var bool_obj = {"valid": true}
	var result3 = Compatibility.safe_call_method(bool_obj, "is_valid", [], false)
	print("Safe call to is_x method with fallback: ", result3)
	
	# Test safe_call_method for set_x method fallback
	var set_obj = {"name": "old"}
	Compatibility.safe_call_method(set_obj, "set_name", ["new"], null)
	print("After safe call to set_x method: ", set_obj.name)
	assert(set_obj.name == "new", "Property should be updated by set_x fallback")
	
	# Test safe_call_method for has_x method with dictionary fallback
	var dict_container = {"items": {"key1": "value1", "key2": "value2"}}
	var has_result1 = Compatibility.safe_call_method(dict_container, "has_items", ["key1"], false)
	print("Safe call to has_x with dictionary: ", has_result1)
	assert(has_result1, "has_items should return true for existing key")
	
	var has_result2 = Compatibility.safe_call_method(dict_container, "has_items", ["key3"], false)
	print("Safe call to has_x with dictionary for missing key: ", has_result2)
	assert(not has_result2, "has_items should return false for missing key")
	
	# Test dict_has_key
	assert(Compatibility.dict_has_key({"key": "value"}, "key"), "dict_has_key should return true for existing key")
	assert(not Compatibility.dict_has_key({"key": "value"}, "missing"), "dict_has_key should return false for missing key")
	
	print("All compatibility helper tests passed!")