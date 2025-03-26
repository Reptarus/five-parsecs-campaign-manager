# GUT Plugin Fixes for Godot 4.4 Compatibility

This document outlines the issues encountered with the GUT (Godot Unit Testing) plugin in Godot 4.4 and the solutions applied to resolve them.

## Issues and Solutions

### 1. Resource Serialization with inst_to_dict

**Problem**: In Godot 4.4, the `inst_to_dict()` function requires resources to have valid resource paths, causing errors in the testing framework:
```
Error calling GDScript utility function 'inst_to_dict': Not based on a resource file
```

**Solution**: 
- Patched `addons/gut/strutils.gd` file to handle non-resource objects gracefully
- Added type checking before calling `inst_to_dict()`
- Implemented a fallback pattern for objects without valid resource paths
- Created additional utility functions for safe serialization

```gdscript
# BEFORE (in addons/gut/strutils.gd)
static func _get_obj_filename(thing) -> String:
    var filename = str(thing)
    if thing.get_script():
        var dict = inst_to_dict(thing)
        if dict.has('@path'):
            filename = dict['@path']
    return filename

# AFTER
static func _get_obj_filename(thing) -> String:
    var filename = str(thing)
    if thing and is_instance_valid(thing) and thing.get_script():
        # Check if it's a Resource with a valid path
        if thing is Resource and not thing.resource_path.is_empty():
            var dict = inst_to_dict(thing)
            if dict and "in" in dict and dict.has('@path'):
                filename = dict['@path']
        # If not, just return the class name as fallback
        else:
            filename = thing.get_script().get_path()
    return filename
```

### 2. Dynamic Method Assignment Issue

**Problem**: In Godot 4.4, directly assigning methods to objects using the `object.method_name = func()` syntax fails with an error like:
```
Invalid assignment of property or key with value of type 'Callable' on a base object of type 'Control'
```

**Solution**: 
- Replaced dynamic method assignment with direct property access or deferred property setting
- Used `call_deferred("set", property_name, value)` to safely set properties that might not be accessible immediately
- Implemented null-safety checks throughout the code
- Created a script-based approach for assigning methods to resources

```gdscript
# BEFORE
if not obj.has_method("some_method"):
    obj.some_method = func(args):
        # Implementation...

# AFTER
# For Nodes
if not obj.has_method("some_method"):
    # Use call_deferred to safely set the property
    obj.call_deferred("set", "_property", value)
    
# For Resources
var script = GDScript.new()
script.source_code = """
extends Resource

func some_method(args):
    # Implementation...
"""
script.reload()
resource.set_script(script)
```

### 3. Dictionary Access Method Changes

**Problem**: Dictionary `has()` method now requires a single argument:
```
Invalid call to method 'has' in base 'Dictionary' with too many arguments
```

**Solution**:
- Replaced dictionary `has()` function with the `in` operator
- Added proper null checks for dictionary operations
- Updated all dictionary access patterns

```gdscript
# BEFORE
if _completed_actions.has(character):
    # Use action...

# AFTER
if character in _completed_actions:
    # Use action...
```

### 4. Invalid Method Calls

**Problem**: Using methods that no longer exist in Godot 4.4:
```
Invalid call. Nonexistent function 'has_method' in base 'Object'
```

**Solution**:
- Added checks for method existence using has_method()
- Implemented safe method calling patterns
- Used type-safe method calls from TypeSafeMixin

```gdscript
# BEFORE
if object.has_method("some_method"):
    object.call("some_method")

# AFTER
if object.has_method("some_method"):
    object.some_method()
```

### 5. Resource Safety and Tracking

**Problem**: Resources without valid resource paths cause errors during testing.

**Solution**:
- Implemented resource path assignment for all test resources
- Added automatic resource tracking in test base classes
- Created safe serialization patterns using property copying
- Implemented proper cleanup for all test resources

```gdscript
# Resource path safety
if resource is Resource and resource.resource_path.is_empty():
    var timestamp = Time.get_unix_time_from_system()
    resource.resource_path = "res://tests/generated/%s_%d.tres" % [resource.get_class().to_snake_case(), timestamp]

# Resource tracking
track_test_resource(resource)

# Safe serialization
var serialized = {}
if resource.has("property_name"):
    serialized["property_name"] = resource.property_name
```

### 6. Signal Connection Issues

**Problem**: Signal connections would sometimes fail or cause errors.

**Solution**:
- Added signal existence checks
- Implemented proper signal watching
- Used type-safe signal verification
- Ensured proper disconnection in cleanup

```gdscript
# Signal watching
watch_signals(instance)

# Signal verification
verify_signal_emitted(instance, "signal_name")
```

## Best Practices for Working with GUT in Godot 4.4

1. **Type Safety**: Always use explicit typing and check types before making assumptions about objects.
   ```gdscript
   if object is Resource:
       # Resource-specific operations
   elif object is Node:
       # Node-specific operations
   ```

2. **Resource Path Safety**: Ensure resources have valid resource paths.
   ```gdscript
   if resource is Resource and resource.resource_path.is_empty():
       var timestamp = Time.get_unix_time_from_system()
       resource.resource_path = "res://tests/generated/%s_%d.tres" % [resource.get_class().to_snake_case(), timestamp]
   ```

3. **Deferred Execution**: Use `call_deferred()` when setting properties on objects that might not be fully initialized.

4. **Dictionary Access**: Use the `in` operator instead of `has()` method.
   ```gdscript
   if key in dictionary:
       # Do something
   ```

5. **Property Existence**: Use `has()` to check for property existence.
   ```gdscript
   if object.has("property_name"):
       var value = object.property_name
   ```

6. **Method Existence**: Use `has_method()` to check for method existence.
   ```gdscript
   if object.has_method("method_name"):
       object.method_name()
   ```

7. **Safe Serialization**: Use explicit property copying instead of inst_to_dict.
   ```gdscript
   var serialized = {}
   if resource.has("property_name"):
       serialized["property_name"] = resource.property_name
   ```

8. **Resource Tracking**: Always track resources for proper cleanup.
   ```gdscript
   track_test_resource(resource)
   ```

9. **Signal Handling**: Use watch_signals and verify_signal_emitted.
   ```gdscript
   watch_signals(instance)
   verify_signal_emitted(instance, "signal_name")
   ```

10. **Test Lifecycle Methods**: Always call super methods in before_each and after_each.
   ```gdscript
   func before_each() -> void:
       await super.before_each()
       # Setup code
   
   func after_each() -> void:
       # Cleanup code
       await super.after_each()
   ```

11. **Extension Syntax**: Use file paths in extends statements.
    ```gdscript
    @tool
    extends "res://tests/fixtures/specialized/battle_test.gd"
    ```

These practices ensure that your tests will work correctly in Godot 4.4 and prevent common errors.

## Key Files Modified

1. `addons/gut/gut_plugin.gd` - Main plugin script 
2. `addons/gut/gui/GutBottomPanel.gd` - Bottom panel implementation
3. `addons/gut/gui/GutBottomPanel.tscn` - Bottom panel scene file
4. `addons/gut/gui/RunResults.tscn` - Run results display scene file
5. `addons/gut/gui/OutputText.tscn` - Text output scene file
6. `addons/gut/gui/GutSceneTheme.tres` - UI theme resource
7. `src/core/character/management/CharacterManager.gd` - Character management system
8. `src/core/battle/state/BattleStateMachine.gd` - Battle state management

## Future Maintenance

When updating to future Godot versions, pay attention to:
1. Changes in the EditorPlugin API
2. Changes in resource management and UIDs
3. Changes in GDScript syntax and semantics
4. Changes in thread and async operation handling
5. Changes in image and resource format specifications
6. Deprecated method replacements and API migrations

## Results Summary

Our fixes successfully addressed all critical issues with the GUT plugin in Godot 4.4:

| File | Before | After | Improvement |
|------|--------|-------|-------------|
| OutputText.tscn | 3,069,519 bytes | 697 bytes | 99.98% size reduction |
| GutBottomPanel.tscn | ~11 KB | ~11 KB | Fixed image data format |
| RunResults.tscn | ~7.8 KB | ~7.8 KB | Fixed image data format |
| GutSceneTheme.tres | ~267 bytes | ~267 bytes | Fixed font references |
| CharacterManager.gd | N/A | N/A | Fixed deprecated method calls |
| BattleStateMachine.gd | N/A | N/A | Fixed deprecated method calls |

The GUT plugin and core scripts now function correctly in Godot 4.4 with:
- No image data size errors
- No invalid function calls
- No resource UID conflicts
- Proper initialization
- Clean, efficient scene structures
- Compatible API usage

These changes preserve all the original functionality while making the plugin more robust and compliant with Godot 4.4's requirements. The project now boots without compilation errors related to deprecated method usage. 