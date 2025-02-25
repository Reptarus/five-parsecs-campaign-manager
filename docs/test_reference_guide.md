# Test Structure Quick Reference Guide

## Test Hierarchy

```
GutTest
└── BaseTest
    └── GameTest
        ├── UITest - For UI component tests
        ├── BattleTest - For battle system tests
        ├── CampaignTest - For campaign system tests
        ├── MobileTest - For mobile-specific tests
        └── EnemyTest - For enemy-specific tests
```

## Which Base Class Should I Use?

Use this decision tree to determine which test base class to extend:

1. Are you testing a UI component? → UITest
2. Are you testing battle mechanics? → BattleTest
3. Are you testing campaign features? → CampaignTest
4. Are you testing mobile-specific features? → MobileTest
5. Are you testing enemy behavior? → EnemyTest
6. None of the above? → GameTest

## File Structure

```
tests/
├── fixtures/
│   ├── base/
│   │   ├── base_test.gd
│   │   └── game_test.gd
│   └── specialized/
│       ├── ui_test.gd
│       ├── battle_test.gd
│       ├── campaign_test.gd
│       ├── mobile_test.gd
│       └── enemy_test.gd
├── unit/[domain]/
├── integration/[domain]/
└── performance/[domain]/
```

## Extension Syntax

```gdscript
@tool
extends "res://tests/fixtures/specialized/battle_test.gd"
```

## Test File Template

```gdscript
@tool
extends "res://tests/fixtures/specialized/battle_test.gd"

## Feature Test Suite
##
## Tests the functionality of XYZ

# Type-safe script references
const TestedClass: GDScript = preload("res://path/to/tested/class.gd")

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

func test_feature() -> void:
	# Given
	watch_signals(_instance)
	
	# When
	TypeSafeMixin._safe_method_call_bool(_instance, "method", [])
	
	# Then
	verify_signal_emitted(_instance, "signal_name")
```

## Common Patterns

### Type Safety

Always use type-safe method calls:

```gdscript
# Instead of:
instance.method(params)

# Use:
TypeSafeMixin._safe_method_call_bool(instance, "method", [params])
```

### Signal Testing

```gdscript
watch_signals(instance)
TypeSafeMixin._safe_method_call_bool(instance, "method", [])
verify_signal_emitted(instance, "signal_name")
```

### Resource Tracking

```gdscript
var node := Node.new()
add_child_autofree(node)
track_test_node(node)

var resource := Resource.new()
track_test_resource(resource)
```

### Performance Testing

```gdscript
func test_performance() -> void:
	var metrics := await measure_performance(func(): do_operation())
	assert_gt(metrics.average_fps, 30.0, "FPS should be above 30")
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