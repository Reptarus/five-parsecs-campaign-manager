extends "res://addons/gut/test.gd"

# Test implementation of SerializableResource
class TestResource extends SerializableResource:
    var test_value: String = ""
    var test_number: int = 0
    
    func serialize() -> Dictionary:
        return {
            "test_value": test_value,
            "test_number": test_number
        }
    
    func deserialize(data: Dictionary) -> void:
        test_value = data.get("test_value", "")
        test_number = data.get("test_number", 0)

var test_resource: TestResource

func before_each() -> void:
    test_resource = TestResource.new()

func after_each() -> void:
    test_resource = null

func test_serialization() -> void:
    test_resource.test_value = "test"
    test_resource.test_number = 42
    
    var serialized = test_resource.serialize()
    assert_eq(serialized.test_value, "test", "Should serialize string value")
    assert_eq(serialized.test_number, 42, "Should serialize number value")

func test_deserialization() -> void:
    var data = {
        "test_value": "deserialized",
        "test_number": 24
    }
    
    test_resource.deserialize(data)
    assert_eq(test_resource.test_value, "deserialized", "Should deserialize string value")
    assert_eq(test_resource.test_number, 24, "Should deserialize number value")

func test_factory_method() -> void:
    var data = {
        "test_value": "factory",
        "test_number": 100
    }
    
    var new_resource = TestResource.from_dict(data)
    assert_eq(new_resource.test_value, "factory", "Should create instance with correct string value")
    assert_eq(new_resource.test_number, 100, "Should create instance with correct number value") 