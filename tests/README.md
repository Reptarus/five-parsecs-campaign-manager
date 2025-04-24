# Five Parsecs Campaign Manager - Testing Framework

This directory contains tests for the Five Parsecs Campaign Manager application. The testing framework is designed to ensure code quality, catch regressions, and validate game mechanics against the tabletop rules.

## Test Structure

- `fixtures/`: Base test classes and helper utilities
- `fixtures/helpers/`: Helper functions for common testing patterns
- `unit/`: Fine-grained tests for individual components
- `integration/`: Tests for interactions between multiple components
- `mobile/`: Tests specific to mobile platform functionality
- `performance/`: Tests focused on ensuring game performance

## Godot 4.4 Compatibility

As of Godot 4.4, several key behavior changes affect how tests should be written:

1. Resources must have valid resource paths
2. Method checking using `has_method()` is deprecated; use `has()` instead 
3. Dictionary access patterns have changed
4. Type casting needs to be more explicit

### Using the Compatibility Helper

We've created a `test_compatibility_helper.gd` utility with functions to handle these changes:

```gdscript
# Import the helper
const Compatibility = preload("res://tests/fixtures/helpers/test_compatibility_helper.gd")

# 1. Ensure resources have valid paths
var my_resource = SomeResource.new()
my_resource = Compatibility.ensure_resource_path(my_resource, "test_resource_name")

# 2. Safely check for and call methods
if Compatibility.safe_has_method(some_object, "some_method"):
    # Method exists, call it safely
    var result = Compatibility.safe_call_method(some_object, "some_method", [arg1, arg2], default_value)

# 3. Safely access dictionary values
var value = Compatibility.safe_dict_get(my_dict, "key", default_value)

# 4. Safely connect signals
Compatibility.safe_connect_signal(emitter, "signal_name", callable)
```

## Best Practices

1. **Type Safety**: Always use explicit typing for variables, parameters, and return values.

```gdscript
# Good
var _inventory: Resource = null 
func test_some_feature() -> void:
    var count: int = Compatibility.safe_call_method(_inventory, "get_count", [], 0)
    
# Avoid
var _inventory
func test_some_feature():
    var count = _inventory.get_count()
```

2. **Resource Creation**: Always ensure resources have valid paths.

```gdscript
# Good
var item: Resource = Item.new()
item = Compatibility.ensure_resource_path(item, "test_item")

# Avoid
var item = Item.new() # Missing resource path in Godot 4.4
```

3. **Error Handling**: Use null checks and provide meaningful error messages.

```gdscript
# Good
func _create_test_item() -> Resource:
    if not Item:
        push_error("Item script is null")
        return null
        
    var item: Resource = Item.new()
    if not item:
        push_error("Failed to create test item")
        return null
        
    return Compatibility.ensure_resource_path(item, "test_item")
```

4. **Method Calls**: Use safe method calling patterns.

```gdscript
# Good
Compatibility.safe_call_method(object, "method_name", [arg1, arg2], default_value)

# Avoid direct calls without checking
object.method_name(arg1, arg2)
```

5. **Signal Verification**: Use the built-in signal verification tools.

```gdscript
# Good
watch_signals(object)
Compatibility.safe_call_method(object, "do_something", [])
verify_signal_emitted(object, "signal_name")
```

## Running Tests

Tests can be run using the built-in Godot test runner or automated via CI/CD pipelines. To run tests:

1. Open the project in Godot 4.4
2. Navigate to the test scene or script
3. Use the Godot test runner to execute tests

## Contributing New Tests

When adding new tests:

1. Follow the existing directory structure
2. Use the base test classes for consistency
3. Ensure compatibility with Godot 4.4 using the helper functions
4. Include proper test documentation in comments
5. Test both expected behavior and edge cases

## Documentation

Detailed testing documentation is now maintained in the main documentation directory:

- [Five Parsecs Testing Guide](../docs/five_parsecs_testing_guide.md): Comprehensive guide that consolidates all test architecture, patterns, and best practices
- [GUT Compatibility Guide](../docs/gut_compatibility_guide.md): Complete guide for maintaining compatibility between GUT and Godot 4.4
- [Class Name Registry](../docs/class_name_registry.md): Registry of all class names and how to use them properly

Other reference files:
- [README-GUT.md](README-GUT.md): Original GUT (Godot Unit Testing) reference

## Key Considerations for Testing

### Resource Safety

To prevent common test failures, ensure:

1. All resources have valid resource paths:
   ```gdscript
   if resource is Resource and resource.resource_path.is_empty():
       resource.resource_path = "res://tests/generated/test_resource_%d.tres" % Time.get_unix_time_from_system()
   ```

2. Use safe serialization instead of inst_to_dict:
   ```gdscript
   # Instead of inst_to_dict, copy properties explicitly
   var serialized = {}
   if resource.has("property_name"):
       serialized["property_name"] = resource.property_name
   ```

3. Always track resources for cleanup:
   ```gdscript
   track_test_resource(resource)
   ```

### Godot 4.4 Compatibility

Ensure tests work with Godot 4.4:

1. Use `in` operator instead of `has()` for dictionaries
2. Use proper property access checks with `has()`
3. Verify object validity before operations

## Test Structure

Our tests follow a hierarchical structure:

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

Always extend the appropriate specialized test class using file paths:

```gdscript
@tool
extends "res://tests/fixtures/specialized/campaign_test.gd"
```

## Directory Structure

- `unit/` - Tests for individual components
- `integration/` - Tests for component interactions
- `fixtures/` - Test base classes and utilities
- `templates/` - Templates for creating new tests
- `reports/` - Test reports output

## Creating New Tests

1. Choose the appropriate specialized test class
2. Copy the template from `templates/test_template.gd`
3. Follow the naming convention `test_[feature].gd`
4. Implement proper resource safety measures

## Standardized Test File Template

```gdscript
@tool
extends "res://tests/fixtures/specialized/battle_test.gd"  # Use file path, not class name

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

## Test Base Classes

The project includes specialized base test classes to help with specific test scenarios:

1. UI Component Tests → `extends "res://tests/fixtures/specialized/ui_test.gd"`
2. Battle System Tests → `extends "res://tests/fixtures/specialized/battle_test.gd"`
3. Campaign System Tests → `extends "res://tests/fixtures/specialized/campaign_test.gd"`
4. Enemy System Tests → `extends GutTest` (directly extend GutTest)
5. Mobile-Specific Tests → `extends "res://tests/fixtures/specialized/mobile_test.gd"`

Each base class provides helper methods and setup code specific to those test domains.

## Type Safety Best Practices

Always use type-safe method calls and signal verification:

```gdscript
# Instead of direct calls:
instance.method(arg)

# Use type-safe calls:
TypeSafeMixin._safe_method_call_bool(instance, "method", [arg])

# For signals:
watch_signals(instance)
verify_signal_emitted(instance, "signal_name")
```

## Resource Management

Properly track and clean up resources in all tests:

```gdscript
# For nodes:
add_child_autofree(node)  # Auto-freed on cleanup

# For resources:
track_test_resource(resource)  # Tracked for cleanup
```

## Current Migration Status

We are in the process of standardizing all test files according to the defined hierarchy. The migration includes:

1. Updating extends statements to use class_name-based extension
2. Ensuring proper super.before_each() and super.after_each() calls
3. Refactoring to use type-safe methods
4. Organizing tests according to the standard directory structure

## Test File Organization Guidelines

1. Place tests in domain-specific directories
2. Name files according to the pattern `test_[feature].gd`
3. Group related tests with descriptive comments
4. Follow the Given-When-Then (Arrange-Act-Assert) pattern
5. Use descriptive assertion messages

## Performance Testing

For performance-critical code, include performance tests:

```gdscript
func test_performance() -> void:
    var metrics := await measure_performance(func(): perform_operation())
    verify_performance_metrics(metrics, {
        "average_fps": 30.0,
        "minimum_fps": 20.0,
        "memory_delta_kb": 1024.0
    })
```

## Integration Testing

Integration tests should focus on system interactions:

```gdscript
func test_systems_integration() -> void:
    # Given
    var system_a := SystemA.new()
    var system_b := SystemB.new()
    add_child_autofree(system_a)
    add_child_autofree(system_b)
    
    # When
    watch_signals(system_a)
    TypeSafeMixin._safe_method_call_bool(system_a, "interact_with", [system_b])
    
    # Then
    verify_signal_emitted(system_a, "interaction_complete")
    assert_true(TypeSafeMixin._safe_method_call_bool(system_b, "was_modified", []))
```

## Mobile Testing

Mobile tests should verify touch input and screen adaptation:

```gdscript
func test_touch_interaction() -> void:
    var component := UIComponent.new()
    add_child_autofree(component)
    
    simulate_touch_event(component, Vector2(50, 50))
    verify_signal_emitted(component, "touch_detected")
```

## Test Reports

Test reports are automatically generated in `tests/reports/` with details on:
- Test results
- Coverage data
- Performance metrics
- Error logs 

## Recent Updates

### Test Framework Fixes (July 2023)

We've recently fixed several issues with the test framework:

1. **Path-based inheritance**: All test files now use path-based inheritance instead of class names
   - For example: `extends "res://tests/fixtures/base/game_test.gd"` rather than `extends GameTest`
   
2. **Circular dependency removal**: Eliminated self-reference preloads that were causing circular dependencies
   
3. **Duplicate variable fixes**: Removed duplicate `_gut` variable declarations from base test files

See `fixtures/test_fixes_report.md` for more details about these changes and the automated fixer tool.

## Test Organization

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
