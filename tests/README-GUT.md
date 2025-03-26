# Five Parsecs Campaign Manager - GUT Testing Guide

## Introduction

This guide provides information on using GUT (Godot Unit Testing) for the Five Parsecs Campaign Manager project. It covers test structure, best practices, and how to use our standardized testing approach.

## Getting Started

### Test Structure

Our tests follow a standard hierarchy:

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

### Running Tests

1. **Editor Method**:
   - Open your project in Godot
   - Run `tests/run_tests.gd` as an EditorScript

2. **Command Line**:
   ```bash
   godot --script res://tests/run_tests.gd
   ```

### Using the Test Migration Tool

To identify and fix inconsistencies in test files:

1. Open your project in Godot
2. Run `tests/fixtures/test_migration.gd` as an EditorScript
3. Check the generated report in `tests/reports/`

## Writing Tests

### Creating a New Test

1. **Choose the Right Base Class Using File Path References**:
   ```gdscript
   # CORRECT: Use file path reference
   @tool
   extends "res://tests/fixtures/specialized/campaign_test.gd"
   
   # AVOID: Using class names directly
   @tool
   extends CampaignTest
   ```

2. **Select the appropriate specialized class based on test purpose**:
   - UI tests → `extends "res://tests/fixtures/specialized/ui_test.gd"`
   - Battle tests → `extends "res://tests/fixtures/specialized/battle_test.gd"`
   - Campaign tests → `extends "res://tests/fixtures/specialized/campaign_test.gd"`
   - Enemy tests → `extends "res://tests/fixtures/specialized/enemy_test.gd"`
   - Mobile tests → `extends "res://tests/fixtures/specialized/mobile_test.gd"`
   - General tests → `extends "res://tests/fixtures/base/game_test.gd"`

3. **Use the Template**:
   Copy and modify `tests/templates/test_template.gd`

4. **Name Your Test Properly**:
   Follow the naming convention `test_[feature].gd`

### Test Structure

Every test file should follow this structure:

```gdscript
@tool
extends "res://tests/fixtures/specialized/ui_test.gd"  # Use path reference

## Test Suite Name
##
## Description of what's being tested

# Type-safe script references
const TestedClass: GDScript = preload("res://path/to/class.gd")

# Type-safe constants 
const TEST_TIMEOUT: float = 2.0

# Type-safe instance variables
var _instance: Node = null

func before_each() -> void:
    # ALWAYS call super first
    await super.before_each()
    
    # Create and setup the instance
    _instance = TestedClass.new()
    
    # IMPORTANT: Resource path safety check to prevent inst_to_dict errors
    if _instance is Resource and _instance.resource_path.is_empty():
        _instance.resource_path = "res://tests/generated/test_resource_%d.tres" % Time.get_unix_time_from_system()
    
    # Add to tree and track properly
    if _instance is Node:
        add_child_autofree(_instance)
        track_test_node(_instance)
    else:
        track_test_resource(_instance)
        
    await stabilize_engine()

func after_each() -> void:
    # Cleanup
    _instance = null
    
    # ALWAYS call super last
    await super.after_each()

# Group tests by functionality
func test_feature() -> void:
    # Given
    # ... setup ...
    
    # When
    # ... action ...
    
    # Then
    # ... assertion ...
}
```

## Resource Safety

### Preventing inst_to_dict() Errors

A common error in tests is `Error calling GDScript utility function 'inst_to_dict()': Not based on a resource file` which occurs when:

1. GUT tries to stringify an object for test output
2. The object is a resource without a valid resource path
3. inst_to_dict() fails because it requires resources to have valid paths

To prevent this issue:

```gdscript
# Always set a valid resource path for Resources created in tests
if resource is Resource and resource.resource_path.is_empty():
    resource.resource_path = "res://tests/generated/test_resource_%d.tres" % Time.get_unix_time_from_system()
```

When working with mission objects or other complex resources:

```gdscript
# Use explicit property copying instead of inst_to_dict
var serialized = {}
if mission.has("mission_id"): 
    serialized["mission_id"] = mission.mission_id
else:
    serialized["mission_id"] = _generate_mission_id()
    
# For collections, always duplicate
if mission.has("objectives"):
    serialized["objectives"] = mission.objectives.duplicate()
```

### Callable Assignment Pattern

Never assign lambda functions directly to Resources:

```gdscript
# AVOID: Will cause errors
resource.some_method = func(): return 42

# CORRECT: Use a script
var script = GDScript.new()
script.source_code = """
extends Resource

func some_method():
    return 42
"""
script.reload()
resource.set_script(script)
```

## Best Practices

### 1. Type Safety

Always use type-safe method calls and property access:

```gdscript
# INSTEAD OF:
instance.method(args)

# USE:
TypeSafeMixin._safe_method_call_bool(instance, "method", [args])
```

### 2. Resource Management

Properly track and clean up resources:

```gdscript
# For nodes:
add_child_autofree(node)  # Auto-freed on cleanup
track_test_node(node)     # Track for additional safety

# For resources:
track_test_resource(resource)  # Tracked for cleanup
```

### 3. Signal Testing

Use the proper pattern for testing signals:

```gdscript
watch_signals(instance)
TypeSafeMixin._safe_method_call_bool(instance, "method", [])
verify_signal_emitted(instance, "signal_name")
```

### 4. Godot 4.4 Compatibility

For Godot 4.4 compatibility, follow these guidelines:

1. **Dictionary Access**: Use `in` operator instead of `has()`:
   ```gdscript
   # AVOID
   if dictionary.has(key):
       # Do something
   
   # USE
   if key in dictionary:
       # Do something
   ```

2. **Property Access**: Use `has()` to check for property existence:
   ```gdscript
   if object.has("property_name"):
       var value = object.property_name
   ```

3. **Method Calls**: Use type-safe method calls:
   ```gdscript
   # Safe method call pattern
   if object.has("method_name"):
       object.call("method_name", args)
   ```

4. **Object Validity**: Always check if objects are valid:
   ```gdscript
   if is_instance_valid(object):
       # Use object
   ```

### 5. Test Organization

Organize tests according to functionality:

```gdscript
# INITIALIZATION TESTS
# ------------------------------------------------------------------------

func test_initialization() -> void {
    # test code
}

# STATE MANAGEMENT TESTS
# ------------------------------------------------------------------------

func test_state_changes() -> void {
    # test code
}
```

## Common Issues and Solutions

### 1. inst_to_dict Errors

**Error**: `Error calling GDScript utility function 'inst_to_dict': Not based on a resource file`

**Solutions**:
- Ensure resources have valid resource paths
- Use manual serialization with property copying
- Avoid using inst_to_dict directly
- Set resource paths before serializing

### 2. Invalid Method Calls

**Error**: `Invalid call. Nonexistent function in base 'Object'`

**Solutions**:
- Use `has()` to check if methods exist before calling
- Use type-safe method calls
- Verify object is valid before operations

### 3. Signal Connection Errors

**Error**: `Can't connect signal to nonexistent function`

**Solutions**:
- Verify signal exists
- Use watch_signals() for proper testing
- Disconnect signals in after_each()

### 4. Resource Leaks

**Error**: Increasing memory usage during tests

**Solutions**:
- Use add_child_autofree() for nodes
- Track resources with track_test_resource()
- Clear all references in after_each()
- Ensure proper cleanup with await super.after_each()

### 5. Dictionary Method Errors

**Error**: `Invalid call to method 'has' ... expected 1 arguments.`

**Solutions**:
- Replace dictionary.has(key) with key in dictionary
- Update code to match Godot 4.4 syntax

## Debugging Tests

### Using print statements

```gdscript
print_debug("Debug info: ", variable)
gut.p("This only prints during tests: ", variable)
```

### Running a specific test

From the GUT panel, you can:
1. Select a specific test file
2. Click "Run Selected"
3. Use filters to run specific tests

### Fixing hanging tests

If tests get stuck:
1. Check for missing await statements
2. Verify proper signal connections
3. Use timeouts for operations that might not complete

## Test Categories

### Unit Tests

Test individual components in isolation:

```gdscript
func test_component() -> void {
    assert_eq(_instance.value, expected_value)
}
```

### Integration Tests

Test component interactions:

```gdscript
func test_integration() -> void {
    var component_a := ComponentA.new()
    var component_b := ComponentB.new()
    add_child_autofree(component_a)
    add_child_autofree(component_b)
    track_test_node(component_a)
    track_test_node(component_b)
    
    TypeSafeMixin._safe_method_call_bool(
        component_a, "interact_with", [component_b]
    )
    
    assert_true(component_b.was_modified)
}
```

### Performance Tests

Benchmark critical systems:

```gdscript
func test_performance() -> void {
    var metrics := await measure_performance(func(): 
        perform_operation()
    )
    
    verify_performance_metrics(metrics, {
        "average_fps": 30.0,
        "minimum_fps": 20.0,
        "memory_delta_kb": 1024.0
    })
}
```

### Mobile Tests

Platform-specific testing:

```gdscript
func test_touch() -> void {
    var component := UIComponent.new()
    add_child_autofree(component)
    
    simulate_touch(component, Vector2(50, 50))
    verify_signal_emitted(component, "touch_detected")
}
```

## Additional Resources

- [GUT Documentation](https://github.com/bitwes/Gut/wiki)
- [Godot Testing Guide](https://docs.godotengine.org/en/stable/tutorials/scripting/gdscript/gdscript_unit_tests.html) 