# Five Parsecs Campaign Manager Test Suite

## Test Organization

### Unit Tests (`unit/`)
- `character/`: Character system tests (creation, advancement, stats)
- `combat/`: Combat system tests (battlefield, mechanics, resolution)
- `mission/`: Mission system tests (generation, objectives, rewards)
- `terrain/`: Terrain system tests (generation, features, pathfinding)
- `campaign/`: Campaign system tests (state, progression, resources)
- `core/`: Core system tests (error handling, features)
- `ui/`: UI component tests (panels, controllers, state)
- `equipment/`: Equipment system tests (items, modifications)

### Integration Tests (`integration/`)
- `campaign_flow/`: Campaign phase interactions
- `combat_flow/`: Combat system interactions
- `mission_flow/`: Mission system interactions

### Performance Tests (`performance/`)
- `combat/`: Combat system benchmarks
- `terrain/`: Terrain system benchmarks
- `campaign/`: Campaign system benchmarks

### Mobile Tests (`mobile/`)
Platform-specific testing for mobile devices

### Test Fixtures (`fixtures/`)
- `base_test.gd`: Base test class with common functionality
- `game_test.gd`: Game-specific test utilities
- `mock_data/`: Mock data for testing

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
@tool
extends "res://tests/fixtures/base_test.gd"

## Test class for MyFeature functionality
##
## Tests feature creation, modification, and validation

const MyFeature = preload("res://src/core/my_feature.gd")

var _instance: MyFeature

func before_each() -> void:
    await super.before_each()
    _instance = MyFeature.new()
    add_child(_instance)
    track_test_node(_instance)

func after_each() -> void:
    await super.after_each()
    _instance = null

# Basic Functionality Tests
func test_feature_initialization() -> void:
    assert_not_null(_instance, "Feature should be created")

# Error Condition Tests
func test_invalid_input() -> void:
    assert_false(_instance.process_input(null),
        "Should handle null input gracefully")

# Boundary Tests
func test_value_boundaries() -> void:
    assert_true(_instance.set_value(MIN_VALUE),
        "Should accept minimum value")
```

### Best Practices
1. **Test Organization**
   - Group related tests with comments
   - Use descriptive test names
   - Follow the Arrange-Act-Assert pattern

2. **Resource Management**
   - Use `track_test_node()` for nodes
   - Use `track_test_resource()` for resources
   - Clean up in `after_each()`

3. **Error Handling**
   - Test invalid inputs
   - Test boundary conditions
   - Test error recovery

4. **Documentation**
   - Document test class purpose
   - Add descriptive assertion messages
   - Comment complex test setups

## Test Categories

### Unit Tests
Test individual components in isolation:
- Basic functionality
- Error conditions
- Boundary cases
- Resource management

### Integration Tests
Test component interactions:
- System integration
- State transitions
- Data flow
- Error propagation

### Performance Tests
Benchmark critical systems:
- Operation timing
- Memory usage
- Resource loading
- State transitions

### Mobile Tests
Platform-specific testing:
- Touch input
- Screen adaptation
- Performance
- Platform features

## Reports
Test reports are generated in `tests/reports/`:
- Test results
- Coverage data
- Performance metrics
- Error logs 