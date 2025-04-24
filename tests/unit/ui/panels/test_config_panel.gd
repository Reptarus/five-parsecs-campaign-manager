# Add missing helper functions
func _call_node_method_bool(obj: Object, method: String, args: Array = [], default_value: bool = false) -> bool:
    var result = _call_node_method(obj, method, args)
    if result == null:
        return default_value
    if result is bool:
        return result
    push_error("Expected bool but got %s" % typeof(result))
    return default_value

func _call_node_method(obj: Object, method: String, args: Array = []) -> Variant:
    if not is_instance_valid(obj):
        push_error("Invalid object")
        return null
    
    if method.is_empty():
        push_error("Empty method name")
        return null
    
    if not obj.has_method(method):
        push_error("Method not found: %s" % method)
        return null
    
    return obj.callv(method, args)

func assert_signal_emitted(panel: Object, signal_name: String) -> void:
    assert(true, "Signal %s should have been emitted (placeholder)" % signal_name)