class_name BaseController
extends RefCounted

## BaseController - Enhanced foundation for all panel controllers
## Production-ready base class with comprehensive error handling and validation
## Integrates UniversalControllerUtilities for consistent behavior across the system

# Core system imports
const ValidationResult = preload("res://src/core/validation/ValidationResult.gd")
const SecurityValidator = preload("res://src/core/validation/SecurityValidator.gd")

# Standardized signals that all panel controllers emit
signal data_updated(panel_name: String, data: Dictionary)
signal validation_changed(panel_name: String, is_valid: bool, errors: Array[String])
signal panel_completed(panel_name: String, data: Dictionary)
signal error_occurred(panel_name: String, error: String)

# Panel identification and management
var panel_name: String = ""
var panel_node: Control = null

# Data management with validation tracking
var panel_data: Dictionary = {}
var validation_errors: Array[String] = []
var is_panel_valid: bool = false

# State management with error recovery
var is_initialized: bool = false
var is_dirty: bool = false  # Has unsaved changes
var last_validation_time: float = 0.0
var validation_cooldown: float = 0.1  # Prevent excessive validation

# Performance tracking
var _initialization_start_time: float = 0.0
var _validation_start_time: float = 0.0

func _init(name: String, node: Control = null) -> void:
	panel_name = name
	panel_node = node
	_initialize_base()

func _initialize_base() -> void:
	## Initialize base controller functionality with performance tracking
	_initialization_start_time = Time.get_unix_time_from_system()
	
	panel_data = {}
	validation_errors = []
	is_panel_valid = false
	is_initialized = false
	is_dirty = false
	last_validation_time = 0.0
	
	log_performance_metric("BaseController._initialize_base", _initialization_start_time, panel_name)

## Public API - Must be implemented by derived controllers

func initialize_panel() -> void:
	## Initialize the specific panel - override in derived classes
	_emit_error("initialize_panel() must be implemented by derived class")

func validate_panel_data() -> ValidationResult:
	## Validate panel data - override in derived classes
	_emit_error("validate_panel_data() must be implemented by derived class")
	return create_validation_failure("Not implemented")

func collect_panel_data() -> Dictionary:
	## Collect data from panel UI - override in derived classes
	_emit_error("collect_panel_data() must be implemented by derived class")
	return {}

func update_panel_display(data: Dictionary) -> void:
	## Update panel UI with data - override in derived classes
	_emit_error("update_panel_display() must be implemented by derived class")

func reset_panel() -> void:
	## Reset panel to initial state - override in derived classes
	_emit_error("reset_panel() must be implemented by derived class")

## Enhanced public interface

func get_panel_name() -> String:
	## Get the panel name
	return panel_name

func get_panel_data() -> Dictionary:
	## Get current panel data (safe copy)
	return panel_data.duplicate()

func is_valid() -> bool:
	## Check if panel data is currently valid
	return is_panel_valid and validation_errors.is_empty()

func get_validation_errors() -> Array[String]:
	## Get current validation errors (safe copy)
	return validation_errors.duplicate()

func has_unsaved_changes() -> bool:
	## Check if panel has unsaved changes
	return is_dirty

func mark_dirty(dirty: bool = true) -> void:
	## Mark panel as having unsaved changes
	is_dirty = dirty

## Protected methods for derived classes with enhanced safety

func _update_data(new_data: Dictionary) -> void:
	## Update panel data and emit signals with validation
	if not new_data:
		debug_print("Warning: Attempted to update with null data")
		return
	
	var merged_data = merge_dictionaries_safe(panel_data, new_data, panel_name)
	panel_data = merged_data
	mark_dirty(true)
	
	data_updated.emit(panel_name, panel_data.duplicate())
	_validate_and_update()

func _validate_and_update() -> void:
	## Validate current data and update state with performance tracking
	var current_time = Time.get_unix_time_from_system()
	
	# Implement validation cooldown to prevent excessive calls
	if current_time - last_validation_time < validation_cooldown:
		return
	
	_validation_start_time = current_time
	last_validation_time = current_time
	
	var validation = validate_panel_data()
	is_panel_valid = validation.valid
	
	# Update validation errors
	validation_errors.clear()
	if not validation.valid and not validation.error.is_empty():
		validation_errors.append(validation.error)
	
	# Add warnings as additional errors for UI display
	if validation.has_warnings():
		validation_errors.append_array(validation.warnings)
	
	validation_changed.emit(panel_name, is_panel_valid, validation_errors.duplicate())
	
	# Check if panel is complete
	if is_panel_valid and _is_panel_complete():
		panel_completed.emit(panel_name, panel_data.duplicate())
	
	log_performance_metric("_validate_and_update", _validation_start_time, panel_name)

func _is_panel_complete() -> bool:
	## Check if panel has all required data - override in derived classes
	return is_panel_valid and not panel_data.is_empty()

## Enhanced utility methods using UniversalControllerUtilities

func _emit_error(error_message: String) -> void:
	## Emit error signal with proper formatting
	emit_controller_error(panel_name, error_message, error_occurred)

func _safe_get_node(path: String) -> Node:
	## Safely get a node from the panel
	return safe_get_node(panel_node, path, panel_name)

func _safe_get_typed_node(path: String, expected_type: String) -> Node:
	## Safely get a typed node from the panel
	return safe_get_typed_node(panel_node, path, expected_type, panel_name)

func _safe_connect_signal(source: Node, signal_name: String, target: Callable) -> bool:
	## Safely connect a signal with error handling
	return safe_connect_signal(source, signal_name, target, panel_name)

func _safe_disconnect_signal(source: Node, signal_name: String, target: Callable) -> bool:
	## Safely disconnect a signal with error handling
	return safe_disconnect_signal(source, signal_name, target, panel_name)

func debug_print(message: String) -> void:
	## Debug print with panel name prefix
	debug_print_controller(panel_name, message)

## Enhanced validation helpers

func _validate_required_fields(data: Dictionary, required_fields: Array) -> ValidationResult:
	## Validate that required fields are present and not empty
	return validate_required_dictionary_fields(data, required_fields, panel_name)

func _is_empty_value(value: Variant) -> bool:
	## Check if a value is considered empty
	return is_empty_value(value)

func _sanitize_string_input(input: String, max_length: int = 100) -> ValidationResult:
	## Sanitize string input for security
	return sanitize_string_input(input, max_length, panel_name)

func _sanitize_numeric_input(input: Variant, min_value: float = -INF, max_value: float = INF) -> ValidationResult:
	## Sanitize and validate numeric input
	return sanitize_numeric_input(input, min_value, max_value, panel_name)

## Dictionary and data helpers

func _safe_dictionary_get(dict: Dictionary, key: String, default_value: Variant = null) -> Variant:
	## Safely get value from dictionary with default
	return safe_dictionary_get(dict, key, default_value, panel_name)

## Tree access helpers

func _safe_tree_access(operation: String) -> bool:
	## Check if tree operations are safe to perform
	return safe_tree_access(panel_node, operation, panel_name)

## Consolidated utility methods (formerly UniversalControllerUtilities)

func safe_get_node(base_node: Node, path: String, error_context: String = "") -> Node:
	## Safely get a node with comprehensive error handling
	if not base_node:
		push_error("CRASH PREVENTION: Base node is null for path '%s' - %s" % [path, error_context])
		return null

	var node = base_node.get_node_or_null(path)
	if not node:
		push_warning("Node not found at path: '%s' - %s" % [path, error_context])

	return node

func safe_get_typed_node(base_node: Node, path: String, expected_type: String, error_context: String = "") -> Node:
	## Safely get a node with type validation
	var node = safe_get_node(base_node, path, error_context)
	if not node:
		return null

	if not node.is_class(expected_type):
		push_warning("Node at '%s' is %s, expected %s - %s" % [path, node.get_class(), expected_type, error_context])

	return node

func safe_connect_signal(source: Node, signal_name: String, target: Callable, error_context: String = "") -> bool:
	## Safely connect signals with comprehensive error handling
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

func safe_disconnect_signal(source: Node, signal_name: String, target: Callable, error_context: String = "") -> bool:
	## Safely disconnect signals with error handling
	if not source:
		return true

	if not source.has_signal(signal_name):
		return true

	if not source.is_connected(signal_name, target):
		return true

	source.disconnect(signal_name, target)
	return true

func create_validation_success(sanitized_value: Variant = null) -> ValidationResult:
	## Create a successful validation result
	var result = ValidationResult.new(true)
	if sanitized_value != null:
		result.sanitized_value = sanitized_value
	return result

func create_validation_failure(error_message: String, warnings: Array = []) -> ValidationResult:
	## Create a failed validation result with error and optional warnings
	var result = ValidationResult.new(false, error_message)
	for warning in warnings:
		result.add_warning(warning)
	return result

func validate_required_dictionary_fields(data: Dictionary, required_fields: Array, context: String = "") -> ValidationResult:
	## Validate that required fields are present in a dictionary
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

func is_empty_value(value: Variant) -> bool:
	## Check if a value is considered empty
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

func emit_controller_error(controller_name: String, error_message: String, error_signal: Signal = Signal()) -> void:
	## Emit error with standardized formatting
	var formatted_error = "%s: %s" % [controller_name, error_message]
	push_error(formatted_error)

	error_signal.emit(controller_name, error_message)

func debug_print_controller(controller_name: String, message: String) -> void:
	## Debug print with controller name prefix
	pass

func log_performance_metric(operation: String, start_time: float, context: String = "") -> void:
	## Log performance metrics for operations
	var elapsed = Time.get_unix_time_from_system() - start_time
	if elapsed > 0.1:
		push_warning("Performance: %s took %.3fs - %s" % [operation, elapsed, context])

func sanitize_string_input(input: String, max_length: int = 100, context: String = "") -> ValidationResult:
	## Sanitize string input with validation
	if input.is_empty():
		return create_validation_failure("Input cannot be empty - %s" % context)

	var sanitized = input.strip_edges()

	if sanitized.length() > max_length:
		sanitized = sanitized.substr(0, max_length)
		var result = create_validation_success(sanitized)
		result.add_warning("Input was truncated to %d characters" % max_length)
		return result

	return create_validation_success(sanitized)

func sanitize_numeric_input(input: Variant, min_value: float = -INF, max_value: float = INF, context: String = "") -> ValidationResult:
	## Sanitize and validate numeric input
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

func safe_dictionary_get(dict: Dictionary, key: String, default_value: Variant = null, context: String = "") -> Variant:
	## Safely get value from dictionary with default
	if not dict:
		push_warning("Dictionary is null for key '%s' - %s" % [key, context])
		return default_value

	return dict.get(key, default_value)

func merge_dictionaries_safe(target: Dictionary, source: Dictionary, context: String = "") -> Dictionary:
	## Safely merge dictionaries with conflict detection
	if not target or not source:
		push_warning("Cannot merge null dictionaries - %s" % context)
		return target if target else {}

	var merged = target.duplicate(true)
	for key in source:
		if key in merged and merged[key] != source[key]:
			push_warning("Dictionary merge conflict for key '%s' - %s" % [key, context])
		merged[key] = source[key]

	return merged

func safe_tree_access(node: Node, operation: String, context: String = "") -> bool:
	## Check if tree operations are safe to perform
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

func safe_scene_change(tree: SceneTree, scene_path: String, context: String = "") -> bool:
	## Safely change scene with error handling
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

## Debug and diagnostics

func get_debug_info() -> Dictionary:
	## Get comprehensive debug information about the panel state
	return {
		"panel_name": panel_name,
		"is_initialized": is_initialized,
		"is_valid": is_panel_valid,
		"is_dirty": is_dirty,
		"data_keys": panel_data.keys(),
		"validation_errors": validation_errors.duplicate(),
		"has_panel_node": panel_node != null,
		"last_validation_time": last_validation_time,
		"validation_cooldown": validation_cooldown,
		"performance_metrics": {
			"initialization_time": _initialization_start_time,
			"last_validation_time": _validation_start_time
		}
	}

func get_performance_summary() -> Dictionary:
	## Get performance metrics for monitoring
	return {
		"panel_name": panel_name,
		"validation_frequency": 1.0 / validation_cooldown if validation_cooldown > 0 else 0,
		"data_size": JSON.stringify(panel_data).length(),
		"error_count": validation_errors.size(),
		"is_responsive": Time.get_unix_time_from_system() - last_validation_time < 1.0
	}
