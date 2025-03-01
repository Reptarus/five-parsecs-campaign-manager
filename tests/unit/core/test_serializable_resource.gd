@tool
extends "res://tests/fixtures/base/game_test.gd"

const _SerializableScript := preload("res://src/core/state/SerializableResource.gd")
const _TestResourceScript := preload("res://tests/fixtures/specialized/test_resource.gd")

# Type-safe instance variables
var test_resource: Resource = null
var _test_resource: Resource = null

func before_each() -> void:
	await super.before_each()
	test_resource = _SerializableScript.new()
	if not test_resource:
		push_error("Failed to create test resource")
		return
	track_test_resource(test_resource)
	
	_test_resource = _TestResourceScript.new()
	track_test_resource(_test_resource)
	await get_tree().process_frame

func after_each() -> void:
	test_resource = null
	_test_resource = null
	await super.after_each()

# Type-safe helper methods
func _verify_resource_safe(resource: Resource, message: String = "") -> void:
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
	assert_not_null(test_resource, "Should create resource instance")
	var id: String = TypeSafeMixin._safe_cast_to_string(TypeSafeMixin._call_node_method(test_resource, "get_id", []))
	assert_ne(id, "", "Should initialize with an ID")

func test_serialization() -> void:
	var original_id: String = TypeSafeMixin._safe_cast_to_string(TypeSafeMixin._call_node_method(test_resource, "get_id", []))
	var serialized: Dictionary = TypeSafeMixin._call_node_method_dict(test_resource, "serialize", [])
	var new_resource: Resource = _SerializableScript.new()
	track_test_resource(new_resource)
	TypeSafeMixin._call_node_method(new_resource, "deserialize", [serialized])
	var deserialized_id: String = TypeSafeMixin._safe_cast_to_string(TypeSafeMixin._call_node_method(new_resource, "get_id", []))
	assert_eq(deserialized_id, original_id, "Should maintain ID after serialization")

func test_id_uniqueness() -> void:
	var resource1: Resource = _SerializableScript.new()
	var resource2: Resource = _SerializableScript.new()
	track_test_resource(resource1)
	track_test_resource(resource2)
	var id1: String = TypeSafeMixin._safe_cast_to_string(TypeSafeMixin._call_node_method(resource1, "get_id", []))
	var id2: String = TypeSafeMixin._safe_cast_to_string(TypeSafeMixin._call_node_method(resource2, "get_id", []))
	assert_ne(id1, id2, "Should generate unique IDs for different instances")

# Extended TestResource tests
func test_resource_initialization() -> void:
	_verify_resource_safe(_test_resource, "after initialization")
	
	# Verify default values
	assert_eq(_test_resource.test_value, "", "String should default to empty")
	assert_eq(_test_resource.test_number, 0, "Number should default to 0")
	assert_eq(_test_resource.test_array.size(), 0, "Array should be empty")
	assert_eq(_test_resource.test_dict.size(), 0, "Dictionary should be empty")

func test_resource_serialization() -> void:
	_verify_resource_safe(_test_resource, "before serialization")
	
	# Setup test data
	var test_data := _create_test_data()
	_test_resource.test_value = test_data["test_value"]
	_test_resource.test_number = test_data["test_number"]
	_test_resource.test_array = test_data["test_array"]
	_test_resource.test_dict = test_data["test_dict"]
	
	# Test serialization
	var serialized: Dictionary = _test_resource.serialize()
	assert_eq(serialized.get("test_value", ""), test_data["test_value"],
		"Should serialize string value")
	assert_eq(serialized.get("test_number", -1), test_data["test_number"],
		"Should serialize number value")
	assert_eq(serialized.get("test_array", []), test_data["test_array"],
		"Should serialize array value")
	assert_eq(serialized.get("test_dict", {}), test_data["test_dict"],
		"Should serialize dictionary value")

func test_resource_deserialization() -> void:
	_verify_resource_safe(_test_resource, "before deserialization")
	
	# Setup test data
	var test_data := _create_test_data()
	
	# Test deserialization
	_test_resource.deserialize(test_data)
	assert_eq(_test_resource.test_value, test_data["test_value"],
		"Should deserialize string value")
	assert_eq(_test_resource.test_number, test_data["test_number"],
		"Should deserialize number value")
	assert_eq(_test_resource.test_array, test_data["test_array"],
		"Should deserialize array value")
	assert_eq(_test_resource.test_dict, test_data["test_dict"],
		"Should deserialize dictionary value")

func test_resource_null_deserialization() -> void:
	_verify_resource_safe(_test_resource, "before null deserialization")
	
	# Test null data
	_test_resource.deserialize({})
	assert_eq(_test_resource.test_value, "", "Should handle null string")
	assert_eq(_test_resource.test_number, 0, "Should handle null number")
	assert_eq(_test_resource.test_array.size(), 0, "Should handle null array")
	assert_eq(_test_resource.test_dict.size(), 0, "Should handle null dictionary")

func test_resource_invalid_deserialization() -> void:
	_verify_resource_safe(_test_resource, "before invalid deserialization")
	
	# Setup invalid test data
	var invalid_data := {
		"test_value": 42, # Wrong type (int instead of String)
		"test_number": "invalid", # Wrong type (String instead of int)
		"test_array": {"invalid": "array"}, # Wrong type (Dictionary instead of Array)
		"test_dict": ["invalid", "dict"] # Wrong type (Array instead of Dictionary)
	}
	
	# Test invalid data
	_test_resource.deserialize(invalid_data)
	assert_eq(_test_resource.test_value, "", "Should handle invalid string")
	assert_eq(_test_resource.test_number, 0, "Should handle invalid number")
	assert_eq(_test_resource.test_array.size(), 0, "Should handle invalid array")
	assert_eq(_test_resource.test_dict.size(), 0, "Should handle invalid dictionary")

func test_factory_method() -> void:
	var test_data := _create_test_data()
	
	var new_resource := _TestResourceScript.new() as Resource
	new_resource.deserialize(test_data)
	_verify_resource_safe(new_resource, "from factory method")
	
	assert_eq(new_resource.test_value, test_data["test_value"],
		"Should create instance with correct string value")
	assert_eq(new_resource.test_number, test_data["test_number"],
		"Should create instance with correct number value")
	assert_eq(new_resource.test_array, test_data["test_array"],
		"Should create instance with correct array value")
	assert_eq(new_resource.test_dict, test_data["test_dict"],
		"Should create instance with correct dictionary value")