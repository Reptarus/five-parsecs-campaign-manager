# Boolean Conversion Fix in GDScript Tests

## Issue Description

Our test suite was experiencing "Cannot convert 0 to boolean" errors when running tests with Godot 4.4. This error occurs because GDScript 2.0 in Godot 4.x has stricter type checking compared to earlier versions.

The issue specifically happens when non-boolean values (like integers or Objects) are implicitly used in boolean contexts, such as:

```gdscript
# This causes type errors if _signal_variable is 0 instead of false
assert_true(_signal_variable, "Signal should be emitted")
```

## Root Cause

In GDScript 2.0, there's no automatic conversion from integer values (0, 1) to booleans (false, true). This is a breaking change from earlier versions where such conversions were implicitly performed.

The test code was written with implicit boolean conversions in mind, assuming that:
- 0 would convert to false
- 1 (or any non-zero value) would convert to true

## Solution

The solution is to explicitly convert any non-boolean values to booleans using the `bool()` constructor:

```gdscript
# Fixed version: Explicitly convert to boolean
assert_true(bool(_signal_variable), "Signal should be emitted")
```

This ensures that the value is properly converted to a boolean type before being used in a boolean context.

## Files Fixed

The following test files have been updated with boolean conversion fixes:

1. `tests/integration/enemy/test_enemy_campaign_flow.gd`
2. `tests/integration/enemy/test_enemy_campaign_integration.gd`

## Common Patterns Requiring Fixes

### 1. Signal Flag Assertions

```gdscript
# Before
assert_true(_signal_received, "Signal should be emitted")

# After
assert_true(bool(_signal_received), "Signal should be emitted")
```

### 2. Method Return Values

```gdscript
# Before
var result = obj.some_method()
assert_true(result, "Method should succeed")

# After
var result = obj.some_method()
assert_true(bool(result), "Method should succeed")
```

### 3. Comparison Results

```gdscript
# Before
assert_true(count > 0, "Count should be positive")
# This is actually fine as the comparison already returns a boolean

# Also fine - these already return booleans
assert_true(obj.has_method("name"), "Object should have method")
assert_true("key" in dictionary, "Dictionary should contain key")
```

## Best Practices

1. Always use explicit `bool()` conversion when asserting non-boolean values
2. For signal flags and method return values that might be integers, always use `bool()`
3. Use the GUT type-safe mixin for better type safety in tests
4. Note that comparisons (>, <, ==, etc.) already return booleans and don't need conversion

By following these guidelines, we can avoid "Cannot convert X to boolean" errors in our test suite. 