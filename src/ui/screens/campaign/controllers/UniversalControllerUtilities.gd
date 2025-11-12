class_name UniversalControllerUtilities
extends RefCounted

## UniversalControllerUtilities: Centralized utility functions for all controllers
## Provides consistent implementations for common patterns across the Five Parsecs project
## Ensures all controllers have access to essential functionality

# Import system dependencies
const ValidationResult = preload("res://src/core/validation/ValidationResult.gd")
const SecurityValidator = preload("res://src/core/validation/SecurityValidator.gd")

## Safe Node Access Utilities

static func safe_get_node(base_node: Node, path: String, error_context: String = "") -> Node:
	"""Safely get a node with comprehensive error handling"""
	if not base_node:
		push_error("CRASH PREVENTION: Base node is null for path '%s' - %s" % [path, error_context])
		return null
	
	var node = base_node.get_node_or_null(path)
	if not node:
		push_warning("Node not found at path: '%s' - %s" % [path, error_context])
	
	return node

static func safe_get_typed_node(base_node: Node, path: String, expected_type: String, error_context: String = "") -> Node:
	"""Safely get a node with type validation"""
	var node = safe_get_node(base_node, path, error_context)
	if not node:
		return null
	
	# Check if node is of expected type
	if not node.is_class(expected_type):
		push_warning("Node at '%s' is %s, expected %s - %s" % [path, node.get_class(), expected_type, error_context])
	
	return node

## Signal Connection Utilities

static func safe_connect_signal(source: Node, signal_name: String, target: Callable, error_context: String = "") -> bool:
	"""Safely connect signals with comprehensive error handling"""
	if not source:
		push_error("CRASH PREVENTION: Source node is null for signal '%s' - %s" % [signal_name, error_context])
		return false
	
	if not source.has_signal(signal_name):
		push_error("Signal '%s' not found on node %s - %s" % [signal_name, source.name, error_context])
		return false
	
	if source.is_connected(signal_name, target):
		push_warning("Signal '%s' already connected - %s" % [signal_name, error_context])
		return true
	
	var result = source.connect(signal_name, target)
	if result != OK:
		push_error("CRASH PREVENTION: Signal connection failed: %s - %s (Error: %s)" % [signal_name, error_context, result])
		return false
	
	return true

static func safe_disconnect_signal(source: Node, signal_name: String, target: Callable, error_context: String = "") -> bool:
	"""Safely disconnect signals with error handling"""
	if not source:
		return true # Already disconnected
	
	if not source.has_signal(signal_name):
		return true # Signal doesn't exist
	
	if not source.is_connected(signal_name, target):
		return true # Already disconnected
	
	source.disconnect(signal_name, target)
	return true

## Validation Utilities

static func create_validation_success(sanitized_value: Variant = null) -> ValidationResult:
	"""Create a successful validation result"""
	var result = ValidationResult.new(true)
	if sanitized_value != null:
		result.sanitized_value = sanitized_value
	return result

static func create_validation_failure(error_message: String, warnings: Array[String] = []) -> ValidationResult:
	"""Create a failed validation result with error and optional warnings"""
	var result = ValidationResult.new(false, error_message)
	for warning in warnings:
		result.add_warning(warning)
	return result

static func validate_required_dictionary_fields(data: Dictionary, required_fields: Array[String], context: String = "") -> ValidationResult:
	"""Validate that required fields are present in a dictionary"""
	var missing_fields: Array[String] = []
	
	for field in required_fields:
		if not data.has(field):
			missing_fields.append(field)
		elif is_empty_value(data[field]):
			missing_fields.append(field + " (empty)")
	
	if missing_fields.is_empty():
		return create_validation_success()
	else:
		var error_msg = "Missing required fields in %s: %s" % [context, ", ".join(missing_fields)]
		return create_validation_failure(error_msg)

static func is_empty_value(value: Variant) -> bool:
	"""Check if a value is considered empty"""
	if value == null:
		return true
	
	match typeof(value):
		TYPE_STRING:
			return (value as String).is_empty()
		TYPE_ARRAY:
			return (value as Array).is_empty()
		TYPE_DICTIONARY:
			return (value as Dictionary).is_empty()
		_:
			return false

## Error Handling and Logging

static func emit_controller_error(controller_name: String, error_message: String, error_signal: Signal = Signal()) -> void:
	"""Emit error with standardized formatting"""
	var formatted_error = "%s: %s" % [controller_name, error_message]
	push_error(formatted_error)
	
	# Signal validation removed - Framework Bible compliance
	error_signal.emit(controller_name, error_message)

static func debug_print_controller(controller_name: String, message: String) -> void:
	"""Debug print with controller name prefix"""
	print("[%s] %s" % [controller_name, message])

static func log_performance_metric(operation: String, start_time: float, context: String = "") -> void:
	"""Log performance metrics for operations"""
	var elapsed = Time.get_unix_time_from_system() - start_time
	if elapsed > 0.1: # Log operations longer than 100ms
		push_warning("Performance: %s took %.3fs - %s" % [operation, elapsed, context])

## Data Sanitization Utilities

static func sanitize_string_input(input: String, max_length: int = 100, context: String = "") -> ValidationResult:
	"""Sanitize string input with validation"""
	if input.is_empty():
		return create_validation_failure("Input cannot be empty - %s" % context)
	
	var sanitized = input.strip_edges()
	
	if sanitized.length() > max_length:
		sanitized = sanitized.substr(0, max_length)
		var result = create_validation_success(sanitized)
		result.add_warning("Input was truncated to %d characters" % max_length)
		return result
	
	return create_validation_success(sanitized)

static func sanitize_numeric_input(input: Variant, min_value: float = - INF, max_value: float = INF, context: String = "") -> ValidationResult:
	"""Sanitize and validate numeric input"""
	var numeric_value: float
	
	if input is String:
		if not (input as String).is_valid_float():
			return create_validation_failure("Invalid number format - %s" % context)
		numeric_value = (input as String).to_float()
	elif input is int or input is float:
		numeric_value = input as float
	else:
		return create_validation_failure("Input must be a number - %s" % context)
	
	if numeric_value < min_value:
		return create_validation_failure("Value must be at least %s - %s" % [str(min_value), context])
	
	if numeric_value > max_value:
		return create_validation_failure("Value cannot exceed %s - %s" % [str(max_value), context])
	
	return create_validation_success(numeric_value)

## Dictionary and Data Utilities

static func safe_dictionary_get(dict: Dictionary, key: String, default_value: Variant = null, context: String = "") -> Variant:
	"""Safely get value from dictionary with default"""
	if not dict:
		push_warning("Dictionary is null for key '%s' - %s" % [key, context])
		return default_value
	
	return dict.get(key, default_value)

static func merge_dictionaries_safe(target: Dictionary, source: Dictionary, context: String = "") -> Dictionary:
	"""Safely merge dictionaries with conflict detection"""
	if not target or not source:
		push_warning("Cannot merge null dictionaries - %s" % context)
		return target if target else {}
	
	var merged = target.duplicate(true)
	for key in source:
		if key in merged and merged[key] != source[key]:
			push_warning("Dictionary merge conflict for key '%s' - %s" % [key, context])
		merged[key] = source[key]
	
	return merged

## Tree and Scene Utilities

static func safe_tree_access(node: Node, operation: String, context: String = "") -> bool:
	"""Check if tree operations are safe to perform"""
	if not node:
		push_error("CRASH PREVENTION: Node is null for tree operation '%s' - %s" % [operation, context])
		return false
	
	if not node.is_inside_tree():
		push_warning("Node not in tree for operation '%s' - %s" % [operation, context])
		return false
	
	var tree = node.get_tree()
	if not tree:
		push_error("CRASH PREVENTION: Tree is null for operation '%s' - %s" % [operation, context])
		return false
	
	return true

static func safe_scene_change(tree: SceneTree, scene_path: String, context: String = "") -> bool:
	"""Safely change scene with error handling"""
	if not tree:
		push_error("CRASH PREVENTION: Tree is null for scene change - %s" % context)
		return false
	
	if not FileAccess.file_exists(scene_path):
		push_error("Scene file not found: %s - %s" % [scene_path, context])
		return false
	
	var result = tree.change_scene_to_file(scene_path)
	if result != OK:
		push_error("Scene change failed: %s (Error: %s) - %s" % [scene_path, result, context])
		return false
	
	return true