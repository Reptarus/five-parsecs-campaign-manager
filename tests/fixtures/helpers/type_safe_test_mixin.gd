@tool
extends RefCounted

# Type-safe test mixin constants
const ERROR_INVALID_OBJECT := "Invalid object reference"
const ERROR_INVALID_PROPERTY := "Invalid property name"
const ERROR_INVALID_METHOD := "Invalid method name"
const ERROR_PROPERTY_NOT_FOUND := "Property '%s' not found in object"
const ERROR_METHOD_NOT_FOUND := "Method '%s' not found in object"
const ERROR_TYPE_MISMATCH := "Type mismatch: expected %s but got %s"
const ERROR_CAST_FAILED := "Failed to cast %s to %s: %s"
const ERROR_SIGNAL_NOT_FOUND := "Signal '%s' not found in object"

# Property access methods
static func _get_property_safe(obj: Object, property: String, default_value: Variant = null) -> Variant:
	if not is_instance_valid(obj):
		return default_value
	
	if property.is_empty():
		return default_value
	
	if not property in obj:
		return default_value
	
	return obj.get(property)

static func _set_property_safe(obj: Object, property: String, value: Variant) -> bool:
	if not is_instance_valid(obj):
		return false
	
	if property.is_empty():
		return false
	
	if not property in obj:
		return false
	
	obj.set(property, value)
	return true

# Method calling methods
static func _call_node_method(obj: Object, method: String, args: Array = []) -> Variant:
	if not is_instance_valid(obj):
		return null
	
	if method.is_empty():
		return null
	
	if not obj.has_method(method):
		push_error(ERROR_METHOD_NOT_FOUND % method)
		return null
	
	return obj.callv(method, args)

static func _call_node_method_int(obj: Object, method: String, args: Array = [], default: int = 0) -> int:
	var result = _call_node_method(obj, method, args)
	if result == null:
		return default
	
	if result is int:
		return result
	
	if result is float:
		return int(result)
	
	if result is String and result.is_valid_int():
		return result.to_int()
	
	push_error(ERROR_TYPE_MISMATCH % ["int", typeof_as_string(result)])
	return default

static func _call_node_method_bool(obj: Object, method: String, args: Array = [], default: bool = false) -> bool:
	var result = _call_node_method(obj, method, args)
	if result == null:
		return default
	
	if result is bool:
		return result
	
	if result is int:
		return result != 0
	
	push_error(ERROR_TYPE_MISMATCH % ["bool", typeof_as_string(result)])
	return default

static func _call_node_method_array(obj: Object, method: String, args: Array = [], default: Array = []) -> Array:
	var result = _call_node_method(obj, method, args)
	if result == null:
		return default
	
	if result is Array:
		return result
	
	push_error(ERROR_TYPE_MISMATCH % ["Array", typeof_as_string(result)])
	return default

static func _call_node_method_dict(obj: Object, method: String, args: Array = [], default: Dictionary = {}) -> Dictionary:
	var result = _call_node_method(obj, method, args)
	if result == null:
		return default
	
	if result is Dictionary:
		return result
	
	push_error(ERROR_TYPE_MISMATCH % ["Dictionary", typeof_as_string(result)])
	return default

# Type casting methods
static func _safe_cast_int(test_value: Variant, error_message: String = "") -> int:
	if test_value == null:
		return 0
	
	if test_value is int:
		return test_value
	
	if test_value is float:
		return int(test_value)
	
	if test_value is String and test_value.is_valid_int():
		return test_value.to_int()
	
	push_error(ERROR_CAST_FAILED % [typeof_as_string(test_value), "int", error_message])
	return 0

static func _safe_cast_float(test_value: Variant, error_message: String = "") -> float:
	if test_value == null:
		return 0.0
	
	if test_value is float:
		return test_value
	
	if test_value is int:
		return float(test_value)
	
	if test_value is String and test_value.is_valid_float():
		return test_value.to_float()
	
	push_error(ERROR_CAST_FAILED % [typeof_as_string(test_value), "float", error_message])
	return 0.0

static func _safe_cast_array(test_value: Variant, error_message: String = "") -> Array:
	if test_value == null:
		return []
	
	if test_value is Array:
		return test_value
	
	push_error(ERROR_CAST_FAILED % [typeof_as_string(test_value), "Array", error_message])
	return []

static func _safe_cast_to_node(test_value: Variant, expected_type: String = "") -> Node:
	if test_value == null:
		push_error(ERROR_CAST_FAILED % ["null", "Node" + (" of type " + expected_type if not expected_type.is_empty() else ""), ""])
		return null
	
	if not test_value is Node:
		push_error(ERROR_CAST_FAILED % [typeof_as_string(test_value), "Node", ""])
		return null
	
	if not expected_type.is_empty() and not test_value.is_class(expected_type):
		push_error(ERROR_CAST_FAILED % [test_value.get_class(), expected_type, ""])
		return null
	
	return test_value

static func _safe_cast_vector2(test_value: Variant, error_message: String = "") -> Vector2:
	if test_value == null:
		return Vector2.ZERO
	
	if test_value is Vector2:
		return test_value
	
	if test_value is Array and test_value.size() >= 2:
		if (test_value[0] is float or test_value[0] is int) and (test_value[1] is float or test_value[1] is int):
			return Vector2(test_value[0], test_value[1])
	
	push_error(ERROR_CAST_FAILED % [typeof_as_string(test_value), "Vector2", error_message])
	return Vector2.ZERO

# Resource casting methods
static func _safe_cast_to_resource(test_value: Variant, type: String, error_message: String = "") -> Resource:
	if test_value == null:
		return null
	
	if not test_value is Resource:
		push_error(ERROR_CAST_FAILED % [typeof_as_string(test_value), type, error_message])
		return null
	
	if not type.is_empty() and not test_value.is_class(type):
		push_error(ERROR_CAST_FAILED % [test_value.get_class(), type, error_message])
		return null
	
	return test_value

static func _safe_cast_to_object(test_value: Variant, type: String, error_message: String = "") -> Object:
	if test_value == null:
		return null
	
	if not test_value is Object:
		push_error(ERROR_CAST_FAILED % [typeof_as_string(test_value), type, error_message])
		return null
	
	if not type.is_empty() and not test_value.is_class(type):
		push_error(ERROR_CAST_FAILED % [test_value.get_class(), type, error_message])
		return null
	
	return test_value

static func _safe_cast_to_string(test_value: Variant, error_message: String = "") -> String:
	if test_value == null:
		return ""
	
	if test_value is String:
		return test_value
	
	if test_value is int or test_value is float or test_value is bool:
		return str(test_value)
	
	push_error(ERROR_CAST_FAILED % [typeof_as_string(test_value), "String", error_message])
	return ""

# Type utility methods
static func typeof_as_string(test_value: Variant) -> String:
	match typeof(test_value):
		TYPE_NIL: return "null"
		TYPE_BOOL: return "bool"
		TYPE_INT: return "int"
		TYPE_FLOAT: return "float"
		TYPE_STRING: return "String"
		TYPE_VECTOR2: return "Vector2"
		TYPE_VECTOR3: return "Vector3"
		TYPE_ARRAY: return "Array"
		TYPE_DICTIONARY: return "Dictionary"
		TYPE_OBJECT:
			if test_value == null:
				return "null"
			if test_value is Node:
				return "Node (%s)" % test_value.get_class()
			if test_value is Resource:
				return "Resource (%s)" % test_value.get_class()
			return test_value.get_class()
		_: return "Unknown"

# Method calling utilities
static func _safe_method_call_variant(obj: Object, method: String, args: Array = [], default: Variant = null) -> Variant:
	if not is_instance_valid(obj):
		return default
	
	if method.is_empty():
		return default
	
	if not obj.has_method(method):
		return default
	
	return obj.callv(method, args)

# Signal connection utilities
static func _safe_connect(obj: Object, signal_name: String, callable: Callable, flags: int = 0) -> bool:
	if not is_instance_valid(obj):
		return false
	
	if signal_name.is_empty():
		push_error("Signal name cannot be empty")
		return false
	
	if not obj.has_signal(signal_name):
		push_error(ERROR_SIGNAL_NOT_FOUND % signal_name)
		return false
	
	var result = obj.connect(signal_name, callable, flags)
	return result == OK
