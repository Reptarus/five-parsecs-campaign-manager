# Five Parsecs IDE Testing Guide

This guide explains how to run tests using our IDE-based testing workflow instead of relying on the unstable GUT panel.

## Why IDE-Based Testing?

The GUT panel has been problematic:
- Breaks frequently when reloading the project
- Requires manual fixes and workarounds
- Slows down development

Our IDE-based approach provides a more stable, faster workflow for running tests.

## Running Tests from VSCode

### Option 1: Using VSCode Tasks (Recommended)

We've set up VSCode tasks for running tests:

1. **Run All Tests**: `Ctrl+Shift+T`
   - Runs all tests in the project

2. **Run Current Test File**: `Ctrl+Shift+R`
   - Runs all tests in the currently open test file
   - File must be named `test_*.gd`

3. **Run Test at Cursor**: `Ctrl+Shift+F`
   - Runs the specific test function where your cursor is positioned
   - You must select the function name first

### Option 2: Using VSCode Command Palette

1. Press `Ctrl+Shift+P` to open the command palette
2. Type "Tasks: Run Task"
3. Select one of the following:
   - `run-tests`: Run all tests
   - `run-current-test`: Run the current test file
   - `run-test-at-cursor`: Run the test at cursor position

### Option 3: Using the GUT Context Menu

Right-click on a test file in the editor and select one of these options:
- GUT: Run All
- GUT: Run at Cursor
- GUT: Run Current Script

## Running Tests from Terminal

We've created a PowerShell script for running tests:

```powershell
# Run all tests
./run_tests.ps1

# Run a specific test file
./run_tests.ps1 test_example.gd

# Run a specific test function
./run_tests.ps1 test_example.gd test_function_name
```

## Fixing GUT When It Breaks

If GUT still breaks despite using our IDE workflow, you can fix it:

1. In Godot, go to "Editor > Editor Script..."
2. Select "Load..." and navigate to `res://tests/fix_gut.gd`
3. Click "Run"

This script will automatically:
- Delete problematic .uid files
- Fix compatibility issues
- Ensure required files are in place
- Re-enable the GUT plugin if needed

## Best Practices

1. **Always use file path references** in extends statements:
   ```gdscript
   # CORRECT ✅
   extends "res://tests/fixtures/specialized/campaign_test.gd"
   
   # INCORRECT ❌
   extends CampaignTest
   ```

2. **Use the appropriate base test class**:
   - UI tests → `extends "res://tests/fixtures/specialized/ui_test.gd"`
   - Battle tests → `extends "res://tests/fixtures/specialized/battle_test.gd"`
   - Campaign tests → `extends "res://tests/fixtures/specialized/campaign_test.gd"`
   - Mobile tests → `extends "res://tests/fixtures/specialized/mobile_test.gd"`
   - Enemy tests → `extends "res://tests/fixtures/specialized/enemy_test.gd"`
   - General tests → `extends "res://tests/fixtures/base/game_test.gd"`

3. **Update dictionary access** to use the `in` operator:
   ```gdscript
   # INCORRECT ❌
   if dictionary.has("key")
   
   # CORRECT ✅
   if "key" in dictionary
   ```

4. **Use type-safe method calls** from TypeSafeMixin:
   ```gdscript
   # Safe method call with default value
   var result = TypeSafeMixin._call_node_method_bool(obj, "method", [], false)
   ```

5. **Ensure resources have valid paths**:
   ```gdscript
   if resource is Resource and resource.resource_path.is_empty():
       resource.resource_path = "res://tests/generated/resource_%d.tres" % Time.get_unix_time_from_system()
   ```

## Troubleshooting

If you encounter issues:

1. **Tests don't run in VSCode**:
   - Check that the Godot path in the tasks.json file is correct
   - Make sure VSCode settings have the correct godot.editorPath value

2. **File path errors**:
   - Ensure all test files use explicit file path references
   - Check that the path matches the actual file location

3. **GUT keeps breaking**:
   - Run the fix_gut.gd script
   - Delete all .uid files in the addons/gut directory
   - Restart Godot completely
   - Disable and re-enable the GUT plugin 