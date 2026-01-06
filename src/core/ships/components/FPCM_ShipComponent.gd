@tool
extends Resource
class_name FPCM_BaseShipComponent

## Base Ship Component for Five Parsecs
## Provides common functionality for all ship components

signal component_damaged
signal component_repaired
signal component_destroyed

@export var component_name: String = ""
@export var component_type: String = ""
@export var durability: int = 100
@export var max_durability: int = 100
@export var operational: bool = true
@export var cost: int = 0

func _init() -> void:
	pass

func get_component_status() -> Dictionary:
	return {
		"name": component_name,
		"type": component_type,
		"durability": durability,
		"max_durability": max_durability,
		"operational": operational,
		"damage_percentage": float(max_durability - durability) / float(max_durability) * 100.0
	}

func take_damage(amount: int) -> void:
	durability = max(0, durability - amount)

	if durability <= 0:
		operational = false
		component_destroyed.emit()
	else:
		component_damaged.emit()

func repair(amount: int) -> void:
	var old_durability = durability
	durability = min(max_durability, durability + amount)

	if old_durability <= 0 and durability > 0:
		operational = true

	component_repaired.emit()

func is_operational() -> bool:
	return operational and durability > 0

func get_efficiency() -> float:
	if not operational:
		return 0.0
	return float(durability) / float(max_durability)

func serialize() -> Dictionary:
	return {
		"component_name": component_name,
		"component_type": component_type,
		"durability": durability,
		"max_durability": max_durability,
		"operational": operational,
		"cost": cost
	}

func deserialize(data: Dictionary) -> void:
	component_name = data.get("component_name", "")
	component_type = data.get("component_type", "")
	durability = data.get("durability", 100)
	max_durability = data.get("max_durability", 100)
	operational = data.get("operational", true)
	cost = data.get("cost", 0)

