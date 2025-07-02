# Universal Node Validation System - Five Parsecs Campaign Manager
# This system prevents null reference crashes across all UI components

class_name UniversalNodeValidator
extends RefCounted

## Universal Node Access - Prevents null reference crashes
static func safe_get_node(base_node: Node, path: String, context: String = "") -> Node:
	if not base_node:
		push_warning("UniversalValidator: Base node is null in context: " + context)
		return null
	
	var target_node = base_node.get_node_or_null(path)
	if not target_node:
		push_warning("UniversalValidator: Node not found: '%s' in context: %s" % [path, context])
		return null
	
	return target_node

## Safe Signal Connection - Prevents connection to null nodes
static func safe_connect_signal(node: Node, signal_name: String, callable: Callable, context: String = "") -> bool:
	if not node:
		push_warning("UniversalValidator: Cannot connect signal '%s' - node is null in context: %s" % [signal_name, context])
		return false
	
	if not node.has_signal(signal_name):
		push_warning("UniversalValidator: Signal '%s' does not exist on node in context: %s" % [signal_name, context])
		return false
	
	# Avoid duplicate connections
	if node.is_connected(signal_name, callable):
		return true
	
	var error = node.connect(signal_name, callable)
	if error != OK:
		push_warning("UniversalValidator: Failed to connect signal '%s' (Error %d) in context: %s" % [signal_name, error, context])
		return false
	
	return true

## Safe Property Access - Prevents crashes when accessing properties
static func safe_get_property(node: Node, property: String, default_value: Variant = null, context: String = "") -> Variant:
	if not node:
		push_warning("UniversalValidator: Cannot get property '%s' - node is null in context: %s" % [property, context])
		return default_value
	
	if not property in node:
		push_warning("UniversalValidator: Property '%s' does not exist on node in context: %s" % [property, context])
		return default_value
	
	return node.get(property)

## Safe Property Setting - Prevents crashes when setting properties
static func safe_set_property(node: Node, property: String, value: Variant, context: String = "") -> bool:
	if not node:
		push_warning("UniversalValidator: Cannot set property '%s' - node is null in context: %s" % [property, context])
		return false
	
	if not property in node:
		push_warning("UniversalValidator: Property '%s' does not exist on node in context: %s" % [property, context])
		return false
	
	node.set(property, value)
	return true

## Comprehensive Node Validation - For complex UI components
static func validate_required_nodes(base_node: Node, required_paths: Array[String], context: String = "") -> Dictionary:
	var result = {
		"all_found": true,
		"missing_nodes": [],
		"found_nodes": {}
	}
	
	for path in required_paths:
		var node = safe_get_node(base_node, path, context + " - Required Node")
		if node:
			result.found_nodes[path] = node
		else:
			result.all_found = false
			result.missing_nodes.append(path)
	
	return result

## UI Component Validator - All-in-one solution for UI screens
static func setup_ui_component(ui_component: Node, required_nodes: Array[String], 
                                signal_connections: Array[Dictionary] = [], 
                                context: String = "") -> Dictionary:
	var setup_result = {
		"success": true,
		"errors": [],
		"warnings": [],
		"nodes": {}
	}
	
	# Validate all required nodes exist
	var validation_result = validate_required_nodes(ui_component, required_nodes, context)
	setup_result.nodes = validation_result.found_nodes
	
	if not validation_result.all_found:
		setup_result.success = false
		setup_result.errors.append("Missing required nodes: " + str(validation_result.missing_nodes))
	
	# Setup signal connections safely
	for connection_config in signal_connections:
		var node_path = connection_config.get("node_path", "")
		var signal_name = connection_config.get("signal", "")
		var method_name = connection_config.get("method", "")
		
		var node = setup_result.nodes.get(node_path)
		if node and ui_component.has_method(method_name):
			var callable = Callable(ui_component, method_name)
			if not safe_connect_signal(node, signal_name, callable, context + " - " + signal_name):
				setup_result.warnings.append("Failed to connect %s.%s" % [node_path, signal_name])
		else:
			setup_result.warnings.append("Cannot connect %s.%s - missing node or method" % [node_path, signal_name])
	
	return setup_result

## Safe method call - Prevents crashes when calling methods on potentially null nodes
static func safe_call_method(node: Node, method_name: String, args: Array = [], context: String = "") -> Variant:
	if not node:
		push_warning("UniversalValidator: Cannot call method '%s' - node is null in context: %s" % [method_name, context])
		return null
	
	if not node.has_method(method_name):
		push_warning("UniversalValidator: Method '%s' does not exist on node in context: %s" % [method_name, context])
		return null
	
	return node.callv(method_name, args)

## Safe UI element setup - For common UI patterns
static func safe_setup_button(button: Node, text: String, callback: Callable, context: String = "") -> bool:
	if not button:
		push_warning("UniversalValidator: Cannot setup button - button is null in context: %s" % context)
		return false
	
	safe_set_property(button, "text", text, context + " - button text")
	return safe_connect_signal(button, "pressed", callback, context + " - button pressed")

static func safe_setup_toggle(toggle: Node, initial_state: bool, callback: Callable, context: String = "") -> bool:
	if not toggle:
		push_warning("UniversalValidator: Cannot setup toggle - toggle is null in context: %s" % context)
		return false
	
	safe_set_property(toggle, "button_pressed", initial_state, context + " - toggle state")
	return safe_connect_signal(toggle, "toggled", callback, context + " - toggle toggled")

static func safe_setup_input(input: Node, placeholder: String, callback: Callable, context: String = "") -> bool:
	if not input:
		push_warning("UniversalValidator: Cannot setup input - input is null in context: %s" % context)
		return false
	
	safe_set_property(input, "placeholder_text", placeholder, context + " - input placeholder")
	return safe_connect_signal(input, "text_changed", callback, context + " - input text_changed")