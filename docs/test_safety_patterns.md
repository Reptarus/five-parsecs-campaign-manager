# Test Safety Patterns

This document outlines the test safety patterns and best practices used in the Five Parsecs Campaign Manager project.

## Type-Safe Method Calls

### Base Pattern

All test files should extend either:
- `res://tests/fixtures/game_test.gd` (for general game tests)
- `res://tests/fixtures/enemy_test.gd` (for enemy-specific tests)

These base classes provide type-safe methods for interacting with objects under test.

### Available Methods

Instead of using `TypeSafeMixin` directly, use these inherited methods:

```gdscript
# Boolean methods
_call_node_method_bool(obj: Object, method: String, args: Array = []) -> bool

# Integer methods
_call_node_method_int(obj: Object, method: String, args: Array = []) -> int

# Float methods
_call_node_method_float(obj: Object, method: String, args: Array = []) -> float

# String methods
_call_node_method_string(obj: Object, method: String, args: Array = []) -> String

# Dictionary methods
_call_node_method_dict(obj: Object, method: String, args: Array = []) -> Dictionary

# Array methods
_call_node_method_array(obj: Object, method: String, args: Array = []) -> Array

# Generic variant method
_call_node_method(obj: Object, method: String, args: Array = []) -> Variant
```

### Example Usage

```gdscript
# ❌ Don't use TypeSafeMixin directly
var result = TypeSafeMixin._safe_method_call_bool(enemy, "can_attack", [])

# ✅ Use inherited methods instead
var result = _call_node_method_bool(enemy, "can_attack", [])
```

## Property Access

Use these methods for safe property access:

```gdscript
# Get property safely
_get_property_safe(obj: Object, property: String, default_value: Variant = null) -> Variant

# Set property safely
_set_property_safe(obj: Object, property: String, value: Variant) -> void
```

## Node Management

### Node Creation and Cleanup

```gdscript
# Create and track a test node
var node = Node.new()
add_child_autofree(node)  # Will be automatically freed
track_test_node(node)     # For tracking in tests

# Create and track a test resource
var resource = Resource.new()
track_test_resource(resource)  # For tracking in tests
```

### Signal Handling

```gdscript
# Watch signals
_signal_watcher.watch_signals(node)

# Verify signal emission
verify_signal_emitted(node, "signal_name")

# Wait for async signals
var signal_emitted = await assert_async_signal(node, "signal_name", timeout)
```

## Test Structure Best Practices

### 1. Type-Safe Instance Variables

```gdscript
# Declare instance variables with explicit types
var game_state_manager: GameStateManager = null
var _test_game_state: Node = null
```

### 2. Proper Setup and Teardown

```gdscript
func before_each() -> void:
    await super.before_each()
    # Initialize test components
    # Add type checks and error handling

func after_each() -> void:
    # Clean up in reverse order
    # Clear references
    await super.after_each()
```

### 3. Error Handling

```gdscript
# Always check initialization
if not node:
    push_error("Failed to create node")
    return

# Verify critical operations
var added_node := add_child_autofree(node)
if not added_node:
    push_error("Failed to add node to scene tree")
    return
```

### 4. State Verification

```gdscript
# Verify object state
verify_state(node, {
    "is_inside_tree": true,
    "is_processing": true
})

# Verify specific conditions
assert_true(_call_node_method_bool(node, "is_ready"), "Node should be ready")
```

## Integration Test Patterns

### 1. Component Isolation

```gdscript
# Create mock components
var mock_manager = Node.new()
add_child_autofree(mock_manager)
track_test_node(mock_manager)
```

### 2. Async Testing

```gdscript
# Wait for engine stabilization
await stabilize_engine()

# Test async operations
var result = await assert_async_signal(node, "operation_completed")
assert_true(result, "Operation should complete successfully")
```

### 3. Resource Management

```gdscript
# Track and clean up resources
track_test_resource(resource)
_cleanup_tracked_resources()  # Called in after_each
```

## Common Pitfalls to Avoid

1. Never use `TypeSafeMixin` directly in test files
2. Always call `super` methods in `before_each` and `after_each`
3. Don't forget to track nodes and resources
4. Always provide default values for type-safe method calls
5. Handle null checks and error cases explicitly

## Testing Hierarchy

```
GameTest (base class)
├── FiveParsecsEnemyTest (enemy-specific base)
├── Integration Tests
│   ├── test_game_flow.gd
│   ├── test_enemy_combat_integration.gd
│   └── ...
└── Unit Tests
    ├── test_enemy.gd
    ├── test_game_settings.gd
    └── ...
``` 