# Five Parsecs Consistency Guidelines

This document serves as a consolidated reference for consistent coding patterns established across the Five Parsecs Campaign Manager project. Following these guidelines will ensure code quality, prevent common errors, and maintain consistency throughout the codebase.

## File Path References

Always use absolute paths when referencing files:

```gdscript
# CORRECT: Absolute path references
const MyClass = preload("res://src/core/MyClass.gd")
const MyScene = preload("res://src/ui/MyScene.tscn")

# AVOID: Relative path references
const MyClass = preload("../core/MyClass.gd")
const MyScene = load("./MyScene.tscn")
```

## Test Base Class References

Test files should use absolute file paths in extends statements:

```gdscript
# CORRECT: Absolute path in extends
@tool
extends "res://tests/fixtures/specialized/campaign_test.gd"

# AVOID: Using class names directly
@tool
extends CampaignTest

# AVOID: Using relative paths
@tool
extends "../specialized/campaign_test.gd"
```

## Script Loading Patterns

Always use preload/load with absolute paths:

```gdscript
# CORRECT: Use preload with absolute paths
const GameState = preload("res://src/core/state/GameState.gd")
var state = GameState.new()

# AVOID: Using class names directly (unless in class_name_registry.md)
var state = GameState.new()
```

## Resource Path Generation

Generate consistent resource paths for all resources:

```gdscript
# CORRECT: Consistent path generation
if resource is Resource and resource.resource_path.is_empty():
    var timestamp = Time.get_unix_time_from_system()
    resource.resource_path = "res://tests/generated/%s_%d.tres" % [resource.get_class().to_snake_case(), timestamp]
```

## Method Call Safety

Always check for method existence before calling:

```gdscript
# CORRECT: Check method existence
if object.has_method("method_name"):
    object.method_name(args)
else:
    # Fallback behavior
    push_warning("Method 'method_name' not found")

# Alternative: Use type-safe call utilities
TypeSafeMixin._call_node_method_bool(object, "method_name", [args])
```

## Dictionary Access

Use the 'in' operator instead of 'has()' for dictionaries:

```gdscript
# CORRECT: Use 'in' operator
if key in dictionary:
    var value = dictionary[key]
else:
    var value = default_value

# Alternative: Use get() with default
var value = dictionary.get(key, default_value)
```

## Property Access

Check if properties exist before accessing:

```gdscript
# CORRECT: Check property existence
if object.has("property_name"):
    var value = object.property_name
else:
    var value = default_value
```

## Resource Safety

Implement proper resource tracking:

```gdscript
# For nodes:
add_child_autofree(node)
track_test_node(node)

# For resources:
track_test_resource(resource)
```

## Test Lifecycle Methods

Follow consistent test lifecycle pattern:

```gdscript
func before_each() -> void:
    # Always call super first
    await super.before_each()
    
    # Setup code here
    _instance = TestedClass.new()
    
    # Resource safety
    if _instance is Resource and _instance.resource_path.is_empty():
        var timestamp = Time.get_unix_time_from_system()
        _instance.resource_path = "res://tests/generated/%s_%d.tres" % [_instance.get_class().to_snake_case(), timestamp]
    
    # Resource tracking
    if _instance is Node:
        add_child_autofree(_instance)
        track_test_node(_instance)
    else:
        track_test_resource(_instance)
    
    # Always stabilize at the end
    await stabilize_engine()

func after_each() -> void:
    # Cleanup code here
    _instance = null
    
    # Always call super last
    await super.after_each()
```

## Signal Testing

Use proper signal watching and verification:

```gdscript
# Enable signal watching
watch_signals(instance)

# Perform action that should emit signal
instance.some_action()

# Verify signal emission
verify_signal_emitted(instance, "signal_name")
```

## Safe Serialization

Avoid inst_to_dict() and use manual property copying:

```gdscript
# CORRECT: Manual property copying
var serialized = {}
if resource.has("property_name"):
    serialized["property_name"] = resource.property_name

# For collections, always duplicate
if resource.has("array_property"):
    serialized["array_property"] = resource.array_property.duplicate()
```

## Method Assignment

Never assign methods directly; use script-based approach:

```gdscript
# AVOID: Direct method assignment
resource.some_method = func(): return 42

# CORRECT: Script-based approach
var script = GDScript.new()
script.source_code = """
extends Resource

func some_method():
    return 42
"""
script.reload()
resource.set_script(script)

# Ensure resource path
if resource.resource_path.is_empty():
    var timestamp = Time.get_unix_time_from_system()
    resource.resource_path = "res://tests/generated/%s_%d.tres" % [resource.get_class().to_snake_case(), timestamp]
```

## Class Name Usage

Follow class_name registry guidelines:

1. Check class_name_registry.md before using class_name declarations
2. Use preload with absolute paths as the preferred approach
3. Document any class_name removals
4. Update the registry when adding new class_name declarations

## File Naming Conventions

Follow consistent naming conventions:

- **GDScript Classes**: PascalCase.gd (e.g., `CharacterManager.gd`)
- **Scene Files**: PascalCase.tscn (e.g., `MainMenu.tscn`)
- **Resources**: snake_case.tres (e.g., `character_template.tres`)
- **Test Files**: test_snake_case.gd (e.g., `test_character_manager.gd`)
- **Test Base Classes**: snake_case_test.gd (e.g., `campaign_test.gd`)
- **Interface Files**: IPascalCase.gd (e.g., `ICharacter.gd`)
- **Enum Files**: PascalCaseEnums.gd (e.g., `GameEnums.gd`)

## Project Directory Structure

Use consistent directory structure:

```
res://
├── src/
│   ├── core/        # Core systems and game logic
│   ├── game/        # Game-specific implementations
│   └── ui/          # User interface components
└── tests/
    ├── fixtures/    # Test utilities
    │   ├── base/    # Base test classes
    │   ├── helpers/ # Test helper functions
    │   └── specialized/ # Domain-specific test bases
    ├── unit/        # Unit tests (matching src structure)
    └── integration/ # Integration tests
```

## Common Testing Patterns

1. **Arrangement**: Set up the test environment
2. **Action**: Perform the action being tested
3. **Assertion**: Verify the expected outcome

```gdscript
func test_example() -> void:
    # Arrange
    var object = setup_test_object()
    watch_signals(object)
    
    # Act
    object.perform_action()
    
    # Assert
    verify_signal_emitted(object, "action_completed")
    assert_eq(object.get_state(), expected_state, "State should match expected value")
}
```

## Error Prevention Checklist

- [x] Using absolute paths for all file references
- [x] Checking method existence before calling
- [x] Using 'in' operator for dictionaries
- [x] Implementing proper resource tracking
- [x] Setting valid resource paths
- [x] Following test lifecycle patterns
- [x] Using proper signal testing
- [x] Implementing safe serialization
- [x] Following class_name registry guidelines
- [x] Using consistent file naming conventions
- [x] Following project directory structure
- [x] Implementing proper test patterns

This document should be updated whenever new consistency guidelines are established. 