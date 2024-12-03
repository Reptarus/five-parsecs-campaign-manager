class_name SerializableResource
extends Resource

# Virtual method to be implemented by child classes
func serialize() -> Dictionary:
    return {}

# Virtual method to be implemented by child classes
func deserialize(data: Dictionary) -> void:
    pass

# Static factory method
static func from_dict(data: Dictionary) -> SerializableResource:
    var instance = new()
    instance.deserialize(data)
    return instance 