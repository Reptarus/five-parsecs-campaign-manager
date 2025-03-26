# Test File Extends Statement Fixes

## Overview

As described in the Action Plan (Phase 3: Code Architecture Refinement), we've identified issues with the way test files reference their base classes. This document explains the changes needed and provides guidance for fixing all test files.

## Problem

Test files currently use direct class references in extends statements, for example:

```gdscript
extends GameTest
```

This approach causes errors when the class names are removed or when there are conflicts with other classes. The test files should use explicit file paths instead.

## Solution

Replace direct class name references with explicit file paths in all test files:

| Current Pattern | Replacement Pattern |
|-----------------|---------------------|
| `extends GameTest` | `extends "res://tests/fixtures/base/game_test.gd"` |
| `extends BattleTest` | `extends "res://tests/fixtures/specialized/battle_test.gd"` |
| `extends UITest` | `extends "res://tests/fixtures/specialized/ui_test.gd"` |
| `extends CampaignTest` | `extends "res://tests/fixtures/specialized/campaign_test.gd"` |
| `extends EnemyTest` | `extends "res://tests/fixtures/specialized/enemy_test.gd"` |
| `extends MobileTest` | `extends "res://tests/fixtures/specialized/mobile_test.gd"` |

## Test File Locations

The primary test files that need updates are organized in these directories:

1. `tests/unit/` - Unit tests for individual components/systems
2. `tests/integration/` - Integration tests for system interactions
3. `tests/performance/` - Performance tests

## Template Update

The test template (`tests/templates/test_template.gd`) has been updated to use explicit file paths:

```gdscript
@tool
# Choose the appropriate base class for your test
# Replace with one of:
# - extends "res://tests/fixtures/base/game_test.gd" (general game tests)
# - extends "res://tests/fixtures/specialized/ui_test.gd" (UI component tests)
# - extends "res://tests/fixtures/specialized/battle_test.gd" (battle system tests)
# - extends "res://tests/fixtures/specialized/campaign_test.gd" (campaign system tests)
# - extends "res://tests/fixtures/specialized/enemy_test.gd" (enemy system tests)
# - extends "res://tests/fixtures/specialized/mobile_test.gd" (mobile-specific tests)
extends "res://tests/fixtures/base/game_test.gd"

# Use explicit preloads instead of global class names
const TestedClass = preload("res://path/to/class/being/tested.gd")
```

## Manual Fix Examples

Here are examples of files that have been fixed:

1. `tests/unit/campaign/test_patron.gd`
2. `tests/unit/ui/components/combat/test_validation_panel.gd`
3. `tests/integration/battle/test_battle_phase_flow.gd`
4. `tests/unit/mission/test_mission_system.gd`
5. `tests/unit/mission/test_mission_generator.gd`
6. `tests/unit/mission/test_mission_edge_cases.gd`

## Additional Considerations

When updating test files:

1. Add a comment after the extends line: `# Use explicit preloads instead of global class names`
2. Check for any type-related errors that might occur due to removing class_name declarations
3. Update any preload statements to use full paths if they previously relied on global class names
4. Ensure that test resource tracking is properly handled when using explicit paths

## Automation

A PowerShell script (`fix_test_extends.ps1`) has been created to automate these changes, but it should be run with caution and tested thoroughly afterward.

## Verification

After fixing extends statements, verify that:

1. GUT tests run without errors related to missing base classes
2. Test files correctly inherit methods and properties from their parent classes
3. No new script cache errors are introduced 

# Test File Extension Fix Guide

This document provides guidance on fixing test file extension patterns to prevent several common issues, including circular dependencies and resource serialization errors.

## Issue: Class Name vs. File Path Extension

Test files in our codebase should use direct file path references instead of class names in their extends statements:

```gdscript
# PROBLEMATIC: Using class name extension
@tool
extends CampaignTest

# CORRECT: Using file path reference
@tool
extends "res://tests/fixtures/specialized/campaign_test.gd"
```

## Benefits of File Path Extension

Using file path references provides several critical benefits:

1. **Avoids Circular Dependencies**: Prevents circular reference errors when the editor tries to resolve class dependencies.
2. **Improves Serialization**: Helps with proper resource serialization, preventing `inst_to_dict()` errors.
3. **Explicit Dependencies**: Makes dependencies clear and traceable.
4. **Consistent Loading Order**: Ensures scripts load in the correct order.
5. **Editor Tool Support**: Improves reliability when running tests as tool scripts.
6. **Prevents Class Name Conflicts**: Avoids potential class name conflicts across the codebase.
7. **Better Error Messages**: Provides clearer error messages when issues occur.

## Finding Files to Fix

To identify files that need fixing:

```bash
# Find all test files using class name extension
grep -r "extends \(UI\|Battle\|Campaign\|Mobile\|Enemy\|Game\|Base\)Test" --include="*.gd" tests/
```

## Automated Fix Script

We've created a script to automatically fix these issues:

```gdscript
# tests/fixtures/test_file_extends_fix.gd

@tool
extends EditorScript

const BASE_TEST_MAP = {
	"BaseTest": "res://tests/fixtures/base/base_test.gd",
	"GameTest": "res://tests/fixtures/base/game_test.gd",
	"UITest": "res://tests/fixtures/specialized/ui_test.gd",
	"BattleTest": "res://tests/fixtures/specialized/battle_test.gd",
	"CampaignTest": "res://tests/fixtures/specialized/campaign_test.gd",
	"MobileTest": "res://tests/fixtures/specialized/mobile_test.gd",
	"EnemyTest": "res://tests/fixtures/specialized/enemy_test.gd"
}

func _run():
	fix_test_files()

func fix_test_files():
	var test_dir = "res://tests"
	var fixed_count = 0
	var files = find_all_test_files(test_dir)
	
	for file_path in files:
		if fix_file(file_path):
			fixed_count += 1
	
	print("Fixed %d test files" % fixed_count)

func find_all_test_files(dir_path):
	var files = []
	var dir = DirAccess.open(dir_path)
	
	if not dir:
		print("Could not open directory: %s" % dir_path)
		return files
	
	dir.list_dir_begin()
	var file_name = dir.get_next()
	
	while file_name != "":
		var full_path = dir_path + "/" + file_name
		
		if dir.current_is_dir() and file_name != "." and file_name != "..":
			files.append_array(find_all_test_files(full_path))
		elif file_name.ends_with(".gd"):
			files.append(full_path)
		
		file_name = dir.get_next()
	
	return files

func fix_file(file_path):
	var file = FileAccess.open(file_path, FileAccess.READ)
	if not file:
		print("Could not open file: %s" % file_path)
		return false
	
	var content = file.get_as_text()
	file.close()
	
	var pattern = "^extends\\s+(\\w+)\\s*$"
	var regex = RegEx.new()
	regex.compile(pattern)
	
	var fixed_content = ""
	var lines = content.split("\n")
	var fixed = false
	
	for line in lines:
		var result = regex.search(line)
		if result:
			var class_name = result.get_string(1)
			if class_name in BASE_TEST_MAP:
				var file_path = BASE_TEST_MAP[class_name]
				fixed_content += 'extends "%s"' % file_path + "\n"
				fixed = true
				print("Fixed: %s -> %s" % [file_path, line])
			else:
				fixed_content += line + "\n"
		else:
			fixed_content += line + "\n"
	
	if fixed:
		var write_file = FileAccess.open(file_path, FileAccess.WRITE)
		if not write_file:
			print("Could not write to file: %s" % file_path)
			return false
		
		write_file.store_string(fixed_content)
		write_file.close()
		print("Updated file: %s" % file_path)
		return true
	
	return false

## Manual Fix Process

To manually fix a test file:

1. Open the file in your editor
2. Locate the `extends` statement at the top
3. Replace the class name with the appropriate file path:
   - `BaseTest` → `"res://tests/fixtures/base/base_test.gd"`
   - `GameTest` → `"res://tests/fixtures/base/game_test.gd"`
   - `UITest` → `"res://tests/fixtures/specialized/ui_test.gd"`
   - `BattleTest` → `"res://tests/fixtures/specialized/battle_test.gd"`
   - `CampaignTest` → `"res://tests/fixtures/specialized/campaign_test.gd"`
   - `MobileTest` → `"res://tests/fixtures/specialized/mobile_test.gd"`
   - `EnemyTest` → `"res://tests/fixtures/specialized/enemy_test.gd"`
4. Save the file

## Preventing inst_to_dict Errors

Using file path extension helps prevent `inst_to_dict()` errors during testing because:

1. It ensures a cleaner inheritance chain
2. It prevents resources from trying to serialize references to unresolved classes
3. It provides a more predictable object structure for serialization

## Testing After Fixes

After fixing the extends statements:

1. Run the `run_tests.gd` script to verify tests still work
2. Check for any changes in test behavior
3. Watch for errors relating to `inst_to_dict()` or invalid resource paths
4. If errors persist, ensure resources have valid resource paths:

```gdscript
# Ensure resources have valid paths before serialization
if resource is Resource and resource.resource_path.is_empty():
    resource.resource_path = "res://tests/generated/test_resource_%d.tres" % Time.get_unix_time_from_system()
```

## Best Practices Going Forward

For all new test files:

1. Always use file path references in `extends` statements
2. Follow the pattern `extends "res://tests/fixtures/specialized/{domain}_test.gd"`
3. Avoid creating class declarations with `class_name` in test base classes
4. Ensure all tested resources have valid resource paths
5. Use the resource path safety check pattern shown above

## Common Issues

### Circular Dependencies

Using class names can create circular dependencies:
```
ERROR: Circular class reference for class "CampaignTest"
```

### Missing Method Errors

Using class names can cause method resolution issues:
```
Invalid call. Nonexistent function 'stabilize_engine' in base 'Object'
```

### Resource Serialization Errors

Class name extensions can lead to resource serialization errors:
```
Error calling GDScript utility function 'inst_to_dict': Not based on a resource file
```

## Migration Status

Current migration status:
- Unit Tests: X% converted to file path extension
- Integration Tests: Y% converted to file path extension
- Performance Tests: Z% converted to file path extension 

# Five Parsecs Test Migration Guide

This comprehensive guide helps you migrate test files to our standardized structure, focusing on fixing common issues and implementing best practices.

## Quick Migration Checklist

1. [ ] Fix extends statement to use absolute path
2. [ ] Add proper super.before_each() and super.after_each() calls
3. [ ] Replace direct class type references with preloaded script constants
4. [ ] Add proper error handling for async operations
5. [ ] Ensure resources are properly tracked and cleaned up

## File Path Extension Pattern

### The Problem

Test files originally used direct class references in extends statements:

```gdscript
extends GameTest
```

This approach causes errors when:
- Class names are removed
- Conflicts occur with other classes
- Resources need serialization with inst_to_dict() 
- Circular references are created

### The Solution

Replace direct class name references with explicit file paths:

| Current Pattern | Replacement Pattern |
|-----------------|---------------------|
| `extends GameTest` | `extends "res://tests/fixtures/base/game_test.gd"` |
| `extends BattleTest` | `extends "res://tests/fixtures/specialized/battle_test.gd"` |
| `extends UITest` | `extends "res://tests/fixtures/specialized/ui_test.gd"` |
| `extends CampaignTest` | `extends "res://tests/fixtures/specialized/campaign_test.gd"` |
| `extends EnemyTest` | `extends "res://tests/fixtures/specialized/enemy_test.gd"` |
| `extends MobileTest` | `extends "res://tests/fixtures/specialized/mobile_test.gd"` |

### Benefits of File Path Extension

Using file path references provides several critical benefits:

1. **Avoids Circular Dependencies**: Prevents circular reference errors when the editor tries to resolve class dependencies.
2. **Improves Serialization**: Helps with proper resource serialization, preventing `inst_to_dict()` errors.
3. **Explicit Dependencies**: Makes dependencies clear and traceable.
4. **Consistent Loading Order**: Ensures scripts load in the correct order.
5. **Editor Tool Support**: Improves reliability when running tests as tool scripts.
6. **Prevents Class Name Conflicts**: Avoids potential class name conflicts across the codebase.
7. **Better Error Messages**: Provides clearer error messages when issues occur.

## Common Anti-Patterns and Fixes

### 1. Extends Statement Patterns

#### ❌ Problematic Patterns

```gdscript
# Relative path (avoid)
extends "../../../fixtures/base/game_test.gd"

# Global class reference (avoid if class has conflicts)
extends GameTest
```

#### ✅ Correct Pattern

```gdscript
# Absolute path (preferred)
extends "res://tests/fixtures/base/game_test.gd"

# Or for specialized test bases:
extends "res://tests/fixtures/specialized/battle_test.gd"
```

### 2. Super Calls in Lifecycle Methods

#### ❌ Missing Super Calls

```gdscript
func before_each() -> void:
    # Missing super.before_each()
    setup_test_resources()
}

func after_each() -> void:
    cleanup_test_resources()
    # Missing super.after_each()
}
```

#### ✅ Correct Implementation

```gdscript
func before_each() -> void:
    await super.before_each()
    # Custom setup code
}

func after_each() -> void:
    # Custom cleanup code
    await super.after_each()
}
```

### 3. Resource Tracking Patterns

#### ❌ Untracked Resources

```gdscript
func test_creation() -> void:
    var instance = SomeClass.new()
    add_child(instance)
    # Resource not tracked for cleanup
    assert_true(is_instance_valid(instance))
}
```

#### ✅ Proper Resource Tracking

```gdscript
func test_creation() -> void:
    var instance = SomeClass.new()
    add_child_autofree(instance)
    track_test_node(instance)  # Ensure cleanup
    assert_true(is_instance_valid(instance))
}
```

### 4. Class Reference Patterns

#### ❌ Direct Class References

```gdscript
func test_character() -> void:
    var character = Character.new()  # Relies on global class_name
    assert_true(character.is_valid())
}
```

#### ✅ Script Preloading

```gdscript
# At top of file
const CharacterScript = preload("res://src/core/character/Character.gd")

func test_character() -> void:
    var character = CharacterScript.new()
    assert_true(character.is_valid())
}
```

### 5. Async Test Patterns

#### ❌ Unhandled Async

```gdscript
func test_delayed_operation() -> void:
    var result = some_operation_that_returns_signal()
    # Missing await
    assert_true(result)
}
```

#### ✅ Proper Async Handling

```gdscript
func test_delayed_operation() -> void:
    var operation = some_operation_that_returns_signal()
    await operation
    assert_true(operation.is_done())
}
```

### 6. Signal Testing Patterns

#### ❌ Unreliable Signal Testing

```gdscript
func test_signal_emission() -> void:
    var object = TestObject.new()
    var signal_emitted = false
    object.my_signal.connect(func(): signal_emitted = true)
    object.do_something()
    # May fail if signal is emitted asynchronously
    assert_true(signal_emitted)
}
```

#### ✅ Reliable Signal Testing

```gdscript
func test_signal_emission() -> void:
    var object = TestObject.new()
    
    # Create signal watcher
    watch_signals(object)
    
    # Perform action
    object.do_something()
    
    # Verify signal
    verify_signal_emitted(object, "my_signal")
}
```

## Preventing Resource and Serialization Issues

### Resource Path Safety Pattern

To prevent `inst_to_dict()` errors during testing:

```gdscript
# Ensure resources have valid paths before serialization
if resource is Resource and resource.resource_path.is_empty():
    resource.resource_path = "res://tests/generated/test_resource_%d.tres" % Time.get_unix_time_from_system()
```

### Factory Method Pattern

For test data creation, use factory methods with proper tracking:

```gdscript
func create_test_data(value: int = 10) -> Resource:
    var data = preload("res://src/data/SomeResource.gd").new()
    data.value = value
    
    # Ensure valid resource path
    if data.resource_path.is_empty():
        data.resource_path = "res://tests/generated/%s_%d.tres" % [data.get_class(), randi()]
    
    track_test_resource(data)  # Important!
    return data

func test_with_data() -> void:
    var data = create_test_data(10)
    assert_eq(process_data(data), 20)
}
```

## Test File Template

```gdscript
@tool
extends "res://tests/fixtures/specialized/battle_test.gd"  # Use appropriate test base

## Test Suite Name
##
## Tests the functionality of [Feature]

# Type-safe script references
const TestedClass = preload("res://path/to/tested/script.gd")

# Type-safe instance variables
var _instance: Node = null

# Setup - runs before each test
func before_each() -> void:
    await super.before_each()
    
    _instance = TestedClass.new()
    
    # Resource path safety check
    if _instance is Resource and _instance.resource_path.is_empty():
        _instance.resource_path = "res://tests/generated/test_resource_%d.tres" % Time.get_unix_time_from_system()
    
    # Add to tree and track for cleanup
    if _instance is Node:
        add_child_autofree(_instance)
        track_test_node(_instance)
    else:
        track_test_resource(_instance)
    
    await stabilize_engine()

# Teardown - runs after each test
func after_each() -> void:
    _instance = null
    await super.after_each()

# Test methods - organize by functionality
func test_example() -> void:
    # Given
    watch_signals(_instance)
    
    # When
    TypeSafeMixin._safe_method_call_bool(_instance, "some_method", [])
    
    # Then
    assert_true(_instance.property, "Expected property to be true")
    verify_signal_emitted(_instance, "signal_name")
}
```

## Finding Files to Migrate

To identify files that need fixing:

```bash
# Find all test files using class name extension
grep -r "extends \(UI\|Battle\|Campaign\|Mobile\|Enemy\|Game\|Base\)Test" --include="*.gd" tests/
```

For Windows users:
```cmd
dir /s /b tests\*.gd | findstr "test_"
```

## Automated Fix Script

Here's a script to automate the extension fixes:

```gdscript
# tests/fixtures/test_file_extends_fix.gd

@tool
extends EditorScript

const BASE_TEST_MAP = {
	"BaseTest": "res://tests/fixtures/base/base_test.gd",
	"GameTest": "res://tests/fixtures/base/game_test.gd",
	"UITest": "res://tests/fixtures/specialized/ui_test.gd",
	"BattleTest": "res://tests/fixtures/specialized/battle_test.gd",
	"CampaignTest": "res://tests/fixtures/specialized/campaign_test.gd",
	"MobileTest": "res://tests/fixtures/specialized/mobile_test.gd",
	"EnemyTest": "res://tests/fixtures/specialized/enemy_test.gd"
}

func _run():
	fix_test_files()

func fix_test_files():
	var test_dir = "res://tests"
	var fixed_count = 0
	var files = find_all_test_files(test_dir)
	
	for file_path in files:
		if fix_file(file_path):
			fixed_count += 1
	
	print("Fixed %d test files" % fixed_count)

func find_all_test_files(dir_path):
	var files = []
	var dir = DirAccess.open(dir_path)
	
	if not dir:
		print("Could not open directory: %s" % dir_path)
		return files
	
	dir.list_dir_begin()
	var file_name = dir.get_next()
	
	while file_name != "":
		var full_path = dir_path + "/" + file_name
		
		if dir.current_is_dir() and file_name != "." and file_name != "..":
			files.append_array(find_all_test_files(full_path))
		elif file_name.ends_with(".gd"):
			files.append(full_path)
		
		file_name = dir.get_next()
	
	return files

func fix_file(file_path):
	var file = FileAccess.open(file_path, FileAccess.READ)
	if not file:
		print("Could not open file: %s" % file_path)
		return false
	
	var content = file.get_as_text()
	file.close()
	
	var pattern = "^extends\\s+(\\w+)\\s*$"
	var regex = RegEx.new()
	regex.compile(pattern)
	
	var fixed_content = ""
	var lines = content.split("\n")
	var fixed = false
	
	for line in lines:
		var result = regex.search(line)
		if result:
			var class_name = result.get_string(1)
			if class_name in BASE_TEST_MAP:
				var file_path = BASE_TEST_MAP[class_name]
				fixed_content += 'extends "%s"' % file_path + "\n"
				fixed = true
				print("Fixed: %s -> %s" % [file_path, line])
			else:
				fixed_content += line + "\n"
		else:
			fixed_content += line + "\n"
	
	if fixed:
		var write_file = FileAccess.open(file_path, FileAccess.WRITE)
		if not write_file:
			print("Could not write to file: %s" % file_path)
			return false
		
		write_file.store_string(fixed_content)
		write_file.close()
		print("Updated file: %s" % file_path)
		return true
	
	return false
```

## Common Errors and Solutions

| Error | Solution |
|-------|----------|
| "Could not find type X in the current scope" | Use preload instead of class_name |
| "Invalid call. Nonexistent function 'stabilize_engine'" | Ensure the test file extends the proper base class |
| "Invalid await in method 'before_each'" | Add async modifier to method |
| "Cyclic reference detected" | Use load() instead of preload() for circular references |
| "No base test helper found" | Ensure paths are correct in extends statement |
| "Error calling GDScript utility function 'inst_to_dict'" | Ensure resources have valid resource paths |
| "Invalid call to method 'has' in base 'Dictionary'" | Use `in` operator instead of `has()` for dictionaries |

## Handling Inheritance Changes

When changing a script's inheritance from one base class to another:

1. Update all test files that instantiate the script appropriately:
   - For `Resource`-based scripts: 
     ```gdscript
     var obj = load("path/to/script.gd").new()
     track_test_resource(obj)
     ```
   - For `Node`-based scripts:
     ```gdscript
     var obj = Node.new()
     obj.set_script(load("path/to/script.gd"))
     add_child_autofree(obj)
     track_test_node(obj)
     ```

2. Update variable type annotations:
   ```gdscript
   # Before
   var _manager: Resource
   
   # After
   var _manager: Node
   ```

## Verification Steps

After migration, verify:

1. Run the `run_tests.gd` script to verify tests still work
2. Check for any changes in test behavior
3. Watch for errors relating to `inst_to_dict()` or invalid resource paths
4. Verify proper cleanup of resources
5. Check for any warning messages during test execution

## Best Practices Going Forward

1. Always use file path references in `extends` statements
2. Follow the pattern `extends "res://tests/fixtures/specialized/{domain}_test.gd"`
3. Avoid creating class declarations with `class_name` in test base classes
4. Ensure all tested resources have valid resource paths
5. Use the resource path safety check pattern shown above
6. Follow the Given-When-Then pattern in tests
7. Use type-safe method calls
8. Always track resources for cleanup 