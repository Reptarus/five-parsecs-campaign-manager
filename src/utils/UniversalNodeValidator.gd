## Universal Node Validator for Five Parsecs Campaign Manager
## Provides safe node validation following development guidelines
class_name UniversalNodeValidator
extends RefCounted

## Validates that required nodes exist and returns validation results
## @param parent_node: The parent node to search within
## @param required_paths: Array of node paths that must exist
## @return: Dictionary with validation results and node references
static func validate_required_nodes(parent_node: Node, required_paths: Array[String]) -> Dictionary:
	var result := {
		"valid": true,
		"missing_nodes": [],
		"found_nodes": {},
		"errors": []
	}
	
	if not parent_node:
		result.valid = false
		result.errors.append("Parent node is null")
		return result
	
	for path in required_paths:
		var node := parent_node.get_node_or_null(path) as Node
		if node:
			result.found_nodes[path] = node
		else:
			result.valid = false
			result.missing_nodes.append(path)
			result.errors.append("Missing required node: " + path)
	
	return result

## Safe node getter with type validation
## @param parent_node: Parent node to search within
## @param path: Node path to find
## @param expected_type: Expected class type (optional)
## @return: Node if found and valid, null otherwise
static func get_safe_node(parent_node: Node, path: String, expected_type: Script = null) -> Node:
	if not parent_node:
		push_error("Parent node is null when looking for: " + path)
		return null
	
	var node := parent_node.get_node_or_null(path) as Node
	if not node:
		push_error("Node not found: " + path)
		return null
	
	if expected_type and not node.get_script() == expected_type:
		push_error("Node type mismatch for: " + path)
		return null
	
	return node

## Validates signal connections safely
## @param source: Source object for signal
## @param signal_name: Name of signal to connect
## @param target: Target object for connection
## @param method_name: Target method name
## @return: True if connection successful
static func safe_connect_signal(source: Object, signal_name: String, target: Object, method_name: String) -> bool:
	if not source:
		push_error("Source object is null for signal: " + signal_name)
		return false
	
	if not target:
		push_error("Target object is null for signal: " + signal_name)
		return false
	
	if not source.has_signal(signal_name):
		push_error("Signal does not exist: " + signal_name)
		return false
	
	if not target.has_method(method_name):
		push_error("Target method does not exist: " + method_name)
		return false
	
	if source.is_connected(signal_name, Callable(target, method_name)):
		return true  # Already connected
	
	var error := source.connect(signal_name, Callable(target, method_name))
	if error != OK:
		push_error("Failed to connect signal: " + signal_name + " Error: " + str(error))
		return false
	
	return true
