@tool
extends RefCounted
class_name TypeSafeTestMixin

# Type-safe helper methods
static func _safe_cast_to_resource(value: Variant, type: String, error_message: String = "") -> Resource:
    if not value is Resource:
        push_error("Cannot cast to %s: %s" % [type, error_message])
        return null
    return value

static func _safe_cast_to_node(value: Variant, type: String, error_message: String = "") -> Node:
    if not value is Node:
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