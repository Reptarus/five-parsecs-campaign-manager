@tool
extends Resource
class_name GameArmor

## Game Armor class for Five Parsecs
## Provides armor protection and characteristics

# GlobalEnums available as autoload singleton

@export var armor_id: String = ""
@export var armor_name: String = ""
@export var description: String = ""
@export var protection_value: int = 1
@export var weight: float = 1.0
@export var armor_type: String = "basic"
@export var durability: int = 100

func _init() -> void:
	armor_id = "armor_" + str(randi())

func get_protection() -> int:
	return protection_value

func get_armor_name() -> String:
	return armor_name

func get_weight() -> float:
	return weight

func serialize() -> Dictionary:
	return {
		"armor_id": armor_id,
		"armor_name": armor_name,
		"description": description,
		"protection_value": protection_value,
		"weight": weight,
		"armor_type": armor_type,
		"durability": durability
	}

func deserialize(data: Dictionary) -> void:
	armor_id = data.get("armor_id", "")
	armor_name = data.get("armor_name", "")
	description = data.get("description", "")
	protection_value = data.get("protection_value", 1)
	weight = data.get("weight", 1.0)
	armor_type = data.get("armor_type", "basic")
	durability = data.get("durability", 100)

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