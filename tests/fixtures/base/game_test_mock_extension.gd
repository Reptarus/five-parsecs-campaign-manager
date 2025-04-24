@tool
extends "res://tests/fixtures/base/game_test.gd"

## Five Parsecs Game Test with Mock Support
## Extends the existing game test with mock capabilities

## Mock implementation provider
var _mock_provider = null

# Test mock extension that adds mocking capabilities to the base game test class
const LocalGutCompatibility = preload("res://tests/fixtures/helpers/gut_compatibility.gd")

var _compatibility = null
var _mock_objects = []

# Override _init instead of using _init
func _ready() -> void:
    # No need to call super._init since it doesn't exist in parent
    # Initialize mock provider
    _mock_provider = load("res://tests/fixtures/helpers/mock_provider.gd").new()

    _compatibility = LocalGutCompatibility.new()

## Creates a mock implementation of a specific manager type
## @param manager_type: Type of manager to mock (e.g. "ResourceManager")
## @return: Mock object with appropriate methods
func create_mock_manager(manager_type: String) -> Object:
    if not _mock_provider:
        push_warning("Mock provider not initialized")
        return null
    
    var mock = _mock_provider.create_manager_mock(manager_type)
    
    # Register for cleanup
    if mock is Resource:
        track_test_resource(mock)
    
    return mock

## Creates a testable control with all required methods
## @return: A Control with all commonly needed methods
func create_test_control() -> Control:
    if not _mock_provider:
        push_warning("Mock provider not initialized")
        return null
        
    var control = _mock_provider.create_mock_control()
    
    # Make control autofree
    add_child_autofree(control)
    
    # Track for cleanup
    track_test_node(control)
    
    return control

## Makes an existing Control testable by ensuring it has all needed methods
## @param control: Control to make testable
## @return: Original control or replacement with methods added
func make_testable(control: Control) -> Control:
    if not is_instance_valid(control):
        push_warning("Cannot make invalid control testable")
        return null
        
    var testable = TypeSafeMixin.make_testable(control)
    
    # Track the testable control
    if testable != control:
        track_test_node(testable)
    
    return testable

## Automatically add missing methods to a node tree
## @param root: Root node to process recursively
func auto_fix_node_tree(root: Node = null) -> void:
    if not _mock_provider:
        push_warning("Mock provider not initialized")
        return
        
    if root == null:
        if get_tree() and get_tree().root:
            root = get_tree().root
        else:
            return
            
    # Fix current node if it's a Control
    if root is Control:
        _mock_provider.fix_missing_methods(root)
        
    # Process all children
    for child in root.get_children():
        if child.name == "GUT" or child.name == "TestRunner":
            continue
        auto_fix_node_tree(child)

## Override before_each to include auto-fixing of nodes
func before_each() -> void:
    await super.before_each()
    
    # Initialize the mock provider if needed
    if not _mock_provider:
        _mock_provider = load("res://tests/fixtures/helpers/mock_provider.gd").new()
    
    # Auto-fix nodes in the test scene
    auto_fix_node_tree()

    _mock_objects.clear()

## Creates a mock object with given methods and properties
## @param methods: Dictionary of method names to return values
## @param properties: Dictionary of property names to values
## @return: A RefCounted object with the specified methods and properties
func create_mock(methods: Dictionary = {}, properties: Dictionary = {}) -> RefCounted:
    if not _mock_provider:
        push_warning("Mock provider not initialized")
        return null
        
    var mock = _mock_provider.create_mock_object()
    
    # Add methods
    for method_name in methods:
        mock.set_mock_value(method_name, methods[method_name])
    
    # Add properties
    for property_name in properties:
        mock.set_mock_value(property_name, properties[property_name])
    
    _mock_objects.append(mock)
    
    return mock

## Creates a Node with mocked methods
## @param methods: Dictionary of method names to return values
## @return: A Node with the specified methods
func create_mock_node(methods: Dictionary = {}) -> Node:
    var node = Node.new()
    node.name = "MockNode"
    
    # Add to tree
    add_child_autofree(node)
    
    # Track the node
    track_test_node(node)
    
    # Add methods
    for method_name in methods:
        TypeSafeMixin.mock_method(node, method_name, methods[method_name])
    
    return node

func after_each():
    for mock in _mock_objects:
        if is_instance_valid(mock) and not mock.is_queued_for_deletion():
            if mock is Node and mock.is_inside_tree():
                mock.queue_free()
            mock = null
    _mock_objects.clear()
    
    await super.after_each()

# Creates a mock object from the given script or class
func create_mock_from_script(from_script):
    var mock = _compatibility.create_double(from_script)
    if mock:
        _mock_objects.append(mock)
    return mock

# Adds spy capability to an object
func spy_on(obj):
    var spied_obj = _compatibility.add_spy(obj)
    return spied_obj

# Stubs a method on an object to return a specific value
func stub_method(obj, method_name, return_value = null):
    _compatibility.stub_method(obj, method_name, return_value)
    return obj

# Verifies that the given methods were called on the spied object
func assert_methods_called(obj, method_names: Array, message = ""):
    var called = _compatibility.verify_called(obj, method_names)
    
    if message.is_empty():
        message = "Expected methods %s to be called on %s" % [method_names, obj]
        
    assert_true(called, message)

# Gets the number of times a method was called
func get_call_count(obj, method_name = null, default = 0) -> Variant:
    return _compatibility.get_call_count(obj, method_name)

# Assert a method was called a specific number of times
func assert_call_count(obj, method_name: String, expected_count: int, message = ""):
    var actual_count = get_call_count(obj, method_name)
    
    if message.is_empty():
        message = "Expected method '%s' to be called %d times, but was called %d times" % [
            method_name, expected_count, actual_count
        ]
        
    assert_eq(actual_count, expected_count, message)

# Creates a dummy object with the specified methods
func create_dummy_with_methods(methods: Dictionary):
    var source = "extends RefCounted\n\n"
    
    for method_name in methods:
        source += "func %s():\n" % method_name
        source += "    %s\n\n" % methods[method_name].replace("\n", "\n    ")
    
    var script = _compatibility.create_script_from_source(source)
    var dummy = _compatibility.instantiate_script(script)
    
    if dummy:
        _mock_objects.append(dummy)
        
    return dummy