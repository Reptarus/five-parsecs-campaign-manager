@tool
extends "res://src/core/state/SerializableResource.gd"

#
class_name TestResource

# Type-safe properties
var test_value: String = ""
var test_number: int = 0
var test_array: Array[String] = []
var test_dict: Dictionary = {}
#

func _init() -> void:
	test_array = []
	test_dict = {}

func serialize() -> Dictionary:
	return {
		"test_value": test_value,
		"test_number": test_number,
		"test_array": test_array,
		"test_dict": test_dict,
	}

func deserialize(data: Dictionary) -> void:
	if not data:
		return

	test_value = data.get("test_value", "")
	test_number = data.get("test_number", 0)

	# Handle array data
	var array_data = data.get("test_array", [])
	test_array.clear()
	for item: String in array_data:
		if item is String:
			test_array.push_back(item)

	# Handle dictionary data
	var dict_data = data.get("test_dict", {})
	test_dict.clear()
	test_dict.merge(dict_data)
