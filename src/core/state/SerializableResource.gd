extends Resource
class_name SerializableResource

# GlobalEnums available as autoload singleton

# Base properties that all serializable resources should have
@export var resource_id: String = ""
@export var display_name: String = ""
@export var resource_type: int = GlobalEnums.ResourceType.NONE
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

	resource_type = data.get("resource_type", GlobalEnums.ResourceType.NONE)

	resource_description = data.get("resource_description", "")

# Static factory method
static func from_dict(data: Dictionary) -> SerializableResource:
	var instance: SerializableResource = SerializableResource.new()
	instance.deserialize(data)
	return instance

# Validation method to be implemented by child classes
func validate() -> bool:
	return resource_id != "" and display_name != ""

# Helper method to create a deep copy with serialization
func create_copy() -> SerializableResource:
	var copy := SerializableResource.new()
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

## Safe property access helper - eliminates UNSAFE_METHOD_ACCESS warnings
## Based on Godot 4.4 best practices for safe property access
func safe_get_property(obj: Variant, property: String, default_value: Variant = null) -> Variant:
	if obj == null:
		return default_value
	if obj is Object and obj.has_method("get"):
		var value: Variant = obj.get(property)
		return value if value != null else default_value
	elif obj is Dictionary:
		return obj.get(property, default_value)
	return default_value
## Safe method call helper - eliminates UNSAFE_METHOD_ACCESS warnings
func safe_call_method(obj: Variant, method_name: String, args: Array = []) -> Variant:
	if obj == null:
		return null
	if obj is Object and obj.has_method(method_name):
		return obj.callv(method_name, args)
	return null