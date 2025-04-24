@tool
extends "res://addons/gut/test.gd"

# Base test class for character tests with common utilities

# Game enums for consistency
var GameEnums = preload("res://src/core/enums/GameEnums.gd")

# State tracking
var _game_state: Node = null
var _tracked_nodes = []

# Constants for character test types
enum CharacterTestType {
    BASIC,
    SOLDIER,
    SCOUT,
    MEDIC,
    ENGINEER
}

func before_all() -> void:
    # No-op by default, override in child classes
    pass

func before_each() -> void:
    # Reset tracked nodes
    _tracked_nodes.clear()

func after_each() -> void:
    # Clean up any tracked nodes
    _cleanup_tracked_nodes()
    
    # Clean up game state
    if is_instance_valid(_game_state):
        _game_state.queue_free()
    _game_state = null

func _cleanup_tracked_nodes() -> void:
    for node in _tracked_nodes:
        if is_instance_valid(node):
            node.queue_free()
    _tracked_nodes.clear()

# Track a node for automatic cleanup
func track_test_node(node: Node) -> void:
    if node and not node in _tracked_nodes:
        _tracked_nodes.append(node)

# Helper method to safely get a property from an object
func _get_property_safe(object: Object, property_name: String, default_value = null):
    if not object:
        return default_value
    if not property_name in object:
        return default_value
    return object.get(property_name)

# Helper method to safely call a method on an object
func _call_node_method(node: Object, method: String, args: Array = []):
    if not node:
        push_error("Cannot call method '%s' on null node" % method)
        return null
    
    if not node.has_method(method):
        push_error("Node does not have method: %s" % method)
        return null
    
    return node.callv(method, args)

# Helper method to call a method and convert result to bool
func _call_node_method_bool(node: Object, method: String, args: Array = []) -> bool:
    var result = _call_node_method(node, method, args)
    if result == null:
        return false
    return bool(result)

# Helper method to call a method and convert result to int
func _call_node_method_int(node: Object, method: String, args: Array = []) -> int:
    var result = _call_node_method(node, method, args)
    if result == null:
        return 0
    return int(result)

# Helper method to call a method and convert result to float
func _call_node_method_float(node: Object, method: String, args: Array = []) -> float:
    var result = _call_node_method(node, method, args)
    if result == null:
        return 0.0
    return float(result)

# Helper method to call a method and convert result to string
func _call_node_method_string(node: Object, method: String, args: Array = []) -> String:
    var result = _call_node_method(node, method, args)
    if result == null:
        return ""
    return str(result)

# Helper method to call a method and convert result to array
func _call_node_method_array(node: Object, method: String, args: Array = []) -> Array:
    var result = _call_node_method(node, method, args)
    if result == null or not result is Array:
        return []
    return result

# Helper method to call a method and convert result to dictionary
func _call_node_method_dict(node: Object, method: String, args: Array = []) -> Dictionary:
    var result = _call_node_method(node, method, args)
    if result == null or not result is Dictionary:
        return {}
    return result