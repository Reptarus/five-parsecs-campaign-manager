@tool
extends RefCounted

# Type-safe error handling
const ERROR_INVALID_OBJECT := "Invalid object provided"
const ERROR_INVALID_PROPERTY := "Invalid property name provided"
const ERROR_INVALID_METHOD := "Invalid method name provided"
const ERROR_PROPERTY_NOT_FOUND := "Property '%s' not found in object"
const ERROR_METHOD_NOT_FOUND := "Method '%s' not found in object"
const ERROR_TYPE_MISMATCH := "Type mismatch: expected %s but got %s"
const ERROR_CAST_FAILED := "Failed to cast %s to %s: %s"

# Type-safe property access
static func _get_property_safe(obj: Object, property: String, default_value: Variant = null) -> Variant:
	if not is_instance_valid(obj):
		push_error(ERROR_INVALID_OBJECT)
		return default_value
	
	if property.is_empty():
		push_error(ERROR_INVALID_PROPERTY)
		return default_value
	
	if not property in obj:
		push_error(ERROR_PROPERTY_NOT_FOUND % property)
		return default_value
	
	return obj.get(property)

static func _set_property_safe(obj: Object, property: String, value: Variant) -> bool:
	if not is_instance_valid(obj):
		push_error(ERROR_INVALID_OBJECT)
		return false
	
	if property.is_empty():
		push_error(ERROR_INVALID_PROPERTY)
		return false
	
	if not property in obj:
		push_error(ERROR_PROPERTY_NOT_FOUND % property)
		return false
	
	obj.set(property, value)
	return true

# Type-safe method calls with enhanced error handling
static func _call_node_method(obj: Object, method: String, args: Array = []) -> Variant:
	if obj == null:
		push_warning(ERROR_INVALID_OBJECT + ": Object is null for method " + method)
		return null
		
	if not is_instance_valid(obj):
		push_warning(ERROR_INVALID_OBJECT + ": Object is not valid for method " + method)
		return null
	
	if method.is_empty():
		push_warning(ERROR_INVALID_METHOD + " when calling on " + str(obj))
		return null
	
	if not obj.has_method(method):
		push_warning(ERROR_METHOD_NOT_FOUND % method + " in object " + str(obj))
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
	
	# Try to convert to boolean if possible
	if result == null:
		return default
	if result is bool:
		return result
	if result is int:
		return result != 0
	if result is float:
		return result != 0.0
	if result is String:
		var lower_result = result.to_lower()
		if lower_result == "true" or lower_result == "yes" or lower_result == "1":
			return true
		if lower_result == "false" or lower_result == "no" or lower_result == "0" or lower_result.is_empty():
			return false
		return not result.is_empty()
	if result is Dictionary:
		if result.has("success"):
			return result.success
		if result.has("is_valid"):
			return result.is_valid
		if result.has("valid"):
			return result.valid
		return not result.is_empty()
	if result is Array:
		return not result.is_empty()
		
	# Default to true for non-null values that aren't easily convertible
	return true

static func _call_node_method_array(obj: Object, method: String, args: Array = [], default: Array = []) -> Array:
	var result = _call_node_method(obj, method, args)
	
	# Return default for null results
	if result == null:
		push_warning("Null result from method %s, using default array" % method)
		return default
	
	# Handle Array types - both regular and typed arrays return is_array() == true
	if result is Array:
		return result
	
	# If we get here, the result isn't an array
	push_error(ERROR_TYPE_MISMATCH % ["Array", typeof_as_string(result)])
	push_warning("Got %s instead of Array from method %s" % [typeof_as_string(result), method])
	return default

static func _call_node_method_dict(obj: Object, method: String, args: Array = [], default: Dictionary = {}) -> Dictionary:
	var result = _call_node_method(obj, method, args)
	if result == null:
		return default
	if result is Dictionary:
		return result
	push_error(ERROR_TYPE_MISMATCH % ["Dictionary", typeof_as_string(result)])
	return default

static func _call_node_method_resource(obj: Object, method: String, args: Array = [], default: Resource = null) -> Resource:
	var result = _call_node_method(obj, method, args)
	if result == null:
		return default
	if result is Resource:
		return result
	push_error(ERROR_TYPE_MISMATCH % ["Resource", typeof_as_string(result)])
	return default

# Enhanced type-safe casting with better error messages
static func _safe_cast_int(value: Variant, error_message: String = "") -> int:
	if value == null:
		push_error(ERROR_CAST_FAILED % ["null", "int", error_message])
		return 0
	if value is int:
		return value
	if value is float:
		return int(value)
	if value is String and value.is_valid_int():
		return value.to_int()
	push_error(ERROR_CAST_FAILED % [typeof_as_string(value), "int", error_message])
	return 0

static func _safe_cast_float(value: Variant, error_message: String = "") -> float:
	if value == null:
		push_error(ERROR_CAST_FAILED % ["null", "float", error_message])
		return 0.0
	if value is float:
		return value
	if value is int:
		return float(value)
	if value is String and value.is_valid_float():
		return value.to_float()
	push_error(ERROR_CAST_FAILED % [typeof_as_string(value), "float", error_message])
	return 0.0

static func _safe_cast_array(value: Variant, error_message: String = "") -> Array:
	if value == null:
		push_error(ERROR_CAST_FAILED % ["null", "Array", error_message])
		return []
	if value is Array:
		return value
	push_error(ERROR_CAST_FAILED % [typeof_as_string(value), "Array", error_message])
	return []

static func _safe_cast_to_node(value: Variant, expected_type: String = "") -> Node:
	if value == null:
		push_error(ERROR_CAST_FAILED % ["null", "Node" + (" of type " + expected_type if not expected_type.is_empty() else ""), ""])
		return null
	if not value is Node:
		push_error(ERROR_CAST_FAILED % [typeof_as_string(value), "Node", ""])
		return null
	if not expected_type.is_empty() and not value.is_class(expected_type):
		push_error(ERROR_CAST_FAILED % ["Node", expected_type, "Wrong node type"])
		return null
	return value

static func _safe_cast_vector2(value: Variant, error_message: String = "") -> Vector2:
	if value == null:
		push_error(ERROR_CAST_FAILED % ["null", "Vector2", error_message])
		return Vector2.ZERO
	if value is Vector2:
		return value
	if value is Array and value.size() >= 2:
		if value[0] is float or value[0] is int and value[1] is float or value[1] is int:
			return Vector2(float(value[0]), float(value[1]))
	push_error(ERROR_CAST_FAILED % [typeof_as_string(value), "Vector2", error_message])
	return Vector2.ZERO

# Enhanced type-safe helper methods
static func _safe_cast_to_resource(value: Variant, type: String, error_message: String = "") -> Resource:
	if value == null:
		push_error(ERROR_CAST_FAILED % ["null", type, error_message])
		return null
	if not value is Resource:
		push_error(ERROR_CAST_FAILED % [typeof_as_string(value), type, error_message])
		return null
	if not type.is_empty() and not value.is_class(type):
		push_error(ERROR_CAST_FAILED % ["Resource", type, error_message])
		return null
	return value

static func _safe_cast_to_object(value: Variant, type: String, error_message: String = "") -> Object:
	if value == null:
		push_error(ERROR_CAST_FAILED % ["null", type, error_message])
		return null
	if not value is Object:
		push_error(ERROR_CAST_FAILED % [typeof_as_string(value), type, error_message])
		return null
	if not type.is_empty() and not value.is_class(type):
		push_error(ERROR_CAST_FAILED % ["Object", type, error_message])
		return null
	return value

static func _safe_cast_to_string(value: Variant, error_message: String = "") -> String:
	if value == null:
		push_error(ERROR_CAST_FAILED % ["null", "String", error_message])
		return ""
	if value is String:
		return value
	if value is int or value is float or value is bool:
		return str(value)
	push_error(ERROR_CAST_FAILED % [typeof_as_string(value), "String", error_message])
	return ""

# Utility functions
static func typeof_as_string(value: Variant) -> String:
	match typeof(value):
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
			if value == null:
				return "null"
			if value is Node:
				return "Node"
			if value is Resource:
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
		push_error(ERROR_METHOD_NOT_FOUND % method)
		return default
	
	return obj.callv(method, args)

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
	
	return obj.connect(signal_name, callable, flags) == OK

# Helper for GUT test debugging
static func debug_test_object(obj: Object, method_names: Array[String] = [], property_names: Array[String] = []) -> Dictionary:
	var result := {
		"object_valid": is_instance_valid(obj),
		"object_type": str(obj.get_class()) if is_instance_valid(obj) else "Invalid",
		"object_path": str(obj.get_path()) if is_instance_valid(obj) and obj is Node else "Not a Node",
		"methods": {},
		"properties": {}
	}
	
	if not is_instance_valid(obj):
		push_error("Cannot debug invalid object")
		return result
		
	# Check methods
	if method_names.is_empty():
		# Get all methods if none specified
		var methods := obj.get_method_list()
		for method in methods:
			if method.name.begins_with("_"):
				continue
			method_names.append(method.name)
	
	for method_name in method_names:
		result.methods[method_name] = {
			"exists": obj.has_method(method_name),
			"callable": obj.has_method(method_name) and is_instance_valid(Callable(obj, method_name).get_object())
		}
	
	# Check properties
	if property_names.is_empty():
		# Try to get common properties
		property_names = ["name", "position", "global_position", "visible", "script"]
	
	for property_name in property_names:
		if property_name in obj:
			var value = obj.get(property_name)
			result.properties[property_name] = {
				"exists": true,
				"value": str(value),
				"type": typeof(value)
			}
		else:
			result.properties[property_name] = {
				"exists": false
			}
	
	return result
