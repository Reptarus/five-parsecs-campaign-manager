# Five Parsecs Campaign Manager - Test Suite

This directory contains the test suite for the Five Parsecs Campaign Manager project. The tests are organized into categories and use the GUT (Godot Unit Testing) framework.

## Directory Structure

```
tests/
├── fixtures/          # Test helpers and base classes
├── unit/             # Unit tests for individual components
├── integration/      # Integration tests for system interactions
├── performance/      # Performance and stress tests
├── mobile/          # Mobile-specific tests
├── reports/         # Test execution reports
└── logs/            # Test execution logs
```

## Test Categories

### Unit Tests
- Individual component testing
- Isolated functionality verification
- No external dependencies
- Fast execution

### Integration Tests
- System interaction testing
- Component communication
- State management
- Event propagation

### Performance Tests
- Resource usage monitoring
- Execution time benchmarks
- Memory allocation tracking
- State persistence efficiency

### Mobile Tests
- Touch input validation
- UI scaling verification
- Performance profiling
- Battery impact assessment

## Running Tests

### Command Line
```bash
# Run all tests
godot --script res://tests/fixtures/test_suite.gd

# Run specific category
godot --script res://tests/fixtures/test_suite.gd --category=unit
godot --script res://tests/fixtures/test_suite.gd --category=integration
godot --script res://tests/fixtures/test_suite.gd --category=performance
godot --script res://tests/fixtures/test_suite.gd --category=mobile
```

### Godot Editor
1. Open the project in Godot
2. Select "Run Tests" from the GUT plugin menu
3. Choose test category from the dropdown

## Writing Tests

### Base Test Class
All test scripts should extend the `BaseTest` class:
```gdscript
@tool
extends BaseTest

func test_example() -> void:
    assert_true(true, "This test should pass")
```

### Test Helpers
The `TestHelper` class provides common utilities:
```gdscript
# Create test resources
var mission := TestHelper.create_test_mission()
var character := TestHelper.create_test_character()

# Measure performance
var execution_time := TestHelper.measure_execution_time(func():
    # Code to measure
    pass
)

# Validate data
var errors := TestHelper.validate_mission_data(mission_data)
```

### Performance Monitoring
Enable performance monitoring in your test class:
```gdscript
func before_all() -> void:
    super.before_all()
    _performance_monitoring = true
```

### Resource Management
Track resources for automatic cleanup:
```gdscript
var resource := Resource.new()
_track_test_resource(resource)  # Will be freed after test
```

## Test Reports

Test results are automatically exported to `tests/reports/` when failures occur. Reports include:
- Test execution duration
- Pass/fail counts
- Detailed error messages
- Performance metrics

## Best Practices

1. **Test Organization**
   - One test file per component
   - Clear test names describing behavior
   - Group related tests together

2. **Test Independence**
   - Each test should be self-contained
   - Clean up resources after each test
   - Don't rely on test execution order

3. **Performance Testing**
   - Set clear benchmarks
   - Test with realistic data sizes
   - Monitor resource usage

4. **Mobile Testing**
   - Test on multiple screen sizes
   - Verify touch input behavior
   - Check UI scaling

5. **Documentation**
   - Document test purpose
   - Explain complex test setups
   - Include usage examples

## Contributing

1. Create new tests in appropriate category
2. Follow existing test patterns
3. Update documentation
4. Run full test suite before committing

## Dependencies

- Godot 4.2
- GUT Plugin
- Five Parsecs Core Systems 

## GUT Configuration and Setup

### Installation and Quick Setup
1. Install GUT plugin from AssetLib in Godot 4.2
2. Enable the plugin in Project Settings -> Plugins
3. Restart Godot editor
4. Open the GUT panel from the bottom panel tabs (next to Output, Debugger, etc.)

#### Default Configuration
GUT will automatically detect and use the following standard test structure:
```
your-project/
├── tests/              ← Main test directory
│   ├── unit/          ← Unit tests
│   ├── integration/   ← Integration tests
│   └── performance/   ← Performance tests
```

To use this default structure:
1. Create a `tests` directory in your project root
2. In GUT panel settings:
   - Set Directory 0 to "res://tests/"
   - Enable "Include Subdirs" ✓
   - Click "Save" to remember these settings

#### Quick Start Configuration
Create this file at `res://tests/gut_config.json`:
```json
{
    "dirs": ["res://tests/"],
    "double_strategy": "script_only",
    "ignore_pause": true,
    "include_subdirs": true,
    "log_level": 1,
    "prefix": "test_",
    "should_exit": true,
    "should_maximize": true,
    "should_exit_on_success": true,
    "unit_test_name": "",
    "post_run_script": "res://tests/fixtures/post_run.gd",
    "pre_run_script": "res://tests/fixtures/pre_run.gd",
    "selected": "",
    "suffix": ".gd"
}
```

This configuration will:
- Automatically find all test files in `res://tests/` and subdirectories
- Use standard test file naming (`test_*.gd`)
- Set up basic logging and execution options

#### First Test Example
Create your first test file at `res://tests/unit/test_example.gd`:
```gdscript
@tool
extends BaseTest

func test_first_example() -> void:
    assert_true(true, "Your first test!")
```

Run it by:
1. Opening GUT panel
2. Clicking "Run All" - it will automatically find and run your test

#### Directory Structure Templates
For new projects, you can quickly set up the recommended structure:

```bash
your-project/
├── tests/
│   ├── unit/                  # Unit tests
│   │   └── test_example.gd    # Your first test
│   ├── integration/           # Integration tests
│   ├── performance/           # Performance tests
│   ├── fixtures/             # Test helpers
│   │   ├── pre_run.gd        # Setup script
│   │   └── post_run.gd       # Cleanup script
│   └── gut_config.json       # Default configuration
```

To create this structure automatically, save this as `res://tests/setup_tests.gd`:
```gdscript
@tool
extends EditorScript

func _run() -> void:
    var dirs := [
        "res://tests/unit",
        "res://tests/integration",
        "res://tests/performance",
        "res://tests/fixtures"
    ]
    
    for dir in dirs:
        if not DirAccess.dir_exists_absolute(dir):
            DirAccess.make_dir_recursive_absolute(dir)
    
    # Create example test
    if not FileAccess.file_exists("res://tests/unit/test_example.gd"):
        var file := FileAccess.open("res://tests/unit/test_example.gd", FileAccess.WRITE)
        file.store_string("""@tool
extends BaseTest

func test_first_example() -> void:
    assert_true(true, "Your first test!")
""")
```

Run this script from Godot's Script Editor to automatically create the test structure.

### Panel Interface
The GUT panel contains several key sections:

#### Top Bar Controls
- **Run All**: Executes all configured test cases
- **Current**: Shows currently selected test
- **Settings**: Access to all GUT configuration options
- **Copy/Clear**: Manage test output

#### Settings Panel (Right Side)
The settings panel controls how your tests run, display, and report results. Here's a detailed breakdown of each section:

1. **General Settings**
   - **Log Level** (1-3): Controls how detailed your test output is
     - Level 1: Basic pass/fail and errors (recommended for most cases)
     - Level 2: Adds setup/teardown information
     - Level 3: Verbose debugging output
   - **Ignore Pause**: Prevents the debugger from pausing test execution
   - **Hide Orphans**: Suppresses Godot's orphan node warnings, useful when testing node creation/deletion
   - **Exit on Finish**: Automatically closes the test runner when complete
   - **Exit on Success**: Only closes the runner if all tests pass (good for CI/CD pipelines)

2. **Runner Settings**
   - **Double Strategy**: How test doubles (mocks/stubs) are created
     - "Script Only": Fastest, only doubles script methods
     - "Inner" (Advanced): Also doubles built-in Godot functionality
   - **Errors cause failures**: When enabled, Godot errors (like null references) will fail tests
   - **Panel Output**: Customizes how test results display in the panel
     - Useful for different screen sizes or readability preferences

3. **Display Settings**
   These settings affect how the GUT panel looks and feels:
   - **Font/Font Size**: Adjust readability (CourierPrime is monospaced, good for test output)
   - **Runner Window**: Configure the test runner's appearance
   - **Opacity**: Make the panel semi-transparent to see the game behind it
   - **Compact Mode**: Reduces spacing for more tests on screen

4. **Test Directories**
   Configure where GUT looks for test files:
   - **Include Subdirs**: ✓ Check this for the standard test structure:
     ```
     tests/
     ├── unit/          ← Directory 0
     ├── integration/   ← Directory 1
     └── performance/   ← Directory 2
     ```
   - **Directory 0-5**: Add multiple test locations
     - Use "..." to browse for directories
     - Paths should start with "res://"
     - Order determines execution sequence

5. **Output Settings**
   Control test reporting and documentation:
   - **XML Output**: Generate machine-readable test results
     - Useful for CI/CD integration
     - Compatible with JUnit report formats
   - **Output Path**: Where to save test reports
     - Recommended: "res://tests/reports/"
   - **Include Timestamp**: Add timing info to reports
     - Helps track test execution duration
     - Useful for performance monitoring

6. **Hooks**
   Advanced features for test automation:
   - **Pre-Run Hook**: Script that runs before tests start
     - Set up test environment
     - Clear test data
     - Initialize required resources

### Recommended Settings for Beginners
If you're new to testing, start with these settings:

1. **Essential Settings**:
   - Log Level: 1
   - Errors cause failures: ✓ (checked)
   - Include Subdirs: ✓ (checked)
   - Directory 0: "res://tests/"

2. **Helpful Display Settings**:
   - Font: CourierPrime
   - Font Size: 16
   - Opacity: 100
   - Compact Mode: Unchecked initially

3. **Output Configuration**:
   - XML Output: Unchecked initially
   - Include Timestamp: ✓ (checked)

As you become more comfortable with testing, you can explore advanced features like:
- Different double strategies for complex mocking
- XML output for test reporting
- Pre-run hooks for test automation
- Custom font settings for better readability

### Basic Configuration
To set up your test environment:

1. Open the GUT panel
2. In Test Directories:
   - Set Directory 0 to your main test directory (e.g., "res://tests/")
   - Enable "Include Subdirs" if using the recommended structure
3. Configure Output Settings:
   - Set Output Path to "res://tests/reports/"
   - Enable Include Timestamp for detailed logs
4. Adjust Display Settings:
   - Set Font Size for readability (recommended: 16)
   - Adjust Opacity if needed (default: 100)

### Running Tests
1. From the GUT panel:
   - Click "Run All" to execute all tests
   - Use directory selection to run specific test sets
   - Double-click individual test files to run them

2. Using keyboard shortcuts:
   - F12: Run all tests
   - Shift+F12: Run current test file
   - Ctrl+F12: Run current test only

### Viewing Results
Test results appear in the main panel area with:
- Pass/fail status for each test
- Detailed error messages
- Test execution time
- Resource usage statistics (if enabled)

### Configuration Files
The project uses two main GUT configuration files:

1. `gut_config.json` - CLI and general settings:
```json
{
    "dirs": ["res://tests/"],
    "double_strategy": "partial",
    "ignore_pause": true,
    "include_subdirs": true,
    "log_level": 1,
    "prefix": "test_",
    "should_exit": true,
    "should_maximize": true
}
```

2. `.gut_editor_config.json` - Editor-specific settings

### Test Structure
GUT tests in this project follow this pattern:
```gdscript
@tool
extends BaseTest

# Optional - Enable performance monitoring
func before_all() -> void:
    super.before_all()
    _performance_monitoring = true

# Setup before each test
func before_each() -> void:
    super.before_each()
    # Initialize test resources

# Cleanup after each test
func after_each() -> void:
    super.after_each()
    # Clean up resources

# Example test method
func test_feature_behavior() -> void:
    # Arrange
    var test_data = setup_test_data()
    
    # Act
    var result = perform_action()
    
    # Assert
    assert_eq(result, expected_value, "Feature should behave as expected")
```

### GUT Assertions
Common assertions used in the project:
```gdscript
# Equality
assert_eq(actual, expected, "message")
assert_ne(actual, expected, "message")

# Boolean
assert_true(condition, "message")
assert_false(condition, "message")

# Null checks
assert_not_null(value, "message")
assert_null(value, "message")

# Range checks
assert_between(value, min, max, "message")

# Collections
assert_has(dictionary, key, "message")
assert_contains(array, value, "message")
```

### Running Specific Tests
From command line:
```bash
# Run a specific test file
godot --script res://tests/fixtures/test_suite.gd --unit=res://tests/unit/test_feature.gd

# Run tests with a specific prefix
godot --script res://tests/fixtures/test_suite.gd --prefix=test_feature

# Run tests in a specific directory
godot --script res://tests/fixtures/test_suite.gd --directory=res://tests/integration
```

From editor:
1. Open GUT panel (View -> GUT)
2. Select test directory or file
3. Click "Run Tests"

### Performance Testing with GUT
Enable performance monitoring in your test:
```gdscript
func test_performance() -> void:
    if not _performance_monitoring:
        return
        
    var execution_time := TestHelper.measure_execution_time(func():
        # Code to measure
        pass
    )
    
    print("Execution time: %.3f seconds" % execution_time)
    assert_between(execution_time, 0.0, 2.0, "Should complete within 2 seconds")
```

### Debugging Tests
1. Add breakpoints in your test code
2. Enable "Debug" in GUT panel
3. Run tests to hit breakpoints
4. Use Godot's debugger to inspect variables

### Common Issues and Solutions
1. **Tests not running:**
   - Check if `@tool` annotation is present
   - Verify test file naming follows prefix/suffix pattern
   - Ensure test extends BaseTest

2. **Resource cleanup:**
   - Use `track_resource()` for automatic cleanup
   - Implement `after_each()` for manual cleanup
   - Check for memory leaks with monitoring

3. **Performance monitoring:**
   - Enable in `before_all()`
   - Use appropriate benchmarks
   - Consider system variations 

### Understanding Test Results

#### Reading the Output
Test results in GUT are color-coded and structured for easy reading:
- 🟢 **Green**: Passed tests
- 🔴 **Red**: Failed tests
- 🟡 **Yellow**: Warnings or skipped tests
- ⚪ **White**: Informational messages

#### Common Output Patterns

1. **Basic Test Failure**
```
[FAILED] test_feature_behavior
> Assertion failed: Value should be 42
> Got: 24, Expected: 42
> At: res://tests/unit/test_feature.gd:45
```
**How to Address**:
- Check the line number in the test file
- Verify expected vs actual values
- Review the feature implementation
- Add print statements before the assertion to debug

2. **Resource Cleanup Warnings**
```
[WARNING] Orphan nodes detected after test
> Node 'TestScene' was not freed
```
**How to Address**:
- Add `track_resource()` calls for created nodes
- Implement proper cleanup in `after_each()`
- Enable "Hide Orphans" temporarily while fixing
- Use `queue_free()` in cleanup methods

3. **Performance Issues**
```
[INFO] Performance test completed
> Execution time: 3.542 seconds
> Expected maximum: 2.000 seconds
```
**How to Address**:
- Increase Log Level to 2 for more details
- Use the Performance Monitor (Shift+F3)
- Check for unnecessary resource loading
- Consider optimizing critical paths

#### Adjusting Settings Based on Results

1. **For Frequent Failures**:
   - Increase Log Level to 2 or 3
   - Disable "Exit on Failure"
   - Enable "Panel Output" for better error visibility
   - Consider running specific test categories:
     ```bash
     godot --script res://tests/fixtures/test_suite.gd --directory=res://tests/unit
     ```

2. **For Performance Issues**:
   - Enable Performance Monitoring
   - Adjust benchmarks in test cases
   - Use "Script Only" double strategy
   - Run performance tests separately:
     ```bash
     godot --script res://tests/fixtures/test_suite.gd --directory=res://tests/performance
     ```

3. **For Resource Leaks**:
   - Enable "Hide Orphans" temporarily
   - Add cleanup logging:
     ```gdscript
     func after_each() -> void:
         super.after_each()
         print("Cleaning up resources...")
         print_orphan_counts()
     ```

#### Test Report Analysis

When using XML output (recommended for larger projects):

1. **Coverage Patterns**
   ```xml
   <testsuites>
     <testsuite name="MyFeature" tests="10" failures="2" skipped="1">
   ```
   - Low test count → Add more test cases
   - High skip count → Review test relevance
   - Clustered failures → Check common dependencies

2. **Timing Patterns**
   ```xml
   <testcase name="test_feature" time="1.234">
   ```
   - Long running tests → Consider optimization
   - Inconsistent timing → Check for race conditions
   - Pattern of slow tests → Review test setup

#### Making Systematic Improvements

1. **Test Quality**
   - Group related failures
   - Look for patterns in error messages
   - Review test naming for clarity
   - Add more specific assertions:
     ```gdscript
     # Instead of
     assert_true(result)
     
     # Use
     assert_eq(result.status, "success", "Operation should complete successfully")
     assert_has(result, "data", "Result should contain data")
     ```

2. **Performance Optimization**
   - Track execution times over time
   - Set realistic benchmarks
   - Use profiling tools:
     ```gdscript
     func test_performance() -> void:
         var start_memory := Performance.get_monitor(Performance.MEMORY_STATIC)
         # ... test code ...
         var memory_used := Performance.get_monitor(Performance.MEMORY_STATIC) - start_memory
         assert_less(memory_used, 1000000, "Memory usage should be reasonable")
     ```

3. **Resource Management**
   - Implement systematic cleanup
   - Use resource pools for heavy tests
   - Track creation and deletion:
     ```gdscript
     var _created_nodes := []
     
     func _track_node(node: Node) -> void:
         _created_nodes.append(node)
         track_resource(node)
     
     func after_each() -> void:
         for node in _created_nodes:
             if is_instance_valid(node):
                 print("Node not cleaned up: ", node.name)
         _created_nodes.clear()
         super.after_each()
     ```

#### Tips for Maintaining Test Quality

1. **Regular Maintenance**
   - Run full suite daily
   - Review failed tests immediately
   - Update benchmarks periodically
   - Clean up obsolete tests

2. **Documentation**
   - Comment non-obvious test setups
   - Document performance expectations
   - Keep a test improvement log
   - Update README with new patterns

3. **Collaboration**
   - Share common test patterns
   - Document custom assertions
   - Maintain consistent naming
   - Review test changes carefully 