class_name BaseWorld
extends Resource

## Base class for all world implementations
##
## Provides core functionality for representing game worlds

# Core signals
signal world_initialized
signal world_property_changed(property_name: String, new_value: Variant)

# Base properties
var world_name: String = ""
var is_initialized: bool = false
var properties: Dictionary = {}

# --- Core functionality ---

## Initialize the world with basic properties
func initialize(name: String) -> void:
	world_name = name
	is_initialized = true
	world_initialized.emit()

## Set a property value and emit a signal
func set_property(property_name: String, value: Variant) -> void:
	properties[property_name] = value
	world_property_changed.emit(property_name, value)

## Get a property value, with an optional default if not found
func get_property(property_name: String, default_value: Variant = null) -> Variant:
	return properties.get(property_name, default_value)

## Check if a property exists
func has_property(property_name: String) -> bool:
	return properties.has(property_name)

## Get all properties
func get_all_properties() -> Dictionary:
	return properties.duplicate()

## Clear all properties
func clear_properties() -> void:
	properties.clear()
	world_property_changed.emit("all", null)

## Get a description of the world
func get_description() -> String:
	return "World: %s" % world_name