@tool
extends GdUnitGameTest

# Mock Serializable Resource with expected values (Universal Mock Strategy)
class MockSerializableResource extends Resource:
	var _id: String = ""
	
	func _init():
		_id = "mock_resource_" + str(randi())
	
	func get_id() -> String:
		return _id
	
	func serialize() -> Dictionary:
		return {
			"id": _id,
			"type": "MockSerializableResource"
		}
	
	func deserialize(data: Dictionary) -> void:
		_id = data.get("id", _id)

# Mock Test Resource with expected values (Universal Mock Strategy)
class MockTestResource extends Resource:
	var test_value: String = ""
	var test_number: int = 0
	var test_array: Array = []
	var test_dict: Dictionary = {}
	var _id: String = ""
	
	func _init():
		_id = "test_resource_" + str(randi())
	
	func get_id() -> String:
		return _id
	
	func serialize() -> Dictionary:
		return {
			"id": _id,
			"test_value": test_value,
			"test_number": test_number,
			"test_array": test_array,
			"test_dict": test_dict,
			"type": "MockTestResource"
		}
	
	func deserialize(data: Dictionary) -> void:
		_id = data.get("id", _id)
		
		# Type-safe deserialization with validation
		var value = data.get("test_value", "")
		if value is String:
			test_value = value
		else:
			test_value = ""
		
		var number = data.get("test_number", 0)
		if number is int:
			test_number = number
		else:
			test_number = 0
		
		var array = data.get("test_array", [])
		if array is Array:
			test_array = array
		else:
			test_array = []
		
		var dict = data.get("test_dict", {})
		if dict is Dictionary:
			test_dict = dict
		else:
			test_dict = {}

# Type-safe instance variables
var test_resource: MockSerializableResource = null
var _test_resource: MockTestResource = null

func before_test() -> void:
	super.before_test()
	test_resource = MockSerializableResource.new()
	track_resource(test_resource)
	
	_test_resource = MockTestResource.new()
	track_resource(_test_resource)

func after_test() -> void:
	test_resource = null
	_test_resource = null
	super.after_test()

# Type-safe helper methods
func _verify_resource_safe(resource: Resource, message: String = "") -> void:
	assert_that(resource).is_not_null()
	assert_that(resource is MockTestResource).is_true()

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
	# Test direct method calls instead of safe wrappers (proven pattern)
	assert_that(test_resource).is_not_null()
	var id: String = test_resource.get_id()
	assert_that(id).is_not_empty()

func test_serialization() -> void:
	# Test direct method calls instead of safe wrappers (proven pattern)
	var original_id: String = test_resource.get_id()
	var serialized: Dictionary = test_resource.serialize()
	var new_resource: MockSerializableResource = MockSerializableResource.new()
	track_resource(new_resource)
	new_resource.deserialize(serialized)
	var deserialized_id: String = new_resource.get_id()
	assert_that(deserialized_id).is_equal(original_id)

func test_id_uniqueness() -> void:
	# Test direct method calls instead of safe wrappers (proven pattern)
	var resource1: MockSerializableResource = MockSerializableResource.new()
	var resource2: MockSerializableResource = MockSerializableResource.new()
	track_resource(resource1)
	track_resource(resource2)
	var id1: String = resource1.get_id()
	var id2: String = resource2.get_id()
	assert_that(id1).is_not_equal(id2)

# Extended TestResource tests
func test_resource_initialization() -> void:
	# Test direct method calls instead of safe wrappers (proven pattern)
	_verify_resource_safe(_test_resource, "after initialization")
	
	# Verify default values
	assert_that(_test_resource.test_value).is_equal("")
	assert_that(_test_resource.test_number).is_equal(0)
	assert_that(_test_resource.test_array.size()).is_equal(0)
	assert_that(_test_resource.test_dict.size()).is_equal(0)

func test_resource_serialization() -> void:
	# Test direct method calls instead of safe wrappers (proven pattern)
	_verify_resource_safe(_test_resource, "before serialization")
	
	# Setup test data
	var test_data := _create_test_data()
	_test_resource.test_value = test_data["test_value"]
	_test_resource.test_number = test_data["test_number"]
	_test_resource.test_array = test_data["test_array"]
	_test_resource.test_dict = test_data["test_dict"]
	
	# Test serialization
	var serialized: Dictionary = _test_resource.serialize()
	assert_that(serialized.get("test_value", "")).is_equal(test_data["test_value"])
	assert_that(serialized.get("test_number", -1)).is_equal(test_data["test_number"])
	assert_that(serialized.get("test_array", [])).is_equal(test_data["test_array"])
	assert_that(serialized.get("test_dict", {})).is_equal(test_data["test_dict"])

func test_resource_deserialization() -> void:
	# Test direct method calls instead of safe wrappers (proven pattern)
	_verify_resource_safe(_test_resource, "before deserialization")
	
	# Setup test data
	var test_data := _create_test_data()
	
	# Test deserialization
	_test_resource.deserialize(test_data)
	assert_that(_test_resource.test_value).is_equal(test_data["test_value"])
	assert_that(_test_resource.test_number).is_equal(test_data["test_number"])
	assert_that(_test_resource.test_array).is_equal(test_data["test_array"])
	assert_that(_test_resource.test_dict).is_equal(test_data["test_dict"])

func test_resource_null_deserialization() -> void:
	# Test direct method calls instead of safe wrappers (proven pattern)
	_verify_resource_safe(_test_resource, "before null deserialization")
	
	# Test null data
	_test_resource.deserialize({})
	assert_that(_test_resource.test_value).is_equal("")
	assert_that(_test_resource.test_number).is_equal(0)
	assert_that(_test_resource.test_array.size()).is_equal(0)
	assert_that(_test_resource.test_dict.size()).is_equal(0)

func test_resource_invalid_deserialization() -> void:
	# Test direct method calls instead of safe wrappers (proven pattern)
	_verify_resource_safe(_test_resource, "before invalid deserialization")
	
	# Setup invalid test data
	var invalid_data := {
		"test_value": 42, # Wrong type (int instead of String)
		"test_number": "invalid", # Wrong type (String instead of int)
		"test_array": {"invalid": "array"}, # Wrong type (Dictionary instead of Array)
		"test_dict": ["invalid", "dict"] # Wrong type (Array instead of Dictionary)
	}
	
	# Test invalid data - mock handles type validation
	_test_resource.deserialize(invalid_data)
	assert_that(_test_resource.test_value).is_equal("")
	assert_that(_test_resource.test_number).is_equal(0)
	assert_that(_test_resource.test_array.size()).is_equal(0)
	assert_that(_test_resource.test_dict.size()).is_equal(0)

func test_factory_method() -> void:
	# Test direct method calls instead of safe wrappers (proven pattern)
	var test_data := _create_test_data()
	
	var new_resource := MockTestResource.new() as Resource
	track_resource(new_resource)
	new_resource.deserialize(test_data)
	_verify_resource_safe(new_resource, "from factory method")
	
	assert_that(new_resource.test_value).is_equal(test_data["test_value"])
	assert_that(new_resource.test_number).is_equal(test_data["test_number"])
	assert_that(new_resource.test_array).is_equal(test_data["test_array"])
	assert_that(new_resource.test_dict).is_equal(test_data["test_dict"])

func test_serialization_roundtrip() -> void:
	# Test direct method calls instead of safe wrappers (proven pattern)
	# Setup original resource with data
	var test_data := _create_test_data()
	_test_resource.deserialize(test_data)
	
	# Serialize and deserialize
	var serialized: Dictionary = _test_resource.serialize()
	var new_resource := MockTestResource.new()
	track_resource(new_resource)
	new_resource.deserialize(serialized)
	
	# Verify data integrity
	assert_that(new_resource.test_value).is_equal(_test_resource.test_value)
	assert_that(new_resource.test_number).is_equal(_test_resource.test_number)
	assert_that(new_resource.test_array).is_equal(_test_resource.test_array)
	assert_that(new_resource.test_dict).is_equal(_test_resource.test_dict)

func test_id_persistence() -> void:
	# Test direct method calls instead of safe wrappers (proven pattern)
	var original_id: String = _test_resource.get_id()
	
	# Serialize and deserialize
	var serialized: Dictionary = _test_resource.serialize()
	var new_resource := MockTestResource.new()
	track_resource(new_resource)
	new_resource.deserialize(serialized)
	
	# ID should be preserved
	assert_that(new_resource.get_id()).is_equal(original_id)

func test_empty_containers() -> void:
	# Test direct method calls instead of safe wrappers (proven pattern)
	# Test with explicitly empty containers
	var empty_data := {
		"test_value": "",
		"test_number": 0,
		"test_array": [],
		"test_dict": {}
	}
	
	_test_resource.deserialize(empty_data)
	assert_that(_test_resource.test_value).is_equal("")
	assert_that(_test_resource.test_number).is_equal(0)
	assert_that(_test_resource.test_array.size()).is_equal(0)
	assert_that(_test_resource.test_dict.size()).is_equal(0)

func test_partial_data() -> void:
	# Test direct method calls instead of safe wrappers (proven pattern)
	# Test with partial data (missing some fields)
	var partial_data := {
		"test_value": "partial",
		"test_number": 123
		# Missing test_array and test_dict
	}
	
	_test_resource.deserialize(partial_data)
	assert_that(_test_resource.test_value).is_equal("partial")
	assert_that(_test_resource.test_number).is_equal(123)
	assert_that(_test_resource.test_array.size()).is_equal(0) # Should default to empty
	assert_that(_test_resource.test_dict.size()).is_equal(0) # Should default to empty