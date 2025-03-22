# Five Parsecs Campaign Manager Test Suite

## Current Test Structure

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

## Directory Structure

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
│   ├── campaign/         # Campaign system tests
│   ├── battle/          # Battle system tests
│   ├── character/       # Character system tests
│   ├── core/           # Core system tests
│   ├── enemy/          # Enemy system tests
│   ├── mission/        # Mission system tests
│   ├── ship/           # Ship system tests
│   ├── terrain/        # Terrain system tests
│   ├── tutorial/       # Tutorial system tests
│   └── ui/             # UI component tests
├── integration/          # Integration tests by domain
├── mobile/              # Mobile-specific tests
└── performance/         # Performance benchmarks
```

## Standardized Test File Template

```gdscript
@tool
extends EnemyTest  # Use class_name, not path reference

## Test class for MyFeature functionality
##
## Tests feature creation, modification, and validation

# Type-safe script references
const MyFeature: GDScript = preload("res://src/core/my_feature.gd")

# Type-safe instance variables
var _instance: Node = null

func before_each() -> void:
    await super.before_each()
    _instance = MyFeature.new()
    add_child_autofree(_instance)
    await stabilize_engine(STABILIZE_TIME)

func after_each() -> void:
    _instance = null
    await super.after_each()

func test_feature_initialization() -> void:
    # Given
    assert_not_null(_instance, "Feature should be created")
    
    # When
    watch_signals(_instance)
    TypeSafeMixin._safe_method_call_bool(_instance, "initialize", [])
    
    # Then
    assert_true(_instance.is_initialized)
    verify_signal_emitted(_instance, "initialized")
```

## Base Test Class Selection Guide

When writing a new test, use this guide to select the appropriate base class:

1. UI Component Tests → `extends UITest`
2. Battle System Tests → `extends BattleTest`
3. Campaign System Tests → `extends CampaignTest`
4. Enemy System Tests → `extends EnemyTest`
5. Mobile-Specific Tests → `extends MobileTest`
6. General Game Tests → `extends GameTest`

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

## Running Tests

### Via Editor
1. Open the project in Godot
2. Run `tests/run_tests.gd` as an EditorScript

### Via Command Line
```bash
godot --script res://tests/run_tests.gd
```

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
