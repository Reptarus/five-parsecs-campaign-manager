# GUT Compatibility Guide for Godot 4.4

This guide focuses on maintaining compatibility between GUT (Godot Unit Testing) and Godot 4.4. It outlines common issues, their solutions, and preventative measures to avoid GUT breaking during development.

## Common Compatibility Issues

### 1. Dictionary Method Changes

Godot 4.4 removed the ability to call `.has()` directly on dictionaries:

```gdscript
# No longer works in Godot 4.4:
if dictionary.has("key"):
    # Do something

# Must be replaced with:
if "key" in dictionary:
    # Do something
```

### 2. Static Typing Changes

Godot 4.4 enforces stricter type checking:

```gdscript
# No longer works in Godot 4.4:
var boolean_value = 1  # Integer
assert_true(boolean_value)  # Error: Cannot convert 0 to boolean

# Must be replaced with:
assert_true(bool(boolean_value))
```

### 3. Script Inheritance Resolution

Class name references in extends statements cause issues:

```gdscript
# Problematic:
extends GameTest

# Better approach:
extends "res://tests/fixtures/base/game_test.gd"
```

### 4. Scene File Corruption

GUT scene files can become corrupted, especially:
- `addons/gut/gui/GutBottomPanel.tscn`
- `addons/gut/gui/OutputText.tscn`
- `addons/gut/gui/RunResults.tscn`

### 5. Resource Path Issues

Resources without valid paths cause serialization errors:

```gdscript
# Creating a resource without a path:
var resource = Resource.new()
var serialized = inst_to_dict(resource)  # Error: Not based on a resource file
```

## Manual GUT Repair Steps

When GUT stops working in Godot 4.4, follow these manual repair steps:

### 1. Create Compatibility Layer

First, make sure you have the GUT compatibility layer correctly set up:

1. Create the directory: `addons/gut/temp`
2. Create an empty script file at `addons/gut/temp/__empty.gd` with this content:
   ```gdscript
   extends GDScript
   
   # This is an empty script file used by the compatibility layer
   # to replace GDScript.new() functionality in Godot 4.4
   ```
3. Ensure your `addons/gut/compatibility.gd` file has these critical functions (non-static):
   ```gdscript
   func create_gdscript() -> GDScript:
       return load(EMPTY_SCRIPT_PATH)
   
   func create_script_from_source(source_code: String) -> GDScript:
       var script = create_gdscript()
       script.source_code = source_code
       script.reload()
       return script
   
   func create_user_preferences(editor_settings):
       var script = load("res://addons/gut/gui/gut_user_preferences.gd")
       var instance = script.new()
       if instance.has_method("setup"):
           instance.setup(editor_settings)
       return instance
   ```

### 2. Delete Corrupted Files

Delete these files if they're large (>50KB) or corrupted:
```
addons/gut/gui/GutBottomPanel.tscn
addons/gut/gui/OutputText.tscn
addons/gut/gui/RunResults.tscn
```

### 3. Clean Up UID Files

Delete all .uid files in the GUT directory:
- On Linux/macOS: `find addons/gut -name "*.uid" -delete`
- On Windows: Manually search for and delete all .uid files in the addons/gut directory

### 4. Fix Dictionary Access

Search through your test files for `.has()` calls and replace them with the `in` operator:
```gdscript
# Find:
if dictionary.has("key")

# Replace with:
if "key" in dictionary
```

### 5. Restart and Re-enable GUT

1. Restart Godot completely
2. Go to Project > Project Settings > Plugins
3. Disable GUT plugin, then re-enable it

## The GutCompatibility Layer

We've created a compatibility layer to handle these issues. It's located at:

```
res://addons/gut/compatibility.gd
```

### Key Features

1. **Dictionary Access**:
```gdscript
# Safe dictionary has check
static func dict_has_key(dict, key) -> bool:
    if dict == null or not dict is Dictionary:
        return false
    return key in dict
```

2. **Type-Safe Method Calls**:
```gdscript
# Type-safe method calls with proper returns
static func call_method_bool(obj, method, args=[], default=false) -> bool:
    if obj == null or not obj.has_method(method):
        return default
    var result = obj.callv(method, args)
    return bool(result)
```

3. **Resource Path Safety**:
```gdscript
# Ensure resources have valid paths
static func ensure_resource_path(resource):
    if resource is Resource and resource.resource_path.is_empty():
        var timestamp = Time.get_unix_time_from_system()
        resource.resource_path = "res://tests/generated/%s_%d.tres" % [
            resource.get_class().to_snake_case(), timestamp
        ]
    return resource
```

### Using the Compatibility Layer

Import the compatibility layer in test files:

```gdscript
const GutCompatibility = preload("res://addons/gut/compatibility.gd")

# Use compatibility methods
if GutCompatibility.dict_has_key(data, "property"):
    # Do something

# Safe method calls
var bool_result = GutCompatibility.call_method_bool(obj, "is_valid", [])

# Resource safety
resource = GutCompatibility.ensure_resource_path(resource)
```

## Preventing GUT Breaking

Follow these preventative measures:

### 1. File Patterns to Avoid

Avoid these patterns in test files:

```gdscript
# 1. Don't use class names in extends
extends GameTest  # Avoid!

# 2. Don't use dictionary.has() directly
if dictionary.has("key"):  # Avoid!

# 3. Don't serialize resources without paths
var serialized = inst_to_dict(resource)  # Avoid without ensuring path!

# 4. Don't omit super calls
func before_each():
    # Missing super.before_each() - Avoid!
```

### 2. UID File Management

The `.uid` files in the `addons/gut` directory can cause issues:

```bash
# Delete all .uid files in the GUT directory (Linux/macOS)
find addons/gut -name "*.uid" -delete
```

### 3. Scene File Size Monitoring

Corrupted scene files are usually large:

```bash
# Check for large files (potentially corrupted)
find addons/gut -name "*.tscn" -size +100k
```

## Troubleshooting Specific Issues

### Error: "Invalid call. Nonexistent function 'new' in base 'GDScript'"

This occurs because Godot 4.4 removed the ability to call `new()` directly on GDScript.

**Manual Fix:**
1. Update `addons/gut/compatibility.gd` to include these non-static methods:
   ```gdscript
   func create_gdscript() -> GDScript:
       return load(EMPTY_SCRIPT_PATH)
   
   func create_script_from_source(source_code: String) -> GDScript:
       var script = create_gdscript()
       script.source_code = source_code
       script.reload()
       return script
   ```
2. Ensure the `__empty.gd` file exists at `addons/gut/temp/__empty.gd`

### Error: "Invalid access to property or key on a base object of type"

This occurs due to changes in dictionary access in Godot 4.4.

**Manual Fix:**
1. Find the file mentioned in the error
2. Replace `.has(key)` with `key in dict`
3. Replace direct property access with the safe method:
   ```gdscript
   # Replace:
   var value = dict.property
   
   # With:
   var value = GutCompatibility.dict_get(dict, "property")
   ```

### Error: "Unicode parsing error, some characters were replaced with (U+FFFD): NUL character"

This usually indicates corrupted scene files.

**Manual Fix:**
1. Delete the corrupted scene files:
   ```
   addons/gut/gui/GutBottomPanel.tscn
   addons/gut/gui/OutputText.tscn
   addons/gut/gui/RunResults.tscn
   ```
2. Restart Godot and re-enable the GUT plugin

## Godot 4.4 Compatibility Checklist

For all test files:

- [ ] Use file path references in extends statements
- [ ] Replace dictionary.has() with "key" in dictionary
- [ ] Add explicit boolean conversions with bool()
- [ ] Ensure resources have valid paths
- [ ] Call super methods in before_each/after_each
- [ ] Track all resources for cleanup
- [ ] Use type-safe method calls from GutCompatibility

## Common Error Messages and Solutions

| Error Message | Solution |
|---------------|----------|
| `InvalidGrammar: Expected 'in' after expression` | Replace `dict.has(key)` with `key in dict` |
| `Cannot convert X to boolean` | Use explicit `bool()` conversion |
| `Cannot call parent class virtual function` | Fix extends statement to use file path |
| `Error calling inst_to_dict: Not based on resource file` | Add valid resource_path to resource |
| `Another resource is loaded from path` | Use unique resource paths with timestamps |
| `Could not resolve class` | Use file path in extends instead of class name |
| `Invalid call. Nonexistent function 'new' in base 'GDScript'` | Use compatibility layer for GDScript instances |

## Running GUT from Command Line

For automated testing and CI/CD integration, use the command line interface:

```bash
# Basic command to run all tests
godot -s addons/gut/gut_cmdln.gd -d --path "$PWD" -gexit

# Run specific directory of tests
godot -s addons/gut/gut_cmdln.gd -d --path "$PWD" -gdir=res://tests/unit -gexit

# Run with specific log level (1-3)
godot -s addons/gut/gut_cmdln.gd -d --path "$PWD" -glog=3 -gexit

# Run specific test script
godot -s addons/gut/gut_cmdln.gd -d --path "$PWD" -gtest=res://tests/unit/test_specific.gd -gexit
```

### Config File for Command Line Testing

Create a `.gutconfig.json` file in your project root to simplify command-line options:

```json
{
  "dirs":["res://tests/unit/","res://tests/integration/"],
  "double_strategy":"partial",
  "ignore_pause":false,
  "include_subdirs":true,
  "inner_class":"",
  "log_level":3,
  "opacity":100,
  "prefix":"test_",
  "selected":"",
  "should_exit":true,
  "should_maximize":true,
  "suffix":".gd",
  "tests":[],
  "unit_test_name":""
}
```

## Memory Management in GUT

GUT will report orphaned objects after tests run, which appear as:

```
ERROR: ~List: Condition "_first != __null" is true.
   At: ./core/self_list.h:112.
WARNING: cleanup: ObjectDB Instances still exist!
   At: core/object.cpp:2071.
ERROR: clear: Resources Still in use at Exit!
   At: core/resource.cpp:476.
```

### Using GUT's Memory Management Helpers

Our base test classes extend GUT's built-in memory management:

```gdscript
# Use these methods in your tests
var my_node = add_child_autofree(MyNode.new())  # Adds to tree and frees after test
var my_resource = track_test_resource(MyResource.new())  # Tracks resource for cleanup
```

For older nodes:
```gdscript
# Will be freed after test
autofree(node)  

# Will be queue_freed after test
autoqfree(node)
```

### TypeSafeMixin Integration

Our `TypeSafeMixin` class works seamlessly with `GutCompatibility`:

```gdscript
const TypeSafeMixin = preload("res://tests/fixtures/helpers/type_safe_test_mixin.gd")
const GutCompatibility = preload("res://addons/gut/compatibility.gd")

# In your test
func test_example():
    var obj = TestedClass.new()
    obj = GutCompatibility.ensure_resource_path(obj)
    track_test_resource(obj)
    
    # Use TypeSafeMixin for method calls
    const TypeSafeMixin = preload("res://tests/fixtures/helpers/type_safe_test_mixin.gd")
    var result = TypeSafeMixin._call_node_method_vector2(obj, "get_position", [], Vector2.ZERO)
    assert_vector2_approx_eq(result, Vector2(10, 20))
```

## Conclusion

By following these manual steps and preventative guidelines, you can ensure your tests remain functional across Godot 4.4 updates.

For questions or issues with GUT testing in our project, please contact the core engineering team. 