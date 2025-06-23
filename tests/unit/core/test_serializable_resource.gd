@tool
extends GdUnitGameTest

# Mock serializable resource for testing
class MockSerializableResource extends Resource:
    var _id: String = ""
    
    func _init() -> void:
        _id = "mock_resource_" + str(randi())
    
    func get_id() -> String:
        return _id

    func serialize() -> Dictionary:
        return {
            "id": _id,
            "type": "MockSerializableResource"
        }
    
    func deserialize(data: Dictionary) -> void:
        if data.has("id"):
            _id = data["id"]

# Mock test resource with comprehensive testing features
class MockTestResource extends Resource:
    var test_value: String = ""
    var test_number: int = 0
    var test_array: Array = []
    var test_dict: Dictionary = {}
    var _id: String = ""
    
    func _init() -> void:
        _id = "mock_test_resource_" + str(randi())
    
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
        if data.has("id"):
            _id = data["id"]
        
        # Type-safe deserialization with validation
        if data.has("test_value"):
            var _value = data["test_value"]
            if _value is String:
                test_value = _value
        
        if data.has("test_number"):
            var number = data["test_number"]
            if number is int:
                test_number = number
        
        if data.has("test_array"):
            var array = data["test_array"]
            if array is Array:
                test_array = array
        
        if data.has("test_dict"):
            var dict = data["test_dict"]
            if dict is Dictionary:
                test_dict = dict

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

func _verify_resource_safe(resource: Resource, message: String = "") -> void:
    if not resource:
        push_error("Resource verification failed: " + message)

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

func test_initialization() -> void:
    # Test direct method calls instead of safe wrappers (proven pattern)
    _verify_resource_safe(test_resource, "after initialization")
    var id: String = test_resource.get_id()
    assert_that(id).is_not_equal("")

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
    var _data = _create_test_data()
    _test_resource.test_value = _data["test_value"]
    _test_resource.test_number = _data["test_number"]
    _test_resource.test_array = _data["test_array"]
    _test_resource.test_dict = _data["test_dict"]
    
    # Test serialization
    var serialized: Dictionary = _test_resource.serialize()
    assert_that(serialized.has("test_value")).is_true()
    assert_that(serialized.has("test_number")).is_true()
    assert_that(serialized.has("test_array")).is_true()
    assert_that(serialized.has("test_dict")).is_true()

func test_resource_deserialization() -> void:
    # Test direct method calls instead of safe wrappers (proven pattern)
    _verify_resource_safe(_test_resource, "before deserialization")
    
    # Setup test data
    var test_data := _create_test_data()
    
    # Deserialize and verify
    _test_resource.deserialize(test_data)
    assert_that(_test_resource.test_value).is_equal("test")
    assert_that(_test_resource.test_number).is_equal(42)
    assert_that(_test_resource.test_array.size()).is_equal(3)
    assert_that(_test_resource.test_dict.size()).is_equal(2)

func test_resource_null_deserialization() -> void:
    # Test direct method calls instead of safe wrappers (proven pattern)
    _verify_resource_safe(_test_resource, "before null deserialization")
    
    # Test with empty dictionary
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
    
    # Should handle gracefully
    _test_resource.deserialize(invalid_data)
    assert_that(_test_resource.test_value).is_equal("")
    assert_that(_test_resource.test_number).is_equal(0)
    assert_that(_test_resource.test_array.size()).is_equal(0)
    assert_that(_test_resource.test_dict.size()).is_equal(0)

func test_complex_serialization_cycle() -> void:
    # Test comprehensive serialization/deserialization cycle
    _test_resource.test_value = "complex_test"
    _test_resource.test_number = 999
    _test_resource.test_array = ["item1", "item2", "item3"]
    _test_resource.test_dict = {"nested": {"data": "value"}}
    
    var serialized = _test_resource.serialize()
    var new_resource = MockTestResource.new()
    track_resource(new_resource)
    new_resource.deserialize(serialized)
    
    assert_that(new_resource.test_value).is_equal("complex_test")
    assert_that(new_resource.test_number).is_equal(999)
    assert_that(new_resource.test_array.size()).is_equal(3)
    assert_that(new_resource.test_dict.has("nested")).is_true()

func test_partial_deserialization() -> void:
    # Test partial data deserialization
    var partial_data = {
        "test_value": "partial",
        "test_number": 123
        # Missing test_array and test_dict
    }
    
    _test_resource.deserialize(partial_data)
    assert_that(_test_resource.test_value).is_equal("partial")
    assert_that(_test_resource.test_number).is_equal(123)
    assert_that(_test_resource.test_array.size()).is_equal(0)
    assert_that(_test_resource.test_dict.size()).is_equal(0)
