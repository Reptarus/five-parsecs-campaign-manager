# Five Parsecs Test Architecture Decisions

This document outlines key architecture decisions for the Five Parsecs Campaign Manager test framework.

## Test Hierarchy

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

## Base Class Selection Guide

Use this decision tree to determine which test base class to extend:

1. Are you testing a UI component? → UITest
2. Are you testing battle mechanics? → BattleTest
3. Are you testing campaign features? → CampaignTest
4. Are you testing mobile-specific features? → MobileTest
5. Are you testing enemy behavior? → EnemyTest
6. None of the above? → GameTest

## File Path Reference Pattern

For test class inheritance, we use explicit file paths rather than class names:

```gdscript
# ALWAYS use file path references:
@tool
extends "res://tests/fixtures/specialized/campaign_test.gd"

# NEVER use class name references:
@tool
extends CampaignTest
```

**Rationale:**
1. Avoids class_name conflicts
2. Makes dependencies explicit and traceable
3. Prevents circular reference issues
4. Ensures proper script loading order
5. Simplifies tool behavior in the editor

## Resource Safety Principles

To ensure tests are reliable when working with resources, we implement these safeguards:

1. **Valid Resource Paths**: All resources created during tests must have valid resource paths
   ```gdscript
   if resource is Resource and resource.resource_path.is_empty():
       var timestamp = Time.get_unix_time_from_system()
       resource.resource_path = "res://tests/generated/%s_%d.tres" % [resource.get_class().to_snake_case(), timestamp]
   ```

2. **Safe Serialization**: Never rely on `inst_to_dict()` for serialization, instead use explicit property copying
   ```gdscript
   var serialized = {}
   if resource.has("property_name"):
       serialized["property_name"] = resource.property_name
   ```

3. **Resource Tracking**: All resources must be tracked for cleanup
   ```gdscript
   track_test_resource(resource)
   ```

## Directory Organization

We organize tests by domain and functionality:

```
tests/
├── fixtures/                # Test utilities and base classes
│   ├── base/              # Core test classes
│   │   ├── base_test.gd   # Base test with core utilities
│   │   └── game_test.gd   # Game-specific test functionality
│   ├── specialized/       # Domain-specific test bases
│   │   ├── ui_test.gd     # UI testing functionality
│   │   ├── battle_test.gd # Battle testing functionality
│   │   ├── campaign_test.gd # Campaign testing functionality
│   │   ├── mobile_test.gd # Mobile testing functionality
│   │   └── enemy_test.gd  # Enemy testing functionality
│   ├── helpers/           # Test helper functions
│   └── scenarios/         # Common test scenarios
├── unit/                  # Unit tests by domain
│   ├── campaign/          # Campaign system tests
│   ├── battle/            # Battle system tests
│   ├── character/         # Character system tests
│   ├── core/              # Core system tests
│   ├── enemy/             # Enemy system tests
│   ├── mission/           # Mission system tests
│   ├── ship/              # Ship system tests
│   ├── terrain/           # Terrain system tests
│   ├── tutorial/          # Tutorial system tests
│   └── ui/                # UI component tests
├── integration/           # Integration tests by domain
│   ├── battle/            # Battle flow tests
│   ├── campaign/          # Campaign flow tests
│   ├── core/              # Core system integration
│   ├── enemy/             # Enemy system integration
│   ├── game/              # Game flow tests
│   ├── mission/           # Mission flow tests
│   ├── terrain/           # Terrain system integration
│   └── ui/                # UI flow tests
├── mobile/                # Mobile-specific tests
├── performance/           # Performance benchmarks
├── templates/             # Test templates for creating new tests
└── reports/               # Test reports output directory
```

## Test Categories

### 1. Unit Tests
- Individual component testing
- Minimal dependencies
- Clear state verification
- Type-safe method calls

### 2. Integration Tests
- System interaction testing
- State flow verification
- Resource lifecycle management
- Error handling verification

### 3. Performance Tests
- Resource usage monitoring
- Frame rate verification
- Memory management
- Load time analysis

### 4. Mobile Tests
- Touch input handling
- Screen adaptation
- Platform-specific features

## Test File Naming

All test files follow these naming conventions:

1. **Test Files**: `test_[feature].gd` - where [feature] is the specific feature being tested
2. **Test Methods**: `test_[behavior]` - where [behavior] is the specific behavior being verified
3. **Base Test Files**: `[domain]_test.gd` - where [domain] is the test domain (e.g., ui_test.gd)
4. **Helper Files**: `[purpose]_helper.gd` - where [purpose] is the helper's function

## Standard Test File Template

```gdscript
@tool
extends "res://tests/fixtures/specialized/battle_test.gd"

## Feature Test Suite
##
## Tests the functionality of XYZ

# Type-safe script references
const TestedClass = preload("res://path/to/tested/class.gd")

# Type-safe instance variables
var _instance: Node = null

# Type-safe constants
const TEST_TIMEOUT: float = 2.0

# SETUP AND TEARDOWN
# ------------------------------------------------------------------------

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

func after_each() -> void:
    _instance = null
    await super.after_each()

# INITIALIZATION TESTS
# ------------------------------------------------------------------------

func test_initialization() -> void:
    # Test initialization

# STATE MANAGEMENT TESTS
# ------------------------------------------------------------------------

func test_state_changes() -> void:
    # Given
    watch_signals(_instance)
    
    # When
    TypeSafeMixin._safe_method_call_bool(_instance, "method", [])
    
    # Then
    verify_signal_emitted(_instance, "signal_name")
```

## Common Patterns

### Type-Safe Method Calls

All method calls in tests should be type-safe:

```gdscript
# Instead of direct calls:
instance.method(arg)

# Use type-safe calls:
TypeSafeMixin._safe_method_call_bool(instance, "method", [arg])
```

**Rationale:**
1. Prevents runtime errors if methods don't exist
2. Provides more descriptive error messages
3. Ensures type safety for return values
4. Consistent pattern for method calls

### Signal Testing Pattern

Signal testing follows this pattern:

```gdscript
# Enable signal watching
watch_signals(instance)

# Perform action that should emit signal
TypeSafeMixin._safe_method_call_bool(instance, "method", [])

# Verify signal emission
verify_signal_emitted(instance, "signal_name")

# With parameters
verify_signal_emitted_with_parameters(instance, "signal_name", [param1, param2])
```

### Resource Tracking and Cleanup

All resources created during tests must be properly tracked and cleaned up:

```gdscript
# For nodes:
add_child_autofree(node)  # Auto-freed on cleanup
track_test_node(node)     # Track for additional safety

# For resources:
track_test_resource(resource)  # Tracked for cleanup
```

### Performance Testing

For performance testing:

```gdscript
func test_performance() -> void:
    var metrics := await measure_performance(func(): do_operation())
    assert_gt(metrics.average_fps, 30.0, "FPS should be above 30")
}
```

## Godot 4.4 Compatibility

All tests must follow these Godot 4.4 compatibility patterns:

1. **Dictionary Checks**: Use `in` operator instead of `has()`
   ```gdscript
   if key in dictionary:  # Instead of dictionary.has(key)
       # Do something
   ```

2. **Property Checks**: Use `has()` to check for property existence
   ```gdscript
   if object.has("property_name"):
       var value = object.property_name
   ```

3. **Method Checks**: Use `has_method()` to check for method existence
   ```gdscript
   if object.has_method("method_name"):
       object.method_name()
   ```

4. **Object Validity**: Check if objects are valid
   ```gdscript
   if is_instance_valid(object):
       # Use object
   ```

## Test-Specific Resource Paths

Tests should use specific resource paths to avoid conflicts:

```gdscript
# Resource path for tests
var timestamp = Time.get_unix_time_from_system()
var resource_path = "res://tests/generated/%s_%d.tres" % [test_name, timestamp]
```

## Best Practices

1. Always call `super.before_each()` at the beginning of your `before_each()` method
2. Always call `super.after_each()` at the end of your `after_each()` method
3. Use `add_child_autofree()` for nodes
4. Track test resources with `track_test_resource()`
5. Use descriptive test names
6. Follow the Arrange-Act-Assert pattern (Given-When-Then)
7. Use `assert_*` methods with descriptive messages
8. Use `verify_signal_*` methods to test signals
9. Clean up all resources in `after_each()`
10. Use appropriate timeouts for async operations

## Success Criteria

### 1. Code Quality
- No duplicate declarations
- Type-safe method calls
- Clear inheritance structure
- Documented base functionality

### 2. Test Coverage
- Core systems > 90%
- Integration paths > 80%
- UI components > 85%
- Error handling > 90%

### 3. Performance
- Test suite execution < 2 minutes
- No memory leaks
- Stable frame rate
- Clean resource cleanup

## Future Directions

1. **Automated Coverage Reports**: Implement automatic coverage reporting in CI pipeline
2. **Performance Benchmarking**: Add standard performance benchmarks for critical systems
3. **Visual Testing**: Add support for visual regression testing of UI components
4. **Mobile Test Automation**: Enhance mobile testing capabilities for touch and gestures
5. **Scene Testing**: Improve testing of complex scene hierarchies

## Recent Architectural Improvements

1. **Path-based Inheritance**: Migrated all tests to use file path references for class extension
2. **Resource Safety**: Implemented comprehensive resource safety patterns
3. **Type-Safe Methods**: Added type-safe method call utilities
4. **Signal Testing**: Improved signal watching and verification
5. **Resource Tracking**: Added automatic resource tracking and cleanup
6. **Test Organization**: Standardized test file organization
7. **Godot 4.4 Compatibility**: Updated all tests for Godot 4.4 compatibility 