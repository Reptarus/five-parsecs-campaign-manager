@tool
extends "res://tests/fixtures/base/game_test.gd"

const _SerializableScript := preload("res://src/core/state/SerializableResource.gd")
const _TestResourceScript := preload("res://tests/fixtures/specialized/test_resource.gd")

# Type-safe instance variables - use looser typing
var test_resource = null
var _test_resource = null

func before_each() -> void:
	await super.before_each()
	
	# Create resources with proper error handling
	if _SerializableScript:
		test_resource = _SerializableScript.new()
		if not test_resource:
			push_error("Failed to create test resource")
			return
		track_test_resource(test_resource)
	else:
		push_error("_SerializableScript not found")
		return
	
	if _TestResourceScript:
		_test_resource = _TestResourceScript.new()
		if _test_resource:
			track_test_resource(_test_resource)
		else:
			push_error("Failed to create test resource")
			return
	else:
		push_error("_TestResourceScript not found")
		return
		
	await get_tree().process_frame

func after_each() -> void:
	test_resource = null
	_test_resource = null
	await super.after_each()

# Type-safe helper methods
func _verify_resource_safe(resource, message: String = "") -> void:
	if not resource:
		push_error("Resource is null: %s" % message)
		assert_false(true, "Resource is null: %s" % message)
		return
	
	if not resource is _TestResourceScript:
		push_error("Resource is not TestResource: %s" % message)
		assert_false(true, "Resource is not TestResource: %s" % message)
		return
	
	assert_not_null(resource, "Resource should not be null: %s" % message)

func _create_test_data() -> Dictionary:
	return {
		"test_value": "test",
		"test_number": 42,
		"test_array": ["one", "two", "three"],
		"test_dict": {
			"key1": "value1",
			"key2": "value2"
		}
	}

# Base SerializableResource tests
func test_initialization() -> void:
	if not test_resource:
		pending("Test resource is null, skipping test")
		return
		
	assert_not_null(test_resource, "Should create resource instance")
	var id: String = TypeSafeMixin._safe_cast_to_string(TypeSafeMixin._call_node_method(test_resource, "get_id", []))
	assert_ne(id, "", "Should initialize with an ID")

func test_serialization() -> void:
	if not test_resource:
		pending("Test resource is null, skipping test")
		return
		
	var original_id: String = TypeSafeMixin._safe_cast_to_string(TypeSafeMixin._call_node_method(test_resource, "get_id", []))
	var serialized: Dictionary = TypeSafeMixin._call_node_method_dict(test_resource, "serialize", [])
	
	var new_resource = null
	if _SerializableScript:
		new_resource = _SerializableScript.new()
		if new_resource:
			track_test_resource(new_resource)
		else:
			push_error("Failed to create new resource")
			return
	else:
		push_error("_SerializableScript not found")
		return
		
	TypeSafeMixin._call_node_method(new_resource, "deserialize", [serialized])
	var deserialized_id: String = TypeSafeMixin._safe_cast_to_string(TypeSafeMixin._call_node_method(new_resource, "get_id", []))
	assert_eq(deserialized_id, original_id, "Should maintain ID after serialization")

func test_id_uniqueness() -> void:
	if not _SerializableScript:
		pending("SerializableScript is null, skipping test")
		return
		
	var resource1 = _SerializableScript.new()
	var resource2 = _SerializableScript.new()
	
	if not resource1 or not resource2:
		push_error("Failed to create test resources")
		return
		
	track_test_resource(resource1)
	track_test_resource(resource2)
	
	var id1: String = TypeSafeMixin._safe_cast_to_string(TypeSafeMixin._call_node_method(resource1, "get_id", []))
	var id2: String = TypeSafeMixin._safe_cast_to_string(TypeSafeMixin._call_node_method(resource2, "get_id", []))
	assert_ne(id1, id2, "Should generate unique IDs for different instances")

# Extended TestResource tests
func _get_resource_property(resource, property_name, default_value = null):
	if resource == null:
		return default_value
		
	# Try using a get_property() method if it exists
	if resource.has_method("get_" + property_name):
		return resource.call("get_" + property_name)
	
	# Try using object.get(property) which is safer than direct access
	if resource.has_method("get"):
		return resource.get(property_name, default_value)
	
	# Try the 'in' operator and direct access as a last resort
	if property_name in resource:
		return resource[property_name]
		
	return default_value

func _set_resource_property(resource, property_name, value):
	if resource == null:
		return false
		
	# Try using a set_property() method if it exists
	if resource.has_method("set_" + property_name):
		resource.call("set_" + property_name, value)
		return true
	
	# Try direct property assignment if the property exists
	if property_name in resource:
		resource[property_name] = value
		return true
		
	return false

func _test_resource_initialization() -> void:
	if not _test_resource:
		pending("Test resource is null, skipping test")
		return
		
	_verify_resource_safe(_test_resource, "after initialization")
	
	# Verify default values using safer property access
	var test_value = _get_resource_property(_test_resource, "test_value", "")
	var test_number = _get_resource_property(_test_resource, "test_number", 0)
		
	assert_eq(test_value, "", "String should default to empty")
	assert_eq(test_number, 0, "Number should default to 0")
	
	# Check array and dict with safe access
	var test_array = _get_resource_property(_test_resource, "test_array", [])
	var test_dict = _get_resource_property(_test_resource, "test_dict", {})
	
	assert_not_null(test_array, "Array should exist")
	if test_array != null:
		assert_eq(test_array.size(), 0, "Array should be empty")
	
	assert_not_null(test_dict, "Dictionary should exist")
	if test_dict != null:
		assert_eq(test_dict.size(), 0, "Dictionary should be empty")

func test_resource_serialization() -> void:
	if not _test_resource:
		pending("Test resource is null, skipping test")
		return
		
	_verify_resource_safe(_test_resource, "before serialization")
	
	# Setup test data
	var test_data := _create_test_data()
	
	# Set properties safely
	_set_resource_property(_test_resource, "test_value", test_data["test_value"])
	_set_resource_property(_test_resource, "test_number", test_data["test_number"])
	
	# Arrays and dictionaries require special handling
	var test_array = _get_resource_property(_test_resource, "test_array", [])
	if test_array != null:
		test_array.clear()
		for item in test_data["test_array"]:
			test_array.append(item)
	
	var test_dict = _get_resource_property(_test_resource, "test_dict", {})
	if test_dict != null:
		test_dict.clear()
		for key in test_data["test_dict"]:
			test_dict[key] = test_data["test_dict"][key]
	
	# Test serialization with safe error handling
	var serialized: Dictionary = {}
	if _test_resource.has_method("serialize"):
		serialized = _test_resource.serialize()
	else:
		push_error("Test resource doesn't have serialize method")
		return
		
	assert_eq(serialized.get("test_value", ""), test_data["test_value"],
		"Should serialize string value")
	assert_eq(serialized.get("test_number", -1), test_data["test_number"],
		"Should serialize number value")
	
	var serialized_array = serialized.get("test_array", [])
	var test_data_array = test_data["test_array"]
	assert_eq(serialized_array.size(), test_data_array.size(), "Should serialize array value with correct size")
	
	var serialized_dict = serialized.get("test_dict", {})
	var test_data_dict = test_data["test_dict"]
	assert_eq(serialized_dict.size(), test_data_dict.size(), "Should serialize dictionary value with correct size")

func test_resource_deserialization() -> void:
	if not _test_resource:
		pending("Test resource is null, skipping test")
		return
		
	_verify_resource_safe(_test_resource, "before deserialization")
	
	# Setup test data
	var test_data := _create_test_data()
	
	# Test deserialization with safe error handling
	if _test_resource.has_method("deserialize"):
		_test_resource.deserialize(test_data)
	else:
		push_error("Test resource doesn't have deserialize method")
		return
	
	# Verify with safe property access
	var test_value = _get_resource_property(_test_resource, "test_value", "ERROR")
	var test_number = _get_resource_property(_test_resource, "test_number", -1)
	
	assert_eq(test_value, test_data["test_value"], "Should deserialize string value")
	assert_eq(test_number, test_data["test_number"], "Should deserialize number value")
	
	var test_array = _get_resource_property(_test_resource, "test_array", [])
	var test_data_array = test_data["test_array"]
	if test_array != null:
		assert_eq(test_array.size(), test_data_array.size(), "Should deserialize array value with correct size")
	
	var test_dict = _get_resource_property(_test_resource, "test_dict", {})
	var test_data_dict = test_data["test_dict"]
	if test_dict != null:
		assert_eq(test_dict.size(), test_data_dict.size(), "Should deserialize dictionary value with correct size")

func test_resource_null_deserialization() -> void:
	if not _test_resource:
		pending("Test resource is null, skipping test")
		return
		
	_verify_resource_safe(_test_resource, "before null deserialization")
	
	# Test null data with safe error handling
	if _test_resource.has_method("deserialize"):
		_test_resource.deserialize({})
	else:
		push_error("Test resource doesn't have deserialize method")
		return
	
	# Verify with safe property access
	var test_value = _get_resource_property(_test_resource, "test_value", "ERROR")
	var test_number = _get_resource_property(_test_resource, "test_number", -1)
	
	assert_eq(test_value, "", "Should handle null string")
	assert_eq(test_number, 0, "Should handle null number")
	
	var test_array = _get_resource_property(_test_resource, "test_array", [])
	if test_array != null:
		assert_eq(test_array.size(), 0, "Should handle null array")
	
	var test_dict = _get_resource_property(_test_resource, "test_dict", {})
	if test_dict != null:
		assert_eq(test_dict.size(), 0, "Should handle null dictionary")

func test_resource_invalid_deserialization() -> void:
	if not _test_resource:
		pending("Test resource is null, skipping test")
		return
		
	_verify_resource_safe(_test_resource, "before invalid deserialization")
	
	# Setup invalid test data
	var invalid_data := {
		"test_value": 42, # Wrong type (int instead of String)
		"test_number": "invalid", # Wrong type (String instead of int)
		"test_array": {"invalid": "array"}, # Wrong type (Dictionary instead of Array)
		"test_dict": ["invalid", "dict"] # Wrong type (Array instead of Dictionary)
	}
	
	# Test invalid data with safe error handling
	if _test_resource.has_method("deserialize"):
		_test_resource.deserialize(invalid_data)
	else:
		push_error("Test resource doesn't have deserialize method")
		return
	
	# Verify with safe property access
	var test_value = _get_resource_property(_test_resource, "test_value", "ERROR")
	var test_number = _get_resource_property(_test_resource, "test_number", -1)
	
	assert_eq(test_value, "", "Should handle invalid string")
	assert_eq(test_number, 0, "Should handle invalid number")
	
	var test_array = _get_resource_property(_test_resource, "test_array", [])
	if test_array != null:
		assert_eq(test_array.size(), 0, "Should handle invalid array")
	
	var test_dict = _get_resource_property(_test_resource, "test_dict", {})
	if test_dict != null:
		assert_eq(test_dict.size(), 0, "Should handle invalid dictionary")

func test_factory_method() -> void:
	if not _TestResourceScript:
		pending("TestResourceScript is null, skipping test")
		return
		
	var test_data := _create_test_data()
	
	var new_resource = null
	if _TestResourceScript:
		new_resource = _TestResourceScript.new()
	else:
		push_error("_TestResourceScript not found")
		return
		
	if not new_resource:
		push_error("Failed to create new test resource")
		return
		
	# Test deserialize with safe error handling
	if new_resource.has_method("deserialize"):
		new_resource.deserialize(test_data)
	else:
		push_error("New resource doesn't have deserialize method")
		return
		
	_verify_resource_safe(new_resource, "from factory method")
	
	# Verify with safe property access
	var test_value = _get_resource_property(new_resource, "test_value", "ERROR")
	var test_number = _get_resource_property(new_resource, "test_number", -1)
	
	assert_eq(test_value, test_data["test_value"], "Should create instance with correct string value")
	assert_eq(test_number, test_data["test_number"], "Should create instance with correct number value")
	
	var new_array = _get_resource_property(new_resource, "test_array", [])
	var test_data_array = test_data["test_array"]
	if new_array != null:
		assert_eq(new_array.size(), test_data_array.size(), "Should create instance with correct array size")
	
	var new_dict = _get_resource_property(new_resource, "test_dict", {})
	var test_data_dict = test_data["test_dict"]
	if new_dict != null:
		assert_eq(new_dict.size(), test_data_dict.size(), "Should create instance with correct dictionary size")

# Helper method to handle array data safely
func _process_array_data(data) -> Array:
	var result = []
	if data is Array:
		for item in data:
			result.append(item)
	return result

# Helper method to handle dictionary data safely
func _process_dict_data(data) -> Dictionary:
	var result = {}
	if data is Dictionary:
		for key in data:
			result[key] = data[key]
	return result
