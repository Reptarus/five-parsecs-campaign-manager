# Five Parsecs Campaign Manager Tests

This directory contains the test suite for the Five Parsecs Campaign Manager project. We use GUT (Godot Unit Test) framework for testing.

## Structure

- `test_suite.gd`: Main test suite with core system tests
- `test_battlefield_generator.gd`: Tests for battlefield generation
- `test_runner.tscn`: Scene for running tests in Godot
- `gut_config.json`: GUT configuration file

## Running Tests

1. Open the project in Godot
2. Enable the GUT plugin in Project Settings > Plugins
3. Open the test runner scene (`test_runner.tscn`)
4. Click the "Play Scene" button or press F6

## Writing Tests

1. Create a new script in the `tests` directory
2. Name it `test_*.gd` where * is the feature you're testing
3. Extend `GutTest`
4. Add test functions prefixed with `test_`
5. Use assertions from GUT framework

Example:
```gdscript
extends GutTest

func test_my_feature():
    assert_true(true, "This test should pass")
```

## Available Assertions

- `assert_true(value, message="")`
- `assert_false(value, message="")`
- `assert_eq(got, expected, message="")`
- `assert_ne(got, not_expected, message="")`
- `assert_gt(got, expected, message="")`
- `assert_lt(got, expected, message="")`
- `assert_between(got, expect_low, expect_high, message="")`
- `assert_null(got, message="")`
- `assert_not_null(got, message="")`

## Best Practices

1. Keep tests focused and atomic
2. Use descriptive test names
3. Clean up resources in `after_each()` or `after_all()`
4. Group related tests in the same file
5. Use setup methods (`before_all()`, `before_each()`) for common initialization 