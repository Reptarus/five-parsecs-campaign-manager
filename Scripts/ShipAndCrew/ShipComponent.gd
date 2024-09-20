class_name ShipComponent
extends Resource

@export var name: String
@export var description: String
@export var component_type: GlobalEnums.ComponentType
@export var power_usage: int
@export var health: int
@export var is_damaged: bool = false
@export var weight: float = 1.0

func _init(p_name: String = "", p_description: String = "", p_component_type: GlobalEnums.ComponentType = GlobalEnums.ComponentType.HULL, p_power_usage: int = 0, p_health: int = 0, p_weight: float = 1.0):
	name = p_name
	description = p_description
	component_type = p_component_type
	power_usage = p_power_usage
	health = p_health
	weight = p_weight

# Add other common methods here
func serialize() -> Dictionary:
	var data = {
		"name": name,
		"description": description,
		"type": component_type,
		"power_usage": power_usage,
		"health": health,
		"is_damaged": is_damaged
	}
	data["weight"] = weight
	return data

static func deserialize(data: Dictionary) -> ShipComponent:
	var component = ShipComponent.new(
		data["name"],
		data["description"],
		data["type"],
		data["power_usage"],
		data["health"],
		data["weight"]
	)
	component.is_damaged = data["is_damaged"]
	return component

func repair() -> void:
	is_damaged = false

func damage() -> void:
	is_damaged = true

func get_effectiveness() -> float:
	return 1.0 if not is_damaged else 0.5

# Add a method for taking damage
func take_damage(amount: int) -> void:
	health = max(0, health - amount)
	if health == 0:
		damage()

