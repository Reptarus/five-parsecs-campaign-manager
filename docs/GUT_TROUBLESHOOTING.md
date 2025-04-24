# GUT Troubleshooting Guide

This guide covers common issues that occur with GUT (Godot Unit Testing) in Godot 4.4+ and how to fix them.

## Common Errors and Solutions

### GDScript.new() Error

**Error Message:**
```
ERROR: res://addons/gut/utils.gd:159 - Invalid call. Nonexistent function 'new' in base 'GDScript'.
```

**Cause:**
Godot 4.4 removed the ability to create GDScript instances using `GDScript.new()`.

**Solution:**
1. Make sure the `compatibility.gd` file is properly set up in the GUT addon
2. Create a directory for temporary scripts:
   ```
   mkdir -p addons/gut/temp
   ```
3. Create an empty script file that will be loaded instead of creating new GDScript instances:
   ```
   # In addons/gut/temp/__empty.gd
   extends GDScript
   
   # This is an empty script file used by the compatibility layer
   # to replace GDScript.new() functionality in Godot 4.4
   ```

### GUI Issues with GutBottomPanel

**Error Messages:**
```
ERROR: res://addons/gut/gui/GutBottomPanel.gd:105 - Invalid access to property or key 'hide_settings' on a base object of type 'Nil'.
ERROR: res://addons/gut/gui/gut_config_gui.gd:222 - Invalid access to property or key 'double_strategy' on a base object of type 'Dictionary'.
```

**Solution:**
1. Fix GutBottomPanel.gd to add safe implementations of `hide_settings` and `hide_output_text` functions
2. Make sure to check for null values in `_cfg_ctrls` and other objects
3. If scene files are corrupted, recreate them:
   - GutBottomPanel.tscn
   - OutputText.tscn
   - RunResults.tscn

### Issues with Test Files

**Error Message:**
```
ERROR: Failed parse script res://tests/fixtures/specialized/enemy_test.gd
ERROR: The function signature doesn't match the parent. Parent signature is "create_test_enemy(Variant = <default>) -> CharacterBody2D".
```

**Solution:**
Update the test file function signatures to match the parent class:

```gdscript
# Change this:
func create_test_enemy(enemy_data: Resource = null) -> Node:
    # ...

# To this:
func create_test_enemy(enemy_data: Variant = null) -> CharacterBody2D:
    # ...
```

### .uid Files Causing Issues

**Solution:**
Delete all .uid files in the GUT directory to force Godot to regenerate them:

```
del /s /q addons\gut\*.uid
```

## Node Path Issues in GutBottomPanel

**Error Messages:**
```
ERROR: Node not found: "layout/ControlBar/RunAll" (relative to "...")
ERROR: Node not found: "layout/ControlBar/Shortcuts" (relative to "...")
```

**Solution:**
1. Check that your GutBottomPanel.tscn scene matches the expected node structure
2. Common issues involve node path mismatches between the GutBottomPanel.gd script and the scene file
3. Key node paths that must exist:
   - layout/ControlBar/RunAll
   - layout/ControlBar/Shortcuts
   - layout/ControlBar/Settings
   - layout/ControlBar/RunResultsBtn
   - layout/ControlBar/OutputBtn
   - layout/ControlBar/RunAtCursor
   - layout/RSplit/sc/Settings
   - layout/RSplit/CResults/ControlBar/Light3D
   - layout/RSplit/CResults/TabBar/RunResults
4. If these paths don't match, either fix the scene file or update the script

### GutUserPreferences Errors

**Error Messages:**
```
ERROR: Invalid call. Nonexistent function 'new' in base 'GDScript'.
ERROR: GutUserPreferences could not be created
```

**Solution:**
1. Update the create_user_preferences function in compatibility.gd:
   ```gdscript
   func create_user_preferences(editor_settings):
       # In Godot 4.4, we can't use .new() directly
       if ResourceLoader.exists("res://addons/gut/gui/gut_user_preferences.gd"):
           var script = load("res://addons/gut/gui/gut_user_preferences.gd")
           # Check if we can instantiate the script
           if script and script.can_instantiate():
               var instance = script.new()
               if instance.has_method("setup"):
                   instance.setup(editor_settings)
               return instance
       
       # Create a simple fallback preferences object
       var fallback_prefs = RefCounted.new()
       fallback_prefs.hide_settings = {"value": false}
       fallback_prefs.hide_result_tree = {"value": false}
       fallback_prefs.hide_output_text = {"value": false}
       fallback_prefs.save_it = func(): pass
       
       return fallback_prefs
   ```
2. Create a simplified gut_user_preferences.gd script that works with Godot 4.4

## General Troubleshooting Process

1. **Clean Cache Files**:
   - Delete all .uid files
   - Delete .godot/.mono/metadata directory if using C#
   
2. **Fix Compatibility Issues**:
   - Check that compatibility.gd is properly set up
   - Ensure the temp/__empty.gd file exists
   
3. **Repair GUI Problems**:
   - If GUI elements are broken, check for null checks in all functions
   - Recreate scene files if necessary
   
4. **Test Files**:
   - Update function signatures in test files to match parent class
   - Ensure proper type hints are used

## Preventative Measures

1. Create a `gut_compatibility.gd` script in your tests directory to ensure proper operation
2. Add helper scripts to handle resources and objects in tests
3. Document the Godot version you're using and GUT version
4. Pin the GUT version to a specific tag/commit to prevent unexpected changes

If issues persist, check the [GUT GitHub repository](https://github.com/bitwes/Gut) for the latest updates and compatibility fixes. 