# GUT Recovery Guide

This document provides a comprehensive approach to preventing and recovering from issues with the GUT (Godot Unit Testing) plugin in Godot 4.4.

## Quick Recovery Instructions

If your GUT plugin is currently broken, follow these steps in order:

1. **Run the GUT repair tool**:
   ```gdscript
   # From the Godot Editor menu:
   Editor > Run Script... > tools/gut_repair.gd
   ```

2. **Delete corrupted scene files** (if identified by the repair tool):
   ```bash
   # In your project directory:
   rm addons/gut/gui/OutputText.tscn
   rm addons/gut/gui/RunResults.tscn
   rm addons/gut/gui/GutBottomPanel.tscn
   ```

3. **Delete .uid files** in the GUT plugin directory:
   ```bash
   # In your project directory:
   find addons/gut -name "*.uid" -delete
   ```

4. **Restart Godot** and let it rebuild the deleted scene files.

5. **Re-enable the GUT plugin** from Project > Project Settings > Plugins.

## Common Error Patterns and Solutions

### 1. Missing Functions in Scripts

**Error Pattern**:
```
ERROR: Static function "_call_node_method_vector2()" not found in base "res://tests/fixtures/helpers/type_safe_test_mixin.gd"
ERROR: Static function "_call_node_method_float()" not found in base "res://tests/fixtures/helpers/type_safe_test_mixin.gd"
```

**Solution**:
- Our newly created `GutCompatibility` class provides these missing functions
- Import the compatibility class in your test files:
  ```gdscript
  const GutCompatibility = preload("res://tests/fixtures/helpers/gut_compatibility.gd")
  ```
- Replace direct calls with compatibility calls:
  ```gdscript
  # Before:
  _call_node_method_vector2(instance, "get_position")
  
  # After:
  GutCompatibility._call_node_method_vector2(instance, "get_position")
  ```

### 2. Dictionary Method Errors

**Error Pattern**:
```
ERROR: Function "has()" not found in base self
ERROR: Invalid access to property or key 'double_strategy' on a base object of type 'Dictionary'
```

**Solution**:
- Replace dictionary `has()` method with the `in` operator:
  ```gdscript
  # Before:
  if dictionary.has("key"):
      # Do something
  
  # After:
  if "key" in dictionary:
      # Do something
  ```
- For easier maintenance, use our compatibility helper:
  ```gdscript
  if GutCompatibility.dict_has_key(dictionary, "key"):
      # Do something
  ```

### 3. GDScript utility 'new' Function Errors

**Error Pattern**:
```
ERROR: Invalid call. Nonexistent function 'new' in base 'GDScript'
```

**Solution**:
- Replace direct `GDScript.new()` calls with our safe creator:
  ```gdscript
  # Before:
  var instance = SomeScript.new()
  
  # After:
  var instance = GutCompatibility.safe_new("res://path/to/SomeScript.gd")
  ```

### 4. Scene File Corruption

**Error Pattern**:
```
ERROR: Unicode parsing error, some characters were replaced with � (U+FFFD): NUL character
```

**Solution**:
- The GUT panel scene files may become corrupted
- Delete the corrupted scenes and let Godot rebuild them:
  ```bash
  rm addons/gut/gui/OutputText.tscn
  rm addons/gut/gui/RunResults.tscn
  rm addons/gut/gui/GutBottomPanel.tscn
  ```

### 5. UID File Conflicts

**Problem**:
The numerous `.uid` files in the `addons/gut` directory can cause conflicts when Godot tries to reload the plugin.

**Solution**:
- Delete all `.uid` files in the GUT plugin directory:
  ```bash
  find addons/gut -name "*.uid" -delete
  ```

### 6. Autoload Script Compilation Failures

**Error Pattern**:
```
ERROR: Failed to create an autoload, script 'res://src/core/character/management/CharacterManager.gd' is not compiling
```

**Solution**:
- These scripts likely use dictionary `has()` method that no longer works in Godot 4.4
- Run the gut_repair tool to scan and fix these files automatically

## Preventative Measures

To prevent GUT from breaking in the future, follow these best practices:

### 1. Use the GutSafety Autoload

We've created a GutSafety autoload script that automatically fixes common issues on project startup.

Add it to your project:
1. Go to Project > Project Settings > Autoload
2. Add "res://autoloads/gut_safety.gd" with name "GutSafety"
3. Make sure it's enabled

### 2. Use GutCompatibility in All Test Files

Adopt our compatibility helper throughout your test code:

```gdscript
# At the top of your test files:
const GutCompatibility = preload("res://tests/fixtures/helpers/gut_compatibility.gd")

# When creating resources:
var resource = Resource.new()
resource = GutCompatibility.ensure_resource_path(resource)

# When checking dictionaries:
if GutCompatibility.dict_has_key(dictionary, "key"):
    # Do something

# When calling methods that might return Vector2 or float:
var position = GutCompatibility._call_node_method_vector2(node, "get_position")
var distance = GutCompatibility._call_node_method_float(node, "get_distance")
```

### 3. Use Absolute File Paths in Extends

Always use absolute file paths in all "extends" statements:

```gdscript
# CORRECT:
@tool
extends "res://tests/fixtures/specialized/ui_test.gd"

# AVOID:
@tool
extends UITest
```

### 4. Ensure Resources Have Valid Paths

Always assign valid resource paths to resources before using them:

```gdscript
func before_each():
    # Create resource
    var resource = Resource.new()
    
    # Ensure it has a valid path
    resource = GutCompatibility.ensure_resource_path(resource)
    
    # Now it can be safely used in tests
    track_test_resource(resource)
```

### 5. Use the 'in' Operator for Dictionary Checks

Always use the 'in' operator instead of the 'has()' method:

```gdscript
# CORRECT:
if "key" in dictionary:
    # Use dictionary["key"]

# AVOID:
if dictionary.has("key"):
    # This will fail in Godot 4.4
```

### 6. Monitor Scene File Sizes

Periodically check the size of GUT scene files:

```bash
find addons/gut -name "*.tscn" -size +100k
```

If you find large files (> 100KB), they are likely corrupted and should be deleted.

## Troubleshooting

If GUT continues to break despite these measures:

1. **Check for UID conflicts**: Delete all .uid files in the project
2. **Verify file paths**: Make sure all "extends" statements use absolute paths
3. **Check for dictionary usage**: Search for `.has(` in your scripts
4. **Look for corrupted scenes**: Check scene file sizes
5. **Verify resource paths**: Ensure all resources have valid paths

## Reference: Key Files

Our solution includes the following files:

1. **GutCompatibility Helper**:
   `res://tests/fixtures/helpers/gut_compatibility.gd`

2. **GUT Repair Tool**:
   `res://tools/gut_repair.gd`

3. **GUT Safety Autoload**:
   `res://autoloads/gut_safety.gd`

Use these files to keep GUT running smoothly in Godot 4.4 and beyond. 