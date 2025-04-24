@tool
extends "res://src/core/state/SerializableResource.gd"

## Test implementation of SerializableResource for unit testing
## This is used for testing serialization/deserialization functionality
# Use explicit preloads instead of global class names
const TestResourceSelf = preload("res://tests/fixtures/specialized/test_resource.gd")

# Type-safe properties
var test_value: String = ""
var test_number: int = 0
var test_array: Array[String] = []
var test_dict: Dictionary = {}

func _init() -> void:
	test_array = []
	test_dict = {}

# Getter methods for safer access
func get_test_value() -> String:
	return test_value

func get_test_number() -> int:
	return test_number

func get_test_array() -> Array:
	return test_array

func get_test_dict() -> Dictionary:
	return test_dict

# Setter methods for safer assignment
func set_test_value(value: String) -> void:
	test_value = value

func set_test_number(value: int) -> void:
	# Ensure value is set as integer to avoid type mismatch
	test_number = int(value)

func serialize() -> Dictionary:
	return {
		"test_value": test_value,
		"test_number": test_number,
		"test_array": test_array,
		"test_dict": test_dict
	}

func deserialize(data: Dictionary) -> void:
	if not data:
		push_error("Attempting to deserialize null data")
		return
	
	# Get string value with proper type casting
	if data.has("test_value"):
		if data is Dictionary and "test_value" in data:
			var value = data["test_value"]
			if value is String:
				test_value = value
			else:
				test_value = str(value)
		else:
			test_value = ""
	else:
		test_value = ""
	
	# Get number value with proper type casting
	if data.has("test_number"):
		if data is Dictionary and "test_number" in data:
			var value = data["test_number"]
			if value is int:
				test_number = value
			else:
				# Try to convert to int safely
				test_number = int(value)
		else:
			test_number = 0
	else:
		test_number = 0
	
	# Get array data with proper type casting
	test_array.clear()
	
	if data is Dictionary and data.has("test_array"):
		var array_data = data["test_array"]
		if array_data is Array:
			for item in array_data:
				if item is String:
					test_array.push_back(item)
				else:
					# Convert to string if not already
					test_array.push_back(str(item))
	
	# Get dictionary data with proper type casting
	test_dict.clear()
	
	if data is Dictionary and data.has("test_dict"):
		var dict_data = data["test_dict"]
		if dict_data is Dictionary:
			for key in dict_data:
				if key is String:
					var value = dict_data[key]
					test_dict[key] = value
		elif dict_data is Array:
			# Handle the case where we got an array instead of a dictionary
			for i in range(dict_data.size()):
				if i < dict_data.size():
					var item = dict_data[i]
					var key = "item_" + str(i)
					test_dict[key] = str(item)
