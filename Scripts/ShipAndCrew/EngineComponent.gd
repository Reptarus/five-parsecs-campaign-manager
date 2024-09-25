# Scripts/ShipAndCrew/EngineComponent.gd
class_name EngineComponent extends ShipComponent

@export var speed: int
@export var fuel_efficiency: float

func _init(p_name: String, p_description: String, p_power_usage: int, p_health: int, p_weight: float = 1.0, p_speed: int = 0, p_fuel_efficiency: float = 0.0):
	super(p_name, p_description, GlobalEnums.ComponentType.ENGINE, p_power_usage, p_health, p_weight)
	speed = p_speed
	fuel_efficiency = p_fuel_efficiency

func calculate_travel_time(distance: int) -> int:
	if health > 0:
		return int(float(distance) / speed)
	return -1  # Unable to travel

func modify_fuel_cost(base_cost: int) -> int:
	return int(base_cost * (1.0 - fuel_efficiency))

func serialize() -> Dictionary:
	var data = super.serialize()
	data["speed"] = speed
	data["fuel_efficiency"] = fuel_efficiency
	return data

static func deserialize(data: Dictionary) -> EngineComponent:
	var component = EngineComponent.new(
		data["name"],
		data["description"],
		data["power_usage"],
		data["health"],
		data["weight"],
		data["speed"],
		data["fuel_efficiency"]
	)
	component.max_health = data["max_health"]
	component.is_damaged = data["is_damaged"]
	return component
