# Five Parsecs Campaign Manager: Testing Guide

This guide explains how to use GUT (Godot Unit Testing) with the Five Parsecs Campaign Manager project.

## Table of Contents

1. [Test Structure](#test-structure)
2. [Writing Tests](#writing-tests)
3. [Running Tests](#running-tests)
4. [Resource Safety](#resource-safety)
5. [Godot 4.4 Compatibility](#godot-44-compatibility)
6. [Test Coverage](#test-coverage)
7. [Troubleshooting](#troubleshooting)

## Test Structure

The project's test structure follows a standardized hierarchy:

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

The file structure mirrors the source code structure:

```
tests/
├── unit/                 # Unit tests for individual components
│   ├── character/        # Character system tests
│   ├── campaign/         # Campaign system tests
│   ├── mission/          # Mission system tests
│   ├── ships/            # Ship system tests
│   ├── battle/           # Battle system tests
│   └── ...
├── integration/          # Integration tests between systems
├── fixtures/             # Test fixtures and base classes
├── templates/            # Test templates for creating new tests
├── reports/              # Test reports output directory
└── run_five_parsecs_tests.gd  # Test runner script
```

## Writing Tests

### Test Extension Pattern

Always use explicit file paths for extension:

```gdscript
@tool
extends "res://tests/fixtures/specialized/campaign_test.gd"
```

Do not use class name references:

```gdscript
# AVOID: Using class names directly
@tool
extends CampaignTest
```

### Test Naming Conventions

- **Test Files**: All test files should start with `test_` and end with `.gd`
- **Test Methods**: All test methods should start with `test_`
- **Test Classes**: When using inner classes for tests, use the `Test` prefix

### Basic Test Structure

```gdscript
@tool
extends "res://tests/fixtures/specialized/campaign_test.gd"

# Use explicit preloads for script references
const TestedClass = preload("res://path/to/tested_script.gd")

# Test variables with type annotations
var _instance: Node = null

# Setup - runs before each test
func before_each() -> void:
    # Always call super.before_each() first
    await super.before_each()
    
    # Create an instance of the class being tested
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
    
    # Allow the engine to stabilize
    await stabilize_engine()

# Teardown - runs after each test
func after_each() -> void:
    # Perform your cleanup
    _instance = null
    
    # Always call super.after_each() last
    await super.after_each()

# Test methods
func test_example() -> void:
    # Given-When-Then pattern
    
    # Given
    watch_signals(_instance)
    
    # When - Use type-safe method calls
    var result = TypeSafeMixin._safe_method_call_bool(_instance, "some_method", [])
    
    # Then
    assert_true(result, "Method should return true")
    verify_signal_emitted(_instance, "signal_name")
```

## Running Tests

### From the Editor

1. Open the GUT panel in Godot
2. Select the directories to run tests from
3. Click "Run All" or "Run Selected"

### From Command Line

```bash
godot --headless --script tests/run_five_parsecs_tests.gd
```

### Using the Custom Test Runner

Run the test runner script:

```bash
godot --headless --script tests/run_five_parsecs_tests.gd
```

## Resource Safety

### Preventing inst_to_dict Errors

To prevent errors with `inst_to_dict()` and ensure safe serialization:

1. **Ensure Resources Have Valid Resource Paths**:

```gdscript
# When creating resources
if resource is Resource and resource.resource_path.is_empty():
    resource.resource_path = "res://tests/generated/test_resource_%d.tres" % Time.get_unix_time_from_system()
```

2. **Use Safe Serialization Patterns**:

```gdscript
# Instead of inst_to_dict, copy properties explicitly
var serialized = {}
if resource.has("property_name"):
    serialized["property_name"] = resource.property_name
else:
    serialized["property_name"] = default_value
```

3. **Handle Collection Duplication**:

```gdscript
# When saving arrays or dictionaries, duplicate them
if resource.has("array_property"):
    serialized["array_property"] = resource.array_property.duplicate()
```

4. **Safe Deserialization**:

```gdscript
# Always check input data
if data == null or not data is Dictionary:
    return null
    
# Set properties with defaults
resource.property = data.get("property", default_value)

# Duplicate collections when deserializing
resource.array_property = data.get("array_property", []).duplicate()
```

### Resource Tracking

Always track resources and nodes to ensure proper cleanup:

```gdscript
# For Resources
var resource = Resource.new()
track_test_resource(resource)

# For Nodes
var node = Node.new()
add_child_autofree(node)
track_test_node(node)
```

### Callable Assignment Pattern

Never assign lambdas directly to Resources. Instead:

```gdscript
# Create a script with the methods
var script = GDScript.new()
script.source_code = """
extends Resource

func method_name():
    return 42
"""
script.reload()
resource.set_script(script)
```

## Godot 4.4 Compatibility

### Dictionary Checks

Use the `in` operator instead of `has()`:

```gdscript
# AVOID
if dictionary.has(key):
    # Do something

# USE
if key in dictionary:
    # Do something
```

### Property Existence Checks

Use `has()` to check for property existence:

```gdscript
if object.has("property_name"):
    var value = object.property_name
```

### Type Safety Checks

Always check types before performing operations:

```gdscript
if object is Resource:
    # Resource-specific operations
elif object is Node:
    # Node-specific operations
```

### Method Calls

Use type-safe method calls from the base test classes:

```gdscript
# AVOID
object.method(params)

# USE
TypeSafeMixin._safe_method_call_bool(object, "method", [params])
```

## Test Coverage

We aim for the following coverage goals:

- Core Modules: 90%+ coverage
- Game-specific Modules: 80%+ coverage
- UI Components: 70%+ coverage

Prioritize testing:
1. Core game mechanics that must be accurate
2. Complex logic and calculations
3. Error-prone areas of the codebase

## Troubleshooting

### Common Issues with Solutions

#### 1. inst_to_dict Errors

**Error**: `Error calling GDScript utility function 'inst_to_dict': Not based on a resource file`

**Solutions**:
- Ensure resources have valid resource paths
- Use manual serialization instead of inst_to_dict
- Create resources with proper file paths before serializing

#### 2. Invalid Method Calls

**Error**: `Invalid call. Nonexistent function in base 'Object'`

**Solutions**:
- Check for method existence: `if object.has("method_name")`
- Use type-safe method calls from base classes
- Verify object is valid with `is_instance_valid(object)`

#### 3. Signal Connection Errors

**Error**: `Can't connect signal to nonexistent function`

**Solutions**:
- Use proper signal watching with `watch_signals(object)`
- Verify signal exists with `if object.has_signal("signal_name")`
- Use `verify_signal_emitted()` for clean testing

#### 4. Resource Leaks

**Error**: Memory usage increases over time during tests

**Solutions**:
- Track all resources with `track_test_resource()`
- Use `add_child_autofree()` for nodes
- Clear references in `after_each()`
- Ensure proper cleanup with `await super.after_each()`

#### 5. Mission Object Issues

**Error**: Errors when serializing/deserializing mission objects

**Solutions**:
- Use the serialization safety pattern
- Set valid resource paths on mission objects
- Handle arrays and dictionaries with `duplicate()`
- Use explicit property copying instead of inst_to_dict

## Best Practices for Five Parsecs Tests

1. **Use Explicit Path Extensions**: Always use file paths in extends statements
2. **Test Against Rules**: Ensure tests verify compliance with Five Parsecs From Home rules
3. **Use Realistic Data**: Use realistic game data for testing
4. **Test Edge Cases**: Pay special attention to boundary conditions and edge cases
5. **Performance Testing**: Include performance tests for critical operations
6. **Proper Resource Handling**: Ensure all resources have valid paths and are properly tracked
7. **Type Safety**: Use type annotations and type-safe method calls
8. **Signal Testing**: Use proper signal watching and verification
9. **Given-When-Then**: Structure tests with clear arrange-act-assert patterns
10. **Resource Cleanup**: Always clean up resources in `after_each()` 