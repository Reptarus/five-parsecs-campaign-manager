class_name EngineComponent
extends ShipComponent

@export var speed: int
@export var fuel_efficiency: float

func _init(p_name: String, p_description: String, p_power_usage: int, p_health: int, p_speed: int, p_fuel_efficiency: float) -> void:
	super._init(p_name, p_description, ComponentType.ENGINE, p_power_usage, p_health)
	speed = p_speed
	fuel_efficiency = p_fuel_efficiency

func calculate_travel_time(distance: int) -> int:
	if not is_damaged and health > 0:
		return distance / speed
	return -1  # Unable to travel

func serialize() -> Dictionary:
	var data = super.serialize()
	data.merge({
		"speed": speed,
		"fuel_efficiency": fuel_efficiency
	})
	return data

static func deserialize(data: Dictionary) -> EngineComponent:
	var component = EngineComponent.new(
		data["name"],
		data["description"],
		data["power_usage"],
		data["max_health"],
		data["speed"],
		data["fuel_efficiency"]
	)
	component.health = data["health"]
	component.is_damaged = data["is_damaged"]
	return component
