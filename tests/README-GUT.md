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

1. **Choose the Right Base Class**:
   - UI tests → `extends UITest`
   - Battle tests → `extends BattleTest`
   - Campaign tests → `extends CampaignTest`
   - Enemy tests → `extends EnemyTest`
   - Mobile tests → `extends MobileTest`
   - General tests → `extends GameTest`

2. **Use the Template**:
   Copy and modify `tests/templates/test_template.gd`

3. **Name Your Test Properly**:
   Follow the naming convention `test_[feature].gd`

### Test Structure

Every test file should follow this structure:

```gdscript
@tool
extends UITest  # Or other appropriate base class

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
    await super.before_each()
    _instance = TestedClass.new()
    add_child_autofree(_instance)
    await stabilize_engine()

func after_each() -> void:
    _instance = null
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

### 4. Test Organization

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

### 5. Given-When-Then Pattern

Structure test methods using the Given-When-Then pattern:

```gdscript
func test_feature() -> void:
    # Given - Setup the test conditions
    var data := _create_test_data()
    
    # When - Perform the action being tested
    var result := TypeSafeMixin._safe_method_call_bool(
        _instance, "process", [data]
    )
    
    # Then - Assert the expected outcomes
    assert_true(result, "Processing should succeed")
}
```

## Test Categories

### Unit Tests

Test individual components in isolation:

```gdscript
func test_component() -> void:
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

## Debugging Tests

### Common Issues

1. **Missing Super Calls**:
   Ensure you call `await super.before_each()` at the beginning of `before_each()` and `await super.after_each()` at the end of `after_each()`.

2. **Resource Leaks**:
   Track all nodes with `add_child_autofree()` and resources with `track_test_resource()`.

3. **Signal Timeouts**:
   Use `watch_signals()` before the action and ensure signals are properly connected.

4. **Test Timeouts**:
   Add `await stabilize_engine()` after setup to ensure the engine has time to process.

### Viewing Test Reports

Test reports are saved to `tests/reports/` and include:
- Test results
- Coverage data
- Performance metrics
- Error logs

## Additional Resources

- [GUT Documentation](https://github.com/bitwes/Gut/wiki)
- [Godot Testing Guide](https://docs.godotengine.org/en/stable/tutorials/scripting/gdscript/gdscript_unit_tests.html) 