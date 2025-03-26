# Test Callable Patterns

This document outlines the recommended patterns for working with callables (functions) in tests, particularly when dealing with resources that need to be serialized.

## Challenges with Callables

Callables in Godot 4.4 present several challenges:

1. **Serialization**: Callables cannot be serialized with `inst_to_dict()`
2. **Dynamic Assignment**: Directly assigning callables to objects can cause errors
3. **Resource Safety**: Resources with callable properties may not be properly serialized
4. **Type Safety**: Callable types need proper type checking

## Resource Script Pattern

When you need to assign methods to a resource, use this pattern:

```gdscript
# AVOID this pattern - will cause serialization errors:
var resource = Resource.new()
resource.some_method = func(): return 42

# INSTEAD, use the script creation pattern:
var resource = Resource.new()
var script = GDScript.new()
script.source_code = """
extends Resource

func some_method():
    return 42
"""
script.reload()
resource.set_script(script)

# Ensure the resource has a valid path for serialization
if resource.resource_path.is_empty():
    var timestamp = Time.get_unix_time_from_system()
    resource.resource_path = "res://tests/generated/%s_%d.tres" % [resource.get_class().to_snake_case(), timestamp]

# Then you can safely call the method
var result = resource.some_method()
```

## Node Script Pattern

For assigning methods to Nodes:

```gdscript
# AVOID this pattern:
var node = Node.new()
node.some_method = func(): return 42

# INSTEAD, use a script:
var node = Node.new()
var script = GDScript.new()
script.source_code = """
extends Node

func some_method():
    return 42
"""
script.reload()
node.set_script(script)
```

## Type-Safe Callable Checking

When checking if an object has a callable:

```gdscript
# AVOID:
if object.has_method("some_method"):
    object.some_method()

# INSTEAD:
if object.has_method("some_method"):
    object.some_method.call()
```

## Callable Arguments

When creating callables with arguments:

```gdscript
var script = GDScript.new()
script.source_code = """
extends Resource

func some_method(arg1, arg2 = null):
    return arg1 if arg2 == null else arg1 + arg2
"""
script.reload()
resource.set_script(script)

# Call with arguments
var result = resource.some_method.call(42, 58)
```

## Signal Connections with Callables

When connecting signals:

```gdscript
# AVOID:
object.signal_name.connect(func(): print("Signal received"))

# INSTEAD:
var callback_script = GDScript.new()
callback_script.source_code = """
extends RefCounted

func on_signal_received():
    print("Signal received")
"""
callback_script.reload()
var callback = callback_script.new()
object.signal_name.connect(callback.on_signal_received)
```

## Callable Property Serialization

When a resource has callable properties that need to be serialized:

```gdscript
# Original resource with callables
var resource = MyResource.new()

# Create serializable version WITHOUT callables
var serialized = {}
for property in resource.get_property_list():
    var property_name = property.name
    if property_name.begins_with("_") or property_name in ["script", "resource_path", "resource_name"]:
        continue
        
    var value = resource.get(property_name)
    if value is Callable:
        # Skip callables, they can't be serialized
        continue
        
    serialized[property_name] = value

# When deserializing, add callables back
var deserialized = MyResource.new()
for key in serialized:
    deserialized.set(key, serialized[key])

# Add back the callables using the script pattern
var script = GDScript.new()
script.source_code = """
extends MyResource

func some_method():
    return 42
"""
script.reload()
deserialized.set_script(script)
```

## Mission Callables Pattern

For mission objects with callable properties (a common pattern in Five Parsecs):

```gdscript
# Create a mission with callables
var mission = StoryQuestData.create_mission("Test Mission")

# Ensure valid resource path (prevents inst_to_dict errors)
if mission.resource_path.is_empty():
    var timestamp = Time.get_unix_time_from_system()
    mission.resource_path = "res://tests/generated/mission_%s_%d.tres" % [mission.get_class().to_snake_case(), timestamp]

# Assign callable properties safely
var mission_script = GDScript.new()
mission_script.source_code = """
extends Resource

func on_mission_complete():
    return true
    
func on_mission_fail():
    return false
"""
mission_script.reload()
mission.set_script(mission_script)

# When serializing, create a clean copy without callables
var serialized_mission = {}
for property in mission.get_property_list():
    var property_name = property.name
    if property_name.begins_with("_") or property_name in ["script", "resource_path", "resource_name"]:
        continue
        
    if property_name == "on_mission_complete" or property_name == "on_mission_fail":
        continue  # Skip callable properties
        
    if mission.has(property_name):
        serialized_mission[property_name] = mission.get(property_name)
```

## Stable Helper Scripts

For frequently used callable patterns, create stable helper scripts:

```gdscript
# In tests/fixtures/helpers/callable_helpers.gd

## Creates a script with methods and attaches it to a resource
##
## @param {Resource} resource - The resource to attach the script to
## @param {Dictionary} methods - Dictionary mapping method names to their bodies
## @return {Resource} The resource with the script attached
static func add_methods_to_resource(resource: Resource, methods: Dictionary) -> Resource:
    var source = "extends " + resource.get_class() + "\n\n"
    
    for method_name in methods:
        source += "func " + method_name + "():\n"
        source += "\t" + methods[method_name].replace("\n", "\n\t") + "\n\n"
    
    var script = GDScript.new()
    script.source_code = source
    script.reload()
    resource.set_script(script)
    
    if resource.resource_path.is_empty():
        var timestamp = Time.get_unix_time_from_system()
        resource.resource_path = "res://tests/generated/%s_%d.tres" % [resource.get_class().to_snake_case(), timestamp]
        
    return resource
```

## Testing Patterns for Callables

When testing objects with callables:

```gdscript
# Setup
var resource = Resource.new()
resource = add_methods_to_resource(resource, {
    "calculate": "return 42"
})
track_test_resource(resource)

# Test
func test_resource_with_callable():
    assert_true(resource.has("calculate"), "Resource should have the calculate method")
    assert_eq(resource.calculate(), 42, "Method should return 42")
```

## Best Practices

1. **Never** assign lambdas directly to Resources
2. **Always** ensure Resources have valid resource paths
3. **Always** use explicit script creation for adding methods
4. **Skip** callable properties when serializing
5. **Use** helper functions for common callable patterns
6. **Document** the callable behavior in tests
7. **Track** resources with callables for proper cleanup

## Common Issues and Solutions

### Invalid Method Call

**Problem**:
```
Invalid call. Nonexistent function 'some_method' in base 'Resource'
```

**Solution**:
Use the script creation pattern shown above to add the method to the resource.

### Serialization Error

**Problem**:
```
Error calling GDScript utility function 'inst_to_dict': Can't serialize objects of type 'Callable'
```

**Solution**:
Skip callable properties when serializing or use the property copying approach.

### Invalid Assignment

**Problem**:
```
Invalid assignment to property 'some_method' (on base: 'Resource') with value of type 'Callable'
```

**Solution**:
Use the script creation pattern to add methods, rather than direct assignment. 