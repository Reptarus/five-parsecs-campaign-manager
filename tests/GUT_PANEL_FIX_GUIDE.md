# GUT Panel Fix Guide

This guide will help you fix the GUT panel so it displays the full interface with all functionality as shown in the official GUT documentation.

![GUT Panel](https://raw.githubusercontent.com/bitwes/Gut/main/images/gut_panel.png)

## Quick Fix Steps

1. **Reset GUT Configuration**:
   - Run the fix script we've created: `tests/fix_gut_panel.gd`
   - In Godot editor, go to the Script tab
   - Click "File" → "Open..."
   - Navigate to and select `tests/fix_gut_panel.gd`
   - Click "Run Current Script" (Play button in the top-right of the script editor)

2. **Restart Godot Editor**:
   - After running the fix script, close and reopen Godot

3. **Disable and Re-enable the GUT Plugin**:
   - Go to "Project" → "Project Settings..." → "Plugins" tab
   - Disable the GUT plugin (uncheck it)
   - Close the Project Settings
   - Reopen Project Settings and re-enable the GUT plugin

4. **Open the GUT Panel**:
   - Click the "GUT" button at the bottom of the editor
   - If the button isn't visible, try looking for it in the bottom panel tabs

5. **Configure Test Directories**:
   - If needed, configure your test directories in the GUT panel
   - Ensure "Include Subdirectories" is checked

## Manual Checks

If the above steps don't fully fix the issue:

1. **Check the .gutconfig.json file**:
   Make sure it has the necessary configuration and matches what you need:

   ```json
   {
       "dirs": [
           "res://tests/unit/",
           "res://tests/integration/",
           "res://tests/battle/",
           "res://tests/performance/",
           "res://tests/mobile/",
           "res://tests/diagnostic/"
       ],
       "double_strategy": "partial",
       "include_subdirs": true,
       "log_level": 3,
       "opacity": 100,
       "prefix": "test_",
       "hide_orphans": false,
       "should_exit": false,
       "should_maximize": true
   }
   ```

2. **Check GUT Scene**:
   - Open `tests/GutTestScene.tscn`
   - Ensure it uses the GutRunner script and has the proper configuration

3. **Delete Problematic Files**:
   - Manually delete any `*.uid` files in the `addons/gut` directory and subdirectories
   - Delete the `user://gut_temp_directory` contents (open file explorer and navigate to the user data folder)

## Running Tests from the GUT Panel

Once fixed, you can use the GUT panel to run tests:

1. **Run All Tests**: Click the "Run All" button 
2. **Run a Specific Script**: Open the script and click the button with the script name
3. **Run a Specific Test**: Navigate to a test function in the script and click the button with the test name

## Using Context-Sensitive Run Buttons

The full GUT panel includes context-sensitive run buttons that dynamically update based on your cursor position:

1. **Script-level button**: Appears when you open a test script, lets you run just that script
2. **Test-level button**: Appears when you place your cursor inside a test function, lets you run just that test
3. **Inner class button**: Appears when you're inside an inner test class, lets you run all tests in that class

Make sure to look at the buttons in the GUT panel header to see these context-sensitive options.

## Troubleshooting Persistent Issues

If you still have issues with the GUT panel:

1. **Check for Plugin Conflicts**:
   - Temporarily disable other plugins to see if there's a conflict

2. **Clean Reinstall of GUT**:
   - Disable the GUT plugin
   - Save your project and close Godot
   - Delete the `addons/gut` folder completely
   - Reinstall GUT from the AssetLib
   - Re-enable the plugin

3. **Check Godot Version Compatibility**:
   - Ensure you're using GUT 9.3.1+ for Godot 4.4
   - GUT 9.x series is for Godot 4.x 