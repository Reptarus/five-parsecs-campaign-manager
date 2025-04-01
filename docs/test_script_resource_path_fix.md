# Fixing Cyclic Resource Inclusion in Test Scripts

## Issue Description

When running tests in Godot, the following error was occurring:

```
E 0:00:15:581   test_enemy_campaign_flow.gd:504 @ _setup_test_campaign(): Another resource is loaded from path 'res://tests/generated/test_campaign_script.gd' (possible cyclic resource inclusion).
  <C++ Error>   Method/function failed.
  <C++ Source>  core/io/resource.cpp:75 @ set_path()
  <Stack Trace> test_enemy_campaign_flow.gd:504 @ _setup_test_campaign()
```

This error occurs when multiple tests attempt to create script resources with the same `resource_path`. In this case, multiple instances of test scripts were being assigned the same path:

```gdscript
# Problematic code
script.resource_path = "res://tests/generated/test_campaign_script.gd"
```

When two or more resources share the exact same path, Godot detects this as a potential cyclic inclusion and throws an error to prevent infinite recursion or resource corruption.

## Solution

The solution was to make each script's resource path unique by incorporating timestamps and random numbers:

```gdscript
# Fixed code
var timestamp = Time.get_unix_time_from_system()
var random_id = randi() % 1000000
script.resource_path = "res://tests/temp/test_campaign_%d_%d.gd" % [timestamp, random_id]
```

Additionally, we ensured the temporary directory exists:

```gdscript
if not Compatibility.ensure_temp_directory():
    push_warning("Could not create temp directory for test scripts")
    return campaign
```

## Best Practices for Generated Scripts in Tests

To avoid cyclic resource inclusion errors:

1. **Always use unique paths** for dynamically created scripts:
   - Incorporate timestamps in resource paths
   - Add randomization for concurrent test runs
   - Consider including the test name or test case ID in the path

2. **Use a temporary directory**:
   - Create scripts in `res://tests/temp/` which should be excluded from version control
   - Ensure the directory exists before writing files
   - Clean up test scripts when possible

3. **Resource tracking for cleanup**:
   - Always track resources created in tests
   - Properly release/free resources after tests
   - Consider implementing cleanup utilities for temp directories

4. **Avoid hardcoded paths**:
   - Never use the same hardcoded path for multiple script instances
   - Check if a path is already in use before assigning it
   - Use path generation helpers when available

## Implementation in Your Tests

When creating test scripts:

```gdscript
func create_test_script() -> GDScript:
    var script = GDScript.new()
    
    # Set script content
    script.source_code = "..."
    
    # Generate unique path
    var timestamp = Time.get_unix_time_from_system()
    var random_id = randi() % 1000000
    script.resource_path = "res://tests/temp/test_script_%d_%d.gd" % [timestamp, random_id]
    
    # Ensure directory exists
    if not Compatibility.ensure_temp_directory():
        return null
        
    # Reload to compile the script
    var success = script.reload()
    assert(success, "Script should compile successfully")
    
    return script
```

Use this helper to generate unique scripts for your tests.

## Known Limitations

- Script files in `res://tests/temp/` will accumulate unless manually cleaned up
- Very rapid test creation might still generate duplicates (though unlikely with timestamp + random)
- Resource paths don't guarantee uniqueness across multiple test runs

## Related Issues

This fix addresses similar issues that might occur in:
- Dynamic script generation in game features
- Runtime script compilation
- Test fixtures that generate scripts
- Plugin development with dynamic code generation 