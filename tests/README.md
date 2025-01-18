# Five Parsecs Campaign Manager Test Suite

## Test Organization
- `unit/`: Individual component tests for isolated functionality
- `integration/`: System interaction tests for component integration
- `performance/`: Performance benchmarks and optimization tests
- `mobile/`: Mobile-specific platform tests
- `fixtures/`: Test data and helper files

## Running Tests

### Via Editor
1. Open the project in Godot
2. Load `tests/run_tests.tscn`
3. Press F6 or click the Play Scene button

### Via Command Line
```bash
godot --script res://tests/run_tests.gd
```

### Via GUT Panel
1. Open the GUT panel in the editor (View -> GUT)
2. Configure test directories if needed
3. Click "Run All"

## Writing Tests

### Test Structure
```gdscript
extends "res://tests/test_base.gd"

func before_each():
    # Setup code runs before each test
    pass

func after_each():
    # Cleanup code runs after each test
    pass

func test_my_feature():
    # Test case
    assert_true(true, "Assertion message")
```

### Best Practices
1. One assertion per test when possible
2. Clear, descriptive test names
3. Use appropriate setup/teardown
4. Mock external dependencies
5. Keep tests independent

## Test Types

### Unit Tests
Test individual components in isolation:
- Character systems
- Campaign mechanics
- Battle resolution
- Resource management

### Integration Tests
Test component interactions:
- Campaign phase transitions
- Battle system integration
- UI state management
- Save/load systems

### Performance Tests
Benchmark critical systems:
- Battle calculations
- Path finding
- Large data operations
- Resource loading

### Mobile Tests
Platform-specific testing:
- Touch input
- Screen resolution
- Performance on mobile
- Platform-specific features

## Fixtures
- Sample game states
- Test characters
- Mock battle scenarios
- Test resources

## Reports
Test reports are generated in `tests/reports/`:
- JUnit XML reports
- Performance benchmarks
- Coverage reports (if enabled) 