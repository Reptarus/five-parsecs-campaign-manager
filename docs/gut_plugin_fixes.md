# GUT Plugin Fixes for Godot 4.4

This document outlines the changes made to fix issues with the GUT (Godot Unit Testing) plugin in Godot 4.4.

## Issues Fixed

1. **Scene File Corruption**
   - Deleted and recreated corrupted scene files:
     - `addons/gut/gui/GutBottomPanel.tscn`
     - `addons/gut/gui/OutputText.tscn`
     - `addons/gut/gui/RunResults.tscn`

2. **UID File Conflicts**
   - Deleted all `.uid` files in the `addons/gut` directory

3. **GDScript.new() Usage**
   - Created a compatibility layer in `addons/gut/compatibility.gd` to handle GDScript creation changes in Godot 4.4

4. **Dictionary Method Errors**
   - Fixed `.has()` method calls on dictionaries by replacing them with the `in` operator
   - Created helper functions for dictionary access in the compatibility layer

5. **Missing Methods in Test Files**
   - Added GutCompatibility imports to test files
   - Updated method calls to use GutCompatibility helpers

6. **Null Reference Errors**
   - Added null checks throughout the GUT plugin code
   - Improved error handling for missing nodes and methods

7. **Directory Creation Errors**
   - Created `addons/gut/temp` directory
   - Improved directory creation logic using safer methods

## Files Modified

1. **Core Compatibility**
   - Created `addons/gut/compatibility.gd` with Godot 4.4 compatible functions

2. **Test Files**
   - Updated `tests/unit/battle/ai/test_enemy_state.gd` to use GutCompatibility
   - Updated `tests/unit/enemy/test_enemy_pathfinding.gd` to use GutCompatibility
   - Fixed dictionary access in mission helper files

3. **Plugin Files**
   - Fixed `addons/gut/gui/editor_globals.gd` to safely create directories
   - Fixed `addons/gut/gui/GutBottomPanel.gd` to handle null values and missing methods
   - Created minimal versions of corrupted scene files

4. **Safety Mechanisms**
   - Created `autoloads/gut_safety.gd` to automatically maintain GUT's health
   - Added checks for scene file corruption
   - Added automatic cleanup of problematic .uid files

## How the Fixes Work

### 1. Compatibility Layer

The compatibility layer in `addons/gut/compatibility.gd` provides safe alternatives for:

```gdscript
# Instead of:
var script = GDScript.new()

# We now use:
var script = compatibility.create_gdscript()

# Instead of:
if dict.has("key")

# We now use:
if "key" in dict
```

### 2. Scene Reconstruction

The corrupted scene files were replaced with minimal versions that include just the essential nodes and properties to function correctly.

### 3. Null Safety

All plugin code now has null checks before accessing properties or calling methods:

```gdscript
# Before:
node.call_method()

# After:
if node != null and node.has_method("call_method"):
    node.call_method()
```

### 4. Test File Updates

Test files now import and use the GutCompatibility helper:

```gdscript
const GutCompatibility = preload("res://tests/fixtures/helpers/gut_compatibility.gd")

# Use compatibility methods
var cost = GutCompatibility._call_node_method_float(enemy, "calculate_path_cost", [TEST_END_POS])
```

### 5. Autoload Safety System

The `GutSafety` autoload script provides continuous protection by:
- Checking for corrupted scene files
- Removing problematic .uid files
- Ensuring the temp directory exists

## Usage

1. Add the GutSafety autoload in project settings:
   - Project > Project Settings > Autoload
   - Add "res://autoloads/gut_safety.gd" with name "GutSafety"

2. When importing GUT into new projects:
   - Copy the compatibility.gd file to the new project's addons/gut directory
   - Import the GutCompatibility helper in test files that use _call_node_method_vector2 or _call_node_method_float

## Troubleshooting

If GUT still shows errors after applying these fixes:

1. Delete the scene files again and let Godot recreate them
2. Remove all .uid files from the addons/gut directory
3. Ensure the addons/gut/temp directory exists
4. Re-enable the GUT plugin in Project Settings

## Reference

For more detailed information, see:
- [GUT Recovery Guide](gut_recovery_guide.md)
- [Test Safety Patterns](test_safety_patterns.md) 