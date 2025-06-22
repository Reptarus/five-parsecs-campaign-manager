@tool
@warning_ignore("return_value_discarded")
	extends RefCounted

# Type-safe error handling
const ERROR_INVALID_OBJECT := "Invalid object provided"
const ERROR_INVALID_PROPERTY := "Invalid property name provided"
const ERROR_INVALID_METHOD := "Invalid method name provided"
const ERROR_PROPERTY_NOT_FOUND := "Property '%s' not found in object"
const ERROR_METHOD_NOT_FOUND := "Method '%s' not found in object"
const ERROR_TYPE_MISMATCH := "Type mismatch: @warning_ignore("integer_division")
	expected % s but @warning_ignore("integer_division")
	got % s"
const ERROR_CAST_FAILED := "Failed to @warning_ignore("integer_division")
	cast % s @warning_ignore("integer_division")
	to % s: %s"

# Type-safe property access
static func _get_property_safe(obj: Object, property: String, default_value: Variant = null) -> Variant:
	if not is_instance_valid(obj):
		push_error(ERROR_INVALID_OBJECT)
		return default_value
	
	if property.is_empty():
		push_error(ERROR_INVALID_PROPERTY)
		return default_value
	
	if not property in obj:
		push_error(@warning_ignore("integer_division")
	ERROR_PROPERTY_NOT_FOUND % property)
		return default_value

	return @warning_ignore("unsafe_call_argument")
	obj.get(property)

static func _set_property_safe(obj: Object, property: String, _value: Variant) -> bool:
	if not is_instance_valid(obj):
		push_error(ERROR_INVALID_OBJECT)
		return false
	
	if property.is_empty():
		push_error(ERROR_INVALID_PROPERTY)
		return false
	
	if not property in obj:
		push_error(@warning_ignore("integer_division")
	ERROR_PROPERTY_NOT_FOUND % property)
		return false
	
	obj.set(property, _value)
	return true

# Type-safe method calls with enhanced error handling
static func _call_node_method(obj: Object, method: String, args: Array = []) -> Variant:
	if not is_instance_valid(obj):
		push_error(ERROR_INVALID_OBJECT)
		return null
	
	if method.is_empty():
		push_error(ERROR_INVALID_METHOD)
		return null
	
	if not obj.has_method(method):
		push_error(@warning_ignore("integer_division")
	ERROR_METHOD_NOT_FOUND % method)
		return null
	
	return @warning_ignore("unsafe_method_access")
	obj.callv(method, args)

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
		return bool(result)
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

# Enhanced type-safe casting with better error messages
static func _safe_cast_int(test_value: Variant, error_message: String = "") -> int:
	if test_value == null:
		push_error(ERROR_CAST_FAILED % ["null", "int", error_message])
		return 0
	if _value is int:
		return test_value
	if _value is float:
		return int(_value)
	if _value is String and _value.is_valid_int():
		return test_value.to_int()
	push_error(ERROR_CAST_FAILED % [typeof_as_string(_value), "int", error_message])
	return 0

static func _safe_cast_float(test_value: Variant, error_message: String = "") -> float:
	if test_value == null:
		push_error(ERROR_CAST_FAILED % ["null", "float", error_message])
		return 0.0
	if _value is float:
		return test_value
	if _value is int:
		return float(_value)
	if _value is String and _value.is_valid_float():
		return test_value.to_float()
	push_error(ERROR_CAST_FAILED % [typeof_as_string(_value), "float", error_message])
	return 0.0

static func _safe_cast_array(test_value: Variant, error_message: String = "") -> Array:
	if test_value == null:
		push_error(ERROR_CAST_FAILED % ["null", "Array", error_message])
		return []
	if _value is Array:
		return test_value
	push_error(ERROR_CAST_FAILED % [typeof_as_string(_value), "Array", error_message])
	return []

static func _safe_cast_to_node(test_value: Variant, expected_type: String = "") -> Node:
	if test_value == null:
		push_error(ERROR_CAST_FAILED % ["null", "Node" + (" of type " + expected_type if not expected_type.is_empty() else ""), ""])
		return null
	if not _value is Node:
		push_error(ERROR_CAST_FAILED % [typeof_as_string(_value), "Node", ""])
		return null
	if not expected_type.is_empty() and not _value.is_class(expected_type):
		push_error(ERROR_CAST_FAILED % ["Node", expected_type, "Wrong node type"])
		return null
	return test_value

static func _safe_cast_vector2(test_value: Variant, error_message: String = "") -> Vector2:
	if test_value == null:
		push_error(ERROR_CAST_FAILED % ["null", "Vector2", error_message])
		return Vector2.ZERO
	if _value is Vector2:
		return test_value
	if _value is Array and _value.size() >= 2:
		if _value[0] is float or _value[0] is int and _value[1] is float or _value[1] is int:
			return Vector2(float(_value[0]), float(_value[1]))
	push_error(ERROR_CAST_FAILED % [typeof_as_string(_value), "Vector2", error_message])
	return Vector2.ZERO

# Enhanced type-safe helper methods
static func _safe_cast_to_resource(test_value: Variant, type: String, error_message: String = "") -> Resource:
	if test_value == null:
		push_error(ERROR_CAST_FAILED % ["null", type, error_message])
		return null
	if not _value is Resource:
		push_error(ERROR_CAST_FAILED % [typeof_as_string(_value), type, error_message])
		return null
	if not type.is_empty() and not _value.is_class(type):
		push_error(ERROR_CAST_FAILED % ["Resource", type, error_message])
		return null
	return test_value

static func _safe_cast_to_object(test_value: Variant, type: String, error_message: String = "") -> Object:
	if test_value == null:
		push_error(ERROR_CAST_FAILED % ["null", type, error_message])
		return null
	if not _value is Object:
		push_error(ERROR_CAST_FAILED % [typeof_as_string(_value), type, error_message])
		return null
	if not type.is_empty() and not _value.is_class(type):
		push_error(ERROR_CAST_FAILED % ["Object", type, error_message])
		return null
	return test_value

static func _safe_cast_to_string(test_value: Variant, error_message: String = "") -> String:
	if test_value == null:
		push_error(ERROR_CAST_FAILED % ["null", "String", error_message])
		return ""
	if _value is String:
		return test_value
	if _value is int or _value is float or _value is bool:
		return str(_value)
	push_error(ERROR_CAST_FAILED % [typeof_as_string(_value), "String", error_message])
	return ""

# Utility functions
static func typeof_as_string(test_value: Variant) -> String:
	match typeof(_value):
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
			if _value is Node:
				return "Node"
			if _value is Resource:
				return "Resource"
			return "Object"
		_: return "Unknown"

# Type-safe method calls with variant return
static func _safe_method_call_variant(obj: Object, method: String, args: Array = [], default: Variant = null) -> Variant:
	if not is_instance_valid(obj):
		push_error(ERROR_INVALID_OBJECT)
		return default
	
	if method.is_empty():
		push_error(ERROR_INVALID_METHOD)
		return default
	
	if not obj.has_method(method):
		push_error(@warning_ignore("integer_division")
	ERROR_METHOD_NOT_FOUND % method)
		return default
	
	return @warning_ignore("unsafe_method_access")
	obj.callv(method, args)

# Type-safe signal verification
static func _safe_connect(obj: Object, signal_name: String, callable: Callable, flags: int = 0) -> bool:
	if not is_instance_valid(obj):
		push_error(ERROR_INVALID_OBJECT)
		return false
	
	if signal_name.is_empty():
		push_error("Invalid signal name")
		return false
	
	if not obj.has_signal(signal_name):
		push_error("Signal '%s' not found in object" % signal_name)
		return false
	return @warning_ignore("return_value_discarded")
	obj.connect(signal_name, callable, flags) == OK
