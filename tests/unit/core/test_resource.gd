@tool
extends "res://tests/fixtures/base/game_test.gd"

const _ResourceScript := preload("res://src/core/state/SerializableResource.gd")

# Use looser typing for type safety
var test_resource = null

func before_each() -> void:
	await super.before_each()
	
	# Create resource with proper error handling
	if _ResourceScript:
		test_resource = _ResourceScript.new()
		if test_resource:
			track_test_resource(test_resource)
		else:
			push_error("Failed to create test resource")
	else:
		push_error("_ResourceScript not found")
	
	await get_tree().process_frame

func after_each() -> void:
	test_resource = null
	await super.after_each()

func test_initialization() -> void:
	if not test_resource:
		pending("Test resource is null, skipping test")
		return
		
	assert_not_null(test_resource, "Should create resource instance")
	
	# Safe property access
	var id = TypeSafeMixin._safe_cast_to_string(test_resource.resource_id)
	var invalid_id = TypeSafeMixin._safe_cast_to_string(TypeSafeMixin._call_node_method(test_resource, "get", ["invalid_property"]))
	
	assert_ne(id, "", "Should initialize with an ID")
	assert_eq(invalid_id, "", "Should handle invalid property")

func test_serialization() -> void:
	if not test_resource:
		pending("Test resource is null, skipping test")
		return
		
	var original_id = TypeSafeMixin._safe_cast_to_string(test_resource.resource_id)
	
	# Safe method calling
	var serialized = {}
	if test_resource.has_method("serialize"):
		serialized = test_resource.serialize()
	else:
		push_error("Test resource doesn't have serialize method")
		return
		
	# Verify serialized data
	assert_eq(serialized.get("resource_id", ""), original_id, "Should serialize ID")
	assert_eq(serialized.get("resource_path", ""), "", "Should not serialize resource_path")
	
	# Test deserialization with a new instance
	var new_resource = null
	if _ResourceScript:
		new_resource = _ResourceScript.new()
		if new_resource:
			track_test_resource(new_resource)
		else:
			push_error("Failed to create new resource")
			return
	else:
		push_error("_ResourceScript not found")
		return
	
	# Safe deserialize
	if new_resource.has_method("deserialize"):
		new_resource.deserialize(serialized)
	else:
		push_error("New resource doesn't have deserialize method")
		return
		
	var deserialized_id = TypeSafeMixin._safe_cast_to_string(new_resource.resource_id)
	assert_eq(deserialized_id, original_id, "Should maintain ID after serialization")

func test_id_uniqueness() -> void:
	if not _ResourceScript:
		pending("ResourceScript is null, skipping test")
		return
		
	var resource1 = _ResourceScript.new()
	var resource2 = _ResourceScript.new()
	
	if not resource1 or not resource2:
		push_error("Failed to create test resources")
		return
		
	track_test_resource(resource1)
	track_test_resource(resource2)
	
	var id1 = TypeSafeMixin._safe_cast_to_string(resource1.resource_id)
	var id2 = TypeSafeMixin._safe_cast_to_string(resource2.resource_id)
	
	assert_ne(id1, id2, "Should generate unique IDs for different instances")

func test_get_set_properties() -> void:
	if not test_resource:
		pending("Test resource is null, skipping test")
		return
		
	# Test missing properties
	var missing_value = TypeSafeMixin._call_node_method(test_resource, "get", ["missing_property"])
	assert_null(missing_value, "Should return null for missing properties")
	
	# Test setting properties
	if test_resource.has_method("set"):
		test_resource.set("test_property", "test_value")
	else:
		push_error("Test resource doesn't have set method")
		return
		
	var test_value = TypeSafeMixin._call_node_method(test_resource, "get", ["test_property"])
	assert_eq(test_value, "test_value", "Should set and get properties")
	
	# Test serialization of custom properties
	var serialized = {}
	if test_resource.has_method("serialize"):
		serialized = test_resource.serialize()
	else:
		push_error("Test resource doesn't have serialize method")
		return
		
	assert_eq(serialized.get("test_property", ""), "test_value", "Should serialize custom properties")