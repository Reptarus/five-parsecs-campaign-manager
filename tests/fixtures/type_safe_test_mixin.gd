@tool
extends RefCounted
class_name TypeSafeMixin

# Type-safe property access
static func _get_property_safe(obj: Object, property: String, default_value: Variant = null) -> Variant:
	if not obj or not property:
		push_error("Invalid object or property name")
		return default_value
	
	if not property in obj:
		push_error("Property '%s' not found in object" % property)
		return default_value
	
	return obj.get(property)

static func _set_property_safe(obj: Object, property: String, value: Variant) -> void:
	if not obj or not property:
		push_error("Invalid object or property name")
		return
	
	if not property in obj:
		push_error("Property '%s' not found in object" % property)
		return
	
	obj.set(property, value)

# Type-safe method calls
static func _call_node_method(obj: Object, method: String, args: Array = []) -> Variant:
	if not obj or not method:
		push_error("Invalid object or method name")
		return null
	
	if not obj.has_method(method):
		push_error("Method '%s' not found in object" % method)
		return null
	
	return obj.callv(method, args)

static func _call_node_method_int(obj: Object, method: String, args: Array = []) -> int:
	var result = _call_node_method(obj, method, args)
	if result is int:
		return result
	push_error("Method '%s' did not return an integer" % method)
	return 0

static func _call_node_method_bool(obj: Object, method: String, args: Array = []) -> bool:
	var result = _call_node_method(obj, method, args)
	if result is bool:
		return result
	push_error("Method '%s' did not return a boolean" % method)
	return false

static func _call_node_method_array(obj: Object, method: String, args: Array = []) -> Array:
	var result = _call_node_method(obj, method, args)
	if result is Array:
		return result
	push_error("Method '%s' did not return an array" % method)
	return []

static func _call_node_method_dict(obj: Object, method: String, args: Array = []) -> Dictionary:
	var result = _call_node_method(obj, method, args)
	if result is Dictionary:
		return result
	push_error("Method '%s' did not return a dictionary" % method)
	return {}

# Type-safe casting
static func _safe_cast_int(value: Variant, error_message: String = "") -> int:
	if value is int:
		return value
	if value is float:
		return int(value)
	if value is String and value.is_valid_int():
		return value.to_int()
	push_error("Failed to cast to int: %s" % error_message)
	return 0

static func _safe_cast_float(value: Variant, error_message: String = "") -> float:
	if value is float:
		return value
	if value is int:
		return float(value)
	if value is String and value.is_valid_float():
		return value.to_float()
	push_error("Failed to cast to float: %s" % error_message)
	return 0.0

static func _safe_cast_array(value: Variant, error_message: String = "") -> Array:
	if value is Array:
		return value
	push_error("Failed to cast to array: %s" % error_message)
	return []

static func _safe_cast_to_node(value: Variant, expected_type: String = "") -> Node:
	if value is Node:
		if expected_type.is_empty() or value.is_class(expected_type):
			return value
	push_error("Failed to cast to Node%s" % (" of type " + expected_type if not expected_type.is_empty() else ""))
	return null

static func _safe_cast_vector2(value: Variant, error_message: String = "") -> Vector2:
	if value is Vector2:
		return value
	push_error("Failed to cast to Vector2: %s" % error_message)
	return Vector2.ZERO

# Type-safe helper methods
static func _safe_cast_to_resource(value: Variant, type: String, error_message: String = "") -> Resource:
	if not value is Resource:
		push_error("Cannot cast to %s: %s" % [type, error_message])
		return null
	return value

static func _safe_cast_to_object(value: Variant, type: String, error_message: String = "") -> Object:
	if not value is Object:
		push_error("Cannot cast to %s: %s" % [type, error_message])
		return null
	return value

static func _safe_cast_to_string(value: Variant, error_message: String = "") -> String:
	if not value is String:
		push_error("Cannot cast to String: %s" % error_message)
		return ""
	return value

static func _safe_method_call_bool(obj: Object, method: String, args: Array = [], default: bool = false) -> bool:
	if not obj or not obj.has_method(method):
		push_error("Invalid method call to %s" % method)
		return default
	var result: Variant = obj.callv(method, args)
	return bool(result) if result is bool else default

static func _safe_method_call_int(obj: Object, method: String, args: Array = [], default: int = 0) -> int:
	if not obj or not obj.has_method(method):
		push_error("Invalid method call to %s" % method)
		return default
	var result: Variant = obj.callv(method, args)
	return int(result) if result is int else default

static func _safe_method_call_array(obj: Object, method: String, args: Array = [], default: Array = []) -> Array:
	if not obj or not obj.has_method(method):
		push_error("Invalid method call to %s" % method)
		return default
	var result: Variant = obj.callv(method, args)
	return result if result is Array else default

static func _safe_method_call_string(obj: Object, method: String, args: Array = [], default: String = "") -> String:
	if not obj or not obj.has_method(method):
		push_error("Invalid method call to %s" % method)
		return default
	var result: Variant = obj.callv(method, args)
	return String(result) if result is String else default

static func _safe_method_call_resource(obj: Object, method: String, args: Array = [], default: Resource = null) -> Resource:
	if not obj or not obj.has_method(method):
		push_error("Invalid method call to %s" % method)
		return default
	var result: Variant = obj.callv(method, args)
	return result if result is Resource else default

static func _safe_method_call_dict(obj: Object, method: String, args: Array = [], default: Dictionary = {}) -> Dictionary:
	if not obj or not obj.has_method(method):
		push_error("Invalid method call to %s" % method)
		return default
	var result: Variant = obj.callv(method, args)
	return result if result is Dictionary else default

static func _safe_method_call_float(obj: Object, method: String, args: Array = [], default: float = 0.0) -> float:
	if not obj or not obj.has_method(method):
		push_error("Invalid method call to %s" % method)
		return default
	var result: Variant = obj.callv(method, args)
	return float(result) if result is float else default