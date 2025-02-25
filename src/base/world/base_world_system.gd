@tool
extends Node

## Base class for world systems
##
## Provides core functionality for managing game worlds, locations, and navigation.

signal world_initialized
signal location_changed(old_location: Vector2, new_location: Vector2)
signal world_state_changed

# World state
var world_size: Vector2 = Vector2.ZERO
var current_location: Vector2 = Vector2.ZERO
var is_initialized: bool = false

# Virtual methods to be implemented by derived classes
func initialize_world(size: Vector2) -> void:
    world_size = size
    is_initialized = true
    world_initialized.emit()

func set_location(new_location: Vector2) -> bool:
    if not is_valid_location(new_location):
        return false
    
    var old_location = current_location
    current_location = new_location
    location_changed.emit(old_location, new_location)
    return true

func is_valid_location(location: Vector2) -> bool:
    if not is_initialized:
        return false
    return location.x >= 0 and location.x < world_size.x and location.y >= 0 and location.y < world_size.y

func get_current_location() -> Vector2:
    return current_location

func get_world_size() -> Vector2:
    return world_size

func serialize() -> Dictionary:
    return {
        "world_size": {
            "x": world_size.x,
            "y": world_size.y
        },
        "current_location": {
            "x": current_location.x,
            "y": current_location.y
        },
        "is_initialized": is_initialized
    }

func deserialize(data: Dictionary) -> void:
    if data.has("world_size"):
        world_size = Vector2(
            data["world_size"].get("x", 0),
            data["world_size"].get("y", 0)
        )
    
    if data.has("current_location"):
        current_location = Vector2(
            data["current_location"].get("x", 0),
            data["current_location"].get("y", 0)
        )
    
    is_initialized = data.get("is_initialized", false)
    if is_initialized:
        world_initialized.emit() 