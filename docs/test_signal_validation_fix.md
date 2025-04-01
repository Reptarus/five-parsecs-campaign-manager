# Signal Validation Fix in Test Code

## Issue

The test suite was experiencing errors related to array access, specifically "Out of bounds get index" errors when trying to validate signal emission order. This occurred because our tests were directly accessing array indices to check signal order without proper bounds checking:

```gdscript
# PROBLEMATIC PATTERN - DO NOT USE
var expected_signals = ["signal_1", "signal_2", "signal_3"]
for i in range(expected_signals.size()):
    # This will fail if _received_signals has fewer items than expected_signals
    assert_eq(_received_signals[i], expected_signals[i])
```

## Solution

We've implemented a more robust signal validation approach with:

1. A utility method in the base `campaign_test.gd` class
2. Safer validation patterns that check array bounds first
3. Better error messages to help debug signal issues

### New Utility Method

The `verify_signal_sequence` method in campaign_test.gd provides a safe way to validate signals:

```gdscript
# Usage:
var expected_signals = ["mission_created", "mission_started", "mission_setup_complete"]
verify_signal_sequence(_received_signals, expected_signals, true) # true = strict order
```

### How It Works

The utility method performs three levels of validation:

1. **Count Check** - Ensures enough signals were received
2. **Presence Check** - Verifies all expected signals exist
3. **Order Check** - Optionally validates the signals appear in correct order

### Benefits

- Prevents array out-of-bounds errors
- Provides detailed error messages
- Consistent validation across all test files
- Optional strict vs. relaxed ordering

## Implementation Details

The implementation is in `tests/fixtures/specialized/campaign_test.gd`:

```gdscript
func verify_signal_sequence(received_signals: Array, expected_signals: Array, strict_order: bool = true) -> bool:
    # Detailed implementation with validation and assertion
    # See the file for full implementation details
```

## Using In Tests

All tests should now use this pattern:

```gdscript
# 1. Wait for signals to be emitted
await timeout_or_signal(emitter, "final_signal", SIGNAL_TIMEOUT) 

# 2. Verify signals using the utility
var expected_signals = ["first_signal", "second_signal", "third_signal"]
verify_signal_sequence(_received_signals, expected_signals)

# 3. Continue with other assertions
```

## About Signal Testing

Remember that signal testing can be affected by:

- Timing issues between signals
- Asynchronous operations
- Unintended signal connections
- Order of signal emissions

When debugging signal issues:
- Use the `print("Received signals: ", _received_signals)` pattern
- Consider using `timeout_or_signal()` with sufficient timeout
- Check that signals are correctly connected and disconnected

By following these patterns, we can create more robust tests that don't fail due to technical errors in the test code itself. 