# Five Parsecs Test Framework

A robust testing framework for the Five Parsecs Campaign Manager, designed to make writing tests more reliable with type-safe operations.

## Key Features

- **Type-safe test helpers**: Safely call methods and access properties without crashing
- **Mock objects**: Create mock objects, managers, and UI controls with predefined behaviors
- **Automatic initialization**: Simple setup for all test files
- **Safe error handling**: Prevent test failures due to missing methods or properties

## Getting Started

### Basic Test Structure

```gdscript
@tool
extends "res://tests/fixtures/base/game_test_mock_extension.gd"

# Test resources
var test_component = null

func before_each() -> void:
    await super.before_each()
    
    # Create test component
    test_component = create_mock({
        "get_value": 42,
        "is_enabled": true
    })
    
    await get_tree().process_frame

func test_example() -> void:
    # Use type-safe method calls
    var value = TypeSafeMixin._call_node_method_int(test_component, "get_value")
    var enabled = TypeSafeMixin._call_node_method_bool(test_component, "is_enabled")
    
    assert_eq(value, 42, "Should get the correct value")
    assert_true(enabled, "Component should be enabled")
```

### Creating Mock Objects

```gdscript
# Create a simple mock with static return values
var simple_mock = create_mock({
    "get_health": 100,
    "get_name": "Test Character",
    "is_alive": true
})

# Create a mock with dynamic behavior
var dynamic_mock = create_mock({
    "take_damage": func(amount: int):
        var current_health = dynamic_mock.get_mock_value("health", 100)
        var new_health = max(0, current_health - amount)
        dynamic_mock.set_mock_value("health", new_health)
        return new_health
})

# Create a mock manager
var resource_manager = create_mock_manager("ResourceManager")
```

### Type-Safe Property Access

```gdscript
# Set a property safely
TypeSafeMixin._set_property_safe(object, "property_name", value)

# Get a property with default value if missing
var value = TypeSafeMixin._get_property_safe(object, "property_name", default_value)
```

### Type-Safe Method Calls

```gdscript
# Call method and get properly typed return values
var int_value = TypeSafeMixin._call_node_method_int(object, "method_name", args, default)
var bool_value = TypeSafeMixin._call_node_method_bool(object, "method_name", args, default)
var array_value = TypeSafeMixin._call_node_method_array(object, "method_name", args, default)
var dict_value = TypeSafeMixin._call_node_method_dict(object, "method_name", args, default)
var string_value = TypeSafeMixin._call_node_method_string(object, "method_name", args, default)
```

### UI Testing

```gdscript
# Create a test control
var test_control = create_test_control()

# Make an existing control testable
var testable_control = make_testable(your_control)
```

## Quick Reference

### Mock Provider

- `create_mock_object()`: Creates basic mock object
- `create_mock_control()`: Creates mock UI control
- `create_mock_resource()`: Creates mock resource
- `create_manager_mock(type)`: Creates specialized manager mock
- `fix_missing_methods(object)`: Adds missing methods to object

### Type Safe Mixin

- `_get_property_safe(obj, property, default)`: Safely gets property value
- `_set_property_safe(obj, property, value)`: Safely sets property value
- `_call_node_method(obj, method, args)`: Safely calls method with arguments
- `_call_node_method_int/bool/array/dict/string`: Type-specific method calls
- `_safe_cast_to_string/int/float/array`: Safe type casting
- `mock_method(obj, method_name, return_value)`: Adds mock method to object
- `make_testable(control)`: Makes UI control testable

### Game Test Mock Extension

- `create_mock_manager(manager_type)`: Creates typed manager mock
- `create_test_control()`: Creates testable UI control
- `make_testable(control)`: Makes existing UI control testable
- `auto_fix_node_tree(root)`: Fixes missing methods in node tree
- `create_mock(methods, properties)`: Creates mock with methods and properties
- `create_mock_node(methods)`: Creates Node with mock methods

## Best Practices

1. Use type-safe method calls to prevent crashes from missing methods or unexpected types
2. Mock only what you need to test the specific functionality
3. Add proper cleanup in `after_each()` method
4. Use `await get_tree().process_frame` when testing UI components
5. Use `TypeSafeMixin._call_node_method_*` methods instead of direct calls
6. Provide meaningful default values for all type-safe method calls

## Example Tests

See `tests/examples/test_mock_example.gd` for examples of how to use this framework. 