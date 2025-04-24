@tool
extends RefCounted

## Helper utilities for ResponsiveContainer testing
##
## This class centralizes testing utilities for ResponsiveContainer to handle
## potential conflicts between implementations and provide safer test methods.

# Constants
const PATH_BASE = "res://src/ui/components/base/ResponsiveContainer.gd"
const PATH_DEPRECATED = "res://src/ui/components/ResponsiveContainer.gd"

# Type-safe helper methods
static func create_container() -> Control:
	# Load the script directly to ensure type compatibility
	var script_resource = load(PATH_BASE)
	if not script_resource:
		push_error("Failed to load ResponsiveContainer script")
		return null
		
	# Create the container with explicit type safety
	var container = script_resource.new() as Control
	if not container:
		push_error("Failed to instantiate ResponsiveContainer")
		return null
		
	# Set a name to help with debugging
	container.name = "TestResponsiveContainer"
		
	return container

# Safely access layout modes on the container
static func get_layout_mode(container: Control, mode_name: String, default_value: int = -1) -> int:
	if not container or not is_instance_valid(container):
		push_error("Invalid container instance")
		return default_value
		
	if not "ResponsiveLayoutMode" in container:
		push_error("Container does not have ResponsiveLayoutMode enum")
		return default_value
		
	var modes = container.get("ResponsiveLayoutMode")
	if not modes or not mode_name in modes:
		push_error("ResponsiveLayoutMode does not contain: " + mode_name)
		return default_value
		
	return modes[mode_name]

# Safer signal watching
static func watch_container_signals(signal_watcher: RefCounted, container: Control) -> bool:
	if not signal_watcher or not is_instance_valid(container):
		return false
		
	# Check for required signals
	var required_signals = ["layout_changed", "orientation_changed"]
	for signal_name in required_signals:
		if not container.has_signal(signal_name):
			push_warning("Container missing required signal: " + signal_name)
			return false
			
	# Watch signals using the watcher
	if signal_watcher.has_method("watch_signals"):
		signal_watcher.watch_signals(container)
		return true
		
	return false

# Safe container verification
static func verify_container_integrity(container: Control) -> bool:
	if not is_instance_valid(container):
		return false
		
	# Check if the container has the right script
	var script_path = ""
	if container.get_script():
		script_path = container.get_script().resource_path
	
	if not (script_path == PATH_BASE or script_path == PATH_DEPRECATED):
		push_warning("Container has incorrect script: " + script_path)
		push_warning("Expected either: " + PATH_BASE + " or " + PATH_DEPRECATED)
		return false
		
	# Check required properties
	var required_properties = [
		"responsive_mode",
		"min_width_for_horizontal",
		"horizontal_spacing",
		"vertical_spacing",
		"padding",
		"is_compact",
		"is_portrait"
	]
	
	for prop in required_properties:
		if not prop in container:
			push_warning("Container missing required property: " + prop)
			return false
			
	# Check required methods
	var required_methods = [
		"_sort_children",
		"_should_use_compact_layout",
		"_check_orientation",
		"force_layout_update"
	]
	
	for method in required_methods:
		if not container.has_method(method):
			push_warning("Container missing required method: " + method)
			return false
			
	return true