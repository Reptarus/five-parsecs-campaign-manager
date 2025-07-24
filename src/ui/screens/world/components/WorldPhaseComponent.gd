@tool
extends Control
class_name WorldPhaseComponent

## Base class for WorldPhaseUI component extraction
## Provides common functionality and signal forwarding for extracted components

# Signals forwarded to parent WorldPhaseUI
signal component_ready(component_name: String)
signal component_error(component_name: String, error_message: String)
signal component_state_changed(component_name: String, new_state: Dictionary)

# Common references that all components need
var world_phase: Resource = null
var data_manager: Node = null
var parent_ui: Control = null
var component_name: String = ""
var is_initialized: bool = false

# Feature flag support
var feature_enabled: bool = true

func _init(p_component_name: String = "UnknownComponent"):
	component_name = p_component_name
	name = component_name

func _ready() -> void:
	if not feature_enabled:
		hide()
		return
	
	_initialize_component()

func _initialize_component() -> void:
	"""Override in derived classes for component-specific initialization"""
	if _validate_dependencies():
		_setup_component_ui()
		_connect_component_signals()
		is_initialized = true
		component_ready.emit(component_name)
	else:
		component_error.emit(component_name, "Failed to validate dependencies")

func _validate_dependencies() -> bool:
	"""Override to validate component-specific dependencies"""
	return parent_ui != null

func _setup_component_ui() -> void:
	"""Override to create component-specific UI"""
	pass

func _connect_component_signals() -> void:
	"""Override to connect component-specific signals"""
	pass

func set_world_phase_data(phase_data: Resource) -> void:
	"""Set world phase data reference"""
	world_phase = phase_data
	if is_initialized:
		_on_world_phase_data_changed()

func _on_world_phase_data_changed() -> void:
	"""Override to handle world phase data changes"""
	pass

func set_parent_ui(ui: Control) -> void:
	"""Set parent WorldPhaseUI reference"""
	parent_ui = ui

func set_data_manager(manager: Node) -> void:
	"""Set data manager reference"""
	data_manager = manager

func enable_feature(enabled: bool) -> void:
	"""Enable or disable this component based on feature flag"""
	feature_enabled = enabled
	visible = enabled
	
	if enabled and not is_initialized:
		_initialize_component()

func get_component_state() -> Dictionary:
	"""Override to return component state for debugging/monitoring"""
	return {
		"component_name": component_name,
		"is_initialized": is_initialized,
		"feature_enabled": feature_enabled,
		"visible": visible
	}

# Error handling utilities
func _handle_error(error_message: String, should_hide: bool = false) -> void:
	"""Standard error handling for components"""
	push_error("%s Error: %s" % [component_name, error_message])
	component_error.emit(component_name, error_message)
	
	if should_hide:
		hide()

func _log_info(message: String) -> void:
	"""Standard logging for component operations"""
	print("%s: %s" % [component_name, message])

# Signal forwarding utilities
func _forward_signal(signal_name: String, args: Array = []) -> void:
	"""Forward signals to parent UI when needed"""
	if parent_ui and parent_ui.has_signal(signal_name):
		parent_ui.emit_signal(signal_name, args)
	else:
		_log_info("Cannot forward signal %s - parent UI not available or signal doesn't exist" % signal_name)