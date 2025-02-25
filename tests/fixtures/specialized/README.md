# Specialized Test Bases

This directory contains specialized test base classes that extend the core test functionality for specific game systems.

## Available Base Classes

### UITest
Base class for UI-related tests providing:
- UI component testing utilities
- Theme verification
- Responsive layout testing
- Touch input simulation
- Accessibility validation

### BattleTest
Base class for battle-related tests providing:
- Combat system integration
- Turn management
- Battlefield generation
- AI behavior testing
- Damage calculation

### CampaignTest
Base class for campaign-related tests providing:
- Campaign state management
- Mission generation and validation
- Resource tracking
- Story progression testing
- Save/load verification

### MobileTest
Base class for mobile-specific tests providing:
- Touch input simulation
- Screen size adaptation
- Performance benchmarking for mobile
- Battery usage monitoring
- Gesture recognition testing

### EnemyTest
Base class for enemy-related tests providing:
- Enemy state management and validation
- Combat system integration
- Movement and pathfinding tests
- Performance benchmarking
- Mobile-specific testing
- Error handling validation

## Usage

All test files should extend from the appropriate specialized test base:

```gdscript
@tool
extends EnemyTest

func test_enemy_movement() -> void:
    var enemy := create_test_enemy("BASIC")
    add_child_autofree(enemy)
    
    verify_enemy_movement(enemy, Vector2.ZERO, Vector2(100, 100))

func test_enemy_combat() -> void:
    var enemy := create_test_enemy("ELITE")
    var target := Node2D.new()
    add_child_autofree(enemy)
    add_child_autofree(target)
    
    verify_enemy_combat(enemy, target)
```

## Best Practices

1. **Choose the Right Base**
   - Select the specialized base that best matches your test domain
   - Use GameTest only when no specialized base is appropriate
   - Never extend directly from BaseTest or GutTest

2. **Use Specialized Helpers**
   - Each specialized base provides domain-specific helper methods
   - Use these instead of writing custom implementations
   - Contribute new helpers back to the specialized base

3. **Follow Type Safety**
   - Use type hints for all variables
   - Use the type-safe methods provided by base classes
   - Add type annotations to all new methods

4. **Resource Management**
   - Use the specialized base cleanup methods
   - Track all resources appropriately
   - Clean up in after_each()

5. **Documentation**
   - Document test class purpose
   - Add descriptive assertion messages
   - Comment complex test setups

## Adding New Test Files

When adding a new test file:

1. Determine the appropriate specialized base
2. Extend from that base using class_name (not path)
3. Follow the test file template
4. Include super.before_each() and super.after_each() calls
5. Use the specialized helper methods

## Adding New Specialized Bases

Creating new specialized bases should be rare. If needed:

1. Get approval from the tech lead first
2. Extend from GameTest
3. Use class_name for easy extension
4. Add comprehensive documentation
5. Include all standard lifecycle methods
6. Update this README 