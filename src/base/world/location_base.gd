class_name BaseLocation
extends Resource

## Base class for all location implementations
##
## Provides core functionality for representing locations within worlds

# Core signals
signal location_property_changed(property_name: String, new_value: Variant)

# Base properties
var location_name: String = ""
var coordinates: Vector2 = Vector2.ZERO
var properties: Dictionary = {}
var connected_locations: Array[String] = []

# --- Core functionality ---

## Initialize the location with basic properties
func initialize(name: String, coords: Vector2) -> void:
	location_name = name
	coordinates = coords

## Set a property value and emit a signal
func set_property(property_name: String, value: Variant) -> void:
	properties[property_name] = value
	location_property_changed.emit(property_name, value)

## Get a property value, with an optional default if not found
func get_property(property_name: String, default_value: Variant = null) -> Variant:
	return properties.get(property_name, default_value)

## Check if a property exists
func has_property(property_name: String) -> bool:
	return properties.has(property_name)

## Add a connected location
func add_connection(location_name: String) -> void:
	if not connected_locations.has(location_name):
		connected_locations.append(location_name)
		location_property_changed.emit("connections", connected_locations)

## Remove a connected location
func remove_connection(location_name: String) -> void:
	if connected_locations.has(location_name):
		connected_locations.erase(location_name)
		location_property_changed.emit("connections", connected_locations)

## Get all connected locations
func get_connections() -> Array[String]:
	return connected_locations.duplicate()

## Check if this location is connected to another
func is_connected_to(location_name: String) -> bool:
	return connected_locations.has(location_name)

## Get a description of the location
func get_description() -> String:
	return "Location: %s at %s" % [location_name, coordinates]