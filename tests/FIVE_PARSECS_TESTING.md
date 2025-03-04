# Five Parsecs Campaign Manager: Testing Guide

This guide explains how to use GUT (Godot Unit Testing) with the Five Parsecs Campaign Manager project.

## Table of Contents

1. [Test Structure](#test-structure)
2. [Writing Tests](#writing-tests)
3. [Running Tests](#running-tests)
4. [Test Coverage](#test-coverage)
5. [CI/CD Integration](#cicd-integration)

## Test Structure

The project's test structure mirrors the source code structure:

```
tests/
├── unit/                 # Unit tests for individual components
│   ├── character/        # Character system tests
│   ├── campaign/         # Campaign system tests
│   ├── mission/          # Mission system tests
│   ├── ships/            # Ship system tests
│   ├── battle/           # Battle system tests
│   └── ...
├── integration/          # Integration tests between systems
├── fixtures/             # Test fixtures and mock data
├── templates/            # Test templates for creating new tests
├── reports/              # Test reports output directory
└── run_five_parsecs_tests.gd  # Test runner script
```

## Writing Tests

### Test Naming Conventions

- **Test Files**: All test files should start with `test_` and end with `.gd`
- **Test Methods**: All test methods should start with `test_`
- **Test Classes**: When using inner classes for tests, use the `Test` prefix

### Using Templates

We provide templates to standardize test creation:

1. `tests/templates/five_parsecs_test_template.gd` - Basic template for Five Parsecs tests

To create a new test:

1. Copy the template to the appropriate test directory
2. Rename it according to the naming convention
3. Replace placeholders with actual test code

### Basic Test Structure

```gdscript
@tool
extends "res://addons/gut/test.gd"

# Preload the script being tested
const TestedClass = preload("res://src/path/to/tested_script.gd")

# Test variables
var _instance = null

# Setup - runs before each test
func before_each():
    # Create an instance of the class being tested
    _instance = TestedClass.new()
    add_child_autofree(_instance)
    
    await get_tree().process_frame
    await get_tree().process_frame

# Teardown - runs after each test
func after_each():
    _instance = null
    await get_tree().process_frame

# Test methods
func test_example():
    # Test case implementation
    assert_true(_instance.some_method(), "Method should return true")
```

## Running Tests

### From the Editor

1. Open the GUT panel in Godot
2. Select the directories to run tests from
3. Click "Run All" or "Run Selected"

### From Command Line

```bash
godot --headless --script tests/run_five_parsecs_tests.gd
```

### Using the Custom Test Runner

Run the test runner script:

```bash
godot --headless --script tests/run_five_parsecs_tests.gd
```

This will:
1. Run all tests in the configured directories
2. Generate reports in the tests/reports directory
3. Print a summary of the results

## Test Coverage

We aim for the following coverage goals:

- Core Modules: 90%+ coverage
- Game-specific Modules: 80%+ coverage
- UI Components: 70%+ coverage

Prioritize testing:
1. Core game mechanics that must be accurate
2. Complex logic and calculations
3. Error-prone areas of the codebase

## CI/CD Integration

The test runner is designed to work with CI/CD pipelines. To integrate:

1. Call the test runner script in your CI/CD pipeline
2. Use the exit code to determine if tests passed
3. Archive test reports as artifacts

Example GitHub workflow:

```yaml
name: Run Tests

on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest
    
    steps:
    - uses: actions/checkout@v2
    
    - name: Setup Godot
      uses: josephbmanley/build-godot-action@v1.4.1
      with:
        version: 4.2
        
    - name: Run Tests
      run: godot --headless --script tests/run_five_parsecs_tests.gd
      
    - name: Archive Test Results
      uses: actions/upload-artifact@v2
      with:
        name: test-reports
        path: tests/reports/
```

## Best Practices for Five Parsecs Tests

1. **Test Against Rules**: Ensure tests verify compliance with Five Parsecs From Home rules
2. **Use Realistic Data**: Use realistic game data for testing
3. **Test Edge Cases**: Pay special attention to boundary conditions and edge cases
4. **Performance Testing**: Include performance tests for critical operations
5. **Seed Random Tests**: Use fixed seeds for tests involving randomness

## Mocking Game Components

For testing components that depend on other parts of the system:

```gdscript
# Mock a character
func _create_mock_character():
    var character = Character.new()
    character.id = "mock_id"
    character.name = "Mock Character"
    character.set("morale", 3)
    return character

# Mock data from tables
func _mock_mission_tables():
    return {
        "mission_types": ["Raid", "Defense", "Exploration"],
        "rewards": [{"credits": 100}, {"credits": 200}]
    }
```

## Troubleshooting Common Issues

### Tests Not Finding Scripts

If tests can't find scripts, check:
1. Make sure paths are correct (use `res://` prefix)
2. Check for circular dependencies
3. Ensure the script is preloaded in the test

### Tests Hanging

If tests get stuck:
1. Check for infinite loops
2. Ensure signals are properly connected and disconnected
3. Check for missing await statements

### Random Failures

If tests fail intermittently:
1. Check for timing issues
2. Use fixed random seeds
3. Ensure proper cleanup in `after_each()` 