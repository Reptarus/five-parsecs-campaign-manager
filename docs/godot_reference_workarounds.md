# Godot Reference Workarounds

This document explains common issues with class references in Godot and workarounds implemented in this project.

## Class Name Conflicts

When multiple classes declare the same `class_name`, Godot will report an error. Our solution is to:
1. Keep the class_name in the primary/authoritative version
2. Remove it from other versions
3. Document the change in `docs/class_name_conflicts.md`

## Inner Class Reference Issues

After removing `class_name` declarations, references to inner classes can cause linter errors with malformed paths. These appear in the linter as:

```
Error while getting cache for script "file:res:/res:/res:/c:res:/Usersres:/elijares:/...
```

### Workarounds Implemented

We've implemented several patterns to work around these issues:

#### 1. Factory Methods

For classes that create instances of inner classes, we've added factory methods:

```gdscript
# Instead of direct instantiation:
var instance = InnerClass.new()

# Use a factory method:
func create_inner_class_instance() -> InnerClass:
    return InnerClass.new()

var instance = create_inner_class_instance()
```

This pattern has been implemented in:
- `src/core/state/StateValidator.gd` - Added `create_result()` to instantiate `ValidationResult`
- `src/utils/helpers/PathFinder.gd` - Added `create_path_node()` to instantiate `PathNode`

#### 2. Explicit References

When using scripts that previously had `class_name` declarations, use explicit preloads with absolute paths:

```gdscript
# Instead of:
var instance = SomeClass.new()

# Use:
const SomeClassScript = preload("res://path/to/some_class.gd")
var instance = SomeClassScript.new()
```

#### 3. Documentation Comments

We add explanatory comments to scripts that had their `class_name` declarations removed:

```gdscript
# REMOVED: class_name SomeClass
# This class previously used class_name but it was removed to prevent conflicts
# The authoritative SomeClass is in some/other/path.gd
# Use explicit preloads to reference this class: preload("res://path/to/this/script.gd")
```

### Remaining Linter Issues

Even with these workarounds, you may still see linter errors like:

```
Error while getting cache for script "file:res:/res:/res:/c:res:/Usersres:/..."
```

These errors are related to how Godot constructs paths when referencing inner classes. While annoying, they typically don't prevent the game from running correctly, as long as the actual code references are working at runtime.

If these errors become problematic:
1. Consider extracting inner classes to separate files
2. Add more diagnostic prints to verify the code is working as expected at runtime
3. Check the console for runtime errors (which would indicate actual problems)

## Best Practices

To avoid these issues in the future:

1. **Avoid Duplicating Files**:
   - Don't create multiple copies of the same script
   - Use inheritance or composition instead

2. **Plan Class Names**:
   - Reserve `class_name` for truly global classes
   - Use a consistent naming scheme with project prefixes (e.g., `FiveParsecsPathFinder`)

3. **Organize Scripts**:
   - Keep related scripts in appropriate directories
   - Document organization patterns in README files

4. **Reference Scripts Correctly**:
   - Always use absolute paths with `res://` in preload/load calls
   - Avoid changing script locations after they've been referenced elsewhere 