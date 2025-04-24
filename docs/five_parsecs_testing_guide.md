# Five Parsecs Testing Guide

This comprehensive guide documents the testing approach, patterns, and best practices used in the Five Parsecs Campaign Manager project. It consolidates our learnings from resolving various issues and establishes standards for writing reliable tests.

## Test Architecture

### Test Hierarchy

We use a hierarchical test structure to organize functionality and reuse common testing code:

```
GutTest (from addon/gut/test.gd)
└── BaseTest (from tests/fixtures/base/base_test.gd)
    └── GameTest (from tests/fixtures/base/game_test.gd)
        ├── UITest (from tests/fixtures/specialized/ui_test.gd)
        ├── BattleTest (from tests/fixtures/specialized/battle_test.gd)
        ├── CampaignTest (from tests/fixtures/specialized/campaign_test.gd)
        ├── MobileTest (from tests/fixtures/specialized/mobile_test.gd)
        └── EnemyTest (from tests/fixtures/specialized/enemy_test.gd)
```

### Base Class Selection Guide

Use this decision tree to determine which test base class to extend:

1. Are you testing a UI component? → UITest
2. Are you testing battle mechanics? → BattleTest
3. Are you testing campaign features? → CampaignTest
4. Are you testing mobile-specific features? → MobileTest
5. Are you testing enemy behavior? → EnemyTest
6. None of the above? → GameTest

## Critical Patterns

### 1. File Path Reference Pattern

Always use explicit file paths rather than class names for test class inheritance:

```gdscript
# CORRECT ✅
@tool
extends "res://tests/fixtures/specialized/campaign_test.gd"

# INCORRECT ❌
@tool
extends CampaignTest
```

**Rationale:**
1. Avoids class_name conflicts
2. Makes dependencies explicit and traceable
3. Prevents circular reference issues
4. Ensures proper script loading order
5. Simplifies tool behavior in the editor

### 2. Resource Safety Patterns

Always ensure resources have valid paths to prevent serialization errors:

```gdscript
# Ensure resources have valid paths
if resource is Resource and resource.resource_path.is_empty():
    var timestamp = Time.get_unix_time_from_system()
    resource.resource_path = "res://tests/generated/%s_%d.tres" % [resource.get_class().to_snake_case(), timestamp]
```

### 3. Resource Tracking and Cleanup

Always track resources for proper cleanup:

```gdscript
# For nodes:
add_child_autofree(node)  # Auto-freed on cleanup
track_test_node(node)     # Track for additional safety

# For resources:
track_test_resource(resource)  # Tracked for cleanup
```

### 4. Type-Safe Method Calls

Use type-safe method calls to prevent runtime errors:

```gdscript
# Instead of direct calls:
instance.method(arg)

# Use type-safe calls:
TypeSafeMixin._safe_method_call_bool(instance, "method", [arg])
```

### 5. Dictionary Access in Godot 4.4

Use the correct dictionary access patterns for Godot 4.4:

```gdscript
# INCORRECT ❌
if dictionary.has("key"):
    value = dictionary["key"]

# CORRECT ✅
if "key" in dictionary:
    value = dictionary["key"]
```

### 6. Proper Lifecycle Methods

Always implement before_each and after_each with super calls:

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

## Standard Test File Template

Use this template for new test files:

```gdscript
@tool
extends "res://tests/fixtures/specialized/battle_test.gd"  # Choose appropriate base

## Feature Test Suite
##
## Tests the functionality of XYZ

# Type-safe script references
const TestedClass = preload("res://path/to/tested/class.gd")

# Type-safe instance variables
var _instance: Node = null

# Setup - runs before each test
func before_each() -> void:
    await super.before_each()
    
    _instance = TestedClass.new()
    
    # Resource path safety check
    if _instance is Resource and _instance.resource_path.is_empty():
        var timestamp = Time.get_unix_time_from_system()
        _instance.resource_path = "res://tests/generated/%s_%d.tres" % [_instance.get_class().to_snake_case(), timestamp]
    
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

## Signal Testing

Use this pattern for validating signals:

```gdscript
# Enable signal watching
watch_signals(instance)

# Perform action that should emit signal
TypeSafeMixin._safe_method_call_bool(instance, "method", [])

# Verify signal emission
verify_signal_emitted(instance, "signal_name")

# With parameters
verify_signal_emitted_with_parameters(instance, "signal_name", [param1, param2])

# For testing signal sequences
var expected_signals = ["signal1", "signal2", "signal3"]
verify_signal_sequence(_received_signals, expected_signals, true)  # true = strict order
```

## Boolean Conversion in Godot 4.4

In Godot 4.4, there's no automatic conversion from integer values to booleans. Use explicit conversion:

```gdscript
# INCORRECT ❌
assert_true(_signal_variable, "Signal should be emitted")

# CORRECT ✅
assert_true(bool(_signal_variable), "Signal should be emitted")
```

## Working with Callables (Functions)

Callables present challenges in Godot 4.4, particularly with serialization. Use this pattern:

```gdscript
# Create a script with methods for a resource
var resource = Resource.new()
var script = GDScript.new()
script.source_code = """
extends Resource

func some_method():
    return 42
"""
script.reload()
resource.set_script(script)

# Ensure the resource has a valid path for serialization
if resource.resource_path.is_empty():
    var timestamp = Time.get_unix_time_from_system()
    resource.resource_path = "res://tests/generated/%s_%d.tres" % [resource.get_class().to_snake_case(), timestamp]

# Then you can safely call the method
var result = resource.some_method()
```

## Preventing GUT Plugin Issues

To prevent issues with the GUT plugin in Godot 4.4:

1. **Use file path references** in extends statements for all test files
2. **Update dictionary access** to use the `in` operator instead of `has()`
3. **Ensure proper resource paths** for all resources
4. **Add proper null checks** for method calls and property access
5. **Use the GutCompatibility helper** for backward compatibility

If GUT breaks, follow these recovery steps:

1. Delete .uid files in the addons/gut directory
2. Check for corrupted scene files (unusually large files > 100KB)
3. Restart Godot and re-enable the GUT plugin

## Common Issues and Solutions

### 1. "Cannot convert 0 to boolean"

```
Cannot convert 0 to boolean
```

**Solution**: Use explicit boolean conversion: `bool(value)`

### 2. "Invalid call to method 'has' in base 'Dictionary'"

```
Invalid call to method 'has' in base 'Dictionary'
```

**Solution**: Replace `dictionary.has("key")` with `"key" in dictionary`

### 3. "Another resource is loaded from path (cyclic resource inclusion)"

```
Another resource is loaded from path (possible cyclic resource inclusion)
```

**Solution**: Use unique resource paths with timestamps and random IDs:
```gdscript
var timestamp = Time.get_unix_time_from_system()
var random_id = randi() % 1000000
script.resource_path = "res://tests/temp/script_%d_%d.gd" % [timestamp, random_id]
```

### 4. "Error calling GDScript utility function 'inst_to_dict'"

```
Error calling GDScript utility function 'inst_to_dict': Not based on a resource file
```

**Solution**: Ensure resources have valid resource paths before serialization

### 5. "Cannot call the parent class' virtual function"

```
Cannot call the parent class' virtual function "before_each()" because it hasn't been defined
```

**Solution**: Use proper file path references in extends statements

## Test Organization

Tests are organized in the following directories:

```
tests/
├── fixtures/                # Test utilities and base classes
│   ├── base/                # Core test classes
│   ├── specialized/         # Domain-specific test bases
│   ├── helpers/             # Test helper functions
│   └── scenarios/           # Common test scenarios
├── unit/                    # Unit tests by domain
├── integration/             # Integration tests by domain
├── performance/             # Performance benchmarks
├── templates/               # Test templates
└── generated/               # Generated test resources
```

## Running Tests

Run tests using one of these methods:

1. **From the editor**: Use the GUT panel
2. **Command line**: `godot -s addons/gut/gut_cmdln.gd -d --path "$PWD" -gdir=res://tests/unit -gexit`
3. **Test runner**: Execute the `run_tests.gd` script

## Best Practices Summary

1. **Always use file path references** in extends statements
2. **Call super methods** in before_each and after_each
3. **Track all resources** with track_test_resource()
4. **Use type-safe method calls** from TypeSafeMixin
5. **Validate signals** with watch_signals() and verify_signal_emitted()
6. **Ensure resources have valid paths** to prevent serialization errors
7. **Use the 'in' operator** for dictionary checks, not has()
8. **Provide explicit boolean conversions** with bool()
9. **Add proper error handling** for async operations
10. **Follow the Given-When-Then pattern** in test methods

By following these guidelines, you'll create reliable, maintainable tests that work consistently with Godot 4.4 and beyond. 