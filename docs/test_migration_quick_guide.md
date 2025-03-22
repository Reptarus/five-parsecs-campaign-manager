# Test Migration Quick Reference Guide

This document provides a practical reference for migrating test files to the standardized test structure, with specific examples and techniques to address common issues.

## Quick Migration Checklist

1. [ ] Fix extends statement to use absolute path
2. [ ] Add proper super.before_each() and super.after_each() calls
3. [ ] Replace direct class type references with preloaded script constants
4. [ ] Add proper error handling for async operations
5. [ ] Ensure resources are properly tracked and cleaned up

## Extends Statement Patterns

### ❌ Problematic Patterns

```gdscript
# Relative path (avoid)
extends "../../../fixtures/base/game_test.gd"

# Global class reference (avoid if class has conflicts)
extends GameTest
```

### ✅ Correct Pattern

```gdscript
# Absolute path (preferred)
extends "res://tests/fixtures/base/game_test.gd"

# Or for specialized test bases:
extends "res://tests/fixtures/specialized/battle_test.gd"
```

## Super Calls in Lifecycle Methods

### ❌ Missing Super Calls

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

### ✅ Correct Implementation

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

## Resource Tracking Patterns

### ❌ Untracked Resources

```gdscript
func test_creation() -> void:
    var instance = SomeClass.new()
    add_child(instance)
    # Resource not tracked for cleanup
    assert_true(is_instance_valid(instance))
}
```

### ✅ Proper Resource Tracking

```gdscript
func test_creation() -> void:
    var instance = SomeClass.new()
    add_child(instance)
    track_test_node(instance)  # Ensure cleanup
    assert_true(is_instance_valid(instance))
}
```

## Class Reference Patterns

### ❌ Direct Class References

```gdscript
func test_character() -> void:
    var character = Character.new()  # Relies on global class_name
    assert_true(character.is_valid())
}
```

### ✅ Script Preloading

```gdscript
# At top of file
const CharacterScript = preload("res://src/core/character/Character.gd")

func test_character() -> void:
    var character = CharacterScript.new()
    assert_true(character.is_valid())
}
```

## Async Test Patterns

### ❌ Unhandled Async

```gdscript
func test_delayed_operation() -> void:
    var result = some_operation_that_returns_signal()
    # Missing await
    assert_true(result)
}
```

### ✅ Proper Async Handling

```gdscript
func test_delayed_operation() -> void:
    var operation = some_operation_that_returns_signal()
    await operation
    assert_true(operation.is_done())
}
```

## Signal Testing Patterns

### ❌ Unreliable Signal Testing

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

### ✅ Reliable Signal Testing

```gdscript
func test_signal_emission() -> void:
    var object = TestObject.new()
    
    # Create signal watcher
    var signal_spy = await watch_signal(object, "my_signal", 1.0)
    
    # Perform action
    object.do_something()
    
    # Wait for and verify signal
    await signal_spy.wait()
    assert_true(signal_spy.was_emitted)
    assert_eq(signal_spy.emit_count, 1)
}
```

## Error Handling

### ❌ Missing Error Handling

```gdscript
func test_operation() -> void:
    var result = potentially_failing_operation()
    assert_not_null(result)
}
```

### ✅ Proper Error Handling

```gdscript
func test_operation() -> void:
    var result
    
    # Use error handler
    run_test_with_error_handling(func():
        result = potentially_failing_operation()
    )
    
    assert_not_null(result)
}
```

## Test Data Creation

### ❌ Direct Resource Creation

```gdscript
func test_with_data() -> void:
    var data = SomeResource.new()
    data.value = 10
    assert_eq(process_data(data), 20)
}
```

### ✅ Factory Methods

```gdscript
func create_test_data(value: int = 10) -> Resource:
    var data = preload("res://src/data/SomeResource.gd").new()
    data.value = value
    track_test_resource(data)  # Important!
    return data

func test_with_data() -> void:
    var data = create_test_data(10)
    assert_eq(process_data(data), 20)
}
```

## Mobile Test Patterns

When testing mobile-specific features:

```gdscript
@tool
extends "res://tests/fixtures/base/mobile_test_base.gd"

func test_responsive_layout() -> void:
    # Set up mobile simulation
    simulate_portrait_orientation()
    
    # Create UI component
    var panel = SomePanelScript.new()
    add_child_autofree(panel)
    
    # Verify it fits screen
    assert_fits_screen(panel)
    
    # Test touch interaction
    var button = panel.get_node("Button")
    assert_touch_target_size(button)
    
    # Simulate touch interaction
    simulate_touch_press(button.global_position + Vector2(10, 10))
    await stabilize_engine()
    simulate_touch_release(button.global_position + Vector2(10, 10))
    
    # Verify expected behavior
    assert_true(panel.button_pressed)
}
```

## Finding Tests to Migrate

Use this Windows command to find all test files:

```cmd
dir /s /b tests\*.gd | findstr "test_"
```

## Common Errors and Solutions

| Error | Solution |
|-------|----------|
| "Could not find type X in the current scope" | Use preload instead of class_name |
| "Invalid call. Nonexistent function 'stabilize_engine'" | Ensure the test file extends the proper base class |
| "Invalid await in method 'before_each'" | Add async modifier to method |
| "Cyclic reference detected" | Use load() instead of preload() for circular references |
| "No base test helper found" | Ensure paths are correct in extends statement |

## Priority Order

Follow this migration order to minimize conflicts:

1. Base test classes
2. Helper test classes
3. Unit tests with failing linter errors
4. Integration tests with failing linter errors
5. Performance tests with failing linter errors
6. Remaining tests

## Validation Steps

After migration, verify:

1. Run the test file in isolation to ensure it passes
2. Run the entire test suite to check for integration issues
3. Verify proper cleanup of resources
4. Check for any warning messages during test execution 

## Handling Inheritance Changes

When changing a script's inheritance from one base class to another (e.g., from `Resource` to `Node` or vice versa), ensure the following steps are taken:

1. Update all test files that instantiate the script to use the correct approach:
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

2. Update variable type annotations in all relevant test files:
   ```gdscript
   # Before
   var _manager: Resource
   
   # After
   var _manager: Node
   ```

3. Update initialization parameters:
   - For Resources, parameters are typically passed to the constructor: 
     ```gdscript
     var obj = load("path/to/script.gd").new(param1, param2)
     ```
   - For Nodes, set properties after creation:
     ```gdscript
     var obj = Node.new()
     obj.set_script(load("path/to/script.gd"))
     obj.property1 = param1
     obj.property2 = param2
     ```

4. Update cleanup methods:
   - Resources should use `track_test_resource()`
   - Nodes should use `add_child_autofree()` and `track_test_node()`

Following these steps ensures that your tests will work correctly after inheritance changes. 