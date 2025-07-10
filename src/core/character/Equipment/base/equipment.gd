extends Resource
class_name BaseEquipment

## Base equipment class for Five Parsecs
## Provides common functionality for all equipment types

const GlobalEnums = preload("res://src/core/systems/GlobalEnums.gd")

signal equipment_used
signal equipment_destroyed

@export var equipment_id: String = ""
@export var equipment_name: String = ""
@export var description: String = ""
@export var weight: float = 0.0
@export var value: int = 0
@export var is_destroyed: bool = false
@export var durability: int = 100
@export var max_durability: int = 100

func _init() -> void:
	equipment_id = "equipment_" + str(randi())

func get_equipment_id() -> String:
	return equipment_id

func get_equipment_name() -> String:
	return equipment_name

func get_description() -> String:
	return description

func get_weight() -> float:
	return weight

func get_value() -> int:
	return value

func is_equipment_destroyed() -> bool:
	return is_destroyed

func use_equipment() -> void:
	equipment_used.emit()

func destroy_equipment() -> void:
	is_destroyed = true
	equipment_destroyed.emit()

func repair_equipment(amount: int) -> void:
	durability = min(durability + amount, max_durability)
	if durability > 0:
		is_destroyed = false

func serialize() -> Dictionary:
	return {
		"equipment_id": equipment_id,
		"equipment_name": equipment_name,
		"description": description,
		"weight": weight,
		"value": value,
		"is_destroyed": is_destroyed,
		"durability": durability,
		"max_durability": max_durability
	}

func deserialize(data: Dictionary) -> void:
	equipment_id = data.get("equipment_id", "")
	equipment_name = data.get("equipment_name", "")
	description = data.get("description", "")
	weight = data.get("weight", 0.0)
	value = data.get("value", 0)
	is_destroyed = data.get("is_destroyed", false)
	durability = data.get("durability", 100)
	max_durability = data.get("max_durability", 100)
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