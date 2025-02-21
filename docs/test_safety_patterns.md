# Type Safety Patterns for Godot 4 Test Files

## Overview

This document outlines the patterns and strategies used to achieve 100% type safety in Godot 4 test files, specifically focusing on eliminating unsafe cast warnings. These patterns were initially developed and applied to test files in the Five Parsecs Campaign Manager project.

## Core Principles

1. Never trust raw Variant types
2. Use explicit type checking before casting
3. Implement safe helper functions for common operations
4. Maintain clear error messaging
5. Follow fail-fast principles
6. Use consistent return types
7. Explicitly type all variables
8. Use specialized casting functions for each type
9. Implement component-specific property access methods
10. Use deferred signal handling where appropriate
11. Maintain robust test lifecycle management
12. Implement proper resource tracking and cleanup

## Safe Casting Helper Functions

### Basic Type Casting

```gdscript
func _safe_cast_object(value: Variant, error_message: String = "") -> Object:
    if not value is Object:
        push_error("Cannot cast to Object: %s" % error_message)
        return null
    return value
```

Similar functions exist for:
- `_safe_cast_node()`
- `_safe_cast_resource()`
- `_safe_cast_gdscript()`
- `_safe_cast_array()`
- `_safe_cast_dictionary()`
- `_safe_cast_bool()`
- `_safe_cast_int()`
- `_safe_cast_string()`
- `_safe_cast_signal_watcher()`

### Node Method Call Patterns

```gdscript
func _call_node_method(node: Node, method: String, args: Array = []) -> Variant:
    if not node:
        push_warning("Attempting to call method '%s' on null node" % method)
        return null
    if not node.has_method(method):
        push_warning("Node missing required method: %s" % method)
        return null
    return node.callv(method, args)

func _call_node_method_dict(node: Node, method: String, args: Array = [], default_value: Dictionary = {}) -> Dictionary:
    var result: Variant = _call_node_method(node, method, args)
    if not result is Dictionary:
        push_warning("Method '%s' did not return a Dictionary" % method)
        return default_value
    return result

func _call_node_method_array(node: Node, method: String, args: Array = [], default_value: Array = []) -> Array:
    var result: Variant = _call_node_method(node, method, args)
    if not result is Array:
        push_warning("Method '%s' did not return an Array" % method)
        return default_value
    return result
```

### Resource Method Call Patterns

```gdscript
func _call_resource_method(resource: Resource, method: String, args: Array = []) -> Variant:
    if not resource:
        push_warning("Attempting to call method '%s' on null resource" % method)
        return null
    if not resource.has_method(method):
        push_warning("Resource missing required method: %s" % method)
        return null
    return resource.callv(method, args)

func _call_resource_method_dict(resource: Resource, method: String, args: Array = [], default_value: Dictionary = {}) -> Dictionary:
    var result: Variant = _call_resource_method(resource, method, args)
    if not result is Dictionary:
        push_warning("Method '%s' did not return a Dictionary" % method)
        return default_value
    return result
```

### Component-Specific Property Access

```gdscript
func _get_ui_property(property: String, default_value: Variant = null) -> Variant:
    if not ui_component:
        push_error("Trying to access property '%s' on null UI component" % property)
        return default_value
    if not property in ui_component:
        push_error("UI component missing required property: %s" % property)
        return default_value
    return ui_component.get(property)

func _set_ui_property(property: String, value: Variant) -> void:
    if not ui_component:
        push_error("Trying to set property '%s' on null UI component" % property)
        return
    if not property in ui_component:
        push_error("UI component missing required property: %s" % property)
        return
    ui_component.set(property, value)
```

## Signal Handling Patterns

### Enhanced SignalWatcher Class

```gdscript
class SignalWatcher:
    var _watched_signals: Dictionary = {}
    var _signal_emissions: Dictionary = {}
    var _parent: Node
    
    func _init(parent: Node) -> void:
        _parent = parent
    
    func watch_signals(emitter: Object) -> void:
        if not emitter:
            push_warning("Attempting to watch signals on null emitter")
            return
            
        if not _watched_signals.has(emitter):
            _watched_signals[emitter] = []
            _signal_emissions[emitter] = {}
            
            var signal_list: Array = emitter.get_signal_list()
            for signal_info: Dictionary in signal_list:
                var signal_name: String = signal_info.get("name", "")
                if signal_name.is_empty():
                    continue
                
                if _watched_signals[emitter] is Array:
                    var signals: Array = _watched_signals[emitter]
                    if not signals.has(signal_name):
                        signals.append(signal_name)
                _signal_emissions[emitter][signal_name] = []
                
                if emitter.has_signal(signal_name):
                    var callback := func(arg1: Variant = null, arg2: Variant = null,
                            arg3: Variant = null, arg4: Variant = null,
                            arg5: Variant = null) -> void:
                        var args: Array = []
                        var arg_list: Array = [arg1, arg2, arg3, arg4, arg5]
                        for arg: Variant in arg_list:
                            if arg != null:
                                args.append(arg)
                        _on_signal_emitted.call_deferred(emitter, signal_name, args)
                    
                    # Connect returns void in Godot 4
                    emitter.connect(signal_name, callback, CONNECT_DEFERRED)
```

### Signal Connection Safety

```gdscript
func _connect_signals() -> void:
    if not component:
        return
        
    if component.has_signal("signal_name"):
        component.connect("signal_name", _on_signal_handler)

func _disconnect_signals() -> void:
    if not component:
        return
        
    if component.has_signal("signal_name") and component.is_connected("signal_name", _on_signal_handler):
        component.disconnect("signal_name", _on_signal_handler)
```

## Test Resource Management

### Enhanced Resource Tracking

```gdscript
# Type-safe tracking arrays
var _tracked_nodes: Array[Node] = []
var _tracked_resources: Array[Resource] = []

func track_test_node(node: Node) -> void:
    if not node:
        push_warning("Attempting to track null node")
        return
    if not node in _tracked_nodes:
        _tracked_nodes.append(node)

func track_test_resource(resource: Resource) -> void:
    if not resource:
        push_warning("Attempting to track null resource")
        return
    if not resource in _tracked_resources:
        _tracked_resources.append(resource)
```

### Robust Cleanup

```gdscript
func cleanup_tracked_nodes() -> void:
    for node in _tracked_nodes:
        if is_instance_valid(node) and node.is_inside_tree():
            node.queue_free()
    _tracked_nodes.clear()

func cleanup_tracked_resources() -> void:
    for resource in _tracked_resources:
        if resource and not resource.is_queued_for_deletion():
            resource = null
    _tracked_resources.clear()
```

## Test Lifecycle Management

### Type-Safe Before/After Methods

```gdscript
func before_each() -> void:
    await super.before_each()
    _tracked_nodes.clear()
    _tracked_resources.clear()
    _signal_watcher = null
    
    # Initialize components with type safety
    component = ComponentScene.instantiate()
    if not component:
        push_error("Failed to instantiate component")
        return
        
    add_child_autofree(component)
    track_test_node(component)
    watch_signals(component)
    await get_tree().process_frame

func after_each() -> void:
    # Clean up components
    if component:
        component.queue_free()
        component = null
    
    cleanup_tracked_nodes()
    cleanup_tracked_resources()
    _signal_watcher = null
    await super.after_each()
```

## Type-Safe Assertion Methods

```gdscript
func assert_eq_variant(got: Variant, expected: Variant, text: String = "") -> void:
    # Ensure both values are of the same type before comparison
    var got_type := typeof(got)
    var expected_type := typeof(expected)
    
    if got_type != expected_type:
        assert_false(true, "Type mismatch in assert_eq: got %s (%d), expected %s (%d). %s" % [
            got, got_type, expected, expected_type, text
        ])
        return
    
    # Now we can safely compare
    assert_eq(got, expected, text)

func assert_true_variant(got: Variant, text: String = "") -> void:
    # Convert to boolean explicitly
    var bool_value: bool = false
    
    match typeof(got):
        TYPE_BOOL:
            bool_value = bool(got)
        TYPE_INT:
            bool_value = int(got) != 0
        TYPE_FLOAT:
            bool_value = float(got) != 0.0
        TYPE_STRING:
            bool_value = String(got).length() > 0
        TYPE_OBJECT:
            bool_value = got != null
        _:
            bool_value = got != null
    
    assert_true(bool_value, text)
```

## Error Handling

### Type-Safe Error Handling

```gdscript
func _safe_cast_error(value: Variant, error_message: String = "") -> Error:
    if not value is int:
        push_warning("Cannot cast to Error: %s" % error_message)
        return ERR_INVALID_DATA
    return value # Error is an enum, which is an int, so this is safe

func _handle_error(error: Error, context: String) -> void:
    if error != OK:
        push_warning("%s failed with error: %s" % [context, error_string(error)])
```

## Best Practices Summary

1. Always use type annotations for variables and parameters
2. Track and clean up test resources properly
3. Use safe property access and method calls
4. Implement proper error handling with descriptive messages
5. Use consistent naming patterns to avoid shadowing
6. Validate all node creation and script assignment operations
7. Use dedicated casting functions for type safety
8. Handle null cases explicitly
9. Provide meaningful error messages
10. Clean up resources in after_each()
11. Use deferred signal handling where appropriate
12. Implement component-specific property access methods
13. Maintain robust test lifecycle management
14. Use type-safe assertion methods
15. Handle errors gracefully with proper context

## References

- [Godot 4 Type System Documentation](https://docs.godotengine.org/en/stable/tutorials/scripting/gdscript/static_typing.html)
- [GDScript Style Guide](https://docs.godotengine.org/en/stable/tutorials/scripting/gdscript/gdscript_styleguide.html)
- [GDScript Warning System](https://docs.godotengine.org/en/stable/tutorials/scripting/gdscript/warning_system.html)

## Enhanced Type Safety Patterns

### Handling UNTYPED_DECLARATION and UNSAFE_CALL_ARGUMENT Warnings

These patterns provide robust type safety for test files, particularly addressing common linter warnings around untyped declarations and unsafe method calls.

#### Type-Safe Helper Methods

```gdscript
# Type casting with error handling
func _safe_cast_to_object(value: Variant, type: String, error_message: String = "") -> Object:
    if not value is Object:
        push_error("Cannot cast to %s: %s" % [type, error_message])
        return null
    return value

func _safe_cast_to_string(value: Variant, error_message: String = "") -> String:
    if not value is String:
        push_error("Cannot cast to String: %s" % error_message)
        return ""
    return value

# Type-safe method calls with specific return types
func _safe_method_call_bool(obj: Object, method: String, args: Array = [], default: bool = false) -> bool:
    if not obj or not obj.has_method(method):
        push_error("Invalid method call to %s" % method)
        return default
    var result: Variant = obj.callv(method, args)
    return bool(result) if result is bool else default

func _safe_method_call_int(obj: Object, method: String, args: Array = [], default: int = 0) -> int:
    if not obj or not obj.has_method(method):
        push_error("Invalid method call to %s" % method)
        return default
    var result: Variant = obj.callv(method, args)
    return int(result) if result is int else default

func _safe_method_call_array(obj: Object, method: String, args: Array = [], default: Array = []) -> Array:
    if not obj or not obj.has_method(method):
        push_error("Invalid method call to %s" % method)
        return default
    var result: Variant = obj.callv(method, args)
    return result if result is Array else default
```

#### Type-Safe Signal Handling

```gdscript
func _safe_connect_signal(source: Object, signal_name: String, target: Callable) -> bool:
    if not source or not source.has_signal(signal_name):
        push_error("Signal %s not found" % signal_name)
        return false
    var err: Error = source.connect(signal_name, target)
    return err == OK
```

#### Best Practices for Type Safety

1. **Explicit Type Annotations**
   ```gdscript
   # Always declare variable types
   var game_state: Node = null
   var _credits_changed: bool = false
   var _resources_changed: bool = false

   # Explicit return types for functions
   func _create_test_character() -> Node:
   func _create_test_mission() -> Resource:
   ```

2. **Type-Safe Property Access**
   ```gdscript
   # Use type-safe casting for property access
   var campaign: Object = _safe_cast_to_object(
       _get_property_safe(game_state, "current_campaign"), 
       "Campaign"
   )
   var character_id: String = _safe_cast_to_string(
       _get_property_safe(character, "character_id"), 
       "character_id"
   )
   ```

3. **Method Call Safety**
   ```gdscript
   # Type-safe method calls with error handling
   var add_result: bool = _safe_method_call_bool(campaign, "add_crew_member", [character])
   if not add_result:
       push_error("Failed to add crew member")
       return

   var crew_members: Array = _safe_method_call_array(campaign, "get_crew_members")
   assert_eq(crew_members.size(), 1, "Crew should have one member")
   ```

4. **Signal Connection Safety**
   ```gdscript
   # Safe signal connections with validation
   if game_state.has_signal("credits_changed"):
       var connected: bool = _safe_connect_signal(
           game_state, 
           "credits_changed", 
           _on_credits_changed
       )
       if not connected:
           push_error("Failed to connect signal")
           return
   ```

5. **Resource and Node Creation Safety**
   ```gdscript
   # Safe resource creation with type checking
   func _create_test_mission() -> Resource:
       var mission: Resource = MissionScript.new()
       if not mission:
           push_error("Failed to create mission instance")
           return null
       
       var type_result: bool = _safe_method_call_bool(
           mission, 
           "set_type", 
           [GameEnumsScript.MissionType.PATROL]
       )
       if not type_result:
           mission.set("type", GameEnumsScript.MissionType.PATROL)
       
       return mission
   ```

### Common Type Safety Patterns

1. **Always Check for Null**
   ```gdscript
   if not character:
       push_error("Failed to create character instance")
       return null
   ```

2. **Validate Method Existence**
   ```gdscript
   if not obj or not obj.has_method(method):
       push_error("Invalid method call to %s" % method)
       return default
   ```

3. **Type-Safe Signal Handling**
   ```gdscript
   if game_state.has_signal("signal_name") and 
      game_state.is_connected("signal_name", callback):
       game_state.disconnect("signal_name", callback)
   ```

4. **Default Values for Type Safety**
   ```gdscript
   # Always provide type-appropriate default values
   func _safe_cast_to_string(value: Variant, error_message: String = "") -> String:
       return value if value is String else ""
   ```

5. **Error Messages with Context**
   ```gdscript
   push_error("Cannot cast to %s: %s" % [type, error_message])
   push_error("Invalid method call to %s" % method)
   ```

### Benefits

1. Eliminates UNTYPED_DECLARATION warnings by ensuring all variables have explicit type annotations
2. Prevents UNSAFE_CALL_ARGUMENT warnings through type-safe method calls
3. Provides clear error messages for debugging
4. Ensures type safety across object interactions
5. Maintains consistent return types
6. Handles edge cases gracefully with default values
7. Improves code maintainability and readability

### Implementation Notes

1. These patterns should be implemented in a base test class for reuse
2. Custom type-safe methods can be added for specific project needs
3. Default values should be appropriate for the expected type
4. Error messages should be descriptive and context-aware
5. Type safety should not compromise test readability

## References

- [Godot 4 Type System Documentation](https://docs.godotengine.org/en/stable/tutorials/scripting/gdscript/static_typing.html)
- [GDScript Style Guide](https://docs.godotengine.org/en/stable/tutorials/scripting/gdscript/gdscript_styleguide.html)
- [GDScript Warning System](https://docs.godotengine.org/en/stable/tutorials/scripting/gdscript/warning_system.html) 