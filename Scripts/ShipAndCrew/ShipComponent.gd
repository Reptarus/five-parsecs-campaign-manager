class_name ShipComponent
extends Resource

enum ComponentType { HULL, ENGINE, WEAPONS, SHIELDS, MEDICAL_BAY, CARGO_HOLD }

@export var type: ComponentType
@export var name: String
@export var description: String
@export var health: int
@export var max_health: int
@export var power_usage: int
@export var is_active: bool = true

func activate() -> void:
	is_active = true

func deactivate() -> void:
	is_active = false

func take_damage(amount: int) -> void:
	health = max(0, health - amount)
	if health == 0:
		deactivate()

func repair(amount: int) -> void:
	health = min(max_health, health + amount)
	if health > 0 and not is_active:
		activate()

func to_dict() -> Dictionary:
	return {
		"type": ComponentType.keys()[type],
		"name": name,
		"description": description,
		"health": health,
		"max_health": max_health,
		"power_usage": power_usage,
		"is_active": is_active
	}

static func from_dict(data: Dictionary) -> ShipComponent:
	var component := ShipComponent.new()
	component.type = ComponentType[data["type"]]
	component.name = data["name"]
	component.description = data["description"]
	component.health = data["health"]
	component.max_health = data["max_health"]
	component.power_usage = data["power_usage"]
	component.is_active = data["is_active"]
	return component
