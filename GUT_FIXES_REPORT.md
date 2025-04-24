# GUT Compatibility Fixes for Godot 4.4

## Summary of Issues

GUT (Godot Unit Test) version 9.3.1 has several compatibility issues with Godot 4.4, primarily stemming from changes in the Godot engine:

1. **GDScript.new() Removal**: Godot 4.4 removed the ability to directly instantiate GDScript objects using `GDScript.new()`, which GUT relies on for dynamic script creation.
2. **Dictionary .has() Method Removal**: The `.has()` method was removed from Dictionary, requiring using the `in` operator instead.
3. **Editor Interface Changes**: Changes to the editor interface and plugin system can cause issues when GUT tries to access certain editor resources.
4. **Unicode Parsing Errors**: NUL characters in files cause Unicode parsing errors.
5. **.uid Files**: Cached .uid files can cause issues when upgrading to Godot 4.4.

## Implemented Fixes

### 1. Compatibility Layer (compatibility.gd)

We've enhanced the compatibility.gd file to provide proper alternatives to removed functionality:

- Created a replacement for `GDScript.new()` using an empty script template
- Added safe dictionary access methods to replace the removed `.has()` method
- Implemented proper error handling for all operations
- Added utility methods for ensuring valid resource paths

### 2. Empty Script Template

Created a template script in `addons/gut/temp/__empty.gd` that acts as a replacement for `GDScript.new()`:

```gdscript
@tool
extends GDScript

## This is an empty script file used by the compatibility layer
## to replace GDScript.new() functionality in Godot 4.4
```

### 3. GDScript Polyfill

Added a polyfill script in `addons/gut/temp/gdscript_polyfill.gd` that provides replacements for removed methods:

- `create_script_instance()`: Safely creates script instances
- `dict_has_key()`: Replaces Dictionary.has()
- `object_has_method()`: Safely checks if objects have methods
- Various utility functions for type safety

### 4. Fixed Dynamic GDScript Creation

Updated the `dynamic_gdscript.gd` file to use the template approach instead of direct instantiation:

```gdscript
# For Godot 4.4 compatibility: use the empty script template instead of GDScript.new()
var DynamicScript = null
if ResourceLoader.exists("res://addons/gut/temp/__empty.gd"):
    DynamicScript = load("res://addons/gut/temp/__empty.gd")
else:
    # Fallback for older versions
    DynamicScript = GDScript.new()
```

### 5. Enhanced editor_globals.gd

Improved the `create_temp_directory()` method to handle errors properly and added proper fallbacks:

```gdscript
static func create_temp_directory():
    # Check if directory already exists
    if DirAccess.dir_exists_absolute(temp_directory):
        return
    
    # Create with error handling
    var result = DirAccess.make_dir_recursive_absolute(temp_directory)
    if result != OK:
        push_error("Failed to create temp directory: %s (error: %d)" % [temp_directory, result])
        
        # Try a fallback directory as a last resort
        var fallback_dir = "user://gut_temp"
        result = DirAccess.make_dir_recursive_absolute(fallback_dir)
        if result == OK:
            temp_directory = fallback_dir
            print("Using fallback temp directory: " + fallback_dir)
```

### 6. Fixed User Preferences Handling

Updated the `gut_user_preferences.gd` to use the `in` operator instead of the removed `.has()` method:

```gdscript
func load_it():
    if _settings == null:
        value = default
        return
        
    # Using "in" operator instead of has() for Godot 4.4 compatibility
    if _prefstr() in _settings:
        value = _settings.get_setting(_prefstr())
    else:
        value = default
```

### 7. Automated UID Cleanup

Added code to automatically clean up all `.uid` files in the GUT directory structure to prevent caching issues:

```gdscript
func _clean_uid_files():
    var dir = DirAccess.open("res://addons/gut")
    if !dir:
        return
        
    _clean_directory_uid_files(dir, "res://addons/gut")
```

### 8. Added GUT Safety Autoload

Created/enhanced a GUT Safety autoload that automatically runs at project startup to fix common compatibility issues:

- Creates missing required files
- Ensures directories exist
- Cleans up .uid files
- Identifies and handles corrupted scene files

## How to Verify the Fixes

1. Start Godot and open your project
2. Check the output panel for any remaining GUT-related errors
3. Try running GUT tests via the GUT panel
4. If errors persist, check:
   - That all .uid files have been deleted
   - That the temp directory exists with the required files
   - That any scripts using GDScript.new() have been updated

## Compatibility Guide

For any scripts in your codebase that directly use `GDScript.new()`, replace with this pattern:

```gdscript
var script = null
if ResourceLoader.exists("res://addons/gut/temp/__empty.gd"):
    script = load("res://addons/gut/temp/__empty.gd")
else:
    # Fallback for older versions
    script = GDScript.new()
```

For dictionary `.has()` usage, replace with the `in` operator:

```gdscript
# Old way (doesn't work in 4.4)
if dict.has("key"):
    # ...

# New way (works in 4.4)
if "key" in dict:
    # ...
```

## Further Resources

- [GUT Documentation](https://gut.readthedocs.io/en/latest/)
- [Godot 4.4 Compatibility Guide](https://docs.godotengine.org/en/stable/tutorials/migration/upgrading_to_godot_4_4.html)
- [GUT GitHub Repository](https://github.com/bitwes/Gut)
