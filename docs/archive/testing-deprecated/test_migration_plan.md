# Test Migration Plan

This document outlines the plan to migrate existing tests to the standardized test structure.

## Migration Checklist

For each test file, perform the following steps:

1. [ ] Determine the appropriate specialized test base class
2. [ ] Update the `extends` statement 
3. [ ] Verify proper `super.before_each()` and `super.after_each()` calls
4. [ ] Refactor to use specialized helper methods
5. [ ] Fix any linter errors
6. [ ] Update test documentation

## Migration Command

You can use the following Windows command to find all test files:

```cmd
dir /s /b tests\*.gd | findstr "test_"
```

## Migration Order

Priority order for migration:

1. Unit tests with failing linter errors
2. Integration tests with failing linter errors
3. Performance tests with failing linter errors
4. Remaining unit tests
5. Remaining integration tests
6. Remaining performance tests

## Migration Examples

### Before

```gdscript
@tool
extends "res://tests/fixtures/base/game_test.gd"

func test_feature() -> void {
    # Test implementation
}
```

### After

```gdscript
@tool
extends "res://tests/fixtures/specialized/battle_test.gd"

func test_feature() -> void {
    # Test implementation
}
```

## Extension Mapping

Use this mapping to determine which specialized base to use:

| Directory               | Extension Base                                   |
|-------------------------|--------------------------------------------------|
| tests/unit/ui           | "res://tests/fixtures/specialized/ui_test.gd"    |
| tests/unit/battle       | "res://tests/fixtures/specialized/battle_test.gd"|
| tests/unit/campaign     | "res://tests/fixtures/specialized/campaign_test.gd"|
| tests/unit/enemy        | "res://tests/fixtures/specialized/enemy_test.gd" |
| tests/mobile            | "res://tests/fixtures/specialized/mobile_test.gd"|
| Other directories       | "res://tests/fixtures/base/game_test.gd"         |

## Common Issues and Solutions

### Missing Super Calls

**Problem:** `super.before_each()` or `super.after_each()` not called

**Solution:** Add the appropriate calls:

```gdscript
func before_each() -> void:
    await super.before_each()
    # Setup code
}

func after_each() -> void:
    # Cleanup code
    await super.after_each()
}
```

### Path References

**Problem:** Relative paths used in extends

**Solution:** Use absolute paths:

```gdscript
# Instead of:
extends "../../../fixtures/base/game_test.gd"

# Use:
extends "res://tests/fixtures/specialized/battle_test.gd"
```

### Missing Type Safety

**Problem:** Direct method calls without type safety

**Solution:** Use type-safe methods:

```gdscript
# Instead of:
instance.method(params)

# Use:
TypeSafeMixin._safe_method_call_bool(instance, "method", [params])
```

## Verification

After migration, verify:

1. All linter errors are resolved
2. All tests pass
3. Test coverage is maintained or improved

## Timeline

Estimated time for migration: 1-2 days per test directory 