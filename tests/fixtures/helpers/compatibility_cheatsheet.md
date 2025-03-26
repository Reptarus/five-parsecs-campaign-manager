# GUT Compatibility Helper Cheatsheet

This cheatsheet provides quick examples for test writers to use the `test_compatibility_helper.gd` in their tests to ensure Godot 4.4 compatibility.

## Import Helper

```gdscript
const Compatibility = preload("res://tests/fixtures/helpers/test_compatibility_helper.gd")
```

## Working with Resources

### Ensure Resource Path

```gdscript
# Create resource and ensure it has a valid path
var resource = SomeResource.new()
resource = Compatibility.ensure_resource_path(resource, "descriptive_name")
```

## Safe Method Calls

### Call Methods Safely

```gdscript
# Call a method with safety - will return default_value if method doesn't exist
var result = Compatibility.safe_call_method(object, "method_name", [arg1, arg2], default_value)

# Example with bool return value
var success = Compatibility.safe_call_method(campaign, "add_mission", [mission], false)
assert_true(success, "Should add mission successfully")
```

## Dictionary Operations

### Safe Dictionary Access

```gdscript
# Safely access a dictionary key with a default value if not found
var value = Compatibility.safe_dict_get(dict, "key", default_value)

# Example
var options = {"difficulty": 3}
var level = Compatibility.safe_dict_get(options, "difficulty", 1)
```

## Property Access

### Safe Property Check and Access

```gdscript
# Check if property exists
if object.has("property_name"):
    # Property exists, use it
    object.property_name = value

# Safe property access with default
var value = Compatibility.safe_get_property(object, "property_name", default_value)
```

## Signal Connections

### Safe Signal Connection

```gdscript
# Connect a signal safely (checks if signal exists first)
Compatibility.safe_connect_signal(emitter, "signal_name", callable)
```

## Common Test Patterns

### Resource Creation Pattern

```gdscript
func _create_test_resource() -> Resource:
    if not ResourceScript:
        push_error("Resource script is null")
        return null
        
    var resource = ResourceScript.new()
    if not resource:
        push_error("Failed to create resource")
        return null
    
    # Ensure resource has valid path
    resource = Compatibility.ensure_resource_path(resource, "test_resource")
    return resource
```

### Node Creation Pattern

```gdscript
func _create_test_node() -> Node:
    if not NodeScript:
        push_error("Node script is null")
        return null
        
    var node = NodeScript.new()
    if not node:
        push_error("Failed to create node")
        return null
    
    add_child_autofree(node)
    track_test_node(node)
    return node
```

### Testing Method Existence

```gdscript
# Godot 4.4 syntax
if object.has("method_name"):
    # Method exists
    object.method_name()
```

### Watch and Verify Signals

```gdscript
# In setup
watch_signals(object)

# In test
object.emit_signal("some_signal")
verify_signal_emitted(object, "some_signal")
```

## Tips for Godot 4.4 Compatibility

1. Always use `has()` instead of `has_method()`
2. Always ensure resources have valid resource paths
3. Use safe method calls for better error handling
4. Add null checks before accessing objects
5. Add explicit type annotations for better type safety
6. Track nodes and resources properly for cleanup 