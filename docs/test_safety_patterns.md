# Test Safety Patterns

This document outlines the test safety patterns and best practices used in the Five Parsecs Campaign Manager project.

## Test Hierarchy

All test files MUST follow this inheritance hierarchy:

```gdscript
GutTest (from addon/gut/test.gd)
└── BaseTest (from tests/fixtures/base/base_test.gd)
    └── GameTest (from tests/fixtures/base/game_test.gd)
        ├── UITest (from tests/fixtures/specialized/ui_test.gd)
        ├── BattleTest (from tests/fixtures/specialized/battle_test.gd)
        ├── CampaignTest (from tests/fixtures/specialized/campaign_test.gd)
        ├── MobileTest (from tests/fixtures/specialized/mobile_test.gd)
        └── EnemyTest (from tests/fixtures/specialized/enemy_test.gd)
```

### Class Extension Rules

1. ALL test files MUST extend from one of these specialized classes:
   - `UITest` - For UI component tests
   - `BattleTest` - For battle system tests
   - `CampaignTest` - For campaign system tests
   - `MobileTest` - For mobile-specific tests
   - `EnemyTest` - For enemy-specific tests
   - `GameTest` - For general game logic tests (only when no specialized class fits)

2. Use class_name-based extension:
   ```gdscript
   @tool
   extends BattleTest  # Instead of "res://tests/fixtures/specialized/battle_test.gd"
   ```

3. DO NOT create new specialized test classes unless absolutely necessary
4. DO NOT mix inheritance - stick to one specialized class per test file
5. DO NOT extend from raw GutTest, BaseTest or GameTest directly when a specialized class is appropriate

### File Organization

```
tests/
├── fixtures/
│   ├── base/
│   │   ├── base_test.gd      # Core test functionality
│   │   └── game_test.gd      # Game-specific test functionality
│   ├── specialized/
│   │   ├── ui_test.gd        # UI testing functionality
│   │   ├── battle_test.gd    # Battle testing functionality
│   │   ├── campaign_test.gd  # Campaign testing functionality
│   │   ├── mobile_test.gd    # Mobile testing functionality
│   │   └── enemy_test.gd     # Enemy testing functionality
│   ├── helpers/              # Test helper functions
│   └── scenarios/            # Common test scenarios
├── unit/                     # Unit tests
├── integration/              # Integration tests
└── performance/              # Performance tests
```

### Base Class Responsibilities

1. BaseTest (base_test.gd)
   - Core testing utilities
   - Resource tracking and cleanup
   - Signal handling
   - Type safety
   - Engine stabilization

2. GameTest (game_test.gd)
   - Game state management
   - Game-specific assertions
   - Scene tree management
   - Game signal verification
   - Game resource management

3. Specialized Test Classes
   - UITest: UI component testing
   - BattleTest: Battle system testing
   - CampaignTest: Campaign system testing
   - MobileTest: Mobile-specific testing

## Test File Template

Every test file MUST follow this template:

```gdscript
@tool
extends "res://tests/fixtures/base/game_test.gd"  # Or other specialized test base

# Type-safe script references
const TestedClass := preload("res://path/to/tested/class.gd")

# Test constants
const TEST_TIMEOUT := 1.0

# Type-safe instance variables
var _instance: Node
var _dependencies: Array[Node]

func before_each() -> void:
    await super.before_each()
    
    # Initialize test instance
    _instance = TestedClass.new()
    add_child_autofree(_instance)
    
    await stabilize_engine()

func after_each() -> void:
    _instance = null
    await super.after_each()

func test_example() -> void:
    # Given
    watch_signals(_instance)
    
    # When
    var result := _call_node_method_bool(_instance, "some_method")
    
    # Then
    assert_true(result)
    verify_signal_emitted(_instance, "some_signal")
```

## Type Safety Rules

1. Always use type hints for variables and parameters
2. Use type-safe method calls from base classes
3. Use type-safe property access methods
4. Use type-safe signal verification methods

## Resource Management Rules

1. Always use `add_child_autofree()` for nodes
2. Always track resources with `track_test_resource()`
3. Clean up resources in reverse order
4. Use type-safe resource creation methods

## Signal Testing Rules

1. Always use `watch_signals()` before testing signals
2. Use type-safe signal verification methods
3. Verify signal parameters when relevant
4. Use appropriate timeouts for signal waits

## State Management Rules

1. Always use `create_test_game_state()` for game state
2. Verify state with `verify_game_state()`
3. Use `assert_valid_game_state()` after state changes
4. Clean up state in `after_each()`

## Performance Testing Rules

1. Use type-safe performance monitoring
2. Measure FPS, memory, and draw calls
3. Use appropriate stabilization times
4. Clean up after performance tests

## Mobile Testing Rules

1. Use mobile-specific test base class
2. Test multiple screen sizes
3. Verify touch input
4. Test orientation changes

## Best Practices

1. One test file per class/feature
2. Clear test names describing behavior
3. Given-When-Then pattern in tests
4. Clean up all resources
5. Use type-safe methods
6. Verify all signal emissions
7. Test edge cases
8. Test error conditions
9. Use appropriate timeouts
10. Document complex test setups

Remember:
- Keep tests focused and maintainable
- Use descriptive names
- Clean up resources properly
- Monitor performance
- Test edge cases
- Document complex scenarios
``` 