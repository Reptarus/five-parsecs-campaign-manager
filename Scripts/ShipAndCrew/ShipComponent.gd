class_name ShipComponent
extends Equipment

enum ComponentType { HULL, ENGINE, WEAPONS, SHIELDS, MEDICAL_BAY, CARGO_HOLD, DROP_PODS, SHUTTLE }

@export var component_type: ComponentType
@export var power_usage: int
@export var health: int
@export var max_health: int

func _init(p_name: String, p_description: String, p_component_type: ComponentType, p_power_usage: int, p_health: int):
	super._init(p_name, Equipment.Type.SHIP_COMPONENT, 0, p_description)
	component_type = p_component_type
	power_usage = p_power_usage
	health = p_health
	max_health = p_health

func activate() -> void:
	is_damaged = false

func deactivate() -> void:
	is_damaged = true

func take_damage(amount: int) -> void:
	health = max(0, health - amount)
	if health == 0:
		deactivate()

func repair(amount: int = 0) -> void:
	super.repair()
	if amount == 0:
		health = max_health
	else:
		health = min(max_health, health + amount)

func serialize() -> Dictionary:
	var data = super.serialize()
	data.merge({
		"component_type": ComponentType.keys()[component_type],
		"power_usage": power_usage,
		"health": health,
		"max_health": max_health
	})
	return data

static func deserialize(data: Dictionary) -> ShipComponent:
	var component = ShipComponent.new(
		data["name"],
		data["description"],
		ComponentType[data["component_type"]],
		data["power_usage"],
		data["max_health"]
	)
	component.health = data["health"]
	component.is_damaged = data["is_damaged"]
	return component
