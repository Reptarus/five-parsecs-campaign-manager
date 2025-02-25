extends Resource

const GameEnums = preload("res://src/core/systems/GlobalEnums.gd")

# Base properties that all serializable resources should have
@export var resource_id: String = ""
@export var display_name: String = ""
@export var resource_type: int = GameEnums.ResourceType.NONE
@export var resource_description: String = ""

# Virtual method to be implemented by child classes
func serialize() -> Dictionary:
    return {
        "resource_id": resource_id,
        "display_name": display_name,
        "resource_type": resource_type,
        "resource_description": resource_description
    }

# Virtual method to be implemented by child classes
func deserialize(data: Dictionary) -> void:
    resource_id = data.get("resource_id", "")
    display_name = data.get("display_name", "")
    resource_type = data.get("resource_type", GameEnums.ResourceType.NONE)
    resource_description = data.get("resource_description", "")

# Static factory method
static func from_dict(data: Dictionary) -> SerializableResource:
    var instance = SerializableResource.new()
    instance.deserialize(data)
    return instance

# Validation method to be implemented by child classes
func validate() -> bool:
    return resource_id != "" and display_name != ""

# Helper method to create a deep copy with serialization
func create_copy() -> SerializableResource:
    var copy = SerializableResource.new()
    copy.deserialize(serialize())
    return copy

# Helper method to compare two resources
func equals(other: SerializableResource) -> bool:
    if not other:
        return false
    return serialize().hash() == other.serialize().hash()

# Helper method to get a string representation
func get_display_string() -> String:
    return "%s (%s)" % [display_name, resource_id]