# Five Parsecs Test Safety Patterns

This document outlines safety patterns to prevent common errors and ensure reliable tests across the Five Parsecs Campaign Manager codebase.

## Resource Safety Patterns

### Valid Resource Paths

Resources without valid resource paths can cause `inst_to_dict()` errors during testing. Always ensure resources have valid paths:

```gdscript
# Ensure resource has a valid path
if resource is Resource and resource.resource_path.is_empty():
    var timestamp = Time.get_unix_time_from_system()
    resource.resource_path = "res://tests/generated/%s_%d.tres" % [resource.get_class().to_snake_case(), timestamp]
```

### Resource Tracking

Always track resources for proper cleanup:

```gdscript
# For nodes:
add_child_autofree(node)
track_test_node(node)

# For resources:
track_test_resource(resource)
```

### Safe Serialization Pattern

Avoid `inst_to_dict()` for serialization; instead, manually copy properties:

```gdscript
# Instead of inst_to_dict, copy properties explicitly
var serialized = {}
if resource.has("property_name"):
    serialized["property_name"] = resource.property_name
else:
    serialized["property_name"] = default_value

# For collections, always duplicate
if resource.has("array_property"):
    serialized["array_property"] = resource.array_property.duplicate()
```

### Safe Deserialization Pattern

When deserializing, check input data and use default values:

```gdscript
# Always check input data
if data == null or not data is Dictionary:
    return null
    
# Set properties with defaults
resource.property = data.get("property", default_value)

# Duplicate collections when deserializing
resource.array_property = data.get("array_property", []).duplicate()
```

## Mission Object Safety

Mission objects require special handling due to their complex property structures:

```gdscript
# When creating mission objects
var mission = StoryQuestData.create_mission("Test Mission")

# Always ensure valid resource path
if mission.resource_path.is_empty():
    var timestamp = Time.get_unix_time_from_system()
    mission.resource_path = "res://tests/generated/mission_%s_%d.tres" % [mission.get_class().to_snake_case(), timestamp]
    
# When serializing missions
var serialized_mission = {}
for property in mission.get_property_list():
    var property_name = property.name
    if property_name.begins_with("_") or property_name in ["script", "resource_path", "resource_name"]:
        continue
    
    if mission.has(property_name):
        var value = mission.get(property_name)
        if value is Array or value is Dictionary:
            serialized_mission[property_name] = value.duplicate()
        elif not value is Callable:  # Skip callable properties
            serialized_mission[property_name] = value
```

## Dictionary Access Patterns

Use the correct dictionary access patterns for Godot 4.4:

```gdscript
# AVOID: Using has() on dictionaries
if dictionary.has("key"):
    # Do something

# CORRECT: Using the 'in' operator
if "key" in dictionary:
    # Do something
    
# Safe value retrieval with default
var value = dictionary.get("key", default_value)
```

## Property Access Patterns

Use safe property access with existence checks:

```gdscript
# Check if property exists before accessing
if object.has("property_name"):
    var value = object.property_name
else:
    var value = default_value

# Using get() with default value
var value = object.get("property_name", default_value)
```

## Method Call Patterns

Use type-safe method calls:

```gdscript
# Instead of direct calls:
instance.method(args)

# Check method existence first:
if instance.has_method("method_name"):
    instance.method_name(args)
else:
    # Fallback behavior
    push_warning("Method 'method_name' not found")

# Or use type-safe calls from TypeSafeMixin:
TypeSafeMixin._call_node_method_bool(instance, "method_name", [args])
```

## Signal Safety

Use proper signal watching and verification:

```gdscript
# Enable signal watching
watch_signals(instance)

# Perform action that should emit signal
TypeSafeMixin._call_node_method_bool(instance, "method", [])

# Verify signal emission
verify_signal_emitted(instance, "signal_name")

# With signal parameters
verify_signal_emitted_with_parameters(instance, "signal_name", [expected_param])
```

## Object Validity Checks

Always check object validity before operations:

```gdscript
if is_instance_valid(object):
    # Use object
```

## Stabilization Pattern

Use proper stabilization for asynchronous operations:

```gdscript
# Allow the engine to stabilize
await stabilize_engine()

# With custom timeout
await stabilize_engine(CUSTOM_TIMEOUT)
```

## Test Lifecycle Safety

Properly structure before_each and after_each:

```gdscript
func before_each() -> void:
    # Always call super first
    await super.before_each()
    
    # Setup code here
    _instance = TestedClass.new()
    track_test_resource(_instance)
    
    # Always stabilize at the end
    await stabilize_engine()

func after_each() -> void:
    # Cleanup code here
    _instance = null
    
    # Always call super last
    await super.after_each()
```

## Collection Duplication

Always duplicate collections before modifying:

```gdscript
# For arrays
var copy_of_array = original_array.duplicate()

# For dictionaries
var copy_of_dict = original_dict.duplicate()

# Deep duplication for nested structures
var deep_copy = original.duplicate(true)
```

## Error Handling

Implement proper error handling:

```gdscript
# Try-catch pattern
if ResourceLoader.exists(path):
    var loaded = ResourceLoader.load(path)
    if loaded:
        return loaded
    else:
        push_warning("Failed to load resource at: " + path)
        return null
else:
    return null
```

## File Path References

Always use explicit file paths in extends statements:

```gdscript
# CORRECT: Use file path reference
@tool
extends "res://tests/fixtures/specialized/campaign_test.gd"

# AVOID: Using class names directly
@tool
extends CampaignTest

# AVOID: Using relative paths
@tool
extends "../campaign_test.gd"
```

## Resource Generation

Generate resources consistently for testing:

```gdscript
# Generate temporary resource path
var timestamp = Time.get_unix_time_from_system()
var temp_path = "res://tests/generated/%s_%d.tres" % [resource.get_class().to_snake_case(), timestamp]

# Create and save resource
var resource = Resource.new()
resource.resource_path = temp_path
ResourceSaver.save(resource, temp_path)

# Track for cleanup
track_test_resource(resource)
```

## Mission Functions Safety

When working with mission functions:

```gdscript
# Add mission functions safely
func add_safe_mission_functions(mission):
    var script = GDScript.new()
    script.source_code = """
    extends Resource
    
    func on_mission_start():
        return true
        
    func on_mission_complete():
        return true
        
    func on_mission_fail():
        return false
    """
    script.reload()
    
    # Apply script to mission
    var original_script = mission.get_script()
    mission.set_script(script)
    
    # Ensure resource path
    if mission.resource_path.is_empty():
        var timestamp = Time.get_unix_time_from_system()
        mission.resource_path = "res://tests/generated/mission_%s_%d.tres" % [mission.get_class().to_snake_case(), timestamp]
    
    return mission
```

## Preventing Common Errors

### inst_to_dict Errors

```
Error calling GDScript utility function 'inst_to_dict': Not based on a resource file
```

Prevention:
- Ensure resources have valid resource paths
- Use manual serialization with property copying
- Don't use inst_to_dict directly

### Dictionary Method Errors

```
Invalid call to method 'has' ... expected 1 arguments
```

Prevention:
- Use `in` operator instead of `has()`
- Use `dictionary.get(key, default)` for safe retrieval

### Method Call Errors

```
Invalid call. Nonexistent function in base 'Object'
```

Prevention:
- Check if method exists with `has_method()`
- Use type-safe method calls from TypeSafeMixin

### Resource Leaks

Prevention:
- Use `track_test_resource()` for all resources
- Use `add_child_autofree()` for nodes
- Clear references in `after_each()`
- Call `await super.after_each()` in all test classes

### Signal Connection Errors

Prevention:
- Use `watch_signals()` for proper testing
- Verify signal exists before connecting
- Use `verify_signal_emitted()` for testing

## Common Test Code Smells

1. **Direct property access without checks**: Always check if properties exist
2. **Using inst_to_dict directly**: Use manual property copying instead
3. **Missing resource path assignment**: Always set valid resource paths
4. **Untracked resources**: Always track resources with track_test_resource
5. **Missing super calls**: Always call super.before_each() and super.after_each()
6. **Using class names in extends**: Use absolute file paths instead
7. **Direct lambda assignments**: Use script-based approach instead
8. **Dictionary.has() usage**: Use the in operator
9. **Unchecked signal connections**: Verify signals exist before connecting
```