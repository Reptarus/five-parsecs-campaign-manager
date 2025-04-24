@tool
extends Resource
# This file should be referenced via preload
# Use explicit preloads instead of global class names

const Self = preload("res://src/core/state/SerializableResource.gd")

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
static func from_dict(data: Dictionary) -> Resource:
    var instance = Self.new()
    instance.deserialize(data)
    return instance

# Validation method to be implemented by child classes
func validate() -> bool:
    return resource_id != "" and display_name != ""

# Helper method to create a deep copy with serialization
func create_copy() -> Resource:
    var copy = Self.new()
    copy.deserialize(serialize())
    return copy

# Helper method to compare two resources
func equals(other: Resource) -> bool:
    if not other:
        return false
    if not other.has_method("serialize"):
        return false
    return serialize().hash() == other.serialize().hash()

# Helper method to get a string representation
func get_display_string() -> String:
    return "%s (%s)" % [display_name, resource_id]

# Helper method to get a property with default value - mimics the Resource get() method
# This allows subclasses to use the get() pattern safely
func get(property: StringName) -> Variant:
    var property_name = String(property)
    match property_name:
        "resource_id": return resource_id
        "display_name": return display_name
        "resource_type": return resource_type
        "resource_description": return resource_description
        _:
            # Check if the property exists on the object
            if property_name in self:
                return self[property_name]
            return null

# Helper method with default value handling - safe to use in subclasses
func get_property(property_name: String, default_value = null) -> Variant:
    var result = get(property_name)
    return result if result != null else default_value